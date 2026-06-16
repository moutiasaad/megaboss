import '../../../auth/data/models/driver_model.dart';
import '../../../runsheets/data/models/runsheet_model.dart';
import '../../../pickup/data/models/pickup_model.dart';
import '../../../stats/data/models/stats_model.dart';

// ── Lightweight summaries used exclusively on the dashboard ───────────────────

class RunsheetSummary {
  const RunsheetSummary({
    required this.id,
    required this.label,
    required this.total,
    required this.delivered,
    required this.failed,
    required this.remaining,
  });

  final int id;
  final String label;
  final int total;
  final int delivered;
  final int failed;
  final int remaining;

  double get deliveredPct => total > 0 ? delivered / total : 0;
  double get failedPct => total > 0 ? failed / total : 0;
  double get remainingPct => total > 0 ? remaining / total : 0;

  factory RunsheetSummary.from(RunsheetModel r) => RunsheetSummary(
        id: r.id,
        label: r.label,
        total: r.totalShipments,
        delivered: r.deliveredCount,
        failed: r.failedCount,
        remaining: r.pendingCount,
      );
}

class PickupSummary {
  const PickupSummary({
    required this.id,
    required this.manifestNumber,
    required this.senderName,
    required this.pendingCount,
    this.zone,
  });

  final int id;
  final String manifestNumber;
  final String senderName;
  final int pendingCount;
  final String? zone;

  factory PickupSummary.from(PickupModel p) => PickupSummary(
        id: p.id,
        manifestNumber: p.manifestNumber,
        senderName: p.senderName,
        pendingCount: p.pendingCount,
        zone: p.senderAddress,
      );
}

class DayStats {
  const DayStats({
    required this.deliveries,
    required this.calls,
    required this.codCollected,
  });

  final int deliveries;
  final int calls;
  final double codCollected;

  static const empty = DayStats(deliveries: 0, calls: 0, codCollected: 0);

  factory DayStats.fromStats(StatsModel s) => DayStats(
        deliveries: s.deliveredCount,
        calls: s.callsMade,
        codCollected: s.codCollected,
      );
}

// ── Aggregate ─────────────────────────────────────────────────────────────────

class DashboardData {
  const DashboardData({
    required this.driver,
    this.activeRunsheet,
    this.activePickup,
    required this.today,
    required this.pendingSyncOps,
    this.isOffline = false,
  });

  final DriverModel driver;
  final RunsheetSummary? activeRunsheet;
  final PickupSummary? activePickup;
  final DayStats today;
  final int pendingSyncOps;
  final bool isOffline;

  DashboardData copyWith({
    RunsheetSummary? activeRunsheet,
    PickupSummary? activePickup,
    DayStats? today,
    int? pendingSyncOps,
    bool? isOffline,
  }) =>
      DashboardData(
        driver: driver,
        activeRunsheet: activeRunsheet ?? this.activeRunsheet,
        activePickup: activePickup ?? this.activePickup,
        today: today ?? this.today,
        pendingSyncOps: pendingSyncOps ?? this.pendingSyncOps,
        isOffline: isOffline ?? this.isOffline,
      );
}
