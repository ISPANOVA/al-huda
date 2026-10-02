import 'package:flutter/material.dart';

import '../theme/app_themes.dart';
import 'background_patterns.dart';

/// Vibrant multi-stop gradient with soft light orbs behind the glass layers.
class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final size = MediaQuery.sizeOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: glass.backgroundGradient,
            ),
          ),
        ),
        _Orb(color: glass.orbs[0], diameter: size.width * 0.9, top: -size.width * 0.3, right: -size.width * 0.25),
        _Orb(color: glass.orbs[1], diameter: size.width * 0.7, top: size.height * 0.35, left: -size.width * 0.35),
        _Orb(color: glass.orbs[2], diameter: size.width * 0.8, bottom: -size.width * 0.3, right: -size.width * 0.2),
        const _IslamicPatternOverlay(),
        child,
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double diameter;
  final double? top, left, right, bottom;

  const _Orb({required this.color, required this.diameter, this.top, this.left, this.right, this.bottom});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withValues(alpha: 0.45), color.withValues(alpha: 0.0)],
            ),
          ),
        ),
      ),
    );
  }
}

/// The user's chosen ornament (see BackgroundStyle), painted in the accent.
class _IslamicPatternOverlay extends StatelessWidget {
  const _IslamicPatternOverlay();

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: RepaintBoundary(
        child: ValueListenableBuilder(
          valueListenable: BackgroundStyle.current,
          builder: (context, style, _) => CustomPaint(
            painter: PatternPainter(
              pattern: style.pattern,
              color: glass.accent.withValues(alpha: dark ? 0.11 : 0.16),
              strength: style.strength,
            ),
          ),
        ),
      ),
    );
  }
}

/// Standard page scaffold: gradient background + transparent app bar.
class GlassScaffold extends StatelessWidget {
  final String? title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottom;
  final bool showBack;
  final Widget? titleWidget;

  const GlassScaffold({
    super.key,
    this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottom,
    this.showBack = true,
    this.titleWidget,
  });

  @override
  Widget build(BuildContext context) {
    // The background lives *outside* the Scaffold and behind a RepaintBoundary,
    // so the keyboard animation (which resizes the Scaffold body every frame)
    // never re-lays-out or repaints it. This removes the typing/search stutter.
    return Stack(
      children: [
        const Positioned.fill(child: RepaintBoundary(child: GradientBackground(child: SizedBox.expand()))),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          floatingActionButton: floatingActionButton,
          appBar: (title != null || titleWidget != null)
              ? AppBar(
                  automaticallyImplyLeading: showBack,
                  title: titleWidget ?? Text(title!),
                  actions: actions,
                )
              : null,
          body: SafeArea(
            child: Column(
              children: [
                Expanded(child: body),
                ?bottom,
              ],
            ),
          ),
        ),
      ],
    );
  }
}
