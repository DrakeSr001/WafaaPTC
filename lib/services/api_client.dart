import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config.dart';
import 'device_id.dart';
import 'token_storage.dart';

class ApiClient {
  final Dio dio;
  Completer<void>? _refreshing;

  ApiClient()
      : dio = Dio(
          BaseOptions(
            baseUrl: backendBaseUrl,
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8),
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await TokenStorage.read();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          options.headers['Content-Type'] = 'application/json';
          handler.next(options);
        },
        onError: (error, handler) async {
          final retryResponse = await _tryRefreshAndRetry(error);
          if (retryResponse != null) {
            handler.resolve(retryResponse);
            return;
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<Response<dynamic>?> _tryRefreshAndRetry(DioException error) async {
    final status = error.response?.statusCode;
    final request = error.requestOptions;

    if (status != 401) return null;
    if (request.extra['skipRefresh'] == true) return null;
    if (request.extra['retried'] == true) return null;
    if (request.path.startsWith('/auth/login') || request.path.startsWith('/auth/refresh')) {
      return null;
    }

    final storedRefresh = await TokenStorage.readRefreshToken();
    if (storedRefresh == null || storedRefresh.isEmpty) {
      return null;
    }

    try {
      await _refreshSession(existingToken: storedRefresh);
    } catch (_) {
      return null;
    }

    final token = await TokenStorage.read();
    if (token == null || token.isEmpty) {
      return null;
    }

    request.headers['Authorization'] = 'Bearer $token';
    request.extra['retried'] = true;

    try {
      return await dio.fetch<dynamic>(request);
    } on DioException {
      return null;
    }
  }

  Future<void> _refreshSession({String? existingToken}) async {
    if (_refreshing != null) {
      return _refreshing!.future;
    }

    final completer = Completer<void>();
    _refreshing = completer;

    try {
      final storedRefresh = existingToken ?? await TokenStorage.readRefreshToken();
      if (storedRefresh == null || storedRefresh.isEmpty) {
        await TokenStorage.clear();
        throw StateError('missing_refresh_token');
      }

      final deviceId = await ensureDeviceId();
      final response = await dio.post(
        '/auth/refresh',
        data: {'refreshToken': storedRefresh, 'deviceId': deviceId},
        options: Options(extra: {'skipRefresh': true}),
      );

      final data = response.data;
      if (data is! Map) {
        await TokenStorage.clear();
        throw StateError('invalid_refresh_response');
      }

      final newAccess = data['accessToken'] as String?;
      final newRefresh = data['refreshToken'] as String?;
      if (newAccess == null || newAccess.isEmpty || newRefresh == null || newRefresh.isEmpty) {
        await TokenStorage.clear();
        throw StateError('missing_tokens');
      }

      await TokenStorage.save(newAccess);
      await TokenStorage.saveRefreshToken(newRefresh);

      final refreshExpires = data['refreshTokenExpiresAt'] as String?;
      if (refreshExpires != null && refreshExpires.isNotEmpty) {
        await TokenStorage.saveRefreshExpiresAt(refreshExpires);
      } else {
        await TokenStorage.clearRefreshExpiresAt();
      }

      final user = data['user'];
      if (user is Map && user['role'] is String) {
        await TokenStorage.saveRole((user['role'] as String?) ?? 'doctor');
      }

      completer.complete();
    } catch (error) {
      await TokenStorage.clear();
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
      rethrow;
    } finally {
      _refreshing = null;
    }
  }

  Future<void> _persistSessionFromResponse(Map<String, dynamic> data) async {
    final token = data['accessToken'] as String?;
    final refresh = data['refreshToken'] as String?;
    if (token != null && token.isNotEmpty) {
      await TokenStorage.save(token);
    }
    if (refresh != null && refresh.isNotEmpty) {
      await TokenStorage.saveRefreshToken(refresh);
    } else {
      await TokenStorage.clearRefreshToken();
    }
    final refreshExpires = data['refreshTokenExpiresAt'] as String?;
    if (refreshExpires != null && refreshExpires.isNotEmpty) {
      await TokenStorage.saveRefreshExpiresAt(refreshExpires);
    } else {
      await TokenStorage.clearRefreshExpiresAt();
    }
  }

  Future<void> clearSession() => TokenStorage.clear();

  // Month summary: one row per day with first IN / last OUT (strings)
  Future<Map<String, dynamic>> myMonth({required int year, required int month}) async {
    final r = await dio.get('/attendance/my-month', queryParameters: {
      'year': year,
      'month': month,
    });
    return Map<String, dynamic>.from(r.data);
  }

  // Same data as CSV text (protected with JWT header)
  Future<String> myMonthCsv({required int year, required int month}) async {
    final r = await dio.get(
      '/reports/my-month.csv',
      queryParameters: {'year': year, 'month': month},
      options: Options(responseType: ResponseType.plain),
    );
    return r.data as String;
  }

  Future<String> login(
    String email,
    String password,
    String deviceId, {
    bool rememberMe = false,
  }) async {
    final r = await dio.post(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
        'deviceId': deviceId,
        'rememberMe': rememberMe,
      },
      options: Options(extra: {'skipRefresh': true}),
    );
    final data = Map<String, dynamic>.from(r.data as Map);
    await _persistSessionFromResponse(data);
    final user = data['user'];
    if (user is Map && user['role'] is String) {
      await TokenStorage.saveRole((user['role'] as String?) ?? 'doctor');
    }
    return data['accessToken'] as String;
  }

  Future<Map<String, dynamic>> loginAndGetUser(
    String email,
    String password,
    String deviceId, {
    bool rememberMe = false,
  }) async {
    final r = await dio.post(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
        'deviceId': deviceId,
        'rememberMe': rememberMe,
      },
      options: Options(extra: {'skipRefresh': true}),
    );
    final data = Map<String, dynamic>.from(r.data as Map);
    await _persistSessionFromResponse(data);
    final user = Map<String, dynamic>.from(data['user'] as Map);
    await TokenStorage.saveRole((user['role'] as String?) ?? 'doctor');
    return user; // contains id, name, email, role
  }

  Future<Map<String, dynamic>> scanAttendance(String code) async {
    final r = await dio.post('/attendance/scan', data: {'code': code});
    return Map<String, dynamic>.from(r.data);
  }

  Future<List<Map<String, dynamic>>> listDoctors() async {
    final r = await dio.get('/admin/users', queryParameters: {'role': 'doctor'});
    final list = (r.data as List).cast<dynamic>();
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<String> doctorMonthCsv({required String userId, required int year, required int month}) async {
    final r = await dio.get(
      '/reports/doctor-month.csv',
      queryParameters: {'userId': userId, 'year': year, 'month': month},
      options: Options(responseType: ResponseType.plain),
    );
    return r.data as String;
  }

  Future<Uint8List> clinicMonthWorkbook({required int year, required int month}) async {
    final r = await dio.get(
      '/reports/clinic-month.xlsx',
      queryParameters: {'year': year, 'month': month},
      options: Options(responseType: ResponseType.bytes),
    );
    return _asBytes(r.data);
  }

  Future<String> doctorRangeCsv({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final r = await dio.get(
      '/reports/doctor-range.csv',
      queryParameters: {
        'userId': userId,
        'start': _dateParam(start),
        'end': _dateParam(end),
      },
      options: Options(responseType: ResponseType.plain),
    );
    return r.data as String;
  }

  Future<Uint8List> clinicRangeWorkbook({
    required DateTime start,
    required DateTime end,
  }) async {
    final r = await dio.get(
      '/reports/clinic-range.xlsx',
      queryParameters: {
        'start': _dateParam(start),
        'end': _dateParam(end),
      },
      options: Options(responseType: ResponseType.bytes),
    );
    return _asBytes(r.data);
  }

  Future<Map<String, dynamic>> doctorRangeSummary({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final r = await dio.get(
      '/reports/doctor-range-summary',
      queryParameters: {
        'userId': userId,
        'start': _dateParam(start),
        'end': _dateParam(end),
      },
    );
    return Map<String, dynamic>.from(r.data as Map);
  }

  // Lists
  Future<List<Map<String, dynamic>>> listDevices() async {
    final r = await dio.get('/admin/devices');
    return (r.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // Users
  Future<void> updateUser(String id, {String? fullName, String? role, bool? isActive}) async {
    await dio.patch('/admin/users/$id', data: {
      if (fullName != null) 'fullName': fullName,
      if (role != null) 'role': role,
      if (isActive != null) 'isActive': isActive,
    });
  }

  Future<void> resetUserPassword(String id, String newPassword) async {
    await dio.patch('/admin/users/$id/password', data: {'password': newPassword});
  }

  Future<void> setUserDevice(String id, String deviceId) async {
    await dio.patch('/admin/users/$id/device', data: {'deviceId': deviceId});
  }

  Future<void> clearUserDevice(String id) async {
    await dio.delete('/admin/users/$id/device');
  }

  Future<void> deleteUser(String id) async {
    await dio.delete('/admin/users/$id');
  }

  // Devices
  Future<void> updateDevice(String id, {String? name, String? location, bool? isActive}) async {
    await dio.patch('/admin/devices/$id', data: {
      if (name != null) 'name': name,
      if (location != null) 'location': location,
      if (isActive != null) 'isActive': isActive,
    });
  }

  Future<void> deleteDevice(String id) async {
    await dio.delete('/admin/devices/$id');
  }

  // ---- ADMIN: create user ----
  Future<Map<String, dynamic>> createUser({
    required String fullName,
    required String email,
    required String password,
    String role = 'doctor',
  }) async {
    final r = await dio.post('/admin/users', data: {
      'fullName': fullName,
      'email': email,
      'password': password,
      'role': role,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  // ---- ADMIN: create device ----
  Future<Map<String, dynamic>> createDevice({
    required String name,
    String? location,
  }) async {
    final r = await dio.post('/admin/devices', data: {
      'name': name,
      if (location != null && location.isNotEmpty) 'location': location,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<List<Map<String, dynamic>>> adminAttendanceLogs({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final r = await dio.get(
      '/admin/attendance/logs',
      queryParameters: {
        'userId': userId,
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
      },
    );
    final list = (r.data as List).cast<dynamic>();
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> adminCreateAttendanceLog({
    required String userId,
    required String action,
    required DateTime timestamp,
    String? notes,
  }) async {
    final r = await dio.post('/admin/attendance/logs', data: {
      'userId': userId,
      'action': action,
      'timestamp': timestamp.toUtc().toIso8601String(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> adminUpdateAttendanceLog({
    required String id,
    String? action,
    DateTime? timestamp,
    String? notes,
  }) async {
    final data = <String, dynamic>{
      if (action != null) 'action': action,
      if (timestamp != null) 'timestamp': timestamp.toUtc().toIso8601String(),
    };
    if (notes != null) data['notes'] = notes.trim().isEmpty ? null : notes.trim();
    final r = await dio.patch('/admin/attendance/logs/$id', data: data);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> adminDeleteAttendanceLog(String id) async {
    await dio.delete('/admin/attendance/logs/$id');
  }

  Uint8List _asBytes(dynamic data) {
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(List<int>.from(data));
    throw StateError('unexpected_binary_payload');
  }

  String _dateParam(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}























