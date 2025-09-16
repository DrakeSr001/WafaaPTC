import 'package:dio/dio.dart';
import '../config.dart';
import 'token_storage.dart';

class ApiClient {
  final Dio dio;

  ApiClient() : dio = Dio(BaseOptions(
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

  Future<String> login(String email, String password) async {
    final r = await dio.post('/auth/login', data: {'email': email, 'password': password});
    final token = r.data['accessToken'] as String;
    await TokenStorage.save(token);
    return token;
  }

  Future<Map<String, dynamic>> scanAttendance(String code) async {
    final r = await dio.post('/attendance/scan', data: {'code': code});
    return Map<String, dynamic>.from(r.data);
  }
}
