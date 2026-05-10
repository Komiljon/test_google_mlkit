import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Результат нормализации снимка из галереи/камеры для ML Kit и для UI.
///
/// EXIF-ориентация «запекается» в пиксели (`bakeOrientation`), чтобы координаты
/// лиц из `FaceDetector` совпадали с тем, что рисует тот же JPEG через `decodeImageFromList`.
class PreparedMlKitImage {
  /// JPEG (или исходные байты), уже с учётом поворота по EXIF — их же декодируем во Flutter UI.
  final Uint8List bytesForDecodeAndMlKit;

  /// Временный файл с теми же байтами — для [InputImage.fromFilePath] на нативной стороне ML Kit.
  final File tempJpegFile;

  PreparedMlKitImage({required this.bytesForDecodeAndMlKit, required this.tempJpegFile});

  /// Высвободить временный файл после использования (можно вызвать из `finally`).
  Future<void> deleteTempFile() async {
    try {
      if (await tempJpegFile.exists()) {
        await tempJpegFile.delete();
      }
    } catch (_) {
      // Игнорируем гонки ОС; файл в temp и будет очищен системой.
    }
  }
}

/// Готовит байты и файл для ML Kit + отображения из сырых байтов файла с камеры/галереи.
///
/// Если декодирование через `package:image` не удалось, возвращаем исходные байты и копию во временный файл.
Future<PreparedMlKitImage> prepareImageBytesForMlKit(Uint8List rawBytes, {String suffix = 'pick'}) async {
  final dir = await getTemporaryDirectory();
  final ts = DateTime.now().millisecondsSinceEpoch;

  img.Image? decoded = img.decodeImage(rawBytes);
  if (decoded != null) {
    final baked = img.bakeOrientation(decoded);
    final jpg = Uint8List.fromList(img.encodeJpg(baked, quality: 92));
    final file = File(p.join(dir.path, 'mlkit_${suffix}_$ts.jpg'));
    await file.writeAsBytes(jpg);
    return PreparedMlKitImage(bytesForDecodeAndMlKit: jpg, tempJpegFile: file);
  }

  // Резерв: без поворота, но консистентный путь — один файл и те же байты для UI и ML.
  final ext = '.jpg';
  final file = File(p.join(dir.path, 'mlkit_${suffix}_raw_$ts$ext'));
  await file.writeAsBytes(rawBytes);
  return PreparedMlKitImage(bytesForDecodeAndMlKit: rawBytes, tempJpegFile: file);
}

/// Строит [InputImage] из уже подготовленного временного JPEG (путь обязан быть с правильной ориентацией пикселей).
InputImage inputImageFromPreparedFile(File file) => InputImage.fromFilePath(file.path);

/// Декодирует подготовленный JPEG/PNG в [ui.Image] для отрисовки (`CustomPaint` и т.д.).
///
/// В новых SDK `decodeImageFromList` может отличаться по API; `instantiateImageCodec` стабилен.
Future<ui.Image> decodePreparedBytesToUiImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}
