// Типы [Vector3] / [Quaternion] берём из augen, чтобы совпадали с [ARNode.fromModel] без приведения.
import 'package:augen/augen.dart';

/// Одна пара очков для AR: путь к GLB в assets, трансформ на лице augen и **отдельная** картинка для карточки каталога.
///
/// [catalogPreviewAsset] — плоское PNG для горизонтального списка; не используется движком AR, только UI.
class ArGlassesModel {
  final String id;
  final String name;

  /// Путь `assets/...` к GLB/OBJ/… для [ARNode.fromModel]; `null` если слот только информационный (например .ply).
  final String? assetPath;

  /// PNG/JPEG в [pubspec.yaml] для превью в списке выбора; при `null` экран покажет запасную иконку.
  final String? catalogPreviewAsset;

  final bool isAvailable;
  final String? unavailableReason;

  /// Смещение в системе координат привязки «лицо» augen (подбирается под конкретный меш).
  final Vector3 localPosition;
  final Quaternion rotation;
  final Vector3 scale;

  ArGlassesModel({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.catalogPreviewAsset,
    required this.localPosition,
    required this.rotation,
    required this.scale,
  })  : isAvailable = true,
        unavailableReason = null;

  /// Элемент каталога без загрузки в AR (например формат не поддерживается плагином).
  ArGlassesModel.unavailablePreview({
    required this.id,
    required String title,
    required String reason,
    this.catalogPreviewAsset,
  })  : name = title,
        assetPath = null,
        isAvailable = false,
        unavailableReason = reason,
        localPosition = Vector3.zero(),
        rotation = Quaternion.identity(),
        scale = const Vector3(1, 1, 1);
}
