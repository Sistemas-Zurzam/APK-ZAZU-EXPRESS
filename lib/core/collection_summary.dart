import '../models/order.dart';

/// Resumen de cobros del día para rendir en caja.
///
/// Recaudado = saldo de los pedidos entregados. Se separa el efectivo (lo que
/// el motorizado entrega en caja) de lo cobrado por Yape, QR, transferencia o
/// tarjeta, que ya llegó a las cuentas de la empresa.
class CollectionSummary {
  CollectionSummary._({
    required this.pending,
    required this.pendingCount,
    required this.cash,
    required this.digital,
    required this.unregistered,
    required this.deliveredCount,
    required this.notDeliveredCount,
  });

  factory CollectionSummary.from(List<DeliveryOrder> orders) {
    var pending = 0.0, cash = 0.0, digital = 0.0, unregistered = 0.0;
    var pendingCount = 0, deliveredCount = 0, notDeliveredCount = 0;

    for (final order in orders) {
      if (order.isNotDelivered) {
        notDeliveredCount++;
        continue;
      }
      if (!order.isDelivered) {
        pending += order.amountDue;
        pendingCount++;
        continue;
      }
      deliveredCount++;
      final due = order.amountDue;
      if (due <= 0) continue;

      final method = (order.paymentMethod ?? '').trim().toUpperCase();
      // Cambio y Pago Completo no cobran nada al entregar.
      if (method == 'CAMBIO' || method == 'PAGO COMPLETO') continue;
      if (method.isEmpty) {
        unregistered += due;
        continue;
      }
      final isCashMethod = method == 'EFECTIVO' || method == 'CONTRA_ENTREGA';
      // Pago mixto: monto_efectivo es la parte en efectivo y el resto se pagó
      // con el medio digital registrado.
      final cashPart =
          isCashMethod ? due : (order.cashAmount ?? 0).clamp(0, due).toDouble();
      cash += cashPart;
      digital += due - cashPart;
    }

    return CollectionSummary._(
      pending: pending,
      pendingCount: pendingCount,
      cash: cash,
      digital: digital,
      unregistered: unregistered,
      deliveredCount: deliveredCount,
      notDeliveredCount: notDeliveredCount,
    );
  }

  /// Saldo de los pedidos que todavía faltan entregar.
  final double pending;
  final int pendingCount;

  /// Efectivo cobrado: lo que se entrega en caja.
  final double cash;

  /// Cobrado por Yape, Plin, QR, transferencia o tarjeta.
  final double digital;

  /// Entregados con saldo pero sin medio de pago registrado.
  final double unregistered;

  final int deliveredCount;
  final int notDeliveredCount;

  double get collected => cash + digital + unregistered;
}
