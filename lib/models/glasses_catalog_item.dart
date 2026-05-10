import 'package:flutter/foundation.dart';

/// Элемент виртуальной витрины очков (превью + путь к GLB в Flutter assets и имя после копирования в документы).
///
/// После загрузки [GlassesAssetToDocuments.prepareItem] файл оказывается внутри каталога
/// [getApplicationDocumentsDirectory], что нужно модулю [ar_flutter_plugin] типа
/// [NodeType.fileSystemAppFolderGLB] (ожидает путь относительно `app_flutter` на Android).
@immutable
class GlassesCatalogItem {
  /// Короткий идентификатор каталога.
  final String id;

  /// Заголовок на карточке.
  final String title;

  /// Подстрочное описание.
  final String description;

  /// Картинка превью (PNG и т.д.) из секции assets.
  final String previewAssetPath;

  /// Файл .glb в bundle приложения (`assets/...`).
  final String glbFlutterAsset;

  /// Путь сохранения внутри директории документов, например `models/lenses_a.glb`.
  /// Не добавлять впереди `assets/` — это уже «рабочее» дерево приложения на устройстве.
  final String documentRelativePath;

  /// Переезд калибровки в виде дополнительной метаданной для [ModelData.metadata],
  /// её читает [ResolvingFaceARViewer].
  final Map<String, dynamic> arCalibration;

  const GlassesCatalogItem({
    required this.id,
    required this.title,
    required this.description,
    required this.previewAssetPath,
    required this.glbFlutterAsset,
    required this.documentRelativePath,
    this.arCalibration = const {},
  });
}

/// Ключи метадаты для простого переиспользования в каталоге.
abstract final class FaceArCalibrationKeys {
  /// [Vector3]-совместимо: три double [sx, sy, sz] узла модели ARCore-пресета из плагина по умолчанию.
  static const androidArScale = 'androidArScale';

  /// [Vector3]-совместимо: три double смещения в пространстве сцены.
  static const androidArPosition = 'androidArPosition';

  /// [Vector4]-совместимо: quaternion `x y z w` для вращения.
  static const androidArRotation = 'androidArRotation';
}
