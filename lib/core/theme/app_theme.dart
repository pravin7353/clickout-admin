import 'package:flutter/material.dart';

class AppColors {
  static const accent = Color(0xFF00C853);
  static const accentNeon = Color(0xFF00FF88);

  static const darkBg = Color(0xFF080B08);
  static const darkCard = Color(0xFF111811);
  static const darkCardElevated = Color(0xFF1A201A);
  static const darkText = Color(0xFFF0F0F0);
  static const darkMuted = Color(0xFF888888);
  static const darkBorder = Color(0xFF1F261F);
  static const darkInput = Color(0xFF0D110D);

  static const lightBg = Color(0xFFF8FAFC);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightCardElevated = Color(0xFFF1F5F9);
  static const lightText = Color(0xFF0F172A);
  static const lightMuted = Color(0xFF64748B);
  static const lightBorder = Color(0xFFE2E8F0);
  static const lightInput = Color(0xFFF8FAFC);

  static const error = Color(0xFFE53E3E);
  static const warning = Color(0xFFEF9F27);
  static const success = Color(0xFF00C853);
  static const info = Color(0xFF378ADD);

  static const globalCmd = Color(0xFF7F77DD);
  static const tenantHq = Color(0xFF00C853);
  static const operations = Color(0xFF378ADD);
  static const staffAudit = Color(0xFFEF9F27);
  static const financeRisk = Color(0xFFE24B4A);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      primaryColor: AppColors.accent,
      cardColor: AppColors.darkCard,
      canvasColor: AppColors.darkCard,
      dialogBackgroundColor: AppColors.darkCard,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        surface: AppColors.darkCard,
        onSurface: AppColors.darkText,
        onPrimary: Colors.black,
        error: AppColors.error,
        outline: AppColors.darkBorder,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.darkText),
        bodyMedium: TextStyle(color: AppColors.darkText),
        bodySmall: TextStyle(color: AppColors.darkMuted),
        labelLarge: TextStyle(color: AppColors.darkMuted),
        titleMedium: TextStyle(color: AppColors.darkText, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold),
      ),
      iconTheme: const IconThemeData(color: AppColors.darkText),
      dividerColor: AppColors.darkBorder,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkInput,
        hintStyle: const TextStyle(color: AppColors.darkMuted),
        labelStyle: const TextStyle(color: AppColors.darkMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkText,
          side: const BorderSide(color: AppColors.darkBorder),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkCard,
        foregroundColor: AppColors.darkText,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      tabBarTheme: const TabBarThemeData(indicatorColor: AppColors.accent),
      useMaterial3: true,
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      primaryColor: AppColors.accent,
      cardColor: AppColors.lightCard,
      canvasColor: AppColors.lightCard,
      dialogBackgroundColor: AppColors.lightCard,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        surface: AppColors.lightCard,
        onSurface: AppColors.lightText,
        onPrimary: Colors.black,
        error: AppColors.error,
        outline: AppColors.lightBorder,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.lightText),
        bodyMedium: TextStyle(color: AppColors.lightText),
        bodySmall: TextStyle(color: AppColors.lightMuted),
        labelLarge: TextStyle(color: AppColors.lightMuted),
        titleMedium: TextStyle(color: AppColors.lightText, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: AppColors.lightText, fontWeight: FontWeight.bold),
      ),
      iconTheme: const IconThemeData(color: AppColors.lightMuted),
      dividerColor: AppColors.lightBorder,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightInput,
        hintStyle: const TextStyle(color: AppColors.lightMuted),
        labelStyle: const TextStyle(color: AppColors.lightMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lightText,
          side: const BorderSide(color: AppColors.lightBorder),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightCard,
        foregroundColor: AppColors.lightText,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      tabBarTheme: const TabBarThemeData(indicatorColor: AppColors.accent),
      useMaterial3: true,
    );
  }
}
