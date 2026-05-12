import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector4;

/// Маппинг координат ML Kit / буфера [CameraImage] в координаты виджета превью.
///
/// ML Kit возвращает [Face] в системе координат **буфера** (ширина/высота
/// кадра с камеры). Виджет [CameraPreview] показывает тот же кадр с
/// [BoxFit.cover] внутри прямоугольника [previewSize]. Здесь:
/// 1) поворот буфера в «вертикальную» плоскость отображения по [rotation]
///    (как в [InputImageMetadata.rotation] для Android);
/// 2) масштаб + обрезка как у [BoxFit.cover];
/// 3) при [mirrorPreviewHorizontally] — отражение по X (фронталка на Android,
///    где превью зеркалится, а координаты ML — нет).
///
/// Итоговое преобразование **аффинное** (линейное + перенос), поэтому для
/// [Canvas.transform] достаточно построить [Matrix4] по трём опорным точкам.
abstract final class FaceCoordinateMapper {
  /// Размер «выровненного» кадра: при 90°/270° меняются местами ширина и высота.
  static Size uprightImageSize(Size bufferSize, InputImageRotation rotation) {
    switch (rotation) {
      case InputImageRotation.rotation0deg:
      case InputImageRotation.rotation180deg:
        return bufferSize;
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return Size(bufferSize.height, bufferSize.width);
    }
  }

  /// Перевод точки из координат буфера в координаты превью (пиксели виджета).
  static Offset bufferToPreview({
    required Offset pointInBuffer,
    required Size bufferSize,
    required InputImageRotation rotation,
    required Size previewSize,
    required bool mirrorPreviewHorizontally,
  }) {
    final upright = _bufferPointToUpright(pointInBuffer, bufferSize, rotation);
    final uprightSz = uprightImageSize(bufferSize, rotation);
    return _coverThenMirror(
      upright,
      uprightSz,
      previewSize,
      mirrorPreviewHorizontally,
    );
  }

  /// Аффинная матрица 4×4 для [Canvas.transform]: буфер → превью.
  static Matrix4 bufferToPreviewMatrix4({
    required Size bufferSize,
    required InputImageRotation rotation,
    required Size previewSize,
    required bool mirrorPreviewHorizontally,
  }) {
    final p00 = bufferToPreview(
      pointInBuffer: Offset.zero,
      bufferSize: bufferSize,
      rotation: rotation,
      previewSize: previewSize,
      mirrorPreviewHorizontally: mirrorPreviewHorizontally,
    );
    final p10 = bufferToPreview(
      pointInBuffer: const Offset(1, 0),
      bufferSize: bufferSize,
      rotation: rotation,
      previewSize: previewSize,
      mirrorPreviewHorizontally: mirrorPreviewHorizontally,
    );
    final p01 = bufferToPreview(
      pointInBuffer: const Offset(0, 1),
      bufferSize: bufferSize,
      rotation: rotation,
      previewSize: previewSize,
      mirrorPreviewHorizontally: mirrorPreviewHorizontally,
    );

    final ax = p10.dx - p00.dx;
    final bx = p01.dx - p00.dx;
    final ay = p10.dy - p00.dy;
    final by = p01.dy - p00.dy;

    // Column-major Matrix4: столбцы — образы базисных векторов + перенос.
    return Matrix4.columns(
      Vector4(ax, ay, 0, 0),
      Vector4(bx, by, 0, 0),
      Vector4(0, 0, 1, 0),
      Vector4(p00.dx, p00.dy, 0, 1),
    );
  }

  /// Поворот точки из системы буфера в ось «как на экране» до масштабирования cover.
  ///
  /// Согласовано с типичными примерами ML Kit: 90° — переход к портретной
  /// ориентации при ландшафтном NV21-буфере.
  static Offset _bufferPointToUpright(Offset p, Size s, InputImageRotation r) {
    final x = p.dx;
    final y = p.dy;
    final w = s.width;
    final h = s.height;
    switch (r) {
      case InputImageRotation.rotation0deg:
        return Offset(x, y);
      case InputImageRotation.rotation90deg:
        return Offset(h - y, x);
      case InputImageRotation.rotation180deg:
        return Offset(w - x, h - y);
      case InputImageRotation.rotation270deg:
        return Offset(y, w - x);
    }
  }

  static Offset _coverThenMirror(
    Offset uprightPoint,
    Size uprightSize,
    Size previewSize,
    bool mirrorX,
  ) {
    final scale = math.max(
      previewSize.width / uprightSize.width,
      previewSize.height / uprightSize.height,
    );
    final dx = (previewSize.width - uprightSize.width * scale) / 2;
    final dy = (previewSize.height - uprightSize.height * scale) / 2;
    var x = uprightPoint.dx * scale + dx;
    final y = uprightPoint.dy * scale + dy;
    if (mirrorX) {
      x = previewSize.width - x;
    }
    return Offset(x, y);
  }
}
