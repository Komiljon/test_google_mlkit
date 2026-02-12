import 'package:flutter/material.dart';
import 'package:augen/augen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Virtual Glasses Try-On',
      theme: ThemeData(primarySwatch: Colors.blue, visualDensity: VisualDensity.adaptivePlatformDensity),
      home: ARScreen(),
    );
  }
}

class ARScreen extends StatefulWidget {
  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen> {
  AugenController? _controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AugenView(
        onViewCreated: _onARViewCreated,
        config: ARSessionConfig(planeDetection: true, lightEstimation: true, depthData: false, autoFocus: true),
      ),
    );
  }

  void _onARViewCreated(AugenController controller) {
    _controller = controller;
    _initializeAR();
  }

  Future<void> _initializeAR() async {
    // Check AR support
    final isSupported = await _controller!.isARSupported();
    if (!isSupported) {
      print('AR is not supported on this device');
      return;
    }

    // Initialize AR session
    await _controller!.initialize(ARSessionConfig(planeDetection: true, lightEstimation: true));

    // Listen to detected planes
    _controller!.planesStream.listen((planes) {
      print('Detected ${planes.length} planes');
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
