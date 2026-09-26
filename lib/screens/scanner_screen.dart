import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/app_theme.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../state/providers.dart';
import '../widgets/packing_order_sheet.dart';

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
        await _receiveUnlisted(value);
      } else if (order.isReceived) {
        await showPackingOrderSheet(
          context,
          order,
          orders.length,
          alreadyReceived: true,
        );
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
          if (mounted && ApiService.isAlreadyReceivedError(error)) {
            ref.invalidate(ordersProvider);
            await showPackingOrderSheet(
              context,
              order,
              orders.length,
              alreadyReceived: true,
            );
          } else if (mounted) {
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
        if (!mounted) return;
        await showPackingOrderSheet(context, order, orders.length);
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

  /// El QR no está en la lista local: puede ser de otro motorizado, estar
  /// sin asignar o ser nuestro y la lista estar desactualizada. El backend
  /// decide y, si es nuestro, lo recepciona.
  Future<void> _receiveUnlisted(String value) async {
    try {
      await ref.read(apiProvider).confirmReception(value);
    } catch (error) {
      if (!mounted) return;
      await _showReceptionRejected(value, error);
      return;
    }
    ref.invalidate(ordersProvider);
    final orders = await ref.read(ordersProvider.future);
    if (!mounted) return;
    final order = _findOrder(value, orders);
    if (order != null) {
      await showPackingOrderSheet(context, order, orders.length);
    } else {
      await _showMessage(
        title: 'Pedido recepcionado',
        message: 'El pedido “$value” quedó recepcionado.',
        icon: Icons.check_circle_outline,
        color: AppTheme.success,
      );
    }
  }

  Future<void> _showReceptionRejected(String value, Object error) async {
    final response = error is DioException ? error.response : null;
    final data = response?.data;
    final motivo = data is Map ? data['motivo']?.toString() : null;
    final serverMessage =
        data is Map ? data['message']?.toString().trim() : null;

    if (ApiService.isAlreadyReceivedError(error)) {
      await _showMessage(
        title: 'Pedido ya recepcionado',
        message: serverMessage ?? 'Este pedido ya fue registrado.',
        icon: Icons.warning_amber_rounded,
        color: AppTheme.warning,
      );
    } else if (motivo == 'otro_motorizado') {
      await _showMessage(
        title: 'Pedido de otro motorizado',
        message:
            '${serverMessage ?? 'Este pedido no está asignado a ti.'} '
            'No lo cargues en tu mochila.',
        icon: Icons.assignment_ind_outlined,
        color: AppTheme.danger,
      );
    } else if (motivo == 'sin_asignar') {
      await _showMessage(
        title: 'Pedido sin asignar',
        message:
            '${serverMessage ?? 'Este pedido aún no ha sido asignado.'} '
            'Consulta con tu supervisor antes de llevarlo.',
        icon: Icons.person_off_outlined,
        color: AppTheme.warning,
      );
    } else if (response?.statusCode == 403) {
      // Backend anterior, sin `motivo`.
      await _showMessage(
        title: 'Pedido no asignado a ti',
        message: serverMessage ?? 'Este pedido no está asignado a ti.',
        icon: Icons.assignment_ind_outlined,
        color: AppTheme.danger,
      );
    } else if (response?.statusCode == 404) {
      await _showNotFound(value);
    } else {
      await _showMessage(
        title: 'No se pudo registrar el pedido',
        message: _receptionError(error),
        icon: Icons.sync_problem_outlined,
        color: AppTheme.warning,
      );
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
      // Sin respuesta: el servidor tardó demasiado o no hubo conexión. La
      // recepción pudo registrarse igual, por eso se pide revisar la lista.
      return 'El servidor no respondió a tiempo. Revisa en "Pedidos" si quedó '
          'recepcionado antes de volver a escanear.';
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

  Future<void> _showNotFound(String value) => _showMessage(
    title: 'Pedido no encontrado',
    message: 'El QR “$value” no corresponde a ningún pedido de ZAZU.',
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
