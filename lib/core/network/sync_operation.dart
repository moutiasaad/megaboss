// Model for a single offline operation stored in the Hive queue.
// Idempotent on [clientOperationId] (UUID v4).
// Operation types from the API spec:
//   scan_delivery | scan_pickup | status_update | call_log | location_ping
class SyncOperation {
  const SyncOperation({
    required this.clientOperationId,
    required this.type,
    required this.payload,
    required this.clientTimestamp,
    this.synced = false,
    this.retryCount = 0,
  });

  final String clientOperationId;
  final String type; // SyncOperationType.*
  final Map<String, dynamic> payload;
  final DateTime clientTimestamp;
  final bool synced;
  final int retryCount;

  // Max retries before the operation is dropped from the queue.
  static const int maxRetries = 5;

  factory SyncOperation.fromJson(Map<String, dynamic> json) => SyncOperation(
        clientOperationId: json['client_operation_id'] as String,
        type: json['type'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        clientTimestamp: DateTime.parse(json['client_timestamp'] as String),
        synced: json['synced'] as bool? ?? false,
        retryCount: json['retry_count'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'client_operation_id': clientOperationId,
        'type': type,
        'payload': payload,
        'client_timestamp': clientTimestamp.toIso8601String(),
        'synced': synced,
        'retry_count': retryCount,
      };

  // Shape expected by POST /driver/sync
  Map<String, dynamic> toApiPayload() => {
        'client_operation_id': clientOperationId,
        'type': type,
        'payload': payload,
        'client_timestamp': clientTimestamp.toIso8601String(),
      };

  SyncOperation copyWith({
    bool? synced,
    int? retryCount,
  }) =>
      SyncOperation(
        clientOperationId: clientOperationId,
        type: type,
        payload: payload,
        clientTimestamp: clientTimestamp,
        synced: synced ?? this.synced,
        retryCount: retryCount ?? this.retryCount,
      );
}

abstract final class SyncOperationType {
  static const String scanDelivery = 'scan_delivery';
  static const String scanPickup = 'scan_pickup';
  static const String statusUpdate = 'status_update';
  static const String callLog = 'call_log';
  static const String locationPing = 'location_ping';
}
