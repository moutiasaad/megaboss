import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/stats_model.dart';
import '../../data/services/stats_service.dart';

const _kStatsBox = 'mb_stats';

// Stats repository — caches last fetched stats per period.
class StatsRepository {
  StatsRepository({
    required StatsService service,
    required Box<String> box,
  })  : _service = service,
        _box = box;

  final StatsService _service;
  final Box<String> _box;

  static Future<Box<String>> openBox() => Hive.openBox<String>(_kStatsBox);

  StatsModel? cached(String period) {
    final raw = _box.get(period);
    if (raw == null) return null;
    try {
      return StatsModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<StatsModel> get({
    String period = StatsPeriod.today,
    String? from,
    String? to,
  }) async {
    final stats = await _service.get(period: period, from: from, to: to);
    final key = period == StatsPeriod.custom ? 'custom_${from}_$to' : period;
    _box.put(key, jsonEncode(stats.toJson()));
    return stats;
  }
}
