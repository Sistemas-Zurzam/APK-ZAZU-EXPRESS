import 'package:flutter_test/flutter_test.dart';
import 'package:zazu_driver/core/google_polyline.dart';

void main() {
  test('decodifica una polyline de Google con precisión 5', () {
    final points = decodeGooglePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');

    expect(points, hasLength(3));
    expect(points[0].latitude, closeTo(38.5, 0.00001));
    expect(points[0].longitude, closeTo(-120.2, 0.00001));
    expect(points[2].latitude, closeTo(43.252, 0.00001));
    expect(points[2].longitude, closeTo(-126.453, 0.00001));
  });

  test('une tramos eliminando el punto compartido', () {
    const first = '_p~iF~ps|U_ulLnnqC';
    const second = '_flwFn`faV_mqNvxq`@';

    final points = decodeGooglePolylines([first, second]);

    expect(points, hasLength(3));
    expect(points[1].latitude, closeTo(40.7, 0.00001));
    expect(points[2].latitude, closeTo(43.252, 0.00001));
  });

  test('mantiene los tramos separados para no dibujar uniones rectas', () {
    const first = '_p~iF~ps|U_ulLnnqC';
    const second = '_flwFn`faV_mqNvxq`@';

    final segments = decodeGooglePolylineSegments([first, second]);

    expect(segments, hasLength(2));
    expect(segments[0], hasLength(2));
    expect(segments[1], hasLength(2));
  });

  test('rechaza una polyline incompleta', () {
    expect(() => decodeGooglePolyline('_'), throwsFormatException);
  });
}
