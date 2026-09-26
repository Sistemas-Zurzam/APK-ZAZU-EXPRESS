import 'dart:async';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/google_polyline.dart';
import '../core/app_theme.dart';
import '../core/currency_format.dart';
import '../core/external_navigation.dart';
import '../core/route_rules.dart';
import '../models/order.dart';
import '../state/providers.dart';
import '../widgets/order_contact_sheet.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const fallbackOrigin = LatLng(-12.046374, -77.042793);

  Position? current;
  BitmapDescriptor? motoIcon;
  GoogleMapController? mapController;
  List<DeliveryOrder> routeOrders = const [];
  List<List<LatLng>> routeSegments = const [];
  Map<int, BitmapDescriptor> numberedIcons = const {};
  bool loading = true;
  String? routeMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      routeMessage = null;
    });

    try {
      // Timeout global: sin importar qué se cuelgue adentro (permiso de
      // ubicación, GPS, red), la pantalla nunca debe quedarse "cargando"
      // para siempre.
      await _loadData().timeout(const Duration(seconds: 45));
    } on TimeoutException {
      routeOrders = const [];
      routeSegments = const [];
      routeMessage = 'La carga del mapa tardó demasiado. Intenta de nuevo.';
    } catch (_) {
      routeOrders = const [];
      routeSegments = const [];
      routeMessage = 'No se pudo preparar el mapa y la ubicación.';
    } finally {
      if (mounted) {
        setState(() => loading = false);
        _fitRoute();
        _focusOnOrder(ref.read(focusedOrderIdProvider));
      }
    }
  }

  Future<void> _loadData() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever) {
      try {
        current = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (_) {
        // Sin fix de GPS a tiempo (interiores, señal débil): seguimos con
        // el origen de respaldo en vez de colgar toda la carga del mapa.
      }
    }

    motoIcon ??= await _assetMarker('assets/images/motorizado.png', 64);
    final origin = _origin;

    try {
      final orders = await ref.read(apiProvider).getMyOrders();
      // Los entregados salen del mapa: ya no son paradas de la ruta (el
      // trazado de /motorizado/mi-ruta tampoco los incluye).
      routeOrders =
          orders
              .where((order) => order.hasCoordinates && !order.isDelivered)
              .toList();
      routeOrders.sort(
        (left, right) => (left.deliverySequence ?? 1 << 30).compareTo(
          right.deliverySequence ?? 1 << 30,
        ),
      );
      numberedIcons = await _buildNumberedIcons(routeOrders);
    } catch (_) {
      routeOrders = const [];
      numberedIcons = const {};
      routeMessage = 'No se pudieron cargar los pedidos asignados.';
    }

    try {
      final geometry = await ref
          .read(apiProvider)
          .getMyRoute(origin.latitude, origin.longitude);
      routeSegments = decodeGooglePolylineSegments(geometry.polylines);
      if (routeSegments.isEmpty) {
        routeMessage ??= 'El servidor no devolvió un trazado para la ruta.';
      } else if (_looksLikeStraightLines(routeSegments)) {
        routeMessage =
            'El trazado recibido es una línea recta entre paradas: '
            'no sigue el callejero. Revisa el cálculo de ruta en el servidor.';
      } else if (!geometry.complete) {
        routeMessage =
            'Se muestra una ruta parcial. Algunos tramos no pudieron calcularse.';
      }
    } catch (_) {
      routeSegments = const [];
      routeMessage ??= 'No se pudo cargar el trazado de la ruta.';
    }

    if (routeOrders.isEmpty) {
      routeMessage ??= 'No hay pedidos con coordenadas para mostrar en ruta.';
    }
  }

  /// Paradas vigentes (id + estado): si cambia, el mapa está desactualizado.
  static String _activeStopsKey(List<DeliveryOrder> orders) => (orders
          .where((o) => o.hasCoordinates && !o.isDelivered)
          .map((o) => '${o.id}:${o.status}')
          .toList()
        ..sort())
      .join(',');

  void _focusOnOrder(int? orderId) {
    if (orderId == null) return;
    final index = routeOrders.indexWhere((order) => order.id == orderId);
    final controller = mapController;
    if (index == -1 || controller == null) return;

    final order = routeOrders[index];
    unawaited(
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(order.latitude!, order.longitude!),
          17,
        ),
      ),
    );
    unawaited(
      controller.showMarkerInfoWindow(MarkerId('order_${order.id}_$index')),
    );
    ref.read(focusedOrderIdProvider.notifier).state = null;
  }

  Future<void> _openTurnByTurnNavigation(DeliveryOrder order) async {
    await openExternalNavigation(context, order);
  }

  Future<void> _showOrderSheet(DeliveryOrder order, int sequence) =>
      showOrderContactSheet(
        context,
        order,
        sequence: sequence,
        onNavigate: () => _openTurnByTurnNavigation(order),
        onStartRoute: () => _startRoute(order),
        onDeliver: () {
          ref.read(deliverOrderRequestProvider.notifier).state = order.id;
          ref.read(homeTabIndexProvider.notifier).state = 0;
        },
      );

  /// Inicia la ruta del pedido. Devuelve null si salió bien o el mensaje de
  /// error. Al refrescar los pedidos, el listener recarga el mapa.
  Future<String?> _startRoute(DeliveryOrder order) async {
    final blocked = startRouteBlockReason(
      order,
      ref.read(ordersProvider).valueOrNull ?? routeOrders,
    );
    if (blocked != null) return blocked;
    try {
      await ref
          .read(apiProvider)
          .startRoute(order.id, operationId: order.operationId);
      ref.invalidate(ordersProvider);
      return null;
    } on DioException catch (error) {
      final data = error.response?.data;
      final message = data is Map ? data['message']?.toString() : null;
      if (message != null && message.trim().isNotEmpty) return message;
      if (error.response?.statusCode != null) {
        return 'No se pudo iniciar la ruta (error '
            '${error.response!.statusCode}).';
      }
      return 'No se pudo conectar con el servidor. Revisa tu conexión.';
    } catch (_) {
      return 'No se pudo iniciar la ruta.';
    }
  }

  LatLng get _origin {
    if (current == null) return fallbackOrigin;
    return LatLng(current!.latitude, current!.longitude);
  }

  /// Un tramo real que sigue calles suele tener decenas de vértices (el
  /// callejero curva y da vueltas). Una línea recta entre dos paradas se
  /// decodifica con muy pocos puntos. Si casi todos los tramos tienen 2
  /// puntos o menos por cada ~150 m de distancia, es una línea recta y no
  /// un trazado real.
  bool _looksLikeStraightLines(List<List<LatLng>> segments) {
    var straightSegments = 0;
    for (final segment in segments) {
      if (segment.length > 3) continue;
      final distance = Geolocator.distanceBetween(
        segment.first.latitude,
        segment.first.longitude,
        segment.last.latitude,
        segment.last.longitude,
      );
      if (segment.length <= 2 || distance / segment.length > 150) {
        straightSegments++;
      }
    }
    return straightSegments >= segments.length * 0.7;
  }

  Future<BitmapDescriptor> _assetMarker(String asset, int width) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  Future<Map<int, BitmapDescriptor>> _buildNumberedIcons(
    List<DeliveryOrder> orders,
  ) async {
    final icons = <int, BitmapDescriptor>{};
    for (var index = 0; index < orders.length; index++) {
      final sequence = orders[index].deliverySequence ?? index + 1;
      icons[sequence] ??= await _numberedMarker(sequence);
    }
    return icons;
  }

  Future<BitmapDescriptor> _numberedMarker(int number) async {
    const size = 48.0;
    const center = Offset(size / 2, size / 2);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawCircle(center, 21, Paint()..color = AppTheme.purple);
    canvas.drawCircle(
      center,
      18,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          color: Colors.white,
          fontSize: number >= 100 ? 12 : 16,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );

    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    // Al entregar (o recepcionar, reprogramar...) se invalida ordersProvider:
    // se recarga el mapa para que las paradas y el trazado se actualicen.
    ref.listen<AsyncValue<List<DeliveryOrder>>>(ordersProvider, (
      previous,
      next,
    ) {
      final before = previous?.valueOrNull;
      final after = next.valueOrNull;
      if (before == null || after == null || loading) return;
      if (_activeStopsKey(before) != _activeStopsKey(after)) {
        unawaited(_load());
      }
    });

    ref.listen<int?>(focusedOrderIdProvider, (previous, next) {
      if (next != null) _focusOnOrder(next);
    });

    if (loading) return const Center(child: CircularProgressIndicator());

    final origin = _origin;
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('me'),
        position: origin,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        icon:
            motoIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Mi ubicación'),
      ),
    };

    for (var i = 0; i < routeOrders.length; i++) {
      final order = routeOrders[i];
      final sequence = order.deliverySequence ?? i + 1;
      markers.add(
        Marker(
          markerId: MarkerId('order_${order.id}_$i'),
          position: LatLng(order.latitude!, order.longitude!),
          anchor: const Offset(0.5, 0.5),
          icon:
              numberedIcons[sequence] ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          onTap: () => _showOrderSheet(order, sequence),
          infoWindow: InfoWindow(
            title: '$sequence. ${order.externalRef}',
            snippet:
                '${order.customerName} · ${peruvianCurrency.format(order.amountDue)}',
            onTap: () => _showOrderSheet(order, sequence),
          ),
        ),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: origin, zoom: 12),
          markers: markers,
          polylines: {
            for (var index = 0; index < routeSegments.length; index++)
              Polyline(
                polylineId: PolylineId('smart_route_$index'),
                points: routeSegments[index],
                color: AppTheme.purple,
                width: 7,
              ),
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
          compassEnabled: true,
          mapToolbarEnabled: false,
          onMapCreated: (controller) {
            mapController = controller;
            _fitRoute();
            _focusOnOrder(ref.read(focusedOrderIdProvider));
          },
        ),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Card(
            color: AppTheme.surface.withValues(alpha: .94),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                routeMessage ??
                    'Ruta de reparto\n${routeOrders.length} parada${routeOrders.length == 1 ? '' : 's'} en orden de reparto.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (routeOrders.isNotEmpty) ...[
                FloatingActionButton.extended(
                  heroTag: 'start_navigation',
                  onPressed: () => _openTurnByTurnNavigation(routeOrders.first),
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navegar'),
                ),
                const SizedBox(height: 12),
              ],
              FloatingActionButton.small(
                heroTag: 'reload_route',
                onPressed: _load,
                tooltip: 'Actualizar ruta',
                child: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _fitRoute() {
    final controller = mapController;
    if (controller == null) return;

    final routePoints = routeSegments.expand((segment) => segment).toList();
    final points =
        routePoints.isNotEmpty
            ? routePoints
            : [
              _origin,
              ...routeOrders.map(
                (order) => LatLng(order.latitude!, order.longitude!),
              ),
            ];
    if (points.isEmpty) return;
    if (points.length == 1) {
      unawaited(
        controller.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15)),
      );
      return;
    }
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    unawaited(
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          70,
        ),
      ),
    );
  }
}
