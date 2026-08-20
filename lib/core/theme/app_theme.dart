import 'package:flutter/material.dart';

// ==========================================
// 🚀 1. BUILDCONTEXT EXTENSION (Clean Syntax)
// ==========================================
extension ThemeContext on BuildContext {
  ClickOutColors get colors => Theme.of(this).extension<ClickOutColors>()!;
  TextTheme get textStyles => Theme.of(this).textTheme;
}

// ==========================================
// 🎨 2. SEMANTIC THEME EXTENSION
// ==========================================
class ClickOutColors extends ThemeExtension<ClickOutColors> {
  final Color scaffoldBg;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color ctaBackground;
  final Color ctaText;
  final Color danger;
  final Color warning;
  final Color success;
  final Color border;
  final Color blogHeroBg;

  const ClickOutColors({
    required this.scaffoldBg,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.ctaBackground,
    required this.ctaText,
    required this.danger,
    required this.warning,
    required this.success,
    required this.border,
    required this.blogHeroBg,
  });

  @override
  ClickOutColors copyWith({
    Color? scaffoldBg,
    Color? cardBg,
    Color? textPrimary,
    Color? textSecondary,
    Color? ctaBackground,
    Color? ctaText,
    Color? danger,
    Color? warning,
    Color? success,
    Color? border,
    Color? blogHeroBg,
  }) {
    return ClickOutColors(
      scaffoldBg: scaffoldBg ?? this.scaffoldBg,
      cardBg: cardBg ?? this.cardBg,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      ctaBackground: ctaBackground ?? this.ctaBackground,
      ctaText: ctaText ?? this.ctaText,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      success: success ?? this.success,
      border: border ?? this.border,
      blogHeroBg: blogHeroBg ?? this.blogHeroBg,
    );
  }

  @override
  ClickOutColors lerp(ThemeExtension<ClickOutColors>? other, double t) {
    if (other is! ClickOutColors) return this;
    return ClickOutColors(
      scaffoldBg: Color.lerp(scaffoldBg, other.scaffoldBg, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      ctaBackground: Color.lerp(ctaBackground, other.ctaBackground, t)!,
      ctaText: Color.lerp(ctaText, other.ctaText, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
      border: Color.lerp(border, other.border, t)!,
      blogHeroBg: Color.lerp(blogHeroBg, other.blogHeroBg, t)!,
    );
  }
}

// ==========================================
// 🛠️ 3. APP THEME CONFIGURATION
// ==========================================
class AppTheme {
  // Shared functional colors
  static const Color danger = Color(0xFFFF4D4D);
  static const Color warning = Color(0xFFFFCC00);
  static const Color success = Color(0xFF22C55E); // Standard green

  // --- LIGHT MODE TOKENS ---
  static const _lightScaffold = Color(0xFFFAF2EB); // Softer, lighter warm base
  static const _lightCard = Color(0xFFFFFFFF); // Pure white cards
  static const _lightTextPri = Color(0xFF1A1917); // Dark brown-black for text
  static const _lightTextSec = Color(0xFF6B7280); // Medium grey
  static const _lightCtaBg = Color(0xFF22C55E); // Solid bright green CTA
  static const _lightCtaText = Color(0xFFFFFFFF); // White text on CTA
  static const _lightBorder = Color(0xFFE5E7EB);
  static const _lightBlogHero = Color(
    0xFFF9F6F0,
  ); // Very soft beige (No emerald green)

  // --- DARK MODE TOKENS (Apple/Claude Premium Aesthetic) ---
  static const _darkScaffold = Color(0xFF1A1917); // Soft dark background
  static const _darkCard = Color(0xFF232220); // Silent floating cards
  static const _darkTextPri = Color(0xFFEBEBF5); // Crisp primary text
  static const _darkTextSec = Color(0xFF636366); // Calm secondary text
  static const _darkCtaBg = Color(0xFF242426); // Muted UI elements
  static const _darkCtaText = Color(0xFFEBEBF5); // White text
  static const _darkBorder = Color(0xFF2C2C2E); // Barely visible borders
  static const _darkBlogHero = Color(0xFF242426);

  // ==========================================
  // ☀️ LIGHT THEME
  // ==========================================
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _lightScaffold,
      primaryColor: _lightCtaBg,
      cardColor: _lightCard,
      dividerColor: _lightBorder,
      extensions: const <ThemeExtension<dynamic>>[
        ClickOutColors(
          scaffoldBg: _lightScaffold,
          cardBg: _lightCard,
          textPrimary: _lightTextPri,
          textSecondary: _lightTextSec,
          ctaBackground: _lightCtaBg,
          ctaText: _lightCtaText,
          danger: danger,
          warning: warning,
          success: success,
          border: _lightBorder,
          blogHeroBg: _lightBlogHero,
        ),
      ],
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: _lightTextPri,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.5,
        ),
        headlineLarge: TextStyle(
          color: _lightTextPri,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
        ),
        titleLarge: TextStyle(
          color: _lightTextPri,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
        bodyLarge: TextStyle(color: _lightTextPri, fontSize: 16),
        bodyMedium: TextStyle(color: _lightTextSec, fontSize: 14),
        labelSmall: TextStyle(
          color: _lightTextSec,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _lightCtaBg,
          foregroundColor: _lightCtaText,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      cardTheme: CardThemeData(
        color: _lightCard,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.04), // Soft shadow
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _lightBorder, width: 1),
        ),
      ),
    );
  }

  // ==========================================
  // 🌙 DARK THEME
  // ==========================================
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkScaffold,
      primaryColor: _darkCtaBg,
      cardColor: _darkCard,
      dividerColor: _darkBorder,
      extensions: const <ThemeExtension<dynamic>>[
        ClickOutColors(
          scaffoldBg: _darkScaffold,
          cardBg: _darkCard,
          textPrimary: _darkTextPri,
          textSecondary: _darkTextSec,
          ctaBackground: _darkCtaBg,
          ctaText: _darkCtaText,
          danger: danger,
          warning: warning,
          success: success,
          border: _darkBorder,
          blogHeroBg: _darkBlogHero,
        ),
      ],
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: _darkTextPri,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.5,
        ),
        headlineLarge: TextStyle(
          color: _darkTextPri,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
        ),
        titleLarge: TextStyle(
          color: _darkTextPri,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
        bodyLarge: TextStyle(color: _darkTextPri, fontSize: 16),
        bodyMedium: TextStyle(color: _darkTextSec, fontSize: 14),
        labelSmall: TextStyle(
          color: _darkTextSec,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkCtaBg,
          foregroundColor: _darkCtaText,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      cardTheme: CardThemeData(
        color: _darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _darkBorder, width: 1),
        ),
      ),
    );
  }
}
