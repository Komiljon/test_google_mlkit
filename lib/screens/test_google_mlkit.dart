import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

import 'glasses_try_on_3d_screen.dart';

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
    // На одиночном снимке из галереи/камеры «accurate» даёт более стабильные landmarks
    // (уши, скулы) и углы Эйлера — для примерки 2D это важнее скорости, чем в видеопотоке.
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: true,
      ),
    );
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
      appBar: AppBar(
        title: const Text('Virtual Glasses Try-On'),
        actions: [
          IconButton(
            tooltip: 'Открыть 3D режим',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GlassesTryOn3DScreen(camera: widget.camera),
                ),
              );
            },
            icon: const Icon(Icons.view_in_ar),
          ),
        ],
      ),
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
          // Явный переключатель режимов: текущий экран — 2D PNG; 3D GLB — отдельный экран.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.image_outlined, size: 18),
                  label: const Text('Сейчас: 2D (PNG очки)'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GlassesTryOn3DScreen(camera: widget.camera),
                      ),
                    );
                  },
                  icon: const Icon(Icons.view_in_ar),
                  label: const Text('3D примерка (GLB)'),
                ),
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

    for (final face in faceList) {
      // Если выбраны очки и изображение загружено, рисуем их на лице.
      if (glassesImage != null) {
        _drawGlassesOnFace(canvas, face, glassesImage!);
      }
    }
  }

  void _drawGlassesOnFace(ui.Canvas canvas, Face face, ui.Image glassesImage) {
    // --- Глаза: якорь линз и угол наклона (roll) ---
    final leftEyeLandmark = face.landmarks[FaceLandmarkType.leftEye];
    final rightEyeLandmark = face.landmarks[FaceLandmarkType.rightEye];

    if (leftEyeLandmark == null || rightEyeLandmark == null) return;

    final leftEye = leftEyeLandmark.position;
    final rightEye = rightEyeLandmark.position;

    // На некоторых изображениях/камерах точки могут прийти "зеркально" по X.
    final leftMostEye = leftEye.x <= rightEye.x ? leftEye : rightEye;
    final rightMostEye = leftEye.x <= rightEye.x ? rightEye : leftEye;

    final dx = rightMostEye.x - leftMostEye.x;
    final dy = rightMostEye.y - leftMostEye.y;
    // Межзрачковое расстояние (IPD) в пикселях — главный масштаб для расстояния между линзами.
    final eyeDistance = math.sqrt(dx * dx + dy * dy);
    if (eyeDistance <= 1e-6) return;

    // --- Горизонтальный размах лица: ближе к «от виска до виска», чем просто boundingBox ---
    // ML Kit отдаёт `leftEar`/`rightEar` и `leftCheek`/`rightCheek`. Расстояние между ушными
    // точками обычно хорошо коррелирует с шириной оправы; скулы — запасной вариант, если уши null
    // (профиль, перекрытие волосами). Bounding box лица оставляем как нижнюю границу, т.к. иногда
    // коробка уже, чем визуальная ширина скул.
    final leftEar = face.landmarks[FaceLandmarkType.leftEar]?.position;
    final rightEar = face.landmarks[FaceLandmarkType.rightEar]?.position;
    final leftCheek = face.landmarks[FaceLandmarkType.leftCheek]?.position;
    final rightCheek = face.landmarks[FaceLandmarkType.rightCheek]?.position;

    double? earSpanPx;
    if (leftEar != null && rightEar != null) {
      final ex = (rightEar.x - leftEar.x).toDouble();
      final ey = (rightEar.y - leftEar.y).toDouble();
      earSpanPx = math.sqrt(ex * ex + ey * ey);
    }

    double? cheekSpanPx;
    if (leftCheek != null && rightCheek != null) {
      final cx = (rightCheek.x - leftCheek.x).toDouble();
      final cy = (rightCheek.y - leftCheek.y).toDouble();
      cheekSpanPx = math.sqrt(cx * cx + cy * cy);
    }

    final boxWidth = face.boundingBox.width;

    // Предпочитаем уши, иначе скулы, иначе ширину бокса — это оценка «ширины лица» в кадре.
    final double facialBreadthRaw = earSpanPx ?? cheekSpanPx ?? boxWidth;
    // Если детектор «сжал» уши/скулы (редкий кадр), не опускаемся сильно ниже коробки.
    final double facialBreadth = math.max(facialBreadthRaw, boxWidth * 0.94);

    // Ширина PNG-оправы: две независимые оценки — по IPD (линзы) и по ширине лица (затемки).
    // Раньше использовался clamp к 0.72–0.85 * box: верхняя граница часто **занижала** оправу
    // относительно реальных висков. Берём max(IPD-based, breadth-based) и мягко ограничиваем сверху.
    const eyeDistanceWidthFactor = 2.38;
    final widthFromInterpupillary = eyeDistance * eyeDistanceWidthFactor;
    // Доля от размаха лица: оправа чуть уже полного «висок-висок», но ближе к 90%+, чем к 80%.
    const frameWidthToFacialBreadth = 0.93;
    final widthFromFacialBreadth = facialBreadth * frameWidthToFacialBreadth;

    var glassesWidth = math.max(widthFromInterpupillary, widthFromFacialBreadth);
    final maxReasonableWidth = math.max(boxWidth, facialBreadth) * 1.04;
    glassesWidth = glassesWidth.clamp(eyeDistance * 2.0, maxReasonableWidth);

    // Высота строго из пропорций ассета.
    final glassesAspect = glassesImage.height / glassesImage.width;
    final glassesHeight = glassesWidth * glassesAspect;

    // --- Центр: между глазами + лёгкий перенос к переносице (как в 3D-слое проекта) ---
    final eyesCenterX = (leftMostEye.x + rightMostEye.x) / 2;
    final eyesCenterY = (leftMostEye.y + rightMostEye.y) / 2;
    final noseBaseLm = face.landmarks[FaceLandmarkType.noseBase];
    double centerX = eyesCenterX;
    double centerY = eyesCenterY;
    if (noseBaseLm != null) {
      const noseBridgeBlend = 0.06;
      final nb = noseBaseLm.position;
      centerX = eyesCenterX * (1 - noseBridgeBlend) + nb.x * noseBridgeBlend;
      centerY = eyesCenterY * (1 - noseBridgeBlend) + nb.y * noseBridgeBlend;
    }
    // Смещение по вертикали: положительное — вниз в координатах изображения.
    // Уменьшено относительно старого 0.055, чтобы мост не «сидел» слишком низко на носу.
    const verticalOffsetFactor = 0.028;
    centerY += glassesHeight * verticalOffsetFactor;

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
