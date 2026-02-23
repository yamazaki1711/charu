import 'package:flutter/material.dart';

/// CHARU Liquid Glass Theme.
///
/// CJK text areas use opaque backgrounds for readability.
/// Blur/transparency only on decorative/navigation elements.
class CharuTheme {
  CharuTheme._();

  // ─── Light palette ───
  static const _lightBackground = Color(0xFFF8F9FA);
  static const _lightSurface = Colors.white;
  static const _lightText = Color(0xFF1A1A1A);
  static const _lightAccent = Color(0xFFFF6B6B);

  // ─── Dark palette ───
  static const _darkBackground = Color(0xFF1A1D23);
  static const _darkSurface = Color(0xFF252830);
  static const _darkText = Color(0xFFE8E8E8);
  static const _darkAccent = Color(0xFFFF8585);

  // ─── Common ───
  static const fontFamily = 'Roboto';
  static const cjkMinFontSize = 18.0;

  /// Light theme data.
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: fontFamily,
        scaffoldBackgroundColor: _lightBackground,
        colorScheme: ColorScheme.light(
          primary: _lightAccent,
          secondary: _lightAccent,
          surface: _lightSurface,
          onSurface: _lightText,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: _lightText,
          elevation: 0,
          centerTitle: true,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.transparent,
          selectedItemColor: _lightAccent,
          unselectedItemColor: Colors.grey,
        ),
        cardTheme: CardThemeData(
          color: _lightSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );

  /// Dark theme data.
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: fontFamily,
        scaffoldBackgroundColor: _darkBackground,
        colorScheme: ColorScheme.dark(
          primary: _darkAccent,
          secondary: _darkAccent,
          surface: _darkSurface,
          onSurface: _darkText,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: _darkText,
          elevation: 0,
          centerTitle: true,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.transparent,
          selectedItemColor: _darkAccent,
          unselectedItemColor: Colors.grey,
        ),
        cardTheme: CardThemeData(
          color: _darkSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
}
