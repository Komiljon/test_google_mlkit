import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'arcore_face_controller.dart';
import 'arcore_glasses_calibration.dart';

/// viewType, зарегистрированный в [MainActivity] на Android.
const String kArCoreFaceViewType = 'com.alamat.test_google_mlkit/arcore_face_view';

/// Встраивает нативный `ARSceneView` (TextureSurface) через AndroidView.
///
/// На iOS/web — заглушка: ARCore в этой задаче не портируем.
class ArCoreFaceView extends StatefulWidget {
  const ArCoreFaceView({
    super.key,
    this.creationParams,
    this.onControllerCreated,
  });

  /// Начальный GLB и калибровка, чтобы первый кадр не ждал MethodChannel.
  final Map<String, Object>? creationParams;

  final ValueChanged<ArCoreFaceController>? onControllerCreated;

  @override
  State<ArCoreFaceView> createState() => _ArCoreFaceViewState();
}

class _ArCoreFaceViewState extends State<ArCoreFaceView> {
  ArCoreFaceController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const ColoredBox(
        color: Colors.black87,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'ARCore-примерка доступна только на Android '
              'с Google Play Services for AR.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      );
    }

    return AndroidView(
      viewType: kArCoreFaceViewType,
      layoutDirection: TextDirection.ltr,
      creationParams:
          widget.creationParams ?? ArCoreGlassesCalibration.toCreationParams(),
      creationParamsCodec: const StandardMessageCodec(),
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
      onPlatformViewCreated: (int viewId) {
        _controller?.dispose();
        final controller = ArCoreFaceController(viewId);
        _controller = controller;
        widget.onControllerCreated?.call(controller);
      },
    );
  }
}
