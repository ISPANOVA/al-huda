import 'package:flutter/material.dart';

import '../theme/app_themes.dart';
import 'gradient_background.dart';

/// Browser on a computer or tablet: the app keeps its phone layout in a
/// centred column (a stretched 1440px-wide phone UI looks broken), framed on
/// the app's own background with its name beside it on wide screens.
class WebFrame extends StatelessWidget {
  final Widget child;

  const WebFrame({super.key, required this.child});

  static const double columnWidth = 460;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    if (size.width < 640) return child;
    final glass = GlassTheme.of(context);
    final margin = size.height > 720 ? 18.0 : 0.0;
    final height = size.height - margin * 2;
    final radius = BorderRadius.circular(margin > 0 ? 30 : 0);
    final column = Container(
      width: columnWidth,
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
            size: Size(columnWidth, height),
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
          ),
          child: child,
        ),
      ),
    );
    final brand = size.width >= 1100
        ? Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: (size.width - columnWidth) / 2,
            child: IgnorePointer(child: _Brand(color: glass.accent, text: glass.onGlass, muted: glass.onGlassMuted)),
          )
        : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        const GradientBackground(child: SizedBox.expand()),
        ?brand,
        Center(child: column),
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
