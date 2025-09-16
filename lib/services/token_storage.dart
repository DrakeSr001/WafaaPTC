import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _k = FlutterSecureStorage();

  static Future<void> save(String token) => _k.write(key: 'accessToken', value: token);
  static Future<String?> read() => _k.read(key: 'accessToken');
  static Future<void> clear() => _k.delete(key: 'accessToken');
}
