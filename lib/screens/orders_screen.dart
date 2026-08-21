import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../core/app_theme.dart';
import '../core/currency_format.dart';
import '../core/external_navigation.dart';
import '../core/media_url.dart';
import '../models/order.dart';
import '../models/payment_method.dart';
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
              message: _actionError(error),
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
                                ? () => _focusOnRouteMap(order)
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
    switch (selected) {
      case 'ruta':
        return items.where((order) => order.isInRoute).toList();
      case 'entregados':
        return items.where((order) => order.isDelivered).toList();
      default:
        return items
            .where((order) => !order.isDelivered && !order.isInRoute)
            .toList();
    }
  }

  void _focusOnRouteMap(DeliveryOrder order) {
    ref.read(focusedOrderIdProvider.notifier).state = order.id;
    ref.read(homeTabIndexProvider.notifier).state = 2;
  }

  Future<void> _openNavigation(
    BuildContext context,
    DeliveryOrder order,
  ) async {
    await openExternalNavigation(context, order);
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
                                        order.externalRef,
                                        orderId: order.id,
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
                              onSuccess: () => _focusOnRouteMap(order),
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
    VoidCallback? onSuccess,
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
      onSuccess?.call();
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
    final proceed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Dos fotos de evidencia'),
            content: const Text(
              'Para completar la entrega tomarás dos fotos consecutivas. '
              'Verifica que ambas evidencias sean claras.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Comenzar'),
              ),
            ],
          ),
    );
    if (proceed != true || !context.mounted) return;

    _SelectedPayment? payment;
    if (order.amountDue > 0) {
      payment = await _selectPaymentMethod(context, order);
      if (payment == null || !context.mounted) return;
    }

    final picker = ImagePicker();
    final firstImage = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 78,
      maxWidth: 1600,
    );
    if (firstImage == null || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Primera foto lista. Toma la segunda.')),
    );
    final secondImage = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 78,
      maxWidth: 1600,
    );
    if (secondImage == null || !context.mounted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Entrega no confirmada: falta la segunda foto de evidencia.',
            ),
          ),
        );
      }
      return;
    }

    await _runOrderAction(
      context,
      successMessage: 'Pedido entregado con dos evidencias.',
      onSuccess: () {
        final delivered = order.withStatus('entregado');
        final notifier = ref.read(deliveredOrdersProvider.notifier);
        notifier.state = [
          delivered,
          ...notifier.state.where((item) => item.id != order.id),
        ];
        setState(() => selected = 'entregados');
      },
      action:
          () => ref
              .read(apiProvider)
              .confirmDelivery(
                order.id,
                operationId: order.operationId,
                evidencePaths: [firstImage.path, secondImage.path],
                medioPago: payment?.medioPago,
                yapeAlias: payment?.yapeAlias,
                montoEfectivo: payment?.montoEfectivo,
                nroOperacion: payment?.nroOperacion,
              ),
    );
  }

  Future<_SelectedPayment?> _selectPaymentMethod(
    BuildContext context,
    DeliveryOrder order,
  ) {
    return showModalBottomSheet<_SelectedPayment>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: .82,
            minChildSize: .5,
            maxChildSize: .95,
            builder:
                (context, controller) =>
                    _PaymentMethodSheet(order: order, scrollController: controller),
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
    if (error is DioException) {
      final serverMessage = _serverMessage(error.response?.data);
      if (serverMessage != null) return serverMessage;
      if (error.response?.statusCode != null) {
        return 'No se pudo completar la acción (error ${error.response!.statusCode}).';
      }
      return 'No se pudo conectar con el servidor. Revisa tu conexión.';
    }

    final text = error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Bad state: ', '');
    return text.isEmpty ? 'No se pudo completar la acción.' : text;
  }

  String? _serverMessage(dynamic data) {
    if (data is Map) {
      final message = data['message'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString();
      }
    }
    return null;
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
    final isDelivered = order.isDelivered;
    final isRoute = order.isInRoute;

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
          return !o.isInRoute && !o.isDelivered;
        }).length;
    final route = orders.where((o) => o.isInRoute).length;
    final delivered = orders.where((o) => o.isDelivered).length;
    final amount = orders.fold<double>(
      0,
      (sum, order) => sum + (order.isDelivered ? 0 : order.amountDue),
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

class _SelectedPayment {
  const _SelectedPayment({
    this.medioPago,
    this.yapeAlias,
    this.montoEfectivo,
    this.nroOperacion,
  });

  final String? medioPago;
  final String? yapeAlias;
  final double? montoEfectivo;
  final String? nroOperacion;
}

class _PaymentMethodSheet extends ConsumerStatefulWidget {
  const _PaymentMethodSheet({
    required this.order,
    required this.scrollController,
  });

  final DeliveryOrder order;
  final ScrollController scrollController;

  @override
  ConsumerState<_PaymentMethodSheet> createState() =>
      _PaymentMethodSheetState();
}

class _PaymentMethodSheetState extends ConsumerState<_PaymentMethodSheet> {
  late final Future<List<PaymentMethod>> _future;
  PaymentMethod? _selectedMethod;
  PaymentAccount? _selectedAccount;
  final _referenceController = TextEditingController();
  final _cashController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiProvider).getPaymentMethods(widget.order.id);
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _cashController.dispose();
    super.dispose();
  }

  bool get _isCash {
    final method = _selectedMethod;
    if (method == null) return false;
    return method.codigo.toUpperCase() == 'EFECTIVO' ||
        method.nombre.toLowerCase().contains('efectivo');
  }

  bool get _canContinue {
    final method = _selectedMethod;
    if (method == null) return false;
    if (method.cuentas.isNotEmpty && _selectedAccount == null) return false;
    if (method.requiereReferencia &&
        _referenceController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  void _confirm() {
    final method = _selectedMethod!;
    final cashAmount =
        _isCash
            ? double.tryParse(_cashController.text.trim().replaceAll(',', '.'))
            : null;
    Navigator.pop(
      context,
      _SelectedPayment(
        medioPago: method.codigo.isNotEmpty ? method.codigo : method.nombre,
        yapeAlias: _selectedAccount?.alias,
        montoEfectivo: cashAmount,
        nroOperacion:
            method.requiereReferencia
                ? _referenceController.text.trim()
                : null,
      ),
    );
  }

  void _skip() => Navigator.pop(context, const _SelectedPayment());

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: FutureBuilder<List<PaymentMethod>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return _buildError(context);
          }
          final methods = snapshot.data ?? const [];
          if (methods.isEmpty) {
            return _buildError(
              context,
              message: 'No hay medios de pago configurados.',
            );
          }
          return _buildContent(context, methods);
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, {String? message}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: AppTheme.warning,
          ),
          const SizedBox(height: 14),
          Text(
            message ?? 'No se pudieron cargar los medios de pago.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _skip,
              child: const Text('Continuar sin medio de pago'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<PaymentMethod> methods) {
    final method = _selectedMethod;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 48,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
            children: [
              const Text(
                'Medio de pago',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'Saldo a cobrar: ${peruvianCurrency.format(widget.order.amountDue)}',
                style: const TextStyle(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 18),
              ...methods.map(
                (m) => _MethodTile(
                  method: m,
                  selected: method?.id == m.id,
                  onTap:
                      () => setState(() {
                        _selectedMethod = m;
                        _selectedAccount =
                            m.cuentas.length == 1 ? m.cuentas.first : null;
                        _referenceController.clear();
                      }),
                ),
              ),
              if (method != null && method.cuentas.length > 1) ...[
                const SizedBox(height: 16),
                const Text(
                  'Cuenta a mostrar al cliente',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      method.cuentas
                          .map(
                            (a) => ChoiceChip(
                              label: Text(
                                a.alias ?? a.nombre ?? 'Cuenta ${a.id}',
                              ),
                              selected: _selectedAccount?.id == a.id,
                              onSelected:
                                  (_) => setState(() => _selectedAccount = a),
                            ),
                          )
                          .toList(),
                ),
              ],
              if (method != null && _selectedAccount != null) ...[
                const SizedBox(height: 16),
                _AccountCard(account: _selectedAccount!),
              ],
              if (method != null && method.requiereReferencia) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _referenceController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Número de operación',
                    hintText: 'Ej. 000123456',
                  ),
                ),
              ],
              if (method != null && _isCash) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _cashController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Monto cobrado (opcional)',
                    hintText: widget.order.amountDue.toStringAsFixed(2),
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _canContinue ? _confirm : null,
                  child: const Text('Continuar'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:
            selected ? AppTheme.purple.withValues(alpha: .22) : AppTheme.surface2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? AppTheme.purpleLight : Colors.transparent,
          width: 1.4,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppTheme.purpleLight : AppTheme.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (method.requiereReferencia)
                      const Text(
                        'Requiere número de operación',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account});

  final PaymentAccount account;

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveMediaUrl(account.imagenUrl);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          if (imageUrl != null)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showFullScreenQr(context, imageUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  width: 84,
                  height: 84,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, _, _) => Container(
                        width: 84,
                        height: 84,
                        color: AppTheme.background,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.qr_code_2,
                          color: AppTheme.textMuted,
                        ),
                      ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      width: 84,
                      height: 84,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                ),
              ),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.alias ?? account.nombre ?? 'Cuenta',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                if (account.banco != null && account.banco!.isNotEmpty)
                  Text(
                    account.banco!,
                    style: const TextStyle(
                      color: AppTheme.purpleLight,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                if (account.numero != null && account.numero!.isNotEmpty)
                  Text(
                    'Cuenta: ${account.numero}',
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                if (account.cci != null && account.cci!.isNotEmpty)
                  Text(
                    'CCI: ${account.cci}',
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                const SizedBox(height: 4),
                Text(
                  imageUrl != null
                      ? 'Toca el QR para ampliarlo y mostrárselo al cliente.'
                      : 'Muéstrale esto al cliente para que pague.',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
                if (imageUrl != null) ...[
                  const SizedBox(height: 4),
                  // ignore: avoid_print
                  Text(
                    'DEBUG: $imageUrl',
                    style: const TextStyle(color: Colors.orange, fontSize: 9),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenQr(BuildContext context, String imageUrl) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder:
          (dialogContext) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    imageUrl,
                    errorBuilder:
                        (_, _, _) => Container(
                          width: 260,
                          height: 260,
                          color: AppTheme.surface,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                            color: AppTheme.textMuted,
                          ),
                        ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  account.alias ?? account.nombre ?? 'Cuenta',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                if (account.banco != null && account.banco!.isNotEmpty)
                  Text(
                    account.banco!,
                    style: const TextStyle(
                      color: AppTheme.purpleLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (account.numero != null && account.numero!.isNotEmpty)
                  Text(
                    'Cuenta: ${account.numero}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                if (account.cci != null && account.cci!.isNotEmpty)
                  Text(
                    'CCI: ${account.cci}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          ),
    );
  }
}
