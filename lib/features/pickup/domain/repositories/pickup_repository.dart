import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/pickup_model.dart';
import '../../data/services/pickup_service.dart';

const _kPickupBox = 'mb_pickups';

// Offline-first pickup repository.
// Accept/refuse actions are applied optimistically to the local cache.
class PickupRepository {
  PickupRepository({
    required PickupService service,
    required Box<String> box,
  })  : _service = service,
        _box = box;

  final PickupService _service;
  final Box<String> _box;

  static Future<Box<String>> openBox() => Hive.openBox<String>(_kPickupBox);

  // ── Active list ────────────────────────────────────────────────────────────

  List<PickupModel> get cachedActive {
    final raw = _box.get('active');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => PickupModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<PickupModel>> getActive() async {
    final pickups = await _service.getActive();
    _box.put('active', jsonEncode(pickups.map((p) => p.toJson()).toList()));
    return pickups;
  }

  // ── Detail ─────────────────────────────────────────────────────────────────

  PickupModel? cached(int id) {
    final raw = _box.get('$id');
    if (raw == null) return null;
    try {
      return PickupModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<PickupModel> show(int id) async {
    final pickup = await _service.show(id);
    _box.put('$id', jsonEncode(pickup.toJson()));
    return pickup;
  }

  // ── Accept / Refuse (optimistic) ───────────────────────────────────────────

  Future<PickupShipmentModel> accept(int manifestId, int shipmentId) async {
    final result = await _service.accept(manifestId, shipmentId);
    _updateShipmentLocally(manifestId, shipmentId, PickupShipmentStatus.collected);
    return result;
  }

  Future<void> close(int id) async {
    await _service.close(id);
    final raw = _box.get('$id');
    if (raw == null) return;
    try {
      final pickup = PickupModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _box.put('$id', jsonEncode(pickup.copyWith(status: PickupStatus.completed).toJson()));
    } catch (_) {}
  }

  Future<PickupShipmentModel> refuse(
    int manifestId,
    int shipmentId, {
    String? comment,
  }) async {
    final result = await _service.refuse(manifestId, shipmentId, comment: comment);
    _updateShipmentLocally(manifestId, shipmentId, PickupShipmentStatus.refused);
    return result;
  }

  // Optimistic update for offline accept/refuse actions.
  void acceptLocally(int manifestId, int shipmentId) =>
      _updateShipmentLocally(manifestId, shipmentId, PickupShipmentStatus.collected);

  void refuseLocally(int manifestId, int shipmentId) =>
      _updateShipmentLocally(manifestId, shipmentId, PickupShipmentStatus.refused);

  void _updateShipmentLocally(int manifestId, int shipmentId, String newStatus) {
    final raw = _box.get('$manifestId');
    if (raw == null) return;
    try {
      final pickup = PickupModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      final updatedShipments = pickup.shipments
          .map((s) => s.id == shipmentId ? s.copyWith(status: newStatus) : s)
          .toList();
      final collected =
          updatedShipments.where((s) => s.status == PickupShipmentStatus.collected).length;
      final updated = pickup.copyWith(
        shipments: updatedShipments,
        collectedCount: collected,
      );
      _box.put('$manifestId', jsonEncode(updated.toJson()));
    } catch (_) {}
  }
}
