import 'package:flutter/material.dart';
import 'package:flutter_3d_ar_converter/flutter_3d_ar_converter.dart';

import 'package:test_google_mlkit/widgets/resolving_face_ar_viewer.dart';

/// Лабораторный экран из раннего демо: конвертация «мебели / объекта / очков» из фото.
///
/// Не входит в основной пользовательский поток, но помогает сравнить поведение пакета.
class LegacyConverterLabScreen extends StatefulWidget {
  const LegacyConverterLabScreen({super.key});

  @override
  State<LegacyConverterLabScreen> createState() =>
      _LegacyConverterLabScreenState();
}

class _LegacyConverterLabScreenState extends State<LegacyConverterLabScreen> {
  final ImageTo3DConverter _converter = ImageTo3DConverter();
  ModelData? _modelData;
  bool _isConverting = false;
  String _statusMessage = '';

  Future<void> _pickAndConvert(ModelType modelType) async {
    setState(() {
      _isConverting = true;
      _statusMessage = 'Выбор изображения…';
    });

    try {
      final imageFile = await _converter.pickImage();
      if (imageFile == null) {
        setState(() {
          _isConverting = false;
          _statusMessage = 'Файл не выбран';
        });
        return;
      }

      setState(() {
        _statusMessage = 'Демо-конвертация (≈3 c)…';
      });

      final modelData =
          await _converter.convertImageTo3D(imageFile, modelType);

      setState(() {
        _modelData = modelData;
        _isConverting = false;
        _statusMessage =
            modelData != null ? 'Готово' : 'Конвертация не удалась';
      });
    } catch (e) {
      setState(() {
        _isConverting = false;
        _statusMessage = 'Ошибка: $e';
      });
    }
  }

  void _openArViewer() {
    final data = _modelData;
    if (data == null) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ARViewer(
          modelData: data,
          onARViewCreated: () => debugPrint('AR view created'),
          onObjectPlaced: (_) => debugPrint('Object placed'),
        ),
      ),
    );
  }

  void _openFaceAr() {
    final data = _modelData;
    if (data == null || data.type != ModelType.glasses) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ResolvingFaceARViewer(modelData: data),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Лаборатория конвертера')),
      body: Center(
        child: _isConverting
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_statusMessage),
                ],
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      'Демо ветки ImageTo3DConverter',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.chair),
                      label: const Text('Конвертировать мебель'),
                      onPressed: () => _pickAndConvert(ModelType.furniture),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.face),
                      label: const Text('Конвертировать очки'),
                      onPressed: () => _pickAndConvert(ModelType.glasses),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.view_in_ar),
                      label: const Text('Конвертировать объект'),
                      onPressed: () => _pickAndConvert(ModelType.object),
                    ),
                    const SizedBox(height: 32),
                    if (_modelData != null) ...[
                      Text(
                        'Тип: ${_modelData!.type.name}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.view_in_ar),
                        label: const Text('AR сцена (мир)'),
                        onPressed: _openArViewer,
                      ),
                      if (_modelData!.type == ModelType.glasses) ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.face_retouching_natural),
                          label: const Text('Face AR (через Resolving*)'),
                          onPressed: _openFaceAr,
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),
                    Text(_statusMessage),
                  ],
                ),
              ),
      ),
    );
  }
}
