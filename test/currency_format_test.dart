import 'package:flutter_test/flutter_test.dart';
import 'package:zazu_driver/core/currency_format.dart';

void main() {
  test('formatea soles con el patrón peruano requerido', () {
    expect(peruvianCurrency.format(2914), 'S/ 2.914,00');
  });
}
