import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/noor_ui.dart';

/// The app's colour family: black and gold stay the identity, and each part
/// of the app has its own jewel tone so screens are colourful and easy to
/// find your way around (Quran gold, prayer sapphire, athkar emerald…).
@immutable
class Tone {
  /// Light end of the gradient (icons, text on dark).
  final Color light;

  /// Deep end of the gradient.
  final Color deep;

  const Tone(this.light, this.deep);

  static const gold = Tone(Color(0xFFF3D58A), Color(0xFFC08A2E));
  static const emerald = Tone(Color(0xFF5EE3B0), Color(0xFF0E9F6E));
  static const sapphire = Tone(Color(0xFF8AB8FF), Color(0xFF2F62E0));
  static const amethyst = Tone(Color(0xFFD3A6FF), Color(0xFF7C3AED));
  static const rose = Tone(Color(0xFFFF9BB0), Color(0xFFE0365F));
  static const amber = Tone(Color(0xFFFFCB6B), Color(0xFFEA7A12));
  static const teal = Tone(Color(0xFF6BE6DA), Color(0xFF0F8F84));
  static const sky = Tone(Color(0xFF9EDCFF), Color(0xFF168ACF));
  static const coral = Tone(Color(0xFFFFB199), Color(0xFFE2553A));
  static const slate = Tone(Color(0xFFD5DBE5), Color(0xFF64748B));

  /// The tone as text / icon colour on the page (light on dark, deep on light).
  Color ink(bool dark) => dark ? light : deep;

  /// Middle of the two ends: borders, rings, glows.
  Color get mid => Color.lerp(light, deep, 0.45)!;

  LinearGradient gradient({double opacity = 1}) => LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [light.withValues(alpha: opacity), deep.withValues(alpha: opacity)],
      );

  /// Rich fill for a card in the tone itself (deep enough for white text).
  LinearGradient get solid => LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [mid, deep, Color.lerp(deep, Colors.black, 0.38)!],
      );

  /// A whisper of the tone over a card (for tinted surfaces on black).
  LinearGradient wash(bool dark) => LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [mid.withValues(alpha: dark ? 0.20 : 0.16), mid.withValues(alpha: dark ? 0.04 : 0.03)],
      );

  /// The tone of each part of the app (by the ids used for shortcuts).
  static Tone of(String id) => switch (id) {
        'home' || 'khatmah' => gold,
        'mushaf' || 'search' => emerald,
        'prayer' || 'calendar' || 'imsakiya' => sapphire,
        'athkar' || 'virtues' => rose,
        'media' || 'player' || 'downloads' => amethyst,
        'tasbeeh' || 'more' => teal,
        'qibla' || 'stats' => amber,
        'hifz' || 'review' || 'tasmee' => coral,
        'ruqyah' || 'duas' => sky,
        'appearance' => amethyst,
        'settings' => slate,
        _ => gold,
      };
}

/// A rounded square filled with the tone's gradient and a white icon: the
/// colourful, glossy app-icon look.
class ToneIcon extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final double size;

  const ToneIcon(this.icon, {super.key, required this.tone, this.size = 52});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.34),
        gradient: tone.gradient(),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.34),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [Colors.white.withValues(alpha: 0.28), Colors.white.withValues(alpha: 0)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}

/// A card washed with a tone: dark surface, the tone's glow in a corner and
/// a fine border of the same colour; [ornament] adds a quiet eight-pointed
/// star in the corner.
class ToneCard extends StatelessWidget {
  final Tone tone;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;

  /// Fill with the tone itself (a hero card) instead of a soft wash.
  final bool solid;
  final bool ornament;

  const ToneCard({
    super.key,
    required this.tone,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.onLongPress,
    this.radius = 24,
    this.solid = false,
    this.ornament = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget body = Padding(padding: padding, child: child);
    if (ornament) {
      body = Stack(
        children: [
          PositionedDirectional(
            top: -34,
            end: -34,
            child: IgnorePointer(
              child: SizedBox.square(
                dimension: 120,
                child: CustomPaint(
                  painter: KhatamPainter(
                    (solid ? Colors.white : tone.mid).withValues(alpha: solid ? 0.22 : (dark ? 0.22 : 0.26)),
                  ),
                ),
              ),
            ),
          ),
          body,
        ],
      );
    }
    return Material(
      color: solid ? tone.deep : noorSurface(context),
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: solid ? tone.solid : tone.wash(dark),
            border: Border.all(
              color: solid ? Colors.white.withValues(alpha: 0.16) : tone.mid.withValues(alpha: dark ? 0.30 : 0.35),
            ),
          ),
          child: body,
        ),
      ),
    );
  }
}

/// The eight-pointed star (two interlaced squares) with a smaller one inside:
/// the ornament on cards and headers.
class KhatamPainter extends CustomPainter {
  final Color color;
  final double stroke;

  const KhatamPainter(this.color, {this.stroke = 1.4});

  Path _star(Offset c, double r) {
    final inner = r * math.cos(math.pi / 4) / math.cos(math.pi / 8);
    final p = Path();
    for (var i = 0; i < 16; i++) {
      final a = -math.pi / 2 + i * math.pi / 8;
      final d = i.isEven ? r : inner;
      final o = Offset(c.dx + d * math.cos(a), c.dy + d * math.sin(a));
      if (i == 0) {
        p.moveTo(o.dx, o.dy);
      } else {
        p.lineTo(o.dx, o.dy);
      }
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - stroke;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color;
    canvas.drawPath(_star(c, r), paint);
    canvas.drawPath(_star(c, r * 0.64), paint);
    canvas.drawCircle(c, r * 0.30, paint);
  }

  @override
  bool shouldRepaint(covariant KhatamPainter old) => old.color != color || old.stroke != stroke;
}
