import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

import '../face_tracking/face_pose_estimator.dart';
import '../face_tracking/glasses_2d_layout.dart';
import '../input_image/mlkit_image_prepare.dart';
import '../widgets/glasses_picker.dart';
import 'glasses_try_on_3d_screen.dart';
import 'glasses_try_on_live_screen.dart';

/// Экран примерки по **одному снимку** (камера/галерея) + 2D PNG поверх фото.
///
/// Раньше файл назывался `test_google_mlkit.dart`, что путало с unit-тестами.
/// Отдельно доступны [GlassesTryOnLiveScreen] (поток) и [GlassesTryOn3DScreen] (GLB).
class GlassesTryOnPhotoScreen extends StatefulWidget {
  const GlassesTryOnPhotoScreen({super.key, required this.allCameras});

  /// Все доступные камеры (для переходов в live / 3D с переключателем).
  final List<CameraDescription> allCameras;

  /// Камера по умолчанию для маршрутов, где нужен один [CameraDescription].
  CameraDescription get defaultCamera => allCameras.first;

  @override
  State<GlassesTryOnPhotoScreen> createState() =>
      _GlassesTryOnPhotoScreenState();
}

class _GlassesTryOnPhotoScreenState extends State<GlassesTryOnPhotoScreen> {
  late FaceDetector _faceDetector;
  late final FacePoseEstimator _poseEstimator;
  List<Face> _faces = [];
  late ImagePicker _picker;
  ui.Image? _image;
  Size? _imageSize;
  String? _selectedGlasses;
  ui.Image? _glassesImage;

  /// Идёт чтение файла, bake EXIF и `processImage` ML Kit.
  bool _isScanning = false;

  static const List<String> _glassesAssets = [
    'assets/glasses1.png',
    'assets/glasses2.png',
    'assets/glasses3.png',
  ];

  @override
  void initState() {
    super.initState();
    _picker = ImagePicker();
    _poseEstimator = FacePoseEstimator();
    // На одиночном снимке из галереи/камеры «accurate» даёт более стабильные landmarks
    // (уши, скулы) и углы Эйлера — для примерки 2D это важнее скорости, чем в видеопотоке.
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: true,
      ),
    );
  }

  @override
  void dispose() {
    _image?.dispose();
    _glassesImage?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  /// Переход на экран с GLB; вынесен, чтобы не дублировать с AppBar и блоком под превью.
  void _openGlasses3DScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GlassesTryOn3DScreen(camera: widget.defaultCamera),
      ),
    );
  }

  /// Живой поток с камеры (отдельный экран с собственным [FaceDetector]).
  void _openLiveScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GlassesTryOnLiveScreen(allCameras: widget.allCameras),
      ),
    );
  }

  Future<void> _getAndScanImage({final bool? isFromCamera}) async {
    setState(() {
      _isScanning = true;
    });

    PreparedMlKitImage? prepared;
    try {
      final imageXFile = await _picker.pickImage(
        source: isFromCamera != null && isFromCamera
            ? ImageSource.camera
            : ImageSource.gallery,
      );

      if (imageXFile == null) {
        return;
      }

      final rawBytes = await imageXFile.readAsBytes();
      prepared = await prepareImageBytesForMlKit(rawBytes);

      final inputImage = inputImageFromPreparedFile(prepared.tempJpegFile);
      final facesList = await _faceDetector.processImage(inputImage);
      final imageDecoded = await decodePreparedBytesToUiImage(
        prepared.bytesForDecodeAndMlKit,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _image?.dispose();
        _faces = facesList;
        _image = imageDecoded;
        _imageSize = Size(
          imageDecoded.width.toDouble(),
          imageDecoded.height.toDouble(),
        );
      });
    } catch (e, st) {
      debugPrint('Ошибка загрузки/распознавания: $e\n$st');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка обработки изображения: $e')),
      );
    } finally {
      await prepared?.deleteTempFile();
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _selectGlasses(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();

      final previousGlasses = _glassesImage;
      setState(() {
        _selectedGlasses = assetPath;
        _glassesImage = frame.image;
      });
      previousGlasses?.dispose();
    } catch (e) {
      debugPrint('Error loading glasses image: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка загрузки очков: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Virtual Glasses Try-On'),
        actions: [
          IconButton(
            tooltip: 'Live с камеры',
            onPressed: _isScanning ? null : _openLiveScreen,
            icon: const Icon(Icons.videocam),
          ),
          IconButton(
            tooltip: 'Открыть 3D режим',
            onPressed: _isScanning ? null : _openGlasses3DScreen,
            icon: const Icon(Icons.view_in_ar),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: _image == null
                      ? const Text(
                          'Выберите изображение',
                          style: TextStyle(fontSize: 18),
                        )
                      : FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: _imageSize!.width,
                            height: _imageSize!.height,
                            child: CustomPaint(
                              painter: FacePainter(
                                faceList: _faces,
                                image: _image!,
                                glassesImage: _glassesImage,
                                poseEstimator: _poseEstimator,
                              ),
                            ),
                          ),
                        ),
                ),
                if (_isScanning)
                  Positioned.fill(
                    child: ColoredBox(
                      color: const Color(0x66000000),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(
                              'Распознавание лица…',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isScanning
                      ? null
                      : () => _getAndScanImage(isFromCamera: true),
                  child: const Text('Камера'),
                ),
                ElevatedButton(
                  onPressed: _isScanning
                      ? null
                      : () => _getAndScanImage(isFromCamera: false),
                  child: const Text('Галерея'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                const Chip(
                  avatar: Icon(Icons.image_outlined, size: 18),
                  label: Text('Сейчас: фото (2D PNG)'),
                ),
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _openLiveScreen,
                  icon: const Icon(Icons.videocam),
                  label: const Text('Live с камеры'),
                ),
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _openGlasses3DScreen,
                  icon: const Icon(Icons.view_in_ar),
                  label: const Text('3D примерка (GLB)'),
                ),
              ],
            ),
          ),
          GlassesPickerStrip(
            glassesAssets: _glassesAssets,
            selectedGlassesPath: _selectedGlasses,
            onSelectGlasses: _selectGlasses,
            enabled: !_isScanning,
          ),
        ],
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  FacePainter({
    required this.faceList,
    required this.image,
    this.glassesImage,
    required this.poseEstimator,
  });

  final List<Face> faceList;
  final ui.Image image;
  final ui.Image? glassesImage;
  final FacePoseEstimator poseEstimator;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    canvas.drawImage(image, ui.Offset.zero, ui.Paint());

    if (glassesImage == null) {
      return;
    }

    for (final face in faceList) {
      _drawGlassesOnFace(canvas, face, glassesImage!);
    }
  }

  void _drawGlassesOnFace(ui.Canvas canvas, Face face, ui.Image glassesImage) {
    final layout = Glasses2DLayout.compute(
      face,
      poseEstimator,
      assetPixelWidth: glassesImage.width,
      assetPixelHeight: glassesImage.height,
    );
    if (!layout.isValid) {
      return;
    }

    // Порядок операций в матрице: перенос в центр оправы → yaw/roll → смещение в левый верх dstRect.
    final matrix = Matrix4.identity()
      ..translateByDouble(layout.centerX, layout.centerY, 0, 1)
      ..rotateZ(layout.rollRadians)
      ..translateByDouble(-layout.width / 2, -layout.height / 2, 0, 1);

    final srcRect = ui.Rect.fromLTWH(
      0,
      0,
      glassesImage.width.toDouble(),
      glassesImage.height.toDouble(),
    );
    final dstRect = ui.Rect.fromLTWH(0, 0, layout.width, layout.height);

    canvas.save();
    canvas.transform(matrix.storage);
    canvas.drawImageRect(glassesImage, srcRect, dstRect, ui.Paint());
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FacePainter oldDelegate) {
    return oldDelegate.faceList != faceList ||
        oldDelegate.image != image ||
        oldDelegate.glassesImage != glassesImage ||
        oldDelegate.poseEstimator != poseEstimator;
  }
}
