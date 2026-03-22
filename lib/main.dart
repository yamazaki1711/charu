import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'presentation/navigation/app_router.dart';
import 'presentation/theme/charu_theme.dart';
import 'presentation/widgets/segmented_text_display.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await initializeJieba();
  } catch (e) {
    debugPrint('Jieba initialization failed: $e');
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
