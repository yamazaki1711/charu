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

// ─── Reader line height ──────────────────────────────────────────────────────

/// Provider for the reader line spacing multiplier (default: 1.7).
final lineHeightProvider =
    StateNotifierProvider<LineHeightNotifier, double>((ref) {
  return LineHeightNotifier();
});

/// Notifier for the reader line-height setting (Settings → Appearance).
///
/// Persists to SharedPreferences; default is `1.7` (previously hardcoded).
class LineHeightNotifier extends StateNotifier<double> {
  static const steps = [1.3, 1.7, 2.1];

  LineHeightNotifier() : super(1.7) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getDouble('line_height') ?? 1.7;
  }

  Future<void> set(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('line_height', value);
    state = value;
  }
}

// ─── Reader side margins ─────────────────────────────────────────────────────

/// Provider for the reader horizontal padding in px (default: 16).
final readerMarginProvider =
    StateNotifierProvider<ReaderMarginNotifier, double>((ref) {
  return ReaderMarginNotifier();
});

class ReaderMarginNotifier extends StateNotifier<double> {
  static const steps = [8.0, 16.0, 24.0, 32.0];

  ReaderMarginNotifier() : super(16.0) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getDouble('reader_margin') ?? 16.0;
  }

  Future<void> set(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('reader_margin', value);
    state = value;
  }
}

// ─── Open last file on launch ────────────────────────────────────────────────

/// Provider for "open last read file on launch" (default: OFF — lands on
/// the News tab, like today). When ON, [CharuApp] jumps straight to the
/// most recently opened file's reader right after a cold start.
final openLastFileProvider =
    StateNotifierProvider<OpenLastFileNotifier, bool>((ref) {
  return OpenLastFileNotifier();
});

class OpenLastFileNotifier extends StateNotifier<bool> {
  OpenLastFileNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('open_last_file') ?? false;
  }

  Future<void> set(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('open_last_file', value);
    state = value;
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
