import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';

// FCM device registration — called after login and before logout.
class DeviceService {
  const DeviceService(this._client);
  final ApiClient _client;

  // POST /driver/device/register
  Future<void> register({
    required String deviceToken,
    required String platform, // 'android' | 'ios'
    required String appVersion,
  }) async {
    try {
      await _client.dio.post<void>(
        Endpoints.deviceRegister,
        data: {
          'device_token': deviceToken,
          'platform': platform,
          'app_version': appVersion,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // DELETE /driver/device — called during logout
  Future<void> unregister() async {
    try {
      await _client.dio.delete<void>(Endpoints.device);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
