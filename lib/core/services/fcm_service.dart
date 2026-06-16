import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FcmService {
  FcmService(this._messaging);
  final FirebaseMessaging _messaging;

  /// Requests notification permission (required on iOS; no-op on Android < 13).
  /// Returns the FCM token, or null if permission was denied or on error.
  Future<String?> getToken() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FcmService] notification permission denied');
        return null;
      }
      final token = await _messaging.getToken();
      debugPrint('[FcmService] token: $token');
      return token;
    } catch (e) {
      debugPrint('[FcmService] getToken error: $e');
      return null;
    }
  }

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;
}
