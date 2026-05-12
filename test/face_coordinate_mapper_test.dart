import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:test_google_mlkit/face_tracking/face_coordinate_mapper.dart';
import 'package:vector_math/vector_math_64.dart' show Vector4;

void main() {
  group('FaceCoordinateMapper.uprightImageSize', () {
    test('при 90° меняет ширину и высоту местами', () {
      const buf = Size(1280, 720);
      expect(
        FaceCoordinateMapper.uprightImageSize(
          buf,
          InputImageRotation.rotation90deg,
        ),
        const Size(720, 1280),
      );
    });
  });

  group('FaceCoordinateMapper.bufferToPreview', () {
    test('rotation0 + cover: центр буфера попадает в центр превью', () {
      const buffer = Size(100, 50);
      const preview = Size(200, 100);
      final c = FaceCoordinateMapper.bufferToPreview(
        pointInBuffer: const Offset(50, 25),
        bufferSize: buffer,
        rotation: InputImageRotation.rotation0deg,
        previewSize: preview,
        mirrorPreviewHorizontally: false,
      );
      expect(c, const Offset(100, 50));
    });

    test('mirror по X отражает относительно ширины превью', () {
      const buffer = Size(100, 100);
      const preview = Size(200, 200);
      final a = FaceCoordinateMapper.bufferToPreview(
        pointInBuffer: const Offset(10, 10),
        bufferSize: buffer,
        rotation: InputImageRotation.rotation0deg,
        previewSize: preview,
        mirrorPreviewHorizontally: false,
      );
      final b = FaceCoordinateMapper.bufferToPreview(
        pointInBuffer: const Offset(10, 10),
        bufferSize: buffer,
        rotation: InputImageRotation.rotation0deg,
        previewSize: preview,
        mirrorPreviewHorizontally: true,
      );
      expect(b.dx, preview.width - a.dx);
      expect(b.dy, a.dy);
    });
  });

  group('FaceCoordinateMapper.bufferToPreviewMatrix4', () {
    test(
      'умножение на углы единичного квадрата совпадает с bufferToPreview',
      () {
        const buffer = Size(80, 60);
        const preview = Size(400, 300);
        const mirror = false;
        const rot = InputImageRotation.rotation0deg;

        final m = FaceCoordinateMapper.bufferToPreviewMatrix4(
          bufferSize: buffer,
          rotation: rot,
          previewSize: preview,
          mirrorPreviewHorizontally: mirror,
        );

        Offset mapPoint(double x, double y) =>
            FaceCoordinateMapper.bufferToPreview(
              pointInBuffer: Offset(x, y),
              bufferSize: buffer,
              rotation: rot,
              previewSize: preview,
              mirrorPreviewHorizontally: mirror,
            );

        final p00 = mapPoint(0, 0);
        final p10 = mapPoint(1, 0);
        final p01 = mapPoint(0, 1);

        final o00 = m * Vector4(0, 0, 0, 1);
        final o10 = m * Vector4(1, 0, 0, 1);
        final o01 = m * Vector4(0, 1, 0, 1);

        expect(o00.x, closeTo(p00.dx, 1e-6));
        expect(o00.y, closeTo(p00.dy, 1e-6));
        expect(o10.x, closeTo(p10.dx, 1e-6));
        expect(o10.y, closeTo(p10.dy, 1e-6));
        expect(o01.x, closeTo(p01.dx, 1e-6));
        expect(o01.y, closeTo(p01.dy, 1e-6));
      },
    );
  });
}
