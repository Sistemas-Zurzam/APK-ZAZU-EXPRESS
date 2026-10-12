import 'package:flutter_test/flutter_test.dart';
import 'package:zazu_driver/core/contact_actions.dart';
import 'package:zazu_driver/models/order.dart';

DeliveryOrder _order(String ref, {String? marca}) => DeliveryOrder.fromJson({
  'id': 1,
  'external_ref': ref,
  'cliente': 'Maribel',
  'direccion': 'Av. Lima 123',
  'estado': 'en_ruta',
  if (marca != null) 'marca': marca,
});

void main() {
  test('lee la marca que manda el servidor', () {
    expect(_order('ATC/000018', marca: 'BRAVOS').brand, 'BRAVOS');
    expect(_order('Overshark/066467').brand, isNull);
  });

  test('un ATC se nombra por su marca, sin mostrar el código', () {
    final order = _order('ATC/000018', marca: 'BOX PRIME');
    expect(isAtcOrder(order), isTrue);
    expect(orderBrand(order), 'Box Prime');
    expect(orderPhrase(order), 'el cambio de su pedido anterior de Box Prime');
    expect(orderPhrase(order), isNot(contains('ATC')));
  });

  test('un ATC sin marca no inventa "ATC" como empresa', () {
    final order = _order('ATC/000018');
    expect(orderBrand(order), isNull);
    expect(orderPhrase(order), 'el cambio de su pedido anterior');
  });

  test('un pedido normal mantiene marca y nota de venta', () {
    final order = _order('Overshark/066467');
    expect(isAtcOrder(order), isFalse);
    expect(orderBrand(order), 'Overshark');
    expect(orderPhrase(order), 'su pedido de Overshark (Overshark/066467)');
  });
}
