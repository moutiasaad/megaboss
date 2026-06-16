// ─── 1.3 Spacing, Radii, Elevation ──────────────────────────────────────────
// Base grid: multiples of 4.

class MbSpacing {
  MbSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double md2 = 14;
  static const double lg = 16;
  static const double xl = 22;
  static const double xl2 = 24;
}

class MbRadius {
  MbRadius._();

  // field/button 11 · card 13–14 · chip 6–8 · pill 999 · bottom-sheet 22
  static const double field = 11;
  static const double button = 11;
  static const double card = 14;
  static const double cardSmall = 13;
  static const double chip = 8;
  static const double chipSmall = 6;
  static const double pill = 999;
  static const double bottomSheet = 22;
}

class MbElevation {
  MbElevation._();

  static const double card = 1;
  static const double fab = 6;
  static const double bottomSheet = 16;
  static const double dialog = 24;
}

// Minimum touch target across the whole app (buttons, list rows, scan items)
const double kMbMinTouchTarget = 48;

// Card accent left border width (active / accent variant)
const double kMbCardAccentBorder = 3;
