import 'package:flutter/material.dart';

/// Soft fade + slight upward slide used for every screen in the app.
class FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.035), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}

/// Keeps every tab alive (like IndexedStack) but cross-fades between them with
/// a gentle scale — the "fade through" pattern.
///
/// One controller owned here drives the transition, so it always completes;
/// only the incoming and outgoing tabs are painted, the rest stay offstage.
class FadeThroughIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const FadeThroughIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 320),
  });

  @override
  State<FadeThroughIndexedStack> createState() => _FadeThroughIndexedStackState();
}

class _FadeThroughIndexedStackState extends State<FadeThroughIndexedStack> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration, value: 1)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) setState(() => _previous = null);
    });

  late int _current = widget.index;
  int? _previous;

  late final Animation<double> _fadeIn =
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 1, curve: Curves.easeOutCubic));
  // Slide instead of scale: scaling text-heavy pages (the Mushaf) forces every
  // glyph to be re-rasterised each frame, which stutters; translating doesn't.
  late final Animation<Offset> _slideIn = Tween(begin: const Offset(0, 0.025), end: Offset.zero)
      .animate(CurvedAnimation(parent: _controller, curve: const Interval(0.3, 1, curve: Curves.easeOutCubic)));
  late final Animation<double> _fadeOut =
      ReverseAnimation(CurvedAnimation(parent: _controller, curve: const Interval(0, 0.3, curve: Curves.easeIn)));

  @override
  void didUpdateWidget(covariant FadeThroughIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != _current) {
      _previous = _current;
      _current = widget.index;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _layer(i),
      ],
    );
  }

  Widget _layer(int i) {
    final isCurrent = i == _current;
    final isPrevious = i == _previous;
    final visible = isCurrent || isPrevious;
    // Same widget structure for every tab in every state keeps their State alive.
    return Offstage(
      offstage: !visible,
      child: TickerMode(
        enabled: visible,
        child: IgnorePointer(
          ignoring: !isCurrent,
          child: FadeTransition(
            opacity: isCurrent ? _fadeIn : (isPrevious ? _fadeOut : kAlwaysDismissedAnimation),
            child: SlideTransition(
              position: isCurrent ? _slideIn : const AlwaysStoppedAnimation(Offset.zero),
              child: RepaintBoundary(child: widget.children[i]),
            ),
          ),
        ),
      ),
    );
  }
}
