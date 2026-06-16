import 'package:flutter/material.dart';
import '../theme/colors.dart';

class MbTriProgress extends StatelessWidget {
  const MbTriProgress({
    super.key,
    required this.delivered,
    required this.failed,
    required this.total,
    this.semanticLabel,
  });

  final int delivered;
  final int failed;
  final int total;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final disableAnim = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: semanticLabel,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: disableAnim
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        builder: (context, t, _) {
          return LayoutBuilder(
            builder: (ctx, constraints) {
              final isDark =
                  Theme.of(ctx).brightness == Brightness.dark;
              final trackColor = isDark ? mbDarkLine : mbSurface3;
              final w = constraints.maxWidth;
              final dPct = total > 0 ? delivered / total : 0.0;
              final fPct = total > 0 ? failed / total : 0.0;
              final dW = (w * dPct * t).clamp(0.0, w);
              final fW = (w * fPct * t).clamp(0.0, w - dW);
              final rW = (w - dW - fW).clamp(0.0, w);

              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 9,
                  child: Row(
                    children: [
                      if (dW > 0) Container(width: dW, color: mbOk),
                      if (fW > 0) Container(width: fW, color: mbErr),
                      if (rW > 0) Container(width: rW, color: trackColor),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
