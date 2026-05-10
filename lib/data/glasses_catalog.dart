import 'package:test_google_mlkit/models/glasses_catalog_item.dart';

/// Статический каталог из готовых GLB + превью; при необходимости подстройте коэффициенты здесь же.
///
/// Для второй и третьей модели добавлен небольшой сдвиг по Z, чтобы на устройствах они не «перекрывали» камеру
/// точно тем же оффсетом что и первый пресет из плагина по умолчанию (тонкая настройка — на железе).
final List<GlassesCatalogItem> kGlassesCatalog = [
  GlassesCatalogItem(
    id: 'lenses_glb_ref',
    title: 'Эталон: линзы',
    description: 'Из assets/sunglasses_lenses.glb — основная тестовая пара.',
    previewAssetPath: 'assets/glasses1.png',
    glbFlutterAsset: 'assets/sunglasses_lenses.glb',
    documentRelativePath: 'models/catalog_sunglasses_lenses.glb',
    arCalibration: {
      FaceArCalibrationKeys.androidArScale: [0.22, 0.22, 0.22],
      FaceArCalibrationKeys.androidArPosition: [0.0, 0.0, -1.45],
      FaceArCalibrationKeys.androidArRotation: [1.0, 0.0, 0.0, 0.0],
    },
  ),
  GlassesCatalogItem(
    id: 'sunglasses_full',
    title: 'Солнцезащитные (full)',
    description: 'GLB из assets/models/sunglasses.glb',
    previewAssetPath: 'assets/glasses2.png',
    glbFlutterAsset: 'assets/models/sunglasses.glb',
    documentRelativePath: 'models/catalog_sunglasses.glb',
    arCalibration: {
      FaceArCalibrationKeys.androidArScale: [0.2, 0.2, 0.2],
      FaceArCalibrationKeys.androidArPosition: [0.0, -0.02, -1.5],
      FaceArCalibrationKeys.androidArRotation: [1.0, 0.0, 0.0, 0.0],
    },
  ),
  GlassesCatalogItem(
    id: 'sunglasses_alt',
    title: 'Солнцезащитные (alt)',
    description: 'GLB из assets/models/sunglasses1.glb — альтернативная сетка.',
    previewAssetPath: 'assets/glasses3.png',
    glbFlutterAsset: 'assets/models/sunglasses1.glb',
    documentRelativePath: 'models/catalog_sunglasses1.glb',
    arCalibration: {
      FaceArCalibrationKeys.androidArScale: [0.18, 0.18, 0.18],
      FaceArCalibrationKeys.androidArPosition: [0.0, 0.02, -1.55],
      FaceArCalibrationKeys.androidArRotation: [1.0, 0.0, 0.0, 0.0],
    },
  ),
];
