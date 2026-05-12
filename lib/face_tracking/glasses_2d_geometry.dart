import 'dart:math' as math;

import 'glasses_try_on_calibration.dart';

/// Чистая геометрия для примерки 2D-очков — без зависимости от [Face] ML Kit.
///
/// Используется в [Glasses2DLayout] и в unit-тестах с фиктивными числами.

/// Устойчивый горизонтальный размах лица в пикселях: предпочитаем уши, затем скулы, затем бокс.
double facialBreadthPx({
  required double boxWidthPx,
  double? earSpanPx,
  double? cheekSpanPx,
}) {
  final raw = earSpanPx ?? cheekSpanPx ?? boxWidthPx;
  return math.max(
    raw,
    boxWidthPx * Glasses2DCalibration.facialBreadthMinToBoxFactor,
  );
}

/// Длина отрезка между двумя точками лэндмарков в пикселях.
double segmentLengthPx(double x1, double y1, double x2, double y2) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  return math.sqrt(dx * dx + dy * dy);
}

/// Итоговая ширина нарисованной оправы: max(оценка по IPD, оценка по размаху лица) с clamp.
double glassesWidthPx({
  required double eyeDistancePx,
  required double facialBreadthPx,
  required double boxWidthPx,
}) {
  final fromIpd = eyeDistancePx * Glasses2DCalibration.eyeDistanceWidthFactor;
  final fromBreadth =
      facialBreadthPx * Glasses2DCalibration.frameWidthToFacialBreadth;
  var w = math.max(fromIpd, fromBreadth);
  final cap =
      math.max(boxWidthPx, facialBreadthPx) *
      Glasses2DCalibration.maxWidthOverBreadthFactor;
  w = w.clamp(eyeDistancePx * Glasses2DCalibration.minWidthToIpdFactor, cap);
  return w;
}
