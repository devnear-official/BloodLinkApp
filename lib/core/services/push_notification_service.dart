import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class PushNotificationService {
  PushNotificationService._();

  static const _appId = String.fromEnvironment('ONESIGNAL_APP_ID');
  static bool _initialized = false;
  static bool get isAvailable => _initialized;

  static Future<void> initialize({
    required void Function(Map<String, dynamic> data) onNotificationOpened,
  }) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    if (_appId.isEmpty) {
      debugPrint(
        'Mobile push is disabled: provide ONESIGNAL_APP_ID with --dart-define.',
      );
      return;
    }

    try {
      await OneSignal.initialize(_appId);
      OneSignal.Notifications.addClickListener((event) {
        onNotificationOpened(event.notification.additionalData ?? const {});
      });
      _initialized = true;
    } catch (error, stackTrace) {
      debugPrint('OneSignal initialization failed: $error\n$stackTrace');
    }
  }

  static Future<void> identify(String userId) async {
    if (!_initialized) return;
    try {
      await OneSignal.login(userId);
    } catch (error, stackTrace) {
      debugPrint('OneSignal user identification failed: $error\n$stackTrace');
    }
  }

  static Future<void> clearIdentity() async {
    if (!_initialized) return;
    try {
      await OneSignal.logout();
    } catch (error, stackTrace) {
      debugPrint('OneSignal logout failed: $error\n$stackTrace');
    }
  }

  static Future<bool> requestPermission() async {
    if (!_initialized) return false;
    try {
      return await OneSignal.Notifications.requestPermission(true);
    } catch (error, stackTrace) {
      debugPrint(
          'Could not request notification permission: $error\n$stackTrace');
      rethrow;
    }
  }
}
