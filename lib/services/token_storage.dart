import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const FlutterSecureStorage _storage = FlutterSecureStorage(
  webOptions: WebOptions(
    dbName: 'wafaaptc_secure_db',
    publicKey: 'wafaaptc_secure',
  ),
);

const FlutterSecureStorage _legacyWebStorage = FlutterSecureStorage();

const String _accessKey = 'accessToken';
const String _refreshKey = 'refreshToken';
const String _refreshExpiresKey = 'refreshTokenExpiresAt';
const String _roleKey = 'role';

class TokenStorage {
  static Future<void> save(String token) =>
      _storage.write(key: _accessKey, value: token);

  static Future<String?> read() => _readWithMigration(_accessKey);

  static Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshKey, value: token);

  static Future<String?> readRefreshToken() => _readWithMigration(_refreshKey);

  static Future<void> clearRefreshToken() async {
    await _storage.delete(key: _refreshKey);
    if (kIsWeb) {
      await _legacyWebStorage.delete(key: _refreshKey);
    }
  }

  static Future<void> saveRefreshExpiresAt(String iso8601) =>
      _storage.write(key: _refreshExpiresKey, value: iso8601);

  static Future<String?> readRefreshExpiresAt() =>
      _readWithMigration(_refreshExpiresKey);

  static Future<void> clearRefreshExpiresAt() async {
    await _storage.delete(key: _refreshExpiresKey);
    if (kIsWeb) {
      await _legacyWebStorage.delete(key: _refreshExpiresKey);
    }
  }

  static Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _accessKey),
      _storage.delete(key: _refreshKey),
      _storage.delete(key: _refreshExpiresKey),
      _storage.delete(key: _roleKey),
      if (kIsWeb) _legacyWebStorage.delete(key: _accessKey),
      if (kIsWeb) _legacyWebStorage.delete(key: _refreshKey),
      if (kIsWeb) _legacyWebStorage.delete(key: _refreshExpiresKey),
      if (kIsWeb) _legacyWebStorage.delete(key: _roleKey),
    ]);
  }

  static Future<void> saveRole(String role) =>
      _storage.write(key: _roleKey, value: role);

  static Future<String?> readRole() => _readWithMigration(_roleKey);
}

Future<String?> _readWithMigration(String key) async {
  final value = await _storage.read(key: key);
  if (value != null || !kIsWeb) {
    return value;
  }

  final legacy = await _legacyWebStorage.read(key: key);
  if (legacy == null) {
    return null;
  }

  await _storage.write(key: key, value: legacy);
  await _legacyWebStorage.delete(key: key);
  return legacy;
}
