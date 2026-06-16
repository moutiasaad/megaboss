import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../models/scan_result_model.dart';

// Raw API calls for barcode scanning — no caching.
// All offline queueing is handled at the repository level.
// Callers: ScanRepository
class ScanService {
  const ScanService(this._client);
  final ApiClient _client;

  // POST /driver/scan/delivery
  // Two-phase COD:
  //   Phase 1: send cod_collected=null → receive {requires_confirmation: true}
  //   Phase 2: re-send with cod_collected=true|false
  Future<ScanResultModel> scanDelivery({
    required String barcode,
    required String status, // ShipmentStatus.delivered | .failed | .returned
    required String clientOperationId,
    String? comment,
    String? returnType,
    String? rescheduleDate,
    String? signature, // base64 or URL
    bool? codCollected,
  }) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        Endpoints.scanDelivery,
        data: {
          'barcode': barcode,
          'status': status,
          'client_operation_id': clientOperationId,
          if (comment != null) 'comment': comment,
          if (returnType != null) 'return_type': returnType,
          if (rescheduleDate != null) 'reschedule_date': rescheduleDate,
          if (signature != null) 'signature': signature,
          'cod_collected': codCollected, // null = phase 1
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return ScanResultModel.fromJson(data);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // POST /driver/scan/pickup — single scan during manifest collection
  Future<ScanResultModel> scanPickup({
    required String barcode,
    required String clientOperationId,
  }) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        Endpoints.scanPickup,
        data: {
          'barcode': barcode,
          'client_operation_id': clientOperationId,
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return ScanResultModel.fromJson(data);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // POST /driver/scan/batch — bulk upload after Pickup Rapide session
  // operations[] — see BatchScanItem
  Future<List<ScanResultModel>> scanBatch(List<BatchScanItem> items) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        Endpoints.scanBatch,
        data: {'operations': items.map((e) => e.toJson()).toList()},
      );
      final results = response.data!['data'] as List<dynamic>;
      return results
          .map((e) => ScanResultModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
