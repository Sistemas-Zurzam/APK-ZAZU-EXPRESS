import '../models/order.dart';

/// Resumen de cobros del día para rendir en caja.
///
/// Separa el efectivo que el motorizado entrega en caja y lo cobrado por Ligo,
/// Yape, QR, transferencia u otros medios digitales.
class CollectionSummary {
  CollectionSummary._({
    required this.pending,
    required this.pendingCount,
    required this.cash,
    required this.digital,
    required this.byMethod,
    required this.unregistered,
    required this.deliveredCount,
    required this.notDeliveredCount,
  });

  factory CollectionSummary.from(List<DeliveryOrder> orders) {
    var pending = 0.0, cash = 0.0, digital = 0.0, unregistered = 0.0;
    var pendingCount = 0, deliveredCount = 0, notDeliveredCount = 0;
    final methodTotals = <String, double>{};

    void addMethod(String method, double amount) {
      if (amount <= 0) return;
      methodTotals.update(
        method,
        (total) => total + amount,
        ifAbsent: () => amount,
      );
    }

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
      final method = (order.paymentMethod ?? '').trim().toUpperCase();
      final ligoPaid = order.ligoPaidAmount;
      if (ligoPaid > 0) {
        digital += ligoPaid;
        addMethod('Ligo Pay', ligoPaid);
      }

      // Cambio y Pago Completo no cobran nada al entregar.
      if (method == 'CAMBIO' || method == 'PAGO COMPLETO') continue;
      final due = order.amountDue;
      if (due <= 0) {
        if (method == 'LIGO PAY' && ligoPaid <= 0) {
          addMethod('Ligo Pay', order.amountDue);
          digital += order.amountDue;
        }
        continue;
      }

      if (method == 'LIGO PAY') {
        if (ligoPaid <= 0) {
          digital += due;
          addMethod('Ligo Pay', due);
        }
        continue;
      }

      final isCashMethod =
          method == 'EFECTIVO' || method == 'CONTRA_ENTREGA';
      // Pago mixto: monto_efectivo es la parte en efectivo y el resto se pagó
      // con el medio digital registrado.
      final cashPart =
          isCashMethod ? due : (order.cashAmount ?? 0).clamp(0, due).toDouble();
      final digitalPart = due - cashPart;
      cash += cashPart;
      addMethod('Efectivo', cashPart);

      if (digitalPart <= 0) continue;
      if (method.isEmpty || method == 'MIXTO') {
        unregistered += digitalPart;
        addMethod('Sin medio de pago registrado', digitalPart);
        continue;
      }

      digital += digitalPart;
      addMethod(_methodLabel(method), digitalPart);
    }

    const methodOrder = [
      'Efectivo',
      'Ligo Pay',
      'Yape',
      'Plin',
      'QR',
      'Transferencia',
      'Tarjeta',
      'Sin medio de pago registrado',
    ];
    final orderedTotals = <String, double>{};
    for (final name in methodOrder) {
      final amount = methodTotals[name];
      if (amount != null && amount > 0) orderedTotals[name] = amount;
    }
    for (final entry in methodTotals.entries) {
      if (!orderedTotals.containsKey(entry.key)) {
        orderedTotals[entry.key] = entry.value;
      }
    }

    return CollectionSummary._(
      pending: pending,
      pendingCount: pendingCount,
      cash: cash,
      digital: digital,
      byMethod: Map.unmodifiable(orderedTotals),
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

  /// Cobrado por Ligo Pay, Yape, Plin, QR, transferencia o tarjeta.
  final double digital;

  /// Importe recaudado por cada medio. Un pago mixto queda dividido entre
  /// Efectivo y el medio digital enviado por el motorizado.
  final Map<String, double> byMethod;

  /// Entregados con saldo pero sin medio de pago registrado.
  final double unregistered;

  final int deliveredCount;
  final int notDeliveredCount;

  double get collected => cash + digital + unregistered;

  static String _methodLabel(String method) {
    if (method.contains('LIGO')) return 'Ligo Pay';
    if (method.contains('EFECTIVO') || method.contains('CONTRA_ENTREGA')) {
      return 'Efectivo';
    }
    if (method.contains('YAPE')) return 'Yape';
    if (method.contains('PLIN')) return 'Plin';
    if (method.contains('TRANSFER') || method.contains('BANCO')) {
      return 'Transferencia';
    }
    if (method.contains('QR')) return 'QR';
    if (method.contains('TARJETA') || method.contains('CARD')) return 'Tarjeta';

    return method
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          final lower = word.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }
}
