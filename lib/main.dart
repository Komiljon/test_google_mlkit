import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'screens/glasses_try_on_photo_screen.dart';

/// Точка входа: получаем список камер и стартуем примерку.
///
/// Если камер нет (эмулятор без камеры / отказ в разрешениях на старте),
/// показываем заглушку вместо падения на `cameras.first`.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  List<CameraDescription> cameras = const [];
  try {
    cameras = await availableCameras();
  } catch (e, st) {
    debugPrint('availableCameras: $e\n$st');
  }
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.cameras});

  final List<CameraDescription> cameras;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Virtual Glasses Try-On',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: cameras.isEmpty
          ? const NoCameraAvailableHome()
          : GlassesTryOnPhotoScreen(allCameras: cameras),
    );
  }
}

/// Экран-заглушка, если [availableCameras] вернул пустой список или бросил исключение.
class NoCameraAvailableHome extends StatelessWidget {
  const NoCameraAvailableHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Virtual Glasses Try-On')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Камера недоступна на этом устройстве.\n'
            'Проверьте эмулятор с камерой или разрешения в настройках.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
