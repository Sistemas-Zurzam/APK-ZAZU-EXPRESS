import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/app_theme.dart';
import '../models/order.dart';
import '../state/providers.dart';

/// Índice de la pestaña "Escáner" en la barra inferior de HomeShell.
const _scannerTabIndex = 1;

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    autoStart: false,
  );
  String result = 'Escanea el QR de la nota de venta';
  bool handled = false;

  @override
  void initState() {
    super.initState();
    // IndexedStack mantiene esta pantalla montada todo el tiempo, incluso
    // en pestañas distintas — sin este chequeo, la cámara quedaría prendida
    // (y detectando códigos de cajas/etiquetas reales) para siempre.
    if (ref.read(homeTabIndexProvider) == _scannerTabIndex) {
      unawaited(controller.start());
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (handled || capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue?.trim();
    if (value == null || value.isEmpty) return;

    handled = true;
    setState(() => result = value);
    await controller.stop();

    try {
      final orders = await ref.read(ordersProvider.future);
      final order = _findOrder(value, orders);
      if (!mounted) return;

      if (order == null) {
        await _showNotFound(value);
      } else {
        try {
          await ref
              .read(apiProvider)
              .confirmReception(
                order.externalRef,
                orderId: order.id,
                operationId: order.operationId,
              );
        } catch (error) {
          if (mounted) {
            await _showMessage(
              title: 'No se pudo registrar el pedido',
              message: _receptionError(error),
              icon: Icons.sync_problem_outlined,
              color: AppTheme.warning,
            );
          }
          return;
        }
        ref.invalidate(ordersProvider);
        await _showPackingOrder(order, orders.length);
      }
    } catch (_) {
      if (mounted) {
        await _showMessage(
          title: 'No se pudieron cargar los pedidos',
          message: 'Comprueba tu conexión e inténtalo nuevamente.',
          icon: Icons.cloud_off_outlined,
          color: AppTheme.warning,
        );
      }
    } finally {
      await _resumeScanner();
    }
  }

  String _receptionError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final message = data['message'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }
      }
      if (error.response?.statusCode != null) {
        return 'El servidor rechazó el cambio de estado '
            '(error ${error.response!.statusCode}).';
      }
    }
    return 'El servidor rechazó el cambio de estado. El pedido continúa sin registrar.';
  }

  DeliveryOrder? _findOrder(String scanned, List<DeliveryOrder> orders) {
    final qr = _normalize(scanned);
    for (final order in orders) {
      final reference = _normalize(order.externalRef);
      if (reference.isNotEmpty && (qr == reference || qr.contains(reference))) {
        return order;
      }
    }
    return null;
  }

  String _normalize(String value) =>
      Uri.decodeFull(value).replaceAll(RegExp(r'\s+'), '').toUpperCase();

  Future<void> _showPackingOrder(DeliveryOrder order, int totalOrders) async {
    final deliveryOrder = order.deliverySequence;
    final backpackOrder =
        order.backpackSequence ??
        (deliveryOrder == null ? null : totalOrders - deliveryOrder + 1);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => SafeArea(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppTheme.purpleLight, width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme.textMuted,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 52,
                    color: AppTheme.purpleLight,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppTheme.success),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: AppTheme.success,
                        ),
                        SizedBox(width: 7),
                        Text(
                          '¡PEDIDO RECEPCIONADO!',
                          style: TextStyle(
                            color: AppTheme.success,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    order.externalRef,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    order.customerName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: _PackingMetric(
                          label: 'GRUPO',
                          value: order.routeGroup ?? 'No informado',
                          icon: Icons.group_work_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PackingMetric(
                          label: 'ORDEN DE ENTREGA',
                          value:
                              deliveryOrder == null ? '—' : '#$deliveryOrder',
                          icon: Icons.route_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.purple.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'ORDEN DE CARGA EN MOCHILA',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          backpackOrder == null
                              ? 'No informado'
                              : '#$backpackOrder',
                          style: const TextStyle(
                            color: AppTheme.purpleLight,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (order.backpackSequence == null &&
                            backpackOrder != null)
                          const Text(
                            'Calculado en orden inverso de entrega',
                            style: TextStyle(color: AppTheme.textMuted),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Escanear siguiente'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _showNotFound(String value) => _showMessage(
    title: 'Pedido no encontrado',
    message: 'El QR “$value” no corresponde a tus pedidos activos.',
    icon: Icons.search_off_outlined,
    color: AppTheme.warning,
  );

  Future<void> _showMessage({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 48, color: color),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Escanear nuevamente'),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _resumeScanner() async {
    if (!mounted) return;
    handled = false;
    setState(() => result = 'Escanea el QR de la nota de venta');
    // No reactivar la cámara si el usuario ya navegó a otra pestaña
    // mientras se mostraba el resultado del escaneo anterior.
    if (ref.read(homeTabIndexProvider) == _scannerTabIndex) {
      await controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(homeTabIndexProvider, (previous, next) {
      if (next == _scannerTabIndex) {
        unawaited(controller.start());
      } else if (previous == _scannerTabIndex) {
        unawaited(controller.stop());
      }
    });

    return Stack(
      children: [
        MobileScanner(controller: controller, onDetect: _onDetect),
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 28,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: Text(result, textAlign: TextAlign.center)),
                  IconButton(
                    onPressed: controller.toggleTorch,
                    icon: const Icon(Icons.flashlight_on),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PackingMetric extends StatelessWidget {
  const _PackingMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Icon(icon, color: AppTheme.purpleLight),
        const SizedBox(height: 7),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}
