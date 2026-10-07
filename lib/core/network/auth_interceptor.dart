import 'package:dio/dio.dart';

import '../services/storage_service.dart';

/// Attaches `Authorization: Bearer <token>` to every outgoing request that
/// has a token available, and reacts to `401 Unauthorized` responses by
/// clearing the local session and notifying the app so it can redirect to
/// the login screen.
///
/// [onUnauthorized] is injected from `main.dart` rather than hard-coding a
/// navigation call here, keeping this class free of any UI/routing
/// knowledge (services never touch widgets).
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.onUnauthorized});

  final Future<void> Function() onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await StorageService.instance.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      await StorageService.instance.clearSession();
      await onUnauthorized();
    }
    handler.next(err);
  }
}
