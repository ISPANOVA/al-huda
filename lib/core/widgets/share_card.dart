import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/prayer/presentation/prayer_share.dart';
import '../constants/app_constants.dart';
import '../theme/app_themes.dart';
import 'glass_container.dart';
import 'state_views.dart';
import '../i18n/text.dart';

/// A thikr, dua, name of Allah or hadith as a picture: black and gold as in
/// the app, as tall as the text needs (1350 at least, the shape chats show whole).
class ShareCard {
  final String title; // «أذكار الصباح»، «دعاء»، «الأربعون النووية • الحديث ٣»
  final String body;
  final String? big; // a name of Allah, drawn large above the meaning
  final String? source; // «رواه مسلم»
  final bool quran; // the body is Quran: the Mushaf font

  const ShareCard({required this.title, required this.body, this.big, this.source, this.quran = false});
}

class ShareCardPainter {
  final ShareCard card;
  final ui.Image? logo;

  ShareCardPainter(this.card, {this.logo});

  static const w = 1080.0;
  static const _side = 110.0;
  static const _bodyTop = 330.0;
  static const gold = PrayerCardPainter.gold;

  double get _bigH => card.big == null ? 0 : 260;
  late final TextPainter _body = _layoutBody();
  late final TextPainter? _source = card.source == null || card.source!.trim().isEmpty
      ? null
      : _tp(card.source!, TextStyle(fontFamily: AppFonts.ui, fontSize: 30, color: gold, fontWeight: FontWeight.w700), w - 300);

  TextPainter _tp(String s, TextStyle style, double maxWidth, {TextAlign align = TextAlign.center, int? maxLines}) => TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.rtl,
        textAlign: align,
        maxLines: maxLines,
        ellipsis: maxLines == null ? null : '…',
      )..layout(maxWidth: maxWidth);

  TextStyle _bodyStyle(double size) => card.quran
      ? TextStyle(fontFamily: 'UthmanicHafs', fontSize: size + 4, height: 1.9, color: Colors.white)
      : TextStyle(fontFamily: AppFonts.ui, fontSize: size, height: 1.75, color: Colors.white, fontWeight: FontWeight.w700);

  /// The body as large as reads well: smaller for a long text, which then
  /// makes the picture taller rather than unreadable.
  TextPainter _layoutBody() {
    const maxW = w - 2 * _side;
    var size = card.big == null ? 58.0 : 46.0;
    while (true) {
      final tp = _tp(card.body, _bodyStyle(size), maxW);
      if (tp.height <= 760 - _bigH || size <= 34) return tp;
      tp.dispose();
      size -= 2;
    }
  }

  double get h {
    final content = _bodyTop + _bigH + _body.height + (_source == null ? 0 : _source!.height + 90) + 190;
    return content < 1350 ? 1350 : content;
  }

  void paint(Canvas canvas, Size size) {
    final height = h;
    canvas.save();
    canvas.scale(size.width / w, size.height / height);
    final r = Offset.zero & Size(w, height);
    canvas.drawRect(
        r,
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(0, height),
              const [Color(0xFF050505), Color(0xFF15100A), Color(0xFF2A1F0C)], const [0, 0.55, 1]));
    canvas.drawRect(
        r,
        Paint()
          ..shader = ui.Gradient.radial(const Offset(w / 2, 160), 640, [gold.withValues(alpha: 0.18), gold.withValues(alpha: 0)]));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(34, 34, w - 68, height - 68), const Radius.circular(44)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = gold.withValues(alpha: 0.45));
    final l = logo;
    if (l != null) {
      final src = Offset.zero & Size(l.width.toDouble(), l.height.toDouble());
      canvas.drawImageRect(l, src, Rect.fromCenter(center: Offset(w / 2, height / 2 + 40), width: 820, height: 820),
          Paint()..color = Colors.white.withValues(alpha: 0.045));
      canvas.drawImageRect(l, src, Rect.fromCenter(center: const Offset(w / 2, 128), width: 100, height: 100),
          Paint()..filterQuality = FilterQuality.high);
    }
    final title = _tp(card.title,
        const TextStyle(fontFamily: AppFonts.display, fontSize: 62, color: gold, fontWeight: FontWeight.w700), w - 160,
        maxLines: 1);
    title.paint(canvas, Offset(w / 2 - title.width / 2, 236 - title.height / 2));
    title.dispose();
    final line = Paint()
      ..color = gold.withValues(alpha: 0.55)
      ..strokeWidth = 2.5;
    canvas.drawLine(const Offset(w / 2 - 200, 292), const Offset(w / 2 - 26, 292), line);
    canvas.drawLine(const Offset(w / 2 + 26, 292), const Offset(w / 2 + 200, 292), line);
    canvas.drawCircle(const Offset(w / 2, 292), 7, Paint()..color = gold);

    // The text block sits in the middle of the room left between the title and the footer.
    final blockH = _bigH + _body.height + (_source == null ? 0 : _source!.height + 90);
    var y = _bodyTop + ((height - _bodyTop - 190) - blockH) / 2;
    if (card.big != null) {
      final big = _tp(card.big!, const TextStyle(fontFamily: 'UthmanicHafs', fontSize: 150, color: gold, height: 1.3), w - 160,
          maxLines: 1);
      big.paint(canvas, Offset(w / 2 - big.width / 2, y + (_bigH - big.height) / 2));
      big.dispose();
      y += _bigH;
    }
    _body.paint(canvas, Offset(w / 2 - _body.width / 2, y));
    y += _body.height;
    final src = _source;
    if (src != null) {
      y += 50;
      final box = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(w / 2, y + src.height / 2), width: src.width + 64, height: src.height + 24),
          const Radius.circular(40));
      canvas.drawRRect(box, Paint()..color = gold.withValues(alpha: 0.12));
      canvas.drawRRect(
          box,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = gold.withValues(alpha: 0.4));
      src.paint(canvas, Offset(w / 2 - src.width / 2, y));
    }
    final foot = _tp('تطبيق الهدى • ${AppConstants.shareUrl.replaceFirst('https://', '')}',
        TextStyle(fontFamily: AppFonts.ui, fontSize: 34, color: gold.withValues(alpha: 0.9), fontWeight: FontWeight.w800), w);
    foot.paint(canvas, Offset(w / 2 - foot.width / 2, height - 92 - foot.height / 2));
    foot.dispose();
    canvas.restore();
  }

  Future<Uint8List> png() async {
    final height = h;
    final rec = ui.PictureRecorder();
    paint(Canvas(rec), Size(w, height));
    final img = await rec.endRecording().toImage(w.toInt(), height.round());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    _body.dispose();
    _source?.dispose();
    return bytes!.buffer.asUint8List();
  }
}

/// «مشاركة»: as a picture (the card) or as text, and copy.
Future<void> showShareChoice(BuildContext context, {required ShareCard card, required String text}) async {
  final choice = await showGlassSheet<String>(context, builder: (ctx) {
    final glass = GlassTheme.of(ctx);
    Widget tile(String id, IconData icon, String title, String subtitle) => ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: CircleAvatar(
            backgroundColor: glass.accent.withValues(alpha: 0.16),
            child: Icon(icon, color: glass.accent),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle),
          onTap: () => Navigator.of(ctx).pop(id),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('مشاركة',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: AppFonts.display, fontSize: 21, fontWeight: FontWeight.w700, color: glass.onGlass)),
        const SizedBox(height: 8),
        tile('image', Icons.image_rounded, 'مشاركة كصورة', 'بطاقة بتصميم الهدى للحالة أو المحادثة'),
        tile('text', Icons.notes_rounded, 'مشاركة كنص', 'النص كما هو'),
        tile('copy', Icons.copy_rounded, 'نسخ', 'إلى الحافظة'),
        const SizedBox(height: 8),
      ],
    );
  });
  if (choice == null || !context.mounted) return;
  final withLink = '$text\n\n— تطبيق الهدى ${AppConstants.shareUrl}';
  switch (choice) {
    case 'text':
      await SharePlus.instance.share(ShareParams(text: withLink));
    case 'copy':
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) showGlassSnack(context, 'تم النسخ');
    case 'image':
      final logo = await loadShareLogo();
      final png = await ShareCardPainter(card, logo: logo).png();
      logo?.dispose();
      final ok = await shareImage(png, 'alhuda_${DateTime.now().millisecondsSinceEpoch}.png', withLink);
      if (!ok && context.mounted) showGlassSnack(context, 'تعذر تجهيز الصورة');
  }
}
