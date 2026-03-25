import 'package:flutter/material.dart';

class AppTheme {
  // ==========================================
  // 🌙 DARK THEME COLORS
  // ==========================================
  static const darkBg = Color(0xFF080B08);
  static const darkCard = Color(0xFF111811);
  static const darkAccent = Color(0xFF00C853);
  static const darkText = Color(0xFFF0F0F0);
  static const darkMuted = Color(0xFF888888);

  // ==========================================
  // ☀️ LIGHT THEME COLORS
  // ==========================================
  static const lightBg = Color(0xFFF5F7F5);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightAccent = Color(0xFF00A846);
  static const lightText = Color(0xFF0A0F0A);
  static const lightMuted = Color(0xFF666666);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: darkAccent,
      cardColor: darkCard,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: darkText),
        bodyMedium: TextStyle(color: darkText),
        labelLarge: TextStyle(color: darkMuted),
      ),
      iconTheme: const IconThemeData(color: darkText),
      dividerColor: darkMuted.withOpacity(0.2),
      useMaterial3: true,
      tabBarTheme: TabBarThemeData(indicatorColor: darkAccent),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      primaryColor: lightAccent,
      cardColor: lightCard,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: lightText),
        bodyMedium: TextStyle(color: lightText),
        labelLarge: TextStyle(color: lightMuted),
      ),
      iconTheme: const IconThemeData(color: lightText),
      dividerColor: lightMuted.withOpacity(0.2),
      useMaterial3: true,
      tabBarTheme: TabBarThemeData(indicatorColor: lightAccent),
    );
  }
}
