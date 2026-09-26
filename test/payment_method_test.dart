import 'package:flutter_test/flutter_test.dart';
import 'package:zazu_driver/models/payment_method.dart';
import 'package:zazu_driver/services/api_service.dart';

void main() {
  test('lee los campos usados por los registros de QR de produccion', () {
    final account = PaymentAccount.fromJson({
      'id': 12,
      'nombre': 'QR BBVA ZAZU',
      'alias': 'QR BBVA ZAZU',
      'numero': '0011-0130',
      'tipo_deposito': 'cuenta_bancaria',
      'banco': 'BBVA',
      'imagen_url': '/storage/qrs/bbva.jpg',
      'vistas': ['delivery', 'courier'],
      'activo': true,
    });

    expect(account.nombre, 'QR BBVA ZAZU');
    expect(account.tipoDeposito, 'cuenta_bancaria');
    expect(account.banco, 'BBVA');
    expect(account.vistas, contains('courier'));
    expect(account.activo, isTrue);
  });

  test('acepta cuentas paginadas dentro de un medio de pago', () {
    final method = PaymentMethod.fromJson({
      'id': 5,
      'codigo': 'YAPE',
      'nombre': 'Yape',
      'requiere_referencia': false,
      'cuentas': {
        'data': [
          {'id': 1, 'nombre': 'Principal'},
          {'id': 2, 'nombre': 'Secundaria'},
        ],
      },
    });

    expect(method.cuentas, hasLength(2));
  });

  test('reconoce cuentas desactivadas en cualquier formato', () {
    bool activo(Map<String, dynamic> extra) =>
        PaymentAccount.fromJson({'id': 1, ...extra}).activo;

    expect(activo({}), isTrue);
    expect(activo({'activo': true}), isTrue);
    expect(activo({'activo': 1}), isTrue);
    expect(activo({'estado': 'Activo'}), isTrue);
    expect(activo({'activo': false}), isFalse);
    expect(activo({'activo': 0}), isFalse);
    expect(activo({'activo': '0'}), isFalse);
    expect(activo({'estado': 'inactivo'}), isFalse);
  });

  group('opción QR', () {
    PaymentMethod method(String codigo, [List<PaymentAccount> c = const []]) =>
        PaymentMethod(
          id: codigo.hashCode,
          codigo: codigo,
          nombre: codigo,
          requiereReferencia: false,
          cuentas: c,
        );

    const bbva = PaymentAccount(
      id: 2,
      nombre: 'QR BBVA ZAZU',
      banco: 'BBVA',
      tipoDeposito: 'cuenta_bancaria',
    );
    const yapeInactivo = PaymentAccount(
      id: 3,
      nombre: 'YAPE ZAZU',
      proveedor: 'Yape',
      activo: false,
    );

    test('reemplaza Yape y Plin por QR con solo los activos', () {
      final options = ApiService.buildPaymentOptions(
        [
          method('EFECTIVO'),
          method('YAPE'),
          method('PLIN'),
          method('TRANSFERENCIA'),
        ],
        [bbva, yapeInactivo],
      );
      final codes = options.map((o) => o.codigo).toList();

      expect(codes, ['EFECTIVO', 'TRANSFERENCIA', 'QR']);
      expect(options.last.cuentas.map((a) => a.id), [2]);
      expect(options[1].cuentas.map((a) => a.id), [2]);
    });

    test('sin QR activos no se muestra la opción', () {
      final options = ApiService.buildPaymentOptions(
        [method('EFECTIVO'), method('YAPE')],
        [yapeInactivo],
      );
      expect(options.map((o) => o.codigo), ['EFECTIVO']);
    });

    test('registra el cobro con el medio real del QR', () {
      expect(bbva.paymentCode, 'TRANSFERENCIA');
      expect(yapeInactivo.paymentCode, 'YAPE');
      expect(const PaymentAccount(id: 4, proveedor: 'Otro').paymentCode, 'QR');
      expect(
        const PaymentAccount(id: 5, medioPagoCodigo: 'plin').paymentCode,
        'PLIN',
      );
    });
  });
}
