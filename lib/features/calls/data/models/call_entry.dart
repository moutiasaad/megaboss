// CallEntry: one row in the calls history screen.
// CallFilter: the 4 filter tabs (all / joined / noAnswer / unreachable).
// CallsState: value held by CallsHistoryController.

enum CallFilter { all, joined, noAnswer, unreachable }

extension CallFilterApi on CallFilter {
  String get apiValue => switch (this) {
        CallFilter.all => 'all',
        CallFilter.joined => 'joined',
        CallFilter.noAnswer => 'no_answer',
        CallFilter.unreachable => 'unreachable',
      };
}

class CallEntry {
  const CallEntry({
    required this.id,
    required this.recipient,
    required this.tracking,
    this.shipmentId,
    required this.result,
    required this.time,
    required this.duration,
    required this.phone,
  });

  final int id;
  final String recipient; // "Yasmine El Fassi"
  final String tracking;  // "MB-…0142"
  final int? shipmentId;
  final String result;    // CallResult.reached | noAnswer | unreachable
  final String time;      // "08:50"
  final String duration;  // "1:42"
  final String phone;

  factory CallEntry.fromJson(Map<String, dynamic> json) {
    // Derive display time from ISO timestamp if the `time` field is absent.
    String time = json['time'] as String? ?? '';
    if (time.isEmpty) {
      final raw = json['started_at'] as String?;
      if (raw != null) {
        try {
          final dt = DateTime.parse(raw).toLocal();
          time =
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } catch (_) {}
      }
    }

    // Derive m:ss duration from seconds if the `duration` field is absent.
    String duration = json['duration'] as String? ?? '';
    if (duration.isEmpty) {
      final sec = json['duration_seconds'] as int? ?? 0;
      final m = sec ~/ 60;
      final s = sec % 60;
      duration = '$m:${s.toString().padLeft(2, '0')}';
    }

    return CallEntry(
      id: json['id'] as int? ?? 0,
      recipient: json['recipient'] as String? ??
          json['recipient_name'] as String? ??
          'Numéro inconnu',
      tracking: json['tracking'] as String? ??
          json['tracking_number'] as String? ??
          '',
      shipmentId: json['shipment_id'] as int?,
      result: json['result'] as String? ?? 'no_answer',
      time: time,
      duration: duration,
      phone: json['phone'] as String? ??
          json['phone_number'] as String? ??
          '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipient': recipient,
        'tracking': tracking,
        'shipment_id': shipmentId,
        'result': result,
        'time': time,
        'duration': duration,
        'phone': phone,
      };
}

class CallsState {
  const CallsState({
    required this.filter,
    required this.items,
    this.offline = false,
  });

  final CallFilter filter;
  final List<CallEntry> items;
  final bool offline;

  CallsState copyWith({
    CallFilter? filter,
    List<CallEntry>? items,
    bool? offline,
  }) =>
      CallsState(
        filter: filter ?? this.filter,
        items: items ?? this.items,
        offline: offline ?? this.offline,
      );
}
