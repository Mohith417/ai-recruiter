import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiClient {
  ApiClient._();

  static String? activeToken;

  static Dio create() {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:4000';

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          String? token;
          try {
            final session = Supabase.instance.client.auth.currentSession;
            token = session?.accessToken;
          } catch (_) {
            // Supabase is not initialized or no session active
          }

          token ??= activeToken;

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          return handler.next(options);
        },
      ),
    );

    return dio;
  }
}
