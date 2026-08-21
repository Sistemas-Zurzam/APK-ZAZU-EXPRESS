class DeliveryOrder {
  const DeliveryOrder({
    required this.id,
    required this.externalRef,
    required this.customerName,
    required this.address,
    required this.amountDue,
    required this.status,
    this.phone,
    this.dni,
    this.latitude,
    this.longitude,
    this.operationId,
    this.deliverySequence,
    this.routeGroup,
    this.backpackSequence,
    this.observations,
    this.rawJson = const {},
  });

  final int id;
  final String externalRef;
  final String customerName;
  final String address;
  final double amountDue;
  final String status;
  final String? phone;
  final String? dni;
  final double? latitude;
  final double? longitude;
  final int? operationId;
  final int? deliverySequence;
  final String? routeGroup;
  final int? backpackSequence;
  final String? observations;
  final Map<String, dynamic> rawJson;

  bool get hasCoordinates => latitude != null && longitude != null;
  bool get isDelivered {
    final value = status.toLowerCase();
    return value.contains('entreg') ||
        value.contains('finaliz') ||
        value.contains('complet');
  }

  bool get isInRoute {
    final value = status.toLowerCase();
    return value.contains('ruta') || value.contains('recibido');
  }

  DeliveryOrder withStatus(String newStatus) => DeliveryOrder(
    id: id,
    externalRef: externalRef,
    customerName: customerName,
    address: address,
    amountDue: amountDue,
    status: newStatus,
    phone: phone,
    dni: dni,
    latitude: latitude,
    longitude: longitude,
    operationId: operationId,
    deliverySequence: deliverySequence,
    routeGroup: routeGroup,
    backpackSequence: backpackSequence,
    observations: observations,
    rawJson: rawJson,
  );

  bool get missingImportantData =>
      customerName == 'Cliente' || dni == null || amountDue <= 0;

  String get apiDiagnostics {
    final entries = <String>[];
    _collectDiagnostics(rawJson, entries);
    _collectAllDiagnostics(rawJson, entries);
    if (entries.isEmpty) {
      return 'No llegaron campos de cliente, DNI o monto en este pedido.';
    }
    return _uniqueEntries(entries).take(26).join('\n');
  }

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    final coordinates = _parseCoordinates(
      _findValue(json, [
        'destinatario_coordenadas',
        'coordenadas',
        'destino_coordenadas',
      ]),
    );
    return DeliveryOrder(
      id: _parseInt(_findValue(json, ['id', 'pedido_id'])) ?? 0,
      externalRef: _stringOrDefault(
        _findValue(json, [
          'external_ref',
          'external_red',
          'numero',
          'codigo',
          'referencia',
        ]),
        'Pedido',
      ),
      customerName: _stringOrDefault(
        _findValue(json, [
          'destinatario',
          'destinatario_nombre',
          'destinatario_nombres',
          'nombre_destinatario',
          'nombres_destinatario',
          'cliente_nombre',
          'nombre_cliente',
          'cliente',
          'razon_social',
          'nombre_completo',
          'customer_name',
          'full_name',
          'name',
          'nombre',
        ]),
        'Cliente',
      ),
      address: _stringOrDefault(
        _findValue(json, [
          'destinatario_direccion',
          'direccion',
          'direccion_cliente',
          'address',
        ]),
        'Sin dirección',
      ),
      amountDue: _findMoney(json, [
        'monto_pendiente',
        'monto_cobrar',
        'monto_por_cobrar',
        'monto_a_cobrar',
        'monto_total',
        'importe_pendiente',
        'saldo_pendiente',
        'saldo_a_cobrar',
        'cuenta_cliente',
        'saldo',
        'total_pendiente',
        'total_cobrar',
        'total',
      ]),
      status:
          _stringOrDefault(
            _findValue(json, ['estado_operacion', 'estado_nombre', 'estado']),
            'asignado',
          ).toLowerCase(),
      phone: _stringOrNull(
        _findValue(json, [
          'destinatario_celular',
          'telefono',
          'celular',
          'phone',
        ]),
      ),
      dni: _stringOrNull(
        _findValue(json, [
          'destinatario_dni',
          'destinatario_documento',
          'destinatario_numero_documento',
          'dni_destinatario',
          'dni_cliente',
          'documento_destinatario',
          'documento_cliente',
          'documento_identidad',
          'numero_documento',
          'nro_documento',
          'doc_identidad',
          'identificacion',
          'dni',
          'documento',
        ]),
      ),
      latitude:
          coordinates.$1 ?? _parseDouble(_findValue(json, ['lat', 'latitude'])),
      longitude:
          coordinates.$2 ??
          _parseDouble(_findValue(json, ['lng', 'longitude'])),
      operationId: _parseInt(_findValue(json, ['operacion_id'])),
      deliverySequence: _parseInt(
        _findValue(json, ['orden_entrega', 'orden', 'secuencia']),
      ),
      routeGroup: _stringOrNull(
        _findValue(json, [
          'grupo',
          'grupo_ruta',
          'grupo_reparto',
          'numero_vuelta',
          'vuelta',
        ]),
      ),
      backpackSequence: _parseInt(
        _findValue(json, ['orden_mochila', 'orden_carga', 'posicion_mochila']),
      ),
      observations: _stringOrNull(
        _findValue(json, ['observaciones', 'observacion', 'nota']),
      ),
      rawJson: json,
    );
  }

  static void _collectDiagnostics(
    dynamic value,
    List<String> entries, [
    String path = '',
  ]) {
    if (entries.length >= 20) return;
    if (value is Map<String, dynamic>) {
      for (final entry in value.entries) {
        final key = entry.key;
        final nextPath = path.isEmpty ? key : '$path.$key';
        final normalized = _normalizeKey(key);
        final relevant =
            normalized.contains('nombre') ||
            normalized.contains('cliente') ||
            normalized.contains('dni') ||
            normalized.contains('documento') ||
            normalized.contains('monto') ||
            normalized.contains('saldo') ||
            normalized.contains('total') ||
            normalized.contains('cuenta');
        if (relevant && entry.value is! Map && entry.value is! List) {
          entries.add('$nextPath: ${entry.value}');
        }
        _collectDiagnostics(entry.value, entries, nextPath);
      }
      return;
    }
    if (value is Map) {
      _collectDiagnostics(
        value.map((k, v) => MapEntry(k.toString(), v)),
        entries,
        path,
      );
      return;
    }
    if (value is List) {
      for (var i = 0; i < value.length && i < 3; i++) {
        _collectDiagnostics(value[i], entries, '$path[$i]');
      }
    }
  }

  static void _collectAllDiagnostics(
    dynamic value,
    List<String> entries, [
    String path = '',
  ]) {
    if (entries.length >= 30) return;
    if (value is Map<String, dynamic>) {
      for (final entry in value.entries) {
        final key = entry.key;
        final nextPath = path.isEmpty ? key : '$path.$key';
        if (entry.value is! Map && entry.value is! List) {
          entries.add('$nextPath: ${entry.value}');
        }
        _collectAllDiagnostics(entry.value, entries, nextPath);
      }
      return;
    }
    if (value is Map) {
      _collectAllDiagnostics(
        value.map((k, v) => MapEntry(k.toString(), v)),
        entries,
        path,
      );
      return;
    }
    if (value is List) {
      for (var i = 0; i < value.length && i < 3; i++) {
        _collectAllDiagnostics(value[i], entries, '$path[$i]');
      }
    }
  }

  static Iterable<String> _uniqueEntries(List<String> entries) sync* {
    final seen = <String>{};
    for (final entry in entries) {
      if (seen.add(entry)) yield entry;
    }
  }

  static dynamic _findValue(Map<String, dynamic> json, List<String> keys) {
    final normalizedKeys = keys.map(_normalizeKey).toSet();
    for (final key in keys) {
      if (json.containsKey(key) && json[key] != null) return json[key];
    }
    for (final entry in json.entries) {
      if (normalizedKeys.contains(_normalizeKey(entry.key)) &&
          entry.value != null) {
        return entry.value;
      }
    }

    for (final value in json.values) {
      if (value is Map<String, dynamic>) {
        final found = _findValue(value, keys);
        if (found != null) return found;
      }
      if (value is Map) {
        final found = _findValue(
          value.map((k, v) => MapEntry(k.toString(), v)),
          keys,
        );
        if (found != null) return found;
      }
      if (value is List) {
        for (final item in value) {
          if (item is Map<String, dynamic>) {
            final found = _findValue(item, keys);
            if (found != null) return found;
          }
          if (item is Map) {
            final found = _findValue(
              item.map((k, v) => MapEntry(k.toString(), v)),
              keys,
            );
            if (found != null) return found;
          }
        }
      }
    }
    return null;
  }

  static String _normalizeKey(String key) {
    return key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static double _findMoney(Map<String, dynamic> json, List<String> keys) {
    double fallback = 0;
    for (final key in keys) {
      final value = _findValue(json, [key]);
      if (value == null) continue;
      final amount = _parseMoney(value);
      if (amount > 0) return amount;
      fallback = amount;
    }
    return fallback;
  }

  static String _stringOrDefault(dynamic value, String fallback) {
    final text = _stringOrNull(value);
    return text == null ? fallback : text;
  }

  static String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static double _parseMoney(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is Map) {
      for (final key in [
        'monto',
        'monto_a_cobrar',
        'saldo',
        'total',
        'importe',
        'amount',
        'valor',
      ]) {
        if (value.containsKey(key)) return _parseMoney(value[key]);
      }
      return 0;
    }

    var clean = value.toString().replaceAll(RegExp(r'[^0-9,.\-]'), '');
    final lastComma = clean.lastIndexOf(',');
    final lastDot = clean.lastIndexOf('.');
    if (lastComma >= 0 && lastDot >= 0) {
      final decimalSeparator = lastComma > lastDot ? ',' : '.';
      final thousandSeparator = decimalSeparator == ',' ? '.' : ',';
      clean = clean
          .replaceAll(thousandSeparator, '')
          .replaceAll(decimalSeparator, '.');
    } else {
      clean = clean.replaceAll(',', '.');
    }
    return double.tryParse(clean) ?? 0;
  }

  static (double?, double?) _parseCoordinates(dynamic value) {
    if (value == null) return (null, null);
    if (value is Map) {
      return (
        double.tryParse('${value['lat'] ?? value['latitude'] ?? ''}'),
        double.tryParse('${value['lng'] ?? value['longitude'] ?? ''}'),
      );
    }
    final raw = value.toString().replaceAll(RegExp(r'[\[\]()]'), '');
    final parts = raw.split(',').map((e) => e.trim()).toList();
    if (parts.length < 2) return (null, null);
    return (double.tryParse(parts[0]), double.tryParse(parts[1]));
  }
}
