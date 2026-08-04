import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/app_user.dart';
import '../models/order.dart';
import '../services/api_service.dart';
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

final ordersProvider = FutureProvider.autoDispose<List<DeliveryOrder>>((ref) {
  return ref.watch(apiProvider).getMyOrders();
});
