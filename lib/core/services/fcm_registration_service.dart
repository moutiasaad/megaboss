import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../features/auth/domain/repositories/auth_repository.dart';
import 'fcm_service.dart';

// Owns the FCM lifecycle for the logged-in driver:
//   • Fetches the current FCM token and POSTs it to /driver/device/register
//   • Subscribes to onTokenRefresh and re-registers if FCM rotates the token
//   • Idempotent — skips the network call when the token hasn't changed
//
// Called from LoginController.submit (post-login) and AuthController.build
// (cold start when already authenticated). The actual DELETE is done from
// AuthRepository.unregisterDevice on logout.
class FcmRegistrationService {
  FcmRegistrationService({
    required FcmService fcmService,
    required AuthRepository authRepository,
  })  : _fcm = fcmService,
        _auth = authRepository;

  final FcmService _fcm;
  final AuthRepository _auth;

  StreamSubscription<String>? _refreshSub;
  String? _lastRegisteredToken;
  String? _cachedAppVersion;

  // Idempotent: safe to call multiple times. Returns true when the server now
  // has a fresh token, false on permission denial / network error.
  Future<bool> register() async {
    try {
      final token = await _fcm.getToken();
      if (token == null) {
        debugPrint('[FcmRegistration] no token (permission denied?)');
        return false;
      }

      final registered = await _sendIfNeeded(token);

      // Keep the server in sync if Firebase rotates the token later.
      _refreshSub ??= _fcm.onTokenRefresh.listen(
        (newToken) => unawaited(_sendIfNeeded(newToken)),
        onError: (Object e) => debugPrint('[FcmRegistration] refresh err: $e'),
      );

      return registered;
    } catch (e) {
      debugPrint('[FcmRegistration] register failed (non-fatal): $e');
      return false;
    }
  }

  // Cancels the refresh subscription. Call on logout.
  Future<void> stop() async {
    await _refreshSub?.cancel();
    _refreshSub = null;
    _lastRegisteredToken = null;
  }

  Future<bool> _sendIfNeeded(String token) async {
    if (token == _lastRegisteredToken) return false;
    final version = await _readAppVersion();
    final platform = Platform.isAndroid ? 'android' : 'ios';
    await _auth.registerDevice(
      fcmToken: token,
      platform: platform,
      appVersion: version,
    );
    _lastRegisteredToken = token;
    debugPrint('[FcmRegistration] registered token (platform=$platform v=$version)');
    return true;
  }

  Future<String> _readAppVersion() async {
    if (_cachedAppVersion != null) return _cachedAppVersion!;
    try {
      final info = await PackageInfo.fromPlatform();
      _cachedAppVersion = info.version;
    } catch (_) {
      _cachedAppVersion = '1.0.0';
    }
    return _cachedAppVersion!;
  }
}
