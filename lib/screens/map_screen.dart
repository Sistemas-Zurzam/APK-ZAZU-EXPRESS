import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/app_theme.dart';
import '../models/order.dart';
import '../state/providers.dart';

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
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission != LocationPermission.denied && permission != LocationPermission.deniedForever) {
        current = await Geolocator.getCurrentPosition();
      }

      motoIcon ??= await _assetMarker('assets/images/motorizado.png', 130);
      final origin = _origin;
      final route = await _loadRouteWithFallback(origin);
      routeOrders = route.where((order) => order.hasCoordinates).toList();
      if (routeOrders.isEmpty) {
        routeMessage = 'No hay pedidos con coordenadas para mostrar en ruta.';
      }
    } catch (error) {
      routeOrders = const [];
      routeMessage = 'No se pudo cargar la ruta inteligente.';
    } finally {
      if (mounted) {
        setState(() => loading = false);
        _fitRoute();
      }
    }
  }

  Future<List<DeliveryOrder>> _loadRouteWithFallback(LatLng origin) async {
    try {
      return await ref.read(apiProvider).getSmartRoute(origin.latitude, origin.longitude);
    } catch (_) {
      final orders = await ref.read(apiProvider).getMyOrders();
      routeMessage = 'Ruta armada con tus pedidos. La ruta inteligente del servidor no respondio.';
      return orders;
    }
  }

  LatLng get _origin {
    if (current == null) return fallbackOrigin;
    return LatLng(current!.latitude, current!.longitude);
  }

  Future<BitmapDescriptor> _assetMarker(String asset, int width) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    final origin = _origin;
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('me'),
        position: origin,
        icon: motoIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Mi ubicación'),
      ),
    };

    for (var i = 0; i < routeOrders.length; i++) {
      final order = routeOrders[i];
      markers.add(
        Marker(
          markerId: MarkerId('order_${order.id}_$i'),
          position: LatLng(order.latitude!, order.longitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          infoWindow: InfoWindow(
            title: '${i + 1}. ${order.externalRef}',
            snippet: '${order.customerName} · S/${order.amountDue.toStringAsFixed(2)}',
          ),
        ),
      );
    }

    final points = [
      origin,
      ...routeOrders.map((order) => LatLng(order.latitude!, order.longitude!)),
    ];

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: origin, zoom: 12),
          markers: markers,
          polylines: points.length > 1
              ? {
                  Polyline(
                    polylineId: const PolylineId('smart_route'),
                    points: points,
                    color: AppTheme.purple,
                    width: 7,
                  ),
                }
              : {},
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
          compassEnabled: true,
          mapToolbarEnabled: false,
          onMapCreated: (controller) {
            mapController = controller;
            _fitRoute();
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
                routeMessage ?? 'Ruta inteligente\n${routeOrders.length} parada${routeOrders.length == 1 ? '' : 's'} en orden de reparto.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 24,
          child: FloatingActionButton(onPressed: _load, child: const Icon(Icons.my_location)),
        ),
      ],
    );
  }

  void _fitRoute() {
    final controller = mapController;
    if (controller == null || routeOrders.isEmpty) return;

    final points = [
      _origin,
      ...routeOrders.map((order) => LatLng(order.latitude!, order.longitude!)),
    ];
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
