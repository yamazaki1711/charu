import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shell widget providing the Bottom Navigation Bar.
///
/// Wraps all top-level routes with a consistent scaffold + nav bar.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    (
      icon: Icons.article_outlined,
      activeIcon: Icons.article,
      label: 'Новости',
      path: '/news',
    ),
    (
      icon: Icons.folder_outlined,
      activeIcon: Icons.folder,
      label: 'Файлы',
      path: '/files',
    ),
    (
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart,
      label: 'Прогресс',
      path: '/progress',
    ),
    (
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: 'Настройки',
      path: '/settings',
    ),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: _tabs
            .map(
              (t) => NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.activeIcon),
                label: t.label,
              ),
            )
            .toList(),
      ),
    );
  }
}
