/// Единые константы калибровки для примерки очков (3D и при необходимости 2D).
///
/// Менять посадку на реальных устройствах/фото можно здесь, не трогая формулы
/// в `FacePoseEstimator` и `Glasses3DOverlay`.
library;

/// Параметры оценки позы лица из landmarks ML Kit.
abstract final class FacePoseCalibration {
  /// Базовое межглазное расстояние в пикселях при scale = 1.
  static const double baselineEyeDistance = 110.0;

  /// Смещение якоря от смешения глаз + нос (доли ширины/высоты bounding box лица).
  /// По Y: отрицательное значение поднимает якорь к линии глаз.
  static const double centerOffsetXFactor = 0.0;
  static const double centerOffsetYFactor = -0.02;

  /// Доля вклада точки под носом `FaceLandmarkType.noseBase` в смешении с центром между глазами.
  /// Слишком большое значение опускает якорь к носу (очки оказываются ниже линии глаз).
  /// Мост очков корректнее ловить малым весом (0.03–0.08).
  static const double noseBaseBlendWeight = 0.07;

  /// Минимальный и максимальный масштаб модели (защита от выбросов детектора).
  static const double minScale = 0.45;
  static const double maxScale = 2.8;
}

/// Параметры отображения GLB-слоя поверх статичной фотографии.
abstract final class Glasses3DOverlayCalibration {
  /// Ширина контейнера WebView = межзрачковое расстояние (px) × этот множитель.
  /// Аналог коэффициента ~2.3 в 2D-рисовании PNG; подбирается под ширину оправы в GLB.
  static const double overlayWidthPerEyeDistance = 2.25;

  /// Соотношение высоты к ширине области оверлея (под пропорции превью очков в model-viewer).
  static const double modelAspectRatio = 0.55;

  /// Радиус орбиты камеры model-viewer (процент от bounding sphere).
  /// Меньше значение — камера ближе к модели, очки **крупнее** внутри WebView (при «крошечных» линзах уменьшайте).
  static const double cameraRadius = 60;

  /// Насколько сильно голова меняет горизонтальный угол камеры при заданном yaw.
  static const double yawInfluenceDegrees = 32;

  /// Насколько сильно pitch влияет на вертикальный угол камеры.
  static const double pitchInfluenceDegrees = 24;
}

/// Путь к 3D-ассету очков в `pubspec.yaml`.
abstract final class GlassesAssetPaths {
  static const String sunglassesGlb = 'assets/sunglasses.glb';
  static const String sunglassesLensesGlb = 'assets/sunglasses_lenses.glb';
}
