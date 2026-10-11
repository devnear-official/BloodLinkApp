import 'package:dio/dio.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/api_client.dart';
import '../models/user_model.dart';

/// Result of a successful login/register/google-auth call.
class AuthResult {
  AuthResult({required this.token, required this.user});
  final String token;
  final UserModel user;
}

/// Talks to the `/api/auth/*` routes. Never touches storage or widgets —
/// [AuthProvider] is responsible for persisting the resulting token/user
/// and for driving navigation.
class AuthService {
  final Dio _dio = ApiClient.instance.dio;

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? bloodGroup,
    String? division,
    String? district,
    String? subDistrict,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.register,
      data: {
        'name': name,
        'email': email,
        'password': password,
        if (phone != null) 'phone': phone,
        if (bloodGroup != null) 'bloodGroup': bloodGroup,
        if (division != null) 'division': division,
        if (district != null) 'district': district,
        if (subDistrict != null) 'upazila': subDistrict,
      },
    );
    return _resultFromResponse(response);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.login,
      data: {'email': email, 'password': password},
    );
    return _resultFromResponse(response);
  }

  Future<AuthResult> googleAuth({required String idToken}) async {
    final response = await _dio.post(
      ApiEndpoints.googleAuth,
      data: {'idToken': idToken},
    );
    return _resultFromResponse(response);
  }

  AuthResult _resultFromResponse(Response response) {
    if (response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300) {
      final data = response.data as Map<String, dynamic>;
      return AuthResult(
        token: data['token'] as String,
        user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
      );
    }
    final message = (response.data is Map)
        ? (response.data['message'] ?? 'Authentication failed')
        : 'Authentication failed';
    throw Exception(message);
  }
}
