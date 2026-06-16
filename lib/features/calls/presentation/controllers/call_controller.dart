import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/call_log_model.dart';
import '../../../../core/network/providers.dart';

// ── Call stats ────────────────────────────────────────────────────────────────

class CallStatsController
    extends AutoDisposeFamilyAsyncNotifier<Map<String, dynamic>, String> {
  @override
  Future<Map<String, dynamic>> build(String period) async {
    return ref.read(callRepositoryProvider).stats(period: period);
  }
}

final callStatsProvider = AsyncNotifierProvider.autoDispose
    .family<CallStatsController, Map<String, dynamic>, String>(
  CallStatsController.new,
);

// ── Calls for a shipment ───────────────────────────────────────────────────────

class ShipmentCallHistoryController
    extends AutoDisposeFamilyAsyncNotifier<List<CallLogModel>, int> {
  @override
  Future<List<CallLogModel>> build(int shipmentId) async {
    final repo = ref.watch(callRepositoryProvider);
    final cached = repo.cachedForShipment(shipmentId);
    if (cached.isNotEmpty) {
      Future.microtask(() async {
        try {
          final fresh = await repo.forShipment(shipmentId);
          state = AsyncData(fresh);
        } catch (_) {}
      });
      return cached;
    }
    return repo.forShipment(shipmentId);
  }
}

final shipmentCallHistoryProvider = AsyncNotifierProvider.autoDispose
    .family<ShipmentCallHistoryController, List<CallLogModel>, int>(
  ShipmentCallHistoryController.new,
);

// ── Sync pending call logs ─────────────────────────────────────────────────────

final syncCallLogsProvider = FutureProvider.autoDispose<void>(
  (ref) => ref.read(callRepositoryProvider).syncPending(),
);

// ── Buffer a call log locally (called from native call detection) ───────────────

final bufferCallLogProvider =
    FutureProvider.autoDispose.family<void, CallLogModel>(
  (ref, log) => ref.read(callRepositoryProvider).bufferCallLog(log),
);
