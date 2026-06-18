import '../../../shipments/data/models/shipment_model.dart';

// Pickup manifest — from GET /driver/pickups/:id and GET /driver/pickups/active
class PickupModel {
  const PickupModel({
    required this.id,
    required this.manifestNumber,
    required this.senderName,
    this.senderAddress,
    this.senderPhone,
    required this.status,
    required this.totalShipments,
    required this.collectedCount,
    this.shipments = const [],
  });

  final int id;
  final String manifestNumber;
  final String senderName;
  final String? senderAddress;
  final String? senderPhone;
  final String status; // PickupStatus.*
  final int totalShipments;
  final int collectedCount;
  final List<PickupShipmentModel> shipments;

  int get pendingCount => totalShipments - collectedCount;

  factory PickupModel.fromJson(Map<String, dynamic> json) {
    // API nests sender info under business_owner and counts under stats.
    final owner = json['business_owner'] as Map<String, dynamic>?;
    final stats = json['stats'] as Map<String, dynamic>?;
    return PickupModel(
      id: json['id'] as int,
      manifestNumber: json['manifest_number'] as String? ??
          json['reference'] as String? ?? '#${json['id']}',
      senderName: owner?['name'] as String? ??
          json['sender_name'] as String? ??
          json['sender'] as String? ?? '',
      senderAddress: owner?['address'] as String? ??
          json['sender_address'] as String?,
      senderPhone: owner?['phone'] as String? ??
          json['sender_phone'] as String?,
      status: json['status'] as String? ?? PickupStatus.pending,
      totalShipments: stats?['total'] as int? ??
          json['total_shipments'] as int? ?? 0,
      collectedCount: stats?['accepted'] as int? ??
          json['collected_count'] as int? ?? 0,
      shipments: (json['shipments'] as List<dynamic>?)
              ?.map((e) => PickupShipmentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'manifest_number': manifestNumber,
        'sender_name': senderName,
        'sender_address': senderAddress,
        'sender_phone': senderPhone,
        'status': status,
        'total_shipments': totalShipments,
        'collected_count': collectedCount,
        'shipments': shipments.map((e) => e.toJson()).toList(),
      };

  PickupModel copyWith({
    int? collectedCount,
    String? status,
    List<PickupShipmentModel>? shipments,
  }) =>
      PickupModel(
        id: id,
        manifestNumber: manifestNumber,
        senderName: senderName,
        senderAddress: senderAddress,
        senderPhone: senderPhone,
        status: status ?? this.status,
        totalShipments: totalShipments,
        collectedCount: collectedCount ?? this.collectedCount,
        shipments: shipments ?? this.shipments,
      );
}

// Lightweight shipment row inside a manifest list
class PickupShipmentModel {
  const PickupShipmentModel({
    required this.id,
    required this.trackingNumber,
    this.barcode = '',
    required this.status,
    this.codAmount,
    this.recipientName,
    this.designation,
    this.collectedAt,
    this.refuseReason,
  });

  final int id;
  final String trackingNumber;
  final String barcode;
  final String status; // PickupShipmentStatus.*
  final double? codAmount;
  final String? recipientName;
  final String? designation;
  final DateTime? collectedAt;  // optimistic local timestamp
  final String? refuseReason;   // optimistic local reason

  bool matchesCode(String code) {
    final c = code.trim();
    if (c.isEmpty) return false;
    return trackingNumber.trim() == c || barcode.trim() == c;
  }

  factory PickupShipmentModel.fromJson(Map<String, dynamic> json) {
    // API nests recipient under json['recipient']['name']
    final recipient = json['recipient'] as Map<String, dynamic>?;
    return PickupShipmentModel(
      id: json['id'] as int,
      trackingNumber: json['tracking_number'] as String? ??
          json['code'] as String? ??
          json['barcode'] as String? ?? '',
      barcode: json['barcode'] as String? ?? '',
      status: json['pickup_status'] as String? ??
          json['status'] as String? ??
          PickupShipmentStatus.pending,
      // API returns cod_amount as a String ("161.00"), not a number.
      codAmount: double.tryParse(
          '${json['cod_amount'] ?? json['prix'] ?? ''}'),
      recipientName: recipient?['name'] as String? ??
          json['recipient_name'] as String? ??
          json['nom'] as String?,
      designation: json['package_description'] as String? ??
          json['designation'] as String?,
      collectedAt: json['collected_at'] != null
          ? DateTime.tryParse(json['collected_at'] as String)
          : null,
      refuseReason: json['refuse_reason'] as String? ??
          json['refuse_comment'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tracking_number': trackingNumber,
        'barcode': barcode,
        'pickup_status': status,
        'cod_amount': codAmount,
        'recipient_name': recipientName,
        'designation': designation,
        if (collectedAt != null) 'collected_at': collectedAt!.toIso8601String(),
        if (refuseReason != null) 'refuse_reason': refuseReason,
      };

  // Inflate to full ShipmentModel when navigating to detail
  ShipmentModel toShipment() => ShipmentModel(
        id: id,
        trackingNumber: trackingNumber,
        barcode: barcode,
        status: status,
        recipientName: recipientName ?? '',
        address: '',
        city: '',
        codAmount: codAmount,
        designation: designation,
      );

  PickupShipmentModel copyWith({
    String? status,
    DateTime? collectedAt,
    String? refuseReason,
  }) =>
      PickupShipmentModel(
        id: id,
        trackingNumber: trackingNumber,
        barcode: barcode,
        status: status ?? this.status,
        codAmount: codAmount,
        recipientName: recipientName,
        designation: designation,
        collectedAt: collectedAt ?? this.collectedAt,
        refuseReason: refuseReason ?? this.refuseReason,
      );
}

abstract final class PickupStatus {
  static const String pending = 'pending';
  static const String inProgress = 'in_progress';
  static const String completed = 'completed';
  static const String upcoming = 'upcoming';
}

abstract final class PickupShipmentStatus {
  static const String pending = 'pending';
  static const String collected = 'collected';
  static const String refused = 'refused';
}
