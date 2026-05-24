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
}

class AppTheme {

  // ── LIGHT THEME ───────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.lightBg,
    colorScheme: ColorScheme.light(
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
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.primaryDark,
    ),
    // ✅ Fixed: CardThemeData (not CardTheme)
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.primaryTint),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.primaryTint,
      labelStyle: const TextStyle(color: AppColors.primaryDark),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.primaryTint.withOpacity(0.4),
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
    colorScheme: ColorScheme.dark(
      primary:   AppColors.primaryLight,
      secondary: AppColors.accent,
      surface:   AppColors.primaryDark,
      error:     AppColors.danger,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(
      ThemeData.dark().textTheme,
    ),
    appBarTheme: AppBarTheme(
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
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.primaryDark,
    ),
    // ✅ Fixed: CardThemeData (not CardTheme)
    cardTheme: CardThemeData(
      color: AppColors.primaryDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
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