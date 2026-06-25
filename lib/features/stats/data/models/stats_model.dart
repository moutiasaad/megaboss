// Driver performance statistics — from GET /driver/stats?period=
//
// Response shape (current as of 2026-06-23):
// {
//   "period": "today",
//   "from": "2026-06-23",
//   "to":   "2026-06-23",
//   "deliveries_completed":  2,   "delivery_rate":   33.3,
//   "delivered_per_day":     [{"date":"2026-06-23","count":2}],
//   "deliveries_rescheduled":2,   "reschedule_rate": 33.3,
//   "rescheduled_per_day":   [{"date":"2026-06-23","count":2}],
//   "deliveries_returned":   2,   "return_rate":     33.3,
//   "returned_per_day":      [{"date":"2026-06-23","count":2}],
//   "pickups_assigned":      116, "pickups_realized": 28, "pickups_collected": 4,
//   "cod_collected_total":   "757",
//   "calls_made": 0, "calls_reached": 0, "calls_no_answer": 0, "calls_unreachable": 0,
//   "runsheets_closed": 9
// }
class StatsModel {
  const StatsModel({
    this.from,
    this.to,
    required this.deliveredCount,
    required this.deliveryRate,
    required this.rescheduledCount,
    required this.rescheduleRate,
    required this.returnedCount,
    required this.returnRate,
    required this.codCollected,
    required this.dailyStats,
    this.pickupsAssigned = 0,
    this.pickupsRealized = 0,
    this.pickupsCollected = 0,
    this.callsMade = 0,
    this.callsReached = 0,
    this.callsNoAnswer = 0,
    this.callsUnreachable = 0,
    this.runsheetsClosed = 0,
    this.codCurrency = 'TND',
  });

  // Period range (ISO yyyy-MM-dd) — informational
  final String? from;
  final String? to;

  // Deliveries
  final int deliveredCount;     // deliveries_completed
  final double deliveryRate;    // 0–100
  final int rescheduledCount;   // deliveries_rescheduled (failed with reschedule)
  final double rescheduleRate;
  final int returnedCount;      // deliveries_returned (definitive return)
  final double returnRate;

  // COD + currency
  final double codCollected;
  final String codCurrency;

  // Daily breakdown — one row per day, three counts
  final List<DailyStatModel> dailyStats;

  // Pickups
  final int pickupsAssigned;
  final int pickupsRealized;
  final int pickupsCollected;

  // Calls
  final int callsMade;
  final int callsReached;
  final int callsNoAnswer;
  final int callsUnreachable;

  // Runsheets
  final int runsheetsClosed;

  // ── Derived ──────────────────────────────────────────────────────────────────

  // Total terminal attempts (delivered + both kinds of non-delivery).
  int get totalAttempts => deliveredCount + rescheduledCount + returnedCount;

  // Combined non-delivered count — used for the "Retours" KPI tile.
  int get returnsCount => rescheduledCount + returnedCount;

  // Backward-compat with code that still reads failedCount (= rescheduled + returned).
  int get failedCount => returnsCount;

  // 0.0–1.0 success ratio.
  double get successRate =>
      totalAttempts == 0 ? 0.0 : deliveredCount / totalAttempts;

  // 0.0–1.0 reachability ratio (was a server field, now derived from calls).
  double get reachabilityRate =>
      callsMade == 0 ? 0.0 : callsReached / callsMade;

  // ── JSON ────────────────────────────────────────────────────────────────────

  factory StatsModel.fromJson(Map<String, dynamic> json) {
    // Merge the three per-day arrays into one List<DailyStatModel>.
    final delivered = _readPerDay(json['delivered_per_day']);
    final rescheduled = _readPerDay(json['rescheduled_per_day']);
    final returned = _readPerDay(json['returned_per_day']);
    final dailyStats = _mergeDaily(delivered, rescheduled, returned);

    // Fallback to the legacy `daily_breakdown` / `daily_stats` shape if the
    // per-status arrays are absent (e.g. older cached entries).
    final fallbackDaily = dailyStats.isEmpty
        ? ((json['daily_breakdown'] ?? json['daily_stats']) as List<dynamic>?)
                ?.map((e) => DailyStatModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const <DailyStatModel>[]
        : dailyStats;

    return StatsModel(
      from: json['from'] as String?,
      to: json['to'] as String?,
      deliveredCount: _readInt(json, ['deliveries_completed', 'delivered_count']),
      deliveryRate: _readDouble(json, ['delivery_rate']),
      rescheduledCount:
          _readInt(json, ['deliveries_rescheduled', 'rescheduled_count']),
      rescheduleRate: _readDouble(json, ['reschedule_rate']),
      returnedCount:
          _readInt(json, ['deliveries_returned', 'returned_count']),
      returnRate: _readDouble(json, ['return_rate']),
      // cod_collected_total comes back as a String ("0", "1234.50").
      codCollected: double.tryParse(
              '${json['cod_collected_total'] ?? json['cod_collected'] ?? 0}') ??
          0.0,
      codCurrency: (json['currency'] ?? json['cod_currency']) as String? ??
          'TND',
      dailyStats: fallbackDaily,
      pickupsAssigned: _readInt(json, ['pickups_assigned']),
      pickupsRealized: _readInt(json, ['pickups_realized']),
      pickupsCollected: _readInt(json, ['pickups_collected']),
      callsMade: _readInt(json, ['calls_made']),
      callsReached: _readInt(json, ['calls_reached']),
      callsNoAnswer: _readInt(json, ['calls_no_answer']),
      callsUnreachable: _readInt(json, ['calls_unreachable']),
      runsheetsClosed: _readInt(json, ['runsheets_closed']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        'deliveries_completed': deliveredCount,
        'delivery_rate': deliveryRate,
        'deliveries_rescheduled': rescheduledCount,
        'reschedule_rate': rescheduleRate,
        'deliveries_returned': returnedCount,
        'return_rate': returnRate,
        'cod_collected_total': codCollected.toString(),
        'currency': codCurrency,
        'daily_stats': dailyStats.map((d) => d.toJson()).toList(),
        'pickups_assigned': pickupsAssigned,
        'pickups_realized': pickupsRealized,
        'pickups_collected': pickupsCollected,
        'calls_made': callsMade,
        'calls_reached': callsReached,
        'calls_no_answer': callsNoAnswer,
        'calls_unreachable': callsUnreachable,
        'runsheets_closed': runsheetsClosed,
      };

  static StatsModel empty() => const StatsModel(
        deliveredCount: 0,
        deliveryRate: 0,
        rescheduledCount: 0,
        rescheduleRate: 0,
        returnedCount: 0,
        returnRate: 0,
        codCollected: 0,
        dailyStats: [],
      );
}

class DailyStatModel {
  const DailyStatModel({
    required this.date,
    this.delivered = 0,
    this.rescheduled = 0,
    this.returned = 0,
  });

  final DateTime date;
  final int delivered;
  final int rescheduled;
  final int returned;

  // Combined non-delivered count for this day.
  int get failed => rescheduled + returned;
  int get total => delivered + rescheduled + returned;

  factory DailyStatModel.fromJson(Map<String, dynamic> json) => DailyStatModel(
        date: DateTime.parse(json['date'] as String),
        delivered: json['delivered'] as int? ?? 0,
        // Legacy cached entries may only have `failed` — bucket it into rescheduled.
        rescheduled: json['rescheduled'] as int? ??
            json['failed'] as int? ??
            0,
        returned: json['returned'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'delivered': delivered,
        'rescheduled': rescheduled,
        'returned': returned,
      };
}

// ── Parsing helpers ──────────────────────────────────────────────────────────

int _readInt(Map<String, dynamic> json, List<String> keys) {
  for (final k in keys) {
    final v = json[k];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final parsed = int.tryParse(v);
      if (parsed != null) return parsed;
    }
  }
  return 0;
}

double _readDouble(Map<String, dynamic> json, List<String> keys) {
  for (final k in keys) {
    final v = json[k];
    if (v is num) return v.toDouble();
    if (v is String) {
      final parsed = double.tryParse(v);
      if (parsed != null) return parsed;
    }
  }
  return 0.0;
}

// Parses `[{date, count}, ...]` into a `Map<String dateIso, int count>`.
Map<String, int> _readPerDay(dynamic raw) {
  if (raw is! List) return const {};
  final out = <String, int>{};
  for (final e in raw) {
    if (e is! Map) continue;
    final date = e['date'] as String?;
    if (date == null) continue;
    final count = (e['count'] as num?)?.toInt() ??
        int.tryParse('${e['count'] ?? 0}') ??
        0;
    out[date] = count;
  }
  return out;
}

// Merges the three per-status maps into one ordered `List<DailyStatModel>`.
List<DailyStatModel> _mergeDaily(
  Map<String, int> delivered,
  Map<String, int> rescheduled,
  Map<String, int> returned,
) {
  final dates = <String>{
    ...delivered.keys,
    ...rescheduled.keys,
    ...returned.keys,
  }.toList()
    ..sort();
  return dates
      .map((iso) => DailyStatModel(
            date: DateTime.parse(iso),
            delivered: delivered[iso] ?? 0,
            rescheduled: rescheduled[iso] ?? 0,
            returned: returned[iso] ?? 0,
          ))
      .toList();
}

// Query period values for GET /driver/stats?period=
abstract final class StatsPeriod {
  static const String today = 'today';
  static const String week = 'week';
  static const String month = 'month';
  static const String custom = 'custom'; // requires from + to params
}
