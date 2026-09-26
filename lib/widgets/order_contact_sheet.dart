import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/contact_actions.dart';
import '../core/currency_format.dart';
import '../models/order.dart';

/// Mensajes predefinidos para el cliente. Se abren en WhatsApp ya escritos;
/// el motorizado puede editarlos antes de enviar.
List<({String title, String text})> _templates(DeliveryOrder order) {
  final name = order.customerName.split(' ').first;
  final seller = sellerName(order.externalRef);
  final amount =
      order.amountDue > 0
          ? ' El monto a cobrar es ${peruvianCurrency.format(order.amountDue)}.'
          : '';
  return [
    (
      title: 'Voy en camino',
      text:
          'Hola $name, le saluda su motorizado de ZAZU Express. Estoy en '
          'camino con su pedido de $seller (${order.externalRef}).$amount',
    ),
    (
      title: 'Ya llegué',
      text:
          'Hola $name, ya me encuentro en ${order.address} con su pedido de '
          '$seller (${order.externalRef}).$amount',
    ),
    (
      title: 'No lo encuentro',
      text:
          'Hola $name, estoy en la dirección de entrega de su pedido de '
          '$seller (${order.externalRef}) pero no logro ubicarlo. ¿Podría '
          'indicarme una referencia?',
    ),
  ];
}

/// Ficha del pedido al tocarlo en el mapa: monto a cobrar, nota de venta,
/// datos del cliente y acciones de contacto.
///
/// [onStartRoute] devuelve null si la ruta se inició, o el mensaje de error.
Future<void> showOrderContactSheet(
  BuildContext context,
  DeliveryOrder order, {
  required int sequence,
  VoidCallback? onNavigate,
  Future<String?> Function()? onStartRoute,
  VoidCallback? onDeliver,
}) {
  final hasPhone = whatsAppPhone(order.phone) != null;
  // Siempre visible (salvo entregado); solo se habilita En ruta, que es lo
  // que exige el servidor para registrar la entrega.
  final showDeliver = onDeliver != null && !order.isDelivered;
  final canDeliver = showDeliver && order.isInRoute;
  final canStartRoute =
      onStartRoute != null && !order.isInRoute && !order.isDelivered;
  var startingRoute = false;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppTheme.surface,
    builder:
        (sheetContext) => StatefulBuilder(
          builder:
              (sheetContext, setSheetState) => SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.purple, AppTheme.purpleLight],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              '$sequence',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Nota de venta',
                                  style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  order.externalRef,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.purple.withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'MONTO A COBRAR',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              peruvianCurrency.format(order.amountDue),
                              style: TextStyle(
                                color:
                                    order.amountDue > 0
                                        ? AppTheme.success
                                        : AppTheme.textMuted,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.person_outline,
                        label: 'Cliente',
                        value: order.customerName,
                      ),
                      _InfoRow(
                        icon: Icons.badge_outlined,
                        label: 'DNI',
                        value: order.dni ?? 'No registrado',
                      ),
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        label: 'Teléfono',
                        value: order.phone ?? 'No registrado',
                      ),
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        label: 'Dirección',
                        value: order.address,
                      ),
                      if (order.observations != null)
                        _InfoRow(
                          icon: Icons.notes_outlined,
                          label: 'Observaciones',
                          value: order.observations!,
                        ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _ContactButton(
                              icon: Icons.quickreply_outlined,
                              label: 'Mensaje\nplantilla',
                              onPressed:
                                  hasPhone
                                      ? () => _pickTemplate(sheetContext, order)
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ContactButton(
                              icon: Icons.chat_outlined,
                              label: 'Abrir\nWhatsApp',
                              onPressed:
                                  hasPhone
                                      ? () =>
                                          openWhatsAppChat(sheetContext, order)
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ContactButton(
                              icon: Icons.call_outlined,
                              label: 'Llamar',
                              onPressed:
                                  (order.phone?.trim().isNotEmpty ?? false)
                                      ? () => callCustomer(
                                        sheetContext,
                                        order.phone,
                                      )
                                      : null,
                            ),
                          ),
                        ],
                      ),
                      if (!hasPhone)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'El pedido no tiene un teléfono válido para WhatsApp.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.warning,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (showDeliver) ...[
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed:
                              canDeliver
                                  ? () {
                                    Navigator.pop(sheetContext);
                                    onDeliver();
                                  }
                                  : null,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Entregar'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                          ),
                        ),
                        if (!canDeliver)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'Inicia la ruta de este pedido para poder '
                              'entregarlo.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                      if (canStartRoute) ...[
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed:
                              startingRoute
                                  ? null
                                  : () async {
                                    setSheetState(() => startingRoute = true);
                                    final error = await onStartRoute();
                                    if (!sheetContext.mounted) return;
                                    final messenger = ScaffoldMessenger.of(
                                      sheetContext,
                                    );
                                    if (error == null) {
                                      Navigator.pop(sheetContext);
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Ruta iniciada.'),
                                        ),
                                      );
                                      // Pasa a En ruta y abre de una vez el
                                      // selector Google Maps / Waze.
                                      onNavigate?.call();
                                    } else {
                                      setSheetState(
                                        () => startingRoute = false,
                                      );
                                      messenger.showSnackBar(
                                        SnackBar(content: Text(error)),
                                      );
                                    }
                                  },
                          icon:
                              startingRoute
                                  ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Icon(Icons.route_outlined),
                          label: Text(
                            startingRoute ? 'Iniciando...' : 'Iniciar ruta',
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                        ),
                      ],
                      if (onNavigate != null) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            onNavigate();
                          },
                          icon: const Icon(Icons.navigation_outlined),
                          label: const Text('Cómo llegar'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
        ),
  );
}

Future<void> _pickTemplate(BuildContext context, DeliveryOrder order) async {
  final templates = _templates(order);
  final text = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppTheme.surface,
    builder:
        (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Text(
                  'Elige un mensaje',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              for (final template in templates)
                ListTile(
                  leading: const Icon(Icons.message_outlined),
                  title: Text(template.title),
                  subtitle: Text(
                    template.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.pop(context, template.text),
                ),
            ],
          ),
        ),
  );
  if (text == null || !context.mounted) return;
  await openWhatsAppChat(context, order, text: text);
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.purpleLight),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: AppTheme.purple.withValues(alpha: .22),
      foregroundColor: AppTheme.purpleLight,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}
