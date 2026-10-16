import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-level user settings state (theme, pinyin, font size, notifications).
///
/// Lives in `presentation/state` (not `main.dart`) so that presentation
/// widgets can import it directly without a cyclic import through the app
/// entrypoint.

// ─── Theme mode ───────────────────────────────────────────────────────────────

/// Provider for the app theme mode (persisted to SharedPreferences).
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString('theme_mode') ?? 'system';
    state = ThemeMode.values.firstWhere(
      (e) => e.name == savedMode,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
    state = mode;
  }
}

// ─── Show pinyin toggle ──────────────────────────────────────────────────────

/// Provider for the "show pinyin" setting (default: ON).
///
/// Listeners rebuild immediately when the value changes (no app restart
/// needed).
final showPinyinProvider =
    StateNotifierProvider<ShowPinyinNotifier, bool>((ref) {
  return ShowPinyinNotifier();
});

/// Notifier for the "show pinyin" toggle (Settings → Appearance).
///
/// Persists to SharedPreferences; default is `true` (pinyin shown).
class ShowPinyinNotifier extends StateNotifier<bool> {
  ShowPinyinNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('show_pinyin') ?? true;
  }

  Future<void> set(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_pinyin', value);
    state = value;
  }
}

// ─── Pinyin reveal mode (always vs. tap-to-reveal) ──────────────────────────

/// Provider for "show pinyin only on tap" (default: OFF — always shown).
///
/// When ON, ambient pinyin annotations are hidden in the reader; tapping a
/// word reveals its pinyin (in addition to opening the dictionary popup),
/// which discourages "blind reading" (eyes skipping straight to the
/// romanization instead of recognizing the character). Only meaningful
/// while [showPinyinProvider] is also true.
final pinyinTapOnlyProvider =
    StateNotifierProvider<PinyinTapOnlyNotifier, bool>((ref) {
  return PinyinTapOnlyNotifier();
});

class PinyinTapOnlyNotifier extends StateNotifier<bool> {
  PinyinTapOnlyNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('pinyin_tap_only') ?? false;
  }

  Future<void> set(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pinyin_tap_only', value);
    state = value;
  }
}

// ─── Library: keep traditional characters ───────────────────────────────────

/// When ON, books downloaded from Wikisource (traditional-only source) are
/// saved as-is instead of being converted to simplified characters via
/// OpenCC. Off by default — most learners in this app's audience read
/// simplified.
final libraryKeepTraditionalProvider =
    StateNotifierProvider<LibraryKeepTraditionalNotifier, bool>((ref) {
  return LibraryKeepTraditionalNotifier();
});

class LibraryKeepTraditionalNotifier extends StateNotifier<bool> {
  LibraryKeepTraditionalNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('library_keep_traditional') ?? false;
  }

  Future<void> set(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('library_keep_traditional', value);
    state = value;
  }
}

// ─── Reader font size ────────────────────────────────────────────────────────

/// Provider for the reader font size setting (default: 18, range 14–24).
final fontSizeProvider =
    StateNotifierProvider<FontSizeNotifier, int>((ref) {
  return FontSizeNotifier();
});

/// Notifier for the reader font size (Settings → Appearance).
///
/// Persists to SharedPreferences; default is `18`.
class FontSizeNotifier extends StateNotifier<int> {
  static const minSize = 14;
  static const maxSize = 24;
  static const stepSize = 2;

  FontSizeNotifier() : super(18) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt('font_size') ?? 18;
  }

  Future<void> set(int size) async {
    final prefs = await SharedPreferences.getInstance();
    final clamped = size.clamp(minSize, maxSize);
    await prefs.setInt('font_size', clamped);
    state = clamped;
  }
}

// ─── Notifications ───────────────────────────────────────────────────────────

/// Provider for the "daily reminder" notification setting (default: ON).
final notificationsEnabledProvider =
    StateNotifierProvider<NotificationsEnabledNotifier, bool>((ref) {
  return NotificationsEnabledNotifier();
});

/// Notifier for the daily-reminder notification toggle.
///
/// Persists to SharedPreferences; default is `true`.
class NotificationsEnabledNotifier extends StateNotifier<bool> {
  NotificationsEnabledNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('notifications_enabled') ?? true;
  }

  Future<void> set(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    state = value;
  }
}
