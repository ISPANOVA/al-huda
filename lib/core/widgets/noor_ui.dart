import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_themes.dart';

/// "Noor" design kit: mihrab arches, living sky, solid cards with a gold
/// hairline. Shared by the Home, Prayer, Athkar and More tabs.

// ----------------------------------------------------------------- arch ---

/// Pointed (mihrab) arch on top, rounded bottom corners.
class ArchClipper extends CustomClipper<Path> {
  final double archHeight;
  final double radius;

  const ArchClipper({this.archHeight = 0.22, this.radius = 20});

  static Path path(Size s, {double archHeight = 0.22, double radius = 20}) {
    final w = s.width;
    final h = s.height;
    final ah = math.min(w * archHeight, h * 0.5);
    return Path()
      ..moveTo(0, ah)
      ..cubicTo(0, ah * 0.38, w * 0.3, 0, w / 2, 0)
      ..cubicTo(w * 0.7, 0, w, ah * 0.38, w, ah)
      ..lineTo(w, h - radius)
      ..quadraticBezierTo(w, h, w - radius, h)
      ..lineTo(radius, h)
      ..quadraticBezierTo(0, h, 0, h - radius)
      ..close();
  }

  @override
  Path getClip(Size size) => path(size, archHeight: archHeight, radius: radius);

  @override
  bool shouldReclip(covariant ArchClipper old) => old.archHeight != archHeight || old.radius != radius;
}

class _ArchBorderPainter extends CustomPainter {
  final Color color;
  final double archHeight;
  final double width;

  const _ArchBorderPainter(this.color, this.archHeight, this.width);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    canvas.drawPath(ArchClipper.path(size, archHeight: archHeight), p);
    // inner hairline
    canvas.save();
    canvas.translate(6, 6);
    canvas.drawPath(
      ArchClipper.path(Size(size.width - 12, size.height - 12), archHeight: archHeight),
      p
        ..strokeWidth = width * 0.5
        ..color = color.withValues(alpha: color.a * 0.35),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArchBorderPainter old) => old.color != color || old.archHeight != archHeight;
}

/// Content inside a mihrab-shaped panel with a double gold outline.
class ArchCard extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  final Color? color;
  final double archHeight;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  const ArchCard({
    super.key,
    required this.child,
    this.gradient,
    this.color,
    this.archHeight = 0.22,
    this.padding = const EdgeInsets.fromLTRB(18, 30, 18, 18),
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return CustomPaint(
      foregroundPainter: _ArchBorderPainter(borderColor ?? glass.accent.withValues(alpha: 0.4), archHeight, 1.1),
      child: ClipPath(
        clipper: ArchClipper(archHeight: archHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(color: color ?? noorSurface(context), gradient: gradient),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- cards ---

/// Opaque card surface that reads well over any background ornament.
Color noorSurface(BuildContext context) {
  final glass = GlassTheme.of(context);
  final dark = Theme.of(context).brightness == Brightness.dark;
  final base = glass.backgroundGradient.isNotEmpty ? glass.backgroundGradient.first : Colors.black;
  return dark
      ? Color.alphaBlend(glass.accent.withValues(alpha: 0.06), Color.lerp(base, Colors.white, 0.06)!)
      : Color.alphaBlend(glass.accent.withValues(alpha: 0.05), Colors.white);
}

/// Solid card with a fine gold gradient hairline and soft depth.
class NoorCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final Gradient? gradient;
  final bool highlighted;

  const NoorCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.onLongPress,
    this.radius = 24,
    this.gradient,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = Container(
      margin: margin,
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            glass.accent.withValues(alpha: highlighted ? 0.95 : 0.55),
            glass.accent.withValues(alpha: highlighted ? 0.35 : 0.06),
            glass.accent.withValues(alpha: highlighted ? 0.7 : 0.22),
          ],
        ),
        // Blurred shadows are costly in long lists: only highlighted cards glow.
        boxShadow: !kIsWeb && highlighted
            ? [BoxShadow(color: glass.accent.withValues(alpha: dark ? 0.28 : 0.15), blurRadius: 18, offset: const Offset(0, 4))]
            : null,
      ),
      child: Material(
        color: noorSurface(context),
        borderRadius: BorderRadius.circular(radius - 1.2),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Ink(
            decoration: BoxDecoration(gradient: gradient),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
    return card;
  }
}

/// Large gold-gradient page title used on the main tabs.
class NoorPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const NoorPageHeader(this.title, {super.key, this.subtitle, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (r) => LinearGradient(
                    colors: [glass.accent, Color.lerp(glass.accent, glass.onGlass, 0.45)!],
                  ).createShader(r),
                  child: Text(title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1.2)),
                ),
                if (subtitle != null)
                  Text(subtitle!, style: TextStyle(color: glass.onGlassMuted, height: 1.4)),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Round icon button with a gold ring.
class NoorIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool onDark;

  const NoorIconButton({super.key, required this.icon, required this.onTap, this.tooltip, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final fg = onDark ? Colors.white : glass.accent;
    final button = Material(
      color: onDark ? Colors.white.withValues(alpha: 0.12) : glass.accent.withValues(alpha: 0.10),
      shape: CircleBorder(side: BorderSide(color: fg.withValues(alpha: 0.4))),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(dimension: 46, child: Icon(icon, color: fg, size: 22)),
      ),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8),
      child: tooltip == null ? button : Tooltip(message: tooltip!, child: button),
    );
  }
}

/// Thin ring with a value 0..1 and a centred child.
class NoorRing extends StatelessWidget {
  final double value;
  final double size;
  final double stroke;
  final Color color;
  final Color? track;
  final Widget? child;

  const NoorRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 56,
    this.stroke = 5,
    this.track,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => CustomPaint(
          painter: _RingPainter(v, color, track ?? color.withValues(alpha: 0.15), stroke),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  final Color color;
  final Color track;
  final double stroke;

  _RingPainter(this.v, this.color, this.track, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - stroke / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (v <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * v,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.v != v || old.color != color;
}

/// Section title: small gold star + title + optional action.
class NoorSection extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const NoorSection(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 12, 10),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 14,
            child: CustomPaint(painter: _MiniStar(glass.accent)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: glass.onGlass)),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(action!, style: TextStyle(color: glass.accent, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }
}

class _MiniStar extends CustomPainter {
  final Color color;

  const _MiniStar(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final p = Path();
    for (var i = 0; i < 16; i++) {
      final a = -math.pi / 2 + i * math.pi / 8;
      final rr = i.isEven ? r : r * 0.55;
      final pt = Offset(c.dx + rr * math.cos(a), c.dy + rr * math.sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(p..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MiniStar old) => old.color != color;
}

// ------------------------------------------------------------------ sky ---

enum SkyPhase { night, dawn, morning, afternoon, sunset }

/// Colours of a natural sky for each part of the day (top → horizon).
List<Color> skyColors(SkyPhase p) => switch (p) {
      SkyPhase.night => const [Color(0xFF03050F), Color(0xFF0A1230), Color(0xFF1D2347)],
      SkyPhase.dawn => const [Color(0xFF141634), Color(0xFF55376A), Color(0xFFE08B6E)],
      SkyPhase.morning => const [Color(0xFF15426B), Color(0xFF4F8DB6), Color(0xFFF1D7A0)],
      SkyPhase.afternoon => const [Color(0xFF1F4A6B), Color(0xFF7FA6BE), Color(0xFFF4C27A)],
      SkyPhase.sunset => const [Color(0xFF1E1638), Color(0xFF7E3048), Color(0xFFF09A4A)],
    };

String skyGreeting(SkyPhase p) => switch (p) {
      SkyPhase.night => 'ليلة مباركة',
      SkyPhase.dawn => 'فجر مبارك',
      SkyPhase.morning => 'صباح الخير',
      SkyPhase.afternoon => 'طاب يومك',
      SkyPhase.sunset => 'مساء الخير',
    };

/// Where the sun/moon is: phase, and 0..1 along its arc.
({SkyPhase phase, double t, bool sun}) skyState({
  required DateTime now,
  DateTime? fajr,
  DateTime? sunrise,
  DateTime? dhuhr,
  DateTime? maghrib,
  DateTime? isha,
}) {
  final day = DateTime(now.year, now.month, now.day);
  fajr ??= day.add(const Duration(hours: 4, minutes: 30));
  sunrise ??= day.add(const Duration(hours: 6));
  dhuhr ??= day.add(const Duration(hours: 12));
  maghrib ??= day.add(const Duration(hours: 18));
  isha ??= day.add(const Duration(hours: 19, minutes: 30));
  double frac(DateTime a, DateTime b) =>
      (now.difference(a).inSeconds / math.max(1, b.difference(a).inSeconds)).clamp(0.0, 1.0);

  if (now.isAfter(sunrise) && now.isBefore(maghrib)) {
    final t = frac(sunrise, maghrib);
    final phase = now.isBefore(dhuhr)
        ? SkyPhase.morning
        : (maghrib.difference(now).inMinutes < 40 ? SkyPhase.sunset : SkyPhase.afternoon);
    return (phase: phase, t: t, sun: true);
  }
  if (now.isAfter(fajr) && !now.isAfter(sunrise)) return (phase: SkyPhase.dawn, t: 0.02, sun: true);
  if (!now.isBefore(maghrib) && now.isBefore(isha)) return (phase: SkyPhase.sunset, t: 0.04, sun: false);
  // Night: moon travels from Isha to the next Fajr.
  final start = now.isBefore(fajr) ? isha.subtract(const Duration(days: 1)) : isha;
  final end = now.isBefore(fajr) ? fajr : fajr.add(const Duration(days: 1));
  return (phase: SkyPhase.night, t: frac(start, end), sun: false);
}

/// Painted sky: gradient, stars at night, a dotted orbit with the sun/moon,
/// optional time markers on the orbit, and a mosque skyline at the horizon.
class SkyPainter extends CustomPainter {
  final SkyPhase phase;
  final double t;
  final bool sun;
  final List<double> markers;
  final int highlighted;
  final double orbitTop;

  /// Horizon line as a fraction of the height.
  final double horizonAt;

  const SkyPainter({
    required this.phase,
    required this.t,
    required this.sun,
    this.markers = const [],
    this.highlighted = -1,
    this.orbitTop = 0.28,
    this.horizonAt = 0.80,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final colors = skyColors(phase);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );

    if (phase == SkyPhase.night || phase == SkyPhase.dawn || phase == SkyPhase.sunset) {
      final rnd = math.Random(3);
      final starAlpha = phase == SkyPhase.night ? 1.0 : 0.45;
      for (var i = 0; i < 70; i++) {
        final o = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height * 0.7);
        final r = 0.5 + rnd.nextDouble() * 1.3;
        canvas.drawCircle(o, r, Paint()..color = Colors.white.withValues(alpha: (0.25 + rnd.nextDouble() * 0.6) * starAlpha));
      }
    }

    // orbit: an elliptic arc from the right horizon (east) to the left (west).
    final horizon = size.height * horizonAt;
    final cx = size.width / 2;
    final rx = size.width * 0.42;
    final ry = horizon - size.height * orbitTop;
    Offset at(double f) {
      final a = math.pi * f; // 0 → right, π → left
      return Offset(cx + rx * math.cos(a), horizon - ry * math.sin(a));
    }

    final orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.28);
    for (var f = 0.0; f < 1.0; f += 0.02) {
      canvas.drawLine(at(f), at(f + 0.008), orbit);
    }
    for (var i = 0; i < markers.length; i++) {
      final p = at(markers[i]);
      final hi = i == highlighted;
      canvas.drawCircle(p, hi ? 6 : 3.5, Paint()..color = Colors.white.withValues(alpha: hi ? 1 : 0.6));
      if (hi) {
        canvas.drawCircle(
          p,
          11,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.white.withValues(alpha: 0.6),
        );
      }
    }

    final body = at(t);
    if (sun) {
      canvas.drawCircle(
        body,
        46,
        Paint()
          ..shader = RadialGradient(
            colors: [const Color(0xFFFFE8A3).withValues(alpha: 0.75), const Color(0x00FFE8A3)],
          ).createShader(Rect.fromCircle(center: body, radius: 46)),
      );
      canvas.drawCircle(body, 15, Paint()..color = const Color(0xFFFFF1C4));
    } else {
      canvas.drawCircle(
        body,
        38,
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.white.withValues(alpha: 0.28), Colors.white.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: body, radius: 38)),
      );
      final moon = Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: body, radius: 13)),
        Path()..addOval(Rect.fromCircle(center: body.translate(6, -4), radius: 11)),
      );
      canvas.drawPath(moon, Paint()..color = const Color(0xFFF5EBC8));
    }

    // skyline silhouette
    _skyline(canvas, size, horizon, Color.lerp(colors.first, Colors.black, 0.55)!);
  }

  void _skyline(Canvas canvas, Size size, double horizon, Color color) {
    final w = size.width;
    final fill = Paint()..color = color;
    canvas.drawRect(Rect.fromLTRB(0, horizon, w, size.height), fill);
    final path = Path()..moveTo(0, horizon);
    // gentle dunes
    path.quadraticBezierTo(w * 0.15, horizon - 10, w * 0.3, horizon - 2);
    path.quadraticBezierTo(w * 0.5, horizon + 6, w * 0.7, horizon - 4);
    path.quadraticBezierTo(w * 0.85, horizon - 12, w, horizon - 3);
    path.lineTo(w, horizon + 2);
    path.lineTo(0, horizon + 2);
    canvas.drawPath(path..close(), fill);

    void minaret(double x, double h, double bw) {
      final top = horizon - h;
      canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(x - bw / 2, top, bw, h),
            topLeft: Radius.circular(bw / 2), topRight: Radius.circular(bw / 2)),
        fill,
      );
      canvas.drawRect(Rect.fromLTWH(x - bw, top + h * 0.3, bw * 2, h * 0.04), fill);
      canvas.drawCircle(Offset(x, top - bw * 0.9), bw * 0.32, fill);
    }

    void dome(double cx, double r) {
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, horizon), radius: r), math.pi, math.pi, true, fill);
      canvas.drawCircle(Offset(cx, horizon - r * 1.2), r * 0.12, fill);
    }

    final base = w * 0.2;
    canvas.drawRect(Rect.fromLTWH(base, horizon - 22, w * 0.3, 22), fill);
    dome(base + w * 0.15, w * 0.085);
    dome(base + w * 0.05, w * 0.035);
    dome(base + w * 0.25, w * 0.035);
    minaret(base - 6, 78, 9);
    minaret(base + w * 0.3 + 6, 64, 8);
    // palm
    final px = w * 0.86;
    canvas.drawLine(
      Offset(px, horizon),
      Offset(px - 6, horizon - 46),
      Paint()
        ..color = color
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + (i - 2.5) * 0.55;
      final tip = Offset(px - 6 + 26 * math.cos(a), horizon - 46 + 18 * math.sin(a) + 10);
      canvas.drawLine(
        Offset(px - 6, horizon - 46),
        tip,
        Paint()
          ..color = color
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SkyPainter old) =>
      old.phase != phase || (old.t - t).abs() > 0.001 || old.sun != sun || old.highlighted != highlighted;
}
