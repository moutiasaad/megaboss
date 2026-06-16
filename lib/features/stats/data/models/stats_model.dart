// Driver performance statistics — from GET /driver/stats?period=
class StatsModel {
  const StatsModel({
    required this.deliveredCount,
    required this.failedCount,
    required this.pendingCount,
    required this.codCollected,
    required this.reachabilityRate,
    required this.dailyStats,
    required this.topFailureReasons,
    this.callsMade = 0,
  });

  final int deliveredCount;
  final int failedCount;
  final int pendingCount;
  final double codCollected;
  final double reachabilityRate; // 0.0–1.0
  final List<DailyStatModel> dailyStats;
  final List<FailureReasonModel> topFailureReasons;
  final int callsMade;

  int get totalShipments => deliveredCount + failedCount + pendingCount;

  double get successRate =>
      totalShipments == 0 ? 0.0 : deliveredCount / totalShipments;

  factory StatsModel.fromJson(Map<String, dynamic> json) => StatsModel(
        // API uses deliveries_completed / deliveries_failed; fall back to legacy keys.
        deliveredCount: json['deliveries_completed'] as int? ??
            json['delivered_count'] as int? ?? 0,
        failedCount: json['deliveries_failed'] as int? ??
            json['failed_count'] as int? ?? 0,
        pendingCount: json['pending_count'] as int? ?? 0,
        // cod_collected_total comes back as a String from the API ("0", "1234.50").
        codCollected: double.tryParse(
                '${json['cod_collected_total'] ?? json['cod_collected'] ?? 0}') ??
            0.0,
        reachabilityRate:
            (json['reachability_rate'] as num?)?.toDouble() ?? 0.0,
        // API uses daily_breakdown; fall back to daily_stats.
        dailyStats: ((json['daily_breakdown'] ?? json['daily_stats'])
                    as List<dynamic>?)
                ?.map((e) => DailyStatModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        topFailureReasons: (json['top_failure_reasons'] as List<dynamic>?)
                ?.map((e) =>
                    FailureReasonModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        callsMade: json['calls_made'] as int? ?? 0,
      );

  static StatsModel empty() => const StatsModel(
        deliveredCount: 0,
        failedCount: 0,
        pendingCount: 0,
        codCollected: 0,
        reachabilityRate: 0,
        dailyStats: [],
        topFailureReasons: [],
        callsMade: 0,
      );
}

class DailyStatModel {
  const DailyStatModel({
    required this.date,
    required this.delivered,
    required this.failed,
  });

  final DateTime date;
  final int delivered;
  final int failed;

  factory DailyStatModel.fromJson(Map<String, dynamic> json) => DailyStatModel(
        date: DateTime.parse(json['date'] as String),
        delivered: json['delivered'] as int? ?? 0,
        failed: json['failed'] as int? ?? 0,
      );
}

class FailureReasonModel {
  const FailureReasonModel({required this.reason, required this.count});

  final String reason;
  final int count;

  factory FailureReasonModel.fromJson(Map<String, dynamic> json) => FailureReasonModel(
        reason: json['reason'] as String,
        count: json['count'] as int? ?? 0,
      );
}

// Query period values for GET /driver/stats?period=
abstract final class StatsPeriod {
  static const String today = 'today';
  static const String week = 'week';
  static const String month = 'month';
  static const String custom = 'custom'; // requires from + to params
}
