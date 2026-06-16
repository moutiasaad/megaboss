import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';

class MbStatPill extends StatelessWidget {
  const MbStatPill({
    super.key,
    required this.value,
    required this.label,
    this.valueColor,
    this.onTap,
  });

  final String value;
  final String label;

  /// Number color: mbOk (green), mbErr (red), mbBlue (pending), or null (ink).
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? mbDarkSurface2 : mbSurface2;
    final border = isDark ? mbDarkLine : mbLine2;
    final numColor = valueColor ?? (isDark ? mbDarkInk : mbInk);
    final lblColor = isDark ? mbDarkInk3 : mbInk3;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: GoogleFonts.archivo(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: numColor,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: lblColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
