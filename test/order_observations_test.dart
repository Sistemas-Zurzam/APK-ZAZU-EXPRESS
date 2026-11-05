import 'package:flutter_test/flutter_test.dart';
import 'package:zazu_driver/models/order.dart';

DeliveryOrder _order({String? especificaciones, String? observaciones}) =>
    DeliveryOrder.fromJson({
      'id': 1,
      'external_ref': 'Overshark/076182',
      'cliente': 'Maribel',
      'direccion': 'Av. Lima 123',
      'estado': 'en_ruta',
      'especificaciones': especificaciones,
      'observaciones': observaciones,
    });

void main() {
  test('muestra las especificaciones en observaciones', () {
    expect(
      _order(especificaciones: 'Entregar en portería').observations,
      'Entregar en portería',
    );
  });

  test('especificaciones primero y luego las observaciones', () {
    expect(
      _order(
        especificaciones: 'Entregar en portería',
        observaciones: 'Llamar antes de llegar',
      ).observations,
      'Entregar en portería\nLlamar antes de llegar',
    );
  });

  test('no repite lo que el servidor ya juntó en observaciones', () {
    expect(
      _order(
        especificaciones: 'Entregar en portería',
        observaciones: 'Entregar en portería\nLlamar antes de llegar',
      ).observations,
      'Entregar en portería\nLlamar antes de llegar',
    );
  });

  test('sin ninguna de las dos queda vacío', () {
    expect(_order(especificaciones: ' ').observations, isNull);
  });
}
