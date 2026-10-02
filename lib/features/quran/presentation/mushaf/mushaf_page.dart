import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/data/surah_metadata.dart';
import '../../../../core/theme/app_themes.dart';
import '../../domain/entities/mushaf_line.dart';

/// KFGQPC Uthmanic Hafs (the King Fahd Complex Mushaf font).
const String kMushafFont = 'UthmanicHafs';

const List<String> kJuzNames = [
  'الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس', 'السادس', 'السابع', 'الثامن', 'التاسع', 'العاشر', //
  'الحادي عشر', 'الثاني عشر', 'الثالث عشر', 'الرابع عشر', 'الخامس عشر', 'السادس عشر', 'السابع عشر', //
  'الثامن عشر', 'التاسع عشر', 'العشرون', 'الحادي والعشرون', 'الثاني والعشرون', 'الثالث والعشرون', //
  'الرابع والعشرون', 'الخامس والعشرون', 'السادس والعشرون', 'السابع والعشرون', 'الثامن والعشرون', //
  'التاسع والعشرون', 'الثلاثون',
];

String juzName(int juz) => juz >= 1 && juz <= 30 ? 'الجزء ${kJuzNames[juz - 1]}' : '';

const String kBasmala = 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ';

/// Mushaf colours derived from the app's current theme.
@immutable
class MushafStyle {
  final Color ink;
  final Color muted;
  final Color accent;
  final Color primary;
  final Color highlight;
  final Color selection;

  const MushafStyle({
    required this.ink,
    required this.muted,
    required this.accent,
    required this.primary,
    required this.highlight,
    required this.selection,
  });

  factory MushafStyle.of(BuildContext context) {
    final glass = GlassTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    return MushafStyle(
      ink: glass.onGlass,
      muted: glass.onGlassMuted,
      accent: glass.accent,
      primary: scheme.primary,
      highlight: glass.accent.withValues(alpha: 0.24),
      selection: scheme.primary.withValues(alpha: 0.30),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MushafStyle && other.ink == ink && other.accent == accent && other.primary == primary;

  @override
  int get hashCode => Object.hash(ink, accent, primary);
}

final RegExp _ayahNumber = RegExp(' ([٠-٩]+)\$');

/// A laid-out word (paragraph + position) on a page.
class _Word {
  final ui.Paragraph paragraph;
  final Offset offset;
  final double width;
  final double height;
  final int ayah;
  final int line;

  _Word(this.paragraph, this.offset, this.width, this.height, this.ayah, this.line);
}

/// Per-line horizontal condensing (scale around the right edge).
class _Line {
  final double scale;
  _Line(this.scale);
}

/// Everything needed to paint one page; built once and cached, so swiping
/// between pages costs only a repaint (no text shaping on the UI thread).
class _PageLayout {
  final List<_Word> words;
  final List<_Line> lines;
  final List<({int surah, double top, double height})> headers;
  final double fontSize;
  final double width;

  _PageLayout(this.words, this.lines, this.headers, this.fontSize, this.width);
}

class _LayoutCache {
  static final LinkedHashMap<String, _PageLayout> _map = LinkedHashMap();

  static _PageLayout? get(String key) {
    final v = _map.remove(key);
    if (v != null) _map[key] = v;
    return v;
  }

  static void put(String key, _PageLayout v) {
    _map[key] = v;
    while (_map.length > 14) {
      _map.remove(_map.keys.first);
    }
  }
}

/// Geometry of the last built page, used to pre-build neighbour pages.
class _Geometry {
  final double width;
  final double height;
  final double screenHeight;
  final double referenceWidth;
  final MushafStyle style;

  const _Geometry(this.width, this.height, this.screenHeight, this.referenceWidth, this.style);
}

/// One printed page laid out exactly like the Madinah Mushaf: fixed line
/// slots (15 per page), every line justified edge to edge, the same font size
/// on every page. Text is painted from cached paragraphs for smooth swiping.
class MushafPageView extends StatelessWidget {
  final int page;
  final List<MushafLine> lines;
  final double referenceWidth;
  final MushafStyle style;
  final int? highlightedAyah;
  final int? selectedAyah;

  /// Long-press on an ayah.
  final ValueChanged<int> onAyahTap;

  const MushafPageView({
    super.key,
    required this.page,
    required this.lines,
    required this.referenceWidth,
    required this.style,
    required this.onAyahTap,
    this.highlightedAyah,
    this.selectedAyah,
  });

  static _Geometry? _lastGeometry;

  /// Builds (and caches) the layout of [page] in idle time so the next swipe
  /// is instant. No-op until a page has been shown once.
  static void prewarm(int page, List<MushafLine> lines) {
    final g = _lastGeometry;
    if (g == null || lines.isEmpty) return;
    SchedulerBinding.instance.scheduleTask(
      () => _layout(page, lines, g.width, g.height, g.screenHeight, g.referenceWidth, g.style),
      Priority.idle,
    );
  }

  static String _key(int page, double w, double h, MushafStyle s) =>
      '$page|${w.toStringAsFixed(1)}|${h.toStringAsFixed(1)}|${s.ink.toARGB32()}|${s.accent.toARGB32()}';

  static ui.Paragraph _paragraph(String text, double fs, MushafStyle s, {bool allAccent = false}) {
    final b = ui.ParagraphBuilder(ui.ParagraphStyle(
      textDirection: TextDirection.rtl,
      fontFamily: kMushafFont,
      fontSize: fs,
      fontWeight: FontWeight.w700,
      maxLines: 1,
    ));
    final m = allAccent ? null : _ayahNumber.firstMatch(text);
    b.pushStyle(ui.TextStyle(color: allAccent ? s.accent : s.ink, fontFamily: kMushafFont, fontSize: fs, fontWeight: FontWeight.w700));
    if (m == null) {
      b.addText(text);
    } else {
      b.addText(text.substring(0, m.start));
      b.pushStyle(ui.TextStyle(color: s.accent));
      b.addText(text.substring(m.start));
      b.pop();
    }
    final p = b.build()..layout(const ui.ParagraphConstraints(width: double.infinity));
    final w = p.maxIntrinsicWidth;
    p.layout(ui.ParagraphConstraints(width: w.ceilToDouble() + 1));
    return p;
  }

  static _PageLayout _layout(
    int page,
    List<MushafLine> lines,
    double width,
    double height,
    double screenH,
    double referenceWidth,
    MushafStyle s,
  ) {
    final key = _key(page, width, height, s);
    final cached = _LayoutCache.get(key);
    if (cached != null) return cached;

    final opening = page <= 2;
    final slots = lines.length >= 13 ? lines.length : 15;
    final slotH = height / slots;
    // Same size on every page: a typical line fills the width; longer lines
    // are condensed horizontally. Height cap from the screen so the font never
    // changes when the app's bars show or hide.
    var fs = math.min(width / referenceWidth * 100, screenH * 0.68 / 15 / 1.62);
    var lineH = slotH;
    var top0 = 0.0;
    if (opening) {
      final widest = lines.fold<double>(0, (m, l) => math.max(m, l.width100));
      lineH = math.min(slotH * 1.45, height / (lines.length + 1));
      fs = math.min(lineH / 1.8, width * 0.86 / math.max(widest, 1) * 100);
      top0 = (height - lineH * lines.length) / 2;
    }

    final words = <_Word>[];
    final lineInfo = <_Line>[];
    final headers = <({int surah, double top, double height})>[];
    for (var li = 0; li < lines.length; li++) {
      final line = lines[li];
      final top = top0 + li * lineH;
      switch (line.type) {
        case MushafLineType.header:
          headers.add((surah: line.surah, top: top, height: lineH));
          lineInfo.add(_Line(1));
        case MushafLineType.basmala:
          final p = _paragraph(kBasmala, fs, s);
          final w = p.width;
          words.add(_Word(p, Offset((width - w) / 2, top + (lineH - p.height) / 2), w, p.height, 0, li));
          lineInfo.add(_Line(1));
        case MushafLineType.text:
        case MushafLineType.centered:
          final ps = [for (final w in line.words) _paragraph(w.text, fs, s)];
          final ws = [for (final p in ps) p.width];
          final total = ws.fold<double>(0, (a, b) => a + b);
          final n = ps.length;
          final minGap = fs * 0.12;
          double gap;
          var right = width;
          var scale = 1.0;
          if (line.type == MushafLineType.centered || opening) {
            gap = fs * 0.3;
            final block = total + gap * (n - 1);
            if (block > width) {
              scale = width / block;
            } else {
              right = (width + block) / 2;
            }
          } else if (total + minGap * (n - 1) <= width) {
            gap = n > 1 ? (width - total) / (n - 1) : 0;
          } else {
            gap = minGap;
            scale = width / (total + minGap * (n - 1));
          }
          for (var i = 0; i < n; i++) {
            final p = ps[i];
            final left = right - ws[i];
            words.add(_Word(p, Offset(left, top + (lineH - p.height) / 2), ws[i], p.height, line.words[i].ayah, li));
            right = left - gap;
          }
          lineInfo.add(_Line(scale));
      }
    }
    final layout = _PageLayout(words, lineInfo, headers, fs, width);
    _LayoutCache.put(key, layout);
    return layout;
  }

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final screenH = MediaQuery.sizeOf(context).height;
    return LayoutBuilder(builder: (context, c) {
      _lastGeometry = _Geometry(c.maxWidth, c.maxHeight, screenH, referenceWidth, style);
      final layout = _layout(page, lines, c.maxWidth, c.maxHeight, screenH, referenceWidth, style);
      return GestureDetector(
        // Tap anywhere toggles the reader UI (handled by the parent); a
        // long-press on a word opens that ayah's menu.
        onLongPressStart: (d) {
          final ayah = _hit(layout, d.localPosition);
          if (ayah != null) onAyahTap(ayah);
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _PagePainter(
                  layout,
                  highlighted: highlightedAyah,
                  selected: selectedAyah,
                  highlightColor: style.highlight,
                  selectionColor: style.selection,
                ),
              ),
            ),
            for (final h in layout.headers)
              Positioned(
                top: h.top,
                left: 0,
                right: 0,
                height: h.height,
                child: SurahBanner(surah: h.surah, height: h.height, fontSize: layout.fontSize, style: style),
              ),
          ],
        ),
      );
    });
  }

  static int? _hit(_PageLayout layout, Offset pos) {
    for (final w in layout.words) {
      if (w.ayah == 0) continue;
      final scale = layout.lines[w.line].scale;
      final left = layout.width - (layout.width - w.offset.dx) * scale;
      final rect = Rect.fromLTWH(left, w.offset.dy, w.width * scale, w.height);
      if (rect.inflate(4).contains(pos)) return w.ayah;
    }
    return null;
  }
}

class _PagePainter extends CustomPainter {
  final _PageLayout layout;
  final int? highlighted;
  final int? selected;
  final Color highlightColor;
  final Color selectionColor;

  _PagePainter(
    this.layout, {
    required this.highlighted,
    required this.selected,
    required this.highlightColor,
    required this.selectionColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = layout.width;
    var currentLine = -1;
    var scaled = false;
    for (final word in layout.words) {
      if (word.line != currentLine) {
        if (scaled) canvas.restore();
        currentLine = word.line;
        final scale = layout.lines[currentLine].scale;
        scaled = scale != 1;
        if (scaled) {
          canvas.save();
          canvas.translate(w, 0);
          canvas.scale(scale, 1);
          canvas.translate(-w, 0);
        }
      }
      final bg = word.ayah == 0
          ? null
          : word.ayah == selected
              ? selectionColor
              : (word.ayah == highlighted ? highlightColor : null);
      if (bg != null) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(word.offset.dx - 3, word.offset.dy, word.width + 6, word.height),
            Radius.circular(layout.fontSize * 0.3),
          ),
          Paint()..color = bg,
        );
      }
      canvas.drawParagraph(word.paragraph, word.offset);
    }
    if (scaled) canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PagePainter old) =>
      !identical(old.layout, layout) ||
      old.highlighted != highlighted ||
      old.selected != selected ||
      old.highlightColor != highlightColor ||
      old.selectionColor != selectionColor;
}

/// Surah title frame: an ornamented band in theme colours with the name
/// exactly centred and always kept inside the frame.
class SurahBanner extends StatelessWidget {
  final int surah;
  final double height;
  final double fontSize;
  final MushafStyle style;

  const SurahBanner({
    super.key,
    required this.surah,
    required this.height,
    required this.fontSize,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final info = SurahMetadata.surah(surah);
    final bannerH = math.min(height * 0.9, fontSize * 2.3);
    return Center(
      child: SizedBox(
        height: bannerH,
        width: double.infinity,
        child: CustomPaint(
          painter: _BannerPainter(primary: style.primary, accent: style.accent),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: bannerH * 1.6, vertical: bannerH * 0.16),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'سُورَةُ ${info.name}',
                  textScaler: TextScaler.noScaling,
                  maxLines: 1,
                  style: TextStyle(fontFamily: kMushafFont, fontSize: fontSize * 0.92, color: style.ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerPainter extends CustomPainter {
  final Color primary;
  final Color accent;

  _BannerPainter({required this.primary, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    final rect = Offset.zero & size;
    final outer = RRect.fromRectAndRadius(rect.deflate(1), Radius.circular(h * 0.22));

    canvas.drawRRect(
      outer,
      Paint()
        ..shader = LinearGradient(
          colors: [primary.withValues(alpha: 0.28), primary.withValues(alpha: 0.10), primary.withValues(alpha: 0.28)],
        ).createShader(rect),
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = accent.withValues(alpha: 0.95)
      ..strokeWidth = 1.3;
    canvas.drawRRect(outer, stroke);

    // Inner cartouche holding the name.
    final inner = RRect.fromLTRBR(h * 1.35, h * 0.14, w - h * 1.35, h * 0.86, Radius.circular(h * 0.36));
    canvas.drawRRect(inner, Paint()..color = primary.withValues(alpha: 0.18));
    canvas.drawRRect(inner, stroke..strokeWidth = 1.0..color = accent.withValues(alpha: 0.8));

    // Rosettes at both ends plus small diamonds linking to the cartouche.
    for (final cx in [h * 0.68, w - h * 0.68]) {
      final c = Offset(cx, h / 2);
      final r = h * 0.3;
      final star = Path();
      for (var i = 0; i < 16; i++) {
        final ang = -math.pi / 2 + i * math.pi / 8;
        final rr = i.isEven ? r : r * 0.6;
        final p = Offset(c.dx + rr * math.cos(ang), c.dy + rr * math.sin(ang));
        i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
      }
      star.close();
      canvas.drawPath(star, Paint()..color = accent);
      canvas.drawCircle(c, r * 0.32, Paint()..color = primary);
      canvas.drawCircle(c, r * 1.25, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = accent.withValues(alpha: 0.55));
    }
    final d = h * 0.09;
    for (final cx in [h * 1.18, w - h * 1.18]) {
      final p = Path()
        ..moveTo(cx, h / 2 - d)
        ..lineTo(cx + d, h / 2)
        ..lineTo(cx, h / 2 + d)
        ..lineTo(cx - d, h / 2)
        ..close();
      canvas.drawPath(p, Paint()..color = accent);
    }
  }

  @override
  bool shouldRepaint(covariant _BannerPainter old) => old.primary != primary || old.accent != accent;
}
