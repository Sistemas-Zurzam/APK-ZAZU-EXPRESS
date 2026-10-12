import 'package:flutter_test/flutter_test.dart';
import 'package:zazu_driver/core/collection_summary.dart';
import 'package:zazu_driver/models/order.dart';

DeliveryOrder _order(
  String estado,
  double saldo, {
  String? medio,
  double? efectivo,
}) => DeliveryOrder.fromJson({
  'id': 1,
  'external_ref': 'Overshark/1',
  'estado': estado,
  'cuenta_cliente': saldo,
  if (medio != null) 'medio_pago': medio,
  if (efectivo != null) 'monto_efectivo': efectivo,
});

void main() {
  test('separa efectivo para caja, digital y pendiente', () {
    final summary = CollectionSummary.from([
      _order('entregado', 100, medio: 'EFECTIVO', efectivo: 100),
      _order('entregado', 80, medio: 'YAPE'),
      // Mixto: 30 en efectivo y 50 por QR.
      _order('entregado', 80, medio: 'PLIN', efectivo: 30),
      _order('entregado', 60, medio: 'CONTRA_ENTREGA'),
      _order('entregado', 90, medio: 'Cambio'),
      _order('entregado', 40, medio: 'Pago Completo'),
      _order('en_ruta', 70),
      _order('asignado', 20),
      _order('no_entregado', 55),
    ]);

    expect(summary.cash, 190);
    expect(summary.digital, 130);
    expect(summary.collected, 320);
    expect(summary.deliveredCount, 6);
    expect(summary.pending, 90);
    expect(summary.pendingCount, 2);
    expect(summary.notDeliveredCount, 1);
  });

  test('un entregado sin medio registrado no se pierde del total', () {
    final summary = CollectionSummary.from([_order('entregado', 45)]);
    expect(summary.unregistered, 45);
    expect(summary.cash, 0);
    expect(summary.collected, 45);
  });
}
