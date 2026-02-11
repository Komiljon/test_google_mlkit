import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors; // Добавляем импорт для Matrix4

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
  ui.Image? _glassesImage;

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

  Future<void> _selectGlasses(String assetPath) async {
    try {
      // Загружаем изображение очков
      final ByteData data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();

      setState(() {
        _selectedGlasses = assetPath;
        _glassesImage = frame.image;
      });
    } catch (e) {
      print('Error loading glasses image: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки очков: $e')));
    }
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
                  ? const Text('Выберите изображение', style: TextStyle(fontSize: 18))
                  : FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: _imageSize!.width,
                        height: _imageSize!.height,
                        child: CustomPaint(
                          painter: FacePainter(faceList: _faces, image: _image!, glassesImage: _glassesImage),
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
                    decoration: BoxDecoration(
                      color: _selectedGlasses == glassesAssets[index] ? Colors.blue[100] : Colors.grey[200],
                      border: Border.all(
                        color: _selectedGlasses == glassesAssets[index] ? Colors.blue : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Text('Очки ${index + 1}', textAlign: TextAlign.center)),
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

class FacePainter extends CustomPainter {
  final List<Face> faceList;
  final ui.Image image;
  final ui.Image? glassesImage;

  FacePainter({required this.faceList, required this.image, this.glassesImage});

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

      // Если выбраны очки и изображение загружено, рисуем их на лице
      if (glassesImage != null && face.landmarks != null) {
        _drawGlassesOnFace(canvas, face, glassesImage!);
      }
    }
  }

  void _drawGlassesOnFace(ui.Canvas canvas, Face face, ui.Image glassesImage) {
    // Получаем ключевые точки глаз
    final leftEyeLandmark = face.landmarks?[FaceLandmarkType.leftEye];
    final rightEyeLandmark = face.landmarks?[FaceLandmarkType.rightEye];

    if (leftEyeLandmark == null || rightEyeLandmark == null) return;

    // Получаем координаты точек
    final leftEye = leftEyeLandmark.position;
    final rightEye = rightEyeLandmark.position;

    // Рассчитываем позицию и размер очков
    final eyeDistance = rightEye.x - leftEye.x;
    final glassesWidth = eyeDistance * 2.3; // Ширина очков
    final glassesHeight = glassesWidth * 0.4; // Пропорции очков

    // Центр очков - между глазами
    final centerX = (leftEye.x + rightEye.x) / 2;
    final centerY = (leftEye.y + rightEye.y) / 2 - (glassesHeight * 0.1); // Смещение вверх

    // Рассчитываем угол наклона линии глаз
    final dx = rightEye.x - leftEye.x;
    final dy = rightEye.y - leftEye.y;
    final eyeAngle = -dy / dx * 0.1; // Небольшой коэффициент для коррекции

    // Создаем матрицу трансформации
    final matrix = Matrix4.identity()
      ..translate(centerX, centerY)
      ..rotateZ(eyeAngle)
      ..translate(-glassesWidth / 2, -glassesHeight / 2);

    // Рисуем очки
    final srcRect = ui.Rect.fromLTWH(0, 0, glassesImage.width.toDouble(), glassesImage.height.toDouble());
    final dstRect = ui.Rect.fromLTWH(0, 0, glassesWidth, glassesHeight);

    canvas.save();
    canvas.transform(matrix.storage);
    canvas.drawImageRect(glassesImage, srcRect, dstRect, ui.Paint());
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FacePainter oldDelegate) {
    return oldDelegate.faceList != faceList || oldDelegate.image != image || oldDelegate.glassesImage != glassesImage;
  }
}
