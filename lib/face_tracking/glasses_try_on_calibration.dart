/// Единые константы калибровки для примерки очков (2D и 3D).
///
/// Менять посадку на реальных устройствах/фото можно здесь, не трогая формулы
/// в `FacePoseEstimator`, `Glasses2DLayout` и `Glasses3DOverlay`.
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

/// Множители и пороги для PNG-оправы в 2D (`Glasses2DLayout`).
///
/// Согласованы по смыслу с [Glasses3DOverlayCalibration.overlayWidthPerEyeDistance], чтобы
/// подгонка по одному только IPD не расходилась драматично между 2D и 3D.
abstract final class Glasses2DCalibration {
  /// Множитель IPD → ширина нарисованной оправы по X (пиксели изображения).
  static const double eyeDistanceWidthFactor = 2.38;

  /// Доля ширины лица (размах уши/скулы): во сколько раз оправа уже «висок-висок».
  static const double frameWidthToFacialBreadth = 0.93;

  /// Нижняя граница clamp ширины как доля межзрачкового расстояния.
  static const double minWidthToIpdFactor = 2.0;

  /// Верхняя граница: `max(boxWidth, facialBreadth) * maxWidthOverBreadthFactor`.
  static const double maxWidthOverBreadthFactor = 1.04;

  /// Минимальный множитель: `facialBreadth` не уже `boxWidth *` этого значения.
  static const double facialBreadthMinToBoxFactor = 0.94;

  /// Дополнительный сдвиг якоря по Y после центра из `FacePoseEstimator` (доля высоты PNG-оправы).
  /// Положительное — ниже по картинке (к переносице), отрицательное — к линии глаз.
  static const double verticalOffsetFactor = 0.028;
}

/// Параметры отображения GLB-слоя поверх статичной фотографии.
abstract final class Glasses3DOverlayCalibration {
  /// Ширина контейнера WebView = межзрачковое расстояние (px) × этот множитель.
  ///
  /// Для полного `sunglasses.glb` нужен запас по бокам: model-viewer кадрирует всю
  /// bounding sphere модели, включая дужки, поэтому фронтальная оправа визуально
  /// становится чуть уже, чем PNG с одними линзами/рамкой.
  static const double overlayWidthPerEyeDistance = 2.42;

  /// Альтернативная оценка ширины: насколько оправа должна занимать ширину лица.
  ///
  /// Этот коэффициент включается, когда ML Kit дал уши/скулы. Он не заменяет IPD,
  /// а дополняет его, чтобы очки не были одинаковыми на узком и широком лице.
  static const double frameWidthToFacialBreadth = 0.98;

  /// Нижняя граница ширины 3D-оверлея как доля межзрачкового расстояния.
  static const double minWidthToIpdFactor = 2.05;

  /// Верхняя граница ширины как доля оцененной ширины лица.
  static const double maxWidthOverBreadthFactor = 1.06;

  /// Соотношение высоты к ширине области оверлея.
  ///
  /// Полная GLB-модель почти квадратная по bounds; если оставить низкий viewport,
  /// model-viewer уменьшает очки, чтобы вместить модель по высоте. Более высокий
  /// контейнер даёт оправе крупнее лечь на линию глаз и не режет верх/низ.
  static const double modelAspectRatio = 0.72;

  /// Дополнительный вертикальный сдвиг контейнера как доля его высоты.
  ///
  /// Положительное значение опускает модель к переносице. Небольшой сдвиг нужен,
  /// потому что якорь позы строится около центра глаз, а центр GLB включает
  /// толщину оправы и дужки, а не только мост между линзами.
  static const double verticalOffsetFactor = 0.025;

  /// Дополнительный сдвиг вниз как доля расстояния от линии глаз до основания носа.
  ///
  /// Это помогает посадить мост очков на переносицу, а не просто в геометрический
  /// центр между глазами. Если landmark носа не найден, вклад равен нулю.
  static const double noseBaseVerticalOffsetFactor = 0.08;

  /// Радиус орбиты камеры model-viewer (процент от bounding sphere).
  ///
  /// Меньше значение — камера ближе к модели, очки крупнее внутри WebView. Для
  /// полной модели оставляем умеренно близкую камеру: дужки видны, но фронтальная
  /// часть не превращается в мелкий объект внутри WebView.
  static const double cameraRadius = 48;

  /// Цель камеры model-viewer в локальных координатах GLB.
  ///
  /// Центр модели оставляем в нуле: смещение самого оверлея выше уже делает
  /// посадку относительно лица, а target лучше не трогать без пересчёта bounds.
  static const double cameraTargetX = 0;
  static const double cameraTargetY = 0;
  static const double cameraTargetZ = 0;

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
