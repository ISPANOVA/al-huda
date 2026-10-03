import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/data/surah_metadata.dart';
import '../../../../core/theme/app_themes.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/ayah.dart';

class _CardStyle {
  final String name;
  final List<Color> colors;
  final Color ink;
  final Color accent;

  const _CardStyle(this.name, this.colors, this.ink, this.accent);
}

const _styles = [
  _CardStyle('ليلي', [Color(0xFF0B1424), Color(0xFF13233D)], Colors.white, Color(0xFFD9B26B)),
  _CardStyle('زمردي', [Color(0xFF06261C), Color(0xFF0F4535)], Colors.white, Color(0xFFE2C27D)),
  _CardStyle('عاجي', [Color(0xFFFBF6EA), Color(0xFFEADCBF)], Color(0xFF2B1E12), Color(0xFF9A6B2E)),
  _CardStyle('أسود', [Color(0xFF050505), Color(0xFF1A1A1A)], Colors.white, Color(0xFFCFAE6E)),
  _CardStyle('فيروزي', [Color(0xFF052326), Color(0xFF0D4247)], Colors.white, Color(0xFFDCC59B)),
];

/// Share an ayah as a beautiful image (Mushaf font, ornamented frame).
class AyahImagePage extends StatefulWidget {
  final Ayah ayah;

  const AyahImagePage({super.key, required this.ayah});

  static Route<void> route(Ayah ayah) => MaterialPageRoute(builder: (_) => AyahImagePage(ayah: ayah));

  @override
  State<AyahImagePage> createState() => _AyahImagePageState();
}

class _AyahImagePageState extends State<AyahImagePage> {
  final _boundary = GlobalKey();
  int _style = 0;
  bool _withTafseer = false;
  bool _busy = false;

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ro = _boundary.currentContext?.findRenderObject();
      if (ro is! RenderRepaintBoundary) return;
      final image = await ro.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) return;
      if (kIsWeb) {
        final name = 'alhuda_${widget.ayah.surah}_${widget.ayah.numberInSurah}.png';
        await SharePlus.instance.share(ShareParams(
          files: [XFile.fromData(data.buffer.asUint8List(), name: name, mimeType: 'image/png')],
          fileNameOverrides: [name],
          text: '${_reference()} — تطبيق الهدى',
        ));
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/alhuda_${widget.ayah.surah}_${widget.ayah.numberInSurah}.png');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: '${_reference()} — تطبيق الهدى',
      ));
    } catch (_) {
      if (mounted) showGlassSnack(context, 'تعذر إنشاء الصورة');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _reference() =>
      'سورة ${SurahMetadata.surah(widget.ayah.surah).name} • الآية ${ArabicUtils.toArabicDigits(widget.ayah.numberInSurah)}';

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final style = _styles[_style];
    return GlassScaffold(
      title: 'مشاركة كصورة',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          RepaintBoundary(
            key: _boundary,
            child: _AyahCard(
              ayah: widget.ayah,
              style: style,
              reference: _reference(),
              tafseer: _withTafseer ? widget.ayah.tafseer : null,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _styles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final s = _styles[i];
                final selected = i == _style;
                return GestureDetector(
                  onTap: () => setState(() => _style = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: s.colors),
                      border: Border.all(color: selected ? glass.accent : glass.onGlass.withValues(alpha: 0.2), width: selected ? 3 : 1),
                    ),
                    child: Center(
                      child: Text(s.name, style: TextStyle(color: s.ink, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('إضافة التفسير الميسر'),
            value: _withTafseer,
            onChanged: widget.ayah.tafseer.isEmpty ? null : (v) => setState(() => _withTafseer = v),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            icon: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.ios_share_rounded),
            label: const Text('مشاركة الصورة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            onPressed: _share,
          ),
        ],
      ),
    );
  }
}

class _AyahCard extends StatelessWidget {
  final Ayah ayah;
  final _CardStyle style;
  final String reference;
  final String? tafseer;

  const _AyahCard({required this.ayah, required this.style, required this.reference, this.tafseer});

  @override
  Widget build(BuildContext context) {
    final len = ayah.text.length;
    final fs = (34 - len / 14).clamp(17.0, 32.0);
    return AspectRatio(
      aspectRatio: tafseer == null ? 4 / 5 : 4 / 6,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: style.colors),
        ),
        child: CustomPaint(
          painter: _FramePainter(style.accent),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 34, 30, 22),
            child: Column(
              children: [
                Text('﷽', style: TextStyle(fontSize: 26, color: style.accent)),
                const SizedBox(height: 6),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: '﴿${ayah.text}'),
                            TextSpan(
                              text: ArabicUtils.ornateAyahMarker(ayah.numberInSurah),
                              style: TextStyle(color: style.accent),
                            ),
                            const TextSpan(text: '﴾'),
                          ]),
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: 'UthmanicHafs',
                            fontWeight: FontWeight.w700,
                            fontSize: fs,
                            height: 1.9,
                            color: style.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (tafseer != null) ...[
                  Container(height: 1, margin: const EdgeInsets.symmetric(vertical: 10), color: style.accent.withValues(alpha: 0.4)),
                  Text(
                    tafseer!,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, height: 1.7, color: style.ink.withValues(alpha: 0.85)),
                  ),
                ],
                const SizedBox(height: 12),
                Text(reference, style: TextStyle(color: style.accent, fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 6),
                Text('تطبيق الهدى',
                    style: TextStyle(color: style.ink.withValues(alpha: 0.55), fontSize: 11, letterSpacing: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Double frame with eight-pointed stars in the corners.
class _FramePainter extends CustomPainter {
  final Color accent;

  _FramePainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndRadius((Offset.zero & size).deflate(12), const Radius.circular(20));
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = accent.withValues(alpha: 0.85);
    canvas.drawRRect(outer, p);
    canvas.drawRRect(outer.deflate(5), p..strokeWidth = 0.7..color = accent.withValues(alpha: 0.45));
    for (final c in [
      Offset(12, 12),
      Offset(size.width - 12, 12),
      Offset(12, size.height - 12),
      Offset(size.width - 12, size.height - 12),
    ]) {
      final path = Path();
      for (var i = 0; i < 16; i++) {
        final a = -math.pi / 2 + i * math.pi / 8;
        final r = i.isEven ? 9.0 : 5.0;
        final pt = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = accent);
    }
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) => old.accent != accent;
}
