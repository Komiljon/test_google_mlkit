import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_3d_ar_converter/flutter_3d_ar_converter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:test_google_mlkit/models/glasses_catalog_item.dart';

/// Отвечает за перенос .glb из Flutter assets во внутренний каталог документов приложения.
///
/// [ar_flutter_plugin] загружает `fileSystemAppFolderGLB`, ожидая «корень» приложения вида …/app_flutter
/// совпадающий с результатом `getApplicationDocumentsDirectory()` по аналогии с примером LocalDuck.glb в плагине.
class GlassesAssetToDocuments {
  GlassesAssetToDocuments._();

  /// Загружает байты из bundle, записывает по пути `[documents]/[documentRelativePath]`
  /// и возвращает [ModelData] с относительным путём (от корня документов приложения до файла модели).
  static Future<ModelData> prepareItem(GlassesCatalogItem item) async {
    final docs = await getApplicationDocumentsDirectory();
    final target = File(p.join(docs.path, item.documentRelativePath));
    await target.parent.create(recursive: true);

    final bd = await rootBundle.load(item.glbFlutterAsset);
    final bytes = bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
    await target.writeAsBytes(bytes, flush: true);

    final modelRelative =
        p.relative(target.path, from: docs.path).replaceAll('\\', '/');

    return ModelData(
      type: ModelType.glasses,
      modelPath: modelRelative,
      originalImagePath: item.glbFlutterAsset,
      metadata: {
        ...item.arCalibration,
        'catalogId': item.id,
        'title': item.title,
      },
    );
  }
}
