import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/notif_entry.dart';
import '../../data/services/notification_service.dart';

const _kNotifBox = 'mb_notifications';
const _kCacheKey = 'notif_list';

class NotificationRepository {
  NotificationRepository({
    required NotificationService service,
    required Box<String> box,
  })  : _service = service,
        _box = box;

  final NotificationService _service;
  final Box<String> _box;

  static Future<Box<String>> openBox() => Hive.openBox<String>(_kNotifBox);

  // ── Cache ──────────────────────────────────────────────────────────────────

  List<NotifEntry> get cached {
    final raw = _box.get(_kCacheKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => NotifEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist(List<NotifEntry> items) =>
      _box.put(_kCacheKey, jsonEncode(items.map((e) => e.toJson()).toList()));

  // ── Fetch ──────────────────────────────────────────────────────────────────

  Future<List<NotifEntry>> fetchAll() async {
    final items = await _service.fetchAll();
    await _persist(items);
    return items;
  }

  // ── Mark read ──────────────────────────────────────────────────────────────

  Future<void> markRead(int id) async {
    // Optimistic cache update; fire-and-forget API call.
    final updated = cached.map((n) => n.id == id ? n.copyWith(read: true) : n).toList();
    await _persist(updated);
    _service.markRead(id).ignore();
  }

  Future<void> markAllRead() async {
    final updated = cached.map((n) => n.copyWith(read: true)).toList();
    await _persist(updated);
    _service.markAllRead().ignore();
  }

  // ── FCM insertion (called from foreground message handler) ─────────────────

  Future<void> insertFcm(NotifEntry entry) async {
    final list = [entry, ...cached];
    await _persist(list);
  }
}
