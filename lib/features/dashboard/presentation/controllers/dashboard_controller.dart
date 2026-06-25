import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/providers.dart';
import '../../../../features/pickup/data/models/pickup_model.dart';
import '../../../../features/runsheets/data/models/runsheet_model.dart';
import '../../../../features/stats/data/models/stats_model.dart';
import '../../data/models/dashboard_data.dart';

class DashboardNotifier extends AsyncNotifier<DashboardData> {
  @override
  FutureOr<DashboardData> build() async {
    final cached = _fromCache();
    if (cached != null) {
      // Warm cache hit: return immediately and refresh silently in background.
      Future.microtask(_backgroundRefresh);
      return cached;
    }
    return _fetchAll();
  }

  // ── Cache read ─────────────────────────────────────────────────────────────

  DashboardData? _fromCache() {
    final driver = ref.read(authRepositoryProvider).cachedDriver;
    if (driver == null) return null;

    // Cache fast-path: prefer the active runsheet if it still has pending
    // colis; otherwise look at the cached today list for one with work left.
    final rsRepo = ref.read(runsheetRepositoryProvider);
    final active = rsRepo.cachedActive;
    final runsheet = (active != null && active.pendingCount > 0)
        ? active
        : rsRepo
                .cachedList()
                .where((rs) =>
                    rs.status == RunsheetStatus.inProgress &&
                    rs.pendingCount > 0)
                .firstOrNull ??
            active;
    final pickups = ref.read(pickupRepositoryProvider).cachedActive;
    final stats = ref.read(statsRepositoryProvider).cached(StatsPeriod.today);
    final pendingOps = ref.read(pendingOpsCountProvider).valueOrNull ?? 0;

    return DashboardData(
      driver: driver,
      activeRunsheet:
          runsheet != null ? RunsheetSummary.from(runsheet) : null,
      activePickup:
          pickups.isNotEmpty ? PickupSummary.aggregate(pickups) : null,
      today: stats != null ? DayStats.fromStats(stats) : DayStats.empty,
      pendingSyncOps: pendingOps,
    );
  }

  // ── Network fetch ──────────────────────────────────────────────────────────

  Future<DashboardData> _fetchAll() async {
    debugPrint('[Dashboard] _fetchAll start');

    final connectivity = ref.read(connectivityProvider);
    final result = await connectivity.checkConnectivity();
    final isOffline = result.every((r) => r == ConnectivityResult.none);
    debugPrint('[Dashboard] connectivity=$result isOffline=$isOffline');

    if (isOffline) {
      final cached = _fromCache();
      if (cached != null) return cached.copyWith(isOffline: true);
      throw Exception('offline-no-cache');
    }

    final pendingOps = ref.read(pendingOpsCountProvider).valueOrNull ?? 0;

    // ── /driver/me (falls back to cached driver if request fails) ─────────────
    debugPrint('[Dashboard] → GET /driver/me');
    final driver = await ref.read(authRepositoryProvider).fetchDriver().then((d) {
      debugPrint('[Dashboard] ✓ /driver/me name=${d.name}');
      return d;
    }).catchError((Object e, StackTrace st) {
      debugPrint('[Dashboard] ✗ /driver/me FAILED: $e\n$st');
      final cached = ref.read(authRepositoryProvider).cachedDriver;
      if (cached != null) {
        debugPrint('[Dashboard] → fallback to cached driver: ${cached.name}');
        return cached;
      }
      throw e;
    });

    // ── Non-critical parallel calls — each fallback to null / empty ───────────
    debugPrint('[Dashboard] → GET /driver/runsheets/active');
    debugPrint('[Dashboard] → GET /driver/pickups/active');
    debugPrint('[Dashboard] → GET /driver/stats?period=today');

    final results = await Future.wait([
      ref.read(runsheetRepositoryProvider).getActive().then<RunsheetModel?>((r) async {
        // Prefer a runsheet that still has pending colis. If `/active` returns
        // a runsheet that's fully done (or returns null), look at the list of
        // in-progress runsheets and pick the first one with remaining work.
        if (r != null && r.pendingCount > 0) {
          debugPrint('[Dashboard] ✓ runsheets/active → id=${r.id}');
          return r;
        }
        debugPrint(
            '[Dashboard] runsheets/active=${r?.id ?? 'null'} pending=${r?.pendingCount ?? 0}, looking for one with pending work');
        final list = await ref.read(runsheetRepositoryProvider).list(
          status: RunsheetStatus.inProgress,
          perPage: 20,
        );
        // First with remaining > 0; otherwise keep the originally returned r
        // (still hidden on Home by the dashboard filter, but useful for cache).
        final firstWithWork =
            list.where((rs) => rs.pendingCount > 0).firstOrNull;
        if (firstWithWork != null) {
          debugPrint('[Dashboard] list fallback → id=${firstWithWork.id} pending=${firstWithWork.pendingCount}');
          return firstWithWork;
        }
        debugPrint('[Dashboard] no in-progress runsheet has pending work → keep ${r?.id ?? 'null'}');
        return r;
      }).catchError((Object e, StackTrace st) {
        debugPrint('[Dashboard] ✗ runsheets/active FAILED: $e\n$st');
        return null;
      }),
      ref.read(pickupRepositoryProvider).getActive().then<List<PickupModel>>((list) {
        debugPrint('[Dashboard] ✓ pickups/active → ${list.length} items');
        return list;
      }).catchError((Object e, StackTrace st) {
        debugPrint('[Dashboard] ✗ pickups/active FAILED: $e\n$st');
        return <PickupModel>[];
      }),
      ref.read(statsRepositoryProvider).get(period: StatsPeriod.today).then<StatsModel>((s) {
        debugPrint('[Dashboard] ✓ stats/today → delivered=${s.deliveredCount} cod=${s.codCollected}');
        return s;
      }).catchError((Object e, StackTrace st) {
        debugPrint('[Dashboard] ✗ stats/today FAILED: $e\n$st');
        return StatsModel.empty();
      }),
    ]);

    final runsheet = results[0] as RunsheetModel?;
    final pickupList = results[1] as List<PickupModel>;
    final stats = results[2] as StatsModel;

    debugPrint('[Dashboard] _fetchAll complete');
    return DashboardData(
      driver: driver,
      activeRunsheet: runsheet != null ? RunsheetSummary.from(runsheet) : null,
      activePickup: pickupList.isNotEmpty ? PickupSummary.aggregate(pickupList) : null,
      today: DayStats.fromStats(stats),
      pendingSyncOps: pendingOps,
      isOffline: false,
    );
  }

  // ── Background refresh (called after cache hit) ────────────────────────────

  Future<void> _backgroundRefresh() async {
    try {
      final fresh = await _fetchAll();
      state = AsyncData(fresh);
    } catch (_) {
      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncData(current.copyWith(isOffline: true));
      }
    }
  }

  // ── Public actions ─────────────────────────────────────────────────────────

  // Minimum interval between refresh() calls — prevents the driver from
  // pull-to-refreshing in a tight loop and triggering server-side 429s.
  static const _minRefreshInterval = Duration(seconds: 4);
  DateTime? _lastRefreshAt;

  Future<void> refresh() async {
    final now = DateTime.now();
    if (_lastRefreshAt != null &&
        now.difference(_lastRefreshAt!) < _minRefreshInterval) {
      // Skip — too soon since last refresh.
      return;
    }
    _lastRefreshAt = now;

    // Don't blank the screen — keep cached data visible while fetching.
    try {
      final fresh = await _fetchAll();
      state = AsyncData(fresh);
    } on RateLimitException {
      // Server is throttling — keep what we have, flag the offline state so
      // the banner appears (signals "stale data" to the driver).
      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncData(current.copyWith(isOffline: true));
      }
    } catch (e, st) {
      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncData(current.copyWith(isOffline: true));
      } else {
        state = AsyncError(e, st);
      }
    }
  }
}

final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardData>(
        DashboardNotifier.new);
