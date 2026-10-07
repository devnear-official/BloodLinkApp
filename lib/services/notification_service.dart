import 'package:dio/dio.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/api_client.dart';
import '../models/notification_model.dart';

/// Talks to the `/api/notifications/*` routes.
class NotificationService {
  final Dio _dio = ApiClient.instance.dio;

  Future<List<NotificationModel>> getNotifications() async {
    final response = await _dio.get(ApiEndpoints.notifications);
    _ensureOk(response);
    final list = response.data as List<dynamic>;
    return list
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markAsRead(String id) async {
    final response = await _dio.put(ApiEndpoints.notificationRead(id));
    _ensureOk(response);
  }

  Future<void> markAllAsRead(List<String> ids) async {
    // Backend only exposes a per-notification endpoint, so mark-all fans
    // out concurrently rather than blocking on each one sequentially.
    await Future.wait(ids.map(markAsRead));
  }

  Future<String?> getVapidPublicKey() async {
    final response = await _dio.get(ApiEndpoints.vapidPublicKey);
    _ensureOk(response);
    final data = response.data;
    if (data is Map<String, dynamic>) return data['key'] as String?;
    return data?.toString();
  }

  Future<void> subscribePush(Map<String, dynamic> subscription) async {
    final response = await _dio.post(
      ApiEndpoints.subscribePush,
      data: subscription,
    );
    _ensureOk(response);
  }

  Future<void> sendTestPush() async {
    final response = await _dio.post(ApiEndpoints.testPush);
    _ensureOk(response);
  }

  void _ensureOk(Response response) {
    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300) {
      final message = (response.data is Map)
          ? (response.data['message'] ?? 'Request failed')
          : 'Request failed';
      throw Exception(message);
    }
  }
}
