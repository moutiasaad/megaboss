// Typed API exceptions — mapped from Dio errors to domain errors.
// Usage: catch (ApiException e) { switch (e) { ... } }

sealed class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

// 401 — token absent, expired, or revoked
class UnauthorizedException extends ApiException {
  const UnauthorizedException(
      [super.message = 'Session expirée. Reconnectez-vous.'])
      : super(statusCode: 401);
}

// 422 — validation errors from Laravel
class ValidationException extends ApiException {
  const ValidationException(super.message,
      {required this.errors, int? statusCode})
      : super(statusCode: statusCode ?? 422);
  final Map<String, List<String>> errors;

  String? firstError(String field) => errors[field]?.firstOrNull;
}

// 403 — authenticated but not authorized
class ForbiddenException extends ApiException {
  const ForbiddenException([super.message = 'Accès refusé.'])
      : super(statusCode: 403);
}

// 404 — resource not found
class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Ressource introuvable.'])
      : super(statusCode: 404);
}

// 409 — conflict (e.g. runsheet already closed)
class ConflictException extends ApiException {
  const ConflictException([super.message = 'Conflit de données.'])
      : super(statusCode: 409);
}

// 429 — server-side rate limit (Laravel "Too Many Attempts")
class RateLimitException extends ApiException {
  const RateLimitException(
      [super.message = 'Trop de requêtes. Réessayez dans un instant.'])
      : super(statusCode: 429);
}

// 5xx — server-side error
class ServerException extends ApiException {
  const ServerException([super.message = 'Erreur serveur.', int? code])
      : super(statusCode: code);
}

// Network or socket error
class NetworkException extends ApiException {
  const NetworkException([super.message = 'Aucune connexion réseau.'])
      : super();
}

// Request or response timeout
class TimeoutException extends ApiException {
  const TimeoutException([super.message = 'Délai de connexion dépassé.'])
      : super();
}

// Anything else
class UnknownException extends ApiException {
  const UnknownException(
      [super.message = 'Une erreur inattendue est survenue.'])
      : super();
}
