import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shell widget providing the app navigation.
///
/// On wide screens (≥ 840dp) — [NavigationRail] on the left.
/// On narrow screens — bottom [NavigationBar] (unchanged from before).
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

  /// Breakpoint for switching between NavigationRail and NavigationBar.
  static const double _wideBreakpoint = 840.0;

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  void _navigate(BuildContext context, int i) => context.go(_tabs[i].path);

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: (i) => _navigate(context, i),
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.only(top: 16, bottom: 8),
                child: Icon(Icons.menu_book, size: 28),
              ),
              destinations: _tabs
                  .map(
                    (t) => NavigationRailDestination(
                      icon: Icon(t.icon),
                      selectedIcon: Icon(t.activeIcon),
                      label: Text(t.label),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    // Narrow screen: bottom NavigationBar (unchanged).
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => _navigate(context, i),
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
