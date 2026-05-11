import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Utility class for file operations
class FileUtils {
  /// Get the application documents directory
  static Future<Directory> get appDir async {
    return await getApplicationDocumentsDirectory();
  }

  /// Get the models directory
  static Future<Directory> get modelsDir async {
    final Directory directory = Directory('${(await appDir).path}/models');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  /// Get the images directory
  static Future<Directory> get imagesDir async {
    final Directory directory = Directory('${(await appDir).path}/images');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  /// Save an image file to the app's images directory
  ///
  /// Галерея на iOS часто отдаёт HEIC; прямой `copy` в `.jpg` оставляет неверный тип и
  /// даёт предупреждения вроде `unsupported file format 'public.heic'`. Декодируем через
  /// движок Flutter и сохраняем как PNG — универсально для JPEG/HEIC/PNG.
  static Future<String> saveImage(File imageFile) async {
    final Uint8List bytes = await imageFile.readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    ui.Image? raster;
    try {
      final ui.FrameInfo frame = await codec.getNextFrame();
      raster = frame.image;
      final ByteData? bd =
          await raster.toByteData(format: ui.ImageByteFormat.png);

      if (bd == null) {
        throw StateError('Не удалось раскодировать изображение для сохранения.');
      }

      final String fileName =
          'image_${DateTime.now().millisecondsSinceEpoch}.png';
      final String filePath = '${(await imagesDir).path}/$fileName';

      await File(filePath).writeAsBytes(bd.buffer.asUint8List());
      return filePath;
    } finally {
      raster?.dispose();
      codec.dispose();
    }
  }

  /// Save a model file to the app's models directory
  static Future<String> saveModel(List<int> modelData, String extension) async {
    final String fileName =
        'model_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final String filePath = '${(await modelsDir).path}/$fileName';

    await File(filePath).writeAsBytes(modelData);
    return filePath;
  }

  /// Download a file from a URL
  static Future<List<int>> downloadFile(String url) async {
    final http.Response response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to download file: ${response.statusCode}');
    }
  }

  /// Clean up temporary files
  static Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFiles = await tempDir.list().toList();

      for (final entity in tempFiles) {
        if (entity is File) {
          await entity.delete();
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up temp files: $e');
    }
  }
}
