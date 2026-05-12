import 'package:flutter/material.dart';

/// Горизонтальный выбор PNG-оправы по путям из [pubspec.yaml] (`assets/...`).
///
/// Вынесен из экранов 2D/ live, чтобы не дублировать верстку и логику выделения.
class GlassesPickerStrip extends StatelessWidget {
  const GlassesPickerStrip({
    super.key,
    required this.glassesAssets,
    required this.selectedGlassesPath,
    required this.onSelectGlasses,
    this.enabled = true,
  });

  /// Список путей к PNG в `assets/`.
  final List<String> glassesAssets;

  /// Текущий выбранный путь или null, если очки ещё не выбраны.
  final String? selectedGlassesPath;

  /// Колбэк при тапе по варианту.
  final ValueChanged<String> onSelectGlasses;

  /// Отключает тапы (например, пока идёт загрузка/сканирование на фото-экране).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: glassesAssets.length,
        itemBuilder: (context, index) {
          final path = glassesAssets[index];
          final isSelected = selectedGlassesPath == path;
          return GestureDetector(
            onTap: enabled ? () => onSelectGlasses(path) : null,
            child: Container(
              margin: const EdgeInsets.all(8),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue[100] : Colors.grey[200],
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF2196F3)
                      : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text('Очки ${index + 1}', textAlign: TextAlign.center),
              ),
            ),
          );
        },
      ),
    );
  }
}
