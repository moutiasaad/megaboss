import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/shipment_model.dart';
import '../../data/services/shipment_service.dart';
import '../../../calls/data/models/call_log_model.dart';

const _kShipmentBox = 'mb_shipments';

// Offline-first shipment repository.
// Write operations (status updates) go through the offline queue in ScanRepository
// when offline; this repository is for reads and online-only writes.
class ShipmentRepository {
  ShipmentRepository({
    required ShipmentService service,
    required Box<String> box,
  })  : _service = service,
        _box = box;

  final ShipmentService _service;
  final Box<String> _box;

  static Future<Box<String>> openBox() => Hive.openBox<String>(_kShipmentBox);

  // ── Detail ─────────────────────────────────────────────────────────────────

  ShipmentModel? cached(int id) {
    final raw = _box.get('$id');
    if (raw == null) return null;
    try {
      return ShipmentModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<ShipmentModel> show(int id) async {
    final shipment = await _service.show(id);
    _box.put('$id', jsonEncode(shipment.toJson()));
    return shipment;
  }

  // ── Status update (online path) ───────────────────────────────────────────

  Future<ShipmentModel> updateStatus(
    int id, {
    required String status,
    String? comment,
    String? returnType,
    String? rescheduleDate,
  }) async {
    final shipment = await _service.updateStatus(
      id,
      status: status,
      comment: comment,
      returnType: returnType,
      rescheduleDate: rescheduleDate,
    );
    _box.put('$id', jsonEncode(shipment.toJson()));
    return shipment;
  }

  // Optimistic local update when offline (before queue replay confirms it).
  void updateStatusLocally(int id, String newStatus) {
    final raw = _box.get('$id');
    if (raw == null) return;
    try {
      final s = ShipmentModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _box.put('$id', jsonEncode(s.copyWith(status: newStatus).toJson()));
    } catch (_) {}
  }

  // ── Calls ──────────────────────────────────────────────────────────────────

  List<CallLogModel> cachedCalls(int shipmentId) {
    final raw = _box.get('calls_$shipmentId');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => CallLogModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<CallLogModel>> calls(int shipmentId) async {
    final list = await _service.calls(shipmentId);
    _box.put(
      'calls_$shipmentId',
      jsonEncode(list.map((c) => c.toJson()).toList()),
    );
    return list;
  }
}
