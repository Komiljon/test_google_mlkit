import 'dart:ui';

/// Контейнер с рассчитанной позой лица для 3D-оверлея.
///
/// Все значения привязаны к **исходным пикселям изображения** (та же система, что ML Kit).
/// - [center] — точка якоря для размещения оверлея очков (между глазами ± калибровка);
/// - [eyeDistancePx] — межзрачковое расстояние в пикселях (**главный** масштаб для размера очков в 3D-слое);
/// - [scale] — сохранено для совместимости и отладки (отношение [eyeDistancePx] к базовой калибровке);
/// - [yaw], [pitch], [roll] — углы в радианах.
class FacePoseData {
  final Offset center;

  /// Межзрачковое расстояние между центрами глаз по landmark, в пикселях картинки.
  final double eyeDistancePx;

  final double scale;
  final double yaw;
  final double pitch;
  final double roll;
  final bool isValid;

  const FacePoseData({
    required this.center,
    required this.eyeDistancePx,
    required this.scale,
    required this.yaw,
    required this.pitch,
    required this.roll,
    required this.isValid,
  });

  /// Пустое значение для случаев, когда поза не может быть построена.
  static const FacePoseData invalid = FacePoseData(
    center: Offset.zero,
    eyeDistancePx: 0,
    scale: 1,
    yaw: 0,
    pitch: 0,
    roll: 0,
    isValid: false,
  );
}
