import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  const TokenStorage(this._storage);
  final FlutterSecureStorage _storage;

  static const _tokenKey = 'zazu_auth_token';
  static const _userKey = 'zazu_user_json';

  Future<String?> readToken() => _storage.read(key: _tokenKey);
  Future<String?> readUserJson() => _storage.read(key: _userKey);

  Future<void> saveSession({required String token, required String userJson}) async {
    await Future.wait([
      _storage.write(key: _tokenKey, value: token),
      _storage.write(key: _userKey, value: userJson),
    ]);
  }

  Future<void> clear() => _storage.deleteAll();
}
