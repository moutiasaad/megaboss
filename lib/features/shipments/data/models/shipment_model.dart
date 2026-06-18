// Full shipment / colis model — from GET /driver/shipments/:id
// Also embedded in RunsheetModel.shipments and PickupModel.shipments.

class ShipmentModel {
  const ShipmentModel({
    required this.id,
    required this.trackingNumber,
    required this.barcode,
    required this.status,
    required this.recipientName,
    this.recipientPhone,
    this.recipientPhone2,
    required this.address,
    required this.city,
    this.governorate,
    this.codAmount,
    this.designation,
    this.notes,
    this.requiresSignature = false,
    this.requiresPhoto = false,
    this.requiresOpen = false,
    this.isFragile = false,
    this.nbArticles = 1,
    this.timeline = const [],
    this.senderName,
    this.etaMin,
    this.distanceKm,
  });

  final int id;
  final String trackingNumber;
  final String barcode;
  final String status; // ShipmentStatus.*
  final String recipientName;
  final String? recipientPhone;
  final String? recipientPhone2;
  final String address;
  final String city;
  final String? governorate;
  final double? codAmount;
  final String? designation;
  final String? notes;
  final bool requiresSignature;
  final bool requiresPhoto;
  final bool requiresOpen;
  final bool isFragile;
  final int nbArticles;
  final List<TimelineEventModel> timeline;
  final String? senderName;
  final int? etaMin;
  final double? distanceKm;

  bool get hasCod => codAmount != null && codAmount! > 0;

  factory ShipmentModel.fromJson(Map<String, dynamic> json) {
    // recipient may be a nested object {"name","phone","phone_2"} or flat fields.
    final recipient = json['recipient'] as Map<String, dynamic>?;
    // address may be a nested object {"line","governorate","city",...} or a flat String.
    final addrRaw = json['address'];
    final addrMap = addrRaw is Map<String, dynamic> ? addrRaw : null;
    final addrStr = addrRaw is String ? addrRaw : null;
    // business_owner may be nested for sender info.
    final owner = json['business_owner'] as Map<String, dynamic>?;

    return ShipmentModel(
      id: json['id'] as int,
      trackingNumber: json['tracking_number'] as String? ?? json['code'] as String? ?? '',
      barcode: json['barcode'] as String? ?? '',
      status: json['status'] as String? ?? ShipmentStatus.receivedAtDepot,
      recipientName: recipient?['name'] as String? ??
          json['recipient_name'] as String? ?? json['nom'] as String? ?? '',
      recipientPhone: recipient?['phone'] as String? ??
          json['recipient_phone'] as String? ?? json['tel'] as String?,
      recipientPhone2: recipient?['phone_2'] as String? ??
          json['recipient_phone2'] as String? ?? json['tel2'] as String?,
      address: addrStr ?? addrMap?['line'] as String? ?? json['adresse'] as String? ?? '',
      city: addrMap?['city'] as String? ??
          json['city'] as String? ?? json['ville'] as String? ?? '',
      governorate: addrMap?['governorate'] as String? ??
          json['governorate'] as String? ?? json['gouvernerat'] as String?,
      // cod_amount comes as a String ("253.00") from the API.
      codAmount: double.tryParse('${json['cod_amount'] ?? json['prix'] ?? ''}'),
      designation: json['package_description'] as String? ??
          json['designation'] as String?,
      notes: json['notes'] as String? ?? json['msg'] as String?,
      requiresSignature: json['requires_signature'] as bool? ?? false,
      requiresPhoto: json['requires_photo'] as bool? ?? false,
      requiresOpen: json['requires_open'] as bool? ??
          (json['ouvrir'] as String?)?.toLowerCase() == 'oui',
      isFragile: json['is_fragile'] as bool? ??
          (json['fragile'] as String?) == '1',
      nbArticles: json['nb_articles'] as int? ?? json['nb_article'] as int? ?? 1,
      timeline: (json['timeline'] as List<dynamic>?)
              ?.map((e) => TimelineEventModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      senderName: owner?['name'] as String? ?? json['sender_name'] as String?,
      etaMin: json['eta_min'] as int? ?? json['eta_minutes'] as int?,
      distanceKm: double.tryParse('${json['distance_km'] ?? json['distance'] ?? ''}'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tracking_number': trackingNumber,
        'barcode': barcode,
        'status': status,
        'recipient_name': recipientName,
        'recipient_phone': recipientPhone,
        'recipient_phone2': recipientPhone2,
        'address': address,
        'city': city,
        'governorate': governorate,
        'cod_amount': codAmount,
        'designation': designation,
        'notes': notes,
        'requires_signature': requiresSignature,
        'requires_photo': requiresPhoto,
        'requires_open': requiresOpen,
        'is_fragile': isFragile,
        'nb_articles': nbArticles,
        'timeline': timeline.map((e) => e.toJson()).toList(),
        'sender_name': senderName,
        'eta_min': etaMin,
        'distance_km': distanceKm,
      };

  ShipmentModel copyWith({String? status}) => ShipmentModel(
        id: id,
        trackingNumber: trackingNumber,
        barcode: barcode,
        status: status ?? this.status,
        recipientName: recipientName,
        recipientPhone: recipientPhone,
        recipientPhone2: recipientPhone2,
        address: address,
        city: city,
        governorate: governorate,
        codAmount: codAmount,
        designation: designation,
        notes: notes,
        requiresSignature: requiresSignature,
        requiresPhoto: requiresPhoto,
        requiresOpen: requiresOpen,
        isFragile: isFragile,
        nbArticles: nbArticles,
        timeline: timeline,
        senderName: senderName,
        etaMin: etaMin,
        distanceKm: distanceKm,
      );
}

// Shipment status machine:
//   received_at_depot → picked_up → delivered | failed | returned
abstract final class ShipmentStatus {
  static const String receivedAtDepot = 'received_at_depot';
  static const String pickedUp = 'picked_up';
  static const String delivered = 'delivered';
  static const String failed = 'failed';
  static const String returned = 'returned';

  static bool isTerminal(String status) =>
      status == delivered || status == returned;

  static bool canDeliver(String status) => status == pickedUp;
  static bool canFail(String status) => status == pickedUp;
}

class TimelineEventModel {
  const TimelineEventModel({
    required this.status,
    required this.label,
    required this.timestamp,
    this.comment,
    this.author,
  });

  final String status;
  final String label;
  final DateTime timestamp;
  final String? comment;
  final String? author;

  factory TimelineEventModel.fromJson(Map<String, dynamic> json) => TimelineEventModel(
        status: json['status'] as String,
        label: json['label'] as String? ?? json['status'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String? ?? json['created_at'] as String),
        comment: json['comment'] as String?,
        author: json['author'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'status': status,
        'label': label,
        'timestamp': timestamp.toIso8601String(),
        'comment': comment,
        'author': author,
      };
}
