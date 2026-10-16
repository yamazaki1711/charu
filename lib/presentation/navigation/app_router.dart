import 'package:go_router/go_router.dart';

import '../screens/news/news_screen.dart';
import '../screens/news/article_screen.dart';
import '../screens/files/files_screen.dart';
import '../screens/files/reader_screen.dart';
import '../screens/progress/progress_screen.dart';
import '../screens/progress/review_screen.dart';
import '../screens/settings/settings_screen.dart';
import 'app_shell.dart';

/// Application router configuration.
///
/// Bottom-navigation shell with 4 tabs:
///   📰 News  |  📁 Files  |  📊 Progress  |  ⚙ Settings
///
/// Each tab is its own [StatefulShellBranch] with an independent
/// Navigator stack. Previously this used a single [ShellRoute], where
/// switching tabs called `context.go()` and reset EVERY branch back to
/// its root route — so opening a book in Files, checking Settings, and
/// tapping back to Files always landed on the file list, never back on
/// the open book. StatefulShellRoute keeps each branch's stack alive
/// in the background (an IndexedStack), so returning to a tab resumes
/// exactly where that tab was left.
final GoRouter appRouter = GoRouter(
  initialLocation: '/news',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
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
          ],
        ),
        StatefulShellBranch(
          routes: [
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
          ],
        ),
        StatefulShellBranch(
          routes: [
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
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: SettingsScreen()),
            ),
          ],
        ),
      ],
    ),
  ],
);
