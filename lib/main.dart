import 'package:flutter/material.dart';
import 'package:augen/augen.dart';
import 'dart:async';

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
  AugenController? _controller;
  bool _isInitialized = false;
  bool _isSupported = false;
  bool _isCheckingSupport = true; // Добавим состояние проверки
  List<ARFace> _trackedFaces = [];
  String? _selectedGlasses;

  final List<GlassesModel> _glassesModels = [
    GlassesModel(id: 'glasses_1', name: 'Классические', modelPath: 'assets/models/sunglasses.glb'),
    GlassesModel(id: 'glasses_2', name: 'Солнцезащитные', modelPath: 'assets/models/sunglasses.glb'),
    GlassesModel(id: 'glasses_3', name: 'Очки-авиаторы', modelPath: 'assets/models/sunglasses.glb'),
    GlassesModel(id: 'glasses_4', name: 'Круглые', modelPath: 'assets/models/sunglasses.glb'),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAR();
  }

  Future<void> _initializeAR() async {
    try {
      // Создаем контроллер с viewId (обязательный параметр)
      _controller = AugenController(0);

      // Проверяем поддержку AR *через экземпляр контроллера*
      _isSupported = await _controller!.isARSupported();

      // Обновим состояние проверки
      if (mounted) {
        setState(() {
          _isCheckingSupport = false;
        });
      }

      if (!_isSupported) {
        // Вместо завершения, покажем сообщение и остановимся
        _showMessage('AR не поддерживается на этом устройстве. Попробуйте запустить на другом.');
        return; // ВАЖНО: Выходим из функции, не продолжая инициализацию
      }

      // --- Если поддержка подтверждена, продолжаем инициализацию ---

      // Инициализируем сессию AR
      await _controller!.initialize(
        const ARSessionConfig(
          planeDetection: false, // Для примерки очков плоскости не нужны
          lightEstimation: true,
          depthData: false,
          autoFocus: true,
        ),
      );

      // Включаем отслеживание лиц
      await _controller!.setFaceTrackingEnabled(true);

      // Слушаем поток отслеживаемых лиц
      _controller!.facesStream.listen((faces) {
        if (!mounted) return;
        setState(() {
          _trackedFaces = faces;
        });
        _updateGlassesOnFaces(faces);
      });

      // Слушаем ошибки
      _controller!.errorStream.listen((error) {
        _showMessage('Ошибка AR: $error');
      });

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      _showMessage('AR готово! Покажите лицо перед камерой');
    } catch (e) {
      // Обновим состояние проверки при ошибке
      if (mounted) {
        setState(() {
          _isCheckingSupport = false;
        });
      }
      _showMessage('Ошибка инициализации: $e');
    }
  }

  void _updateGlassesOnFaces(List<ARFace> faces) {
    if (_selectedGlasses == null || _controller == null) return;

    for (final face in faces) {
      if (face.isTracked && face.isReliable) {
        final glassesNodeId = 'glasses_${face.id}';

        // Удаляем старые очки, если есть
        _controller!.removeNode(glassesNodeId);

        // Создаем новую 3D модель очков из внешнего файла
        final glassesNode = ARNode.fromModel(
          id: glassesNodeId,
          modelPath: _selectedGlasses!,
          // Позиционируем очки относительно лица
          // Позиция (0, 0, 0) - центр лица, смещаем немного вперед
          position: const Vector3(0, 0, 0.05),
          rotation: const Quaternion(0, 0, 0, 1),
          // Масштаб подбирается индивидуально для каждой модели
          scale: const Vector3(0.08, 0.08, 0.08),
        );

        // Добавляем модель к отслеживаемому лицу
        _controller!.addNodeToTrackedFace(nodeId: glassesNodeId, faceId: face.id, node: glassesNode).catchError((error) {
          print('Ошибка добавления очков к лицу: $error');
        });
      } else {
        // Если лицо больше не отслеживается, удаляем с него очки
        final glassesNodeId = 'glasses_${face.id}';
        _controller!.removeNode(glassesNodeId);
      }
    }
  }

  Future<void> _selectGlasses(String modelPath) async {
    setState(() {
      _selectedGlasses = modelPath;
    });

    // Обновляем очки на всех отслеживаемых лицах
    _updateGlassesOnFaces(_trackedFaces);

    _showMessage('Выбраны новые очки!');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 30)));
    print(message);
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
              onPressed: null, // Отслеживание включено постоянно
              tooltip: 'Отслеживание лиц активно',
            ),
        ],
      ),
      body: Stack(
        children: [
          // Основное AR представление
          if (_isInitialized)
            AugenView(
              onViewCreated: (controller) {
                // Контроллер уже инициализирован в _initializeAR
              },
              config: const ARSessionConfig(planeDetection: false, lightEstimation: true, depthData: false, autoFocus: true),
            ),

          // Сообщение о неподдерживаемом устройстве ИЛИ во время проверки
          if ((_isCheckingSupport || !_isSupported) && !_isInitialized)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Проверка поддержки AR...',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    key: ValueKey('checking_support'),
                  ),
                  SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text('Пожалуйста, подождите...', textAlign: TextAlign.center, key: ValueKey('checking_wait')),
                  ),
                ],
              ),
            ),

          // Сообщение об ошибке поддержки (после проверки)
          if (!_isSupported && !_isCheckingSupport && !_isInitialized)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Устройство не поддерживает AR',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    key: ValueKey('no_support'),
                  ),
                  SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Для работы приложения требуется устройство с поддержкой дополненной реальности (ARCore для Android или ARKit для iOS).',
                      textAlign: TextAlign.center,
                      key: ValueKey('no_support_desc'),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Если вы запускаете в эмуляторе - AR не работает в эмуляторе.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontStyle: FontStyle.italic),
                    key: ValueKey('emulator_warning'),
                  ),
                ],
              ),
            ),

          // Панель выбора очков (только если инициализировано)
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
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _glassesModels.length,
                        itemBuilder: (context, index) {
                          final model = _glassesModels[index];
                          final isSelected = _selectedGlasses == model.modelPath;

                          return GestureDetector(
                            onTap: () => _selectGlasses(model.modelPath),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              width: 100,
                              child: Column(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? Colors.blue : Colors.white.withOpacity(0.5),
                                        width: 2,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontSize: 24,
                                          color: isSelected ? Colors.blue : Colors.white,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    model.name,
                                    style: TextStyle(
                                      color: isSelected ? Colors.blue : Colors.white,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
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

          // Информация об отслеживании (только если инициализировано)
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
    _controller?.dispose();
    super.dispose();
  }
}

// Модель для описания очков
class GlassesModel {
  final String id;
  final String name;
  final String modelPath;

  GlassesModel({required this.id, required this.name, required this.modelPath});
}
