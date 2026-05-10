import 'dart:async';

import 'package:augen/augen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const GlassesTryOnApp());
}

class GlassesTryOnApp extends StatelessWidget {
  const GlassesTryOnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Примерка очков - 3D AR',
      theme: ThemeData(primarySwatch: Colors.blue, visualDensity: VisualDensity.adaptivePlatformDensity),
      home: const GlassesTryOnScreen(),
    );
  }
}

class GlassesTryOnScreen extends StatefulWidget {
  const GlassesTryOnScreen({super.key});

  @override
  State<GlassesTryOnScreen> createState() => _GlassesTryOnScreenState();
}

class _GlassesTryOnScreenState extends State<GlassesTryOnScreen> {
  /// Выдаётся [AugenView] после создания нативного platform view — без этого канал связи недействителен.
  AugenController? _controller;

  /// Платформенный вид AR уже сообщил свой id (то же самое, что делает виджет [AugenView] внутри себя).
  bool _platformViewReady = false;

  /// Однократный запуск настройки сессии после [onViewCreated].
  bool _sessionSetupStarted = false;

  bool _isInitialized = false;
  bool _isSupported = false;
  bool _isCheckingSetup = false;
  String? _setupUserMessage;

  List<ARFace> _trackedFaces = [];

  /// Выбор хранится по стабильному id, чтобы не путаться при одинаковых путях к моделям.
  late String _selectedModelId;

  StreamSubscription<List<ARFace>>? _facesSub;
  StreamSubscription<String>? _errorSub;

  /// Какие очки уже «надеты» на лицо faceId → id модели (для минимизации remove/add каждый кадр).
  final Map<String, String> _appliedModelByFaceId = {};

  /// Конфиги для примерки: два рабочих GLB из [assets/models], третий слот объясняет ограничение PLY для augen ([ModelFormat] в документации).
  static final List<GlassesModel> _glassesModels = [
    GlassesModel(
      id: 'sunglasses',
      name: 'Sunglasses A',
      assetPath: 'assets/models/sunglasses.glb',
      localPosition: const Vector3(0, 0.02, 0.05),
      rotation: Quaternion.identity(),
      scale: const Vector3(0.08, 0.08, 0.08),
    ),
    GlassesModel(
      id: 'sunglasses_alt',
      name: 'Sunglasses B',
      assetPath: 'assets/models/sunglasses1.glb',
      // Вторая сетка чуть масштаб/смещение под корректное «сидение» на лице.
      localPosition: const Vector3(0, 0.018, 0.048),
      rotation: Quaternion.identity(),
      scale: const Vector3(0.085, 0.085, 0.085),
    ),
    GlassesModel.unavailablePreview(
      id: 'aa_ply',
      title: 'aa.ply (нужен GLB)',
      reason:
          'В assets есть aa.ply, но augen загружает glTF / GLB / OBJ / USDZ. Экспортируйте модель в .glb, положите в assets/models и добавьте в список.',
    ),
  ];

  GlassesModel? _findModel(String id) {
    for (final m in _glassesModels) {
      if (m.id == id) return m;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _selectedModelId = _glassesModels.firstWhere((e) => e.isAvailable).id;
  }

  /// Создаётся из [AugenView] уже с нужным platform view id — здесь включается сессия AR (см. документацию augen).
  void _onAugenViewCreated(AugenController controller) {
    setState(() {
      _platformViewReady = true;
    });

    unawaited(_setupARSession(controller));
  }

  Future<void> _setupARSession(AugenController controller) async {
    if (_sessionSetupStarted) return;
    _sessionSetupStarted = true;
    _controller = controller;

    setState(() {
      _isCheckingSetup = true;
      _setupUserMessage = null;
    });

    final supported = await controller.isARSupported();
    if (!mounted) return;

    _isSupported = supported;
    if (!supported) {
      setState(() {
        _isCheckingSetup = false;
        _setupUserMessage =
            'AR недоступен на этом устройстве или в эмуляторе — нужен аппарат с ARCore и AR‑под камерой либо iOS с ARKit.';
      });
      _showMessage(_setupUserMessage!);
      return;
    }

    const sessionConfig = ARSessionConfig(
      planeDetection: false,
      lightEstimation: true,
      depthData: false,
      autoFocus: true,
    );

    try {
      await controller.initialize(sessionConfig);
      await controller.setFaceTrackingEnabled(true);
      // Фактический API augen ^1.1.0 — только detectLandmarks / detectExpressions / размер лица на кадре.
      await controller.setFaceTrackingConfig(
        detectLandmarks: true,
        detectExpressions: false,
        minFaceSize: 0.08,
        maxFaceSize: 1.0,
      );

      _facesSub ??= controller.facesStream.listen((faces) {
        if (!mounted) return;
        setState(() {
          _trackedFaces = faces;
        });
        _syncGlassesOnFaces(faces).catchError((Object e, StackTrace st) {
          debugPrint('sync glasses: $e\n$st');
        });
      });

      _errorSub ??= controller.errorStream.listen((error) {
        _showMessage('Ошибка AR: $error');
      });

      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _isCheckingSetup = false;
      });
      _showMessage('AR готово. Выберите модель очков ниже.');
    } catch (e, st) {
      debugPrint('AR init failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _isCheckingSetup = false;
        _setupUserMessage = 'Не удалось запустить сессию AR: $e';
      });
      _showMessage(_setupUserMessage!);
    }
  }

  /// Стабильный id узла на лице (один объект очков на одно отслеживаемое лицо).
  String _glassesNodeId(String faceId) => 'glasses_$faceId';

  Future<void> _clearAllFaceGlasses() async {
    final c = _controller;
    if (c == null) return;
    final entries = List<MapEntry<String, String>>.from(_appliedModelByFaceId.entries);
    for (final e in entries) {
      try {
        await c.removeNodeFromTrackedFace(nodeId: _glassesNodeId(e.key), faceId: e.key);
      } catch (err, st) {
        debugPrint('removeNodeFromTrackedFace: $err\n$st');
      }
    }
    _appliedModelByFaceId.clear();
  }

  /// Снимает узлы с лиц, которые пропали из надёжного трекинга, и добавляет/обновляет только при смене модели или лица.
  Future<void> _syncGlassesOnFaces(List<ARFace> faces) async {
    final c = _controller;
    if (!_isInitialized || c == null) return;

    final chosen = _findModel(_selectedModelId);
    if (chosen == null || !chosen.isAvailable || chosen.assetPath == null) return;

    final reliableFaceIds = <String>{};
    for (final f in faces) {
      if (f.isTracked && f.isReliable) reliableFaceIds.add(f.id);
    }

    // Лица перестали отслеживаться — явно отвязываем узел (API для контента на лице — removeNodeFromTrackedFace).
    for (final fid in _appliedModelByFaceId.keys.toList()) {
      if (!reliableFaceIds.contains(fid)) {
        try {
          await c.removeNodeFromTrackedFace(nodeId: _glassesNodeId(fid), faceId: fid);
        } catch (err, st) {
          debugPrint('remove stale face glasses: $err\n$st');
        }
        _appliedModelByFaceId.remove(fid);
      }
    }

    if (!mounted) return;

    for (final face in faces) {
      if (!(face.isTracked && face.isReliable)) continue;
      final fid = face.id;
      if (_appliedModelByFaceId[fid] == _selectedModelId) continue;

      final nodeId = _glassesNodeId(fid);

      try {
        if (_appliedModelByFaceId.containsKey(fid)) {
          await c.removeNodeFromTrackedFace(nodeId: nodeId, faceId: fid);
          _appliedModelByFaceId.remove(fid);
        }

        final node = ARNode.fromModel(
          id: nodeId,
          modelPath: chosen.assetPath!,
          position: chosen.localPosition,
          rotation: chosen.rotation,
          scale: chosen.scale,
        );

        await c.addNodeToTrackedFace(nodeId: nodeId, faceId: fid, node: node);
        _appliedModelByFaceId[fid] = _selectedModelId;
      } catch (e, st) {
        debugPrint('face glasses attach failed: $e\n$st');
      }
    }
  }

  Future<void> _onSelectModel(String modelId) async {
    final m = _findModel(modelId);
    if (m == null) return;
    if (!m.isAvailable) {
      _showMessage(m.unavailableReason ?? 'Модель недоступна для примерки.');
      return;
    }

    setState(() {
      _selectedModelId = modelId;
    });

    await _clearAllFaceGlasses();
    if (!mounted) return;
    await _syncGlassesOnFaces(_trackedFaces);
    if (!mounted) return;
    _showMessage('Выбрана модель «${m.name}».');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 30)),
    );
    debugPrint(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Примерка очков - 3D AR'),
        actions: [
          if (_isInitialized)
            IconButton(
              icon: Icon(_isSupported ? Icons.face : Icons.face_outlined),
              onPressed: null,
              tooltip: 'Отслеживание лиц активно',
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AugenView(
            onViewCreated: _onAugenViewCreated,
            config: const ARSessionConfig(
              planeDetection: false,
              lightEstimation: true,
              depthData: false,
              autoFocus: true,
            ),
          ),

          /// Пока нативное AR‑представление не подключилось, показываем подсказку поверх заглушки.
          if (!_platformViewReady || _isCheckingSetup)
            Container(
              color: Colors.black26,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      !_platformViewReady ? 'Подключение AR‑камеры...' : 'Проверка и запуск AR...',
                      key: !_platformViewReady ? const ValueKey('waiting_view') : const ValueKey('checking_ar'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          /// AR не поддерживается (или не смогли убедиться на устройстве).
          if (_platformViewReady && !_isCheckingSetup && !_isSupported)
            Container(
              color: Colors.black87,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                      const SizedBox(height: 16),
                      const Text(
                        'Устройство не поддерживает AR или AR недоступен',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _setupUserMessage ??
                            'Запускайте приложение на физическом устройстве с ARCore или ARKit. В большинстве эмуляторов AR недоступен.',
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          /// Платформа поддерживается, но сессия упала после проверки.
          if (_platformViewReady &&
              !_isCheckingSetup &&
              _isSupported &&
              !_isInitialized &&
              (_setupUserMessage != null))
            Container(
              color: Colors.black87,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.videocam_off, size: 56, color: Colors.orange),
                      const SizedBox(height: 16),
                      Text(
                        _setupUserMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_isInitialized)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Выберите очки для примерки',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Два варианта — GLB из assets; aa.ply отмечен как недоступный до конвертации в GLB.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _glassesModels.length,
                        itemBuilder: (context, index) {
                          final model = _glassesModels[index];
                          final isSelected = _selectedModelId == model.id;
                          final dimmed = !model.isAvailable;

                          return GestureDetector(
                            onTap: () => _onSelectModel(model.id),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              width: 100,
                              child: Column(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: dimmed
                                          ? Colors.grey.withValues(alpha: 0.2)
                                          : (isSelected
                                                ? Colors.blue.withValues(alpha: 0.3)
                                                : Colors.grey.withValues(alpha: 0.3)),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: dimmed
                                            ? Colors.white24
                                            : (isSelected ? Colors.blue : Colors.white.withValues(alpha: 0.5)),
                                        width: 2,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontSize: 24,
                                          color: dimmed
                                              ? Colors.white38
                                              : (isSelected ? Colors.blue : Colors.white),
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    model.name,
                                    style: TextStyle(
                                      color: dimmed
                                          ? Colors.white38
                                          : (isSelected ? Colors.blueAccent : Colors.white),
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_isInitialized)
            Positioned(
              top: 20,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.face, color: _isSupported ? Colors.green : Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Отслеживание лиц:',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isSupported ? 'ВКЛ' : 'ВЫКЛ',
                          style: TextStyle(color: _isSupported ? Colors.green : Colors.orange, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (_trackedFaces.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.person, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Лиц обнаружено: ${_trackedFaces.length}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _facesSub?.cancel();
    _errorSub?.cancel();
    _controller?.dispose();
    super.dispose();
  }
}

/// Описание одной пары очков для AR: ресурс из assets на лице + локальный трансформ в системе лица augen.
class GlassesModel {
  final String id;
  final String name;
  /// Путь вида assets/... только для поддерживаемых форматов; null если слот зарезервирован под недоступный формат (.ply и т.д.).
  final String? assetPath;
  final bool isAvailable;
  final String? unavailableReason;
  /// Смещение относительно привязки «лицо»: для каждого меша обычно подбирается вручную.
  final Vector3 localPosition;
  final Quaternion rotation;
  final Vector3 scale;

  GlassesModel({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.localPosition,
    required this.rotation,
    required this.scale,
  }) : isAvailable = true,
       unavailableReason = null;

  /// Плейсхолдер в списке (например PLY без конвертации в GLB).
  GlassesModel.unavailablePreview({
    required this.id,
    required String title,
    required String reason,
  }) : name = title,
       assetPath = null,
       isAvailable = false,
       unavailableReason = reason,
       localPosition = Vector3.zero(),
       rotation = Quaternion.identity(),
       scale = const Vector3(1, 1, 1);
}
