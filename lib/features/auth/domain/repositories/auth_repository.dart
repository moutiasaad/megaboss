import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/driver_model.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/device_service.dart';
import '../../../../core/network/api_client.dart';

const _kDriverBox = 'mb_driver';
const _kDriverKey = 'current';

// Offline-first auth repository.
// Stores the driver profile in Hive so it is available immediately on cold start.
class AuthRepository {
  AuthRepository({
    required AuthService authService,
    required DeviceService deviceService,
    required ApiClient apiClient,
    required Box<String> driverBox,
  })  : _authService = authService,
        _deviceService = deviceService,
        _apiClient = apiClient,
        _driverBox = driverBox;

  final AuthService _authService;
  final DeviceService _deviceService;
  final ApiClient _apiClient;
  final Box<String> _driverBox;

  static Future<Box<String>> openBox() => Hive.openBox<String>(_kDriverBox);

  // ── Auth ───────────────────────────────────────────────────────────────────

  // Login: authenticate, persist token, persist driver profile, register FCM.
  Future<DriverModel> login({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    debugPrint('[AuthRepository.login] calling authService.login');
    final result = await _authService.login(
      email: email,
      password: password,
      deviceName: deviceName,
    );
    debugPrint('[AuthRepository.login] token received, saving');
    await _apiClient.saveToken(result.token);
    debugPrint('[AuthRepository.login] token saved, driver=${result.driver?.name}');

    final driver = result.driver ?? await _authService.me();
    debugPrint('[AuthRepository.login] final driver: ${driver.name}');
    _cacheDriver(driver);
    return driver;
  }

  // Logout: invalidate server session, delete local token and profile.
  Future<void> logout() async {
    await _authService.logout();
    await _apiClient.deleteToken();
    await _driverBox.clear();
  }

  // Refresh the token and persist the new one.
  Future<void> refreshToken() async {
    final newToken = await _authService.refresh();
    await _apiClient.saveToken(newToken);
  }

  // Register FCM token after login.
  Future<void> registerDevice({
    required String fcmToken,
    required String platform,
    required String appVersion,
  }) =>
      _deviceService.register(
        deviceToken: fcmToken,
        platform: platform,
        appVersion: appVersion,
      );

  Future<void> unregisterDevice() => _deviceService.unregister();

  // ── Profile ────────────────────────────────────────────────────────────────

  // Returns cached profile immediately; refreshes in background.
  DriverModel? get cachedDriver {
    final raw = _driverBox.get(_kDriverKey);
    if (raw == null) return null;
    try {
      return DriverModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<DriverModel> fetchDriver() async {
    final driver = await _authService.me();
    _cacheDriver(driver);
    return driver;
  }

  bool get isAuthenticated => _driverBox.containsKey(_kDriverKey);

  Future<bool> hasToken() => _apiClient.hasToken();

  // ── Cache helpers ──────────────────────────────────────────────────────────

  void _cacheDriver(DriverModel driver) {
    _driverBox.put(_kDriverKey, jsonEncode(driver.toJson()));
  }
}
