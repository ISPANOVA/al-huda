import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Golden launch screen shown while the app initialises (every launch):
/// the Al-Huda emblem scales in over a slowly turning gold Islamic lattice,
/// then a light shimmer sweeps across it.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const Color background = Color(0xFF000000);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

const _gold = Color(0xFFE2C275);
const _goldLight = Color(0xFFF7E2A3);
const _goldDark = Color(0xFF9C7430);

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
    ..forward();
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logo = CurvedAnimation(parent: _intro, curve: const Interval(0, 0.6, curve: Curves.easeOutBack));
    final text = CurvedAnimation(parent: _intro, curve: const Interval(0.4, 1, curve: Curves.easeOutCubic));
    final shimmer = CurvedAnimation(parent: _intro, curve: const Interval(0.55, 1, curve: Curves.easeInOut));
    final size = MediaQuery.sizeOf(context);
    final logoSize = math.min(size.width * 0.62, 260.0);
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.15),
          radius: 1.05,
          colors: [Color(0xFF3B2C0E), Color(0xFF171106), Color(0xFF000000)],
          stops: [0, 0.5, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _LatticePainter(_loop))),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([logo, _loop, shimmer]),
                  builder: (context, child) {
                    final pulse = 0.5 + 0.5 * math.sin(_loop.value * 2 * math.pi);
                    return Transform.scale(
                      scale: 0.55 + 0.45 * logo.value,
                      child: Opacity(
                        opacity: logo.value.clamp(0.0, 1.0),
                        child: Container(
                          width: logoSize,
                          height: logoSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _gold.withValues(alpha: 0.18 + 0.14 * pulse),
                                blurRadius: 60 + 30 * pulse,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ShaderMask(
                            blendMode: BlendMode.srcATop,
                            shaderCallback: (rect) {
                              final x = -1.5 + 3.0 * shimmer.value;
                              return LinearGradient(
                                begin: Alignment(x - 0.4, -1),
                                end: Alignment(x + 0.4, 1),
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: shimmer.value < 1 ? 0.55 : 0),
                                  Colors.transparent,
                                ],
                                stops: const [0.35, 0.5, 0.65],
                              ).createShader(rect);
                            },
                            child: child,
                          ),
                        ),
                      ),
                    );
                  },
                  child: Image.asset('assets/icon/logo_mark.png', fit: BoxFit.contain),
                ),
                const SizedBox(height: 26),
                FadeTransition(
                  opacity: text,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.5), end: Offset.zero).animate(text),
                    child: ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (rect) => const LinearGradient(
                        colors: [_goldDark, _goldLight, _gold, _goldDark],
                        stops: [0, 0.4, 0.6, 1],
                      ).createShader(rect),
                      child: const Text(
                        'رفيقك اليومي مع القرآن والذكر',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 36,
            child: FadeTransition(
              opacity: text,
              child: const Column(
                children: [
                  Text(
                    'صدقة جارية عن روح والدي سمير حجازي، وعن سعد صالح،\nوعن جميع المسلمين الأحياء منهم والأموات',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xB3F7E2A3), decoration: TextDecoration.none),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'SMRH',
                    style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w800,
                      color: _gold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Faint gold eight-pointed-star lattice that turns very slowly, with a few
/// twinkling gold sparks.
class _LatticePainter extends CustomPainter {
  final Animation<double> t;

  _LatticePainter(this.t) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    // The very first frame can be laid out at zero size: nothing to draw.
    if (size.width <= 0 || size.height <= 0) return;
    final c = size.center(Offset.zero);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(t.value * 2 * math.pi / 24);
    final step = size.width / 4.2;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _gold.withValues(alpha: 0.10);
    final n = (size.longestSide / step).ceil() + 2;
    for (var gy = -n; gy <= n; gy++) {
      for (var gx = -n; gx <= n; gx++) {
        final o = Offset(gx * step + (gy.isOdd ? step / 2 : 0), gy * step * 0.866);
        final r = step * 0.32;
        for (var k = 0; k < 2; k++) {
          final path = Path();
          for (var i = 0; i < 4; i++) {
            final a = k * math.pi / 4 + math.pi / 4 + i * math.pi / 2;
            final p = o + Offset(r * math.cos(a), r * math.sin(a));
            i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
          }
          path.close();
          canvas.drawPath(path, stroke);
        }
        canvas.drawCircle(o, step * 0.12, stroke);
      }
    }
    canvas.restore();

    final rnd = math.Random(11);
    for (var i = 0; i < 36; i++) {
      final p = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      final phase = (t.value * 3 + rnd.nextDouble()) % 1;
      canvas.drawCircle(
        p,
        0.8 + rnd.nextDouble() * 1.6,
        Paint()..color = _goldLight.withValues(alpha: 0.1 + 0.5 * math.sin(phase * math.pi)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LatticePainter oldDelegate) => false;
}
