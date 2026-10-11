import 'package:flutter/foundation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/socket_service.dart';
import '../core/utils/error_mapper.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

/// Drives the notifications screen and the bottom-nav unread badge.
class NotificationProvider extends ChangeNotifier {
  NotificationProvider({NotificationService? service})
      : _service = service ?? NotificationService() {
    _registerSocketListeners();
  }

  final NotificationService _service;

  List<NotificationModel> notifications = [];
  bool isLoading = false;
  AppError? appError;
  String? get errorMessage => appError?.message;

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  void _registerSocketListeners() {
    SocketService.instance.on(ApiEndpoints.eventNotificationNew, (data) {
      if (data is Map<String, dynamic>) {
        final incoming = NotificationModel.fromJson(data);
        if (!notifications.any((n) => n.id == incoming.id)) {
          notifications = [incoming, ...notifications];
          notifyListeners();
        }
      }
    });
  }

  @override
  void dispose() {
    SocketService.instance.off(ApiEndpoints.eventNotificationNew);
    super.dispose();
  }

  Future<void> loadNotifications() async {
    isLoading = true;
    appError = null;
    notifyListeners();
    try {
      notifications = await _service.getNotifications();
    } catch (e) {
      appError = mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String id) async {
    final index = notifications.indexWhere((n) => n.id == id);
    if (index == -1 || notifications[index].isRead) return;
    // Optimistic update — snap back if the request fails.
    final previous = notifications[index];
    notifications[index] = previous.copyWith(isRead: true);
    notifyListeners();
    try {
      await _service.markAsRead(id);
    } catch (e) {
      notifications[index] = previous;
      appError = mapError(e);
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    final unreadIds =
        notifications.where((n) => !n.isRead).map((n) => n.id).toList();
    if (unreadIds.isEmpty) return;
    final previous = notifications;
    notifications =
        notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
    try {
      await _service.markAllAsRead();
    } catch (e) {
      notifications = previous;
      appError = mapError(e);
      notifyListeners();
    }
  }

  Future<bool> sendTestPush() async {
    try {
      await _service.sendTestPush();
      return true;
    } catch (e) {
      appError = mapError(e);
      notifyListeners();
      return false;
    }
  }
}
