import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ThemeMode parsing (as in ThemeModeNotifier)', () {
    // Mirrors the parse logic used by ThemeModeNotifier._loadThemeMode.
    expect(ThemeMode.values.firstWhere((e) => e.name == 'dark'), ThemeMode.dark);
    expect(
      ThemeMode.values.firstWhere(
        (e) => e.name == 'system',
        orElse: () => ThemeMode.system,
      ),
      ThemeMode.system,
    );
    expect(
      ThemeMode.values.firstWhere(
        (e) => e.name == 'bogus',
        orElse: () => ThemeMode.system,
      ),
      ThemeMode.system,
    );
  });
}
