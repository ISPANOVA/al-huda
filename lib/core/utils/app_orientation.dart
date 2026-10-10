import 'dart:ui';

import 'package:flutter/services.dart';

/// Phones stay in portrait (every screen is laid out for it). Tablets and
/// unfolded foldables may turn, e.g. to read two Mushaf pages side by side.
class AppOrientation {
  AppOrientation._();

  static bool? _large;

  /// Shortest side of the window in logical pixels ≥ 600: a tablet or an
  /// unfolded phone. Before the window has a size (very early at startup)
  /// the screen's own size decides; null when neither is known yet.
  static bool? get _largeOrNull {
    final d = PlatformDispatcher.instance;
    for (final v in d.views) {
      if (!v.physicalSize.isEmpty && v.devicePixelRatio > 0) {
        return (v.physicalSize / v.devicePixelRatio).shortestSide >= 600;
      }
    }
    for (final s in d.displays) {
      if (!s.size.isEmpty && s.devicePixelRatio > 0) return (s.size / s.devicePixelRatio).shortestSide >= 600;
    }
    return null;
  }

  static bool get isLargeScreen => _largeOrNull ?? false;

  static List<DeviceOrientation> get allowed =>
      isLargeScreen ? DeviceOrientation.values : const [DeviceOrientation.portraitUp];

  /// Applies the allowed orientations; with [onlyIfChanged] nothing happens
  /// unless the screen class changed (folding / unfolding).
  static Future<void> apply({bool onlyIfChanged = false}) async {
    final large = isLargeScreen;
    if (onlyIfChanged && large == _large) return;
    _large = large;
    await SystemChrome.setPreferredOrientations(
        large ? DeviceOrientation.values : const [DeviceOrientation.portraitUp]);
  }
}
