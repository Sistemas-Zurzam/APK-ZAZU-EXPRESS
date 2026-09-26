class PaymentAccount {
  const PaymentAccount({
    required this.id,
    this.nombre,
    this.alias,
    this.numero,
    this.banco,
    this.cci,
    this.imagenUrl,
    this.proveedor,
    this.tipoDeposito,
    this.medioPagoCodigo,
    this.vistas = const [],
    this.activo = true,
  });

  final int id;
  final String? nombre;
  final String? alias;
  final String? numero;
  final String? banco;
  final String? cci;
  final String? imagenUrl;
  final String? proveedor;
  final String? tipoDeposito;

  /// Código del medio de pago vinculado al QR en el panel (p. ej. YAPE).
  final String? medioPagoCodigo;
  final List<String> vistas;
  final bool activo;

  factory PaymentAccount.fromJson(Map<String, dynamic> json) {
    return PaymentAccount(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nombre: _firstString(json, ['nombre', 'name']),
      alias: _firstString(json, ['alias', 'codigo']),
      numero: _firstString(json, ['numero', 'numero_cuenta', 'celular']),
      banco: _firstString(json, ['banco', 'bank']),
      cci: _firstString(json, ['cci']),
      imagenUrl: _firstString(json, ['imagen_url', 'image_url', 'qr_url']),
      proveedor: _firstString(json, ['proveedor', 'provider']),
      tipoDeposito: _firstString(json, ['tipo_deposito', 'deposit_type']),
      medioPagoCodigo: _firstString(json, ['medio_pago_codigo']),
      vistas: _stringList(json['vistas'] ?? json['views']),
      activo: _isActive(json),
    );
  }

  static String? _firstString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  /// El backend puede enviar el estado como bool, 0/1, "0"/"1" o texto
  /// ("activo"/"inactivo"). Si no informa nada, la cuenta se considera activa.
  static bool _isActive(Map<String, dynamic> json) {
    for (final key in ['activo', 'active', 'is_active', 'estado', 'status']) {
      if (!json.containsKey(key) || json[key] == null) continue;
      final value = json[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      final text = value.toString().trim().toLowerCase();
      if (text.isEmpty) continue;
      return const [
        '1',
        'true',
        'activo',
        'activa',
        'active',
        'habilitado',
      ].contains(text);
    }
    return true;
  }

  /// Código con el que se registra un cobro hecho con este QR. El ERP de
  /// cobranzas agrupa por YAPE/PLIN/TRANSFERENCIA, así que la opción "QR" de
  /// la APK no se envía como tal sino como el medio real del QR elegido.
  String get paymentCode {
    final linked = medioPagoCodigo?.trim().toUpperCase();
    if (linked != null && linked.isNotEmpty) return linked;
    final provider = proveedor?.trim().toUpperCase();
    if (provider == 'YAPE' || provider == 'PLIN') return provider!;
    if (tipoDeposito == 'cuenta_bancaria' || (banco?.isNotEmpty ?? false)) {
      return 'TRANSFERENCIA';
    }
    return 'QR';
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList();
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
    final rawCuentas = _accountList(
      json['cuentas'] ?? json['accounts'] ?? json['qrs'],
    );
    return PaymentMethod(
      id: (json['id'] as num?)?.toInt() ?? 0,
      codigo: json['codigo']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      requiereReferencia: json['requiere_referencia'] == true,
      cuentas:
          rawCuentas
              .whereType<Map>()
              .map(
                (e) => PaymentAccount.fromJson(
                  e.map((k, v) => MapEntry(k.toString(), v)),
                ),
              )
              .toList(),
    );
  }

  PaymentMethod copyWith({List<PaymentAccount>? cuentas}) {
    return PaymentMethod(
      id: id,
      codigo: codigo,
      nombre: nombre,
      requiereReferencia: requiereReferencia,
      cuentas: cuentas ?? this.cuentas,
    );
  }

  static List<dynamic> _accountList(dynamic value) {
    if (value is List) return value;
    if (value is Map) {
      final data = value['data'];
      if (data is List) return data;
      return value.values.whereType<Map>().toList();
    }
    return const [];
  }
}
