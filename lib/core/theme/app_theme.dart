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
  // ☀️ PREMIUM LIGHT THEME COLORS
  // ==========================================
  static const lightBg = Color(0xFFF8FAFC); // Soft Slate Gray Bg
  static const lightCard = Color(0xFFFFFFFF); // Pure White Cards
  static const lightAccent = Color(0xFF00C853); // Fresh Green
  static const lightText = Color(0xFF0F172A); // Deep Slate Text
  static const lightMuted = Color(0xFF64748B); // Muted Slate

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
      canvasColor: lightCard,
      colorScheme: const ColorScheme.light(
        primary: lightAccent,
        surface: lightCard,
        onSurface: lightText,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: lightText),
        bodyMedium: TextStyle(color: lightText),
        labelLarge: TextStyle(color: lightMuted),
      ),
      iconTheme: const IconThemeData(color: lightMuted),
      dividerColor: const Color(
        0xFFE5E7EB,
      ), // Very subtle Sequence-like borders
      useMaterial3: true,
      tabBarTheme: const TabBarThemeData(indicatorColor: lightAccent),
    );
  }
}
