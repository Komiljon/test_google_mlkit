import 'package:flutter/material.dart';
import 'package:flutter_3d_ar_converter/flutter_3d_ar_converter.dart';

import 'package:test_google_mlkit/data/glasses_catalog.dart';
import 'package:test_google_mlkit/models/glasses_catalog_item.dart';
import 'package:test_google_mlkit/screens/legacy_converter_lab_screen.dart';
import 'package:test_google_mlkit/services/glasses_asset_to_documents.dart';
import 'package:test_google_mlkit/widgets/resolving_face_ar_viewer.dart';

/// Главная витрина: карточки моделей + переход в Face AR с подготовкой GLB на диске устройства.
///
/// Дополнительное меню содержит лабораторию старого конвертера (furniture/object) — по плану только для разработки.
class GlassesCatalogScreen extends StatefulWidget {
  const GlassesCatalogScreen({super.key});

  @override
  State<GlassesCatalogScreen> createState() => _GlassesCatalogScreenState();
}

class _GlassesCatalogScreenState extends State<GlassesCatalogScreen> {
  final ImageTo3DConverter _imageConverter = ImageTo3DConverter();
  bool _isBusy = false;
  String _status = '';

  Flutter3dArConverter get _arSdk => Flutter3dArConverter();

  /// Показываем короткую подпись о доступности AR.
  String get _arSubtitle {
    final d = _arSdk.isARAvailable ? 'Да' : 'Нет';
    final f =
        _arSdk.isFaceTrackingAvailable ? 'Да' : 'нет / неизвестно до сессии';
    return 'AR: $d • Лицо (оценка SDK): $f';
  }

  Future<void> _tryOnBundled(GlassesCatalogItem item) async {
    setState(() {
      _isBusy = true;
      _status = 'Копируем ${item.title}…';
    });

    try {
      final model =
          await GlassesAssetToDocuments.prepareItem(item);
      if (!mounted) return;

      setState(() {
        _isBusy = false;
        _status = '';
      });

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ResolvingFaceARViewer(
            modelData: model,
            onArViewCreated: () {
              debugPrint('Face AR session live for ${item.id}');
            },
          ),
        ),
      );
    } catch (e, st) {
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _status = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось подготовить модель: $e')),
      );
    }
  }

  /// Fallback-сценарий из плана: загрузка PNG → заглушечная конвертация пакета → Face AR.
  ///
  /// Полезно как «лабораторный» путь, когда нужно быстро проверить конвейер без локального GLB.
  Future<void> _fallbackFromPhoto() async {
    setState(() {
      _isBusy = true;
      _status = 'Выберите фото очков в галерее…';
    });

    try {
      final image = await _imageConverter.pickImage();
      if (image == null) {
        setState(() {
          _isBusy = false;
          _status = '';
        });
        return;
      }

      setState(() {
        _status = 'Идёт демо-конвертация (может занять ~3 c)…';
      });

      final md = await _imageConverter.convertImageTo3D(
        image,
        ModelType.glasses,
      );

      setState(() {
        _isBusy = false;
        _status = '';
      });

      if (!mounted) return;
      if (md == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Демо-конвертер вернул пустой результат')),
        );
        return;
      }

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              ResolvingFaceARViewer(modelData: md),
        ),
      );
    } catch (e) {
      setState(() {
        _isBusy = false;
        _status = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка конвертации: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Примерка 3D-очков'),
        actions: [
          IconButton(
            tooltip: 'Состояние SDK',
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Состояние AR'),
                  content: Text(
                    '$_arSubtitle\nИнициализирован: '
                    '${_arSdk.isInitialized ? 'да' : 'нет'}',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
              child: const Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Меню разработчика',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.science),
              title: const Text('Лаборатория старого конвертера'),
              subtitle: const Text('мебель / объекты из фото'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const LegacyConverterLabScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 88),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: kGlassesCatalog.length,
              itemBuilder: (context, index) {
                final item = kGlassesCatalog[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.asset(
                          item.previewAssetPath,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.description,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _isBusy
                                  ? null
                                  : () => _tryOnBundled(item),
                              icon: const Icon(Icons.face_retouching_natural),
                              label: const Text('Примерить в AR'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : _fallbackFromPhoto,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Fallback: фото → демо-модель → AR'),
                ),
                if (_status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _status,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
          if (_isBusy)
            const IgnorePointer(
              child: SizedBox.expand(
                child: ColoredBox(
                  color: Color(0x33000000),
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Подождите…'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
