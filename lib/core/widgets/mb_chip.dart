import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

enum MbChipVariant { red, blue }

class MbChip extends StatelessWidget {
  const MbChip({
    super.key,
    required this.label,
    this.variant = MbChipVariant.blue,
  });

  const MbChip.red({super.key, required this.label})
      : variant = MbChipVariant.red;

  const MbChip.blue({super.key, required this.label})
      : variant = MbChipVariant.blue;

  final String label;
  final MbChipVariant variant;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bg;
    final Color fg;
    final Color border;

    if (variant == MbChipVariant.red) {
      bg = isDark ? const Color(0xFF3D0000) : mbErrBg;
      fg = mbRed;
      border = mbRed.withAlpha(0x55);
    } else {
      bg = isDark ? const Color(0xFF001E45) : mbBlue050;
      fg = mbBlue;
      border = mbBlue.withAlpha(0x55);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(MbRadius.chip),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.splineSansMono(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
