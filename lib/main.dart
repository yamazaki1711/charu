import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/navigation/app_router.dart';
import 'presentation/theme/charu_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: CharuApp()));
}

/// Root application widget.
class CharuApp extends StatelessWidget {
  const CharuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'CHARU',
      debugShowCheckedModeBanner: false,
      theme: CharuTheme.light,
      darkTheme: CharuTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
