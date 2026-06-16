import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../models/notif_entry.dart';

class NotificationService {
  const NotificationService(this._client);
  final ApiClient _client;

  // GET /driver/notifications
  Future<List<NotifEntry>> fetchAll() async {
    try {
      final raw = await _client.get<dynamic>(Endpoints.notifications);
      debugPrint('[NotifService.fetchAll] raw type=${raw.runtimeType} value=$raw');
      // Handle: null → [], List → map directly, paginated Map → extract 'data'
      final List<dynamic> list = switch (raw) {
        null => [],
        final List<dynamic> l => l,
        final Map<dynamic, dynamic> m =>
          (m['data'] ?? m['notifications'] ?? m['items'] ?? []) as List<dynamic>,
        _ => [],
      };
      return list
          .whereType<Map<String, dynamic>>()
          .map(NotifEntry.fromJson)
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // POST /driver/notifications/{id}/read
  Future<void> markRead(int id) async {
    try {
      await _client.dio.post<void>(Endpoints.notificationRead(id));
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // POST /driver/notifications/read-all
  Future<void> markAllRead() async {
    try {
      await _client.dio.post<void>(Endpoints.notificationsReadAll);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
