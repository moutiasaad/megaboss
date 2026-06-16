import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/runsheet_model.dart';
import '../../data/services/runsheet_service.dart';

const _kRunsheetBox = 'mb_runsheets';

// Offline-first runsheet repository.
// Strategy: return cache immediately, then refresh from network.
class RunsheetRepository {
  RunsheetRepository({
    required RunsheetService service,
    required Box<String> box,
  })  : _service = service,
        _box = box;

  final RunsheetService _service;
  final Box<String> _box;

  static Future<Box<String>> openBox() => Hive.openBox<String>(_kRunsheetBox);

  // ── Active runsheet ────────────────────────────────────────────────────────

  RunsheetModel? get cachedActive {
    final raw = _box.get('active');
    if (raw == null) return null;
    try {
      return RunsheetModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<RunsheetModel?> getActive() async {
    final runsheet = await _service.getActive();
    if (runsheet != null) {
      _box.put('active', jsonEncode(runsheet.toJson()));
    } else {
      _box.delete('active');
    }
    return runsheet;
  }

  // ── List ───────────────────────────────────────────────────────────────────

  List<RunsheetModel> cachedList() => cachedListForPeriod('today');

  List<RunsheetModel> cachedListForPeriod(String period) {
    final raw = _box.get('list_$period') ?? _box.get('list');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => RunsheetModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<RunsheetModel>> list({
    int perPage = 20,
    String? from,
    String? to,
    String? status,
    String? period,
    int page = 1,
  }) async {
    final runsheets = await _service.list(
      perPage: perPage,
      from: from,
      to: to,
      status: status,
      period: period,
      page: page,
    );
    if (page == 1) {
      final key = period != null ? 'list_$period' : 'list';
      _box.put(key, jsonEncode(runsheets.map((r) => r.toJson()).toList()));
    }
    return runsheets;
  }

  // ── Detail ─────────────────────────────────────────────────────────────────

  RunsheetModel? cachedDetail(int id) {
    final raw = _box.get('detail_$id');
    if (raw == null) return null;
    try {
      return RunsheetModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<RunsheetModel> show(int id) async {
    final runsheet = await _service.show(id);
    _box.put('detail_$id', jsonEncode(runsheet.toJson()));
    if (runsheet.isActive) {
      _box.put('active', jsonEncode(runsheet.toJson()));
    }
    return runsheet;
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  Future<RunsheetModel> create({
    required int warehouseId,
    String? notes,
  }) async {
    final runsheet = await _service.create(warehouseId: warehouseId, notes: notes);
    _box.put('detail_${runsheet.id}', jsonEncode(runsheet.toJson()));
    _box.put('active', jsonEncode(runsheet.toJson()));
    return runsheet;
  }

  Future<RunsheetModel> close(int id) async {
    final runsheet = await _service.close(id);
    _box.put('detail_$id', jsonEncode(runsheet.toJson()));
    _box.delete('active');
    return runsheet;
  }

  // Optimistic update: update local cache after a scan changes a shipment status.
  void updateShipmentStatusLocally(int runsheetId, int shipmentId, String newStatus) {
    final raw = _box.get('detail_$runsheetId');
    if (raw == null) return;
    try {
      final rs = RunsheetModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      final updated = rs.copyWith(
        shipments: rs.shipments
            .map((s) => s.id == shipmentId ? s.copyWith(status: newStatus) : s)
            .toList(),
      );
      _box.put('detail_$runsheetId', jsonEncode(updated.toJson()));
    } catch (_) {}
  }
}
