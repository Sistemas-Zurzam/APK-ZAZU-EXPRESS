import 'package:flutter_test/flutter_test.dart';
import 'package:zazu_driver/models/order.dart';

DeliveryOrder _order(String status) => DeliveryOrder(
  id: 1,
  externalRef: 'Overshark/066412',
  customerName: 'Cliente',
  address: 'Lima',
  amountDue: 99,
  status: status,
);

void main() {
  test('cada estado cae en una sola sección', () {
    final asignado = _order('asignado');
    final recepcionado = _order('Recepcionado');
    final enRuta = _order('en_ruta');
    final entregado = _order('entregado');

    expect(asignado.isReceived, isFalse);
    expect(asignado.isRecepcionado, isFalse);

    expect(recepcionado.isReceived, isTrue);
    expect(recepcionado.isRecepcionado, isTrue);
    expect(recepcionado.isInRoute, isFalse);

    expect(enRuta.isRecepcionado, isFalse);
    expect(enRuta.isInRoute, isTrue);

    expect(entregado.isRecepcionado, isFalse);
    expect(entregado.isDelivered, isTrue);
  });
}
