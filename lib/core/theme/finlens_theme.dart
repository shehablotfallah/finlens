import 'package:flutter/material.dart';

/// Brand color seed for Finlens.
///
/// Chosen to feel trustworthy (finance) while not looking like a copy of any
/// major banking app. The green teal conveys growth; the slate dark theme
/// keeps the late-night-budgeting feel premium.
class FinlensColors {
  FinlensColors._();

  // Primary accent — "lens teal"
  static const Color primary = Color(0xFF0F9D8F);
  static const Color primaryDark = Color(0xFF14B8A6);
  static const Color primaryContainer = Color(0xFFB2DFDB);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Semantic
  static const Color income = Color(0xFF22C55E);
  static const Color expense = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color neutral = Color(0xFF64748B);

  // Light surface
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF1F5F9);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // Dark surface
  static const Color darkBg = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF1F2937);
}

class FinlensTheme {
  FinlensTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: FinlensColors.primary,
      brightness: Brightness.light,
      primary: FinlensColors.primary,
      onPrimary: FinlensColors.onPrimary,
      surface: FinlensColors.lightSurface,
      onSurface: FinlensColors.lightTextPrimary,
    );
    return _base(scheme, Brightness.light).copyWith(
      scaffoldBackgroundColor: FinlensColors.lightBg,
      cardColor: FinlensColors.lightCard,
      dividerColor: FinlensColors.lightBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: FinlensColors.lightBg,
        foregroundColor: FinlensColors.lightTextPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: _inputLight,
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: FinlensColors.primaryDark,
      brightness: Brightness.dark,
      primary: FinlensColors.primaryDark,
      onPrimary: FinlensColors.onPrimary,
      surface: FinlensColors.darkSurface,
      onSurface: FinlensColors.darkTextPrimary,
    );
    return _base(scheme, Brightness.dark).copyWith(
      scaffoldBackgroundColor: FinlensColors.darkBg,
      cardColor: FinlensColors.darkCard,
      dividerColor: FinlensColors.darkBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: FinlensColors.darkBg,
        foregroundColor: FinlensColors.darkTextPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: _inputDark,
    );
  }

  static ThemeData _base(ColorScheme scheme, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor:
          isLight ? FinlensColors.lightBg : FinlensColors.darkBg,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      textTheme: _textTheme(isLight),
      cardTheme: CardThemeData(
        color: isLight ? FinlensColors.lightCard : FinlensColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      iconTheme: IconThemeData(
        color: isLight
            ? FinlensColors.lightTextPrimary
            : FinlensColors.darkTextPrimary,
      ),
      dividerTheme: DividerThemeData(
        color: isLight ? FinlensColors.lightBorder : FinlensColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor:
            isLight ? FinlensColors.lightCard : FinlensColors.darkCard,
        labelStyle: TextStyle(
          color: isLight
              ? FinlensColors.lightTextPrimary
              : FinlensColors.darkTextPrimary,
        ),
        side: BorderSide(
          color: isLight ? FinlensColors.lightBorder : FinlensColors.darkBorder,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isLight
            ? FinlensColors.lightSurface
            : FinlensColors.darkSurface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: isLight
            ? FinlensColors.lightTextSecondary
            : FinlensColors.darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight
            ? FinlensColors.lightSurface
            : FinlensColors.darkSurface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  static TextTheme _textTheme(bool isLight) {
    final base = isLight
        ? FinlensColors.lightTextPrimary
        : FinlensColors.darkTextPrimary;
    final secondary =
        isLight ? FinlensColors.lightTextSecondary : FinlensColors.darkTextSecondary;
    return TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: base, height: 1.2),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: base, height: 1.2),
      displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: base, height: 1.3),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: base, height: 1.3),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: base, height: 1.3),
      titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: base),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: base),
      titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: secondary),
      bodyLarge: TextStyle(fontSize: 16, color: base, height: 1.5),
      bodyMedium: TextStyle(fontSize: 14, color: base, height: 1.5),
      bodySmall: TextStyle(fontSize: 12, color: secondary),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: base),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: secondary),
      labelSmall: TextStyle(fontSize: 11, color: secondary),
    );
  }

  static InputDecorationTheme get _inputLight => InputDecorationTheme(
        filled: true,
        fillColor: FinlensColors.lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FinlensColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FinlensColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  static InputDecorationTheme get _inputDark => InputDecorationTheme(
        filled: true,
        fillColor: FinlensColors.darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FinlensColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FinlensColors.primaryDark, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}

/// Enum that maps to Flutter ThemeMode + an optional custom variant.
///
/// The "accent variant" entry is reserved for a future 4th theme — it's
/// already wired through the providers so adding the variant later
/// doesn't require any consumer refactor.
enum FinlensThemeMode {
  light,
  dark,
  system;

  ThemeMode toFlutter() {
    switch (this) {
      case FinlensThemeMode.light:
        return ThemeMode.light;
      case FinlensThemeMode.dark:
        return ThemeMode.dark;
      case FinlensThemeMode.system:
        return ThemeMode.system;
    }
  }
}
