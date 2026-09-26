import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../core/app_theme.dart';
import '../core/currency_format.dart';
import '../core/external_navigation.dart';
import '../core/media_url.dart';
import '../core/route_rules.dart';
import '../models/order.dart';
import '../models/payment_method.dart';
import '../services/api_service.dart';
import '../state/providers.dart';
import '../widgets/order_card.dart';
import '../widgets/packing_order_sheet.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String selected = 'asignados';
  // Acción en curso ('primary' / 'route'); el bottom sheet la escucha
  // porque setState del screen no reconstruye el modal.
  final _runningAction = ValueNotifier<String?>(null);

  /// Fotos y montos ya cargados en el cobro, por pedido. Si el envío falla
  /// (servidor lento, sin señal), al reintentar siguen ahí y no hay que
  /// volver a tomar las fotos.
  final _deliveryDrafts = <int, _DeliveryDraft>{};

  @override
  void dispose() {
    _runningAction.dispose();
    super.dispose();
  }

  /// El mapa pidió entregar un pedido: se muestra En ruta, se abre su
  /// detalle y arranca el cobro directamente.
  void _handleDeliverRequest(int? orderId) {
    if (orderId == null) return;
    ref.read(deliverOrderRequestProvider.notifier).state = null;
    setState(() => selected = 'ruta');
    final items = ref.read(ordersProvider).valueOrNull ?? const [];
    final routeOrders = items.where((order) => order.isInRoute).toList();
    final index = routeOrders.indexWhere((order) => order.id == orderId);
    if (index == -1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showOrderDetails(
        context,
        routeOrders[index],
        index + 1,
        startDelivery: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int?>(
      deliverOrderRequestProvider,
      (_, orderId) => _handleDeliverRequest(orderId),
    );
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
      case 'recepcionados':
        return items.where((order) => order.isRecepcionado).toList();
      case 'ruta':
        return items.where((order) => order.isInRoute).toList();
      case 'entregados':
        return items.where((order) => order.isDelivered).toList();
      default:
        return items
            // Asignados: todavía sin recepcionar.
            .where((order) => !order.isReceived)
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
    int sequence, {
    bool startDelivery = false,
  }) {
    var deliveryStarted = !startDelivery;
    // Mismo total que usa el escáner para calcular el orden en mochila.
    final totalOrders = ref.read(ordersProvider).valueOrNull?.length ?? 0;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: .68,
            minChildSize: .48,
            maxChildSize: .92,
            builder: (context, controller) {
              if (!deliveryStarted) {
                deliveryStarted = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) _deliverWithEvidence(context, order);
                });
              }
              return Container(
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
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
                    ValueListenableBuilder<String?>(
                      valueListenable: _runningAction,
                      builder:
                          (context, runningAction, _) => _OrderActions(
                            order: order,
                            runningAction: runningAction,
                            onReception:
                                () =>
                                    _receiveOrder(context, order, totalOrders),
                            onStartRoute: () {
                              final blocked = startRouteBlockReason(
                                order,
                                ref.read(ordersProvider).valueOrNull ??
                                    const [],
                              );
                              if (blocked != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(blocked)),
                                );
                                return;
                              }
                              _runOrderAction(
                                context,
                                actionKey: 'route',
                                successMessage: 'Ruta iniciada.',
                                action:
                                    () => ref
                                        .read(apiProvider)
                                        .startRoute(
                                          order.id,
                                          operationId: order.operationId,
                                        ),
                                onSuccess: () => _focusOnRouteMap(order),
                              );
                            },
                            onDeliver:
                                () => _deliverWithEvidence(context, order),
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
              );
            },
          ),
    );
  }

  /// Tras recepcionar desde el detalle se muestra el mismo resultado que al
  /// escanear (grupo, orden de entrega y orden de carga en mochila).
  /// Un pedido ya recepcionado no se vuelve a enviar: se avisa y se muestra
  /// su orden en mochila. Si la lista local estaba desactualizada y el backend
  /// responde que ya estaba recepcionado, se muestra el mismo aviso.
  Future<void> _receiveOrder(
    BuildContext sheetContext,
    DeliveryOrder order,
    int totalOrders,
  ) async {
    if (order.isReceived) {
      Navigator.pop(sheetContext);
      await _showReceptionResult(order, totalOrders, alreadyReceived: true);
      return;
    }
    var alreadyReceived = false;
    await _runOrderAction(
      sheetContext,
      actionKey: 'primary',
      action: () async {
        try {
          await ref
              .read(apiProvider)
              .confirmReception(
                order.externalRef,
                orderId: order.id,
                operationId: order.operationId,
              );
        } catch (error) {
          if (!ApiService.isAlreadyReceivedError(error)) rethrow;
          alreadyReceived = true;
        }
      },
      onSuccess:
          () => _showReceptionResult(
            order,
            totalOrders,
            alreadyReceived: alreadyReceived,
          ),
    );
  }

  /// [totalOrders] se toma antes de recepcionar: después ordersProvider se
  /// invalida y la lista puede estar vacía mientras recarga.
  Future<void> _showReceptionResult(
    DeliveryOrder order,
    int totalOrders, {
    bool alreadyReceived = false,
  }) async {
    if (!mounted) return;
    await showPackingOrderSheet(
      context,
      order,
      totalOrders,
      alreadyReceived: alreadyReceived,
    );
    // "Escanear siguiente" lleva a la pestaña del escáner.
    if (mounted) ref.read(homeTabIndexProvider.notifier).state = 1;
  }

  Future<void> _runOrderAction(
    BuildContext context, {
    required String actionKey,
    required Future<void> Function() action,
    String? successMessage,
    VoidCallback? onSuccess,
    void Function(String message)? onError,
  }) async {
    if (_runningAction.value != null) return;
    _runningAction.value = actionKey;
    try {
      await action();
      ref.invalidate(ordersProvider);
      if (!context.mounted) return;
      Navigator.pop(context);
      if (successMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
      onSuccess?.call();
    } catch (error) {
      if (!context.mounted) return;
      if (onError != null) {
        onError(_actionError(error));
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_actionError(error))));
    } finally {
      _runningAction.value = null;
    }
  }

  Future<void> _deliverWithEvidence(
    BuildContext context,
    DeliveryOrder order,
  ) async {
    final draft = _deliveryDrafts.putIfAbsent(order.id, _DeliveryDraft.new);
    _SelectedPayment? payment;
    if (order.amountDue > 0) {
      payment = await _selectPaymentMethod(context, order, draft);
      if (payment == null || !context.mounted) return;
    }

    // En pago mixto las fotos ya se tomaron en la pantalla de cobro.
    final evidencePaths =
        payment?.evidencePaths ?? await _takeDeliveryPhotos(context);
    if (evidencePaths == null || !context.mounted) return;

    await _runOrderAction(
      context,
      actionKey: 'primary',
      successMessage:
          payment?.paymentProofPath != null
              ? 'Pedido entregado con tres evidencias.'
              : 'Pedido entregado con dos evidencias.',
      onError: (message) => _showDeliveryError(context, order, message),
      onSuccess: () {
        _deliveryDrafts.remove(order.id);
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
                evidencePaths: evidencePaths,
                medioPago: payment?.medioPago,
                yapeAlias: payment?.yapeAlias,
                montoEfectivo: payment?.montoEfectivo,
                nroOperacion: payment?.nroOperacion,
                paymentProofPath: payment?.paymentProofPath,
              ),
    );
  }

  /// El error se muestra completo (un snackbar desaparece antes de leerlo)
  /// y se ofrece reintentar con las mismas fotos.
  Future<void> _showDeliveryError(
    BuildContext context,
    DeliveryOrder order,
    String message,
  ) async {
    final retry = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            icon: const Icon(Icons.cloud_off_outlined, color: AppTheme.warning),
            title: const Text('No se pudo registrar la entrega'),
            content: Text(
              '$message\n\nTus fotos y datos del cobro se guardaron: al '
              'reintentar no tienes que tomarlas de nuevo.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cerrar'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
    );
    if (retry == true && context.mounted) {
      await _deliverWithEvidence(context, order);
    }
  }

  /// Dos fotos consecutivas con la cámara. Devuelve null si se cancela.
  Future<List<String>?> _takeDeliveryPhotos(BuildContext context) async {
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
    if (proceed != true || !context.mounted) return null;

    final picker = ImagePicker();
    final firstImage = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 78,
      maxWidth: 1600,
    );
    if (firstImage == null || !context.mounted) return null;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Primera foto lista. Toma la segunda.')),
    );
    final secondImage = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 78,
      maxWidth: 1600,
    );
    if (secondImage == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Entrega no confirmada: falta la segunda foto de evidencia.',
            ),
          ),
        );
      }
      return null;
    }
    return [firstImage.path, secondImage.path];
  }

  Future<_SelectedPayment?> _selectPaymentMethod(
    BuildContext context,
    DeliveryOrder order,
    _DeliveryDraft draft,
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
                (context, controller) => SafeArea(
                  top: false,
                  child: _PaymentMethodSheet(
                    order: order,
                    draft: draft,
                    scrollController: controller,
                  ),
                ),
          ),
    );
  }

  Future<void> _showRescheduleDialog(
    BuildContext context,
    DeliveryOrder order,
  ) async {
    final result = await showDialog<({String reason, String date})>(
      context: context,
      builder: (context) => const _RescheduleDialog(),
    );
    if (result == null || !context.mounted) return;

    await _runOrderAction(
      context,
      actionKey: 'reschedule',
      successMessage: 'Pedido reprogramado.',
      action:
          () => ref
              .read(apiProvider)
              .rescheduleOrder(
                order.id,
                result.reason,
                result.date,
                operationId: order.operationId,
              ),
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

/// Motivo y nueva fecha. La fecha se elige en un calendario (desde mañana)
/// y se envía como YYYY-MM-DD, el formato que espera el backend.
/// Casilla de una foto de evidencia: vacía invita a tomarla; con foto
/// muestra la miniatura y permite cambiarla o quitarla.
class _EvidenceSlot extends StatelessWidget {
  const _EvidenceSlot({
    required this.label,
    required this.caption,
    required this.required,
    required this.photo,
    required this.onPick,
    required this.onRemove,
  });

  final String label;
  final String caption;
  final bool required;
  final XFile? photo;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final image = photo;
    return AspectRatio(
      aspectRatio: .8,
      child: Material(
        color: AppTheme.surface2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color:
                image != null
                    ? AppTheme.success
                    : (required ? AppTheme.warning : AppTheme.surface2),
          ),
        ),
        child: InkWell(
          onTap: onPick,
          child:
              image == null
                  ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_a_photo_outlined,
                        color: AppTheme.purpleLight,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        caption,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  )
                  : Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(image.path), fit: BoxFit.cover),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          color: Colors.black54,
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: IconButton.filled(
                          tooltip: 'Quitar $label',
                          visualDensity: VisualDensity.compact,
                          iconSize: 16,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                          ),
                          onPressed: onRemove,
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}

class _RescheduleDialog extends StatefulWidget {
  const _RescheduleDialog();

  @override
  State<_RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<_RescheduleDialog> {
  final _reasonController = TextEditingController();
  DateTime? _date;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String _apiDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today.add(const Duration(days: 1)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 60)),
      helpText: 'Nueva fecha de entrega',
      cancelText: 'Cancelar',
      confirmText: 'Elegir',
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _error = null;
      });
    }
  }

  void _submit() {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty || _date == null) {
      setState(
        () =>
            _error =
                reason.isEmpty
                    ? 'Escribe el motivo de la reprogramación.'
                    : 'Elige la nueva fecha de entrega.',
      );
      return;
    }
    Navigator.pop(context, (reason: reason, date: _apiDate(_date!)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reprogramar pedido'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              labelText: 'Motivo',
              hintText: 'Ej.: cliente no se encuentra',
            ),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              _date == null ? 'Elegir nueva fecha' : _displayDate(_date!),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppTheme.danger)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Enviar')),
      ],
    );
  }
}

class _OrderActions extends StatelessWidget {
  const _OrderActions({
    required this.order,
    required this.runningAction,
    required this.onReception,
    required this.onStartRoute,
    required this.onDeliver,
    required this.onReschedule,
    required this.onMap,
  });

  final DeliveryOrder order;
  final String? runningAction;
  final VoidCallback onReception;
  final VoidCallback onStartRoute;
  final VoidCallback onDeliver;
  final VoidCallback onReschedule;
  final VoidCallback? onMap;

  @override
  Widget build(BuildContext context) {
    final isDelivered = order.isDelivered;
    final isRoute = order.isInRoute;
    final processing = runningAction != null;
    // Un pedido ya recepcionado (o entregado) no vuelve a mostrar
    // "Recepcionar"; en ruta el mismo botón pasa a ser "Entregar".
    final showPrimary = isRoute || !order.isReceived;

    return Column(
      children: [
        Row(
          children: [
            if (showPrimary) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      processing || isDelivered
                          ? null
                          : (isRoute ? onDeliver : onReception),
                  icon:
                      runningAction == 'primary'
                          ? const _ButtonSpinner()
                          : Icon(
                            isRoute
                                ? Icons.check_circle_outline
                                : Icons.inventory_2_outlined,
                          ),
                  label: Text(
                    runningAction == 'primary'
                        ? (isRoute ? 'Entregando...' : 'Recepcionando...')
                        : (isRoute ? 'Entregar' : 'Recepcionar'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
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
                icon:
                    runningAction == 'route'
                        ? const _ButtonSpinner()
                        : const Icon(Icons.route_outlined),
                label: Text(
                  runningAction == 'route' ? 'Iniciando...' : 'Iniciar ruta',
                ),
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

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2.2),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.orders});
  final List<DeliveryOrder> orders;

  @override
  Widget build(BuildContext context) {
    final assigned = orders.where((o) => !o.isReceived).length;
    final received = orders.where((o) => o.isRecepcionado).length;
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
                '${orders.length - delivered}',
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
                label: 'Recepcionados',
                value: received,
                color: AppTheme.info,
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
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
            label: 'Recepcionados',
            value: 'recepcionados',
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                    color: active ? Colors.white : AppTheme.textMuted,
                  ),
                ),
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
      'recepcionados' => 'No tienes pedidos recepcionados',
      'ruta' => 'No tienes pedidos en ruta',
      'entregados' => 'Todavía no tienes pedidos entregados',
      _ => 'No tienes pedidos por recepcionar',
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
    this.paymentProofPath,
    this.evidencePaths,
  });

  final String? medioPago;
  final String? yapeAlias;
  final double? montoEfectivo;
  final String? nroOperacion;
  final String? paymentProofPath;

  /// Fotos 1 y 2 de la entrega cuando ya se tomaron en la pantalla de cobro
  /// (pago mixto). Si es null, se toman con la cámara después del cobro.
  final List<String>? evidencePaths;
}

/// Lo que el motorizado ya cargó en el cobro de un pedido. Sobrevive a cerrar
/// la pantalla de cobro, para no perder las fotos si la entrega falla.
class _DeliveryDraft {
  final List<XFile?> photos = List<XFile?>.filled(3, null);
  int? methodId;
  bool isMixed = false;
  String cashText = '';
  String referenceText = '';
}

class _PaymentMethodSheet extends ConsumerStatefulWidget {
  const _PaymentMethodSheet({
    required this.order,
    required this.draft,
    required this.scrollController,
  });

  final DeliveryOrder order;
  final _DeliveryDraft draft;
  final ScrollController scrollController;

  @override
  ConsumerState<_PaymentMethodSheet> createState() =>
      _PaymentMethodSheetState();
}

class _PaymentMethodSheetState extends ConsumerState<_PaymentMethodSheet> {
  late final Future<List<PaymentMethod>> _future;
  PaymentMethod? _selectedMethod;
  PaymentAccount? _selectedAccount;
  bool _isMixed = false;
  late final _referenceController = TextEditingController(
    text: widget.draft.referenceText,
  );
  late final _cashController = TextEditingController(
    text: widget.draft.cashText,
  );

  /// Foto 1 y Foto 2 (entrega) y Foto 3 (comprobante), en cualquier medio.
  /// Es la lista del borrador: lo que se toma aquí queda guardado.
  List<XFile?> get _photos => widget.draft.photos;

  /// El comprobante (Foto 3) es obligatorio en pagos digitales y mixtos; en
  /// efectivo o contra entrega no hay comprobante que fotografiar.
  bool get _requiresProofPhoto => _isMixed || _supportsPaymentProof;

  bool get _photosComplete =>
      _photos[0] != null &&
      _photos[1] != null &&
      (!_requiresProofPhoto || _photos[2] != null);

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiProvider).getPaymentMethods(widget.order.id);
  }

  @override
  void dispose() {
    widget.draft
      ..referenceText = _referenceController.text
      ..cashText = _cashController.text
      ..methodId = _selectedMethod?.id
      ..isMixed = _isMixed;
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

  bool get _requiresReference => _selectedMethod?.requiereReferencia ?? false;

  bool get _supportsPaymentProof {
    if (_isMixed) return true;
    final method = _selectedMethod;
    if (method == null || _isCash) return false;
    final value = '${method.codigo} ${method.nombre}'.toLowerCase();
    return value.contains('qr') ||
        value.contains('yape') ||
        value.contains('plin') ||
        value.contains('transfer') ||
        value.contains('tarjeta');
  }

  /// En efectivo se cobra siempre el saldo completo (no editable); en pago
  /// mixto el motorizado ingresa la parte pagada en efectivo.
  double? get _cashAmount =>
      _isCash && !_isMixed
          ? widget.order.amountDue
          : double.tryParse(_cashController.text.trim().replaceAll(',', '.'));

  double? get _digitalAmount {
    final cash = _cashAmount;
    if (cash == null) return null;
    return widget.order.amountDue - cash;
  }

  bool _isDigitalMethod(PaymentMethod method) {
    final value = '${method.codigo} ${method.nombre}'.toLowerCase();
    return value.contains('qr') ||
        value.contains('yape') ||
        value.contains('transferencia');
  }

  bool get _canContinue {
    final method = _selectedMethod;
    if (method == null) return false;
    if (method.cuentas.isNotEmpty && _selectedAccount == null) return false;
    if (_requiresReference && _referenceController.text.trim().isEmpty) {
      return false;
    }
    if (_isMixed) {
      final cash = _cashAmount;
      if (cash == null || cash <= 0 || cash >= widget.order.amountDue) {
        return false;
      }
    }
    return _photosComplete;
  }

  void _confirm() {
    final method = _selectedMethod!;
    final cashAmount = _isCash || _isMixed ? _cashAmount : null;
    Navigator.pop(
      context,
      _SelectedPayment(
        // La opción "QR" se registra con el medio real del QR elegido.
        medioPago:
            method.id == ApiService.qrMethodId
                ? (_selectedAccount?.paymentCode ?? 'QR')
                : (method.codigo.isNotEmpty ? method.codigo : method.nombre),
        yapeAlias: _selectedAccount?.alias,
        montoEfectivo: cashAmount,
        nroOperacion:
            _requiresReference ? _referenceController.text.trim() : null,
        paymentProofPath: _photos[2]?.path,
        evidencePaths: [_photos[0]!.path, _photos[1]!.path],
      ),
    );
  }

  Future<void> _pickPhoto(int index) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.surface,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Foto ${index + 1}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Tomar foto'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.add_photo_alternate_outlined),
                  title: const Text('Elegir de la galería'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
    );
    if (source == null) return;
    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 78,
      maxWidth: 1600,
    );
    if (image != null && mounted) {
      setState(() => _photos[index] = image);
    }
  }

  bool _draftRestored = false;

  /// Al reintentar una entrega, vuelve a marcar el medio elegido la vez
  /// anterior (las fotos y los montos ya vienen del borrador).
  void _restoreDraftMethod(List<PaymentMethod> methods) {
    if (_draftRestored) return;
    _draftRestored = true;
    final id = widget.draft.methodId;
    if (id == null || _selectedMethod != null) return;
    for (final m in methods) {
      if (m.id != id) continue;
      _selectedMethod = m;
      _isMixed = widget.draft.isMixed;
      _selectedAccount = m.cuentas.isEmpty ? null : m.cuentas.first;
      return;
    }
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
    _restoreDraftMethod(methods);
    final method = _selectedMethod;
    final mixedMethods = methods.where(_isDigitalMethod).toList();
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
              if (mixedMethods.isNotEmpty)
                _MixedPaymentTile(
                  selected: _isMixed,
                  onTap:
                      () => setState(() {
                        _isMixed = true;
                        _selectedMethod = mixedMethods.first;
                        _selectedAccount =
                            mixedMethods.first.cuentas.isEmpty
                                ? null
                                : mixedMethods.first.cuentas.first;
                        _referenceController.clear();
                      }),
                ),
              ...methods.map(
                (m) => _MethodTile(
                  method: m,
                  selected: method?.id == m.id,
                  onTap:
                      () => setState(() {
                        _selectedMethod = m;
                        _isMixed = false;
                        _selectedAccount =
                            m.cuentas.isEmpty ? null : m.cuentas.first;
                        _referenceController.clear();
                        _cashController.clear();
                      }),
                ),
              ),
              if (_isMixed) ...[
                const SizedBox(height: 8),
                const Text(
                  'Pago digital para el saldo restante',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      mixedMethods
                          .map(
                            (m) => ChoiceChip(
                              label: Text(m.nombre),
                              selected: method?.id == m.id,
                              onSelected:
                                  (_) => setState(() {
                                    _selectedMethod = m;
                                    _selectedAccount =
                                        m.cuentas.isEmpty
                                            ? null
                                            : m.cuentas.first;
                                    _referenceController.clear();
                                  }),
                            ),
                          )
                          .toList(),
                ),
              ],
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
              if (method != null && _requiresReference) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _referenceController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Número de operación *',
                    hintText: 'Ej. 000123456',
                  ),
                ),
              ],
              if (method != null && (_isCash || _isMixed)) ...[
                const SizedBox(height: 16),
                if (_isMixed)
                  TextField(
                    controller: _cashController,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Monto pagado en efectivo *',
                      hintText: 'Obligatorio',
                      prefixText: 'S/ ',
                      helperText:
                          'Menor que el saldo de '
                          '${peruvianCurrency.format(widget.order.amountDue)}',
                    ),
                  )
                else
                  TextFormField(
                    key: const ValueKey('cash-full-amount'),
                    initialValue: peruvianCurrency.format(
                      widget.order.amountDue,
                    ),
                    readOnly: true,
                    enableInteractiveSelection: false,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.success,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Monto a cobrar en efectivo',
                      helperText: 'Se cobra el saldo completo del pedido.',
                      suffixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                if (_isMixed) ...[
                  const SizedBox(height: 8),
                  Text(
                    _digitalAmount == null
                        ? 'Ingresa el efectivo para calcular el pago digital.'
                        : _digitalAmount! <= 0
                        ? 'El efectivo debe ser menor que el saldo total.'
                        : 'Pago digital restante: ${peruvianCurrency.format(_digitalAmount!)}',
                    style: TextStyle(
                      color:
                          _digitalAmount != null && _digitalAmount! > 0
                              ? AppTheme.textMuted
                              : AppTheme.warning,
                    ),
                  ),
                ],
              ],
              if (method != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Fotos de evidencia',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  _requiresProofPhoto
                      ? 'Obligatorias: dos de la entrega y una del '
                          'comprobante del pago.'
                      : 'Obligatorias las dos de la entrega. La tercera es '
                          'opcional.',
                  style: TextStyle(
                    color:
                        _photosComplete ? AppTheme.textMuted : AppTheme.warning,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: _EvidenceSlot(
                          label: 'Foto ${i + 1}',
                          caption:
                              i < 2
                                  ? 'Entrega'
                                  : (_requiresProofPhoto
                                      ? 'Comprobante'
                                      : 'Opcional'),
                          required: i < 2 || _requiresProofPhoto,
                          photo: _photos[i],
                          onPick: () => _pickPhoto(i),
                          onRemove: () => setState(() => _photos[i] = null),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.only(top: 8),
          child: Padding(
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
            selected
                ? AppTheme.purple.withValues(alpha: .22)
                : AppTheme.surface2,
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

class _MixedPaymentTile extends StatelessWidget {
  const _MixedPaymentTile({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:
            selected
                ? AppTheme.purple.withValues(alpha: .22)
                : AppTheme.surface2,
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pago mixto',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Efectivo + QR o transferencia',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
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
