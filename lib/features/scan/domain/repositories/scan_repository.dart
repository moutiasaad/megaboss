import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/scan_result_model.dart';
import '../../data/services/scan_service.dart';
import '../../../../core/network/offline_queue.dart';
import '../../../../core/network/sync_operation.dart';
import '../../../shipments/data/models/shipment_model.dart';
import '../../../shipments/domain/repositories/shipment_repository.dart';

// Scan repository — the critical offline-first layer for terrain actions.
//
// Every scan is:
//   1. Optimistically applied to the shipment cache (UI updates instantly).
//   2. Sent to the API if online; queued in Hive if offline.
//   3. Idempotent via clientOperationId (UUID v4).
class ScanRepository {
  ScanRepository({
    required ScanService scanService,
    required ShipmentRepository shipmentRepo,
    required OfflineQueue queue,
    required Connectivity connectivity,
  })  : _scanService = scanService,
        _shipmentRepo = shipmentRepo,
        _queue = queue,
        _connectivity = connectivity;

  final ScanService _scanService;
  final ShipmentRepository _shipmentRepo;
  final OfflineQueue _queue;
  final Connectivity _connectivity;

  static const _uuid = Uuid();

  // ── Delivery scan ──────────────────────────────────────────────────────────

  Future<ScanResultModel?> scanDelivery({
    required String barcode,
    required String status,
    String? comment,
    String? returnType,
    String? rescheduleDate,
    String? signature,
    bool? codCollected,
    int? shipmentId, // for optimistic local update
  }) async {
    final opId = _uuid.v4();

    // Optimistic update
    if (shipmentId != null) {
      _shipmentRepo.updateStatusLocally(shipmentId, status);
    }

    final online = await _isOnline();
    if (online) {
      final result = await _scanService.scanDelivery(
        barcode: barcode,
        status: status,
        clientOperationId: opId,
        comment: comment,
        returnType: returnType,
        rescheduleDate: rescheduleDate,
        signature: signature,
        codCollected: codCollected,
      );
      return result;
    } else {
      await _queue.enqueue(SyncOperation(
        clientOperationId: opId,
        type: SyncOperationType.scanDelivery,
        payload: {
          'barcode': barcode,
          'status': status,
          if (comment != null) 'comment': comment,
          if (returnType != null) 'return_type': returnType,
          if (rescheduleDate != null) 'reschedule_date': rescheduleDate,
          if (codCollected != null) 'cod_collected': codCollected,
        },
        clientTimestamp: DateTime.now().toUtc(),
      ));
      return null; // UI reads the optimistic state from cache
    }
  }

  // ── Pickup scan ────────────────────────────────────────────────────────────

  Future<ScanResultModel?> scanPickup({required String barcode}) async {
    final opId = _uuid.v4();
    final online = await _isOnline();

    if (online) {
      return _scanService.scanPickup(
        barcode: barcode,
        clientOperationId: opId,
      );
    } else {
      await _queue.enqueue(SyncOperation(
        clientOperationId: opId,
        type: SyncOperationType.scanPickup,
        payload: {'barcode': barcode},
        clientTimestamp: DateTime.now().toUtc(),
      ));
      return null;
    }
  }

  // ── Batch scan (Pickup Rapide) ─────────────────────────────────────────────
  //
  // Returns (results, queuedOffline):
  //   queuedOffline=false → online path, results is whatever the API returned.
  //   queuedOffline=true  → offline path, every item was enqueued to Hive.

  Future<({List<ScanResultModel> results, bool queuedOffline})> scanBatch(
      List<BatchScanItem> items) async {
    final online = await _isOnline();
    if (online) {
      final List<ScanResultModel> results = await _scanService.scanBatch(items);
      return (results: results, queuedOffline: false);
    } else {
      for (final item in items) {
        await _queue.enqueue(SyncOperation(
          clientOperationId: item.clientOperationId,
          type: item.type == 'pickup'
              ? SyncOperationType.scanPickup
              : SyncOperationType.scanDelivery,
          payload: item.toJson(),
          clientTimestamp: DateTime.now().toUtc(),
        ));
      }
      return (results: <ScanResultModel>[], queuedOffline: true);
    }
  }

  // ── Barcode validation (Phase 1 — online only, no local update) ───────────

  // Sends barcode to the server with cod_collected=null to get shipment data
  // without committing any delivery. Returns null on any error or if offline.
  Future<ScanResultModel?> lookupByBarcode(String barcode) async {
    final opId = _uuid.v4();
    try {
      return await _scanService.scanDelivery(
        barcode: barcode,
        status: ShipmentStatus.delivered,
        clientOperationId: opId,
        codCollected: null,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  int get pendingCount => _queue.pendingCount;
  Stream<int> get pendingCountStream => _queue.pendingCountStream;

  Future<bool> _isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}
