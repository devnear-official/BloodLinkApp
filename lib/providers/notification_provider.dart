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
  String? _userId;
  int _loadGeneration = 0;

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  void setUserId(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _loadGeneration++;
    notifications = [];
    isLoading = false;
    appError = null;
    notifyListeners();
  }

  void _registerSocketListeners() {
    SocketService.instance.on(ApiEndpoints.eventNotificationNew, (data) {
      if (data is Map) {
        final incoming = NotificationModel.fromJson(
          Map<String, dynamic>.from(data),
        );
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
    final userId = _userId;
    if (userId == null) return;
    final generation = ++_loadGeneration;
    isLoading = true;
    appError = null;
    notifyListeners();
    try {
      final fetched = await _service.getNotifications();
      if (generation != _loadGeneration || userId != _userId) return;
      final currentIds = fetched.map((notification) => notification.id).toSet();
      notifications = [
        ...fetched,
        ...notifications.where(
          (notification) => !currentIds.contains(notification.id),
        ),
      ];
    } catch (e) {
      if (generation == _loadGeneration && userId == _userId) {
        appError = mapError(e);
      }
    } finally {
      if (generation == _loadGeneration && userId == _userId) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> markAsRead(String id) async {
    final userId = _userId;
    final index = notifications.indexWhere((n) => n.id == id);
    if (index == -1 || notifications[index].isRead) return true;
    // Optimistic update — snap back if the request fails.
    final previous = notifications[index];
    notifications[index] = previous.copyWith(isRead: true);
    notifyListeners();
    try {
      await _service.markAsRead(id);
      return true;
    } catch (e) {
      if (userId != _userId) return false;
      final currentIndex = notifications.indexWhere((n) => n.id == id);
      if (currentIndex != -1) notifications[currentIndex] = previous;
      appError = mapError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> markAllAsRead() async {
    final userId = _userId;
    final unreadIds =
        notifications.where((n) => !n.isRead).map((n) => n.id).toList();
    if (unreadIds.isEmpty) return true;
    final previous = notifications;
    notifications = notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
    try {
      await _service.markAllAsRead();
      return true;
    } catch (e) {
      if (userId != _userId) return false;
      final currentById = {
        for (final notification in notifications) notification.id: notification,
      };
      notifications = [
        ...previous.map(
          (notification) => currentById[notification.id] ?? notification,
        ),
        ...notifications.where(
          (notification) => !previous.any((old) => old.id == notification.id),
        ),
      ];
      appError = mapError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendTestPush() async {
    final userId = _userId;
    if (userId == null) return false;
    try {
      final notification = await _service.sendTestPush();
      if (userId != _userId) return false;
      if (!notifications.any((item) => item.id == notification.id)) {
        notifications = [notification, ...notifications];
        notifyListeners();
      }
      return true;
    } catch (e) {
      if (userId != _userId) return false;
      appError = mapError(e);
      notifyListeners();
      return false;
    }
  }
}
