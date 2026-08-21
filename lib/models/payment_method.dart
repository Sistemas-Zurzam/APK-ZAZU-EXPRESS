class PaymentAccount {
  const PaymentAccount({
    required this.id,
    this.nombre,
    this.alias,
    this.numero,
    this.banco,
    this.cci,
    this.imagenUrl,
  });

  final int id;
  final String? nombre;
  final String? alias;
  final String? numero;
  final String? banco;
  final String? cci;
  final String? imagenUrl;

  factory PaymentAccount.fromJson(Map<String, dynamic> json) {
    return PaymentAccount(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nombre: json['nombre']?.toString(),
      alias: json['alias']?.toString(),
      numero: json['numero']?.toString(),
      banco: json['banco']?.toString(),
      cci: json['cci']?.toString(),
      imagenUrl: json['imagen_url']?.toString(),
    );
  }
}

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.requiereReferencia,
    required this.cuentas,
  });

  final int id;
  final String codigo;
  final String nombre;
  final bool requiereReferencia;
  final List<PaymentAccount> cuentas;

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    final rawCuentas = json['cuentas'];
    return PaymentMethod(
      id: (json['id'] as num?)?.toInt() ?? 0,
      codigo: json['codigo']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      requiereReferencia: json['requiere_referencia'] == true,
      cuentas:
          rawCuentas is List
              ? rawCuentas
                  .whereType<Map>()
                  .map(
                    (e) => PaymentAccount.fromJson(
                      e.map((k, v) => MapEntry(k.toString(), v)),
                    ),
                  )
                  .toList()
              : const [],
    );
  }
}
