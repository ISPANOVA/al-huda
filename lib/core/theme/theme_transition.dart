import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Smooth theme switching: instead of interpolating the whole ThemeData every
/// frame (which rebuilds the entire app ~30 times and stutters), we take one
/// snapshot of the current screen, apply the new theme in a single frame and
/// cross-fade the snapshot away on the GPU.
class ThemeTransition extends StatefulWidget {
  final Widget child;

  const ThemeTransition({super.key, required this.child});

  static _ThemeTransitionState? _current;

  /// Call right before changing the theme. Safe to call when not mounted.
  static Future<void> prepare() async => _current?._capture();

  @override
  State<ThemeTransition> createState() => _ThemeTransitionState();
}

class _ThemeTransitionState extends State<ThemeTransition> with SingleTickerProviderStateMixin {
  final GlobalKey _boundary = GlobalKey();
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) _clear();
    });
  ui.Image? _snapshot;

  @override
  void initState() {
    super.initState();
    ThemeTransition._current = this;
  }

  @override
  void dispose() {
    if (identical(ThemeTransition._current, this)) ThemeTransition._current = null;
    _fade.dispose();
    _snapshot?.dispose();
    super.dispose();
  }

  void _clear() {
    if (!mounted) return;
    setState(() {
      _snapshot?.dispose();
      _snapshot = null;
    });
  }

  Future<void> _capture() async {
    final boundary = _boundary.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || !boundary.hasSize) return;
    try {
      final ratio = MediaQuery.devicePixelRatioOf(context);
      final image = await boundary.toImage(pixelRatio: ratio);
      if (!mounted) {
        image.dispose();
        return;
      }
      _snapshot?.dispose();
      _fade.value = 0;
      setState(() => _snapshot = image);
      // Start fading once the frame with the new theme has been drawn.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _snapshot != null) _fade.forward(from: 0);
        });
        WidgetsBinding.instance.scheduleFrame();
      });
    } catch (_) {
      // Snapshot failed: theme still changes, just without the cross-fade.
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(key: _boundary, child: widget.child),
        if (snapshot != null)
          IgnorePointer(
            child: FadeTransition(
              opacity: ReverseAnimation(CurvedAnimation(parent: _fade, curve: Curves.easeInOutCubic)),
              child: RawImage(image: snapshot, fit: BoxFit.fill),
            ),
          ),
      ],
    );
  }
}
