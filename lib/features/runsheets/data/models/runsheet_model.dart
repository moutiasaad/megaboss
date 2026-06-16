import '../../../shipments/data/models/shipment_model.dart';

// Runsheet (tournée) model — from GET /driver/runsheets/:id and /active
class RunsheetModel {
  const RunsheetModel({
    required this.id,
    required this.label,
    this.name = '',
    required this.status,
    required this.totalShipments,
    required this.deliveredCount,
    required this.failedCount,
    required this.pendingCount,
    required this.codTotal,
    this.notes,
    this.shipments = const [],
    this.createdAt,
    this.closedAt,
    this.warehouseId,
  });

  final int id;
  final String label; // reference chip: runsheet_number / reference / #id
  final String name;  // human title: json['label'] or json['name']
  final String status; // RunsheetStatus.*
  final int totalShipments;
  final int deliveredCount;
  final int failedCount;
  final int pendingCount;
  final double codTotal;
  final String? notes;
  final List<ShipmentModel> shipments;
  final DateTime? createdAt;
  final DateTime? closedAt;
  final int? warehouseId;

  bool get canClose => pendingCount == 0;
  bool get isActive => status == RunsheetStatus.inProgress;

  factory RunsheetModel.fromJson(Map<String, dynamic> json) {
    // /active returns a nested stats object; list endpoint uses flat fields.
    final s = json['stats'] as Map<String, dynamic>?;

    final total = json['total_shipments'] as int? ??
        s?['total'] as int? ??
        (json['shipments'] as List?)?.length ?? 0;
    final delivered = json['delivered_count'] as int? ??
        s?['delivered'] as int? ?? 0;
    final failed = json['returned_count'] as int? ??
        json['failed_count'] as int? ??
        s?['returned'] as int? ?? 0;
    final rescheduled = json['rescheduled_count'] as int? ??
        s?['rescheduled'] as int? ?? 0;

    return RunsheetModel(
      id: json['id'] as int,
      label: json['runsheet_number'] as String? ??
          json['reference'] as String? ??
          json['label'] as String? ??
          '#${json['id']}',
      name: json['label'] as String? ?? json['name'] as String? ?? '',
      status: _normalizeStatus(json['status'] as String?),
      totalShipments: total,
      deliveredCount: delivered,
      failedCount: failed,
      // in_progress count from nested stats is the most accurate "remaining".
      pendingCount: json['pending_count'] as int? ??
          s?['in_progress'] as int? ??
          (total - delivered - failed - rescheduled).clamp(0, total),
      // total_cod_amount (list) or stats.total_cod (active) — both may be String or num.
      codTotal: double.tryParse(
              '${json['total_cod_amount'] ?? s?['total_cod'] ?? json['cod_total'] ?? 0}') ??
          0.0,
      notes: json['notes'] as String?,
      shipments: (json['shipments'] as List<dynamic>?)
              ?.map((e) => ShipmentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      closedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : json['closed_at'] != null
              ? DateTime.tryParse(json['closed_at'] as String)
              : null,
      warehouseId: json['warehouse_id'] as int? ??
          (json['warehouse'] as Map<String, dynamic>?)?['id'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'name': name,
        'status': status,
        'total_shipments': totalShipments,
        'delivered_count': deliveredCount,
        'failed_count': failedCount,
        'pending_count': pendingCount,
        'cod_total': codTotal,
        'notes': notes,
        'shipments': shipments.map((s) => s.toJson()).toList(),
        'created_at': createdAt?.toIso8601String(),
        'closed_at': closedAt?.toIso8601String(),
        'warehouse_id': warehouseId,
      };

  RunsheetModel copyWith({
    String? status,
    int? deliveredCount,
    int? failedCount,
    int? pendingCount,
    List<ShipmentModel>? shipments,
    DateTime? closedAt,
  }) =>
      RunsheetModel(
        id: id,
        label: label,
        name: name,
        status: status ?? this.status,
        totalShipments: totalShipments,
        deliveredCount: deliveredCount ?? this.deliveredCount,
        failedCount: failedCount ?? this.failedCount,
        pendingCount: pendingCount ?? this.pendingCount,
        codTotal: codTotal,
        notes: notes,
        shipments: shipments ?? this.shipments,
        createdAt: createdAt,
        closedAt: closedAt ?? this.closedAt,
        warehouseId: warehouseId,
      );
}

abstract final class RunsheetStatus {
  static const String inProgress = 'in_progress';
  static const String closed = 'closed';
  static const String cancelled = 'cancelled';
}

// API may return "completed" or "terminated" for closed runsheets.
String _normalizeStatus(String? raw) => switch (raw) {
      'completed' || 'terminated' || 'done' => RunsheetStatus.closed,
      'in_progress' || 'active' => RunsheetStatus.inProgress,
      'cancelled' || 'canceled' => RunsheetStatus.cancelled,
      _ => raw ?? RunsheetStatus.inProgress,
    };
