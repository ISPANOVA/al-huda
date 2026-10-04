import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Every screen slides in from the reading side (RTL: from the left) while
/// the page underneath drifts a little. Pure translations: no opacity layer
/// (saveLayer) and no re-raster of text, so push *and* back stay at full
/// frame rate even over heavy pages.
class FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeSlidePageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 320);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 260);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    final dir = rtl ? -1.0 : 1.0;
    final inCurve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final outCurve = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return SlideTransition(
      position: Tween(begin: Offset.zero, end: Offset(-0.22 * dir, 0)).animate(outCurve),
      child: SlideTransition(
        position: Tween(begin: Offset(dir, 0), end: Offset.zero).animate(inCurve),
        child: RepaintBoundary(child: child),
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
      if (kIsWeb) {
        // The browser has no raster cache: fading whole tabs costs a full
        // offscreen layer per frame. Switch instantly there.
        _previous = null;
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
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
