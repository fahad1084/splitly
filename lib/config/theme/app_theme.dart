import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ── Primary Teal ──────────────────────────
  static const Color primaryDark   = Color(0xFF134E4A); // nav, icon bg
  static const Color primary       = Color(0xFF0F766E); // buttons, active
  static const Color primaryLight  = Color(0xFF14B8A6); // chips, borders
  static const Color primaryTint   = Color(0xFFCCFBF1); // light surfaces

  // ── Accent Gold ───────────────────────────
  static const Color accent        = Color(0xFFEAB308); // FAB, badges
  static const Color accentDark    = Color(0xFFCA8A04); // gold text

  // ── Backgrounds ───────────────────────────
  static const Color darkBg        = Color(0xFF042F2E); // dark mode page
  static const Color lightBg       = Color(0xFFF0FDFA); // light mode page

  // ── Semantic ──────────────────────────────
  static const Color success       = Color(0xFF16A34A); // owed TO you
  static const Color danger        = Color(0xFFDC2626); // you OWE

  // ── Text colors that pass WCAG 4.5:1 ──────
  // The brand colors above stay as they are (fills, borders, icons). Some are
  // too light for small TEXT on white (primaryLight, success, accentDark) or
  // too dark on dark backgrounds (danger), so text uses these instead.
  static bool _dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color mutedText(BuildContext context) =>
      _dark(context) ? primaryLight : primary;
  static Color successText(BuildContext context) =>
      _dark(context) ? success : const Color(0xFF15803D);
  static Color dangerText(BuildContext context) =>
      _dark(context) ? const Color(0xFFF87171) : danger;
  static Color warningText(BuildContext context) =>
      _dark(context) ? accentDark : const Color(0xFFA16207);

  // On the dark teal summary cards (dark in BOTH themes)
  static const Color successOnDark = Color(0xFF4ADE80);
  static const Color dangerOnDark  = Color(0xFFFCA5A5);
}

class AppTheme {

  // ── LIGHT THEME ───────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.lightBg,
    colorScheme: const ColorScheme.light(
      primary:   AppColors.primary,
      secondary: AppColors.accent,
      surface:   AppColors.lightBg,
      error:     AppColors.danger,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primaryDark,
      foregroundColor: AppColors.primaryTint,
      elevation: 0,
      titleTextStyle: GoogleFonts.poppins(
        color: AppColors.primaryTint,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 14,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.primaryDark,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.primaryTint),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: AppColors.primaryTint,
      labelStyle: TextStyle(color: AppColors.primaryDark),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.primaryTint.withValues(alpha: 0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    ),
  );

  // ── DARK THEME ────────────────────────────
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.darkBg,
    colorScheme: const ColorScheme.dark(
      primary:   AppColors.primaryLight,
      secondary: AppColors.accent,
      surface:   AppColors.primaryDark,
      error:     AppColors.danger,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(
      ThemeData.dark().textTheme,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primaryDark,
      foregroundColor: AppColors.primaryTint,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.primaryDark,
    ),
    cardTheme: CardThemeData(
      color: AppColors.primaryDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.primaryDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
      ),
    ),
  );
}