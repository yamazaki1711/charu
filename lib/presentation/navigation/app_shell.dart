import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shell widget providing the app navigation.
///
/// On wide screens (≥ 840dp) — [NavigationRail] on the left.
/// On narrow screens — bottom [NavigationBar] (unchanged from before).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  /// Drives the [StatefulShellRoute] — each branch keeps its own
  /// Navigator stack alive, so switching tabs doesn't lose where you
  /// were (e.g. a book open in Files survives a trip to Settings).
  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (
      icon: Icons.article_outlined,
      activeIcon: Icons.article,
      label: 'Новости',
    ),
    (
      icon: Icons.folder_outlined,
      activeIcon: Icons.folder,
      label: 'Файлы',
    ),
    (
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart,
      label: 'Прогресс',
    ),
    (
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: 'Настройки',
    ),
  ];

  /// Breakpoint for switching between NavigationRail and NavigationBar.
  static const double _wideBreakpoint = 840.0;

  void _navigate(int index) {
    // Re-tapping the already-active tab resets its branch to the root
    // route (standard "tap home icon to go home" behaviour); switching
    // to a different tab preserves that branch's existing stack.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final index = navigationShell.currentIndex;
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: _navigate,
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
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    // Narrow screen: bottom NavigationBar (unchanged).
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: _navigate,
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
