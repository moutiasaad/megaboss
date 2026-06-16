import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../models/stats_model.dart';

// Raw API calls for driver performance stats.
// Callers: StatsRepository
class StatsService {
  const StatsService(this._client);
  final ApiClient _client;

  // GET /driver/stats?period=today|week|month|custom&from=&to=
  Future<StatsModel> get({
    String period = StatsPeriod.today,
    String? from, // ISO date — required when period=custom
    String? to,
  }) async {
    try {
      final data = await _client.get<dynamic>(
        Endpoints.stats,
        queryParameters: {
          'period': period,
          if (from != null) 'from': from,
          if (to != null) 'to': to,
        },
      );
      if (data == null || data is! Map<String, dynamic>) return StatsModel.empty();
      return StatsModel.fromJson(data);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
