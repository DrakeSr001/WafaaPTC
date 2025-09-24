import 'package:dio/dio.dart';
import '../config.dart';
import 'token_storage.dart';

class ApiClient {
  final Dio dio;

  ApiClient()
      : dio = Dio(BaseOptions(
          baseUrl: backendBaseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        )) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await TokenStorage.read();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        options.headers['Content-Type'] = 'application/json';
        handler.next(options);
      },
    ));
  }

  // Month summary: one row per day with first IN / last OUT (strings)
  Future<Map<String, dynamic>> myMonth(
      {required int year, required int month}) async {
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

  Future<String> login(String email, String password, String deviceId) async {
    final r = await dio
        .post('/auth/login', data: {'email': email, 'password': password, 'deviceId': deviceId});
    final token = r.data['accessToken'] as String;
    await TokenStorage.save(token);
    return token;
  }

  Future<Map<String, dynamic>> loginAndGetUser(String email, String password, String deviceId) async {
    final r = await dio.post('/auth/login', data: {'email': email, 'password': password, 'deviceId': deviceId});
    final token = r.data['accessToken'] as String;
    final user = Map<String, dynamic>.from(r.data['user'] as Map);
    await TokenStorage.save(token);
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

  Future<String> clinicMonthCsv({required int year, required int month}) async {
    final r = await dio.get(
      '/reports/clinic-month.csv',
      queryParameters: {'year': year, 'month': month},
      options: Options(responseType: ResponseType.plain),
    );
    return r.data as String;
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
}
