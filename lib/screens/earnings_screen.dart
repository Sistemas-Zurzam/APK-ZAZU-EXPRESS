import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/app_theme.dart';
import '../state/providers.dart';

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider).valueOrNull ?? [];
    final total = orders.fold<double>(0, (sum, item) => sum + item.amountDue);
    final money = NumberFormat.currency(locale: 'es_PE', symbol: 'S/');
    return Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Ingresos y cobros', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
      const SizedBox(height: 20),
      Card(color: AppTheme.surface, child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Monto pendiente de pedidos asignados', style: TextStyle(color: AppTheme.textMuted)), const SizedBox(height: 10), Text(money.format(total), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppTheme.purpleLight)), const SizedBox(height: 8), Text('${orders.length} pedido(s)')]))),
    ]));
  }
}
