import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';

class MbFab extends StatelessWidget {
  const MbFab({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Color(0x8CEE0101),
            blurRadius: 24,
            spreadRadius: -8,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        backgroundColor: mbRed,
        elevation: 0,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: CustomPaint(
          size: const Size(18, 18),
          painter: const MbScanIconPainter(color: Colors.white),
        ),
        label: Text(
          label,
          style: GoogleFonts.archivo(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── Scan / viewfinder icon ─────────────────────────────────────────────────────
// 4 open corner brackets + horizontal center line, viewBox 24×24.

class MbScanIconPainter extends CustomPainter {
  const MbScanIconPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.8 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    const l = 3.0;   // frame left/top
    const r = 21.0;  // frame right/bottom
    const arm = 6.0; // corner arm length
    const mid = 12.0;

    // Top-left corner
    canvas.drawPath(
      Path()
        ..moveTo((l + arm) * s, l * s)
        ..lineTo(l * s, l * s)
        ..lineTo(l * s, (l + arm) * s),
      p,
    );
    // Top-right corner
    canvas.drawPath(
      Path()
        ..moveTo((r - arm) * s, l * s)
        ..lineTo(r * s, l * s)
        ..lineTo(r * s, (l + arm) * s),
      p,
    );
    // Bottom-left corner
    canvas.drawPath(
      Path()
        ..moveTo(l * s, (r - arm) * s)
        ..lineTo(l * s, r * s)
        ..lineTo((l + arm) * s, r * s),
      p,
    );
    // Bottom-right corner
    canvas.drawPath(
      Path()
        ..moveTo(r * s, (r - arm) * s)
        ..lineTo(r * s, r * s)
        ..lineTo((r - arm) * s, r * s),
      p,
    );
    // Center horizontal scan line
    canvas.drawLine(Offset(l * s, mid * s), Offset(r * s, mid * s), p);
  }

  @override
  bool shouldRepaint(MbScanIconPainter old) => old.color != color;
}
