import 'package:flutter/material.dart';

// ─── 1.1 Brand ────────────────────────────────────────────────────────────────
const Color mbRed = Color(0xFFEE0101);
const Color mbRedDark = Color(0xFFC50303);
const Color mbBlue = Color(0xFF004E95);
const Color mbBlueDark = Color(0xFF003A6F);
const Color mbBlue050 = Color(0xFFE8F0F8);

// ─── Ink / Structure (neutrals — light) ───────────────────────────────────────
const Color mbInk = Color(0xFF1A1F26);
const Color mbInk2 = Color(0xFF5A6675);
const Color mbInk3 = Color(0xFF93A0AF);
const Color mbLine = Color(0xFFD6DDE6);
const Color mbLine2 = Color(0xFFE8ECF2);
const Color mbSurface = Color(0xFFFFFFFF);
const Color mbSurface2 = Color(0xFFF4F6F9);
const Color mbSurface3 = Color(0xFFEDF1F6);

// ─── Status (CRITICAL — consistent across the whole app) ──────────────────────
const Color mbOk = Color(0xFF1B9E4B);
const Color mbOkBg = Color(0xFFE6F4EC);
const Color mbErr = Color(0xFFEE0101);
const Color mbErrBg = Color(0xFFFCE7E7);
const Color mbPend = Color(0xFF004E95);
const Color mbPendBg = Color(0xFFE8F0F8);
const Color mbWarn = Color(0xFFE08600);
const Color mbWarnBg = Color(0xFFFBF0DD);

// ─── Dark neutrals ────────────────────────────────────────────────────────────
const Color mbDarkBg = Color(0xFF0E1217);
const Color mbDarkSurface = Color(0xFF161C24);
const Color mbDarkSurface2 = Color(0xFF1E2630);
const Color mbDarkInk = Color(0xFFE8ECF2);
const Color mbDarkInk2 = Color(0xFF93A0AF);
const Color mbDarkInk3 = Color(0xFF5A6675);
const Color mbDarkLine = Color(0xFF2A3340);
const Color mbDarkLine2 = Color(0xFF222C38);

// ─── Material 3 ColorScheme ───────────────────────────────────────────────────
// primary = red (actions), secondary = blue (headers/nav), error = err

const ColorScheme mbLightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: mbRed,
  onPrimary: Colors.white,
  primaryContainer: mbErrBg,
  onPrimaryContainer: mbRedDark,
  secondary: mbBlue,
  onSecondary: Colors.white,
  secondaryContainer: mbBlue050,
  onSecondaryContainer: mbBlueDark,
  tertiary: mbOk,
  onTertiary: Colors.white,
  tertiaryContainer: mbOkBg,
  onTertiaryContainer: Color(0xFF0D5E2B),
  error: mbErr,
  onError: Colors.white,
  errorContainer: mbErrBg,
  onErrorContainer: mbRedDark,
  surface: mbSurface,
  onSurface: mbInk,
  surfaceContainerHighest: mbSurface3,
  onSurfaceVariant: mbInk2,
  outline: mbLine,
  outlineVariant: mbLine2,
  shadow: Color(0xFF141828),
  scrim: Color(0x661A1F26),
  inverseSurface: mbInk,
  onInverseSurface: mbSurface,
  inversePrimary: Color(0xFFFF8080),
);

const ColorScheme mbDarkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: mbRed,
  onPrimary: Colors.white,
  primaryContainer: Color(0xFF5C0000),
  onPrimaryContainer: Color(0xFFFFB3B3),
  secondary: Color(0xFF5B9BD5),
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFF003166),
  onSecondaryContainer: Color(0xFFB8D4F0),
  tertiary: Color(0xFF34C468),
  onTertiary: Color(0xFF003818),
  tertiaryContainer: Color(0xFF005224),
  onTertiaryContainer: Color(0xFFB0F0CB),
  error: mbErr,
  onError: Colors.white,
  errorContainer: Color(0xFF5C0000),
  onErrorContainer: Color(0xFFFFB3B3),
  surface: mbDarkSurface,
  onSurface: mbDarkInk,
  surfaceContainerHighest: mbDarkSurface2,
  onSurfaceVariant: mbDarkInk2,
  outline: mbDarkLine,
  outlineVariant: mbDarkLine2,
  shadow: Colors.black,
  scrim: Color(0x99000000),
  inverseSurface: mbDarkInk,
  onInverseSurface: mbDarkBg,
  inversePrimary: mbRedDark,
);

// ─── ThemeExtension: MbStatusColors ──────────────────────────────────────────
// Access via: Theme.of(context).extension<MbStatusColors>()!
class MbStatusColors extends ThemeExtension<MbStatusColors> {
  const MbStatusColors({
    required this.ok,
    required this.okBg,
    required this.err,
    required this.errBg,
    required this.pend,
    required this.pendBg,
    required this.warn,
    required this.warnBg,
  });

  final Color ok;
  final Color okBg;
  final Color err;
  final Color errBg;
  final Color pend;
  final Color pendBg;
  final Color warn;
  final Color warnBg;

  static const light = MbStatusColors(
    ok: mbOk,
    okBg: mbOkBg,
    err: mbErr,
    errBg: mbErrBg,
    pend: mbPend,
    pendBg: mbPendBg,
    warn: mbWarn,
    warnBg: mbWarnBg,
  );

  static const dark = MbStatusColors(
    ok: Color(0xFF34C468),
    okBg: Color(0xFF052E14),
    err: mbErr,
    errBg: Color(0xFF3D0000),
    pend: Color(0xFF5B9BD5),
    pendBg: Color(0xFF001E45),
    warn: Color(0xFFF0A020),
    warnBg: Color(0xFF3D2600),
  );

  @override
  MbStatusColors copyWith({
    Color? ok,
    Color? okBg,
    Color? err,
    Color? errBg,
    Color? pend,
    Color? pendBg,
    Color? warn,
    Color? warnBg,
  }) =>
      MbStatusColors(
        ok: ok ?? this.ok,
        okBg: okBg ?? this.okBg,
        err: err ?? this.err,
        errBg: errBg ?? this.errBg,
        pend: pend ?? this.pend,
        pendBg: pendBg ?? this.pendBg,
        warn: warn ?? this.warn,
        warnBg: warnBg ?? this.warnBg,
      );

  @override
  MbStatusColors lerp(MbStatusColors? other, double t) {
    if (other is! MbStatusColors) return this;
    return MbStatusColors(
      ok: Color.lerp(ok, other.ok, t)!,
      okBg: Color.lerp(okBg, other.okBg, t)!,
      err: Color.lerp(err, other.err, t)!,
      errBg: Color.lerp(errBg, other.errBg, t)!,
      pend: Color.lerp(pend, other.pend, t)!,
      pendBg: Color.lerp(pendBg, other.pendBg, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      warnBg: Color.lerp(warnBg, other.warnBg, t)!,
    );
  }
}
