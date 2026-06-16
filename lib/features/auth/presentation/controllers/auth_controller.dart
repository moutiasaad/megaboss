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
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<void> logout() async {
    try {
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
