import 'package:dio/dio.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/api_client.dart';
import '../models/user_model.dart';

/// Talks to the `/api/users/*` routes: profile fetch/update, donor search
/// listing, and admin user-management actions.
class UserService {
  final Dio _dio = ApiClient.instance.dio;

  Future<UserModel> getMe() async {
    final response = await _dio.get(ApiEndpoints.me);
    _ensureOk(response);
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserModel> updateMe(Map<String, dynamic> updates) async {
    final response = await _dio.put(ApiEndpoints.me, data: updates);
    _ensureOk(response);
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Fetches all users. Used both for donor search (filtered client-side
  /// or via query params) and the admin panel.
  Future<List<UserModel>> getUsers({
    String? division,
    String? district,
    String? subDistrict,
    String? bloodGroup,
  }) async {
    final response = await _dio.get(
      ApiEndpoints.users,
      queryParameters: {
        if (division != null && division.isNotEmpty) 'division': division,
        if (district != null && district.isNotEmpty) 'district': district,
        if (subDistrict != null && subDistrict.isNotEmpty)
          'subDistrict': subDistrict,
        if (bloodGroup != null && bloodGroup.isNotEmpty)
          'bloodGroup': bloodGroup,
      },
    );
    _ensureOk(response);
    final list = (response.data as List<dynamic>);
    return list
        .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateUserStatus(String userId, String status) async {
    final response = await _dio.put(
      ApiEndpoints.userStatus(userId),
      data: {'status': status},
    );
    _ensureOk(response);
  }

  Future<void> updateUserRole(String userId, String role) async {
    final response = await _dio.put(
      ApiEndpoints.userRole(userId),
      data: {'role': role},
    );
    _ensureOk(response);
  }

  Future<void> deleteUser(String userId) async {
    final response = await _dio.delete(ApiEndpoints.userById(userId));
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
