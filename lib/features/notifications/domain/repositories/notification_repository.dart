import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/notif_entry.dart';
import '../../data/services/notification_service.dart';

const _kNotifBox = 'mb_notifications';
const _kCacheKey = 'notif_list';
const _kUnreadKey = 'notif_unread_count';

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

  int get cachedUnread => int.tryParse(_box.get(_kUnreadKey) ?? '') ?? 0;

  Future<void> _persistItems(List<NotifEntry> items) => _box.put(
        _kCacheKey,
        jsonEncode(items.map((e) => e.toJson()).toList()),
      );

  Future<void> _persistUnread(int n) => _box.put(_kUnreadKey, n.toString());

  // ── Fetch ──────────────────────────────────────────────────────────────────

  // First page — replaces the cache.
  Future<NotifPage> fetchFirstPage({int perPage = 20}) async {
    final page = await _service.fetchPage(page: 1, perPage: perPage);
    await _persistItems(page.items);
    return page;
  }

  // Subsequent pages — caller is expected to merge into state.
  Future<NotifPage> fetchPage(int page, {int perPage = 20}) =>
      _service.fetchPage(page: page, perPage: perPage);

  // ── Unread count ───────────────────────────────────────────────────────────

  Future<int> fetchUnreadCount() async {
    final n = await _service.unreadCount();
    await _persistUnread(n);
    return n;
  }

  // ── Mark read ──────────────────────────────────────────────────────────────

  // Optimistic — updates cache + decrements unread count immediately, then
  // fires the API call. Returns the server-confirmed entry (if any).
  Future<NotifEntry?> markRead(int id) async {
    final list = cached;
    final wasUnread = list.any((n) => n.id == id && !n.read);
    final updated =
        list.map((n) => n.id == id ? n.copyWith(read: true) : n).toList();
    await _persistItems(updated);
    if (wasUnread) {
      await _persistUnread((cachedUnread - 1).clamp(0, 1 << 31));
    }
    try {
      return await _service.markRead(id);
    } catch (_) {
      return null;
    }
  }

  // Returns the count of newly-marked notifications (server `marked` field).
  Future<int> markAllRead() async {
    final updated = cached.map((n) => n.copyWith(read: true)).toList();
    await _persistItems(updated);
    await _persistUnread(0);
    try {
      return await _service.markAllRead();
    } catch (_) {
      return 0;
    }
  }

  // ── FCM insertion (called from foreground message handler) ─────────────────

  Future<void> insertFcm(NotifEntry entry) async {
    final list = [entry, ...cached];
    await _persistItems(list);
    if (!entry.read) await _persistUnread(cachedUnread + 1);
  }
}
