import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_themes.dart';
import '../../core/utils/arabic_utils.dart';

/// Shared visual pieces of the media section (الوسائط).

/// Stable, pleasant hue per reciter/station so each card has its own colour.
Color mediaTint(String seed, {double s = 0.42, double l = 0.30}) {
  var h = 0;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  // Keep to warm golds, teals, emeralds, indigos and wines — no neon.
  const hues = [38.0, 168.0, 152.0, 222.0, 340.0, 24.0, 196.0, 268.0, 8.0, 130.0];
  return HSLColor.fromAHSL(1, hues[h % hues.length], s, l).toColor();
}

String reciterInitials(String name) {
  final parts = name
      .split(' ')
      .where((p) => p.isNotEmpty && !const {'عبد', 'أبو', 'بن', 'محمد', 'صديق', 'علي', 'خليل'}.contains(p))
      .toList();
  if (parts.isEmpty) return name.characters.first;
  String first(String w) => (w.startsWith('ال') && w.length > 3 ? w.substring(2) : w).characters.first;
  return parts.length == 1 ? first(parts.first) : '${first(parts.first)} ${first(parts.last)}';
}

/// Press feedback: gently scales the child while pressed.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.scale = 0.965});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Animated equalizer bars (static when not playing).
class Equalizer extends StatefulWidget {
  final bool playing;
  final Color color;
  final double size;
  final int bars;

  const Equalizer({super.key, required this.playing, required this.color, this.size = 18, this.bars = 4});

  @override
  State<Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<Equalizer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.playing) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant Equalizer old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.playing && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(painter: _EqPainter(_c, widget.color, widget.bars, widget.playing)),
      ),
    );
  }
}

class _EqPainter extends CustomPainter {
  final Animation<double> t;
  final Color color;
  final int bars;
  final bool playing;

  _EqPainter(this.t, this.color, this.bars, this.playing) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / (bars * 1.7);
    final gap = (size.width - w * bars) / (bars - 1);
    final p = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w;
    for (var i = 0; i < bars; i++) {
      final phase = t.value * 2 * math.pi * (1 + i * 0.37) + i * 1.3;
      final h = playing ? (0.28 + 0.72 * (0.5 + 0.5 * math.sin(phase)).abs()) : const [0.35, 0.6, 0.45, 0.3][i % 4];
      final x = w / 2 + i * (w + gap);
      canvas.drawLine(Offset(x, size.height - w / 2), Offset(x, size.height - w / 2 - (size.height - w) * h), p);
    }
  }

  @override
  bool shouldRepaint(covariant _EqPainter old) => old.playing != playing || old.color != color;
}

/// Pulsing red "مباشر" pill.
class LiveBadge extends StatefulWidget {
  final String label;

  const LiveBadge({super.key, this.label = 'مباشر'});

  @override
  State<LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<LiveBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE5484D),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: const Color(0xFFE5484D).withValues(alpha: 0.45), blurRadius: 12)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
            child: const Icon(Icons.circle, size: 7, color: Colors.white),
          ),
          const SizedBox(width: 5),
          Text(widget.label,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, height: 1.2)),
        ],
      ),
    );
  }
}

/// Monogram portrait: initials over a jewel-tone gradient and a faint star.
class MonogramAvatar extends StatelessWidget {
  final String name;
  final String seed;
  final double size;
  final bool ring;

  const MonogramAvatar({super.key, required this.name, required this.seed, this.size = 72, this.ring = true});

  @override
  Widget build(BuildContext context) {
    final accent = GlassTheme.of(context).accent;
    final tint = mediaTint(seed);
    final avatar = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color.lerp(tint, Colors.white, 0.08)!, Color.lerp(tint, Colors.black, 0.55)!],
        ),
      ),
      child: CustomPaint(
        painter: StarPainter(color: accent.withValues(alpha: 0.22), strokeWidth: size * 0.012, scale: 0.78),
        child: Center(
          child: Text(
            reciterInitials(name),
            style: TextStyle(
              fontSize: size * 0.28,
              fontWeight: FontWeight.w900,
              color: Colors.white.withValues(alpha: 0.95),
              height: 1.1,
            ),
          ),
        ),
      ),
    );
    if (!ring) return SizedBox.square(dimension: size, child: avatar);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.035),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [accent, accent.withValues(alpha: 0.25), accent]),
      ),
      child: Container(
        padding: EdgeInsets.all(size * 0.03),
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
        child: avatar,
      ),
    );
  }
}

/// Eight-pointed star (two overlapping squares) outline.
class StarPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double scale;
  final bool fill;

  const StarPainter({required this.color, this.strokeWidth = 1.2, this.scale = 1, this.fill = false});

  static Path path(Offset c, double r) {
    final p = Path();
    for (var i = 0; i < 16; i++) {
      final a = -math.pi / 2 + i * math.pi / 8;
      final rr = i.isEven ? r : r * 0.76;
      final pt = Offset(c.dx + rr * math.cos(a), c.dy + rr * math.sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 * scale;
    canvas.drawPath(
      path(size.center(Offset.zero), r),
      Paint()
        ..color = color
        ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant StarPainter old) => old.color != color || old.fill != fill;
}

/// Surah number inside an eight-pointed star.
class StarNumber extends StatelessWidget {
  final int number;
  final double size;
  final Color color;
  final bool filled;

  const StarNumber({super.key, required this.number, required this.color, this.size = 44, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: StarPainter(color: filled ? color.withValues(alpha: 0.18) : color, strokeWidth: 1.4, fill: filled),
        child: Center(
          child: Text(
            ArabicUtils.toArabicDigits(number),
            style: TextStyle(fontSize: size * 0.3, fontWeight: FontWeight.w900, color: color),
          ),
        ),
      ),
    );
  }
}

/// Faint Islamic star lattice used as texture on hero cards.
class LatticePainter extends CustomPainter {
  final Color color;
  final double cell;

  const LatticePainter({required this.color, this.cell = 46});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var y = -cell; y < size.height + cell; y += cell * 0.866) {
      final odd = ((y / (cell * 0.866)).round()).isOdd;
      for (var x = -cell; x < size.width + cell; x += cell) {
        final c = Offset(x + (odd ? cell / 2 : 0), y);
        canvas.drawPath(StarPainter.path(c, cell * 0.3), p);
        canvas.drawCircle(c, cell * 0.08, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant LatticePainter old) => old.color != color;
}

/// Stylised skyline of a holy mosque: [makkah] draws the Kaaba between
/// minarets, otherwise the Prophet's Mosque dome.
class SkylinePainter extends CustomPainter {
  final Color color;
  final bool makkah;

  const SkylinePainter({required this.color, required this.makkah});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final base = h;
    final fill = Paint()..color = color;
    final path = Path()..moveTo(0, base);

    void minaret(double x, double height, double width) {
      final top = base - height;
      final r = RRect.fromRectAndCorners(
        Rect.fromLTWH(x - width / 2, top, width, height),
        topLeft: Radius.circular(width / 2),
        topRight: Radius.circular(width / 2),
      );
      canvas.drawRRect(r, fill);
      // balconies
      for (final f in const [0.35, 0.62]) {
        canvas.drawRect(Rect.fromLTWH(x - width * 0.85, top + height * f, width * 1.7, height * 0.025), fill);
      }
      // spire + crescent
      canvas.drawLine(Offset(x, top), Offset(x, top - width * 1.6), fill..strokeWidth = width * 0.18);
      canvas.drawCircle(Offset(x, top - width * 1.9), width * 0.32, fill);
    }

    void dome(double cx, double r, double y) {
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, y), radius: r), math.pi, math.pi, true, fill);
      canvas.drawLine(Offset(cx, y - r), Offset(cx, y - r * 1.45), fill..strokeWidth = r * 0.07);
      canvas.drawCircle(Offset(cx, y - r * 1.55), r * 0.1, fill);
    }

    // low arcade wall
    path
      ..lineTo(0, base - h * 0.16)
      ..lineTo(w, base - h * 0.16)
      ..lineTo(w, base)
      ..close();
    canvas.drawPath(path, fill);
    for (var x = w * 0.04; x < w; x += w * 0.06) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(x, base - h * 0.16), radius: w * 0.022),
        math.pi,
        math.pi,
        true,
        fill,
      );
    }

    if (makkah) {
      for (final x in [0.1, 0.22, 0.78, 0.9]) {
        minaret(w * x, h * (x == 0.22 || x == 0.78 ? 0.78 : 0.62), w * 0.03);
      }
      // the Kaaba with its golden band
      final kw = w * 0.2;
      final kh = h * 0.42;
      final k = Rect.fromLTWH(w * 0.5 - kw / 2, base - h * 0.16 - kh, kw, kh);
      canvas.drawRect(k, fill);
      canvas.drawRect(
        Rect.fromLTWH(k.left, k.top + kh * 0.2, kw, kh * 0.07),
        Paint()..color = const Color(0xFFE2C275).withValues(alpha: 0.55),
      );
      // clock tower in the distance
      minaret(w * 0.66, h * 0.95, w * 0.045);
    } else {
      for (final x in [0.12, 0.3, 0.7, 0.88]) {
        minaret(w * x, h * (x == 0.3 || x == 0.7 ? 0.8 : 0.64), w * 0.028);
      }
      dome(w * 0.5, w * 0.11, base - h * 0.16);
      dome(w * 0.38, w * 0.05, base - h * 0.16);
      dome(w * 0.62, w * 0.05, base - h * 0.16);
    }
  }

  @override
  bool shouldRepaint(covariant SkylinePainter old) => old.color != color || old.makkah != makkah;
}

/// Section heading with an optional trailing action.
class MediaSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  const MediaSectionHeader(this.title, {super.key, this.subtitle, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 4,
            height: subtitle == null ? 22 : 36,
            margin: const EdgeInsetsDirectional.only(end: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [glass.accent, glass.accent.withValues(alpha: 0.2)],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: glass.onGlass)),
                if (subtitle != null)
                  Text(subtitle!, style: TextStyle(fontSize: 12.5, color: glass.onGlassMuted)),
              ],
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: glass.accent),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(action!, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const Icon(Icons.chevron_left_rounded, size: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
