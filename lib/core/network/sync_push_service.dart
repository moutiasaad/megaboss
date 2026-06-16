import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'endpoints.dart';
import 'offline_queue.dart';
import 'sync_operation.dart';

// Replays the offline queue when the network is restored.
// Registered as a singleton via Riverpod; started after login.
//
// Flow:
//   1. connectivity_plus signals connectivity regained
//   2. SyncPushService reads all pending SyncOperations from OfflineQueue
//   3. Sends them in order via POST /driver/sync (idempotent on client_operation_id)
//   4. Marks each as synced and removes it from the queue
//   5. On failure: increments retryCount; drops after SyncOperation.maxRetries
class SyncPushService {
  SyncPushService({
    required ApiClient client,
    required OfflineQueue queue,
    required Connectivity connectivity,
  })  : _client = client,
        _queue = queue,
        _connectivity = connectivity;

  final ApiClient _client;
  final OfflineQueue _queue;
  final Connectivity _connectivity;

  bool _running = false;

  // Call once after login to start listening for connectivity changes.
  void start() {
    _connectivity.onConnectivityChanged.listen((results) {
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (hasNetwork && !_running) {
        _flush();
      }
    });
  }

  // Force a manual sync (called from the Settings screen).
  Future<void> flush() => _flush();

  Future<void> _flush() async {
    if (_running || _queue.isEmpty) return;
    _running = true;

    try {
      final ops = _queue.pending;
      if (ops.isEmpty) return;

      // Send in batches of 50 to stay within server limits.
      final batches = _chunk(ops, 50);
      for (final batch in batches) {
        await _sendBatch(batch);
      }
    } finally {
      _running = false;
      await _queue.removeSynced();
    }
  }

  Future<void> _sendBatch(List<SyncOperation> ops) async {
    try {
      await _client.dio.post<void>(
        Endpoints.syncPush,
        data: {'operations': ops.map((o) => o.toApiPayload()).toList()},
      );
      for (final op in ops) {
        await _queue.markSynced(op.clientOperationId);
      }
    } on DioException catch (e) {
      final mapped = mapDioException(e);
      if (mapped is NetworkException || mapped is TimeoutException) {
        // Network lost again — stop, will retry on next connectivity event.
        return;
      }
      // For server/validation errors increment retry counter per-operation.
      for (final op in ops) {
        await _queue.incrementRetry(op.clientOperationId);
      }
    }
  }

  // GET /driver/sync/pull?since= — pull any server-side changes since last sync
  Future<Map<String, dynamic>?> pull(DateTime since) async {
    try {
      final data = await _client.get<dynamic>(
        Endpoints.syncPull,
        queryParameters: {'since': since.toIso8601String()},
      );
      return data as Map<String, dynamic>?;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  List<List<T>> _chunk<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return chunks;
  }
}
