import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../models/motif_model.dart';

// GET /driver/motifs — returns return_reasons + refusal_reasons.
class MotifsService {
  const MotifsService(this._client);
  final ApiClient _client;

  Future<MotifsModel> get() async {
    try {
      final data = await _client.get<dynamic>(Endpoints.motifs);
      if (data == null || data is! Map<String, dynamic>) {
        return MotifsModel.empty;
      }
      return MotifsModel.fromJson(data);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
