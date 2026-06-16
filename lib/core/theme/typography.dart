import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── 1.2 Typography scale ────────────────────────────────────────────────────
// Display : Archivo        w700/w800 — titles, KPI numbers, action labels, AppBar
// Text    : Hanken Grotesk w400–w700 — body, lists, descriptions
// Mono    : Spline Sans Mono w500/w600 — tracking IDs, endpoints, timestamps
//
// Scale: h1 26/800 · h2 18/700 · h3 15/700 · body 14/400 · sub 12/500
//        cap 11/600 UPPERCASE +0.04em · mono 12/600 · stat 23/800
//
// Rule: no interactive text < 13px; respect textScaleFactor.

class MbTypography {
  MbTypography._();

  // ── Named semantic styles (use these in widgets) ──────────────────────────

  static TextStyle h1([Color? color]) => _archivo(26, FontWeight.w800, color);
  static TextStyle h2([Color? color]) => _archivo(18, FontWeight.w700, color);
  static TextStyle h3([Color? color]) => _archivo(15, FontWeight.w700, color);
  static TextStyle stat([Color? color]) => _archivo(23, FontWeight.w800, color);

  static TextStyle body([Color? color]) => _hanken(14, FontWeight.w400, color);
  static TextStyle bodyBold([Color? color]) => _hanken(14, FontWeight.w600, color);
  static TextStyle sub([Color? color]) => _hanken(12, FontWeight.w500, color);

  static TextStyle cap([Color? color]) => GoogleFonts.hankenGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.44, // 0.04 em × 11px
        color: color,
      );

  static TextStyle mono([Color? color]) => GoogleFonts.splineSansMono(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color,
      );

  // ── Material 3 TextTheme (applied to ThemeData.textTheme) ─────────────────
  // Maps design scale → M3 roles closest in semantic intent.

  static TextTheme get textTheme => TextTheme(
        // Display → screen hero titles & KPI stats
        displayLarge: _archivo(26, FontWeight.w800, null),
        displayMedium: _archivo(23, FontWeight.w800, null),
        displaySmall: _archivo(18, FontWeight.w700, null),

        // Headline → card titles, section heads
        headlineLarge: _archivo(18, FontWeight.w700, null),
        headlineMedium: _archivo(15, FontWeight.w700, null),
        headlineSmall: _archivo(15, FontWeight.w600, null),

        // Title → list row titles, modal headers
        titleLarge: _archivo(18, FontWeight.w700, null),
        titleMedium: _hanken(15, FontWeight.w600, null),
        titleSmall: _hanken(13, FontWeight.w600, null),

        // Body → content, descriptions
        bodyLarge: _hanken(14, FontWeight.w400, null),
        bodyMedium: _hanken(14, FontWeight.w400, null),
        bodySmall: _hanken(12, FontWeight.w500, null),

        // Label → buttons, chips, caps, tabs
        labelLarge: _archivo(15, FontWeight.w700, null),
        labelMedium: GoogleFonts.hankenGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.44,
        ),
        labelSmall: GoogleFonts.hankenGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.44,
        ),
      );

  // ── Private helpers ────────────────────────────────────────────────────────

  static TextStyle _archivo(double size, FontWeight weight, Color? color) =>
      GoogleFonts.archivo(fontSize: size, fontWeight: weight, color: color);

  static TextStyle _hanken(double size, FontWeight weight, Color? color) =>
      GoogleFonts.hankenGrotesk(fontSize: size, fontWeight: weight, color: color);
}
