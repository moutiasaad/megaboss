// A single driver→client call log entry.
// Synced to POST /driver/calls/sync ; listed via GET /driver/shipments/:id/calls
class CallLogModel {
  const CallLogModel({
    required this.id,
    required this.rawLogId,
    required this.phoneNumber,
    required this.durationSeconds,
    required this.startedAt,
    required this.type,
    required this.result,
    this.manual = false,
    this.shipmentId,
    this.recipientName,
  });

  final int id;
  final String rawLogId; // Android/iOS native call log ID (idempotency key)
  final String phoneNumber;
  final int durationSeconds;
  final DateTime startedAt;
  final String type; // CallType.*
  final String result; // CallResult.*
  final bool manual; // true = driver manually entered the result (iOS)
  final int? shipmentId;
  final String? recipientName;

  factory CallLogModel.fromJson(Map<String, dynamic> json) => CallLogModel(
        id: json['id'] as int? ?? 0,
        rawLogId: json['raw_log_id'] as String,
        phoneNumber: json['phone_number'] as String,
        durationSeconds: json['duration_seconds'] as int? ?? 0,
        startedAt: DateTime.parse(json['started_at'] as String),
        type: json['type'] as String,
        result: json['result'] as String,
        manual: json['manual'] as bool? ?? false,
        shipmentId: json['shipment_id'] as int?,
        recipientName: json['recipient_name'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'raw_log_id': rawLogId,
        'phone_number': phoneNumber,
        'duration_seconds': durationSeconds,
        'started_at': startedAt.toIso8601String(),
        'type': type,
        'result': result,
        'manual': manual,
        'shipment_id': shipmentId,
        'recipient_name': recipientName,
      };

  // Shape expected by POST /driver/calls/sync (calls[])
  Map<String, dynamic> toSyncPayload() => {
        'raw_log_id': rawLogId,
        'phone_number': phoneNumber,
        'duration_seconds': durationSeconds,
        'started_at': startedAt.toIso8601String(),
        'type': type,
        'result': result,
        'manual': manual,
      };
}

abstract final class CallType {
  static const String outgoing = 'outgoing';
  static const String incoming = 'incoming';
  static const String missed = 'missed';
}

abstract final class CallResult {
  static const String reached = 'reached';
  static const String noAnswer = 'no_answer';
  static const String unreachable = 'unreachable';
}
