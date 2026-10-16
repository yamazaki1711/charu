import 'package:flutter/material.dart';

/// Chinese Aesthetics Theme for CHARU
/// Traditional Chinese red accent, flat Material 3 (no blur/glass effects)
class CharuTheme {
  CharuTheme._();

  // ─── Chinese Red Palette ───
  static const _chinaRed = Color(0xFFCC2B2B);
  static const _chinaGold = Color(0xFFD4AF37);
  static const _darkRed = Color(0xFF8B1A1A);
  static const _jadeGreen = Color(0xFF2E8B57);

  // ─── Light theme colors ───
  static const _lightBackground = Color(0xFFFFF8F0);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightOnSurface = Color(0xFF2C2C2C);

  // ─── Dark theme colors ───
  static const _darkBackground = Color(0xFF1C1410);
  static const _darkSurface = Color(0xFF2C2420);
  static const _darkOnSurface = Color(0xFFF5E6D3);

  static const fontFamily = 'Roboto';
  static const cjkMinFontSize = 18.0;

  /// Light theme - Chinese aesthetics
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: _lightBackground,
    colorScheme: ColorScheme.light(
      primary: _chinaRed,
      secondary: _chinaGold,
      tertiary: _jadeGreen,
      surface: _lightSurface,
      onSurface: _lightOnSurface,
      error: const Color(0xFFB71C1C),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _chinaRed,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: _lightSurface,
      elevation: 2,
      shadowColor: _chinaRed.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _chinaRed.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _lightSurface,
      elevation: 4,
      indicatorColor: _chinaRed.withValues(alpha: 0.15),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: _chinaRed,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          );
        }
        return TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: _chinaRed);
        }
        return IconThemeData(color: Colors.grey[600]);
      }),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _chinaRed,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _chinaRed,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    // Without an explicit shape, Material 3's default OutlinedButton is a
    // full-stadium pill while ElevatedButton above is a rounded rectangle —
    // the two button types look like they belong to different apps when
    // placed side by side (e.g. the review-card "Не помню"/"Помню" pair).
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _chinaRed,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _lightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _chinaRed.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _chinaRed, width: 2),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: _chinaRed.withValues(alpha: 0.1),
      thickness: 1,
    ),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    dialogTheme: const DialogThemeData(),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: _chinaRed,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
  );

  /// Dark theme - Chinese aesthetics
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: _darkBackground,
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFFE85050),
      secondary: _chinaGold,
      tertiary: _jadeGreen,
      surface: _darkSurface,
      onSurface: _darkOnSurface,
      error: const Color(0xFFFF6B6B),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _darkRed,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: _darkSurface,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: const Color(0xFFE85050).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _darkSurface,
      elevation: 4,
      indicatorColor: const Color(0xFFE85050).withValues(alpha: 0.2),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: Color(0xFFE85050),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          );
        }
        return TextStyle(
          color: Colors.grey[400],
          fontSize: 12,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Color(0xFFE85050));
        }
        return IconThemeData(color: Colors.grey[400]);
      }),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFFE85050),
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE85050),
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFE85050),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE85050), width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE85050), width: 2),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: const Color(0xFFE85050).withValues(alpha: 0.1),
      thickness: 1,
    ),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    dialogTheme: const DialogThemeData(),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Color(0xFFE85050),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
  );
}
