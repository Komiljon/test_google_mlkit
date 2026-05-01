import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Рисует [ui.Image] в координатах «один к одному» с системой ML Kit:
/// точка (0,0) — верхний левый угол кадра, как у `Face.boundingBox` и landmarks.
///
/// Так надёжнее, чем [RawImage]: не зависит от дефолтного `fit` и даёт те же оси,
/// что и при отладочной рамке лица поверх этого слоя.
class DecodedImagePainter extends CustomPainter {
  DecodedImagePainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImage(image, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(covariant DecodedImagePainter oldDelegate) =>
      oldDelegate.image != image;
}
