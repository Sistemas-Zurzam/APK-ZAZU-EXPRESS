import 'package:flutter_test/flutter_test.dart';
import 'package:zazu_driver/models/route_geometry.dart';

void main() {
  test('lee la respuesta directa de mi-ruta', () {
    final geometry = RouteGeometry.fromJson({
      'polylines': ['abc', 'def'],
      'completa': true,
    });

    expect(geometry.polylines, ['abc', 'def']);
    expect(geometry.complete, isTrue);
  });

  test('admite una respuesta envuelta en data', () {
    final geometry = RouteGeometry.fromJson({
      'data': {
        'polylines': ['abc'],
        'completa': false,
      },
    });

    expect(geometry.polylines, ['abc']);
    expect(geometry.complete, isFalse);
  });
}
