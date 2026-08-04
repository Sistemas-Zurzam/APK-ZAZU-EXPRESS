import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_theme.dart';
import '../core/currency_format.dart';
import '../models/order.dart';
import '../state/providers.dart';
import '../widgets/order_card.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String selected = 'asignados';
  bool processingAction = false;

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider);

    return RefreshIndicator(
      color: AppTheme.purple,
      onRefresh: () => ref.refresh(ordersProvider.future),
      child: orders.when(
        loading: () => const _OrdersLoading(),
        error:
            (error, _) => _ErrorState(
              message: error.toString().replaceFirst('Exception: ', ''),
              onRetry: () => ref.invalidate(ordersProvider),
            ),
        data: (items) {
          final filtered = _filterOrders(items);
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Summary(orders: items),
                      const SizedBox(height: 18),
                      _Filters(
                        selected: selected,
                        onSelected: (value) => setState(() => selected = value),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Mis pedidos',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${filtered.length} pedido${filtered.length == 1 ? '' : 's'} en esta sección',
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: () => ref.invalidate(ordersProvider),
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Actualizar pedidos',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(filter: selected),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                  sliver: SliverList.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final order = filtered[index];
                      return OrderCard(
                        order: order,
                        sequence: index + 1,
                        onTap:
                            () => _showOrderDetails(context, order, index + 1),
                        onRoute:
                            order.hasCoordinates
                                ? () => _openNavigation(context, order)
                                : null,
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<DeliveryOrder> _filterOrders(List<DeliveryOrder> items) {
    bool isDelivered(DeliveryOrder order) =>
        order.status.toLowerCase().contains('entregado');
    bool isRoute(DeliveryOrder order) {
      final value = order.status.toLowerCase();
      return value.contains('ruta') || value.contains('recibido');
    }

    switch (selected) {
      case 'ruta':
        return items.where(isRoute).toList();
      case 'entregados':
        return items.where(isDelivered).toList();
      default:
        return items
            .where((order) => !isDelivered(order) && !isRoute(order))
            .toList();
    }
  }

  Future<void> _openNavigation(
    BuildContext context,
    DeliveryOrder order,
  ) async {
    if (!order.hasCoordinates) return;

    final destination = '${order.latitude},${order.longitude}';
    final googleNavigation = Uri.parse(
      'google.navigation:q=$destination&mode=d',
    );
    final webNavigation = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
      'travelmode': 'driving',
    });

    try {
      final opened = await launchUrl(
        googleNavigation,
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
    } catch (_) {
      // Se intenta el enlace web compatible con cualquier navegador.
    }

    final opened = await launchUrl(
      webNavigation,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la navegación.')),
      );
    }
  }

  void _showOrderDetails(
    BuildContext context,
    DeliveryOrder order,
    int sequence,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: .68,
            minChildSize: .48,
            maxChildSize: .92,
            builder:
                (context, controller) => Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.purple, AppTheme.purpleLight],
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(
                              '$sequence',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Detalle del pedido',
                                  style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  order.externalRef,
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _DetailTile(
                        icon: Icons.person_outline,
                        label: 'Cliente',
                        value: order.customerName,
                      ),
                      _DetailTile(
                        icon: Icons.badge_outlined,
                        label: 'DNI',
                        value: order.dni ?? 'No registrado',
                      ),
                      _DetailTile(
                        icon: Icons.phone_outlined,
                        label: 'Teléfono',
                        value: order.phone ?? 'No registrado',
                      ),
                      _DetailTile(
                        icon: Icons.location_on_outlined,
                        label: 'Dirección',
                        value: order.address,
                      ),
                      if (order.observations != null)
                        _DetailTile(
                          icon: Icons.notes_outlined,
                          label: 'Observaciones',
                          value: order.observations!,
                        ),
                      _DetailTile(
                        icon: Icons.payments_outlined,
                        label: 'Monto a cobrar',
                        value: peruvianCurrency.format(order.amountDue),
                        valueColor:
                            order.amountDue > 0
                                ? AppTheme.success
                                : AppTheme.textMuted,
                      ),
                      _DetailTile(
                        icon: Icons.local_shipping_outlined,
                        label: 'Estado',
                        value: order.status,
                      ),
                      const SizedBox(height: 20),
                      _OrderActions(
                        order: order,
                        processing: processingAction,
                        onReception:
                            () => _runOrderAction(
                              context,
                              successMessage: 'Pedido recepcionado.',
                              action:
                                  () => ref
                                      .read(apiProvider)
                                      .confirmReception(
                                        order.id,
                                        operationId: order.operationId,
                                      ),
                            ),
                        onStartRoute:
                            () => _runOrderAction(
                              context,
                              successMessage: 'Ruta iniciada.',
                              action:
                                  () => ref
                                      .read(apiProvider)
                                      .startRoute(
                                        order.id,
                                        operationId: order.operationId,
                                      ),
                            ),
                        onDeliver: () => _deliverWithEvidence(context, order),
                        onReschedule:
                            () => _showRescheduleDialog(context, order),
                        onMap:
                            order.hasCoordinates
                                ? () {
                                  Navigator.pop(context);
                                  _openNavigation(context, order);
                                }
                                : null,
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Cerrar detalle'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Future<void> _runOrderAction(
    BuildContext context, {
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    if (processingAction) return;
    setState(() => processingAction = true);
    try {
      await action();
      ref.invalidate(ordersProvider);
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_actionError(error))));
    } finally {
      if (mounted) setState(() => processingAction = false);
    }
  }

  Future<void> _deliverWithEvidence(
    BuildContext context,
    DeliveryOrder order,
  ) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 78,
      maxWidth: 1600,
    );
    if (image == null || !context.mounted) return;

    await _runOrderAction(
      context,
      successMessage: 'Pedido entregado con evidencia.',
      action:
          () => ref
              .read(apiProvider)
              .confirmDelivery(
                order.id,
                operationId: order.operationId,
                evidencePath: image.path,
              ),
    );
  }

  Future<void> _showRescheduleDialog(
    BuildContext context,
    DeliveryOrder order,
  ) async {
    final reasonController = TextEditingController();
    final dateController = TextEditingController();
    final result = await showDialog<({String reason, String date})>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reprogramar pedido'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Motivo'),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(
                    labelText: 'Nueva fecha',
                    hintText: 'YYYY-MM-DD',
                  ),
                  keyboardType: TextInputType.datetime,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final reason = reasonController.text.trim();
                  final date = dateController.text.trim();
                  if (reason.isEmpty || date.isEmpty) return;
                  Navigator.pop(context, (reason: reason, date: date));
                },
                child: const Text('Enviar'),
              ),
            ],
          ),
    );
    reasonController.dispose();
    dateController.dispose();
    if (result == null || !context.mounted) return;

    await _runOrderAction(
      context,
      successMessage: 'Pedido reprogramado.',
      action:
          () => ref
              .read(apiProvider)
              .rescheduleOrder(order.id, result.reason, result.date),
    );
  }

  String _actionError(Object error) {
    final text = error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Bad state: ', '');
    return text.isEmpty ? 'No se pudo completar la accion.' : text;
  }
}

class _OrderActions extends StatelessWidget {
  const _OrderActions({
    required this.order,
    required this.processing,
    required this.onReception,
    required this.onStartRoute,
    required this.onDeliver,
    required this.onReschedule,
    required this.onMap,
  });

  final DeliveryOrder order;
  final bool processing;
  final VoidCallback onReception;
  final VoidCallback onStartRoute;
  final VoidCallback onDeliver;
  final VoidCallback onReschedule;
  final VoidCallback? onMap;

  @override
  Widget build(BuildContext context) {
    final status = order.status.toLowerCase();
    final isDelivered = status.contains('entregado');
    final isRoute = status.contains('ruta') || status.contains('recibido');

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    processing || isDelivered
                        ? null
                        : (isRoute ? onDeliver : onReception),
                icon: Icon(
                  isRoute
                      ? Icons.check_circle_outline
                      : Icons.inventory_2_outlined,
                ),
                label: Text(isRoute ? 'Entregar' : 'Recepcionar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: processing || isDelivered ? null : onReschedule,
                icon: const Icon(Icons.event_repeat_outlined),
                label: const Text('Reprogramar'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    processing || isRoute || isDelivered ? null : onStartRoute,
                icon: const Icon(Icons.route_outlined),
                label: const Text('Iniciar ruta'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: processing ? null : onMap,
                icon: const Icon(Icons.navigation_outlined),
                label: const Text('Mapa'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.orders});
  final List<DeliveryOrder> orders;

  @override
  Widget build(BuildContext context) {
    final assigned =
        orders.where((o) {
          final s = o.status.toLowerCase();
          return !s.contains('ruta') &&
              !s.contains('recibido') &&
              !s.contains('entregado');
        }).length;
    final route =
        orders.where((o) {
          final s = o.status.toLowerCase();
          return s.contains('ruta') || s.contains('recibido');
        }).length;
    final delivered =
        orders
            .where((o) => o.status.toLowerCase().contains('entregado'))
            .length;
    final amount = orders.fold<double>(
      0,
      (sum, order) => sum + order.amountDue,
    );

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.surface2,
                AppTheme.purple.withValues(alpha: .27),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.purple.withValues(alpha: .25)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.purple.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  color: AppTheme.purpleLight,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monto pendiente por cobrar',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      peruvianCurrency.format(amount),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${orders.length}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.purpleLight,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'Asignados',
                value: assigned,
                color: AppTheme.purpleLight,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Metric(
                label: 'En ruta',
                value: route,
                color: AppTheme.warning,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Metric(
                label: 'Entregados',
                value: delivered,
                color: AppTheme.success,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FilterButton(
            label: 'Asignados',
            value: 'asignados',
            selected: selected,
            onSelected: onSelected,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _FilterButton(
            label: 'En ruta',
            value: 'ruta',
            selected: selected,
            onSelected: onSelected,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _FilterButton(
            label: 'Entregados',
            value: 'entregados',
            selected: selected,
            onSelected: onSelected,
          ),
        ),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final active = selected == value;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: 50,
      decoration: BoxDecoration(
        gradient:
            active
                ? const LinearGradient(
                  colors: [AppTheme.purpleDark, AppTheme.purple],
                )
                : null,
        color: active ? null : AppTheme.surface,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: () => onSelected(value),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                color: active ? Colors.white : AppTheme.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.purple.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppTheme.purpleLight, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});
  final String filter;

  @override
  Widget build(BuildContext context) {
    final text = switch (filter) {
      'ruta' => 'No tienes pedidos en ruta',
      'entregados' => 'Todavía no tienes pedidos entregados',
      _ => 'No tienes pedidos asignados todavía',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: AppTheme.purple.withValues(alpha: .13),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 38,
                color: AppTheme.purpleLight,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            const Text(
              'Desliza hacia abajo para actualizar la información.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(28),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * .12),
        const Icon(Icons.cloud_off_rounded, size: 64, color: AppTheme.danger),
        const SizedBox(height: 18),
        const Text(
          'No pudimos cargar tus pedidos',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textMuted),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Volver a intentar'),
        ),
      ],
    );
  }
}

class _OrdersLoading extends StatelessWidget {
  const _OrdersLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(18),
      itemCount: 5,
      itemBuilder:
          (context, index) => Container(
            height: index == 0 ? 126 : 150,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
    );
  }
}
