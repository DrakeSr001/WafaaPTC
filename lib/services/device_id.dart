import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _prefsKeyDeviceId = 'device_id_v1';
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

  final existing = prefs?.getString(_prefsKeyDeviceId);
  if (existing != null && existing.isNotEmpty) {
    _cachedDeviceId = existing;
    return existing;
  }

  final generated = _uuid.v4();
  _cachedDeviceId = generated;

  if (prefs != null) {
    try {
      await prefs.setString(_prefsKeyDeviceId, generated);
    } catch (error, stackTrace) {
      _logSharedPrefsIssue('setString', error, stackTrace);
    }
  }

  return generated;
}

void _logSharedPrefsIssue(String action, Object error, StackTrace stackTrace) {
  if (kDebugMode) {
    debugPrint('device_id: $action failed: $error');
    debugPrint('$stackTrace');
  }
}