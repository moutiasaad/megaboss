// NotifEntry: one row in the notifications screen.
// NotifType: icon + colour category.
// NotifState: value held by NotificationsController.

enum NotifType {
  runsheetNew,
  runsheetClosed,
  pickupNew,
  shipmentAdded,
  system,
}

extension NotifTypeApi on NotifType {
  static NotifType fromString(String? raw) => switch (raw) {
        'runsheet_new' => NotifType.runsheetNew,
        'runsheet_closed' => NotifType.runsheetClosed,
        'pickup_new' => NotifType.pickupNew,
        'shipment_added' => NotifType.shipmentAdded,
        _ => NotifType.system,
      };

  String get apiValue => switch (this) {
        NotifType.runsheetNew => 'runsheet_new',
        NotifType.runsheetClosed => 'runsheet_closed',
        NotifType.pickupNew => 'pickup_new',
        NotifType.shipmentAdded => 'shipment_added',
        NotifType.system => 'system',
      };
}

class NotifEntry {
  const NotifEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.read,
    this.deeplink,
  });

  final int id;
  final NotifType type;
  final String title;
  final String subtitle; // pre-formatted context + timestamp
  final DateTime timestamp;
  final bool read;
  final String? deeplink; // e.g. "/runsheets/2049"

  NotifEntry copyWith({bool? read}) => NotifEntry(
        id: id,
        type: type,
        title: title,
        subtitle: subtitle,
        timestamp: timestamp,
        read: read ?? this.read,
        deeplink: deeplink,
      );

  factory NotifEntry.fromJson(Map<String, dynamic> json) => NotifEntry(
        id: json['id'] as int? ?? 0,
        type: NotifTypeApi.fromString(json['type'] as String?),
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ??
            json['body'] as String? ??
            '',
        timestamp: DateTime.tryParse(json['timestamp'] as String? ??
                json['created_at'] as String? ??
                '') ??
            DateTime.now(),
        read: json['read'] as bool? ?? json['read_at'] != null,
        deeplink: json['deeplink'] as String? ?? _buildDeeplink(json),
      );

  static String? _buildDeeplink(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    final refId = json['ref_id'] as int?;
    if (refId == null) return null;
    return switch (type) {
      'runsheet_new' || 'runsheet_closed' => '/runsheets/$refId',
      'pickup_new' => '/pickups/$refId',
      'shipment_added' => '/shipments/$refId',
      _ => null,
    };
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.apiValue,
        'title': title,
        'subtitle': subtitle,
        'timestamp': timestamp.toIso8601String(),
        'read': read,
        'deeplink': deeplink,
      };
}

class NotifState {
  const NotifState({
    required this.items,
    this.unread = 0,
    this.offline = false,
  });

  final List<NotifEntry> items;
  final int unread;
  final bool offline;

  NotifState copyWith({
    List<NotifEntry>? items,
    int? unread,
    bool? offline,
  }) =>
      NotifState(
        items: items ?? this.items,
        unread: unread ?? this.unread,
        offline: offline ?? this.offline,
      );
}
