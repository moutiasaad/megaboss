import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    final runsheet = ref.read(runsheetRepositoryProvider).cachedActive;
    final pickups = ref.read(pickupRepositoryProvider).cachedActive;
    final stats = ref.read(statsRepositoryProvider).cached(StatsPeriod.today);
    final pendingOps = ref.read(pendingOpsCountProvider).valueOrNull ?? 0;

    return DashboardData(
      driver: driver,
      activeRunsheet:
          runsheet != null ? RunsheetSummary.from(runsheet) : null,
      activePickup:
          pickups.isNotEmpty ? PickupSummary.from(pickups.first) : null,
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
        if (r != null) {
          debugPrint('[Dashboard] ✓ runsheets/active → id=${r.id}');
          return r;
        }
        // Endpoint returned null — fall back to first in_progress from the list.
        debugPrint('[Dashboard] runsheets/active=null, trying list fallback');
        final list = await ref.read(runsheetRepositoryProvider).list(
          status: RunsheetStatus.inProgress,
          perPage: 1,
        );
        final first = list.isNotEmpty ? list.first : null;
        debugPrint('[Dashboard] list fallback → ${first == null ? 'none' : 'id=${first.id}'}');
        return first;
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
      activePickup: pickupList.isNotEmpty ? PickupSummary.from(pickupList.first) : null,
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

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchAll);
  }
}

final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardData>(
        DashboardNotifier.new);
