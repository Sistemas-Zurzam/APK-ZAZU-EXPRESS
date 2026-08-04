import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_theme.dart';
import '../core/currency_format.dart';
import '../models/order.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.sequence,
    this.onTap,
    this.onRoute,
  });

  final DeliveryOrder order;
  final int sequence;
  final VoidCallback? onTap;
  final VoidCallback? onRoute;

  @override
  Widget build(BuildContext context) {
    final status = _statusStyle(order.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: status.color.withValues(alpha: .65),
          width: 1.2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.purple, AppTheme.purpleLight],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
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
                        Text(
                          order.externalRef,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          order.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      status.label,
                      style: TextStyle(
                        color: status.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 19,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      order.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MONTO A COBRAR',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          peruvianCurrency.format(order.amountDue),
                          style: TextStyle(
                            color:
                                order.amountDue > 0
                                    ? AppTheme.success
                                    : AppTheme.textMuted,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ActionIcon(
                    icon: Icons.phone_outlined,
                    enabled: (order.phone ?? '').isNotEmpty,
                    onPressed: () => _call(order.phone),
                  ),
                  const SizedBox(width: 8),
                  _ActionIcon(
                    icon: Icons.navigation_outlined,
                    enabled: order.hasCoordinates,
                    onPressed: onRoute,
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed:
                        (order.phone ?? '').trim().isEmpty
                            ? null
                            : () => _openWhatsApp(context, order),
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: const Text('WhatsApp'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.purple.withValues(alpha: .2),
                      foregroundColor: AppTheme.purpleLight,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone.trim());
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp(BuildContext context, DeliveryOrder order) async {
    final phone = _whatsAppPhone(order.phone);
    if (phone == null) return;
    final seller = _sellerName(order.externalRef);

    final uri = Uri.https('wa.me', '/$phone', {
      'text': 'Hola, le escribo respecto a su pedido $seller.',
    });

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) return;
    } catch (_) {
      // Se informa el problema debajo si no existe una aplicación compatible.
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir WhatsApp para este número.'),
        ),
      );
    }
  }

  String? _whatsAppPhone(String? rawPhone) {
    if (rawPhone == null) return null;
    var digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.length == 9) digits = '51$digits';
    return digits.length >= 11 ? digits : null;
  }

  String _sellerName(String reference) {
    final seller = reference.split('/').first.trim();
    return seller.isEmpty ? 'ZAZU' : seller;
  }

  _StatusStyle _statusStyle(String raw) {
    final value = raw.toLowerCase().replaceAll('_', ' ');
    if (value.contains('entregado'))
      return const _StatusStyle('Entregado', AppTheme.success);
    if (value.contains('ruta') || value.contains('recibido'))
      return const _StatusStyle('En ruta', AppTheme.warning);
    if (value.contains('cancel') || value.contains('fall'))
      return const _StatusStyle('Incidencia', AppTheme.danger);
    return const _StatusStyle('Asignado', AppTheme.purpleLight);
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.surface2,
        disabledBackgroundColor: AppTheme.surface2.withValues(alpha: .5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle(this.label, this.color);
  final String label;
  final Color color;
}
