import 'package:dio/dio.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/api_client.dart';
import '../models/blood_request_model.dart';

/// Talks to the `/api/requests/*` routes.
class RequestService {
  final Dio _dio = ApiClient.instance.dio;

  Future<List<BloodRequestModel>> getRequests({
    String? division,
    String? district,
    String? bloodGroup,
  }) async {
    final response = await _dio.get(
      ApiEndpoints.requests,
      queryParameters: {
        if (division != null && division.isNotEmpty) 'division': division,
        if (district != null && district.isNotEmpty) 'district': district,
        if (bloodGroup != null && bloodGroup.isNotEmpty)
          'bloodGroup': bloodGroup,
      },
    );
    _ensureOk(response);
    final list = response.data as List<dynamic>;
    return list
        .map((e) => BloodRequestModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BloodRequestModel> createRequest(BloodRequestModel request) async {
    final response = await _dio.post(
      ApiEndpoints.requests,
      data: request.toCreateJson(),
    );
    _ensureOk(response);
    return BloodRequestModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Donor responds to an open request. The backend re-validates the
  /// 90-day eligibility rule server-side regardless of client-side checks.
  Future<BloodRequestModel> respondToRequest(String requestId) async {
    final response = await _dio.post(ApiEndpoints.requestRespond(requestId));
    _ensureOk(response);
    return BloodRequestModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Request creator accepts or rejects a specific donor's response.
  Future<BloodRequestModel> setResponseStatus({
    required String requestId,
    required String donorId,
    required String status, // 'Accepted' | 'Rejected'
  }) async {
    final response = await _dio.put(
      ApiEndpoints.requestResponseStatus(requestId, donorId),
      data: {'status': status},
    );
    _ensureOk(response);
    return BloodRequestModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BloodRequestModel> updateRequestStatus({
    required String requestId,
    required String status,
  }) async {
    final response = await _dio.put(
      ApiEndpoints.requestStatus(requestId),
      data: {'status': status},
    );
    _ensureOk(response);
    return BloodRequestModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BloodRequestModel> updateRequestPriority({
    required String requestId,
    required String priority,
  }) async {
    final response = await _dio.put(
      ApiEndpoints.requestPriority(requestId),
      data: {'priority': priority},
    );
    _ensureOk(response);
    return BloodRequestModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteRequest(String requestId) async {
    final response = await _dio.delete(ApiEndpoints.requestById(requestId));
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
