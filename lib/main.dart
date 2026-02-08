import 'dart:async';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:camera_avfoundation/camera_avfoundation.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  const MyApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Virtual Glasses Try-On',
      theme: ThemeData(primarySwatch: Colors.blue, visualDensity: VisualDensity.adaptivePlatformDensity),
      home: GlassesTryOnScreen(camera: camera),
    );
  }
}

class GlassesTryOnScreen extends StatefulWidget {
  final CameraDescription camera;

  const GlassesTryOnScreen({super.key, required this.camera});

  @override
  State<GlassesTryOnScreen> createState() => _GlassesTryOnScreenState();
}

class _GlassesTryOnScreenState extends State<GlassesTryOnScreen> {
  late FaceDetector _faceDetector;
  List<Face> _faces = [];
  late ImagePicker _picker;
  ui.Image? _image;
  Size? _imageSize;
  String? _selectedGlasses;

  final List<String> glassesAssets = ['assets/glasses1.png', 'assets/glasses2.png', 'assets/glasses3.png'];

  @override
  void initState() {
    super.initState();
    _picker = ImagePicker();
    _faceDetector = FaceDetector(options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast, enableLandmarks: true));
  }

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _getAndScanImage({final bool? isFromCamera}) async {
    setState(() {
      _image = null;
      _faces = [];
      _imageSize = null;
    });

    final imageXFile = await _picker.pickImage(
      source: isFromCamera != null && isFromCamera ? ImageSource.camera : ImageSource.gallery,
    );

    if (imageXFile != null) {
      final inputImage = InputImage.fromFilePath(imageXFile.path);
      final facesList = await _faceDetector.processImage(inputImage);
      final imageAsBytes = await imageXFile.readAsBytes();
      final imageDecoded = await decodeImageFromList(imageAsBytes);

      setState(() {
        _faces = facesList;
        _image = imageDecoded;
        _imageSize = Size(imageDecoded.width.toDouble(), imageDecoded.height.toDouble());
      });
    }
  }

  void _selectGlasses(String assetPath) {
    setState(() {
      _selectedGlasses = assetPath;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Virtual Glasses Try-On')),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _image == null
                  ? const Text('Выберите изображение')
                  : FittedBox(
                      child: SizedBox(
                        width: _imageSize!.width,
                        height: _imageSize!.height,
                        child: CustomPaint(
                          painter: FacePainter(faceList: _faces, image: _image!, glassesAsset: _selectedGlasses),
                        ),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: () => _getAndScanImage(isFromCamera: true), child: const Text('Камера')),
                ElevatedButton(onPressed: () => _getAndScanImage(isFromCamera: false), child: const Text('Галерея')),
              ],
            ),
          ),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: glassesAssets.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _selectGlasses(glassesAssets[index]),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    width: 80,
                    height: 80,
                    color: _selectedGlasses == glassesAssets[index] ? Colors.blue[100] : Colors.grey[200],
                    child: Center(child: Text('Очки ${index + 1}')),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// КЛАСС FacePainter - ДОБАВЬТЕ ЭТОТ КОД
class FacePainter extends CustomPainter {
  final List<Face> faceList;
  final ui.Image image;
  final String? glassesAsset;
  ui.Image? glassesImage;

  FacePainter({required this.faceList, required this.image, this.glassesAsset});

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    // Рисуем исходное изображение
    canvas.drawImage(image, ui.Offset.zero, ui.Paint());

    // Рисуем прямоугольники вокруг лиц (для отладки)
    final paint = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = ui.Color.fromARGB(255, 255, 0, 0);

    for (final face in faceList) {
      final rect = face.boundingBox;
      canvas.drawRect(rect, paint);

      // Если выбраны очки, рисуем их на лице
      if (glassesAsset != null) {
        // Здесь нужно добавить код для рисования очков
        // Для этого нужно получить координаты глаз из face.landmarks
        // и разместить очки соответствующим образом
      }
    }
  }

  @override
  bool shouldRepaint(covariant FacePainter oldDelegate) {
    return oldDelegate.faceList != faceList || oldDelegate.image != image || oldDelegate.glassesAsset != glassesAsset;
  }
}
