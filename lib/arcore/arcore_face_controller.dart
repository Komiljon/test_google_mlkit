import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Состояние установки/совместимости Google Play Services for AR.
enum ArCoreAvailability {
  checking,
  installRequested,
  ready,
  unsupported,
}

/// Жизненный цикл нативной AR-сессии (не путать с tracking лица).
enum ArCoreSessionPhase {
  starting,
  running,
  paused,
  failed,
}

/// Есть ли TRACKING у единственного лица фронтальной камеры.
enum ArCoreTrackingPhase {
  searching,
  tracking,
  lost,
}

enum ArCoreModelPhase {
  loading,
  ready,
  failed,
}

/// Снимок каналов: availability + session + tracking + model.
///
/// Pose-матрицы лица сюда не входят — они остаются на native renderer.
@immutable
class ArCoreFaceSnapshot {
  const ArCoreFaceSnapshot({
    required this.availability,
    required this.session,
    this.sessionMessage,
    required this.tracking,
    required this.model,
    this.modelMessage,
  });

  final ArCoreAvailability availability;
  final ArCoreSessionPhase session;
  final String? sessionMessage;
  final ArCoreTrackingPhase tracking;
  final ArCoreModelPhase model;
  final String? modelMessage;

  static const initial = ArCoreFaceSnapshot(
    availability: ArCoreAvailability.checking,
    session: ArCoreSessionPhase.starting,
    tracking: ArCoreTrackingPhase.searching,
    model: ArCoreModelPhase.loading,
  );

  ArCoreFaceSnapshot copyWith({
    ArCoreAvailability? availability,
    ArCoreSessionPhase? session,
    String? sessionMessage,
    bool clearSessionMessage = false,
    ArCoreTrackingPhase? tracking,
    ArCoreModelPhase? model,
    String? modelMessage,
    bool clearModelMessage = false,
  }) {
    return ArCoreFaceSnapshot(
      availability: availability ?? this.availability,
      session: session ?? this.session,
      sessionMessage: clearSessionMessage
          ? null
          : (sessionMessage ?? this.sessionMessage),
      tracking: tracking ?? this.tracking,
      model: model ?? this.model,
      modelMessage: clearModelMessage ? null : (modelMessage ?? this.modelMessage),
    );
  }
}

/// Per-view MethodChannel + EventChannel после `onPlatformViewCreated`.
class ArCoreFaceController {
  ArCoreFaceController(this.viewId)
    : _method = MethodChannel(
        'com.alamat.test_google_mlkit/arcore_face/method_$viewId',
      ),
      _events = EventChannel(
        'com.alamat.test_google_mlkit/arcore_face/events_$viewId',
      ) {
    _subscription = _events.receiveBroadcastStream().listen(
      _onEvent,
      onError: (Object error, StackTrace stack) {
        debugPrint('ArCoreFaceController events: $error\n$stack');
      },
    );
    unawaited(_pullState());
  }

  final int viewId;
  final MethodChannel _method;
  final EventChannel _events;
  StreamSubscription<dynamic>? _subscription;

  final ValueNotifier<ArCoreFaceSnapshot> snapshot = ValueNotifier(
    ArCoreFaceSnapshot.initial,
  );

  Future<void> setModelAsset(String assetKey) {
    return _method.invokeMethod<void>('setModelAsset', <String, Object>{
      'assetKey': assetKey,
    });
  }

  Future<void> setCalibration(Map<String, Object> params) {
    return _method.invokeMethod<void>('setCalibration', params);
  }

  Future<void> retrySession() {
    return _method.invokeMethod<void>('retrySession');
  }

  Future<void> _pullState() async {
    try {
      final raw = await _method.invokeMapMethod<String, dynamic>('getState');
      if (raw == null) {
        return;
      }
      for (final entry in raw.entries) {
        final event = entry.value;
        if (event is Map) {
          _applyEvent(Map<Object?, Object?>.from(event));
        }
      }
    } on PlatformException catch (e, st) {
      debugPrint('ArCoreFaceController.getState: $e\n$st');
    }
  }

  void _onEvent(dynamic event) {
    if (event is Map) {
      _applyEvent(Map<Object?, Object?>.from(event));
    }
  }

  void _applyEvent(Map<Object?, Object?> event) {
    final type = event['type'] as String?;
    final state = event['state'] as String?;
    if (type == null || state == null) {
      return;
    }
    final message = event['message'] as String?;
    final current = snapshot.value;
    switch (type) {
      case 'availability':
        snapshot.value = current.copyWith(
          availability: _availability(state),
        );
      case 'session':
        snapshot.value = current.copyWith(
          session: _session(state),
          sessionMessage: message,
          clearSessionMessage: message == null,
        );
      case 'tracking':
        snapshot.value = current.copyWith(tracking: _tracking(state));
      case 'model':
        snapshot.value = current.copyWith(
          model: _model(state),
          modelMessage: message,
          clearModelMessage: message == null,
        );
    }
  }

  static ArCoreAvailability _availability(String state) {
    return switch (state) {
      'installRequested' => ArCoreAvailability.installRequested,
      'ready' => ArCoreAvailability.ready,
      'unsupported' => ArCoreAvailability.unsupported,
      _ => ArCoreAvailability.checking,
    };
  }

  static ArCoreSessionPhase _session(String state) {
    return switch (state) {
      'running' => ArCoreSessionPhase.running,
      'paused' => ArCoreSessionPhase.paused,
      'failed' => ArCoreSessionPhase.failed,
      _ => ArCoreSessionPhase.starting,
    };
  }

  static ArCoreTrackingPhase _tracking(String state) {
    return switch (state) {
      'tracking' => ArCoreTrackingPhase.tracking,
      'lost' => ArCoreTrackingPhase.lost,
      _ => ArCoreTrackingPhase.searching,
    };
  }

  static ArCoreModelPhase _model(String state) {
    return switch (state) {
      'ready' => ArCoreModelPhase.ready,
      'failed' => ArCoreModelPhase.failed,
      _ => ArCoreModelPhase.loading,
    };
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    snapshot.dispose();
  }
}
