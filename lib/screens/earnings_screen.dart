import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_theme.dart';
import '../core/collection_summary.dart';
import '../core/currency_format.dart';
import '../state/providers.dart';

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = CollectionSummary.from(
      ref.watch(ordersProvider).valueOrNull ?? [],
    );
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Ingresos y cobros',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 20),
        Card(
          color: AppTheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Efectivo a entregar en caja',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 10),
                Text(
                  peruvianCurrency.format(summary.cash),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.success,
                  ),
                ),
                const SizedBox(height: 8),
                Text('${summary.deliveredCount} pedido(s) entregado(s)'),
                const Divider(height: 28),
                _Line(
                  label: 'Total recaudado',
                  value: summary.collected,
                  bold: true,
                ),
                for (final entry in summary.byMethod.entries)
                  _Line(
                    label: entry.key,
                    value: entry.value,
                    color:
                        entry.key == 'Sin medio de pago registrado'
                            ? AppTheme.warning
                            : null,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          color: AppTheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Monto pendiente de pedidos asignados',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 10),
                Text(
                  peruvianCurrency.format(summary.pending),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.purpleLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text('${summary.pendingCount} pedido(s) por entregar'),
                if (summary.notDeliveredCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${summary.notDeliveredCount} pedido(s) no entregado(s)',
                    style: const TextStyle(color: AppTheme.danger),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
  });

  final String label;
  final double value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: color ?? (bold ? null : AppTheme.textMuted),
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(peruvianCurrency.format(value), style: style),
        ],
      ),
    );
  }
}
