import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/log.dart';
import 'di/di.dart';
import 'presentation/navigation/app_router.dart';
import 'presentation/services/notification_service.dart';
import 'presentation/state/app_settings_state.dart' show themeModeProvider;
import 'presentation/theme/charu_theme.dart';
import 'presentation/widgets/segmented_text_display.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initializeJieba();
  } catch (e) {
    log('Jieba initialization failed: $e');
  }

  // Restore the daily reading reminder (if enabled) after a fresh launch.
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notifications_enabled') ?? true) {
      final time = prefs.getString('notification_time') ?? '18:00';
      await NotificationService.instance.onReminderChanged(true, time);
    } else {
      await NotificationService.instance.onReminderChanged(false, '18:00');
    }
  } catch (_) {
    // Best-effort; never block startup on notifications.
  }

  runApp(const ProviderScope(child: CharuApp()));
}

class CharuApp extends ConsumerStatefulWidget {
  const CharuApp({super.key});

  @override
  ConsumerState<CharuApp> createState() => _CharuAppState();
}

class _CharuAppState extends ConsumerState<CharuApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOpenLastFile());
  }

  /// "Открывать последний файл при запуске" (Settings → off by default) —
  /// jumps straight into the most recently read file's reader instead of
  /// landing on the News tab. One-shot: runs once after the very first
  /// frame of a cold start, never again for the lifetime of this widget.
  ///
  /// Reads SharedPreferences directly rather than through
  /// [openLastFileProvider]: that notifier loads its value asynchronously
  /// in its own constructor, so a `ref.read` right after the first frame
  /// can race it and see the not-yet-loaded default (false) even when the
  /// user has the setting on.
  Future<void> _maybeOpenLastFile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('open_last_file') ?? false;
      if (!enabled) return;
      final recent = await ref.read(getRecentFilesUseCaseProvider).call();
      if (recent.isEmpty) return;
      final file = recent.first;
      appRouter.go('/files/reader', extra: {
        'path': file.path,
        'name': file.name,
      });
    } catch (e) {
      log('[Startup] Open-last-file skipped: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Kira',
      debugShowCheckedModeBanner: false,
      theme: CharuTheme.light,
      darkTheme: CharuTheme.dark,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
