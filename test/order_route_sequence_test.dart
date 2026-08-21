import 'package:flutter_test/flutter_test.dart';
import 'package:zazu_driver/models/order.dart';

void main() {
  test('lee orden_entrega asignado por el ruteo inteligente', () {
    final order = DeliveryOrder.fromJson({'id': 10, 'orden_entrega': 7});

    expect(order.deliverySequence, 7);
  });

  test('lee grupo y posición de mochila enviados por el backend', () {
    final order = DeliveryOrder.fromJson({
      'id': 10,
      'numero_vuelta': 'Grupo 2',
      'orden_mochila': 4,
    });

    expect(order.routeGroup, 'Grupo 2');
    expect(order.backpackSequence, 4);
  });

  test('reconoce estados finales usados por el backend', () {
    expect(DeliveryOrder.fromJson({'estado': 'Entregado'}).isDelivered, isTrue);
    expect(DeliveryOrder.fromJson({'estado': 'Finalizado'}).isDelivered, isTrue);
    expect(DeliveryOrder.fromJson({'estado': 'Completado'}).isDelivered, isTrue);
    expect(DeliveryOrder.fromJson({'estado': 'En ruta'}).isDelivered, isFalse);
  });
}
