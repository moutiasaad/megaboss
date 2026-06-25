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

  // Fetches /driver/pickups/active and returns a merged list: server active
  // pickups + locally-cached "done" pickups that the server no longer returns.
  // The server has no list-all endpoint, so completed manifests would otherwise
  // disappear from the list the moment they finish.
  Future<List<PickupModel>> getActive() async {
    final fresh = await _service.getActive();
    final freshIds = fresh.map((p) => p.id).toSet();
    final keptDone = cachedList
        .where((p) => _isDone(p) && !freshIds.contains(p.id))
        .toList();
    final merged = [...fresh, ...keptDone];

    _box.put('active', jsonEncode(fresh.map((p) => p.toJson()).toList()));
    _box.put('list', jsonEncode(merged.map((p) => p.toJson()).toList()));
    return merged;
  }

  // ── Merged list (active + cached done) ────────────────────────────────────

  List<PickupModel> get cachedList {
    final raw = _box.get('list');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => PickupModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static bool _isDone(PickupModel p) {
    if (p.totalShipments > 0 && p.collectedCount >= p.totalShipments) {
      return true;
    }
    final s = p.status.toLowerCase();
    return s == 'completed' || s == 'closed' || s == 'done' || s == 'collected';
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
      _syncListCaches(id, status: PickupStatus.completed);
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
      _syncListCaches(manifestId, collectedCount: collected);
    } catch (_) {}
  }

  // Keep 'list' + 'active' cache entries in sync with per-manifest cache so the
  // pickups list reflects detail-screen actions immediately on return.
  void _syncListCaches(int manifestId, {int? collectedCount, String? status}) {
    for (final key in const ['list', 'active']) {
      final raw = _box.get(key);
      if (raw == null) continue;
      try {
        final list = (jsonDecode(raw) as List<dynamic>)
            .map((e) => PickupModel.fromJson(e as Map<String, dynamic>))
            .toList();
        final updated = list
            .map((p) => p.id == manifestId
                ? p.copyWith(
                    collectedCount: collectedCount,
                    status: status,
                  )
                : p)
            .toList();
        _box.put(key, jsonEncode(updated.map((p) => p.toJson()).toList()));
      } catch (_) {}
    }
  }
}
