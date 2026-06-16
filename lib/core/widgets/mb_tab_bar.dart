import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';

// ── Data ───────────────────────────────────────────────────────────────────────

enum MbTabIcon { home, runsheets, pickup, stats, profile }

class MbTab {
  const MbTab({
    required this.icon,
    required this.label,
    this.badge = 0,
  });

  final MbTabIcon icon;
  final String label;

  /// Red badge count. 0 = hidden. Uses dot for 1, pill for >1.
  final int badge;
}

// ── MbTabBar ───────────────────────────────────────────────────────────────────

class MbTabBar extends StatelessWidget {
  const MbTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<MbTab> items;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? mbDarkSurface : mbSurface;
    final border = isDark ? mbDarkLine : mbLine;
    final vPad = MediaQuery.viewPaddingOf(context).bottom;
    final bottomPad = vPad < 20 ? 20.0 : vPad;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border, width: 1)),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: 9, bottom: bottomPad),
        child: Row(
          children: items.asMap().entries.map((e) {
            return Expanded(
              child: _MbTabItem(
                tab: e.value,
                active: currentIndex == e.key,
                index: e.key,
                total: items.length,
                onTap: () => onTap(e.key),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Tab item ───────────────────────────────────────────────────────────────────

class _MbTabItem extends StatelessWidget {
  const _MbTabItem({
    required this.tab,
    required this.active,
    required this.index,
    required this.total,
    required this.onTap,
  });

  final MbTab tab;
  final bool active;
  final int index;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final disableAnim = MediaQuery.disableAnimationsOf(context);
    final targetColor = active ? mbBlue : mbInk3;

    return Semantics(
      button: true,
      selected: active,
      label: '${tab.label}, onglet${active ? ' sélectionné,' : ''} ${index + 1} sur $total',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 48,
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: targetColor),
            duration: disableAnim
                ? Duration.zero
                : const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            builder: (context, color, _) {
              final c = color ?? targetColor;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon with optional badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _TabIcon(icon: tab.icon, color: c, size: 21),
                      if (tab.badge > 0)
                        PositionedDirectional(
                          top: -4,
                          end: -5,
                          child: _Badge(count: tab.badge),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tab.label,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: c,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Badge ──────────────────────────────────────────────────────────────────────

class _Badge extends StatefulWidget {
  const _Badge({required this.count});
  final int count;

  @override
  State<_Badge> createState() => _BadgeState();
}

class _BadgeState extends State<_Badge> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..forward();
    _scale = Tween(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.count > 99 ? '99+' : '${widget.count}';
    final isDot = widget.count == 1;

    return ScaleTransition(
      scale: _scale,
      child: FadeTransition(
        opacity: _scale,
        child: isDot
            ? Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: mbRed,
                  shape: BoxShape.circle,
                ),
              )
            : Container(
                constraints: const BoxConstraints(minWidth: 16),
                height: 16,
                padding: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: mbRed,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
      ),
    );
  }
}

// ── Custom icon painter ────────────────────────────────────────────────────────

class _TabIcon extends StatelessWidget {
  const _TabIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  final MbTabIcon icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _IconPainter(icon: icon, color: color),
    );
  }
}

class _IconPainter extends CustomPainter {
  const _IconPainter({required this.icon, required this.color});

  final MbTabIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    switch (icon) {
      case MbTabIcon.home:
        _drawHome(canvas, paint, s);
      case MbTabIcon.runsheets:
        _drawRunsheets(canvas, paint, s);
      case MbTabIcon.pickup:
        _drawPickup(canvas, paint, s);
      case MbTabIcon.stats:
        _drawStats(canvas, paint, s);
      case MbTabIcon.profile:
        _drawProfile(canvas, paint, s);
    }
  }

  // Maison — toit + corps
  void _drawHome(Canvas canvas, Paint p, double s) {
    // Roof: M3 10.5 L12 3 L21 10.5
    canvas.drawPath(
      Path()
        ..moveTo(3 * s, 10.5 * s)
        ..lineTo(12 * s, 3 * s)
        ..lineTo(21 * s, 10.5 * s),
      p,
    );
    // Body: M5 9.5 V20 H19 V9.5
    canvas.drawPath(
      Path()
        ..moveTo(5 * s, 9.5 * s)
        ..lineTo(5 * s, 20 * s)
        ..lineTo(19 * s, 20 * s)
        ..lineTo(19 * s, 9.5 * s),
      p,
    );
  }

  // Runsheets — feuille avec 3 lignes
  void _drawRunsheets(Canvas canvas, Paint p, double s) {
    // Frame: rect x4 y3 w16 h18 rx2
    canvas.drawRRect(
      RRect.fromLTRBR(4 * s, 3 * s, 20 * s, 21 * s, Radius.circular(2 * s)),
      p,
    );
    // Lines: M8 8 H16 · M8 12 H16 · M8 16 H13
    canvas.drawLine(Offset(8 * s, 8 * s), Offset(16 * s, 8 * s), p);
    canvas.drawLine(Offset(8 * s, 12 * s), Offset(16 * s, 12 * s), p);
    canvas.drawLine(Offset(8 * s, 16 * s), Offset(13 * s, 16 * s), p);
  }

  // Pickup — camion de livraison
  void _drawPickup(Canvas canvas, Paint p, double s) {
    // Cargo box: M3 7 H16 V17 H3 Z
    canvas.drawPath(
      Path()
        ..moveTo(3 * s, 7 * s)
        ..lineTo(16 * s, 7 * s)
        ..lineTo(16 * s, 17 * s)
        ..lineTo(3 * s, 17 * s)
        ..close(),
      p,
    );
    // Cab: M16 10 H19 L21 13 V17 H16
    canvas.drawPath(
      Path()
        ..moveTo(16 * s, 10 * s)
        ..lineTo(19 * s, 10 * s)
        ..lineTo(21 * s, 13 * s)
        ..lineTo(21 * s, 17 * s)
        ..lineTo(16 * s, 17 * s),
      p,
    );
    // Wheels
    canvas.drawCircle(Offset(7 * s, 18 * s), 1.6 * s, p);
    canvas.drawCircle(Offset(17.5 * s, 18 * s), 1.6 * s, p);
  }

  // Stats — barres verticales
  void _drawStats(Canvas canvas, Paint p, double s) {
    // Bars: M4 20 V10 · M10 20 V4 · M16 20 V13
    canvas.drawLine(Offset(4 * s, 20 * s), Offset(4 * s, 10 * s), p);
    canvas.drawLine(Offset(10 * s, 20 * s), Offset(10 * s, 4 * s), p);
    canvas.drawLine(Offset(16 * s, 20 * s), Offset(16 * s, 13 * s), p);
    // Base: M22 20 H2
    canvas.drawLine(Offset(22 * s, 20 * s), Offset(2 * s, 20 * s), p);
  }

  // Profil — tête + épaules
  void _drawProfile(Canvas canvas, Paint p, double s) {
    // Head: circle cx12 cy8 r3.4
    canvas.drawCircle(Offset(12 * s, 8 * s), 3.4 * s, p);
    // Shoulders: M5 20 c0-3.5 3-6 7-6 s7 2.5 7 6
    // SVG smooth cubic → Flutter cubicTo pairs
    canvas.drawPath(
      Path()
        ..moveTo(5 * s, 20 * s)
        // c0-3.5 3-6 7-6 → cubic (5,16.5) (8,14) (12,14)
        ..cubicTo(5 * s, 16.5 * s, 8 * s, 14 * s, 12 * s, 14 * s)
        // s7 2.5 7 6 → smooth: reflected cp=(16,14), cp2=(19,16.5), end=(19,20)
        ..cubicTo(16 * s, 14 * s, 19 * s, 16.5 * s, 19 * s, 20 * s),
      p,
    );
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.color != color || old.icon != icon;
}
