import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/order.dart';

Future<void> openExternalNavigation(
  BuildContext context,
  DeliveryOrder order,
) async {
  if (!order.hasCoordinates) return;

  final app = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '¿Con qué aplicación deseas navegar?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Google Maps'),
              subtitle: const Text('Abrir indicaciones en Google Maps'),
              onTap: () => Navigator.pop(context, 'google'),
            ),
            ListTile(
              leading: const Icon(Icons.navigation_outlined),
              title: const Text('Waze'),
              subtitle: const Text('Abrir navegación para motocicleta'),
              onTap: () => Navigator.pop(context, 'waze'),
            ),
          ],
        ),
      ),
    ),
  );
  if (app == null || !context.mounted) return;

  final destination = '${order.latitude},${order.longitude}';
  final uri = app == 'waze'
      ? Uri.https('waze.com', '/ul', {
          'll': destination,
          'navigate': 'yes',
          'vehicle_type': 'motorcycle',
          'utm_source': 'zazu_driver',
        })
      : Uri.parse('google.navigation:q=$destination&mode=d');

  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // Si Google Maps no está instalado, se intenta su enlace universal.
  }

  if (app == 'google') {
    final fallback = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
      'travelmode': 'driving',
    });
    if (await launchUrl(fallback, mode: LaunchMode.externalApplication)) {
      return;
    }
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'No se pudo abrir ${app == 'waze' ? 'Waze' : 'Google Maps'}.',
        ),
      ),
    );
  }
}
