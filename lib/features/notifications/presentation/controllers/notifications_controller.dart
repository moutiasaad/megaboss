import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/notif_entry.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/providers.dart';

class NotificationsController extends AsyncNotifier<NotifState> {
  static const _perPage = 20;

  @override
  Future<NotifState> build() async {
    final repo = ref.read(notificationRepositoryProvider);
    final cached = repo.cached;

    if (cached.isNotEmpty) {
      // Serve cache instantly; refresh silently in background.
      Future.microtask(_silentRefresh);
      return NotifState(
        items: cached,
        unread: repo.cachedUnread,
        offline: true,
      );
    }

    return _firstPageWithFallback();
  }

  Future<NotifState> _firstPageWithFallback() async {
    final repo = ref.read(notificationRepositoryProvider);
    try {
      final page = await repo.fetchFirstPage(perPage: _perPage);
      final unread = await _safeUnreadCount();
      return NotifState(
        items: page.items,
        unread: unread,
        currentPage: page.currentPage,
        lastPage: page.lastPage,
      );
    } on NotFoundException {
      return const NotifState(items: [], unread: 0);
    } on NetworkException {
      return const NotifState(items: [], unread: 0, offline: true);
    } on ServerException {
      return const NotifState(items: [], unread: 0);
    }
  }

  Future<int> _safeUnreadCount() async {
    try {
      return await ref.read(notificationRepositoryProvider).fetchUnreadCount();
    } catch (_) {
      return ref.read(notificationRepositoryProvider).cachedUnread;
    }
  }

  Future<void> _silentRefresh() async {
    try {
      final repo = ref.read(notificationRepositoryProvider);
      final page = await repo.fetchFirstPage(perPage: _perPage);
      final unread = await _safeUnreadCount();
      state = AsyncData(NotifState(
        items: page.items,
        unread: unread,
        currentPage: page.currentPage,
        lastPage: page.lastPage,
      ));
    } catch (_) {}
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _firstPageWithFallback());
  }

  // Fetches the next page and appends it to the existing list.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref
          .read(notificationRepositoryProvider)
          .fetchPage(current.currentPage + 1, perPage: _perPage);
      // Dedup by id — server may have shifted entries between pages.
      final existingIds = current.items.map((e) => e.id).toSet();
      final merged = [
        ...current.items,
        ...page.items.where((e) => !existingIds.contains(e.id)),
      ];
      state = AsyncData(current.copyWith(
        items: merged,
        currentPage: page.currentPage,
        lastPage: page.lastPage,
        loadingMore: false,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  Future<void> markRead(int id) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final wasUnread = current.items.any((n) => n.id == id && !n.read);
    final updated = current.items
        .map((n) => n.id == id ? n.copyWith(read: true) : n)
        .toList();
    state = AsyncData(current.copyWith(
      items: updated,
      unread: wasUnread ? (current.unread - 1).clamp(0, 1 << 31) : current.unread,
    ));
    await ref.read(notificationRepositoryProvider).markRead(id);
  }

  Future<void> markAllRead() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = current.items.map((n) => n.copyWith(read: true)).toList();
    state = AsyncData(current.copyWith(items: updated, unread: 0));
    await ref.read(notificationRepositoryProvider).markAllRead();
  }

  // Called from FCM foreground handler — prepends entry.
  void insertFcm(NotifEntry entry) {
    final current = state.valueOrNull;
    final list = [entry, ...?current?.items];
    final delta = entry.read ? 0 : 1;
    state = AsyncData(NotifState(
      items: list,
      unread: (current?.unread ?? 0) + delta,
      offline: current?.offline ?? false,
      currentPage: current?.currentPage ?? 1,
      lastPage: current?.lastPage ?? 1,
    ));
    ref.read(notificationRepositoryProvider).insertFcm(entry).ignore();
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsController, NotifState>(
  NotificationsController.new,
);

// Unread count for the bell badge on the dashboard.
// Polls the dedicated /unread-count endpoint and falls back to whatever the
// list controller has if the dedicated call fails.
final unreadNotifCountProvider = FutureProvider.autoDispose<int>((ref) async {
  // Keep the value alive briefly so navigating away and back doesn't refetch.
  final link = ref.keepAlive();
  Future.delayed(const Duration(seconds: 30), link.close);
  try {
    return await ref.read(notificationRepositoryProvider).fetchUnreadCount();
  } catch (_) {
    return ref.read(notificationsProvider).valueOrNull?.unread ??
        ref.read(notificationRepositoryProvider).cachedUnread;
  }
});
