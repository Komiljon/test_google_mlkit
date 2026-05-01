import 'dart:math' as math;
import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'face_pose_data.dart';
import 'glasses_try_on_calibration.dart';

/// Сервис преобразования landmarks/углов ML Kit в набор параметров для 3D-модели очков.
///
/// Вся калибровка задаётся в `glasses_try_on_calibration.dart`;
/// здесь только геометрия сборки позы из landmarks и euler-углов головы ML Kit.
class FacePoseEstimator {

  /// Возвращает позу только по первому лицу.
  /// Для MVP достаточно одного лица, чтобы не усложнять UI/UX.
  FacePoseData estimatePrimaryFace(List<Face> faces) {
    if (faces.isEmpty) {
      return FacePoseData.invalid;
    }
    return estimateFacePose(faces.first);
  }

  /// Оценивает позицию, масштаб и углы поворота для одного лица.
  FacePoseData estimateFacePose(Face face) {
    final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;
    if (leftEye == null || rightEye == null) {
      return FacePoseData.invalid;
    }

    final leftMostEye = leftEye.x <= rightEye.x ? leftEye : rightEye;
    final rightMostEye = leftEye.x <= rightEye.x ? rightEye : leftEye;

    final dx = rightMostEye.x - leftMostEye.x;
    final dy = rightMostEye.y - leftMostEye.y;
    final eyeDistance = math.sqrt(dx * dx + dy * dy);
    if (eyeDistance <= 0) {
      return FacePoseData.invalid;
    }

    // Центр между глазами как основной якорь; при наличии `noseBase` слегка смещаем
    // в сторону переносицы — так мост очков лучше совпадает с реальной геометрией лица.
    final eyesCenter = Offset((leftMostEye.x + rightMostEye.x) / 2, (leftMostEye.y + rightMostEye.y) / 2);
    final noseBasePt = face.landmarks[FaceLandmarkType.noseBase]?.position;
    final weightedCenter = noseBasePt != null
        ? _blendTowardsNoseBridge(
            eyesCenter,
            Offset(noseBasePt.x.toDouble(), noseBasePt.y.toDouble()),
          )
        : eyesCenter;

    final box = face.boundingBox;
    final center = Offset(
      weightedCenter.dx + box.width * FacePoseCalibration.centerOffsetXFactor,
      weightedCenter.dy + box.height * FacePoseCalibration.centerOffsetYFactor,
    );

    // Масштабируем модель от расстояния между глазами.
    final rawScale = eyeDistance / FacePoseCalibration.baselineEyeDistance;
    final scale = rawScale.clamp(FacePoseCalibration.minScale, FacePoseCalibration.maxScale);

    // Roll в радианах можно стабильно получить по линии глаз.
    final roll = math.atan2(dy, dx);

    // ML Kit отдает headEulerAngle* в градусах, переводим в радианы.
    // Если angle null, используем 0 как безопасный fallback.
    final yaw = _degToRad(face.headEulerAngleY ?? 0.0);
    final pitch = _degToRad(face.headEulerAngleX ?? 0.0);

    return FacePoseData(
      center: center,
      eyeDistancePx: eyeDistance,
      scale: scale,
      yaw: yaw,
      pitch: pitch,
      roll: roll,
      isValid: true,
    );
  }

  double _degToRad(double degrees) => degrees * (math.pi / 180.0);

  /// Смешивает центр между глазами и точку переносицы для более стабильной посадки на носу.
  Offset _blendTowardsNoseBridge(Offset eyesMid, Offset noseBridge) {
    final w = FacePoseCalibration.noseBaseBlendWeight.clamp(0.0, 1.0);
    return Offset(
      eyesMid.dx * (1 - w) + noseBridge.dx * w,
      eyesMid.dy * (1 - w) + noseBridge.dy * w,
    );
  }
}
