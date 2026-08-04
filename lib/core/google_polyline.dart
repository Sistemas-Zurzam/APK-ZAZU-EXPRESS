import 'package:google_maps_flutter/google_maps_flutter.dart';

List<LatLng> decodeGooglePolyline(String encoded) {
  final points = <LatLng>[];
  var index = 0;
  var latitude = 0;
  var longitude = 0;

  while (index < encoded.length) {
    final latitudeChange = _decodeValue(encoded, index);
    index = latitudeChange.nextIndex;
    latitude += latitudeChange.value;

    if (index >= encoded.length) {
      throw const FormatException('Polyline incompleta: falta la longitud.');
    }

    final longitudeChange = _decodeValue(encoded, index);
    index = longitudeChange.nextIndex;
    longitude += longitudeChange.value;

    points.add(LatLng(latitude / 1e5, longitude / 1e5));
  }

  return points;
}

({int value, int nextIndex}) _decodeValue(String encoded, int startIndex) {
  var index = startIndex;
  var result = 0;
  var shift = 0;
  int byte;

  do {
    if (index >= encoded.length) {
      throw const FormatException('Polyline incompleta.');
    }
    byte = encoded.codeUnitAt(index++) - 63;
    if (byte < 0 || byte > 63) {
      throw const FormatException('Polyline con caracteres inválidos.');
    }
    result |= (byte & 0x1f) << shift;
    shift += 5;
  } while (byte >= 0x20);

  final value = (result & 1) == 1 ? ~(result >> 1) : result >> 1;
  return (value: value, nextIndex: index);
}

List<LatLng> decodeGooglePolylines(Iterable<String> encodedPolylines) {
  final points = <LatLng>[];

  for (final encoded in encodedPolylines) {
    final segment = decodeGooglePolyline(encoded);
    if (points.isNotEmpty &&
        segment.isNotEmpty &&
        points.last.latitude == segment.first.latitude &&
        points.last.longitude == segment.first.longitude) {
      points.addAll(segment.skip(1));
    } else {
      points.addAll(segment);
    }
  }

  return points;
}

List<List<LatLng>> decodeGooglePolylineSegments(
  Iterable<String> encodedPolylines,
) {
  return encodedPolylines
      .map(decodeGooglePolyline)
      .where((segment) => segment.length > 1)
      .toList(growable: false);
}
