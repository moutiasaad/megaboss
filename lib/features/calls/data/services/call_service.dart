import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../models/call_entry.dart';
import '../models/call_log_model.dart';

// Raw API calls for call logs and stats.
// Callers: CallRepository
class CallService {
  const CallService(this._client);
  final ApiClient _client;

  // POST /driver/calls/sync — uploads a batch of call log entries
  // Idempotent on raw_log_id (Android native call log ID).
  Future<void> syncCallLogs(List<CallLogModel> calls) async {
    try {
      await _client.dio.post<void>(
        Endpoints.callsSync,
        data: {'calls': calls.map((c) => c.toSyncPayload()).toList()},
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // GET /driver/calls/stats?period=day|week|month
  Future<Map<String, dynamic>> stats({String period = 'day'}) async {
    try {
      final data = await _client.get<dynamic>(
        Endpoints.callsStats,
        queryParameters: {'period': period},
      );
      return data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // GET /driver/calls/stats?filter=all|joined|no_answer|unreachable
  // Returns the driver's call history, filtered by result.
  Future<List<CallEntry>> getHistory({String filter = 'all'}) async {
    try {
      final data = await _client.get<dynamic>(
        Endpoints.callsStats,
        queryParameters: {'filter': filter},
      );
      return (data as List<dynamic>)
          .map((e) => CallEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // GET /driver/shipments/:id/calls
  Future<List<CallLogModel>> forShipment(int shipmentId) async {
    try {
      final data = await _client.get<dynamic>(Endpoints.shipmentCalls(shipmentId));
      return (data as List<dynamic>)
          .map((e) => CallLogModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
