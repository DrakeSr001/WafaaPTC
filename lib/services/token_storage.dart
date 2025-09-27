import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _k = FlutterSecureStorage();

  static Future<void> save(String token) =>
      _k.write(key: 'accessToken', value: token);
  static Future<String?> read() => _k.read(key: 'accessToken');

  static Future<void> saveRefreshToken(String token) =>
      _k.write(key: 'refreshToken', value: token);
  static Future<String?> readRefreshToken() => _k.read(key: 'refreshToken');
  static Future<void> clearRefreshToken() =>
      _k.delete(key: 'refreshToken');

  static Future<void> saveRefreshExpiresAt(String iso8601) =>
      _k.write(key: 'refreshTokenExpiresAt', value: iso8601);
  static Future<String?> readRefreshExpiresAt() =>
      _k.read(key: 'refreshTokenExpiresAt');
  static Future<void> clearRefreshExpiresAt() =>
      _k.delete(key: 'refreshTokenExpiresAt');

  static Future<void> clear() async {
    await _k.delete(key: 'accessToken');
    await _k.delete(key: 'refreshToken');
    await _k.delete(key: 'refreshTokenExpiresAt');
    await _k.delete(key: 'role');
  }

  static Future<void> saveRole(String role) =>
      _k.write(key: 'role', value: role);
  static Future<String?> readRole() => _k.read(key: 'role');
}
