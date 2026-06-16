import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/shipment_model.dart';
import '../../../calls/data/models/call_log_model.dart';
import '../../../../core/network/providers.dart';

// ── Shipment detail ────────────────────────────────────────────────────────────

class ShipmentDetailController
    extends AutoDisposeFamilyAsyncNotifier<ShipmentModel, int> {
  @override
  Future<ShipmentModel> build(int id) async {
    final repo = ref.watch(shipmentRepositoryProvider);
    final cached = repo.cached(id);
    if (cached != null) {
      Future.microtask(() async {
        try {
          final fresh = await repo.show(id);
          state = AsyncData(fresh);
        } catch (_) {}
      });
      return cached;
    }
    return repo.show(id);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(shipmentRepositoryProvider).show(arg),
    );
  }

  // Online-only status update (offline path goes through ScanRepository).
  Future<void> updateStatus(
    String status, {
    String? comment,
    String? returnType,
    String? rescheduleDate,
  }) async {
    state = await AsyncValue.guard(
      () => ref.read(shipmentRepositoryProvider).updateStatus(
            arg,
            status: status,
            comment: comment,
            returnType: returnType,
            rescheduleDate: rescheduleDate,
          ),
    );
  }
}

final shipmentDetailProvider = AsyncNotifierProvider.autoDispose
    .family<ShipmentDetailController, ShipmentModel, int>(
  ShipmentDetailController.new,
);

// ── Calls for a shipment ───────────────────────────────────────────────────────

class ShipmentCallsController
    extends AutoDisposeFamilyAsyncNotifier<List<CallLogModel>, int> {
  @override
  Future<List<CallLogModel>> build(int shipmentId) async {
    final repo = ref.watch(shipmentRepositoryProvider);
    final cached = repo.cachedCalls(shipmentId);
    if (cached.isNotEmpty) {
      Future.microtask(() async {
        try {
          final fresh = await repo.calls(shipmentId);
          state = AsyncData(fresh);
        } catch (_) {}
      });
      return cached;
    }
    return repo.calls(shipmentId);
  }
}

final shipmentCallsProvider = AsyncNotifierProvider.autoDispose
    .family<ShipmentCallsController, List<CallLogModel>, int>(
  ShipmentCallsController.new,
);
