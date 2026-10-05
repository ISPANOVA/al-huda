import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_themes.dart';

enum FlagKind { egypt, saudi }

/// A national flag filling its box: still, or waving while [waving] is on.
///
/// The flag is drawn once into an image; waving then only slides thin
/// vertical strips of that image up and down (plus a light/shade band), so a
/// frame costs a few dozen image blits — cheap in the browser too. Nothing
/// ticks while the flag is still.
class WavingFlag extends StatefulWidget {
  final FlagKind kind;
  final bool waving;

  const WavingFlag({super.key, required this.kind, required this.waving});

  @override
  State<WavingFlag> createState() => _WavingFlagState();
}

class _WavingFlagState extends State<WavingFlag> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900));
  ui.Image? _image;
  String? _key;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(WavingFlag old) {
    super.didUpdateWidget(old);
    if (old.waving != widget.waving) _sync();
  }

  void _sync() {
    if (widget.waving) {
      if (!_t.isAnimating) _t.repeat();
    } else {
      _t.stop();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    _image?.dispose();
    super.dispose();
  }

  ui.Image? _imageFor(Size size, double dpr) {
    final key = '${widget.kind} ${size.width.round()}x${size.height.round()}@$dpr';
    if (key == _key) return _image;
    _image?.dispose();
    _image = null;
    _key = key;
    final w = (size.width * dpr).ceil(), h = (size.height * dpr).ceil();
    if (w <= 0 || h <= 0) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(dpr);
    paintFlag(canvas, size, widget.kind);
    final picture = recorder.endRecording();
    try {
      _image = picture.toImageSync(w, h);
    } catch (_) {
      _image = null;
    }
    picture.dispose();
    return _image;
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(builder: (context, c) {
      final size = c.biggest;
      if (!size.isFinite || size.isEmpty) return const SizedBox.shrink();
      return RepaintBoundary(
        child: CustomPaint(
          size: size,
          painter: _FlagPainter(
            kind: widget.kind,
            image: _imageFor(size, dpr),
            t: _t,
            waving: widget.waving,
          ),
        ),
      );
    });
  }
}

class _FlagPainter extends CustomPainter {
  final FlagKind kind;
  final ui.Image? image;
  final Animation<double> t;
  final bool waving;

  _FlagPainter({required this.kind, required this.image, required this.t, required this.waving}) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final img = image;
    if (img == null) {
      paintFlag(canvas, size, kind);
      return;
    }
    final paint = Paint()..filterQuality = FilterQuality.low;
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    if (!waving) {
      canvas.drawImageRect(img, src, Offset.zero & size, paint);
      return;
    }
    // Waving: strips slide on a travelling sine wave that grows from the
    // pole (left) to the free end, each strip lit or shaded by its slope.
    final w = size.width, h = size.height;
    final strips = kIsWeb ? 44 : 64;
    final sw = w / strips;
    final maxAmp = h * 0.05;
    final scaleX = img.width / w;
    final phase0 = t.value * 2 * math.pi;
    final shade = Paint();
    for (var i = 0; i < strips; i++) {
      final x = i * sw;
      final f = (x + sw / 2) / w;
      final a = 2 * math.pi * f * 1.35 - phase0;
      final amp = maxAmp * (0.2 + 0.8 * f);
      final dy = amp * math.sin(a);
      final s = Rect.fromLTWH(x * scaleX, 0, sw * scaleX, src.height);
      final d = Rect.fromLTWH(x, dy - maxAmp, sw + 0.7, h + 2 * maxAmp);
      canvas.drawImageRect(img, s, d, paint);
      final light = math.cos(a) * (0.08 + 0.12 * f);
      shade.color = light > 0
          ? Colors.white.withValues(alpha: light * 0.9)
          : Colors.black.withValues(alpha: -light * 1.4);
      canvas.drawRect(Rect.fromLTWH(x, 0, sw + 0.7, h), shade);
    }
  }

  @override
  bool shouldRepaint(covariant _FlagPainter old) =>
      old.image != image || old.waving != waving || old.kind != kind;
}

/// Draws the whole flag to fill [size].
void paintFlag(Canvas canvas, Size size, FlagKind kind) {
  switch (kind) {
    case FlagKind.egypt:
      _egypt(canvas, size);
    case FlagKind.saudi:
      _saudi(canvas, size);
  }
}

void _egypt(Canvas canvas, Size size) {
  final w = size.width, h = size.height;
  final band = h / 3;
  canvas.drawRect(Rect.fromLTWH(0, 0, w, band + 0.5), Paint()..color = const Color(0xFFCE1126));
  canvas.drawRect(Rect.fromLTWH(0, band, w, band + 0.5), Paint()..color = Colors.white);
  canvas.drawRect(Rect.fromLTWH(0, band * 2, w, band), Paint()..color = Colors.black);

  // The golden eagle in the white band (drawn in a 100×100 box).
  final e = band * 0.92;
  canvas.save();
  canvas.translate(w / 2 - e / 2, band + (band - e) / 2);
  canvas.scale(e / 100);
  const gold = Color(0xFFC09300);
  const deep = Color(0xFF8C6A00);
  final fill = Paint()..color = gold;
  final line = Paint()
    ..color = deep
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round;

  // wings
  Path wing(bool left) {
    final s = left ? -1.0 : 1.0;
    double x(double v) => 50 + s * v;
    return Path()
      ..moveTo(x(8), 34)
      ..quadraticBezierTo(x(22), 14, x(40), 12)
      ..lineTo(x(37), 22)
      ..lineTo(x(44), 22)
      ..lineTo(x(40), 32)
      ..lineTo(x(46), 34)
      ..lineTo(x(40), 44)
      ..lineTo(x(44), 48)
      ..quadraticBezierTo(x(30), 66, x(10), 64)
      ..close();
  }

  canvas.drawPath(wing(true), fill);
  canvas.drawPath(wing(false), fill);
  for (final s in [-1.0, 1.0]) {
    for (var k = 0; k < 4; k++) {
      final y = 30.0 + k * 8;
      canvas.drawLine(Offset(50 + s * 16, y), Offset(50 + s * (30 + k * 2), y - 6), line);
    }
  }
  // head and neck
  canvas.drawPath(
    Path()
      ..moveTo(44, 30)
      ..quadraticBezierTo(42, 16, 47, 12)
      ..quadraticBezierTo(53, 8, 55, 14)
      ..lineTo(60, 15)
      ..lineTo(55, 18)
      ..quadraticBezierTo(56, 24, 56, 30)
      ..close(),
    fill,
  );
  canvas.drawCircle(const Offset(51, 13.5), 1.3, Paint()..color = deep);
  // shield on the chest
  final shield = Path()
    ..moveTo(40, 31)
    ..lineTo(60, 31)
    ..lineTo(60, 56)
    ..quadraticBezierTo(60, 66, 50, 70)
    ..quadraticBezierTo(40, 66, 40, 56)
    ..close();
  canvas.drawPath(shield, fill);
  canvas.save();
  canvas.clipPath(shield);
  canvas.drawRect(const Rect.fromLTWH(43, 34, 4.5, 36), Paint()..color = const Color(0xFFCE1126));
  canvas.drawRect(const Rect.fromLTWH(47.5, 34, 5, 36), Paint()..color = Colors.white);
  canvas.drawRect(const Rect.fromLTWH(52.5, 34, 4.5, 36), Paint()..color = Colors.black);
  canvas.restore();
  canvas.drawPath(shield, line);
  // tail and the scroll under the feet
  canvas.drawPath(
    Path()
      ..moveTo(44, 68)
      ..lineTo(50, 80)
      ..lineTo(56, 68)
      ..close(),
    fill,
  );
  final scroll = RRect.fromRectAndRadius(const Rect.fromLTWH(30, 80, 40, 9), const Radius.circular(3));
  canvas.drawRRect(scroll, fill);
  canvas.drawRRect(scroll.deflate(2), Paint()..color = const Color(0xFFE9D27A));
  canvas.restore();
}

void _saudi(Canvas canvas, Size size) {
  final w = size.width, h = size.height;
  canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF006C35));

  // The shahada and the sword, a little softened so the station's name
  // written over the flag stays easy to read.
  canvas.saveLayer(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: 0.6));
  final tp = TextPainter(
    text: const TextSpan(
      text: 'لا إله إلا الله محمد رسول الله',
      style: TextStyle(fontFamily: AppFonts.display, fontSize: 100, color: Colors.white, fontWeight: FontWeight.w700),
    ),
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.center,
  )..layout();
  final target = math.min(w * 0.5, h * 1.6);
  final scale = target / tp.width;
  canvas.save();
  canvas.translate(w / 2 - target / 2, h * 0.42 - tp.height * scale / 2);
  canvas.scale(scale);
  tp.paint(canvas, Offset.zero);
  canvas.restore();
  tp.dispose();

  // The sword beneath: blade to the left, hilt on the right.
  final white = Paint()..color = Colors.white;
  final y = h * 0.70;
  final t = math.max(2.0, h * 0.022);
  final left = w / 2 - target * 0.46, right = w / 2 + target * 0.36;
  canvas.drawPath(
    Path()
      ..moveTo(left, y)
      ..quadraticBezierTo(left + target * 0.06, y - t * 1.4, left + target * 0.14, y - t * 0.6)
      ..lineTo(right, y - t * 0.6)
      ..lineTo(right, y + t * 0.6)
      ..lineTo(left + target * 0.14, y + t * 0.6)
      ..quadraticBezierTo(left + target * 0.06, y + t * 0.2, left, y)
      ..close(),
    white,
  );
  // guard, grip and pommel
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(right + t * 0.6, y), width: t * 1.2, height: t * 4.2),
        Radius.circular(t * 0.6)),
    white,
  );
  canvas.drawRect(Rect.fromLTWH(right + t * 1.2, y - t * 0.55, target * 0.09, t * 1.1), white);
  canvas.drawCircle(Offset(right + t * 1.2 + target * 0.09 + t * 0.5, y), t * 0.85, white);
  canvas.restore();
}
