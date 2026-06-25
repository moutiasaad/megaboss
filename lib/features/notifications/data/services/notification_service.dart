import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../models/notif_entry.dart';

// Raw API calls for the driver inbox.
// Callers: NotificationRepository
class NotificationService {
  const NotificationService(this._client);
  final ApiClient _client;

  // GET /driver/notifications?page=&per_page=&unread=
  Future<NotifPage> fetchPage({
    int page = 1,
    int perPage = 20,
    bool unreadOnly = false,
  }) async {
    try {
      final raw = await _client.get<dynamic>(
        Endpoints.notifications,
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (unreadOnly) 'unread': 1,
        },
      );
      return NotifPage.fromJson(raw);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // GET /driver/notifications/unread-count → { "unread": n }
  Future<int> unreadCount() async {
    try {
      final raw = await _client.get<dynamic>(Endpoints.notificationsUnreadCount);
      if (raw is Map<String, dynamic>) {
        return raw['unread'] as int? ?? 0;
      }
      return 0;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // POST /driver/notifications/{id}/read → returns the updated notification.
  Future<NotifEntry?> markRead(int id) async {
    try {
      final raw = await _client.post<dynamic>(Endpoints.notificationRead(id));
      if (raw is Map<String, dynamic>) return NotifEntry.fromJson(raw);
      return null;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // POST /driver/notifications/read-all → { "marked": n }
  Future<int> markAllRead() async {
    try {
      final raw = await _client.post<dynamic>(Endpoints.notificationsReadAll);
      if (raw is Map<String, dynamic>) {
        return raw['marked'] as int? ?? 0;
      }
      return 0;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
