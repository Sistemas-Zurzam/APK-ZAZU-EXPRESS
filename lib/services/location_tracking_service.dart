import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';

/// Reporta la posición del motorizado al backend cada [interval] mientras
/// haya al menos un pedido en ruta, para que el panel web pueda mostrar su
/// movimiento por polling (ver `_load` de MapScreen para el mismo patrón de
/// permisos de ubicación).
class LocationTrackingService {
  LocationTrackingService(this._api, {this.interval = const Duration(seconds: 15)});

  final ApiService _api;
  final Duration interval;
  Timer? _timer;

  void start() {
    if (_timer != null) return;
    unawaited(_reportOnce());
    _timer = Timer.periodic(interval, (_) => _reportOnce());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _reportOnce() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 10),
        ),
      );
      await _api.updateLocation(position.latitude, position.longitude);
    } catch (_) {
      // Un reporte perdido no es crítico: se reintenta en el próximo ciclo.
    }
  }
}
