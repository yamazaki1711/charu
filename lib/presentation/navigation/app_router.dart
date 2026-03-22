import 'package:go_router/go_router.dart';

import '../screens/news/news_screen.dart';
import '../screens/files/files_screen.dart';
import '../screens/files/reader_screen.dart';
import '../screens/progress/progress_screen.dart';
import '../screens/settings/settings_screen.dart';
import 'app_shell.dart';

/// Application router configuration.
///
/// Bottom-navigation shell with 4 tabs:
///   📰 News  |  📁 Files  |  📊 Progress  |  ⚙ Settings
final GoRouter appRouter = GoRouter(
  initialLocation: '/news',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/news',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: NewsScreen()),
        ),
        GoRoute(
          path: '/files',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: FilesScreen()),
          routes: [
            GoRoute(
              path: 'reader',
              pageBuilder: (context, state) {
                final args = state.extra as Map<String, dynamic>?;
                return NoTransitionPage(
                  child: ReaderScreen(
                    filePath: args?['path'] ?? '',
                    fileName: args?['name'] ?? 'Файл',
                  ),
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/progress',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProgressScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SettingsScreen()),
        ),
      ],
    ),
  ],
);
