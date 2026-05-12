import 'package:flutter_test/flutter_test.dart';
import 'package:test_google_mlkit/face_tracking/glasses_2d_geometry.dart';
import 'package:test_google_mlkit/face_tracking/glasses_try_on_calibration.dart';

void main() {
  group('facialBreadthPx', () {
    test('предпочитает уши и не опускается ниже порога от bounding box', () {
      expect(
        facialBreadthPx(boxWidthPx: 100, earSpanPx: 200, cheekSpanPx: 150),
        200,
      );
      // Если «сырой» размах меньше коробки — подтягиваем не ниже 0.94 * box.
      expect(
        facialBreadthPx(boxWidthPx: 100, earSpanPx: 80, cheekSpanPx: null),
        100 * Glasses2DCalibration.facialBreadthMinToBoxFactor,
      );
    });

    test('без ушей использует скулы', () {
      expect(
        facialBreadthPx(boxWidthPx: 100, earSpanPx: null, cheekSpanPx: 180),
        180,
      );
    });

    test(
      'если только бокс — raw равен ширине бокса (она уже >= порога 0.94 * box)',
      () {
        expect(
          facialBreadthPx(boxWidthPx: 100, earSpanPx: null, cheekSpanPx: null),
          100,
        );
      },
    );
  });

  group('glassesWidthPx', () {
    test('берёт max(IPD-множитель, breadth-множитель) в пределах clamp', () {
      const ipd = 50.0;
      const breadth = 220.0;
      const box = 200.0;
      final w = glassesWidthPx(
        eyeDistancePx: ipd,
        facialBreadthPx: breadth,
        boxWidthPx: box,
      );
      final fromIpd = ipd * Glasses2DCalibration.eyeDistanceWidthFactor;
      final fromBreadth =
          breadth * Glasses2DCalibration.frameWidthToFacialBreadth;
      final expectedMax = fromIpd > fromBreadth ? fromIpd : fromBreadth;
      expect(w, expectedMax);
      final cap =
          (box > breadth ? box : breadth) *
          Glasses2DCalibration.maxWidthOverBreadthFactor;
      expect(w <= cap, true);
    });

    test('segmentLengthPx считает евклидову длину', () {
      expect(segmentLengthPx(0, 0, 3, 4), 5);
    });

    test(
      'очень малое IPD и большой размах лица: ширина не ниже minWidthToIpdFactor * ipd',
      () {
        // Имитация «профиль»: межзрачковое маленькое, но лицо широкое по ушам/боксу.
        const ipd = 8.0;
        const breadth = 220.0;
        const box = 200.0;
        final w = glassesWidthPx(
          eyeDistancePx: ipd,
          facialBreadthPx: breadth,
          boxWidthPx: box,
        );
        final minByIpd = ipd * Glasses2DCalibration.minWidthToIpdFactor;
        expect(w >= minByIpd, true);
        final cap =
            (box > breadth ? box : breadth) *
            Glasses2DCalibration.maxWidthOverBreadthFactor;
        expect(w <= cap, true);
      },
    );
  });
}
