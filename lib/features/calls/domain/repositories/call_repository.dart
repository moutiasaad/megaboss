import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/call_entry.dart';
import '../../data/models/call_log_model.dart';
import '../../data/services/call_service.dart';

const _kCallBox = 'mb_calls';

// Call log repository.
// Stores logs locally; syncs unsent logs on reconnect.
class CallRepository {
  CallRepository({
    required CallService service,
    required Box<String> box,
  })  : _service = service,
        _box = box;

  final CallService _service;
  final Box<String> _box;

  static Future<Box<String>> openBox() => Hive.openBox<String>(_kCallBox);

  // ── Local buffer ───────────────────────────────────────────────────────────

  // Add a call log to the local buffer (before syncing).
  Future<void> bufferCallLog(CallLogModel log) async {
    _box.put(log.rawLogId, jsonEncode(log.toJson()));
  }

  List<CallLogModel> get unsynced {
    return _box.values
        .where((raw) {
          try {
            final map = jsonDecode(raw) as Map<String, dynamic>;
            return map['synced'] != true;
          } catch (_) {
            return false;
          }
        })
        .map((raw) {
          try {
            return CallLogModel.fromJson(
                jsonDecode(raw) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<CallLogModel>()
        .toList();
  }

  // ── Sync ───────────────────────────────────────────────────────────────────

  Future<void> syncPending() async {
    final pending = unsynced;
    if (pending.isEmpty) return;
    await _service.syncCallLogs(pending);
    for (final log in pending) {
      final raw = _box.get(log.rawLogId);
      if (raw != null) {
        final map = Map<String, dynamic>.from(
            jsonDecode(raw) as Map<String, dynamic>);
        map['synced'] = true;
        _box.put(log.rawLogId, jsonEncode(map));
      }
    }
  }

  // ── History (calls screen) ─────────────────────────────────────────────────

  List<CallEntry> cachedHistory(String filter) {
    final raw = _box.get('history_$filter');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => CallEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<CallEntry>> fetchHistory({String filter = 'all'}) async {
    final list = await _service.getHistory(filter: filter);
    _box.put(
        'history_$filter', jsonEncode(list.map((e) => e.toJson()).toList()));
    return list;
  }

  // ── Stats ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> stats({String period = 'day'}) =>
      _service.stats(period: period);

  // ── Shipment calls ─────────────────────────────────────────────────────────

  List<CallLogModel> cachedForShipment(int shipmentId) {
    final raw = _box.get('ship_$shipmentId');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => CallLogModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<CallLogModel>> forShipment(int shipmentId) async {
    final list = await _service.forShipment(shipmentId);
    _box.put('ship_$shipmentId',
        jsonEncode(list.map((c) => c.toJson()).toList()));
    return list;
  }
}
