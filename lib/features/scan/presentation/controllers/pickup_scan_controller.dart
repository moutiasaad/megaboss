import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/network/providers.dart';
import '../../../../core/network/sync_operation.dart';
import '../../data/models/scan_result_model.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class ScanBatchState {
  const ScanBatchState({
    this.scanned = const [],
    this.sending = false,
    this.sentOffline = false,
    this.isOffline = false,
    this.persistedOpIds = const <String, String>{},
  });

  final List<String> scanned;  // unique barcodes, most recent first
  final bool sending;
  final bool sentOffline;
  final bool isOffline;
  // barcode → clientOperationId of the Hive entry (set as soon as scanned offline)
  final Map<String, String> persistedOpIds;

  int get count => scanned.length;
  bool get canSend => scanned.isNotEmpty && !sending;

  // Barcodes already safe in Hive — will be sent by SyncPushService on reconnect
  Set<String> get _persisted => persistedOpIds.keys.toSet();

  ScanBatchState copyWith({
    List<String>? scanned,
    bool? sending,
    bool? sentOffline,
    bool? isOffline,
    Map<String, String>? persistedOpIds,
  }) =>
      ScanBatchState(
        scanned: scanned ?? this.scanned,
        sending: sending ?? this.sending,
        sentOffline: sentOffline ?? this.sentOffline,
        isOffline: isOffline ?? this.isOffline,
        persistedOpIds: persistedOpIds ?? this.persistedOpIds,
      );
}

// ─── Controller ───────────────────────────────────────────────────────────────

class PickupScanController
    extends AutoDisposeFamilyNotifier<ScanBatchState, int> {
  static const _uuid = Uuid();

  @override
  ScanBatchState build(int arg) {
    _watchConnectivity();
    return const ScanBatchState();
  }

  // ── Connectivity ────────────────────────────────────────────────────────────

  void _watchConnectivity() async {
    final conn = ref.read(connectivityProvider);
    // Initial state
    try {
      final initial = await conn.checkConnectivity();
      _applyConnectivity(initial);
    } catch (_) {}
    // Ongoing changes
    final sub = conn.onConnectivityChanged.listen(_applyConnectivity);
    ref.onDispose(sub.cancel);
  }

  void _applyConnectivity(List<ConnectivityResult> results) {
    final isOnline = results.any((r) => r != ConnectivityResult.none);
    if (state.isOffline == !isOnline) return;
    state = state.copyWith(isOffline: !isOnline);
  }

  // ── Scan actions ────────────────────────────────────────────────────────────

  // Returns true if added (new), false if already scanned (duplicate).
  bool add(String barcode) {
    if (state.scanned.contains(barcode)) return false;
    state = state.copyWith(scanned: [barcode, ...state.scanned]);
    // Offline: persist immediately so the scan survives app close / crashes.
    if (state.isOffline) _persistNow(barcode);
    return true;
  }

  // Immediately writes barcode to Hive (fire-and-forget).
  // Updates state.persistedOpIds once enqueue completes.
  void _persistNow(String barcode) {
    final opId = _uuid.v4();
    ref
        .read(offlineQueueProvider)
        .enqueue(SyncOperation(
          clientOperationId: opId,
          type: SyncOperationType.scanPickup,
          payload: {'barcode': barcode},
          clientTimestamp: DateTime.now().toUtc(),
        ))
        .then((_) {
      // Guard: barcode might have been removed before persist completed
      if (state.scanned.contains(barcode) &&
          !state.persistedOpIds.containsKey(barcode)) {
        state = state.copyWith(
          persistedOpIds: {...state.persistedOpIds, barcode: opId},
        );
      }
    });
  }

  void remove(String barcode) {
    // If queued to Hive, mark it synced so SyncPushService skips it
    final opId = state.persistedOpIds[barcode];
    if (opId != null) {
      ref.read(offlineQueueProvider).markSynced(opId);
    }
    final updatedOpIds = Map<String, String>.from(state.persistedOpIds)
      ..remove(barcode);
    state = state.copyWith(
      scanned: state.scanned.where((b) => b != barcode).toList(),
      persistedOpIds: updatedOpIds,
    );
  }

  // Queue all in-memory (non-persisted) barcodes into Hive.
  // Call this when the user closes the screen while offline to avoid data loss.
  Future<void> persistAll() async {
    final queue = ref.read(offlineQueueProvider);
    final unpersisted =
        state.scanned.where((b) => !state.persistedOpIds.containsKey(b)).toList();
    for (final barcode in unpersisted) {
      final opId = _uuid.v4();
      await queue.enqueue(SyncOperation(
        clientOperationId: opId,
        type: SyncOperationType.scanPickup,
        payload: {'barcode': barcode},
        clientTimestamp: DateTime.now().toUtc(),
      ));
      state = state.copyWith(
        persistedOpIds: {...state.persistedOpIds, barcode: opId},
      );
    }
  }

  // Returns true on success (online or queued). Throws on hard error.
  Future<bool> sendBatch() async {
    if (!state.canSend) return false;
    state = state.copyWith(sending: true);

    // Skip barcodes already safe in Hive — SyncPushService will send them.
    final persisted = state._persisted;
    final items = state.scanned.reversed
        .where((b) => !persisted.contains(b))
        .map((b) => BatchScanItem(
              type: 'pickup',
              barcode: b,
              clientOperationId: _uuid.v4(),
              scannedAt: DateTime.now().toUtc().toIso8601String(),
            ))
        .toList();

    // All barcodes already individually queued → nothing to batch-send.
    if (items.isEmpty && persisted.isNotEmpty) {
      state = state.copyWith(sending: false, sentOffline: true);
      return true;
    }

    try {
      final results =
          await ref.read(scanRepositoryProvider).scanBatch(items);
      // Empty results = offline (new items were also individually queued by scanBatch).
      final offline = results.isEmpty && items.isNotEmpty;
      state = state.copyWith(
        sending: false,
        sentOffline: offline || persisted.isNotEmpty,
      );
      return true;
    } catch (e) {
      state = state.copyWith(sending: false);
      rethrow;
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final pickupScanProvider = NotifierProvider.autoDispose
    .family<PickupScanController, ScanBatchState, int>(
  PickupScanController.new,
);
