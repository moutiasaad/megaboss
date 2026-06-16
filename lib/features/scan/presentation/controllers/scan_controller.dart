import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/scan_result_model.dart';
import '../../domain/repositories/scan_repository.dart';
import '../../../shipments/data/models/shipment_model.dart';
import '../../../../core/network/providers.dart';

// Scan session state — tracks the current scan mode and accumulated results.
class ScanState {
  const ScanState({
    this.lastResult,
    this.isProcessing = false,
    this.error,
    this.batchScanned = const [],
    this.requiresCodConfirmation = false,
    this.pendingBarcode,
    this.pendingOpId,
  });

  final ScanResultModel? lastResult;
  final bool isProcessing;
  final Object? error;
  final List<String> batchScanned; // barcodes collected in pickup-rapid mode
  final bool requiresCodConfirmation; // two-phase COD in progress
  final String? pendingBarcode; // barcode waiting for COD confirmation
  final String? pendingOpId;

  ScanState copyWith({
    ScanResultModel? lastResult,
    bool? isProcessing,
    Object? error,
    List<String>? batchScanned,
    bool? requiresCodConfirmation,
    String? pendingBarcode,
    String? pendingOpId,
  }) =>
      ScanState(
        lastResult: lastResult ?? this.lastResult,
        isProcessing: isProcessing ?? this.isProcessing,
        error: error,
        batchScanned: batchScanned ?? this.batchScanned,
        requiresCodConfirmation: requiresCodConfirmation ?? this.requiresCodConfirmation,
        pendingBarcode: pendingBarcode ?? this.pendingBarcode,
        pendingOpId: pendingOpId ?? this.pendingOpId,
      );
}

// ── Delivery scan controller ────────────────────────────────────────────────────

class DeliveryScanController extends Notifier<ScanState> {
  @override
  ScanState build() => const ScanState();

  ScanRepository get _repo => ref.read(scanRepositoryProvider);

  Future<void> scan({
    required String barcode,
    required String status,
    String? comment,
    String? returnType,
    String? rescheduleDate,
    String? signature,
    int? shipmentId,
  }) async {
    state = state.copyWith(isProcessing: true, error: null);
    try {
      final result = await _repo.scanDelivery(
        barcode: barcode,
        status: status,
        comment: comment,
        returnType: returnType,
        rescheduleDate: rescheduleDate,
        signature: signature,
        shipmentId: shipmentId,
      );

      // Phase 1: server needs COD confirmation.
      if (result?.requiresConfirmation == true) {
        state = state.copyWith(
          isProcessing: false,
          requiresCodConfirmation: true,
          pendingBarcode: barcode,
          lastResult: result,
        );
        return;
      }

      state = state.copyWith(
        isProcessing: false,
        lastResult: result,
        requiresCodConfirmation: false,
        pendingBarcode: null,
      );
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: e);
    }
  }

  // Phase 2: confirm COD collection after server requests it.
  Future<void> confirmCod({required bool collected}) async {
    final barcode = state.pendingBarcode;
    if (barcode == null) return;
    state = state.copyWith(isProcessing: true, error: null);
    try {
      final result = await _repo.scanDelivery(
        barcode: barcode,
        status: ShipmentStatus.delivered,
        codCollected: collected,
      );
      state = state.copyWith(
        isProcessing: false,
        lastResult: result,
        requiresCodConfirmation: false,
        pendingBarcode: null,
      );
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: e);
    }
  }

  void reset() => state = const ScanState();
}

final deliveryScanProvider = NotifierProvider<DeliveryScanController, ScanState>(
  DeliveryScanController.new,
);

// ── Pickup rapid (batch) scan controller ───────────────────────────────────────

class BatchScanController extends Notifier<ScanState> {
  @override
  ScanState build() => const ScanState();

  ScanRepository get _repo => ref.read(scanRepositoryProvider);

  // Add a barcode to the batch — idempotent (re-scan ignored).
  void addBarcode(String barcode) {
    if (state.batchScanned.contains(barcode)) return; // idempotent
    state = state.copyWith(
      batchScanned: [...state.batchScanned, barcode],
    );
  }

  // Upload the accumulated batch.
  Future<List<ScanResultModel>> submit() async {
    if (state.batchScanned.isEmpty) return [];
    state = state.copyWith(isProcessing: true, error: null);
    try {
      final items = state.batchScanned
          .map((barcode) => BatchScanItem(
                type: 'pickup',
                barcode: barcode,
                clientOperationId: barcode, // UUID would be better; keep simple for now
              ))
          .toList();
      final results = await _repo.scanBatch(items);
      state = const ScanState(); // reset after submit
      return results;
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: e);
      return [];
    }
  }

  void removeBarcode(String barcode) {
    state = state.copyWith(
      batchScanned: state.batchScanned.where((b) => b != barcode).toList(),
    );
  }

  void reset() => state = const ScanState();
}

final batchScanProvider = NotifierProvider<BatchScanController, ScanState>(
  BatchScanController.new,
);

// Pending offline operations count — shown in header.
final scanPendingCountProvider = StreamProvider<int>((ref) {
  return ref.watch(scanRepositoryProvider).pendingCountStream;
});
