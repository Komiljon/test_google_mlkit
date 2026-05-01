import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

import '../face_tracking/face_pose_data.dart';
import '../face_tracking/glasses_try_on_calibration.dart';

/// Виджет, который рисует 3D-модель очков поверх изображения.
///
/// Подход:
/// - размер/позиция контейнера задаются из 2D-позы;
/// - yaw/pitch прокидываются в камеру через `setCameraOrbit`;
/// - roll применяется 2D-поворотом контейнера, чтобы очки совпадали с наклоном головы.
class Glasses3DOverlay extends StatefulWidget {
  final FacePoseData pose;
  final String modelAssetPath;

  const Glasses3DOverlay({
    super.key,
    required this.pose,
    required this.modelAssetPath,
  });

  @override
  State<Glasses3DOverlay> createState() => _Glasses3DOverlayState();
}

class _Glasses3DOverlayState extends State<Glasses3DOverlay> {
  final Flutter3DController _controller = Flutter3DController();
  bool _isModelReady = false;

  @override
  void initState() {
    super.initState();
    _controller.onModelLoaded.addListener(_onModelLoadedChanged);
  }

  @override
  void didUpdateWidget(covariant Glasses3DOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isModelReady && widget.pose.isValid) {
      _applyCameraFromPose(widget.pose);
    }
  }

  @override
  void dispose() {
    _controller.onModelLoaded.removeListener(_onModelLoadedChanged);
    _controller.onModelLoaded.dispose();
    super.dispose();
  }

  void _onModelLoadedChanged() {
    if (!_controller.onModelLoaded.value) return;
    _isModelReady = true;
    if (widget.pose.isValid) {
      _applyCameraFromPose(widget.pose);
    }
  }

  void _applyCameraFromPose(FacePoseData pose) {
    final yawDeg = _radToDeg(pose.yaw);
    final pitchDeg = _radToDeg(pose.pitch);

    // Базовая орбита model-viewer близка к "0deg 75deg 105%".
    // Подкручиваем ее углами головы, чтобы модель реагировала на поворот лица.
    final theta = yawDeg * Glasses3DOverlayCalibration.yawInfluenceDegrees / 45.0;
    final phi = (75 - (pitchDeg * Glasses3DOverlayCalibration.pitchInfluenceDegrees / 45.0)).clamp(15, 120).toDouble();
    _controller.setCameraOrbit(theta, phi, Glasses3DOverlayCalibration.cameraRadius);
    _controller.setCameraTarget(0, 0, 0);
  }

  double _radToDeg(double radians) => radians * 180 / math.pi;

  @override
  Widget build(BuildContext context) {
    if (!widget.pose.isValid) {
      return const SizedBox.shrink();
    }

    // Размер именно по межзрачковому расстоянию — так область WebView согласована с лицом,
    // без «второго» масштаба через baseline (он давал слишком мелкое превью модели).
    final modelWidth =
        widget.pose.eyeDistancePx * Glasses3DOverlayCalibration.overlayWidthPerEyeDistance;
    final modelHeight = modelWidth * Glasses3DOverlayCalibration.modelAspectRatio;
    final left = widget.pose.center.dx - (modelWidth / 2);
    final top = widget.pose.center.dy - (modelHeight / 2);

    return Positioned(
      left: left,
      top: top,
      width: modelWidth,
      height: modelHeight,
      child: IgnorePointer(
        // Оверлей должен следовать за лицом, а не перехватывать жесты.
        ignoring: true,
        child: Transform.rotate(
          angle: widget.pose.roll,
          child: Flutter3DViewer(
            src: widget.modelAssetPath,
            controller: _controller,
            enableTouch: false,
            activeGestureInterceptor: true,
            progressBarColor: Colors.transparent,
            onLoad: (_) {
              _isModelReady = true;
              _applyCameraFromPose(widget.pose);
            },
            onError: (error) {
              debugPrint('3D model load error: $error');
            },
          ),
        ),
      ),
    );
  }
}
