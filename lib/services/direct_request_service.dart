import 'package:dio/dio.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/api_client.dart';
import '../models/direct_request_model.dart';

/// Talks to the `/api/direct-requests/*` routes.
class DirectRequestService {
  final Dio _dio = ApiClient.instance.dio;

  /// [box] is either 'received' or 'sent'.
  Future<List<DirectRequestModel>> getDirectRequests(String box) async {
    final response = await _dio.get(
      ApiEndpoints.directRequests,
      queryParameters: {'type': box},
    );
    _ensureOk(response);
    final list = response.data as List<dynamic>;
    return list
        .map((e) => DirectRequestModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DirectRequestModel> createDirectRequest(
    DirectRequestModel request, {
    required String toUserId,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.directRequests,
      data: request.toCreateJson(toUserId: toUserId),
    );
    _ensureOk(response);
    return DirectRequestModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DirectRequestModel> updateStatus({
    required String id,
    required String status, // Accepted | Declined | Cancelled
  }) async {
    final response = await _dio.put(
      ApiEndpoints.directRequestStatus(id),
      data: {'status': status},
    );
    _ensureOk(response);
    return DirectRequestModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> cancel(String id) async {
    final response = await _dio.delete(ApiEndpoints.directRequestById(id));
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
