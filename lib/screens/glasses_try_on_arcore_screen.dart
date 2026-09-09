import 'package:flutter/material.dart';

import '../arcore/arcore_face_controller.dart';
import '../arcore/arcore_face_view.dart';
import '../arcore/arcore_glasses_calibration.dart';

/// Живая примерка очков: лицо трекает ARCore Augmented Faces, GLB рисует SceneView.
///
/// ML Kit и пакет `camera` здесь не используются — они не делят камеру с ARCore.
/// Нужно физическое ARCore-устройство с фронтальной камерой (не эмулятор AVD).
class GlassesTryOnArCoreScreen extends StatefulWidget {
  const GlassesTryOnArCoreScreen({super.key});

  @override
  State<GlassesTryOnArCoreScreen> createState() =>
      _GlassesTryOnArCoreScreenState();
}

class _GlassesTryOnArCoreScreenState extends State<GlassesTryOnArCoreScreen> {
  ArCoreFaceController? _controller;
  late Map<String, Object> _params;
  bool _showCalibration = false;

  @override
  void initState() {
    super.initState();
    _params = ArCoreGlassesCalibration.toCreationParams();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ARCore примерка'),
        actions: [
          IconButton(
            tooltip: _showCalibration ? 'Скрыть калибровку' : 'Калибровка',
            onPressed: () {
              setState(() {
                _showCalibration = !_showCalibration;
              });
            },
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ArCoreFaceView(
                  creationParams: _params,
                  onControllerCreated: (controller) {
                    _controller = controller;
                    setState(() {});
                  },
                ),
                if (_controller != null) _FirstFrameScrim(controller: _controller!),
                if (_controller != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 12,
                    child: _StatusBanner(controller: _controller!),
                  ),
              ],
            ),
          ),
          if (_controller != null) _RetryBar(controller: _controller!),
          if (_showCalibration)
            _CalibrationPanel(
              params: _params,
              onChanged: _onCalibrationChanged,
              onReset: _resetCalibration,
            ),
        ],
      ),
    );
  }

  void _onCalibrationChanged(Map<String, Object> next) {
    setState(() {
      _params = next;
    });
    _controller?.setCalibration(next);
  }

  void _resetCalibration() {
    _onCalibrationChanged(ArCoreGlassesCalibration.toCreationParams());
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.controller});

  final ArCoreFaceController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ArCoreFaceSnapshot>(
      valueListenable: controller.snapshot,
      builder: (context, snap, _) {
        return Material(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              _statusText(snap),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        );
      },
    );
  }

  String _statusText(ArCoreFaceSnapshot snap) {
    if (snap.availability == ArCoreAvailability.unsupported) {
      return 'Устройство без ARCore. 2D/3D экраны по-прежнему доступны.';
    }
    if (snap.availability == ArCoreAvailability.installRequested) {
      return 'Нужны Google Play Services for AR. Установите и нажмите Повтор.';
    }
    if (snap.session == ArCoreSessionPhase.failed) {
      return 'Сессия AR не стартовала: ${snap.sessionMessage ?? 'ошибка'}. '
          'Проверьте разрешение камеры.';
    }
    if (snap.session == ArCoreSessionPhase.starting) {
      return 'Запуск фронтальной AR-сессии…';
    }
    if (snap.session == ArCoreSessionPhase.paused) {
      return 'Сессия на паузе (приложение в фоне).';
    }
    final tracking = switch (snap.tracking) {
      ArCoreTrackingPhase.searching => 'Ищем лицо в кадре',
      ArCoreTrackingPhase.tracking => 'Лицо в трекинге',
      ArCoreTrackingPhase.lost => 'Лицо потеряно — повернитесь к камере',
    };
    final model = switch (snap.model) {
      ArCoreModelPhase.loading => 'загрузка GLB',
      ArCoreModelPhase.ready => 'оправа готова',
      ArCoreModelPhase.failed => 'GLB: ${snap.modelMessage ?? 'ошибка'}',
    };
    return '$tracking · $model';
  }
}

/// Заглушка на первые секунды AR-сессии: чёрный/пустой кадр камеры в этот
/// момент — норма для ARCore (см. официальный ARFaceDemo), а не баг. Держим
/// поверх [ArCoreFaceView], пока не пришёл первый `onSessionUpdated` или сессия
/// не упала явной ошибкой (тогда сообщение об ошибке важнее заглушки).
class _FirstFrameScrim extends StatelessWidget {
  const _FirstFrameScrim({required this.controller});

  final ArCoreFaceController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ArCoreFaceSnapshot>(
      valueListenable: controller.snapshot,
      builder: (context, snap, _) {
        final showScrim =
            !snap.firstFrameSeen && snap.session != ArCoreSessionPhase.failed;
        if (!showScrim) {
          return const SizedBox.shrink();
        }
        return const ColoredBox(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Ждём первый кадр фронтальной камеры…',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RetryBar extends StatelessWidget {
  const _RetryBar({required this.controller});

  final ArCoreFaceController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ArCoreFaceSnapshot>(
      valueListenable: controller.snapshot,
      builder: (context, snap, _) {
        final needRetry =
            snap.session == ArCoreSessionPhase.failed ||
            snap.availability == ArCoreAvailability.installRequested ||
            snap.availability == ArCoreAvailability.unsupported;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Только Android · одно лицо · физическое устройство с ARCore.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: needRetry ? controller.retrySession : null,
                child: const Text('Повтор'),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Слайдеры посадки: чтобы на устройстве подогнать origin GLB без пересборки.
class _CalibrationPanel extends StatelessWidget {
  const _CalibrationPanel({
    required this.params,
    required this.onChanged,
    required this.onReset,
  });

  final Map<String, Object> params;
  final ValueChanged<Map<String, Object>> onChanged;
  final VoidCallback onReset;

  double _num(String key) => (params[key] as num?)?.toDouble() ?? 0;

  bool _flag(String key) => params[key] as bool? ?? false;

  @override
  Widget build(BuildContext context) {
    final anchor = ArCoreFaceAnchorWire.fromWire(params['anchor'] as String?);
    return Material(
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('Якорь'),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('center'),
                    selected: anchor == ArCoreFaceAnchor.center,
                    onSelected: (_) => _patch('anchor', 'center'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('nose'),
                    selected: anchor == ArCoreFaceAnchor.nose,
                    onSelected: (_) => _patch('anchor', 'nose'),
                  ),
                  const Spacer(),
                  TextButton(onPressed: onReset, child: const Text('Сброс')),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Авторский pivot',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: _flag('keepAuthoredPivot'),
                      onChanged: (v) => _patch('keepAuthoredPivot', v ?? true),
                    ),
                  ),
                  Expanded(
                    child: CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Оккlusion лица',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: _flag('occlusionEnabled'),
                      onChanged: (v) => _patch('occlusionEnabled', v ?? false),
                    ),
                  ),
                ],
              ),
              _slider('Ширина, м', 'widthMeters', 0.08, 0.22),
              _slider('offset X', 'offsetX', -0.08, 0.08),
              _slider('offset Y', 'offsetY', -0.08, 0.08),
              _slider('offset Z', 'offsetZ', -0.05, 0.12),
              _slider('rot X°', 'rotationX', -180, 180),
              _slider('rot Y°', 'rotationY', -180, 180),
              _slider('rot Z°', 'rotationZ', -180, 180),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slider(String label, String key, double min, double max) {
    final value = _num(key).clamp(min, max);
    return Row(
      children: [
        SizedBox(width: 88, child: Text('$label ${value.toStringAsFixed(3)}')),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: (v) => _patch(key, v),
          ),
        ),
      ],
    );
  }

  void _patch(String key, Object value) {
    onChanged(Map<String, Object>.from(params)..[key] = value);
  }
}
