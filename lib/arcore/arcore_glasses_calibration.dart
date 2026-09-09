/// Калибровка GLB для нативного ARCore Augmented Faces.
///
/// Отдельно от [FacePoseCalibration] / ML Kit: там пиксели фото, здесь метры
/// и локальный pose лица. Если оправа «уехала» по осям — правьте константы
/// или слайдеры на экране; большой yaw/roll модели лучше чинить в Blender.
library;

import '../face_tracking/glasses_try_on_calibration.dart';

/// Якорь оправы относительно mesh лица ARCore.
enum ArCoreFaceAnchor {
  /// `AugmentedFace.centerPose` — за переносицей, стабильнее для широкой оправы.
  center,

  /// `RegionType.NOSE_TIP` — если origin GLB сидит на кончике носа.
  nose,
}

/// Стартовые метры/градусы для [GlassesAssetPaths.sunglassesGlb].
///
/// `centerPose` лежит *внутри* головы; +Z смотрит из лица к камере.
/// Небольшой +Y поднимает оправу к линии глаз, +Z выносит её на поверхность.
///
/// Значения offsetY/offsetZ подобраны под фактический AABB `sunglasses.glb`
/// (ширина 1.304 / высота 0.422 / глубина 1.080 в исходных единицах модели) —
/// см. план `arcore_glasses_fix`: авторский pivot GLB уже стоит на переносице,
/// поэтому `keepAuthoredPivot = true` и небольшой офсет вместо пересадки pivot.
abstract final class ArCoreGlassesCalibration {
  static const String defaultAssetKey = GlassesAssetPaths.sunglassesGlb;

  /// Нормализация `ModelNode(scaleToUnits)`: максимальный габарит ≈ 14 см.
  static const double widthMeters = 0.14;

  static const double offsetX = 0.0;
  static const double offsetY = 0.012;
  static const double offsetZ = 0.03;

  /// Эйлер в градусах, порядок SceneView (Rotation = градусы XYZ).
  static const double rotationX = 0.0;
  static const double rotationY = 0.0;
  static const double rotationZ = 0.0;

  static const ArCoreFaceAnchor anchor = ArCoreFaceAnchor.center;

  /// Оставить авторский pivot GLB (на переносице) вместо центра AABB модели.
  static const bool keepAuthoredPivot = true;

  /// Depth-occluder сетки лица. Выключен по умолчанию первой итерацией —
  /// у GLB два материала с alphaMode=BLEND (линзы/накладки), порядок отрисовки
  /// с occluder-сеткой без явного Filament priority нужно разбирать отдельно.
  static const bool occlusionEnabled = false;

  static Map<String, Object> toCreationParams({
    String assetKey = defaultAssetKey,
    double widthMeters = ArCoreGlassesCalibration.widthMeters,
    double offsetX = ArCoreGlassesCalibration.offsetX,
    double offsetY = ArCoreGlassesCalibration.offsetY,
    double offsetZ = ArCoreGlassesCalibration.offsetZ,
    double rotationX = ArCoreGlassesCalibration.rotationX,
    double rotationY = ArCoreGlassesCalibration.rotationY,
    double rotationZ = ArCoreGlassesCalibration.rotationZ,
    ArCoreFaceAnchor anchor = ArCoreGlassesCalibration.anchor,
    bool keepAuthoredPivot = ArCoreGlassesCalibration.keepAuthoredPivot,
    bool occlusionEnabled = ArCoreGlassesCalibration.occlusionEnabled,
  }) {
    return <String, Object>{
      'assetKey': assetKey,
      'widthMeters': widthMeters,
      'offsetX': offsetX,
      'offsetY': offsetY,
      'offsetZ': offsetZ,
      'rotationX': rotationX,
      'rotationY': rotationY,
      'rotationZ': rotationZ,
      'anchor': anchor.wireName,
      'keepAuthoredPivot': keepAuthoredPivot,
      'occlusionEnabled': occlusionEnabled,
    };
  }
}

extension ArCoreFaceAnchorWire on ArCoreFaceAnchor {
  String get wireName => switch (this) {
    ArCoreFaceAnchor.center => 'center',
    ArCoreFaceAnchor.nose => 'nose',
  };

  static ArCoreFaceAnchor fromWire(String? value) {
    return value == 'nose' ? ArCoreFaceAnchor.nose : ArCoreFaceAnchor.center;
  }
}
