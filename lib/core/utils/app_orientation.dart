import 'dart:ui';

import 'package:flutter/services.dart';

/// Phones stay in portrait (every screen is laid out for it). Tablets and
/// unfolded foldables may turn, e.g. to read two Mushaf pages side by side.
class AppOrientation {
  AppOrientation._();

  static bool? _large;

  /// Shortest side of the window in logical pixels ≥ 600: a tablet or an
  /// unfolded phone.
  static bool get isLargeScreen {
    final views = PlatformDispatcher.instance.views;
    if (views.isEmpty) return false;
    final v = views.first;
    if (v.devicePixelRatio <= 0) return false;
    return (v.physicalSize / v.devicePixelRatio).shortestSide >= 600;
  }

  static List<DeviceOrientation> get allowed =>
      isLargeScreen ? DeviceOrientation.values : const [DeviceOrientation.portraitUp];

  /// Applies the allowed orientations; with [onlyIfChanged] nothing happens
  /// unless the screen class changed (folding / unfolding).
  static Future<void> apply({bool onlyIfChanged = false}) async {
    final large = isLargeScreen;
    if (onlyIfChanged && large == _large) return;
    _large = large;
    await SystemChrome.setPreferredOrientations(allowed);
  }
}
