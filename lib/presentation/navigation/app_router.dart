import 'package:go_router/go_router.dart';

import '../screens/news/news_screen.dart';
import '../screens/news/article_screen.dart';
import '../screens/files/files_screen.dart';
import '../screens/files/reader_screen.dart';
import '../screens/library/library_screen.dart';
import '../screens/progress/progress_screen.dart';
import '../screens/progress/review_screen.dart';
import '../screens/settings/settings_screen.dart';
import 'app_shell.dart';

/// Application router configuration.
///
/// Bottom-navigation shell with 5 tabs:
///   📰 News  |  📁 Files  |  📚 Library  |  📊 Progress  |  ⚙ Settings
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
          routes: [
            GoRoute(
              path: 'article',
              pageBuilder: (context, state) {
                final articleId = state.extra as String? ?? '';
                return NoTransitionPage(
                  child: ArticleScreen(articleId: articleId),
                );
              },
            ),
          ],
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
                    demoText: args?['demoText'] as String?,
                  ),
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/library',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: LibraryScreen()),
        ),
        GoRoute(
          path: '/progress',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProgressScreen()),
          routes: [
            GoRoute(
              path: 'review',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ReviewScreen()),
            ),
          ],
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
