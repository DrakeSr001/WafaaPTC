import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _prefsKeyDeviceId = 'device_id_v1';
const FlutterSecureStorage _secureDeviceStorage = FlutterSecureStorage(
  webOptions: WebOptions(
    dbName: 'wafaaptc_device_db',
    publicKey: 'wafaaptc_device',
  ),
);
final _uuid = Uuid();
String? _cachedDeviceId;

Future<String> ensureDeviceId() async {
  final cached = _cachedDeviceId;
  if (cached != null && cached.isNotEmpty) {
    return cached;
  }

  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (error, stackTrace) {
    _logSharedPrefsIssue('getInstance', error, stackTrace);
  }

  final stored = prefs?.getString(_prefsKeyDeviceId);
  if (stored != null && stored.isNotEmpty) {
    _cachedDeviceId = stored;
    await _persistToSecure(stored);
    return stored;
  }

  final secureStored = await _readFromSecure();
  if (secureStored != null && secureStored.isNotEmpty) {
    _cachedDeviceId = secureStored;
    await _savePrefs(prefs, secureStored);
    return secureStored;
  }

  final generated = _uuid.v4();
  _cachedDeviceId = generated;
  await Future.wait([
    _savePrefs(prefs, generated),
    _persistToSecure(generated),
  ]);
  return generated;
}

Future<String?> _readFromSecure() async {
  try {
    final value = await _secureDeviceStorage.read(key: _prefsKeyDeviceId);
    if (value != null && value.isNotEmpty) {
      return value;
    }
  } catch (error, stackTrace) {
    _logSecureIssue('read', error, stackTrace);
  }
  return null;
}

Future<void> _persistToSecure(String deviceId) async {
  try {
    await _secureDeviceStorage.write(key: _prefsKeyDeviceId, value: deviceId);
  } catch (error, stackTrace) {
    _logSecureIssue('write', error, stackTrace);
  }
}

Future<void> _savePrefs(SharedPreferences? prefs, String deviceId) async {
  if (prefs == null) {
    return;
  }
  try {
    await prefs.setString(_prefsKeyDeviceId, deviceId);
  } catch (error, stackTrace) {
    _logSharedPrefsIssue('setString', error, stackTrace);
  }
}

void _logSharedPrefsIssue(String action, Object error, StackTrace stackTrace) {
  if (kDebugMode) {
    debugPrint('device_id: $action failed: $error');
    debugPrint('$stackTrace');
  }
}

void _logSecureIssue(String action, Object error, StackTrace stackTrace) {
  if (kDebugMode) {
    debugPrint('device_id secure: $action failed: $error');
    debugPrint('$stackTrace');
  }
}
