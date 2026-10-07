import 'package:dio/dio.dart';

/// Broad category of a failure, used to decide which icon/copy an
/// [ErrorStateView] shows.
enum AppErrorType {
  /// No internet connection, or the host couldn't be resolved/reached at
  /// all (DNS failure, airplane mode, etc.).
  noInternet,

  /// The request reached the server but it took too long to respond —
  /// common with the backend's free-tier cold starts.
  timeout,

  /// The server responded, but with an error status.
  server,

  /// Anything else (parsing errors, unexpected app-level exceptions).
  unknown,
}

/// A user-facing error: a short, friendly [message] plus enough
/// classification ([type]) for the UI to pick an appropriate icon.
class AppError {
  const AppError({required this.message, required this.type});

  final String message;
  final AppErrorType type;

  bool get isNoInternet => type == AppErrorType.noInternet;
}

/// Pulls a human-readable message out of whatever shape the backend used
/// for its error response body. Different endpoints/backends commonly use
/// different keys (`message`, `error`, `errors: [...]`, `msg`), so this
/// checks each in turn rather than assuming one convention — otherwise a
/// perfectly good validation reason from the server gets swallowed into a
/// generic "something went wrong", making the real problem invisible.
String? _extractServerMessage(dynamic data) {
  if (data == null) return null;

  if (data is String && data.trim().isNotEmpty) return data.trim();

  if (data is Map) {
    for (final key in ['message', 'error', 'msg', 'detail']) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    final errors = data['errors'];
    if (errors is List && errors.isNotEmpty) {
      final parts = errors.map((e) {
        if (e is String) return e;
        if (e is Map) {
          return (e['message'] ?? e['msg'] ?? e.toString()).toString();
        }
        return e.toString();
      });
      return parts.join(', ');
    }
    if (errors is Map && errors.isNotEmpty) {
      return errors.values.map((v) => v.toString()).join(', ');
    }
  }

  return null;
}

/// Converts any error thrown by the networking/service layer into an
/// [AppError] with friendly, non-technical copy. This is the single place
/// that should ever look at a raw [DioException] — every provider and
/// screen in the app should go through this rather than calling
/// `error.toString()` directly, so a person never sees something like
/// "DioException [connection error]: Failed host lookup: ...".
AppError mapError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionError:
        return const AppError(
          message:
              "You're offline. Check your internet connection and try again.",
          type: AppErrorType.noInternet,
        );

      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const AppError(
          message:
              'The server is taking longer than usual to respond. Please try again in a moment.',
          type: AppErrorType.timeout,
        );

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final serverMessage = _extractServerMessage(error.response?.data);
        final prefix = statusCode != null ? '[$statusCode] ' : '';
        return AppError(
          message: serverMessage != null
              ? '$prefix$serverMessage'
              : 'Something went wrong on the server${statusCode != null ? ' ($statusCode)' : ''}. Please try again.',
          type: AppErrorType.server,
        );

      case DioExceptionType.cancel:
        return const AppError(
          message: 'The request was cancelled.',
          type: AppErrorType.unknown,
        );

      case DioExceptionType.badCertificate:
        return const AppError(
          message: 'Couldn\'t establish a secure connection. Please try again.',
          type: AppErrorType.unknown,
        );

      case DioExceptionType.unknown:
        // Dio bundles plain socket/DNS failures under `unknown` on some
        // platforms rather than `connectionError` — treat them the same.
        final underlying = error.error?.toString().toLowerCase() ?? '';
        if (underlying.contains('socketexception') ||
            underlying.contains('failed host lookup') ||
            underlying.contains('network is unreachable')) {
          return const AppError(
            message:
                "You're offline. Check your internet connection and try again.",
            type: AppErrorType.noInternet,
          );
        }
        return const AppError(
          message: 'Something went wrong. Please try again.',
          type: AppErrorType.unknown,
        );
    }
  }

  // Non-Dio exceptions thrown by our own service layer are already plain
  // `Exception('message from server')` strings — strip the boilerplate
  // prefix and use them as-is, since they're already meant to be shown.
  final raw = error.toString().replaceFirst('Exception: ', '').trim();
  return AppError(
    message: raw.isEmpty ? 'Something went wrong. Please try again.' : raw,
    type: AppErrorType.unknown,
  );
}
