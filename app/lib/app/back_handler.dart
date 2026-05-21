import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Intercepts Android [WidgetsBindingObserver.didPopRoute] before
/// [WidgetsBinding.handlePopRoute] calls [SystemNavigator.pop].
///
/// go_router's [GoRouterDelegate.popRoute] often targets the root navigator
/// (branch stacks have a single route, so `canPop()` is false). Tab-level
/// [PopScope] on the branch route is then skipped; [popRoute] returns false and
/// the app exits. This observer handles Capture/Settings → Jobs first.
class AppBackHandler extends WidgetsBindingObserver {
  AppBackHandler(this.router);

  final GoRouter router;

  static const _secondaryTabPaths = {'/capture', '/settings'};

  @override
  Future<bool> didPopRoute() async {
    final path = router.state.uri.path;
    if (_secondaryTabPaths.contains(path)) {
      router.go('/jobs');
      return true;
    }
    return false;
  }
}
