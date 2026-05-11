import 'package:flutter/material.dart';
import 'package:test_google_mlkit/screens/glasses_try_on_screen.dart';

void main() {
  runApp(const GlassesTryOnApp());
}

/// Корневая оболочка: тема и домашний экран примерки вынесен в [GlassesTryOnScreen].
class GlassesTryOnApp extends StatelessWidget {
  const GlassesTryOnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Примерка очков - 3D AR',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const GlassesTryOnScreen(),
    );
  }
}
