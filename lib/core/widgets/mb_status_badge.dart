import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

// Status string constants (mirrors RunsheetStatus without creating a dependency).
abstract final class _S {
  static const inProgress = 'in_progress';
  static const closed = 'closed';
  static const cancelled = 'cancelled';
}

class MbStatusBadge extends StatelessWidget {
  const MbStatusBadge({
    super.key,
    required this.status,
    required this.label,
  });

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sc = Theme.of(context).extension<MbStatusColors>();

    final Color dot;
    final Color text;
    final Color bg;

    switch (status) {
      case _S.inProgress:
        dot = sc?.pend ?? mbPend;
        text = sc?.pend ?? mbPend;
        bg = sc?.pendBg ?? mbPendBg;
      case _S.closed:
        dot = sc?.ok ?? mbOk;
        text = sc?.ok ?? mbOk;
        bg = sc?.okBg ?? mbOkBg;
      case _S.cancelled:
        dot = isDark ? mbDarkInk3 : mbInk3;
        text = isDark ? mbDarkInk2 : mbInk2;
        bg = isDark ? mbDarkSurface2 : mbSurface3;
      default:
        dot = sc?.pend ?? mbPend;
        text = sc?.pend ?? mbPend;
        bg = sc?.pendBg ?? mbPendBg;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: MbSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(MbRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: text,
            ),
          ),
        ],
      ),
    );
  }
}
