import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/endpoints.dart';
import '../models/driver_model.dart';

// Raw API calls for authentication — no caching, no state.
// Callers: AuthRepository
class AuthService {
  const AuthService(this._client);
  final ApiClient _client;

  // POST /driver/login → {data: {token, user}}
  // Returns the raw token string; driver model is a bonus if included.
  Future<({String token, DriverModel? driver})> login({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    try {
      debugPrint('[AuthService.login] POST ${Endpoints.login} email=$email');
      final response = await _client.dio.post<Map<String, dynamic>>(
        Endpoints.login,
        data: {
          'email': email,
          'password': password,
          'device_name': deviceName,
        },
      );
      debugPrint('[AuthService.login] HTTP ${response.statusCode}');
      debugPrint('[AuthService.login] body keys: ${response.data?.keys}');
      final body = response.data!;
      final data = body['data'] as Map<String, dynamic>;
      debugPrint('[AuthService.login] data keys: ${data.keys}');
      final token = data['token'] as String;
      // API returns user fields directly inside data (not nested under 'user').
      final userJson = (data['user'] as Map<String, dynamic>?) ?? data;
      debugPrint('[AuthService.login] userJson keys: ${userJson.keys}');
      final driver = DriverModel.fromJson(userJson);
      debugPrint('[AuthService.login] driver parsed: ${driver.name}');
      return (token: token, driver: driver);
    } on DioException catch (e) {
      debugPrint('[AuthService.login] DioException: ${e.type} ${e.response?.statusCode} ${e.message}');
      throw mapDioException(e);
    } catch (e, st) {
      debugPrint('[AuthService.login] unexpected error: $e\n$st');
      rethrow;
    }
  }

  // GET /driver/me → {data: DriverModel}
  Future<DriverModel> me() async {
    try {
      return await _client.get<DriverModel>(
        Endpoints.me,
        mapper: (data) => DriverModel.fromJson(data as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // POST /driver/refresh → {data: {token}}
  Future<String> refresh() async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(Endpoints.refresh);
      return (response.data!['data'] as Map<String, dynamic>)['token'] as String;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // POST /driver/logout
  Future<void> logout() async {
    try {
      await _client.dio.post<void>(Endpoints.logout);
    } on DioException catch (e) {
      // Ignore 401 — token may already be revoked.
      final mapped = mapDioException(e);
      if (mapped is UnauthorizedException) return;
      throw mapped;
    }
  }
}
