import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

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
      debugPrint('Error loading glasses image: $e');
      if (!mounted) return;
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

      // Если выбраны очки и изображение загружено, рисуем их на лице.
      if (glassesImage != null) {
        _drawGlassesOnFace(canvas, face, glassesImage!);
      }
    }
  }

  void _drawGlassesOnFace(ui.Canvas canvas, Face face, ui.Image glassesImage) {
    // Получаем ключевые точки глаз
    final leftEyeLandmark = face.landmarks[FaceLandmarkType.leftEye];
    final rightEyeLandmark = face.landmarks[FaceLandmarkType.rightEye];

    if (leftEyeLandmark == null || rightEyeLandmark == null) return;

    // Получаем координаты точек, которые вернул ML Kit.
    final leftEye = leftEyeLandmark.position;
    final rightEye = rightEyeLandmark.position;

    // На некоторых изображениях/камерах точки могут прийти "зеркально" по X.
    // Явно определяем левую и правую точку, чтобы геометрия была стабильной.
    final leftMostEye = leftEye.x <= rightEye.x ? leftEye : rightEye;
    final rightMostEye = leftEye.x <= rightEye.x ? rightEye : leftEye;

    // Евклидово расстояние между глазами устойчивее, чем только разница по X.
    // Так размер очков корректно учитывает наклон головы.
    final dx = rightMostEye.x - leftMostEye.x;
    final dy = rightMostEye.y - leftMostEye.y;
    final eyeDistance = math.sqrt(dx * dx + dy * dy);

    // Ширину очков масштабируем относительно межглазного расстояния.
    // Коэффициент 2.3 оставляем как базовую калибровку под текущие ассеты.
    final glassesWidth = eyeDistance * 2.3;

    // Высоту считаем по реальному aspect ratio PNG, чтобы не "сплющивать" модель.
    final glassesAspect = glassesImage.height / glassesImage.width;
    final glassesHeight = glassesWidth * glassesAspect;

    // Центр очков размещаем между глазами.
    final centerX = (leftMostEye.x + rightMostEye.x) / 2;
    // Небольшой вертикальный оффсет оставляем параметром калибровки:
    // отрицательное значение поднимает очки, положительное опускает.
    const verticalOffsetFactor = -0.02;
    final centerY = (leftMostEye.y + rightMostEye.y) / 2 + (glassesHeight * verticalOffsetFactor);

    // Угол наклона очков должен совпадать с линией глаз.
    // atan2 корректно работает во всех квадрантах и не ломается при dx ~= 0.
    final eyeAngle = math.atan2(dy, dx);

    // Порядок операций в матрице принципиален:
    // 1) переносим систему координат в центр очков;
    // 2) поворачиваем относительно этого центра;
    // 3) смещаем в левый верхний угол целевого прямоугольника.
    // Такой порядок гарантирует, что очки вращаются "вокруг лица", а не вокруг (0,0).
    final matrix = Matrix4.identity()
      ..translateByDouble(centerX, centerY, 0, 1)
      ..rotateZ(eyeAngle)
      ..translateByDouble(-glassesWidth / 2, -glassesHeight / 2, 0, 1);

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
