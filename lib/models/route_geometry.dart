class RouteGeometry {
  const RouteGeometry({required this.polylines, required this.complete});

  final List<String> polylines;
  final bool complete;

  factory RouteGeometry.fromJson(Map<String, dynamic> json) {
    final payload = _payload(json);
    final rawPolylines = payload['polylines'];

    return RouteGeometry(
      polylines:
          rawPolylines is List
              ? rawPolylines
                  .map((value) => value?.toString().trim() ?? '')
                  .where((value) => value.isNotEmpty)
                  .toList(growable: false)
              : const [],
      complete: payload['completa'] == true,
    );
  }

  static Map<String, dynamic> _payload(Map<String, dynamic> json) {
    for (final key in ['trazado', 'data']) {
      final value = json[key];
      if (value is Map) {
        return value.map((key, value) => MapEntry(key.toString(), value));
      }
    }
    return json;
  }
}
