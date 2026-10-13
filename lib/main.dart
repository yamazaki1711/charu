import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    debugPrint('Jieba initialization failed: $e');
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

class CharuApp extends ConsumerWidget {
  const CharuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'CHARU',
      debugShowCheckedModeBanner: false,
      theme: CharuTheme.light,
      darkTheme: CharuTheme.dark,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
