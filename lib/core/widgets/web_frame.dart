import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_themes.dart';
import 'gradient_background.dart';

/// Wide screens (a computer, or a tablet in landscape): the app keeps its
/// phone layout in a centred column (a stretched phone UI looks broken),
/// framed on the app's own background with its name beside it. While the
/// Mushaf is on screen the column opens to the full width so two pages fit.
class WebFrame extends StatelessWidget {
  final Widget child;

  const WebFrame({super.key, required this.child});

  static const double columnWidth = 460;

  /// Set by the Mushaf reader while it is visible.
  static final ValueNotifier<bool> wide = ValueNotifier(false);

  /// Browser from 640px; the phone app only on big landscape screens.
  static bool framed(Size size) => kIsWeb ? size.width >= 640 : size.width >= 900 && size.width > size.height;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    if (!framed(size)) return child;
    return ValueListenableBuilder<bool>(valueListenable: wide, builder: (context, isWide, _) => _framed(context, mq, isWide));
  }

  Widget _framed(BuildContext context, MediaQueryData mq, bool isWide) {
    final size = mq.size;
    final glass = GlassTheme.of(context);
    final big = size.height > 720;
    final top = big ? math.max(18.0, mq.viewPadding.top + 8) : mq.viewPadding.top;
    final bottom = big ? math.max(18.0, mq.viewPadding.bottom + 8) : mq.viewPadding.bottom;
    final height = size.height - top - bottom;
    final width = isWide ? math.min(size.width - 36, 1400.0) : columnWidth;
    final radius = BorderRadius.circular(big ? 30 : 0);
    final column = AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.only(top: top, bottom: bottom),
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: glass.accent.withValues(alpha: 0.35)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 30)],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: MediaQuery(
          data: mq.copyWith(
            size: Size(width, height),
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
          ),
          child: child,
        ),
      ),
    );
    final brand = size.width >= 1100 && !isWide
        ? Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: (size.width - columnWidth) / 2,
            child: IgnorePointer(
              child: Material(
                type: MaterialType.transparency,
                child: _Brand(color: glass.accent, text: glass.onGlass, muted: glass.onGlassMuted),
              ),
            ),
          )
        : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        const GradientBackground(child: SizedBox.expand()),
        ?brand,
        Align(alignment: Alignment.topCenter, child: column),
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  final Color color, text, muted;

  const _Brand({required this.color, required this.text, required this.muted});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icon/logo_mark.png', width: 150, height: 150),
            const SizedBox(height: 22),
            Text('الهدى', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 6),
            Text('رفيقك اليومي مع القرآن والذكر',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: text)),
            const SizedBox(height: 18),
            Text(
              'على الموبايل: افتح الموقع وأضِفه إلى الشاشة الرئيسية ليعمل كتطبيق',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.7, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
