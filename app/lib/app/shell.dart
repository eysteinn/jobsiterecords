import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom-nav shell using [StatefulNavigationShell].
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (Icons.work_outline, Icons.work_rounded, 'Jobs'),
    (Icons.camera_alt_outlined, Icons.camera_alt_rounded, 'Capture'),
    (Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.$1),
              selectedIcon: Icon(d.$2),
              label: d.$3,
            ),
        ],
      ),
    );
  }
}

/// Wraps Capture or Settings tab roots.
///
/// [PopScope] must sit on the **branch navigator's** top route (this widget),
/// not on [AppShell]. go_router calls `maybePop` on that inner navigator first;
/// a shell-level [PopScope] never runs, which is why back was exiting the app
/// (especially on MIUI with predictive back).
class SecondaryTabBack extends StatelessWidget {
  const SecondaryTabBack({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final shell = StatefulNavigationShell.maybeOf(context);
        if (shell != null) {
          shell.goBranch(0);
        } else {
          context.go('/jobs');
        }
      },
      child: child,
    );
  }
}
