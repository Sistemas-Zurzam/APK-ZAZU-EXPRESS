import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/order.dart';

/// Resultado de una recepción: grupo, orden de entrega y orden de carga en
/// mochila. Se muestra tanto al escanear como al recepcionar desde el detalle.
/// Con [alreadyReceived] avisa que el pedido ya estaba registrado para que no
/// se vuelva a escanear.
Future<void> showPackingOrderSheet(
  BuildContext context,
  DeliveryOrder order,
  int totalOrders, {
  bool alreadyReceived = false,
  String buttonLabel = 'Escanear siguiente',
  IconData buttonIcon = Icons.qr_code_scanner,
}) async {
  final badgeColor = alreadyReceived ? AppTheme.warning : AppTheme.success;
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
              border: Border.all(
                color:
                    alreadyReceived ? AppTheme.warning : AppTheme.purpleLight,
                width: 1.5,
              ),
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
                    color: badgeColor.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: badgeColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        alreadyReceived
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        color: badgeColor,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        alreadyReceived
                            ? 'PEDIDO YA RECEPCIONADO'
                            : '¡PEDIDO RECEPCIONADO!',
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (alreadyReceived) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Este pedido ya fue registrado. No es necesario volver a '
                    'escanearlo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.warning),
                  ),
                ],
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
                        value: deliveryOrder == null ? '—' : '#$deliveryOrder',
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
                    icon: Icon(buttonIcon),
                    label: Text(buttonLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
  );
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
