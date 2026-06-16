import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

// ─── 1.4 ThemeData assembly (light + dark) ───────────────────────────────────
// Rule: never hard-code a color in a widget — always use the theme.
// Access status colors via: Theme.of(ctx).extension<MbStatusColors>()!

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(
        colorScheme: mbLightColorScheme,
        statusColors: MbStatusColors.light,
        isDark: false,
      );

  static ThemeData dark() => _build(
        colorScheme: mbDarkColorScheme,
        statusColors: MbStatusColors.dark,
        isDark: true,
      );

  static ThemeData _build({
    required ColorScheme colorScheme,
    required MbStatusColors statusColors,
    required bool isDark,
  }) {
    final surfaceBg = isDark ? mbDarkSurface : mbSurface;
    final lineColor = isDark ? mbDarkLine : mbLine;
    final line2Color = isDark ? mbDarkLine2 : mbLine2;
    final inkColor = isDark ? mbDarkInk : mbInk;
    final ink2Color = isDark ? mbDarkInk2 : mbInk2;
    final ink3Color = isDark ? mbDarkInk3 : mbInk3;
    final surface3Color = isDark ? mbDarkSurface2 : mbSurface3;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      extensions: [statusColors],
      textTheme: MbTypography.textTheme,

      // Scaffold background = surface2 (off-white / dark bg)
      scaffoldBackgroundColor: isDark ? mbDarkBg : mbSurface2,

      // ── AppBar ──────────────────────────────────────────────────────────────
      // Blue navy, white text/icons, Archivo w700, no elevation.
      appBarTheme: AppBarTheme(
        backgroundColor: mbBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.archivo(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white, size: 24),
        actionsIconTheme: const IconThemeData(color: Colors.white, size: 24),
      ),

      // ── Card ────────────────────────────────────────────────────────────────
      // White surface, radius 14, 1px border line, very soft shadow.
      cardTheme: CardThemeData(
        color: surfaceBg,
        elevation: MbElevation.card,
        shadowColor: const Color(0x1F142850),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MbRadius.card),
          side: BorderSide(color: lineColor, width: 1),
        ),
      ),

      // ── FilledButton — primary red action ───────────────────────────────────
      // Red background, white Archivo w700 label, radius 11, min height 48.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: mbRed,
          foregroundColor: Colors.white,
          disabledBackgroundColor: mbLine,
          disabledForegroundColor: mbInk3,
          minimumSize: const Size(double.infinity, kMbMinTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MbRadius.button),
          ),
          textStyle: GoogleFonts.archivo(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          elevation: 0,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.pressed)
                ? mbRedDark.withAlpha(0x33)
                : null,
          ),
        ),
      ),

      // ── OutlinedButton — ghost blue ─────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: mbBlue,
          minimumSize: const Size.fromHeight(kMbMinTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MbRadius.button),
          ),
          side: const BorderSide(color: mbBlue, width: 1.5),
          textStyle: GoogleFonts.archivo(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ── TextButton ──────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: mbBlue,
          minimumSize: const Size(0, kMbMinTouchTarget),
          textStyle: GoogleFonts.hankenGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── ElevatedButton (secondary use) ──────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: mbBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(kMbMinTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MbRadius.button),
          ),
          textStyle: GoogleFonts.archivo(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          elevation: 0,
        ),
      ),

      // ── Input decoration ─────────────────────────────────────────────────────
      // Filled surface3, border line, focus blue 1.5px, radius 11.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface3Color,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MbSpacing.lg,
          vertical: MbSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MbRadius.field),
          borderSide: BorderSide(color: lineColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MbRadius.field),
          borderSide: BorderSide(color: lineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MbRadius.field),
          borderSide: const BorderSide(color: mbBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MbRadius.field),
          borderSide: const BorderSide(color: mbErr, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MbRadius.field),
          borderSide: const BorderSide(color: mbErr, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MbRadius.field),
          borderSide: BorderSide(color: line2Color),
        ),
        labelStyle: GoogleFonts.hankenGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.44,
          color: ink2Color,
        ),
        hintStyle: GoogleFonts.hankenGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: ink3Color,
        ),
        errorStyle: GoogleFonts.hankenGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: mbErr,
        ),
      ),

      // ── BottomSheet ──────────────────────────────────────────────────────────
      // Radius 22 top, drag handle 38×4 grey.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceBg,
        elevation: MbElevation.bottomSheet,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(MbRadius.bottomSheet),
          ),
        ),
        dragHandleColor: lineColor,
        dragHandleSize: const Size(38, 4),
      ),

      // ── NavigationBar ────────────────────────────────────────────────────────
      // White/dark surface, active item = blue, inactive = ink3.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceBg,
        indicatorColor: mbBlue050,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? mbBlue : ink3Color,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.hankenGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? mbBlue : ink3Color,
          );
        }),
      ),

      // ── SnackBar / Toast ──────────────────────────────────────────────────────
      // Dark ink background, white text, floating with rounded corners.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? mbDarkLine : mbInk,
        contentTextStyle: GoogleFonts.hankenGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        actionTextColor: mbBlue050,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MbRadius.chip),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),

      // ── FAB — red scanner button ─────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: mbRed,
        foregroundColor: Colors.white,
        elevation: MbElevation.fab,
        highlightElevation: MbElevation.fab + 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MbRadius.pill),
        ),
      ),

      // ── Divider ─────────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: line2Color,
        thickness: 1,
        space: 1,
      ),

      // ── Chip ────────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: surface3Color,
        labelStyle: GoogleFonts.hankenGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: ink2Color,
        ),
        side: BorderSide(color: lineColor, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MbRadius.chip),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: MbSpacing.sm,
          vertical: MbSpacing.xs,
        ),
      ),

      // ── ListTile ─────────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        minTileHeight: kMbMinTouchTarget,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MbSpacing.lg,
          vertical: MbSpacing.xs,
        ),
        titleTextStyle: GoogleFonts.hankenGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: inkColor,
        ),
        subtitleTextStyle: GoogleFonts.hankenGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: ink2Color,
        ),
      ),

      // ── Switch ──────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return mbBlue;
          return ink3Color;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return mbBlue050;
          return lineColor;
        }),
      ),

      // ── Progress indicator ───────────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: mbBlue,
        linearTrackColor: lineColor,
        circularTrackColor: lineColor,
      ),

      // ── Dialog ───────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceBg,
        elevation: MbElevation.dialog,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MbRadius.card),
        ),
        titleTextStyle: GoogleFonts.archivo(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: inkColor,
        ),
        contentTextStyle: GoogleFonts.hankenGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: ink2Color,
        ),
      ),

      // ── Badge ────────────────────────────────────────────────────────────────
      badgeTheme: const BadgeThemeData(
        backgroundColor: mbRed,
        textColor: Colors.white,
        smallSize: 8,
        largeSize: 16,
      ),

      // ── IconButton ───────────────────────────────────────────────────────────
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(kMbMinTouchTarget, kMbMinTouchTarget),
        ),
      ),

      // ── SegmentedButton ──────────────────────────────────────────────────────
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: mbBlue050,
          selectedForegroundColor: mbBlue,
          foregroundColor: ink2Color,
          textStyle: GoogleFonts.hankenGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MbRadius.field),
          ),
          side: BorderSide(color: lineColor),
        ),
      ),

      // ── PopupMenu ────────────────────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceBg,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MbRadius.cardSmall),
          side: BorderSide(color: lineColor),
        ),
        textStyle: GoogleFonts.hankenGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: inkColor,
        ),
      ),
    );
  }
}
