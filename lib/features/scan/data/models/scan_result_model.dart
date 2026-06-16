import '../../../shipments/data/models/shipment_model.dart';

// Response from POST /driver/scan/delivery and POST /driver/scan/pickup
class ScanResultModel {
  const ScanResultModel({
    required this.success,
    this.requiresConfirmation,
    this.codAmount,
    this.shipment,
    this.message,
    this.alreadyScanned = false,
  });

  final bool success;

  // Two-phase COD: server returns true when it needs cod_collected confirmation.
  // Driver re-sends same barcode with cod_collected=true|false.
  final bool? requiresConfirmation;

  final double? codAmount;
  final ShipmentModel? shipment;
  final String? message;

  // Idempotent re-scan — barcode was already processed.
  final bool alreadyScanned;

  factory ScanResultModel.fromJson(Map<String, dynamic> json) => ScanResultModel(
        success: json['success'] as bool? ?? json['status'] == 'ok',
        requiresConfirmation: json['requires_confirmation'] as bool?,
        codAmount: (json['cod_amount'] as num?)?.toDouble(),
        shipment: json['shipment'] != null
            ? ShipmentModel.fromJson(json['shipment'] as Map<String, dynamic>)
            : null,
        message: json['message'] as String?,
        alreadyScanned: json['already_scanned'] as bool? ?? false,
      );
}

// Payload for a single item in POST /driver/scan/batch operations array
class BatchScanItem {
  const BatchScanItem({
    required this.type,
    required this.barcode,
    required this.clientOperationId,
    this.status,
    this.comment,
    this.rescheduleDate,
    this.scannedAt,
    this.codCollected,
  });

  final String type; // 'pickup' | 'delivery'
  final String barcode;
  final String clientOperationId;
  final String? status; // for delivery: ShipmentStatus.*
  final String? comment;
  final String? rescheduleDate; // ISO date
  final String? scannedAt; // ISO datetime
  final bool? codCollected;

  Map<String, dynamic> toJson() => {
        'type': type,
        'barcode': barcode,
        'client_operation_id': clientOperationId,
        if (status != null) 'status': status,
        if (comment != null) 'comment': comment,
        if (rescheduleDate != null) 'reschedule_date': rescheduleDate,
        if (scannedAt != null) 'scanned_at': scannedAt,
        if (codCollected != null) 'cod_collected': codCollected,
      };
}
