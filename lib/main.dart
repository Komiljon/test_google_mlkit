import 'package:flutter/material.dart';

import 'package:test_google_mlkit/screens/ar_bootstrap_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GlassesTryOnApp());
}

/// Корневой виджет приложения примерки очков.
class GlassesTryOnApp extends StatelessWidget {
  const GlassesTryOnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Примерка 3D-очков',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const ArBootstrapScreen(),
    );
  }
}
