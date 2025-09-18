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

  Future<String> login(String email, String password) async {
    final r = await dio
        .post('/auth/login', data: {'email': email, 'password': password});
    final token = r.data['accessToken'] as String;
    await TokenStorage.save(token);
    return token;
  }

  Future<Map<String, dynamic>> scanAttendance(String code) async {
    final r = await dio.post('/attendance/scan', data: {'code': code});
    return Map<String, dynamic>.from(r.data);
  }
}
