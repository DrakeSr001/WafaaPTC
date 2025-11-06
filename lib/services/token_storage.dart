import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
const String _fallbackPrefix = 'ts_fallback_';

Future<SharedPreferences?> _fallbackPrefs() async {
  try {
    return await SharedPreferences.getInstance();
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('token_storage: shared preferences unavailable: $error');
      debugPrint('$stackTrace');
    }
    return null;
  }
}

Future<void> _fallbackWrite(String key, String? value) async {
  if (!kIsWeb) return;
  final prefs = await _fallbackPrefs();
  if (prefs == null) return;
  final storageKey = '$_fallbackPrefix$key';
  if (value == null) {
    await prefs.remove(storageKey);
  } else {
    await prefs.setString(storageKey, value);
  }
}

Future<String?> _fallbackRead(String key) async {
  if (!kIsWeb) return null;
  final prefs = await _fallbackPrefs();
  if (prefs == null) return null;
  return prefs.getString('$_fallbackPrefix$key');
}

Future<void> _fallbackDelete(String key) => _fallbackWrite(key, null);

class TokenStorage {
  static Future<void> save(String token) async {
    try {
      await _storage.write(key: _accessKey, value: token);
    } catch (error, stackTrace) {
      if (!kIsWeb) rethrow;
      if (kDebugMode) {
        debugPrint('token_storage: secure save failed: $error');
        debugPrint('$stackTrace');
      }
    }
    await _fallbackWrite(_accessKey, token);
  }

  static Future<String?> read() => _readWithMigration(_accessKey);

  static Future<void> saveRefreshToken(String token) async {
    try {
      await _storage.write(key: _refreshKey, value: token);
    } catch (error, stackTrace) {
      if (!kIsWeb) rethrow;
      if (kDebugMode) {
        debugPrint('token_storage: secure refresh save failed: $error');
        debugPrint('$stackTrace');
      }
    }
    await _fallbackWrite(_refreshKey, token);
  }

  static Future<String?> readRefreshToken() => _readWithMigration(_refreshKey);

  static Future<void> clearRefreshToken() async {
    try {
      await _storage.delete(key: _refreshKey);
    } catch (error, stackTrace) {
      if (!kIsWeb) rethrow;
      if (kDebugMode) {
        debugPrint('token_storage: secure refresh clear failed: $error');
        debugPrint('$stackTrace');
      }
    }
    await _fallbackDelete(_refreshKey);
    if (kIsWeb) {
      await _legacyWebStorage.delete(key: _refreshKey);
    }
  }

  static Future<void> saveRefreshExpiresAt(String iso8601) async {
    try {
      await _storage.write(key: _refreshExpiresKey, value: iso8601);
    } catch (error, stackTrace) {
      if (!kIsWeb) rethrow;
      if (kDebugMode) {
        debugPrint('token_storage: secure expires save failed: $error');
        debugPrint('$stackTrace');
      }
    }
    await _fallbackWrite(_refreshExpiresKey, iso8601);
  }

  static Future<String?> readRefreshExpiresAt() =>
      _readWithMigration(_refreshExpiresKey);

  static Future<void> clearRefreshExpiresAt() async {
    try {
      await _storage.delete(key: _refreshExpiresKey);
    } catch (error, stackTrace) {
      if (!kIsWeb) rethrow;
      if (kDebugMode) {
        debugPrint('token_storage: secure expires clear failed: $error');
        debugPrint('$stackTrace');
      }
    }
    await _fallbackDelete(_refreshExpiresKey);
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
      _fallbackDelete(_accessKey),
      _fallbackDelete(_refreshKey),
      _fallbackDelete(_refreshExpiresKey),
      _fallbackDelete(_roleKey),
      if (kIsWeb) _legacyWebStorage.delete(key: _accessKey),
      if (kIsWeb) _legacyWebStorage.delete(key: _refreshKey),
      if (kIsWeb) _legacyWebStorage.delete(key: _refreshExpiresKey),
      if (kIsWeb) _legacyWebStorage.delete(key: _roleKey),
    ]);
  }

  static Future<void> saveRole(String role) async {
    try {
      await _storage.write(key: _roleKey, value: role);
    } catch (error, stackTrace) {
      if (!kIsWeb) rethrow;
      if (kDebugMode) {
        debugPrint('token_storage: secure role save failed: $error');
        debugPrint('$stackTrace');
      }
    }
    await _fallbackWrite(_roleKey, role);
  }

  static Future<String?> readRole() => _readWithMigration(_roleKey);
}

Future<String?> _readWithMigration(String key) async {
  String? value;
  try {
    value = await _storage.read(key: key);
  } catch (error, stackTrace) {
    if (!kIsWeb) rethrow;
    if (kDebugMode) {
      debugPrint('token_storage: secure read failed: $error');
      debugPrint('$stackTrace');
    }
  }
  if (value != null) {
    return value;
  }

  if (kIsWeb) {
    final fallback = await _fallbackRead(key);
    if (fallback != null) {
      try {
        await _storage.write(key: key, value: fallback);
      } catch (_) {
        // ignore – secure storage unavailable, fallback already has value
      }
      return fallback;
    }
  }

  if (!kIsWeb) {
    return null;
  }

  final legacy = await _legacyWebStorage.read(key: key);
  if (legacy == null) {
    return null;
  }

  try {
    await _storage.write(key: key, value: legacy);
  } catch (_) {
    // ignore secure storage failure; fallback keeps legacy value
  }
  await _legacyWebStorage.delete(key: key);
  await _fallbackWrite(key, legacy);
  return legacy;
}
