import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../models/runsheet_model.dart';

// Raw API calls for runsheets — no caching, no state.
// Callers: RunsheetRepository
class RunsheetService {
  const RunsheetService(this._client);
  final ApiClient _client;

  // GET /driver/runsheets/active
  Future<RunsheetModel?> getActive() async {
    try {
      final data = await _client.get<dynamic>(Endpoints.runsheetsActive);
      if (data == null) return null;
      final map = data as Map<String, dynamic>;
      // Some API versions wrap the result in {items:[...]}
      if (map.containsKey('items')) {
        final items = map['items'] as List<dynamic>?;
        if (items == null || items.isEmpty) return null;
        return RunsheetModel.fromJson(items.first as Map<String, dynamic>);
      }
      return RunsheetModel.fromJson(map);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // GET /driver/runsheets?per_page=&period=&from=&to=&status=
  // API wraps the result in {items: [...], meta: {...}}
  Future<List<RunsheetModel>> list({
    int perPage = 20,
    String? from,
    String? to,
    String? status,
    String? period,
    int page = 1,
  }) async {
    try {
      final data = await _client.get<dynamic>(
        Endpoints.runsheets,
        queryParameters: {
          'per_page': perPage,
          'page': page,
          if (period != null) 'period': period,
          if (from != null) 'from': from,
          if (to != null) 'to': to,
          if (status != null) 'status': status,
        },
      );
      if (data == null) return [];
      // Unwrap {items: [...], meta: {...}} envelope.
      final rawList = (data is Map<String, dynamic>)
          ? (data['items'] as List<dynamic>?) ?? []
          : (data as List<dynamic>?) ?? [];
      return rawList
          .map((e) => RunsheetModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // GET /driver/runsheets/:id
  Future<RunsheetModel> show(int id) async {
    try {
      final data = await _client.get<dynamic>(Endpoints.runsheet(id));
      return RunsheetModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // POST /driver/runsheets — body: {warehouse_id, notes?}
  Future<RunsheetModel> create({
    required int warehouseId,
    String? notes,
  }) async {
    try {
      final data = await _client.post<dynamic>(
        Endpoints.runsheets,
        data: {
          'warehouse_id': warehouseId,
          if (notes != null) 'notes': notes,
        },
      );
      return RunsheetModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // POST /driver/runsheets/:id/close
  Future<RunsheetModel> close(int id) async {
    try {
      final data = await _client.post<dynamic>(Endpoints.runsheetClose(id));
      return RunsheetModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
