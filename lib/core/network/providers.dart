import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'api_client.dart';
import 'offline_queue.dart';
import 'sync_push_service.dart';
import '../services/fcm_service.dart';
import '../../features/auth/data/models/driver_model.dart';
import '../../features/auth/data/services/auth_service.dart';
import '../../features/auth/data/services/device_service.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/runsheets/data/services/runsheet_service.dart';
import '../../features/runsheets/domain/repositories/runsheet_repository.dart';
import '../../features/shipments/data/services/shipment_service.dart';
import '../../features/shipments/domain/repositories/shipment_repository.dart';
import '../../features/pickup/data/services/pickup_service.dart';
import '../../features/pickup/domain/repositories/pickup_repository.dart';
import '../../features/scan/data/services/scan_service.dart';
import '../../features/scan/domain/repositories/scan_repository.dart';
import '../../features/calls/data/services/call_service.dart';
import '../../features/calls/domain/repositories/call_repository.dart';
import '../../features/notifications/data/services/notification_service.dart';
import '../../features/notifications/domain/repositories/notification_repository.dart';
import '../../features/stats/data/services/stats_service.dart';
import '../../features/stats/domain/repositories/stats_repository.dart';

// ── Infrastructure ─────────────────────────────────────────────────────────────

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  ),
);

final connectivityProvider = Provider<Connectivity>((_) => Connectivity());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(storage: ref.watch(secureStorageProvider));
});

// OfflineQueue is opened from main() and overridden via ProviderScope overrides.
final offlineQueueProvider = Provider<OfflineQueue>((_) => throw UnimplementedError());

final syncPushServiceProvider = Provider<SyncPushService>((ref) {
  return SyncPushService(
    client: ref.watch(apiClientProvider),
    queue: ref.watch(offlineQueueProvider),
    connectivity: ref.watch(connectivityProvider),
  );
});

// Live count of pending offline operations (drives MbAppHeader badge + Settings).
final pendingOpsCountProvider = StreamProvider<int>((ref) {
  return ref.watch(offlineQueueProvider).pendingCountStream;
});

// ── FCM ───────────────────────────────────────────────────────────────────────

final fcmServiceProvider = Provider<FcmService>(
  (_) => FcmService(FirebaseMessaging.instance),
);

// ── Auth ──────────────────────────────────────────────────────────────────────

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(apiClientProvider)),
);

final deviceServiceProvider = Provider<DeviceService>(
  (ref) => DeviceService(ref.watch(apiClientProvider)),
);

// driverBoxProvider is opened from main() and overridden via ProviderScope.
final driverBoxProvider = Provider<Box<String>>((_) => throw UnimplementedError());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    authService: ref.watch(authServiceProvider),
    deviceService: ref.watch(deviceServiceProvider),
    apiClient: ref.watch(apiClientProvider),
    driverBox: ref.watch(driverBoxProvider),
  );
});

// ── Runsheets ─────────────────────────────────────────────────────────────────

final runsheetServiceProvider = Provider<RunsheetService>(
  (ref) => RunsheetService(ref.watch(apiClientProvider)),
);

final runsheetBoxProvider = Provider<Box<String>>((_) => throw UnimplementedError());

final runsheetRepositoryProvider = Provider<RunsheetRepository>((ref) {
  return RunsheetRepository(
    service: ref.watch(runsheetServiceProvider),
    box: ref.watch(runsheetBoxProvider),
  );
});

// ── Shipments ─────────────────────────────────────────────────────────────────

final shipmentServiceProvider = Provider<ShipmentService>(
  (ref) => ShipmentService(ref.watch(apiClientProvider)),
);

final shipmentBoxProvider = Provider<Box<String>>((_) => throw UnimplementedError());

final shipmentRepositoryProvider = Provider<ShipmentRepository>((ref) {
  return ShipmentRepository(
    service: ref.watch(shipmentServiceProvider),
    box: ref.watch(shipmentBoxProvider),
  );
});

// ── Pickup ────────────────────────────────────────────────────────────────────

final pickupServiceProvider = Provider<PickupService>(
  (ref) => PickupService(ref.watch(apiClientProvider)),
);

final pickupBoxProvider = Provider<Box<String>>((_) => throw UnimplementedError());

final pickupRepositoryProvider = Provider<PickupRepository>((ref) {
  return PickupRepository(
    service: ref.watch(pickupServiceProvider),
    box: ref.watch(pickupBoxProvider),
  );
});

// ── Scan ──────────────────────────────────────────────────────────────────────

final scanServiceProvider = Provider<ScanService>(
  (ref) => ScanService(ref.watch(apiClientProvider)),
);

final scanRepositoryProvider = Provider<ScanRepository>((ref) {
  return ScanRepository(
    scanService: ref.watch(scanServiceProvider),
    shipmentRepo: ref.watch(shipmentRepositoryProvider),
    queue: ref.watch(offlineQueueProvider),
    connectivity: ref.watch(connectivityProvider),
  );
});

// ── Calls ─────────────────────────────────────────────────────────────────────

final callServiceProvider = Provider<CallService>(
  (ref) => CallService(ref.watch(apiClientProvider)),
);

final callBoxProvider = Provider<Box<String>>((_) => throw UnimplementedError());

final callRepositoryProvider = Provider<CallRepository>((ref) {
  return CallRepository(
    service: ref.watch(callServiceProvider),
    box: ref.watch(callBoxProvider),
  );
});

// ── Notifications ─────────────────────────────────────────────────────────────

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(ref.watch(apiClientProvider)),
);

final notificationBoxProvider =
    Provider<Box<String>>((_) => throw UnimplementedError());

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(
    service: ref.watch(notificationServiceProvider),
    box: ref.watch(notificationBoxProvider),
  );
});

// ── Stats ─────────────────────────────────────────────────────────────────────

final statsServiceProvider = Provider<StatsService>(
  (ref) => StatsService(ref.watch(apiClientProvider)),
);

final statsBoxProvider = Provider<Box<String>>((_) => throw UnimplementedError());

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return StatsRepository(
    service: ref.watch(statsServiceProvider),
    box: ref.watch(statsBoxProvider),
  );
});

// ── Convenience: current driver from cache ─────────────────────────────────────

final currentDriverProvider = Provider<DriverModel?>((ref) {
  return ref.watch(authRepositoryProvider).cachedDriver;
});
