import 'package:flutter_test/flutter_test.dart';
import 'package:zazu_driver/models/ligo_qr.dart';
import 'package:zazu_driver/models/order.dart';

void main() {
  group('LigoQr', () {
    test('lee el QR vigente que devuelve el backend', () {
      final qr = LigoQr.fromJson({
        'status': 'vigente',
        'amount': 99,
        'currency': 'PEN',
        'qr_value': '000201010212TEST',
        'id_qr': '26080309211940789496',
        'expires_at': '2026-10-08T14:32:00-05:00',
        'paid_at': null,
        'instruction_id': null,
      });

      expect(qr.isActive, isTrue);
      expect(qr.isPaid, isFalse);
      expect(qr.amount, 99);
      expect(qr.expiresAt, isNotNull);
      expect(qr.instructionId, isNull);
    });

    test('pagado no muestra QR y trae la operación', () {
      final qr = LigoQr.fromJson({
        'status': 'pagado',
        'amount': '14.00',
        'qr_value': null,
        'instruction_id': '2026080312320209214115017565',
      });

      expect(qr.isPaid, isTrue);
      expect(qr.isActive, isFalse);
      expect(qr.amount, 14);
      expect(qr.instructionId, '2026080312320209214115017565');
    });

    test('vencido o con saldo cambiado se puede volver a generar', () {
      expect(LigoQr.fromJson({'status': 'vencido'}).canRegenerate, isTrue);
      expect(LigoQr.fromJson({'status': 'disponible'}).canRegenerate, isTrue);
      expect(LigoQr.fromJson({'status': 'sin_saldo'}).canRegenerate, isFalse);
    });

    test('un vigente sin cadena EMV no se trata como QR mostrable', () {
      expect(LigoQr.fromJson({'status': 'vigente'}).isActive, isFalse);
    });
  });

  group('saldo del pedido', () {
    Map<String, dynamic> pedido(Map<String, dynamic> extra) => {
      'id': 7,
      'external_ref': 'Overshark/TEST-7',
      'cliente': 'Cliente',
      'direccion': 'Lima',
      'estado': 'en_ruta',
      'monto_total': 149,
      ...extra,
    };

    test('un saldo en cero no cae en el monto total', () {
      final order = DeliveryOrder.fromJson(
        pedido({'cuenta_cliente': 0, 'monto_cobrar': 0}),
      );
      expect(order.amountDue, 0);
    });

    test('usa cuenta_cliente cuando hay saldo', () {
      final order = DeliveryOrder.fromJson(
        pedido({'cuenta_cliente': 59.5, 'monto_cobrar': 59.5}),
      );
      expect(order.amountDue, 59.5);
    });

    test('sin cuenta_cliente sigue buscando en las otras claves', () {
      final order = DeliveryOrder.fromJson(pedido({'monto_pendiente': 30}));
      expect(order.amountDue, 30);
    });
  });
}
