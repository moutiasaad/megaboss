import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../models/pickup_model.dart';

// Raw API calls for pickup manifests — no caching.
// Callers: PickupRepository
class PickupService {
  const PickupService(this._client);
  final ApiClient _client;

  // GET /driver/pickups/active
  Future<List<PickupModel>> getActive() async {
    try {
      final data = await _client.get<dynamic>(Endpoints.pickupsActive);
      if (data == null) return [];
      if (data is! List) return [];
      return data
          .map((e) => PickupModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // GET /driver/pickups/:id
  Future<PickupModel> show(int id) async {
    try {
      final data = await _client.get<dynamic>(Endpoints.pickup(id));
      return PickupModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // POST /driver/pickups/:manifestId/shipments/:shipmentId/accept
  Future<PickupShipmentModel> accept(int manifestId, int shipmentId) async {
    try {
      final data = await _client.post<dynamic>(
        Endpoints.pickupAccept(manifestId, shipmentId),
      );
      return PickupShipmentModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // POST /driver/pickups/:id/close
  Future<void> close(int id) async {
    try {
      await _client.post<dynamic>(Endpoints.pickupClose(id));
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // POST /driver/pickups/:manifestId/shipments/:shipmentId/refuse — body: {comment?}
  Future<PickupShipmentModel> refuse(
    int manifestId,
    int shipmentId, {
    String? comment,
  }) async {
    try {
      final data = await _client.post<dynamic>(
        Endpoints.pickupRefuse(manifestId, shipmentId),
        data: {if (comment != null) 'comment': comment},
      );
      return PickupShipmentModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
