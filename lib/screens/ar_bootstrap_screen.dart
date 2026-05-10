import 'package:flutter/material.dart';
import 'package:flutter_3d_ar_converter/flutter_3d_ar_converter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:test_google_mlkit/screens/glasses_catalog_screen.dart';

/// Первый экран запуска: инициализирует `Flutter3dArConverter`, запрашивает базовые разрешения
/// и отправляет пользователя либо в каталог очков, либо показывает дружественное сообщение.
class ArBootstrapScreen extends StatefulWidget {
  const ArBootstrapScreen({super.key});

  @override
  State<ArBootstrapScreen> createState() => _ArBootstrapScreenState();
}

class _ArBootstrapScreenState extends State<ArBootstrapScreen> {
  Future<_BootstrapOutcome>? _outcomeFuture;

  @override
  void initState() {
    super.initState();
    _outcomeFuture = _runBootstrap();
  }

  /// Повторяем инициализацию, если после обновления настроек разрешений пользователь попробует ещё раз.
  Future<void> _restartBootstrap() async {
    setState(() {
      _outcomeFuture = _runBootstrap();
    });
  }

  Future<_BootstrapOutcome> _runBootstrap() async {
    await [Permission.camera, Permission.storage].request();

    final converter = Flutter3dArConverter();
    final initializedOk = await converter.initialize();

    return _BootstrapOutcome(
      initializedOk: initializedOk,
      converter: converter,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootstrapOutcome>(
      future: _outcomeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 24),
                  Text('Проверяем возможности дополненной реальности…'),
                ],
              ),
            ),
          );
        }

        final outcome = snapshot.data!;
        final c = outcome.converter;

        if (!outcome.initializedOk || !c.isARAvailable) {
          return Scaffold(
            appBar: AppBar(title: const Text('AR недоступен')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 64, color: Colors.orange),
                  const SizedBox(height: 16),
                  Text(
                    'На этом устройстве не удалось поднять AR-сессию '
                    '(или отсутствует ARCore / ARKit). '
                    'Всё равно можно открыть каталог, но Face AR скорее всего не заработает.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const GlassesCatalogScreen(),
                        ),
                      );
                    },
                    child: const Text('Перейти в каталог'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _restartBootstrap,
                    child: const Text('Проверить снова'),
                  ),
                ],
              ),
            ),
          );
        }

        return const GlassesCatalogScreen();
      },
    );
  }
}

class _BootstrapOutcome {
  final bool initializedOk;
  final Flutter3dArConverter converter;

  _BootstrapOutcome({
    required this.initializedOk,
    required this.converter,
  });
}
