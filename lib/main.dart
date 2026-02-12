import 'package:flutter/material.dart';
import 'package:flutter_3d_ar_converter/flutter_3d_ar_converter.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '3D AR Converter Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final ImageTo3DConverter _converter = ImageTo3DConverter();
  ModelData? _modelData;
  bool _isConverting = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.storage].request();
  }

  Future<void> _pickAndConvertImage(ModelType modelType) async {
    setState(() {
      _isConverting = true;
      _statusMessage = 'Selecting image...';
    });

    try {
      final imageFile = await _converter.pickImage();

      if (imageFile == null) {
        setState(() {
          _isConverting = false;
          _statusMessage = 'No image selected';
        });
        return;
      }

      setState(() {
        _statusMessage = 'Converting image to 3D model...';
      });

      final modelData = await _converter.convertImageTo3D(imageFile, modelType);

      setState(() {
        _modelData = modelData;
        _isConverting = false;
        _statusMessage = modelData != null ? 'Conversion complete!' : 'Conversion failed';
      });
    } catch (e) {
      setState(() {
        _isConverting = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  void _openARViewer() {
    if (_modelData == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ARViewer(
          modelData: _modelData!,
          onARViewCreated: () {
            debugPrint('AR view created');
          },
          onObjectPlaced: (node) {
            debugPrint('Object placed');
          },
        ),
      ),
    );
  }

  void _openFaceARViewer() {
    if (_modelData == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceARViewer(
          modelData: _modelData!,
          onARViewCreated: () {
            debugPrint('Face AR view created');
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('3D AR Converter Demo')),
      body: Center(
        child: _isConverting
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(_statusMessage)],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Convert images to 3D models', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.chair),
                    label: const Text('Convert Furniture Image'),
                    onPressed: () => _pickAndConvertImage(ModelType.furniture),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.face),
                    label: const Text('Convert Glasses Image'),
                    onPressed: () => _pickAndConvertImage(ModelType.glasses),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.view_in_ar),
                    label: const Text('Convert Generic Object'),
                    onPressed: () => _pickAndConvertImage(ModelType.object),
                  ),
                  const SizedBox(height: 32),
                  if (_modelData != null) ...[
                    Text(
                      'Model created: ${_modelData!.type.toString().split('.').last}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.view_in_ar),
                      label: const Text('View in AR'),
                      onPressed: _openARViewer,
                    ),
                    const SizedBox(height: 16),
                    if (_modelData!.type == ModelType.glasses)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.face),
                        label: const Text('Try on Glasses'),
                        onPressed: _openFaceARViewer,
                      ),
                  ],
                  const SizedBox(height: 16),
                  Text(_statusMessage),
                ],
              ),
      ),
    );
  }
}
