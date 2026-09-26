import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zazu_driver/services/api_service.dart';

DioException _rejected(String message) {
  final options = RequestOptions(path: '/motorizado/recepcionar');
  return DioException(
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: 422,
      data: {'message': message},
    ),
  );
}

void main() {
  test('reconoce el rechazo del backend por pedido ya recepcionado', () {
    expect(
      ApiService.isAlreadyReceivedError(
        _rejected(
          'El pedido debe estar en estado Asignado '
          '(estado actual: Recepcionado).',
        ),
      ),
      isTrue,
    );
    expect(
      ApiService.isAlreadyReceivedError(
        _rejected(
          'El pedido debe estar en estado Asignado (estado actual: En Ruta).',
        ),
      ),
      isTrue,
    );
  });

  test('no confunde otros errores con un pedido ya recepcionado', () {
    expect(
      ApiService.isAlreadyReceivedError(
        _rejected('Este pedido no está asignado a ti.'),
      ),
      isFalse,
    );
    expect(ApiService.isAlreadyReceivedError(Exception('x')), isFalse);
  });
}
