// Reason items shown when a driver fails/returns a delivery or refuses a
// pickup — comes from GET /driver/motifs.
//
// Server contract:
//   {
//     "success": true,
//     "data": {
//       "return_reasons":  [ { "value": "...", "emoji": "📞" }, ... ],
//       "refusal_reasons": [ { "value": "...", "emoji": "📦" }, ... ]
//     }
//   }
//
// The `value` field is the human-readable French label AND the string the API
// expects back in the comment/refuse_reason payload — the web app sends the
// label verbatim, the mobile app must match.

class MotifModel {
  const MotifModel({required this.value, this.emoji});

  final String value;
  final String? emoji;

  factory MotifModel.fromJson(Map<String, dynamic> json) => MotifModel(
        value: json['value'] as String? ?? '',
        emoji: json['emoji'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'value': value,
        if (emoji != null) 'emoji': emoji,
      };
}

class MotifsModel {
  const MotifsModel({
    this.returnReasons = const [],
    this.refusalReasons = const [],
  });

  final List<MotifModel> returnReasons;
  final List<MotifModel> refusalReasons;

  static const empty = MotifsModel();

  factory MotifsModel.fromJson(Map<String, dynamic> json) {
    List<MotifModel> parseList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(MotifModel.fromJson)
          .where((m) => m.value.isNotEmpty)
          .toList(growable: false);
    }

    return MotifsModel(
      returnReasons: parseList(json['return_reasons']),
      refusalReasons: parseList(json['refusal_reasons']),
    );
  }

  Map<String, dynamic> toJson() => {
        'return_reasons': returnReasons.map((m) => m.toJson()).toList(),
        'refusal_reasons': refusalReasons.map((m) => m.toJson()).toList(),
      };
}
