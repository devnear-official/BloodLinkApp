import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../utils/error_mapper.dart';

/// A friendly, full-width error state — icon, short title, message, and an
/// optional Retry button — shown in place of a raw exception whenever a
/// network call fails. Every screen that lists data from the backend
/// (requests, donors, direct requests, notifications, admin users) uses
/// this instead of dumping `error.toString()` into a `Text` widget.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.error,
    this.onRetry,
  });

  /// The raw error caught from a service/provider call. Pass the original
  /// exception object (not a pre-stringified message) so this widget can
  /// classify it via [mapError] and choose the right icon/copy.
  final Object error;

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final mapped = mapError(error);
    return _ErrorStateBody(appError: mapped, onRetry: onRetry);
  }
}

/// Same as [ErrorStateView] but for callers that already hold an
/// [AppError] (e.g. a provider that mapped and cached it once, to avoid
/// re-classifying the same error on every rebuild).
class ErrorStateViewFromAppError extends StatelessWidget {
  const ErrorStateViewFromAppError({
    super.key,
    required this.appError,
    this.onRetry,
  });

  final AppError appError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _ErrorStateBody(appError: appError, onRetry: onRetry);
  }
}

class _ErrorStateBody extends StatelessWidget {
  const _ErrorStateBody({required this.appError, this.onRetry});

  final AppError appError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isOffline = appError.isNoInternet;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOffline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
              size: 34,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isOffline ? 'No Internet Connection' : 'Something Went Wrong',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            appError.message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
            ),
          ],
        ],
      ),
    );
  }
}
