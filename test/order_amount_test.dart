import 'package:flutter_test/flutter_test.dart';
import 'package:zazu_driver/models/order.dart';

void main() {
  test('usa exclusivamente cuenta_cliente para el monto a cobrar', () {
    final order = DeliveryOrder.fromJson({
      'monto_total': 149,
      'cuenta_cliente': 0,
    });

    expect(order.amountDue, 0);
  });

  test('lee el valor de cuenta_cliente cuando es mayor que cero', () {
    final order = DeliveryOrder.fromJson({
      'monto_total': 149,
      'cuenta_cliente': 25.50,
    });

    expect(order.amountDue, 25.50);
  });
}
