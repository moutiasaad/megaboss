import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/pickup_model.dart';
import '../../../../core/network/providers.dart';

class PickupDetailController
    extends AutoDisposeFamilyAsyncNotifier<PickupModel, int> {
  @override
  Future<PickupModel> build(int arg) async {
    final repo = ref.read(pickupRepositoryProvider);
    final cached = repo.cached(arg);
    if (cached != null) {
      Future.microtask(_backgroundRefresh);
      return cached;
    }
    return repo.show(arg);
  }

  Future<void> _backgroundRefresh() async {
    try {
      final fresh = await ref.read(pickupRepositoryProvider).show(arg);
      state = AsyncData(fresh);
    } catch (_) {}
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(pickupRepositoryProvider).show(arg),
    );
  }

  Future<void> accept(int shipmentId) async {
    final previous = state.valueOrNull;
    _applyShipmentUpdate(
      shipmentId,
      PickupShipmentStatus.collected,
      collectedAt: DateTime.now(),
    );
    try {
      await ref.read(pickupRepositoryProvider).accept(arg, shipmentId);
    } catch (_) {
      if (previous != null) state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> refuse(int shipmentId, {required String reason}) async {
    final previous = state.valueOrNull;
    _applyShipmentUpdate(
      shipmentId,
      PickupShipmentStatus.refused,
      refuseReason: reason,
    );
    try {
      await ref
          .read(pickupRepositoryProvider)
          .refuse(arg, shipmentId, comment: reason);
    } catch (_) {
      if (previous != null) state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> close() async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(status: PickupStatus.completed));
    try {
      await ref.read(pickupRepositoryProvider).close(arg);
    } catch (_) {
      state = AsyncData(current);
    }
  }

  void _applyShipmentUpdate(
    int shipmentId,
    String newStatus, {
    DateTime? collectedAt,
    String? refuseReason,
  }) {
    final current = state.valueOrNull;
    if (current == null) return;
    final updatedShipments = current.shipments
        .map((s) => s.id == shipmentId
            ? s.copyWith(
                status: newStatus,
                collectedAt: collectedAt,
                refuseReason: refuseReason,
              )
            : s)
        .toList();
    final collected = updatedShipments
        .where((s) => s.status == PickupShipmentStatus.collected)
        .length;
    state = AsyncData(current.copyWith(
      shipments: updatedShipments,
      collectedCount: collected,
    ));
  }
}

final pickupDetailProvider = AsyncNotifierProvider.autoDispose
    .family<PickupDetailController, PickupModel, int>(
  PickupDetailController.new,
);
