import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/runsheet_model.dart';
import '../../../../core/network/providers.dart';

// ── Period enum for the runsheets list screen ─────────────────────────────────

enum RunsheetPeriod { today, week, month, custom }

extension RunsheetPeriodX on RunsheetPeriod {
  String get apiValue => switch (this) {
        RunsheetPeriod.today => 'today',
        RunsheetPeriod.week => 'week',
        RunsheetPeriod.month => 'month',
        RunsheetPeriod.custom => 'custom',
      };
}

// ── Page state ────────────────────────────────────────────────────────────────

class RunsheetsPageData {
  const RunsheetsPageData({
    required this.items,
    required this.period,
    this.offline = false,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.customFrom,
    this.customTo,
  });

  final List<RunsheetModel> items;
  final RunsheetPeriod period;
  final bool offline;
  final bool hasMore;
  final bool isLoadingMore;
  final String? customFrom;
  final String? customTo;

  RunsheetsPageData copyWith({
    List<RunsheetModel>? items,
    RunsheetPeriod? period,
    bool? offline,
    bool? hasMore,
    bool? isLoadingMore,
    String? customFrom,
    String? customTo,
  }) =>
      RunsheetsPageData(
        items: items ?? this.items,
        period: period ?? this.period,
        offline: offline ?? this.offline,
        hasMore: hasMore ?? this.hasMore,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        customFrom: customFrom ?? this.customFrom,
        customTo: customTo ?? this.customTo,
      );
}

// ── Page notifier ─────────────────────────────────────────────────────────────

class RunsheetsPageNotifier extends AsyncNotifier<RunsheetsPageData> {
  RunsheetPeriod _period = RunsheetPeriod.today;
  int _page = 1;
  List<RunsheetModel> _all = [];
  bool _hasMore = true;
  String? _customFrom;
  String? _customTo;

  @override
  Future<RunsheetsPageData> build() async {
    _period = RunsheetPeriod.today;
    _page = 1;
    _all = [];
    _hasMore = true;
    _customFrom = null;
    _customTo = null;

    final repo = ref.watch(runsheetRepositoryProvider);
    final cached = repo.cachedListForPeriod(_period.apiValue);
    if (cached.isNotEmpty) {
      _all = _mergeWithDetailCache(cached);
      Future.microtask(() => _silentRefresh());
      return RunsheetsPageData(
        items: _sorted(_all),
        period: _period,
        hasMore: false,
      );
    }
    return _doFetch();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> setPeriod(
    RunsheetPeriod period, {
    String? from,
    String? to,
  }) async {
    _period = period;
    _customFrom = from;
    _customTo = to;
    _page = 1;
    _all = [];
    _hasMore = true;

    final repo = ref.read(runsheetRepositoryProvider);
    final cached = repo.cachedListForPeriod(period.apiValue);

    state = const AsyncLoading();
    try {
      final fresh = await _doFetch();
      state = AsyncData(fresh);
    } catch (e, st) {
      if (cached.isNotEmpty) {
        state = AsyncData(RunsheetsPageData(
          items: _sorted(cached),
          period: _period,
          offline: true,
        ));
      } else {
        state = AsyncError(e, st);
      }
    }
  }

  Future<void> refresh() async {
    final repo = ref.read(runsheetRepositoryProvider);
    final cached = repo.cachedListForPeriod(_period.apiValue);
    _page = 1;
    _all = [];
    _hasMore = true;

    state = const AsyncLoading();
    try {
      state = AsyncData(await _doFetch());
    } catch (e, st) {
      if (cached.isNotEmpty) {
        state = AsyncData(RunsheetsPageData(
          items: _sorted(cached),
          period: _period,
          offline: true,
        ));
      } else {
        state = AsyncError(e, st);
      }
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    _page++;

    try {
      final more = await _fetchPage();
      _all = [..._all, ...more];
      _hasMore = more.length >= 20;
      state = AsyncData(current.copyWith(
        items: _sorted(_all),
        hasMore: _hasMore,
        isLoadingMore: false,
        offline: false,
      ));
    } catch (_) {
      _page--;
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  // ── Private ────────────────────────────────────────────────────────────────

  Future<void> _silentRefresh() async {
    try {
      final fresh = await _doFetch();
      state = AsyncData(fresh);
    } catch (_) {
      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncData(current.copyWith(offline: true));
      }
    }
  }

  Future<RunsheetsPageData> _doFetch() async {
    _page = 1;
    final items = await _fetchPage();
    _all = _mergeWithDetailCache(items);
    _hasMore = items.length >= 20;
    return RunsheetsPageData(
      items: _sorted(_all),
      period: _period,
      offline: false,
      hasMore: _hasMore,
      customFrom: _customFrom,
      customTo: _customTo,
    );
  }

  // Overlay accurate counts from any cached detail/active entries onto list items.
  // The list API often omits delivered/failed counts; detail and active always have them.
  List<RunsheetModel> _mergeWithDetailCache(List<RunsheetModel> items) {
    final repo = ref.read(runsheetRepositoryProvider);
    final active = repo.cachedActive;
    return items.map((rs) {
      final detail = repo.cachedDetail(rs.id) ??
          (active?.id == rs.id ? active : null);
      if (detail == null) return rs;
      return rs.copyWith(
        deliveredCount: detail.deliveredCount,
        failedCount: detail.failedCount,
        pendingCount: detail.pendingCount,
      );
    }).toList();
  }

  Future<List<RunsheetModel>> _fetchPage() {
    return ref.read(runsheetRepositoryProvider).list(
          period: _period != RunsheetPeriod.custom ? _period.apiValue : null,
          from: _period == RunsheetPeriod.custom ? _customFrom : null,
          to: _period == RunsheetPeriod.custom ? _customTo : null,
          page: _page,
        );
  }

  // Replace a single item in the in-memory list (e.g. after loading its detail).
  void patchItem(RunsheetModel rs) {
    final current = state.valueOrNull;
    if (current == null) return;
    _all = _all.map((r) => r.id == rs.id ? rs : r).toList();
    state = AsyncData(current.copyWith(items: _sorted(_all)));
  }

  List<RunsheetModel> _sorted(List<RunsheetModel> items) {
    final out = [...items];
    out.sort((a, b) {
      if (a.isActive && !b.isActive) return -1;
      if (!a.isActive && b.isActive) return 1;
      final aDate = a.createdAt;
      final bDate = b.createdAt;
      if (aDate != null && bDate != null) return bDate.compareTo(aDate);
      return b.id.compareTo(a.id);
    });
    return out;
  }
}

final runsheetsPageProvider =
    AsyncNotifierProvider<RunsheetsPageNotifier, RunsheetsPageData>(
  RunsheetsPageNotifier.new,
);

// ── Active runsheet ────────────────────────────────────────────────────────────

class ActiveRunsheetController extends AsyncNotifier<RunsheetModel?> {
  @override
  Future<RunsheetModel?> build() async {
    final repo = ref.watch(runsheetRepositoryProvider);
    // Serve cache immediately while fetching.
    final cached = repo.cachedActive;
    if (cached != null) {
      Future.microtask(() async {
        try {
          final fresh = await repo.getActive();
          state = AsyncData(fresh);
        } catch (_) {}
      });
      return cached;
    }
    return repo.getActive();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(runsheetRepositoryProvider).getActive(),
    );
  }

  Future<RunsheetModel?> close(int id) async {
    try {
      final closed = await ref.read(runsheetRepositoryProvider).close(id);
      state = const AsyncData(null); // active is now null after close
      return closed;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }
}

final activeRunsheetProvider =
    AsyncNotifierProvider<ActiveRunsheetController, RunsheetModel?>(
  ActiveRunsheetController.new,
);

// ── Runsheet list ──────────────────────────────────────────────────────────────

class RunsheetListParams {
  const RunsheetListParams({
    this.status,
    this.from,
    this.to,
    this.page = 1,
  });
  final String? status;
  final String? from;
  final String? to;
  final int page;
}

class RunsheetListController
    extends AutoDisposeFamilyAsyncNotifier<List<RunsheetModel>, RunsheetListParams> {
  @override
  Future<List<RunsheetModel>> build(RunsheetListParams params) async {
    final repo = ref.watch(runsheetRepositoryProvider);
    if (params.page == 1) {
      final cached = repo.cachedList();
      if (cached.isNotEmpty) {
        Future.microtask(() async {
          try {
            final fresh = await repo.list(
              from: params.from,
              to: params.to,
              status: params.status,
            );
            state = AsyncData(fresh);
          } catch (_) {}
        });
        return cached;
      }
    }
    return repo.list(
      from: params.from,
      to: params.to,
      status: params.status,
      page: params.page,
    );
  }
}

final runsheetListProvider = AsyncNotifierProvider.autoDispose
    .family<RunsheetListController, List<RunsheetModel>, RunsheetListParams>(
  RunsheetListController.new,
);

// ── Runsheet detail ────────────────────────────────────────────────────────────

class RunsheetDetailController
    extends AutoDisposeFamilyAsyncNotifier<RunsheetModel, int> {
  @override
  Future<RunsheetModel> build(int id) async {
    final repo = ref.watch(runsheetRepositoryProvider);
    final cached = repo.cachedDetail(id);
    if (cached != null) {
      Future.microtask(() async {
        try {
          final fresh = await repo.show(id);
          state = AsyncData(fresh);
          // Propagate fresh counts back to the list so the card shows correct data.
          ref.read(runsheetsPageProvider.notifier).patchItem(fresh);
        } catch (_) {}
      });
      return cached;
    }
    final fresh = await repo.show(id);
    ref.read(runsheetsPageProvider.notifier).patchItem(fresh);
    return fresh;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(runsheetRepositoryProvider).show(arg),
    );
  }

  Future<void> close() async {
    final closed = await ref.read(runsheetRepositoryProvider).close(arg);
    state = AsyncData(closed);
    ref.invalidate(activeRunsheetProvider);
  }
}

final runsheetDetailProvider = AsyncNotifierProvider.autoDispose
    .family<RunsheetDetailController, RunsheetModel, int>(
  RunsheetDetailController.new,
);

// ── Create runsheet ────────────────────────────────────────────────────────────

final createRunsheetProvider =
    FutureProvider.autoDispose.family<RunsheetModel, ({int warehouseId, String? notes})>(
  (ref, args) => ref.read(runsheetRepositoryProvider).create(
        warehouseId: args.warehouseId,
        notes: args.notes,
      ),
);
