import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _k = FlutterSecureStorage();

  static Future<void> save(String token) =>
      _k.write(key: 'accessToken', value: token);
  static Future<String?> read() => _k.read(key: 'accessToken');
  static Future<void> clear() async {
    await _k.delete(key: 'accessToken');
    await _k.delete(key: 'role');
  }

  static Future<void> saveRole(String role) =>
      _k.write(key: 'role', value: role);
  static Future<String?> readRole() => _k.read(key: 'role');
}
