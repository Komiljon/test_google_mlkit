import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

import '../face_tracking/glasses_try_on_calibration.dart';
import '../face_tracking/face_pose_data.dart';
import '../face_tracking/face_pose_estimator.dart';
import '../glasses_3d/glasses_3d_overlay.dart';
import '../input_image/mlkit_image_prepare.dart';
import '../painting/decoded_image_painter.dart';

/// Отдельный экран для 3D-режима примерки очков из GLB.
///
/// Экран не заменяет 2D-реализацию, а живет отдельно, чтобы:
/// - безопасно экспериментировать с 3D-посадкой;
/// - быстро сравнивать качество трекинга 2D и 3D;
/// - не смешивать разную рендер-архитектуру в одном painter-коде.
class GlassesTryOn3DScreen extends StatefulWidget {
  final CameraDescription camera;

  const GlassesTryOn3DScreen({super.key, required this.camera});

  @override
  State<GlassesTryOn3DScreen> createState() => _GlassesTryOn3DScreenState();
}

class _GlassesTryOn3DScreenState extends State<GlassesTryOn3DScreen> {
  late FaceDetector _faceDetector;
  late final ImagePicker _picker;
  late final FacePoseEstimator _poseEstimator;

  ui.Image? _image;
  Size? _imageSize;
  FacePoseData _pose = FacePoseData.invalid;

  /// Синхронно с 2D-экраном: bake EXIF + ML Kit.
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _picker = ImagePicker();
    _poseEstimator = FacePoseEstimator();
    // Для 3D-посадки лучше `accurate`: стабильнее landmarks (в т.ч. переносица).
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: true,
        enableClassification: false,
        enableContours: false,
      ),
    );
  }

  @override
  void dispose() {
    _image?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _pickAndAnalyzeImage({required bool isFromCamera}) async {
    setState(() {
      _isScanning = true;
    });

    PreparedMlKitImage? prepared;
    try {
      final imageXFile = await _picker.pickImage(
        source: isFromCamera ? ImageSource.camera : ImageSource.gallery,
      );
      if (imageXFile == null) {
        return;
      }

      final rawBytes = await imageXFile.readAsBytes();
      prepared = await prepareImageBytesForMlKit(rawBytes, suffix: '3d');

      final inputImage = inputImageFromPreparedFile(prepared.tempJpegFile);
      final faces = await _faceDetector.processImage(inputImage);
      final decodedImage = await decodePreparedBytesToUiImage(
        prepared.bytesForDecodeAndMlKit,
      );

      final pose = _poseEstimator.estimatePrimaryFace(faces);

      if (!mounted) {
        return;
      }
      setState(() {
        _image?.dispose();
        _image = decodedImage;
        _imageSize = Size(
          decodedImage.width.toDouble(),
          decodedImage.height.toDouble(),
        );
        _pose = pose;
      });
    } catch (e, st) {
      debugPrint('3D pick/analyze: $e\n$st');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('3D Try-On (GLB)')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: _image == null
                      ? const Text(
                          'Выберите изображение для 3D-режима',
                          style: TextStyle(fontSize: 18),
                        )
                      : FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: _imageSize!.width,
                            height: _imageSize!.height,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: DecodedImagePainter(_image!),
                                  ),
                                ),
                                Glasses3DOverlay(
                                  pose: _pose,
                                  modelAssetPath:
                                      GlassesAssetPaths.sunglassesLensesGlb,
                                ),
                              ],
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
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              _pose.isValid
                  ? '3D модель привязана к позе лица (yaw/pitch/roll + scale).'
                  : 'Лицо не найдено или landmarks недостаточны для 3D-привязки.',
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
                      : () => _pickAndAnalyzeImage(isFromCamera: true),
                  child: const Text('Камера'),
                ),
                ElevatedButton(
                  onPressed: _isScanning
                      ? null
                      : () => _pickAndAnalyzeImage(isFromCamera: false),
                  child: const Text('Галерея'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
