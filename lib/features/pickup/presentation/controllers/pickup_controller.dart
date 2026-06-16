import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/pickup_model.dart';
import '../../../../core/network/providers.dart';

// ── Active pickup list ─────────────────────────────────────────────────────────

class ActivePickupsController extends AsyncNotifier<List<PickupModel>> {
  @override
  Future<List<PickupModel>> build() async {
    final repo = ref.watch(pickupRepositoryProvider);
    final cached = repo.cachedActive;
    if (cached.isNotEmpty) {
      Future.microtask(() async {
        try {
          final fresh = await repo.getActive();
          state = AsyncData(fresh);
        } catch (_) {}
      });
      return cached;
    }
    return repo.getActive();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(pickupRepositoryProvider).getActive(),
    );
  }
}

final activePickupsProvider =
    AsyncNotifierProvider<ActivePickupsController, List<PickupModel>>(
  ActivePickupsController.new,
);

// ── Pickup / manifest detail ───────────────────────────────────────────────────

class PickupDetailController
    extends AutoDisposeFamilyAsyncNotifier<PickupModel, int> {
  @override
  Future<PickupModel> build(int id) async {
    final repo = ref.watch(pickupRepositoryProvider);
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
      () => ref.read(pickupRepositoryProvider).show(arg),
    );
  }

  // Optimistic accept — updates local cache instantly.
  Future<void> acceptShipment(int shipmentId) async {
    // Optimistic UI: update state before awaiting the network call.
    final current = state.valueOrNull;
    if (current != null) {
      final updated = current.copyWith(
        shipments: current.shipments
            .map((s) => s.id == shipmentId
                ? s.copyWith(status: PickupShipmentStatus.collected)
                : s)
            .toList(),
        collectedCount: current.collectedCount + 1,
      );
      state = AsyncData(updated);
    }
    try {
      await ref.read(pickupRepositoryProvider).accept(arg, shipmentId);
    } catch (e, st) {
      // Rollback on error.
      state = AsyncError(e, st);
      ref.invalidateSelf();
    }
  }

  Future<void> refuseShipment(int shipmentId, {String? comment}) async {
    final current = state.valueOrNull;
    if (current != null) {
      final updated = current.copyWith(
        shipments: current.shipments
            .map((s) => s.id == shipmentId
                ? s.copyWith(status: PickupShipmentStatus.refused)
                : s)
            .toList(),
      );
      state = AsyncData(updated);
    }
    try {
      await ref.read(pickupRepositoryProvider).refuse(arg, shipmentId, comment: comment);
    } catch (e, st) {
      state = AsyncError(e, st);
      ref.invalidateSelf();
    }
  }
}

final pickupDetailProvider = AsyncNotifierProvider.autoDispose
    .family<PickupDetailController, PickupModel, int>(
  PickupDetailController.new,
);
