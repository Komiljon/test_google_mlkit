import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'face_pose_estimator.dart';
import 'glasses_2d_geometry.dart';
import 'glasses_try_on_calibration.dart';

/// Рассчитанный прямоугольник и поворот для отрисовки PNG-очков в системе координат [Image] / ML Kit.
class Glasses2DLayout {
  /// Горизонтальный центр оправы (пиксели).
  final double centerX;

  /// Вертикальный центр оправы (пиксели).
  final double centerY;

  /// Ширина и высота нарисованной текстуры очков.
  final double width;
  final double height;

  /// Roll = наклон линии глаз, радианы (тот же знак, что в [FacePoseData.roll]).
  final double rollRadians;

  final bool isValid;

  const Glasses2DLayout({
    required this.centerX,
    required this.centerY,
    required this.width,
    required this.height,
    required this.rollRadians,
    required this.isValid,
  });

  /// Недопустимая раскладка (нет глаз, нулевая ширина ассета и т.д.).
  static const Glasses2DLayout invalid = Glasses2DLayout(
    centerX: 0,
    centerY: 0,
    width: 0,
    height: 0,
    rollRadians: 0,
    isValid: false,
  );

  /// Собирает параметры 2D-оверлея: ширина по ушам/скулам + IPD из [FacePoseEstimator], якорь как в 3D.
  ///
  /// [assetPixelWidth]/[assetPixelHeight] — размер PNG очков; по ним сохраняется aspect ratio.
  static Glasses2DLayout compute(
    Face face,
    FacePoseEstimator estimator, {
    required int assetPixelWidth,
    required int assetPixelHeight,
  }) {
    if (assetPixelWidth <= 0 || assetPixelHeight <= 0) {
      return Glasses2DLayout.invalid;
    }

    final pose = estimator.estimateFacePose(face);
    if (!pose.isValid) {
      return Glasses2DLayout.invalid;
    }

    final leftEar = face.landmarks[FaceLandmarkType.leftEar]?.position;
    final rightEar = face.landmarks[FaceLandmarkType.rightEar]?.position;
    final leftCheek = face.landmarks[FaceLandmarkType.leftCheek]?.position;
    final rightCheek = face.landmarks[FaceLandmarkType.rightCheek]?.position;

    double? earSpanPx;
    if (leftEar != null && rightEar != null) {
      earSpanPx = segmentLengthPx(
        leftEar.x.toDouble(),
        leftEar.y.toDouble(),
        rightEar.x.toDouble(),
        rightEar.y.toDouble(),
      );
    }

    double? cheekSpanPx;
    if (leftCheek != null && rightCheek != null) {
      cheekSpanPx = segmentLengthPx(
        leftCheek.x.toDouble(),
        leftCheek.y.toDouble(),
        rightCheek.x.toDouble(),
        rightCheek.y.toDouble(),
      );
    }

    final boxW = face.boundingBox.width;
    final breadth = facialBreadthPx(
      boxWidthPx: boxW,
      earSpanPx: earSpanPx,
      cheekSpanPx: cheekSpanPx,
    );

    final w = glassesWidthPx(
      eyeDistancePx: pose.eyeDistancePx,
      facialBreadthPx: breadth,
      boxWidthPx: boxW,
    );

    final aspect = assetPixelHeight / assetPixelWidth;
    final h = w * aspect;

    // Якорь совпадает с 3D ([FacePoseData.center]) плюс тонкая подстройка под PNG-мост.
    final cx = pose.center.dx;
    final cy = pose.center.dy + h * Glasses2DCalibration.verticalOffsetFactor;

    return Glasses2DLayout(
      centerX: cx,
      centerY: cy,
      width: w,
      height: h,
      rollRadians: pose.roll,
      isValid: true,
    );
  }
}
