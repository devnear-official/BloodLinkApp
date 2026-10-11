import 'package:dio/dio.dart';

import '../constants/api_endpoints.dart';
import 'auth_interceptor.dart';

/// Wraps a configured [Dio] instance. Every service in `lib/services/`
/// should call [ApiClient.instance.dio] rather than constructing its own
/// Dio — this keeps timeouts, headers, and interceptors consistent
/// app-wide.
///
/// Timeouts allow the local backend time to connect to its database.
class ApiClient {
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();

  late final Dio dio = _build();

  /// Must be called once, early in `main()`, with a callback that routes
  /// the user back to the login screen after a 401.
  void configure({required Future<void> Function() onUnauthorized}) {
    dio.interceptors
      ..clear()
      ..add(AuthInterceptor(onUnauthorized: onUnauthorized))
      ..add(
        LogInterceptor(
          requestBody: false,
          responseBody: false,
          error: true,
          logPrint: (_) {}, // silenced in production; flip on for debugging
        ),
      );
  }

  Dio _build() {
    return Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.apiBase,
        // Leave enough time for the backend and database to establish a connection.
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        // Only treat 2xx as success — every 4xx/5xx now throws a proper
        // DioException (type: badResponse) that carries the full response
        // body, so error_mapper.dart's mapError() can pull out the real
        // backend validation message consistently everywhere, instead of
        // each service having to hand-roll its own error text.
        validateStatus: (status) => status != null && status >= 200 && status < 300,
      ),
    );
  }
}
