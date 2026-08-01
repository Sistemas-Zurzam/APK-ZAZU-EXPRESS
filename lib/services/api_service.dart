import 'package:dio/dio.dart';
import '../core/app_config.dart';
import '../models/app_user.dart';
import '../models/order.dart';
import 'token_storage.dart';

class LoginResult {
  const LoginResult({required this.token, required this.user});
  final String token;
  final AppUser user;
}

class ApiService {
  ApiService(this._storage)
      : _dio = Dio(BaseOptions(
          baseUrl: AppConfig.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          headers: {'Accept': 'application/json'},
        )) {
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
      final token = await _storage.readToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    }));
  }

  final Dio _dio;
  final TokenStorage _storage;

  Future<LoginResult> login(String username, String password) async {
    final response = await _dio.post('/login', data: {
      'login': username.trim(),
      'username': username.trim(),
      'dni': username.trim(),
      'password': password,
    });
    final root = _asMap(response.data);
    final data = _asMap(root['data']);
    final token = _findString(root, ['token', 'access_token']) ??
        _findString(data, ['token', 'access_token']);
    final userJson = _asMap(root['user']).isNotEmpty
        ? _asMap(root['user'])
        : (_asMap(data['user']).isNotEmpty ? _asMap(data['user']) : data);
    if (token == null || token.isEmpty || userJson.isEmpty) {
      throw StateError('El login no devolvió token o usuario.');
    }
    final user = AppUser.fromJson(userJson);
    if (_isExplicitNonDriver(userJson, user)) {
      throw StateError('Este usuario no es motorizado.');
    }
    return LoginResult(token: token, user: user);
  }

  Future<List<DeliveryOrder>> getMyOrders() async {
    final response = await _getFirstAvailable(['/apk/pedidos', '/motorizado/mis-pedidos']);
    final list = _extractList(response.data, ['pedidos', 'data', 'orders']);
    return list.map((e) => DeliveryOrder.fromJson(_asMap(e))).toList();
  }

  Future<List<DeliveryOrder>> getSmartRoute(double lat, double lng) async {
    final response = await _getFirstAvailable(
      ['/apk/ruta-inteligente', '/motorizado/ruta-inteligente', '/ruta-inteligente'],
      queryParameters: {'lat': lat, 'lng': lng},
    );
    final list = _extractList(response.data, [
      'pedidos', 'ruta', 'ruta_ordenada', 'ordenados', 'orders', 'data', 'stops', 'paradas'
    ]);
    return list.map((e) => DeliveryOrder.fromJson(_asMap(e))).toList();
  }

  Future<void> confirmReception(int orderId, {int? operationId}) async {
    await _postFirstAvailable(['/apk/confirmar-recepcion', '/motorizado/recepcionar'], data: {
      'pedido_id': orderId,
      if (operationId != null) 'operacion_id': operationId,
    });
  }

  Future<void> startRoute(int orderId, {int? operationId}) async {
    await _postFirstAvailable(['/apk/pedidos/asignar', '/motorizado/iniciar-ruta'], data: {
      'pedido_id': orderId,
      if (operationId != null) 'operacion_id': operationId,
    });
  }

  Future<void> confirmDelivery(int orderId, {int? operationId, required String evidencePath}) async {
    final fileName = evidencePath.split(RegExp(r'[\\/]')).last;
    await _postFirstAvailable(
      ['/apk/confirmar-entrega', '/motorizado/entregar'],
      dataBuilder: () => FormData.fromMap({
        'pedido_id': orderId,
        if (operationId != null) 'operacion_id': operationId,
        'foto_evidencia': MultipartFile.fromFileSync(evidencePath, filename: fileName),
      }),
    );
  }

  Future<void> rescheduleOrder(int orderId, String reason, String newDate) async {
    await _dio.post('/motorizado/reprogramar', data: {
      'pedido_id': orderId,
      'motivo': reason,
      'nueva_fecha': newDate,
    });
  }

  Future<void> registerDriver(Map<String, dynamic> data) async {
    try {
      await _dio.post('/apk/register', data: data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 405) {
        await _dio.post('/registro-motorizado', data: data);
        return;
      }
      rethrow;
    }
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
    return <String, dynamic>{};
  }

  static String? _findString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().isNotEmpty) return value.toString();
    }
    return null;
  }

  static List<dynamic> _extractList(dynamic raw, List<String> keys) {
    if (raw is List) return raw;
    final map = _asMap(raw);
    for (final key in keys) {
      final value = map[key];
      if (value is List) return value;
      if (value is Map) {
        final nested = _extractList(value, keys);
        if (nested.isNotEmpty) return nested;
      }
    }
    return const [];
  }

  Future<Response<dynamic>> _getFirstAvailable(
    List<String> paths, {
    Map<String, dynamic>? queryParameters,
  }) async {
    DioException? lastNotFound;
    for (final path in paths) {
      try {
        return await _dio.get(path, queryParameters: queryParameters);
      } on DioException catch (error) {
        if (error.response?.statusCode == 404 && path != paths.last) {
          lastNotFound = error;
          continue;
        }
        rethrow;
      }
    }
    throw lastNotFound ?? StateError('No se encontró un endpoint disponible.');
  }

  Future<Response<dynamic>> _postFirstAvailable(
    List<String> paths, {
    dynamic data,
    dynamic Function()? dataBuilder,
  }) async {
    DioException? lastNotFound;
    for (final path in paths) {
      try {
        return await _dio.post(path, data: dataBuilder?.call() ?? data);
      } on DioException catch (error) {
        if (error.response?.statusCode == 404 && path != paths.last) {
          lastNotFound = error;
          continue;
        }
        rethrow;
      }
    }
    throw lastNotFound ?? StateError('No se encontró un endpoint disponible.');
  }

  static bool _isExplicitNonDriver(Map<String, dynamic> json, AppUser user) {
    final rawRole = '${json['role'] ?? json['rol'] ?? json['role_name'] ?? ''}'.toLowerCase();
    if (rawRole.contains('motorizado') || rawRole.contains('driver')) return false;
    if (rawRole.isNotEmpty) return true;

    final hasRoleId = json.containsKey('role_id') || json.containsKey('rol_id');
    return hasRoleId && user.roleId != 6;
  }
}
