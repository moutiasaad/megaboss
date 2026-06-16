import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../models/shipment_model.dart';
import '../../../calls/data/models/call_log_model.dart';

// Raw API calls for individual shipments — no caching.
// Callers: ShipmentRepository
class ShipmentService {
  const ShipmentService(this._client);
  final ApiClient _client;

  // GET /driver/shipments/:id
  Future<ShipmentModel> show(int id) async {
    try {
      final data = await _client.get<dynamic>(Endpoints.shipment(id));
      return ShipmentModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // POST /driver/shipments/:id/status
  // Transitions: received_at_depot→picked_up ; picked_up→delivered|failed|returned
  // comment required for failed/returned; reschedule_date required for failed
  Future<ShipmentModel> updateStatus(
    int id, {
    required String status,
    String? comment,
    String? returnType,
    String? rescheduleDate, // ISO date 'YYYY-MM-DD'
  }) async {
    try {
      final data = await _client.post<dynamic>(
        Endpoints.shipmentStatus(id),
        data: {
          'status': status,
          if (comment != null) 'comment': comment,
          if (returnType != null) 'return_type': returnType,
          if (rescheduleDate != null) 'reschedule_date': rescheduleDate,
        },
      );
      return ShipmentModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // GET /driver/shipments/:id/calls
  Future<List<CallLogModel>> calls(int id) async {
    try {
      final data = await _client.get<dynamic>(Endpoints.shipmentCalls(id));
      return (data as List<dynamic>)
          .map((e) => CallLogModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
