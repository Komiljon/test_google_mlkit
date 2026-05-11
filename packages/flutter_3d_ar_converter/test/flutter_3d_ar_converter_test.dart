import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_3d_ar_converter/flutter_3d_ar_converter.dart';

void main() {
  test('Flutter3dArConverter can be instantiated', () {
    final converter = Flutter3dArConverter();
    expect(converter, isNotNull);
    expect(converter, isA<Flutter3dArConverter>());
  });

  test('ModelType enum has expected values', () {
    expect(ModelType.values.length, 3);
    expect(ModelType.values, contains(ModelType.furniture));
    expect(ModelType.values, contains(ModelType.glasses));
    expect(ModelType.values, contains(ModelType.object));
  });
}
