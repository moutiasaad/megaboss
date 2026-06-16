import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'sync_operation.dart';

const _kQueueBox = 'mb_offline_queue';

// Hive-backed FIFO queue for offline operations.
// All terrain write actions (scan, status update, call log) are stored here
// when the device is offline and replayed by SyncService on reconnect.
class OfflineQueue {
  OfflineQueue(this._box);

  final Box<String> _box;

  static Future<OfflineQueue> open() async {
    final box = await Hive.openBox<String>(_kQueueBox);
    return OfflineQueue(box);
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  Future<void> enqueue(SyncOperation op) async {
    await _box.put(op.clientOperationId, jsonEncode(op.toJson()));
  }

  Future<void> markSynced(String clientOperationId) async {
    final raw = _box.get(clientOperationId);
    if (raw == null) return;
    final op = SyncOperation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    await _box.put(clientOperationId, jsonEncode(op.copyWith(synced: true).toJson()));
  }

  Future<void> incrementRetry(String clientOperationId) async {
    final raw = _box.get(clientOperationId);
    if (raw == null) return;
    final op = SyncOperation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    final updated = op.copyWith(retryCount: op.retryCount + 1);
    if (updated.retryCount >= SyncOperation.maxRetries) {
      await _box.delete(clientOperationId);
    } else {
      await _box.put(clientOperationId, jsonEncode(updated.toJson()));
    }
  }

  Future<void> removeSynced() async {
    final toDelete = pending.where((op) => op.synced).map((op) => op.clientOperationId);
    for (final id in toDelete) {
      await _box.delete(id);
    }
  }

  Future<void> clear() => _box.clear();

  // ── Read ───────────────────────────────────────────────────────────────────

  List<SyncOperation> get pending {
    return _box.values
        .map((raw) {
          try {
            final op = SyncOperation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
            return op.synced ? null : op;
          } catch (_) {
            return null;
          }
        })
        .whereType<SyncOperation>()
        .toList();
  }

  int get pendingCount => pending.length;

  bool get isEmpty => pendingCount == 0;
  bool get isNotEmpty => !isEmpty;

  // ── Listenable ─────────────────────────────────────────────────────────────

  // Watch for changes (used by MbAppHeader to show the pending count banner).
  Stream<int> get pendingCountStream => _box.watch().map((_) => pendingCount);
}
