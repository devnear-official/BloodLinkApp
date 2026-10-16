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
    final data = response.data;
    final list = data is List<dynamic>
        ? data
        : (data as Map<String, dynamic>)['items'] as List<dynamic>;
    return list
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markAsRead(String id) async {
    final response = await _dio.put(ApiEndpoints.notificationRead(id));
    _ensureOk(response);
  }

  Future<void> markAllAsRead() async {
    final response = await _dio.put(ApiEndpoints.notificationsReadAll);
    _ensureOk(response);
  }

  Future<NotificationModel> sendTestPush() async {
    final response = await _dio.post(ApiEndpoints.testPush);
    _ensureOk(response);
    final data = response.data as Map<String, dynamic>;
    return NotificationModel.fromJson(
      data['notification'] as Map<String, dynamic>,
    );
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
