import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_exception.dart';
import 'endpoints.dart';

// Storage key for the Sanctum bearer token
const _kTokenKey = 'mb_bearer_token';

// Singleton Dio client with:
//   - BaseOptions (baseUrl, timeouts, JSON headers)
//   - AuthInterceptor (attaches Bearer token from SecureStorage)
//   - ErrorInterceptor (maps DioException → typed ApiException)
class ApiClient {
  ApiClient({
    required FlutterSecureStorage storage,
    String? baseUrl,
  })  : _storage = storage,
        _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? Endpoints.staging,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ),
        ) {
    _dio.interceptors.addAll([
      _AuthInterceptor(_storage),
      _ErrorInterceptor(),
      LogInterceptor(requestBody: true, responseBody: true),
    ]);
  }

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Dio get dio => _dio;

  // ── Token management ────────────────────────────────────────────────────────

  Future<void> saveToken(String token) => _storage.write(key: _kTokenKey, value: token);
  Future<void> deleteToken() => _storage.delete(key: _kTokenKey);
  Future<String?> readToken() => _storage.read(key: _kTokenKey);
  Future<bool> hasToken() async => (await _storage.read(key: _kTokenKey)) != null;

  // ── Convenience wrappers — return data payload or throw ApiException ────────

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? mapper,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: queryParameters,
    );
    final data = (response.data as Map<String, dynamic>)['data'];
    return mapper != null ? mapper(data) : data as T;
  }

  Future<T> post<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? mapper,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(path, data: data);
    final payload = (response.data as Map<String, dynamic>)['data'];
    return mapper != null ? mapper(payload) : payload as T;
  }

  Future<T> delete<T>(
    String path, {
    T Function(dynamic)? mapper,
  }) async {
    final response = await _dio.delete<Map<String, dynamic>>(path);
    final payload = (response.data as Map<String, dynamic>)['data'];
    return mapper != null ? mapper(payload) : payload as T;
  }
}

// ── Interceptors ──────────────────────────────────────────────────────────────

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._storage);
  final FlutterSecureStorage _storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: _kTokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: _mapError(err),
        type: err.type,
        response: err.response,
      ),
    );
  }

  ApiException _mapError(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout) {
      return const TimeoutException();
    }
    if (err.type == DioExceptionType.connectionError) {
      return const NetworkException();
    }

    final status = err.response?.statusCode;
    final body = err.response?.data;
    final message = _extractMessage(body);

    return switch (status) {
      401 => const UnauthorizedException(),
      403 => ForbiddenException(message),
      404 => NotFoundException(message),
      409 => ConflictException(message),
      422 => ValidationException(
          message,
          errors: _extractErrors(body),
        ),
      429 => RateLimitException(message),
      _ when (status ?? 0) >= 500 => ServerException(message, status),
      _ => UnknownException(message),
    };
  }

  String _extractMessage(dynamic body) {
    if (body is Map) {
      return body['message'] as String? ?? 'Erreur inconnue.';
    }
    return 'Erreur inconnue.';
  }

  Map<String, List<String>> _extractErrors(dynamic body) {
    if (body is Map && body['errors'] is Map) {
      return (body['errors'] as Map).map(
        (k, v) => MapEntry(
          k as String,
          (v as List).map((e) => e.toString()).toList(),
        ),
      );
    }
    return {};
  }
}

// Helper: extract ApiException from DioException thrown by ApiClient methods.
ApiException mapDioException(Object e) {
  if (e is DioException && e.error is ApiException) {
    return e.error as ApiException;
  }
  if (e is ApiException) return e;
  return const UnknownException();
}
