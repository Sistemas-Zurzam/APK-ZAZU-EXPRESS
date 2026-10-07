/// Cobro con el QR efímero de Ligo Pay: monto exacto y un solo pago. Lo
/// genera el backend (el mismo QR que ve el cliente en el tracking); la app
/// solo dibuja la cadena EMV y consulta el estado hasta que el webhook de
/// Ligo confirma el pago.
class LigoQr {
  const LigoQr({
    required this.status,
    required this.amount,
    this.qrValue,
    this.idQr,
    this.expiresAt,
    this.paidAt,
    this.instructionId,
    this.message,
  });

  /// vigente, pagado, vencido, disponible (hay saldo pero no un QR vigente),
  /// sin_saldo o monto_no_permitido (Ligo no cobra menos de S/ 1.00).
  final String status;
  final double amount;

  /// Cadena EMV del QR interoperable. Solo viene mientras está vigente.
  final String? qrValue;
  final String? idQr;
  final DateTime? expiresAt;
  final DateTime? paidAt;

  /// Número de operación de Ligo; queda como nro_operacion de la entrega.
  final String? instructionId;
  final String? message;

  bool get isPaid => status == 'pagado';

  bool get isActive =>
      status == 'vigente' && qrValue != null && qrValue!.isNotEmpty;

  /// Se puede pedir un QR nuevo: el anterior venció o el saldo cambió.
  bool get canRegenerate => status == 'vencido' || status == 'disponible';

  factory LigoQr.fromJson(Map<String, dynamic> json) {
    return LigoQr(
      status: json['status']?.toString() ?? 'disponible',
      amount: _money(json['amount']),
      qrValue: _text(json['qr_value']),
      idQr: _text(json['id_qr']),
      expiresAt: _date(json['expires_at']),
      paidAt: _date(json['paid_at']),
      instructionId: _text(json['instruction_id']),
      message: _text(json['message']),
    );
  }

  static String? _text(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static double _money(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _date(dynamic value) {
    final text = _text(value);
    return text == null ? null : DateTime.tryParse(text)?.toLocal();
  }
}
