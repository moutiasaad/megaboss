import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/notif_entry.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/providers.dart';

class NotificationsController extends AsyncNotifier<NotifState> {
  @override
  Future<NotifState> build() async {
    final repo = ref.read(notificationRepositoryProvider);
    final cached = repo.cached;

    if (cached.isNotEmpty) {
      // Serve cache instantly; refresh silently in background.
      Future.microtask(() async {
        try {
          final fresh = await repo.fetchAll();
          state = AsyncData(_toState(fresh, offline: false));
        } catch (_) {}
      });
      return _toState(cached, offline: true);
    }

    // No cache — attempt API fetch; degrade gracefully when endpoint is absent.
    try {
      final items = await repo.fetchAll();
      return _toState(items);
    } on NotFoundException {
      // Endpoint not yet deployed — show empty state.
      return const NotifState(items: [], unread: 0);
    } on NetworkException {
      return const NotifState(items: [], unread: 0, offline: true);
    } on ServerException {
      return const NotifState(items: [], unread: 0);
    }
  }

  NotifState _toState(List<NotifEntry> items, {bool offline = false}) => NotifState(
        items: items,
        unread: items.where((n) => !n.read).length,
        offline: offline,
      );

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final items = await ref.read(notificationRepositoryProvider).fetchAll();
      state = AsyncData(_toState(items));
    } on NotFoundException {
      state = const AsyncData(NotifState(items: [], unread: 0));
    } on NetworkException {
      state = const AsyncData(NotifState(items: [], unread: 0, offline: true));
    } on ServerException {
      state = const AsyncData(NotifState(items: [], unread: 0));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> markRead(int id) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await ref.read(notificationRepositoryProvider).markRead(id);
    final updated =
        current.items.map((n) => n.id == id ? n.copyWith(read: true) : n).toList();
    state = AsyncData(_toState(updated, offline: current.offline));
  }

  Future<void> markAllRead() async {
    final current = state.valueOrNull;
    if (current == null) return;
    await ref.read(notificationRepositoryProvider).markAllRead();
    final updated = current.items.map((n) => n.copyWith(read: true)).toList();
    state = AsyncData(NotifState(items: updated, unread: 0, offline: current.offline));
  }

  // Called from FCM foreground handler — prepends entry with animation key.
  void insertFcm(NotifEntry entry) {
    final current = state.valueOrNull;
    final list = [entry, ...?current?.items];
    state = AsyncData(_toState(list, offline: current?.offline ?? false));
    ref.read(notificationRepositoryProvider).insertFcm(entry).ignore();
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsController, NotifState>(
  NotificationsController.new,
);

// Unread count for the bell badge on the dashboard.
final unreadNotifCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).valueOrNull?.unread ?? 0;
});
