import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _prefsKeyDeviceId = 'device_id_v1';
final _uuid = Uuid();
String? _cachedDeviceId;

Future<String> ensureDeviceId() async {
  if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
    return _cachedDeviceId!;
  }

  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(_prefsKeyDeviceId);
  if (existing != null && existing.isNotEmpty) {
    _cachedDeviceId = existing;
    return existing;
  }

  final generated = _uuid.v4();
  await prefs.setString(_prefsKeyDeviceId, generated);
  _cachedDeviceId = generated;
  return generated;
}