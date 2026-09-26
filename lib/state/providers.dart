import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/app_user.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../services/location_tracking_service.dart';
import '../services/token_storage.dart';

final secureStorageProvider = Provider(
  (ref) => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  ),
);
final tokenStorageProvider = Provider(
  (ref) => TokenStorage(ref.watch(secureStorageProvider)),
);
final apiProvider = Provider(
  (ref) => ApiService(ref.watch(tokenStorageProvider)),
);

class AuthState {
  const AuthState({this.user, this.loading = false, this.error});
  final AppUser? user;
  final bool loading;
  final String? error;
  bool get authenticated => user != null;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._api, this._storage) : super(const AuthState());
  final ApiService _api;
  final TokenStorage _storage;

  Future<void> restore() async {
    final token = await _storage.readToken();
    final raw = await _storage.readUserJson();
    if (token == null || raw == null) return;
    try {
      state = AuthState(user: AppUser.fromJson(jsonDecode(raw)));
    } catch (_) {
      await _storage.clear();
    }
  }

  Future<bool> login(String username, String password) async {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty) {
      state = const AuthState(error: 'Ingresa tu usuario o DNI.');
      return false;
    }
    if (password.isEmpty) {
      state = const AuthState(error: 'Ingresa tu contrasena.');
      return false;
    }

    state = const AuthState(loading: true);
    try {
      final result = await _api.login(cleanUsername, password);
      await _storage.saveSession(
        token: result.token,
        userJson: jsonEncode({
          'id': result.user.id,
          'name': result.user.name,
          'username': result.user.username,
          'role_id': result.user.roleId,
          'estado': result.user.estado,
          'activo': result.user.activo,
        }),
      );
      state = AuthState(user: result.user);
      return true;
    } catch (e) {
      state = AuthState(error: _message(e));
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.clear();
    state = const AuthState();
  }

  String _message(Object e) {
    if (e is DioException) {
      final statusCode = e.response?.statusCode;
      final serverMessage = _serverMessage(e.response?.data);
      if (serverMessage != null) return serverMessage;
      if (statusCode == 401 || statusCode == 422) {
        return 'Usuario/DNI o contrasena incorrectos.';
      }
      if (statusCode != null) {
        return 'No se pudo iniciar sesion. Error $statusCode.';
      }
      return 'No se pudo conectar con el servidor.';
    }

    final text = e.toString();
    return text.replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '');
  }

  String? _serverMessage(dynamic data) {
    if (data is Map) {
      final message = data['message'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString();
      }

      final errors = data['errors'];
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) return value.first.toString();
          if (value != null && value.toString().trim().isNotEmpty) {
            return value.toString();
          }
        }
      }
    }
    return null;
  }
}

final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.watch(apiProvider),
    ref.watch(tokenStorageProvider),
  );
});

final deliveredOrdersProvider = StateProvider<List<DeliveryOrder>>(
  (ref) => const [],
);

final ordersProvider = FutureProvider.autoDispose<List<DeliveryOrder>>((
  ref,
) async {
  final serverOrders = await ref.watch(apiProvider).getMyOrders();
  final localDelivered = ref.watch(deliveredOrdersProvider);
  final serverIds = serverOrders.map((order) => order.id).toSet();
  return [
    ...serverOrders,
    ...localDelivered.where((order) => !serverIds.contains(order.id)),
  ];
});

final homeTabIndexProvider = StateProvider<int>((ref) => 0);

final focusedOrderIdProvider = StateProvider<int?>((ref) => null);

/// Pedido que el mapa pidió entregar: la pantalla de Pedidos lo abre y arranca
/// el cobro (ahí vive el flujo de fotos y medio de pago).
final deliverOrderRequestProvider = StateProvider<int?>((ref) => null);

final _locationTrackingServiceProvider = Provider<LocationTrackingService>((
  ref,
) {
  final service = LocationTrackingService(ref.watch(apiProvider));
  ref.onDispose(service.stop);
  return service;
});

/// Arranca/detiene el reporte periódico de ubicación según si el motorizado
/// tiene algún pedido en ruta ahora mismo. Debe mantenerse "vivo" en algún
/// widget siempre presente (ver HomeShell) para que el `ref.watch` inicial
/// lo active.
final locationTrackingProvider = Provider<void>((ref) {
  final orders = ref.watch(ordersProvider);
  final hasActiveRoute = orders.maybeWhen(
    data: (list) => list.any((order) => order.status.contains('ruta')),
    orElse: () => false,
  );

  final service = ref.watch(_locationTrackingServiceProvider);
  if (hasActiveRoute) {
    service.start();
  } else {
    service.stop();
  }
});
