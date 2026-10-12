import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_themes.dart';
import '../../core/utils/arabic_utils.dart';

/// One look for the video: what is painted behind the ayah and its colours.
class VideoBackground {
  final String id;
  final String name;
  final Color ink;
  final Color accent;
  final List<Color> colors;

  const VideoBackground(this.id, this.name, this.colors, {this.ink = Colors.white, this.accent = const Color(0xFFE2C074)});

  static const custom = 'photo';

  static const all = [
    VideoBackground('night', 'ليل', [Color(0xFF03050F), Color(0xFF0A1230), Color(0xFF1D2347)], accent: Color(0xFFF1D7A0)),
    VideoBackground('gold', 'ذهبي', [Color(0xFF050505), Color(0xFF15100A), Color(0xFF2A1F0C)]),
    VideoBackground('emerald', 'زمردي', [Color(0xFF02140F), Color(0xFF07301F), Color(0xFF0E4A33)]),
    VideoBackground('dawn', 'فجر', [Color(0xFF141634), Color(0xFF55376A), Color(0xFFE08B6E)], accent: Color(0xFFFFE3B0)),
    VideoBackground('amethyst', 'بنفسجي', [Color(0xFF0B0716), Color(0xFF1F1238), Color(0xFF3A1E63)], accent: Color(0xFFE6C9FF)),
    VideoBackground('sea', 'فيروزي', [Color(0xFF021619), Color(0xFF06363A), Color(0xFF0D5257)], accent: Color(0xFFDCC59B)),
    VideoBackground('ivory', 'عاجي', [Color(0xFFFBF6EA), Color(0xFFF2E8D2), Color(0xFFE6D5B3)],
        ink: Color(0xFF2B1E12), accent: Color(0xFF8A5A1E)),
    VideoBackground(custom, 'صورة من جهازك', [Color(0xFF000000), Color(0xFF0A0A0A), Color(0xFF151515)]),
  ];

  static VideoBackground byId(String id) => all.firstWhere((b) => b.id == id, orElse: () => all.first);
}

/// What one frame shows.
class FrameContent {
  final String text; // ayah words (one chunk of them for a long ayah)
  final int? ayahNumber; // the ayah end marker on the last chunk; null for the basmala
  final String surahName;
  final String reciterName;
  final String? caption; // «الآية ٣» or «البسملة»

  const FrameContent({
    required this.text,
    required this.ayahNumber,
    required this.surahName,
    required this.reciterName,
    this.caption,
  });
}

/// Draws the video frames. Coordinates are those of a 1080x1920 story, scaled
/// to any size, so the preview and the video are the same picture.
class VideoFramePainter {
  final VideoBackground bg;
  final ui.Image? photo; // the user's own background
  final ui.Image? logo; // assets/icon/logo_mark.png
  final ui.Image? reciterPhoto;

  VideoFramePainter({required this.bg, this.photo, this.logo, this.reciterPhoto});

  static const w = 1080.0;
  static const h = 1920.0;
  static const textBox = Rect.fromLTRB(96, 560, 984, 1360);
  static const minFont = 46.0;
  static const maxFont = 84.0;

  static String get link => AppConstants.shareUrl.replaceFirst('https://', '');

  /// The ayah as painted text: words, then the ornate number.
  static TextSpan ayahSpan(String text, int? number, double size, Color ink, Color accent) => TextSpan(
        style: TextStyle(fontFamily: 'UthmanicHafs', fontWeight: FontWeight.w700, fontSize: size, height: 1.85, color: ink),
        children: [
          TextSpan(text: text),
          if (number != null) TextSpan(text: ' ${ArabicUtils.ornateAyahMarker(number)}', style: TextStyle(color: accent)),
        ],
      );

  static TextPainter _layout(InlineSpan span, double maxWidth) =>
      TextPainter(text: span, textDirection: TextDirection.rtl, textAlign: TextAlign.center)..layout(maxWidth: maxWidth);

  static bool fits(String text, int? number, double size) {
    final tp = _layout(ayahSpan(text, number, size, Colors.white, Colors.white), textBox.width);
    final ok = tp.height <= textBox.height;
    tp.dispose();
    return ok;
  }

  /// A long ayah split into pages that each fit at a readable size.
  static List<String> split(String text, int? number) {
    if (fits(text, number, minFont)) return [text];
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final pages = <String>[];
    var cur = <String>[];
    for (final word in words) {
      final next = [...cur, word].join(' ');
      if (cur.isNotEmpty && !fits(next, number, minFont + 6)) {
        pages.add(cur.join(' '));
        cur = [word];
      } else {
        cur.add(word);
      }
    }
    if (cur.isNotEmpty) pages.add(cur.join(' '));
    return pages;
  }

  void paintFrame(Canvas canvas, Size size, FrameContent c) {
    canvas.save();
    canvas.scale(size.width / w, size.height / h);
    _background(canvas);
    _header(canvas, c.surahName);

    // The ayah, as large as fits.
    var fs = maxFont;
    while (fs > 30 && !fits(c.text, c.ayahNumber, fs)) {
      fs -= 2;
    }
    final tp = _layout(ayahSpan(c.text, c.ayahNumber, fs, bg.ink, bg.accent), textBox.width);
    final shadow = _layout(
        ayahSpan(c.text, c.ayahNumber, fs, Colors.black.withValues(alpha: bg.id == 'ivory' ? 0 : 0.45), Colors.transparent),
        textBox.width);
    final top = textBox.center.dy - tp.height / 2;
    shadow.paint(canvas, Offset(textBox.left, top + 3));
    tp.paint(canvas, Offset(textBox.left, top));
    tp.dispose();
    shadow.dispose();

    if (c.caption != null) {
      _text(canvas, c.caption!, Offset(w / 2, textBox.bottom + 54),
          TextStyle(fontFamily: AppFonts.display, fontSize: 34, color: bg.accent.withValues(alpha: 0.9)));
    }
    _reciter(canvas, c.reciterName);
    _footer(canvas);
    canvas.restore();
  }

  /// The last seconds: the app and its link.
  void paintOutro(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / w, size.height / h);
    _background(canvas);
    if (logo != null) {
      const s = 300.0;
      canvas.drawImageRect(logo!, Offset.zero & Size(logo!.width.toDouble(), logo!.height.toDouble()),
          Rect.fromCenter(center: const Offset(w / 2, 700), width: s, height: s), Paint()..filterQuality = FilterQuality.high);
    }
    _text(canvas, 'تطبيق الهدى', const Offset(w / 2, 940),
        TextStyle(fontFamily: AppFonts.display, fontSize: 96, color: bg.accent, fontWeight: FontWeight.w700));
    _text(canvas, 'القرآن الكريم • التلاوات • المواقيت • الأذكار', const Offset(w / 2, 1060),
        TextStyle(fontFamily: AppFonts.ui, fontSize: 38, color: bg.ink.withValues(alpha: 0.85), fontWeight: FontWeight.w700));
    _text(canvas, 'مجاني بالكامل وبلا إعلانات', const Offset(w / 2, 1130),
        TextStyle(fontFamily: AppFonts.ui, fontSize: 34, color: bg.ink.withValues(alpha: 0.7)));
    _pill(canvas, 'حمّل التطبيق: $link', const Offset(w / 2, 1300), 40);
    _text(canvas, 'صدقة جارية', const Offset(w / 2, 1460),
        TextStyle(fontFamily: AppFonts.display, fontSize: 36, color: bg.accent.withValues(alpha: 0.8)));
    canvas.restore();
  }

  // ----------------------------------------------------------------- parts ---

  void _background(Canvas canvas) {
    const r = Offset.zero & Size(w, h);
    if (bg.id == VideoBackground.custom && photo != null) {
      final img = photo!;
      final scale = math.max(w / img.width, h / img.height);
      final src = Rect.fromCenter(
          center: Offset(img.width / 2, img.height / 2), width: w / scale, height: h / scale);
      canvas.drawImageRect(img, src, r, Paint()..filterQuality = FilterQuality.high);
      // Darkened so the white text stays clear on any photo.
      canvas.drawRect(
          r,
          Paint()
            ..shader = ui.Gradient.linear(Offset.zero, const Offset(0, h),
                [Colors.black.withValues(alpha: 0.55), Colors.black.withValues(alpha: 0.35), Colors.black.withValues(alpha: 0.65)], [0, 0.5, 1]));
      return;
    }
    canvas.drawRect(r, Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(0, h), bg.colors, [0, 0.55, 1]));
    switch (bg.id) {
      case 'night':
        _stars(canvas, 1);
        _crescent(canvas, const Offset(820, 330), 54);
        _skyline(canvas, const Color(0xFF02030A));
      case 'dawn':
        _stars(canvas, 0.35);
        _sun(canvas, const Offset(w / 2, 1640), 120);
        _skyline(canvas, const Color(0xFF1A1230));
      case 'ivory':
        _lattice(canvas, bg.accent.withValues(alpha: 0.10));
        _frame(canvas);
      default:
        _glow(canvas);
        _lattice(canvas, bg.accent.withValues(alpha: 0.07));
        if (logo != null) {
          final p = Paint()
            ..colorFilter = ColorFilter.mode(bg.accent.withValues(alpha: 0.07), BlendMode.srcIn)
            ..filterQuality = FilterQuality.high;
          canvas.drawImageRect(logo!, Offset.zero & Size(logo!.width.toDouble(), logo!.height.toDouble()),
              Rect.fromCenter(center: const Offset(w / 2, 960), width: 980, height: 980), p);
        }
        _frame(canvas);
    }
  }

  void _glow(Canvas canvas) {
    canvas.drawCircle(
        const Offset(w / 2, 900),
        900,
        Paint()
          ..shader = ui.Gradient.radial(const Offset(w / 2, 900), 900,
              [bg.accent.withValues(alpha: 0.16), bg.accent.withValues(alpha: 0)]));
  }

  void _frame(Canvas canvas) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = bg.accent.withValues(alpha: 0.55);
    final rr = RRect.fromRectAndRadius(const Rect.fromLTRB(44, 44, w - 44, h - 44), const Radius.circular(48));
    canvas.drawRRect(rr, p);
    canvas.drawRRect(rr.deflate(14), p..strokeWidth = 1.5..color = bg.accent.withValues(alpha: 0.3));
    for (final c in const [Offset(44, 44), Offset(w - 44, 44), Offset(44, h - 44), Offset(w - 44, h - 44)]) {
      canvas.drawPath(_star(c, 22, 13), Paint()..color = bg.accent.withValues(alpha: 0.8));
    }
  }

  static Path _star(Offset c, double r1, double r2) {
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final a = -math.pi / 2 + i * math.pi / 8;
      final r = i.isEven ? r1 : r2;
      final pt = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }

  void _lattice(Canvas canvas, Color color) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    const step = 180.0;
    for (var y = 0.0; y <= h + step; y += step) {
      for (var x = (y ~/ step).isEven ? 0.0 : step / 2; x <= w + step; x += step) {
        canvas.drawPath(_star(Offset(x, y), 62, 44), p);
      }
    }
  }

  void _stars(Canvas canvas, double k) {
    final rnd = math.Random(7);
    for (var i = 0; i < 160; i++) {
      final o = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * 0.72);
      canvas.drawCircle(o, 1.2 + rnd.nextDouble() * 2.6,
          Paint()..color = Colors.white.withValues(alpha: (0.25 + rnd.nextDouble() * 0.6) * k));
    }
  }

  void _crescent(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r * 3,
        Paint()..shader = ui.Gradient.radial(c, r * 3, [Colors.white.withValues(alpha: 0.18), Colors.white.withValues(alpha: 0)]));
    canvas.saveLayer(Rect.fromCircle(center: c, radius: r + 2), Paint());
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFF5EBC8));
    canvas.drawCircle(c + Offset(r * 0.45, -r * 0.3), r * 0.85, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
  }

  void _sun(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r * 4,
        Paint()..shader = ui.Gradient.radial(c, r * 4, [const Color(0xFFFFE3A3).withValues(alpha: 0.55), const Color(0x00FFE3A3)]));
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFFFF1C4));
  }

  void _skyline(Canvas canvas, Color color) {
    const horizon = 1720.0;
    final p = Paint()..color = color;
    canvas.drawRect(const Rect.fromLTRB(0, horizon, w, h), p);
    // A mosque: the prayer hall, a great dome, two small domes, two minarets.
    const x = 250.0;
    canvas.drawRect(const Rect.fromLTRB(x, horizon - 70, x + 380, horizon), p);
    canvas.drawArc(Rect.fromCircle(center: const Offset(x + 190, horizon - 70), radius: 120), math.pi, math.pi, true, p);
    canvas.drawCircle(const Offset(x + 190, horizon - 205), 12, p);
    for (final dx in [60.0, 320.0]) {
      canvas.drawArc(Rect.fromCircle(center: Offset(x + dx, horizon - 70), radius: 48), math.pi, math.pi, true, p);
    }
    for (final mx in [x - 30, x + 410]) {
      canvas.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTRB(mx - 16, horizon - 330, mx + 16, horizon),
              topLeft: const Radius.circular(16), topRight: const Radius.circular(16)),
          p);
      canvas.drawRect(Rect.fromLTRB(mx - 28, horizon - 240, mx + 28, horizon - 226), p);
      canvas.drawCircle(Offset(mx, horizon - 352), 10, p);
    }
    // A palm on the other side.
    final palm = Paint()
      ..color = color
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const px = 900.0;
    canvas.drawLine(const Offset(px, horizon), const Offset(px - 14, horizon - 190), palm);
    palm.strokeWidth = 9;
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + (i - 2.5) * 0.55;
      canvas.drawLine(const Offset(px - 14, horizon - 190),
          Offset(px - 14 + 90 * math.cos(a), horizon - 190 + 60 * math.sin(a) + 34), palm);
    }
  }

  void _header(Canvas canvas, String surahName) {
    if (logo != null) {
      canvas.drawImageRect(logo!, Offset.zero & Size(logo!.width.toDouble(), logo!.height.toDouble()),
          Rect.fromCenter(center: const Offset(w / 2, 250), width: 92, height: 92),
          Paint()
            ..colorFilter = ColorFilter.mode(bg.accent, BlendMode.srcIn)
            ..filterQuality = FilterQuality.high);
    }
    _text(canvas, surahName, const Offset(w / 2, 380),
        TextStyle(fontFamily: AppFonts.display, fontSize: 72, color: bg.accent, fontWeight: FontWeight.w700,
            shadows: [Shadow(color: Colors.black.withValues(alpha: bg.id == 'ivory' ? 0 : 0.4), blurRadius: 12)]));
    // A thin ornament under the title.
    final p = Paint()
      ..color = bg.accent.withValues(alpha: 0.6)
      ..strokeWidth = 2.5;
    canvas.drawLine(const Offset(w / 2 - 220, 456), const Offset(w / 2 - 34, 456), p);
    canvas.drawLine(const Offset(w / 2 + 34, 456), const Offset(w / 2 + 220, 456), p);
    canvas.drawPath(_star(const Offset(w / 2, 456), 16, 10), Paint()..color = bg.accent);
  }

  void _reciter(Canvas canvas, String name) {
    const cy = 1520.0;
    final label = 'بصوت القارئ $name';
    final tp = _layout(
        TextSpan(text: label, style: TextStyle(fontFamily: AppFonts.ui, fontSize: 38, fontWeight: FontWeight.w800, color: bg.ink)),
        w - 300);
    final photoSize = reciterPhoto == null ? 0.0 : 96.0;
    final gap = reciterPhoto == null ? 0.0 : 22.0;
    final total = tp.width + photoSize + gap;
    final pill = RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(w / 2, cy), width: total + 64, height: math.max(photoSize, tp.height) + 36),
        const Radius.circular(80));
    canvas.drawRRect(pill, Paint()..color = (bg.id == 'ivory' ? Colors.white : Colors.black).withValues(alpha: 0.35));
    canvas.drawRRect(
        pill,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = bg.accent.withValues(alpha: 0.5));
    // Right to left: the photo first (on the right), then the name.
    final right = w / 2 + total / 2;
    if (reciterPhoto != null) {
      final img = reciterPhoto!;
      final dst = Rect.fromLTWH(right - photoSize, cy - photoSize / 2, photoSize, photoSize);
      canvas.save();
      canvas.clipPath(Path()..addOval(dst));
      canvas.drawImageRect(img, Offset.zero & Size(img.width.toDouble(), img.height.toDouble()), dst,
          Paint()..filterQuality = FilterQuality.high);
      canvas.restore();
      canvas.drawCircle(dst.center, photoSize / 2, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = bg.accent);
    }
    tp.paint(canvas, Offset(right - photoSize - gap - tp.width, cy - tp.height / 2));
    tp.dispose();
  }

  void _footer(Canvas canvas) {
    _pill(canvas, 'تطبيق الهدى • $link', const Offset(w / 2, 1720), 32);
  }

  void _pill(Canvas canvas, String text, Offset c, double size) {
    final tp = _layout(
        TextSpan(text: text, style: TextStyle(fontFamily: AppFonts.ui, fontSize: size, fontWeight: FontWeight.w800, color: bg.id == 'ivory' ? Colors.white : const Color(0xFF1A1206))),
        w - 160);
    final rr = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: tp.width + 70, height: tp.height + 30), const Radius.circular(60));
    canvas.drawRRect(rr, Paint()..color = bg.accent);
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  static void _text(Canvas canvas, String text, Offset center, TextStyle style) {
    final tp = _layout(TextSpan(text: text, style: style), w - 140);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }
}
