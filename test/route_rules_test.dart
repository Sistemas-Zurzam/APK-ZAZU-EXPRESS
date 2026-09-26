import 'package:flutter_test/flutter_test.dart';
import 'package:zazu_driver/core/route_rules.dart';
import 'package:zazu_driver/models/order.dart';

DeliveryOrder _order(int id, String status) => DeliveryOrder(
  id: id,
  externalRef: 'Overshark/$id',
  customerName: 'Cliente $id',
  address: 'Lima',
  amountDue: 99,
  status: status,
);

void main() {
  test('solo un pedido en ruta a la vez', () {
    final enRuta = _order(1, 'en_ruta');
    final siguiente = _order(2, 'recepcionado');

    expect(
      startRouteBlockReason(siguiente, [enRuta, siguiente]),
      contains('Overshark/1'),
    );
    expect(startRouteBlockReason(siguiente, [siguiente]), isNull);
  });

  test('no se inicia ruta sin recepcionar ni de uno entregado', () {
    final asignado = _order(1, 'asignado');
    final entregado = _order(2, 'entregado');

    expect(startRouteBlockReason(asignado, [asignado]), contains('recepciona'));
    expect(
      startRouteBlockReason(entregado, [entregado]),
      contains('entregado'),
    );
  });

  test('un entregado no bloquea iniciar el siguiente', () {
    final entregado = _order(1, 'entregado');
    final siguiente = _order(2, 'recepcionado');

    expect(startRouteBlockReason(siguiente, [entregado, siguiente]), isNull);
  });
}
