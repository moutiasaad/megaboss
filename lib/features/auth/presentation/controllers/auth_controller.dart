import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/driver_model.dart';
import '../../../../core/network/providers.dart';

// Auth state: null = unauthenticated, DriverModel = authenticated.
class AuthController extends AsyncNotifier<DriverModel?> {
  @override
  Future<DriverModel?> build() async {
    final repo = ref.watch(authRepositoryProvider);
    if (!await repo.hasToken()) return null;
    // Return cached profile immediately; refresh in background.
    final cached = repo.cachedDriver;
    Future.microtask(() async {
      try {
        final fresh = await repo.fetchDriver();
        state = AsyncData(fresh);
      } catch (_) {
        // Ignore — cached profile is still valid.
      }
    });
    // Cold-start FCM registration so the server has the current device token
    // even when the driver doesn't re-login (e.g. after a Firebase config
    // change rotates the token). Fire-and-forget — never blocks startup.
    Future.microtask(
      () => ref.read(fcmRegistrationServiceProvider).register(),
    );
    return cached;
  }

  Future<bool> login({
    required String email,
    required String password,
    String deviceName = 'MegaBoss Driver',
  }) async {
    state = const AsyncLoading();
    try {
      final driver = await ref.read(authRepositoryProvider).login(
            email: email,
            password: password,
            deviceName: deviceName,
          );
      state = AsyncData(driver);
      // Start offline sync listener.
      ref.read(syncPushServiceProvider).start();
      // Register the FCM token with the server. Service is idempotent and
      // self-subscribes to onTokenRefresh.
      unawaited(ref.read(fcmRegistrationServiceProvider).register());
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await ref.read(fcmRegistrationServiceProvider).stop();
      await ref.read(authRepositoryProvider).logout();
    } finally {
      state = const AsyncData(null);
    }
  }

  Future<void> registerDevice({
    required String fcmToken,
    required String platform,
    required String appVersion,
  }) =>
      ref.read(authRepositoryProvider).registerDevice(
            fcmToken: fcmToken,
            platform: platform,
            appVersion: appVersion,
          );
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, DriverModel?>(AuthController.new);

// Derived: is the user authenticated?
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authControllerProvider).valueOrNull != null;
});
