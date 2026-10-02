import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Decorative background ornaments the user can pick (المظهر ← زخرفة الخلفية).
enum BgPattern { none, khatam, arabesque, hexagram, mashrabiya, mihrab, starryNight }

extension BgPatternInfo on BgPattern {
  String get labelAr => switch (this) {
        BgPattern.none => 'سادة',
        BgPattern.khatam => 'نجمة الخاتم',
        BgPattern.arabesque => 'أرابيسك',
        BgPattern.hexagram => 'نجوم سداسية',
        BgPattern.mashrabiya => 'مشربية',
        BgPattern.mihrab => 'محراب',
        BgPattern.starryNight => 'سماء الليل',
      };

  String get hintAr => switch (this) {
        BgPattern.none => 'خلفية هادئة بدون زخرفة',
        BgPattern.khatam => 'نجوم ثمانية متشابكة',
        BgPattern.arabesque => 'دوائر متداخلة كالزهور',
        BgPattern.hexagram => 'نسيج هندسي سداسي',
        BgPattern.mashrabiya => 'شبكة خشبية تقليدية',
        BgPattern.mihrab => 'قوس محراب وقنديل',
        BgPattern.starryNight => 'نجوم متلألئة وهلال',
      };
}

/// Current choice, set by SettingsCubit; read by every GradientBackground.
class BackgroundStyle {
  BackgroundStyle._();

  static final ValueNotifier<({BgPattern pattern, double strength})> current =
      ValueNotifier((pattern: BgPattern.khatam, strength: 1.0));

  static void set(BgPattern pattern, double strength) {
    final v = (pattern: pattern, strength: strength);
    if (current.value != v) current.value = v;
  }
}

/// Paints [pattern] in [color]; strongest near the top, fading downwards.
class PatternPainter extends CustomPainter {
  final BgPattern pattern;
  final Color color;
  final double strength;

  /// Smaller cells for thumbnails.
  final double scale;

  const PatternPainter({required this.pattern, required this.color, this.strength = 1, this.scale = 1});

  @override
  void paint(Canvas canvas, Size size) {
    if (pattern == BgPattern.none || size.isEmpty) return;
    final a = (color.a * strength).clamp(0.0, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * scale.clamp(0.6, 1.0)
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: a), color.withValues(alpha: a * 0.35)],
      ).createShader(Offset.zero & size);
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..shader = paint.shader;

    switch (pattern) {
      case BgPattern.none:
        return;
      case BgPattern.khatam:
        _khatam(canvas, size, paint);
      case BgPattern.arabesque:
        _arabesque(canvas, size, paint);
      case BgPattern.hexagram:
        _hexagram(canvas, size, paint);
      case BgPattern.mashrabiya:
        _mashrabiya(canvas, size, paint, fill);
      case BgPattern.mihrab:
        _mihrab(canvas, size, paint, fill);
      case BgPattern.starryNight:
        _starry(canvas, size, paint, fill);
    }
  }

  static Path _star(Offset c, double outer, double inner, int points, [double rot = -math.pi / 2]) {
    final p = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? outer : inner;
      final ang = rot + i * math.pi / points;
      final pt = Offset(c.dx + r * math.cos(ang), c.dy + r * math.sin(ang));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  /// Classic octagram-and-cross tiling: an 8-pointed star in every cell,
  /// four-armed crosses where the cells meet, joined by strapwork.
  void _khatam(Canvas canvas, Size size, Paint p) {
    final cell = 84.0 * scale;
    final ro = cell * 0.5;
    final ri = ro * 0.62;
    for (var y = 0.0; y <= size.height + cell; y += cell) {
      for (var x = 0.0; x <= size.width + cell; x += cell) {
        final c = Offset(x, y);
        canvas.drawPath(_star(c, ro, ri, 8, -math.pi / 2 + math.pi / 8), p);
        canvas.drawPath(_star(c, ri * 0.72, ri * 0.48, 8, -math.pi / 2 + math.pi / 8), p);
        canvas.drawCircle(c, ri * 0.22, p);
        // cross in the gap between four stars
        final g = Offset(x + cell / 2, y + cell / 2);
        canvas.drawPath(_star(g, cell * 0.24, cell * 0.1, 4, 0), p);
      }
    }
  }

  /// Overlapping circles forming four-petal flowers, with small rosettes.
  void _arabesque(Canvas canvas, Size size, Paint p) {
    final cell = 70.0 * scale;
    final r = cell / math.sqrt2;
    for (var y = 0.0; y <= size.height + cell; y += cell) {
      for (var x = 0.0; x <= size.width + cell; x += cell) {
        final c = Offset(x, y);
        canvas.drawCircle(c, r, p);
        canvas.drawCircle(Offset(x + cell / 2, y + cell / 2), cell * 0.09, p);
        canvas.drawCircle(c, cell * 0.16, p);
      }
    }
  }

  /// Six-pointed stars on a hexagonal lattice, linked by hexagons.
  void _hexagram(Canvas canvas, Size size, Paint p) {
    final r = 34.0 * scale;
    final dx = r * math.sqrt(3) * 1.5;
    final dy = r * 1.5 * 1.73;
    var row = 0;
    for (var y = 0.0; y <= size.height + dy; y += dy / 2, row++) {
      for (var x = (row.isOdd ? dx / 2 : 0.0); x <= size.width + dx; x += dx) {
        final c = Offset(x, y);
        canvas.drawPath(_star(c, r, r * 0.58, 6), p);
        final hex = Path();
        for (var i = 0; i < 6; i++) {
          final ang = i * math.pi / 3;
          final pt = Offset(c.dx + r * 0.42 * math.cos(ang), c.dy + r * 0.42 * math.sin(ang));
          i == 0 ? hex.moveTo(pt.dx, pt.dy) : hex.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(hex..close(), p);
      }
    }
  }

  /// Turned-wood lattice: diagonal slats with beads at the joints.
  void _mashrabiya(Canvas canvas, Size size, Paint p, Paint fill) {
    final cell = 30.0 * scale;
    final span = size.width + size.height;
    for (var d = -size.height; d <= span; d += cell) {
      canvas.drawLine(Offset(d, 0), Offset(d + size.height, size.height), p);
      canvas.drawLine(Offset(d + size.height, 0), Offset(d, size.height), p);
    }
    for (var y = 0.0; y <= size.height + cell; y += cell / 2) {
      final odd = ((y / (cell / 2)).round()).isOdd;
      for (var x = odd ? cell / 2 : 0.0; x <= size.width + cell; x += cell) {
        canvas.drawCircle(Offset(x, y), cell * 0.11, fill);
        canvas.drawCircle(Offset(x, y), cell * 0.22, p);
      }
    }
  }

  /// A single pointed mihrab arch framing the page, with a hanging lantern.
  void _mihrab(Canvas canvas, Size size, Paint p, Paint fill) {
    final w = size.width;
    final h = size.height;
    for (final inset in [w * 0.06, w * 0.09]) {
      final left = inset;
      final right = w - inset;
      final springY = h * 0.32 + inset;
      final apex = Offset(w / 2, h * 0.05 + inset);
      final arch = Path()
        ..moveTo(left, h + 10)
        ..lineTo(left, springY)
        ..quadraticBezierTo(left, apex.dy + (springY - apex.dy) * 0.25, apex.dx, apex.dy)
        ..quadraticBezierTo(right, apex.dy + (springY - apex.dy) * 0.25, right, springY)
        ..lineTo(right, h + 10);
      canvas.drawPath(arch, p);
    }
    // lantern
    final top = h * 0.05 + w * 0.09;
    final chainEnd = top + h * 0.12;
    canvas.drawLine(Offset(w / 2, top), Offset(w / 2, chainEnd), p);
    final lw = w * 0.08;
    final body = Path()
      ..moveTo(w / 2 - lw * 0.35, chainEnd)
      ..lineTo(w / 2 + lw * 0.35, chainEnd)
      ..lineTo(w / 2 + lw * 0.6, chainEnd + lw * 0.7)
      ..lineTo(w / 2 + lw * 0.35, chainEnd + lw * 1.5)
      ..lineTo(w / 2 - lw * 0.35, chainEnd + lw * 1.5)
      ..lineTo(w / 2 - lw * 0.6, chainEnd + lw * 0.7)
      ..close();
    canvas.drawPath(body, p);
    canvas.drawCircle(Offset(w / 2, chainEnd + lw * 0.75), lw * 0.18, fill);
    canvas.drawLine(Offset(w / 2, chainEnd + lw * 1.5), Offset(w / 2, chainEnd + lw * 1.9), p);
    // small stars along the arch
    for (final f in [0.2, 0.35, 0.65, 0.8]) {
      canvas.drawPath(_star(Offset(w * f, h * 0.2), w * 0.012, w * 0.005, 4, 0), fill);
    }
  }

  /// Scattered twinkles and a crescent in the corner.
  void _starry(Canvas canvas, Size size, Paint p, Paint fill) {
    final rnd = math.Random(7);
    final count = (size.width * size.height / (5200 * scale * scale)).round().clamp(14, 320);
    for (var i = 0; i < count; i++) {
      final c = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      final big = rnd.nextDouble() < 0.12;
      final r = (big ? 7.0 : 1.8 + rnd.nextDouble() * 2.0) * scale.clamp(0.5, 1.0);
      if (big) {
        canvas.drawPath(_star(c, r, r * 0.22, 4, 0), fill);
        canvas.drawCircle(c, r * 0.18, fill);
      } else {
        canvas.drawCircle(c, r * 0.6, fill);
      }
    }
    final m = Offset(size.width * 0.18, size.height * 0.09);
    final mr = size.width * 0.09;
    final crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: m, radius: mr)),
      Path()..addOval(Rect.fromCircle(center: m.translate(mr * 0.38, -mr * 0.18), radius: mr * 0.86)),
    );
    canvas.drawPath(crescent, fill);
  }

  @override
  bool shouldRepaint(covariant PatternPainter old) =>
      old.pattern != pattern || old.color != color || old.strength != strength || old.scale != scale;
}
