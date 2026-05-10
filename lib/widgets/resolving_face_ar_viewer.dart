import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:flutter_3d_ar_converter/flutter_3d_ar_converter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:test_google_mlkit/models/glasses_catalog_item.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

/// Улучшенный просмотр Face AR над оригинальным виджетом из `flutter_3d_ar_converter`.
///
/// Причины отдельного файла в проекте (а не патч pub-пакета):
/// - На Android узел типа `fileSystemAppFolderGLB` требует **относительного** пути файла под `ApplicationDocuments`,
///   а исходный `FaceARViewer` передавал `modelPath` как есть и проверял `File.exists` там же — из‑за этого
///   проваливалась проверка файла или строился неверный путь к renderable Sceneform.
/// - Здесь мы однозначно приводим `modelPath` к абсолютному расположению на диске и обратно к относительному URI ARCore,
///   а параметры трансформации берём из метадаты [ModelData] (калибровка из каталога).
class ResolvingFaceARViewer extends StatefulWidget {
  /// Данные о модели после подготовки на диске (смотри `GlassesAssetToDocuments`).
  final ModelData modelData;

  /// Колбэк по готовности сессии Face AR на iOS.
  final VoidCallback? onArViewCreated;

  const ResolvingFaceARViewer({
    super.key,
    required this.modelData,
    this.onArViewCreated,
  });

  @override
  State<ResolvingFaceARViewer> createState() => _ResolvingFaceARViewerState();
}

class _ResolvingFaceARViewerState extends State<ResolvingFaceARViewer>
    with WidgetsBindingObserver {
  ARKitController? arkitController;
  ARKitNode? faceNode;

  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARNode? androidFaceNode;

  bool isInitialized = false;
  bool isFaceTrackingAvailable = false;

  bool hasError = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (Platform.isIOS && arkitController != null) {
      /* ARKit управляет паузами внутренне */
    } else if (Platform.isAndroid && arSessionManager != null) {
      /* ar_flutter_plugin сам обрабатывает жизненный цикл активности */
    }
  }

  /// Запрашиваем камеру; без этого Face AR технически невозможен.
  Future<void> _requestPermissions() async {
    try {
      final status = await Permission.camera.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        setState(() {
          hasError = true;
          errorMessage =
              'Нужен доступ к камере для примерки в дополненной реальности.';
        });
      }
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = 'Не удалось запросить камеру: $e';
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    if (Platform.isIOS) {
      arkitController?.dispose();
    } else if (Platform.isAndroid) {
      arSessionManager?.dispose();
    }

    super.dispose();
  }

  /// Собирает абсолютный путь к файлу модели так, чтобы и Android, и iOS видели один и тот же файл.
  Future<File?> _resolvedModelOnDisk() async {
    final raw = widget.modelData.modelPath.replaceAll(r'\', '/');
    if (p.isAbsolute(raw)) {
      return File(raw);
    }
    final docs = await getApplicationDocumentsDirectory();
    return File(p.join(docs.path, raw));
  }

  /// То, что отправляется как `uri` в `ARNodes` класса Sceneform-путей приложения (`app_flutter/...`).
  Future<String?> _relativeUriAgainstDocuments(File resolved) async {
    final docs = await getApplicationDocumentsDirectory();
    final relative = p.relative(resolved.path, from: docs.path);
    if (relative.startsWith('..')) {
      debugPrint(
        'Файл модели за пределами ApplicationDocumentsDirectory: ${resolved.path}',
      );
      return null;
    }
    return relative.replaceAll(r'\', '/');
  }

  Vector3 _readVec3(List<dynamic>? keyCandidates, Vector3 fallback) {
    for (final key in keyCandidates ?? const <dynamic>[]) {
      final list = widget.modelData.metadata?[key];
      if (list is List && list.length >= 3) {
        return Vector3(
          (list[0] as num).toDouble(),
          (list[1] as num).toDouble(),
          (list[2] as num).toDouble(),
        );
      }
    }
    return fallback;
  }

  Vector4 _readVec4(List<dynamic>? keyCandidates, Vector4 fallback) {
    for (final key in keyCandidates ?? const <dynamic>[]) {
      final list = widget.modelData.metadata?[key];
      if (list is List && list.length >= 4) {
        return Vector4(
          (list[0] as num).toDouble(),
          (list[1] as num).toDouble(),
          (list[2] as num).toDouble(),
          (list[3] as num).toDouble(),
        );
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ошибка Face AR'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(errorMessage, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      hasError = false;
                      errorMessage = '';
                    });
                    _requestPermissions();
                  },
                  child: const Text('Повторить запрос камеры'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (Platform.isIOS) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Примерка (Face AR • iOS)'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              tooltip: 'Сброс сессии AR',
              onPressed: _resetIosSession,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'На iOS текущий пакет после проверки файла модели продолжает '
                'отображать упрощённую геометрию «очков», а не сам GLB '
                '(ограничение flutter_3d_ar_converter). На Android показывается ваш GLB.',
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: ARKitSceneView(
                configuration: ARKitConfiguration.faceTracking,
                onARKitViewCreated: _onArkitViewCreated,
              ),
            ),
            if (!isInitialized)
              Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text(
                      'Инициализация отслеживания лица…',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    if (Platform.isAndroid) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Примерка (Face AR • Android)'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              tooltip: 'Сброс сессии AR',
              onPressed: _resetAndroidSession,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ARView(onARViewCreated: _onAndroidArViewCreated),
            ),
            if (!isInitialized)
              Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text(
                      'Инициализация сцены ARCore…',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Face AR'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.phone_android, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Face AR поддерживается только на iOS и Android.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Назад'),
            ),
          ],
        ),
      ),
    );
  }

  void _resetIosSession() {
    if (arkitController == null) return;
    try {
      if (faceNode != null) {
        arkitController!.remove(faceNode!.name);
        faceNode = null;
      }
      setState(() {
        isInitialized = false;
      });
      Future<void>.delayed(const Duration(milliseconds: 500), () async {
        if (!mounted || !isFaceTrackingAvailable) return;
        await _addGlassesModelIos();
        Future<void>.delayed(const Duration(seconds: 1), () {
          if (!mounted) return;
          setState(() {
            isInitialized = true;
          });
        });
      });
    } catch (e) {
      debugPrint('ошибка сброса iOS AR: $e');
    }
  }

  void _resetAndroidSession() {
    if (arSessionManager == null || arObjectManager == null) return;
    try {
      if (androidFaceNode != null) {
        arObjectManager!.removeNode(androidFaceNode!);
        androidFaceNode = null;
      }
      setState(() {
        isInitialized = false;
      });
      Future<void>.delayed(const Duration(milliseconds: 500), () async {
        if (!mounted || !isFaceTrackingAvailable) return;
        await _addAndroidFaceModel();
        Future<void>.delayed(const Duration(seconds: 1), () {
          if (!mounted) return;
          setState(() {
            isInitialized = true;
          });
        });
      });
    } catch (e) {
      debugPrint('ошибка сброса Android AR: $e');
    }
  }

  void _onAndroidArViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) {
    arSessionManager = sessionManager;
    arObjectManager = objectManager;
    _startAndroidSession();
  }

  Future<void> _startAndroidSession() async {
    try {
      await arSessionManager!.onInitialize(
        showFeaturePoints: false,
        showPlanes: false,
        customPlaneTexturePath: null,
        showWorldOrigin: false,
        handlePans: true,
        handleRotation: true,
        handleTaps: true,
      );

      setState(() {
        isFaceTrackingAvailable = true;
        isInitialized = true;
      });

      await _addAndroidFaceModel();
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage =
            'Ошибка инициализации ARCore-сессии. Проверьте поддержку служб Google Play для AR.';
      });
      debugPrint('Android AR session error: $e');
    }
  }

  Future<void> _addAndroidFaceModel() async {
    try {
      final modelFile = await _resolvedModelOnDisk();
      if (modelFile == null || !await modelFile.exists()) {
        debugPrint('Файл модели недоступен: ${widget.modelData.modelPath}');
        return;
      }

      final uri = await _relativeUriAgainstDocuments(modelFile);
      if (uri == null) return;

      final scale = _readVec3(
        [FaceArCalibrationKeys.androidArScale],
        Vector3(0.2, 0.2, 0.2),
      );
      final position = _readVec3(
        [FaceArCalibrationKeys.androidArPosition],
        Vector3(0.0, 0.0, -1.5),
      );
      final rotation = _readVec4(
        [FaceArCalibrationKeys.androidArRotation],
        Vector4(1.0, 0.0, 0.0, 0.0),
      );

      androidFaceNode = ARNode(
        type: NodeType.fileSystemAppFolderGLB,
        uri: uri,
        scale: scale,
        position: position,
        rotation: rotation,
      );

      await arObjectManager!.addNode(androidFaceNode!);
    } catch (e) {
      debugPrint('Не удалось добавить Android-модель: $e');
    }
  }

  void _onArkitViewCreated(ARKitController controller) {
    try {
      arkitController = controller;
      controller.onAddNodeForAnchor = _handleAddAnchor;
      controller.onUpdateNodeForAnchor = _handleUpdateAnchor;

      Future<void>.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        if (faceNode != null) {
          setState(() {
            isFaceTrackingAvailable = true;
            isInitialized = true;
          });
        } else {
          setState(() {
            isFaceTrackingAvailable = false;
            hasError = true;
            errorMessage =
                'На этом устройстве слабее или недоступен Face Tracking ARKit.';
          });
        }
      });

      _addGlassesModelIos();

      widget.onArViewCreated?.call();
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = 'Не удалось поднять ARKit Face AR: $e';
      });
    }
  }

  void _handleAddAnchor(ARKitAnchor anchor) {
    if (anchor is ARKitFaceAnchor) {
      _updateFaceGeometry(anchor);
    }
  }

  void _handleUpdateAnchor(ARKitAnchor anchor) {
    if (anchor is ARKitFaceAnchor) {
      _updateFaceGeometry(anchor);
    }
  }

  void _updateFaceGeometry(ARKitFaceAnchor anchor) {
    try {
      if (faceNode != null) {
        faceNode!.transform = anchor.transform;
      }
    } catch (e) {
      debugPrint('Ошибка обновления решётки лица: $e');
    }
  }

  /// По образцу `FaceARViewer` родительского пакета: упрощённая геометрия после того,
  /// как убеждаемся, что файл на диске существует (реальный импорт модели здесь всё ещё не выполняется — это задача авторов плагина).
  Future<void> _addGlassesModelIos() async {
    try {
      if (arkitController == null) return;

      final modelOnDisk = await _resolvedModelOnDisk();
      if (modelOnDisk == null || !await modelOnDisk.exists()) {
        debugPrint(
          'Model file does not exist (iOS sanity check failed): '
          '${widget.modelData.modelPath}',
        );
        return;
      }

      faceNode = ARKitNode(
        geometry: ARKitSphere(radius: 0.01),
        position: Vector3(0, 0, 0),
        eulerAngles: Vector3.zero(),
      );

      arkitController!.add(faceNode!);
      _addGlassesFrames();
    } catch (e) {
      debugPrint('Не удалось выставить iOS узел лица: $e');
    }
  }

  void _addGlassesFrames() {
    try {
      if (faceNode == null || arkitController == null) return;

      final glassMaterial = _createGlassMaterial();
      final frameMaterial = _createFrameMaterial();

      final leftLensGeometry = ARKitSphere(
        radius: 0.025,
        materials: [glassMaterial],
      );
      final rightLensGeometry = ARKitSphere(
        radius: 0.025,
        materials: [glassMaterial],
      );
      final bridgeGeometry = ARKitBox(
        width: 0.02,
        height: 0.01,
        length: 0.01,
        materials: [frameMaterial],
      );
      final leftTempleGeometry = ARKitBox(
        width: 0.08,
        height: 0.005,
        length: 0.005,
        materials: [frameMaterial],
      );
      final rightTempleGeometry = ARKitBox(
        width: 0.08,
        height: 0.005,
        length: 0.005,
        materials: [frameMaterial],
      );

      final leftLens = ARKitNode(
        geometry: leftLensGeometry,
        position: Vector3(-0.035, 0, 0.06),
        eulerAngles: Vector3.zero(),
      );
      final rightLens = ARKitNode(
        geometry: rightLensGeometry,
        position: Vector3(0.035, 0, 0.06),
        eulerAngles: Vector3.zero(),
      );
      final bridge = ARKitNode(
        geometry: bridgeGeometry,
        position: Vector3(0, 0, 0.06),
        eulerAngles: Vector3.zero(),
      );
      final leftTemple = ARKitNode(
        geometry: leftTempleGeometry,
        position: Vector3(-0.06, 0, 0.05),
        eulerAngles: Vector3(0, -0.2, 0),
      );
      final rightTemple = ARKitNode(
        geometry: rightTempleGeometry,
        position: Vector3(0.06, 0, 0.05),
        eulerAngles: Vector3(0, 0.2, 0),
      );

      arkitController!.add(leftLens, parentNodeName: faceNode!.name);
      arkitController!.add(rightLens, parentNodeName: faceNode!.name);
      arkitController!.add(bridge, parentNodeName: faceNode!.name);
      arkitController!.add(leftTemple, parentNodeName: faceNode!.name);
      arkitController!.add(rightTemple, parentNodeName: faceNode!.name);
    } catch (e) {
      debugPrint('Не удалось собрать геометрию оправ: $e');
    }
  }

  ARKitMaterial _createGlassMaterial() {
    final blueWithOpacity = Color.fromRGBO(0, 0, 255, 0.5);
    return ARKitMaterial(
      transparency: 0.5,
      diffuse: ARKitMaterialProperty.color(blueWithOpacity),
      specular: ARKitMaterialProperty.color(Colors.white),
    );
  }

  ARKitMaterial _createFrameMaterial() {
    return ARKitMaterial(
      diffuse: ARKitMaterialProperty.color(Colors.black),
      specular: ARKitMaterialProperty.color(Colors.grey),
    );
  }
}
