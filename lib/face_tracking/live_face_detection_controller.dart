import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Контроллер живого потока: [CameraController] + [FaceDetector] + throttling.
///
/// Поток кадров (`startImageStream`) гоняется в ML Kit с ограничением частоты
/// (~10 FPS) и флагом [_isBusy], чтобы не копить очередь `processImage` на
/// слабых устройствах. Конвертация [CameraImage] → [InputImage] повторяет
/// рекомендации `google_mlkit_commons` (NV21/BGRA, один plane, rotation).
///
/// **Профилирование (perf-knobs):** при лагах уменьшите [resolutionPreset] до
/// [ResolutionPreset.low] или увеличьте [_minFrameInterval] (мс между запусками
/// распознавания), не трогая остальной код.
class LiveFaceDetectionController extends ChangeNotifier {
  LiveFaceDetectionController({
    required List<CameraDescription> cameras,
    this.resolutionPreset = ResolutionPreset.medium,
    Duration minFrameInterval = const Duration(milliseconds: 100),
  }) : _cameras = List<CameraDescription>.unmodifiable(cameras),
       _minFrameInterval = minFrameInterval;

  /// Доступные камеры (переключение передняя/задняя).
  final List<CameraDescription> _cameras;

  /// Разрешение превью и кадров для ML Kit (см. комментарий класса).
  final ResolutionPreset resolutionPreset;

  /// Минимальный интервал между **стартами** распознавания (throttle).
  final Duration _minFrameInterval;

  CameraController? _cameraController;

  /// Создаётся в [initialize]; до вызова может быть null (безопасный [dispose]).
  FaceDetector? _faceDetector;

  /// Последний список лиц из ML Kit (координаты в системе буфера кадра).
  List<Face> _faces = [];

  /// Размер последнего [CameraImage] (ширина/высота буфера).
  Size _imageSize = Size.zero;

  /// Rotation, переданный в [InputImageMetadata] для Android (на iOS тоже
  /// храним для маппинга оверлея в [FaceCoordinateMapper]).
  InputImageRotation _rotation = InputImageRotation.rotation0deg;

  bool _isBusy = false;
  DateTime? _lastProcessStartedAt;
  bool _disposed = false;
  int _cameraIndex = 0;

  /// Индекс текущей камеры в [_cameras].
  int get cameraIndex => _cameraIndex;

  CameraController? get cameraController => _cameraController;

  List<Face> get faces => _faces;

  Size get imageSize => _imageSize;

  InputImageRotation get rotation => _rotation;

  CameraDescription get currentCamera => _cameras[_cameraIndex];

  /// Выбирает стартовую камеру: предпочитаем фронтальную (примерка «селфи»).
  static int initialCameraIndex(List<CameraDescription> cameras) {
    final frontIdx = cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    return frontIdx >= 0 ? frontIdx : 0;
  }

  /// Создаёт детектор в режиме **fast** + трекинг — для видеопотока важнее FPS,
  /// чем максимальная точность landmarks (для снимков остаётся `accurate`).
  void _createDetector() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableLandmarks: true,
        enableTracking: true,
        enableClassification: false,
        enableContours: false,
        minFaceSize: 0.2,
      ),
    );
  }

  /// Инициализация выбранной камеры и запуск потока кадров.
  Future<void> initialize() async {
    if (_cameras.isEmpty) {
      throw StateError('LiveFaceDetectionController: список камер пуст.');
    }
    _createDetector();
    _cameraIndex = initialCameraIndex(_cameras);
    await _openCameraAt(_cameraIndex);
  }

  Future<void> _openCameraAt(int index) async {
    await stopImageStream();
    await _cameraController?.dispose();
    _cameraController = null;

    final desc = _cameras[index];
    final controller = CameraController(
      desc,
      resolutionPreset,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await controller.initialize();
    if (_disposed) {
      await controller.dispose();
      return;
    }

    _cameraController = controller;
    _cameraIndex = index;

    await controller.startImageStream(_onCameraImage);
    notifyListeners();
  }

  /// Переключение между передней и задней камерой (циклически по списку).
  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    final next = (_cameraIndex + 1) % _cameras.length;
    await _openCameraAt(next);
  }

  void _onCameraImage(CameraImage image) {
    if (_disposed) return;
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (_isBusy) return;

    final now = DateTime.now();
    if (_lastProcessStartedAt != null &&
        now.difference(_lastProcessStartedAt!) < _minFrameInterval) {
      return;
    }
    _lastProcessStartedAt = now;
    _isBusy = true;

    unawaited(_processFrame(image, controller));
  }

  Future<void> _processFrame(
    CameraImage image,
    CameraController controller,
  ) async {
    final detector = _faceDetector;
    if (detector == null) return;
    try {
      final input = _inputImageFromCameraImage(image, controller);
      if (input == null) return;

      final detected = await detector.processImage(input);
      if (_disposed) return;

      _faces = detected;
      _imageSize = Size(image.width.toDouble(), image.height.toDouble());
      _rotation = input.metadata!.rotation;

      notifyListeners();
    } catch (e, st) {
      debugPrint('LiveFaceDetectionController.processFrame: $e\n$st');
    } finally {
      _isBusy = false;
    }
  }

  /// Останавливает поток кадров (перед dispose или при уходе приложения в фон).
  Future<void> stopImageStream() async {
    final c = _cameraController;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isStreamingImages) {
      await c.stopImageStream();
    }
  }

  /// Пауза при inactive/paused: освобождаем камеру для других приложений.
  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      await stopImageStream();
    } else if (state == AppLifecycleState.resumed) {
      final c = _cameraController;
      if (c != null && c.value.isInitialized && !c.value.isStreamingImages) {
        await c.startImageStream(_onCameraImage);
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final c = _cameraController;
    _cameraController = null;
    if (c != null) {
      unawaited(_disposeCameraFully(c));
    }
    final detector = _faceDetector;
    _faceDetector = null;
    if (detector != null) {
      unawaited(detector.close());
    }
    super.dispose();
  }

  /// Асинхронная очистка камеры: [ChangeNotifier.dispose] не может быть async,
  /// поэтому гоняем `unawaited` из синхронного [dispose].
  Future<void> _disposeCameraFully(CameraController c) async {
    try {
      if (c.value.isInitialized && c.value.isStreamingImages) {
        await c.stopImageStream();
      }
    } catch (_) {}
    try {
      await c.dispose();
    } catch (_) {}
  }

  // --- InputImage из CameraImage (как в README google_mlkit_commons) ---

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  /// Собирает [InputImage] из одного кадра потока или возвращает null, если
  /// формат/плоскости не совпали с ожиданиями ML Kit.
  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    CameraController controller,
  ) {
    final camera = controller.description;

    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[controller.value.deviceOrientation];
      if (rotationCompensation == null) return null;

      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    rotation ??= InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    if (image.planes.isEmpty) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }
}
