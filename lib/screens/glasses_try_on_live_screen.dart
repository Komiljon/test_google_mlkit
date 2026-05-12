import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../face_tracking/face_coordinate_mapper.dart';
import '../face_tracking/face_pose_estimator.dart';
import '../face_tracking/glasses_2d_layout.dart';
import '../face_tracking/live_face_detection_controller.dart';
import '../widgets/glasses_picker.dart';

/// Экран **live**-примерки: поток кадров → ML Kit → PNG поверх [CameraPreview].
///
/// Ориентация зафиксирована в портрете — так проще совпасть с внутренним
/// [RotatedBox] Android в [CameraPreview] и с маппингом координат.
class GlassesTryOnLiveScreen extends StatefulWidget {
  const GlassesTryOnLiveScreen({super.key, required this.allCameras});

  final List<CameraDescription> allCameras;

  @override
  State<GlassesTryOnLiveScreen> createState() => _GlassesTryOnLiveScreenState();
}

class _GlassesTryOnLiveScreenState extends State<GlassesTryOnLiveScreen>
    with WidgetsBindingObserver {
  late final LiveFaceDetectionController _live;
  late final FacePoseEstimator _poseEstimator;

  ui.Image? _glassesImage;
  String? _selectedGlasses;

  /// Время, с которого не видим ни одного лица (для подсказки «Лицо не найдено»).
  DateTime? _noFaceSince;

  static const List<String> _glassesAssets = [
    'assets/glasses1.png',
    'assets/glasses2.png',
    'assets/glasses3.png',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Упрощает согласование превью и координат ML Kit (см. [CameraPreview]).
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);

    _poseEstimator = FacePoseEstimator();
    _live = LiveFaceDetectionController(cameras: widget.allCameras);
    _live.addListener(_onLiveUpdate);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      await _live.initialize();
    } catch (e, st) {
      debugPrint('Live init error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось запустить камеру: $e')),
      );
    }
  }

  void _onLiveUpdate() {
    if (!mounted) return;
    if (_live.faces.isEmpty) {
      _noFaceSince ??= DateTime.now();
    } else {
      _noFaceSince = null;
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_live.handleAppLifecycleState(state));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
    _live.removeListener(_onLiveUpdate);
    _live.dispose();
    _glassesImage?.dispose();
    super.dispose();
  }

  /// Android: превью фронталки зеркалится; iOS — обычно нет. ML Kit всегда в «сырых» координатах.
  bool get _mirrorPreviewHorizontally {
    return Platform.isAndroid &&
        _live.currentCamera.lensDirection == CameraLensDirection.front;
  }

  Future<void> _selectGlasses(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final prev = _glassesImage;
      setState(() {
        _selectedGlasses = assetPath;
        _glassesImage = frame.image;
      });
      prev?.dispose();
    } catch (e) {
      debugPrint('Live glasses load error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка загрузки очков: $e')));
    }
  }

  /// Возврат к экрану фото (live обычно открыт поверх него через [Navigator.push]).
  void _backToPhotoScreen() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final showNoFaceHint =
        _noFaceSince != null &&
        DateTime.now().difference(_noFaceSince!) >
            const Duration(milliseconds: 500) &&
        _live.faces.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live примерка (2D)'),
        actions: [
          IconButton(
            tooltip: 'Переключить камеру',
            onPressed: widget.allCameras.length < 2
                ? null
                : () => unawaited(_live.switchCamera()),
            icon: const Icon(Icons.cameraswitch),
          ),
          IconButton(
            tooltip: 'Режим фото',
            onPressed: _backToPhotoScreen,
            icon: const Icon(Icons.photo_camera_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final controller = _live.cameraController;
                if (controller == null || !controller.value.isInitialized) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(
                      controller,
                      child: CustomPaint(
                        painter: LiveGlassesPainter(
                          faces: _live.faces,
                          glassesImage: _glassesImage,
                          poseEstimator: _poseEstimator,
                          bufferImageSize: _live.imageSize,
                          inputImageRotation: _live.rotation,
                          mirrorPreviewHorizontally: _mirrorPreviewHorizontally,
                        ),
                      ),
                    ),
                    if (showNoFaceHint)
                      const Positioned(
                        left: 0,
                        right: 0,
                        top: 24,
                        child: IgnorePointer(
                          child: Center(
                            child: Chip(
                              label: Text('Лицо не найдено — встаньте в кадр'),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              _live.faces.isEmpty
                  ? 'Ожидание лица в кадре…'
                  : 'Найдено лиц: ${_live.faces.length}. Выберите оправу ниже.',
            ),
          ),
          GlassesPickerStrip(
            glassesAssets: _glassesAssets,
            selectedGlassesPath: _selectedGlasses,
            onSelectGlasses: _selectGlasses,
          ),
        ],
      ),
    );
  }
}

/// Рисует PNG-очки поверх превью, переводя буферные координаты ML Kit в пиксели виджета.
class LiveGlassesPainter extends CustomPainter {
  LiveGlassesPainter({
    required this.faces,
    required this.glassesImage,
    required this.poseEstimator,
    required this.bufferImageSize,
    required this.inputImageRotation,
    required this.mirrorPreviewHorizontally,
  });

  final List<Face> faces;
  final ui.Image? glassesImage;
  final FacePoseEstimator poseEstimator;
  final Size bufferImageSize;
  final InputImageRotation inputImageRotation;
  final bool mirrorPreviewHorizontally;

  @override
  void paint(Canvas canvas, Size size) {
    final g = glassesImage;
    if (g == null ||
        faces.isEmpty ||
        bufferImageSize.width <= 0 ||
        bufferImageSize.height <= 0) {
      return;
    }

    final bufToPrev = FaceCoordinateMapper.bufferToPreviewMatrix4(
      bufferSize: bufferImageSize,
      rotation: inputImageRotation,
      previewSize: size,
      mirrorPreviewHorizontally: mirrorPreviewHorizontally,
    );

    for (final face in faces) {
      final layout = Glasses2DLayout.compute(
        face,
        poseEstimator,
        assetPixelWidth: g.width,
        assetPixelHeight: g.height,
      );
      if (!layout.isValid) continue;

      final glassesLocal = Matrix4.identity()
        ..translateByDouble(layout.centerX, layout.centerY, 0, 1)
        ..rotateZ(layout.rollRadians)
        ..translateByDouble(-layout.width / 2, -layout.height / 2, 0, 1);

      final full = bufToPrev * glassesLocal;

      final srcRect = Rect.fromLTWH(
        0,
        0,
        g.width.toDouble(),
        g.height.toDouble(),
      );
      final dstRect = Rect.fromLTWH(0, 0, layout.width, layout.height);

      canvas.save();
      canvas.transform(full.storage);
      canvas.drawImageRect(g, srcRect, dstRect, Paint());
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant LiveGlassesPainter oldDelegate) {
    return oldDelegate.faces != faces ||
        oldDelegate.glassesImage != glassesImage ||
        oldDelegate.poseEstimator != poseEstimator ||
        oldDelegate.bufferImageSize != bufferImageSize ||
        oldDelegate.inputImageRotation != inputImageRotation ||
        oldDelegate.mirrorPreviewHorizontally != mirrorPreviewHorizontally;
  }
}
