import 'package:flutter/material.dart';

/// Hooks shared by the app's frame: the Mushaf asks for the full width while
/// it is visible ([wide]) and the top route is watched ([observer]). Wide
/// screens now get their own layout (side navigation, wider pages), so the
/// app is no longer squeezed into a phone-sized column.
class WebFrame extends StatelessWidget {
  final Widget child;

  const WebFrame({super.key, required this.child});

  /// Set by the Mushaf reader while it is visible.
  static final ValueNotifier<bool> wide = ValueNotifier(false);

  /// Whether the top route is a popup (a sheet or a dialog), so the Mushaf
  /// stays wide behind its settings sheet or guide.
  static bool popupOnTop = false;

  static final NavigatorObserver observer = _TopRouteObserver();

  @override
  Widget build(BuildContext context) => child;
}

class _TopRouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> _stack = [];

  void _sync() => WebFrame.popupOnTop = _stack.isNotEmpty && _stack.last is PopupRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route);
    _sync();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _sync();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _sync();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (i >= 0 && newRoute != null) {
      _stack[i] = newRoute;
    } else if (i >= 0) {
      _stack.removeAt(i);
    } else if (newRoute != null) {
      _stack.add(newRoute);
    }
    _sync();
  }
}

