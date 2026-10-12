import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_themes.dart';
import '../../../core/utils/arabic_utils.dart';
import '../domain/prayer_entities.dart';

/// What the picture of today's times shows.
class PrayerCardData {
  final String city;
  final String gregorian; // «الاثنين ١٢ أكتوبر ٢٠٢٦»
  final String hijri; // «١ جمادى الأولى ١٤٤٨ هـ»
  final List<(String, String)> times; // name, time
  final int next; // the row of the next prayer, -1 for none

  const PrayerCardData({required this.city, required this.gregorian, required this.hijri, required this.times, this.next = -1});

  static const _order = [
    PrayerName.fajr,
    PrayerName.sunrise,
    PrayerName.dhuhr,
    PrayerName.asr,
    PrayerName.maghrib,
    PrayerName.isha,
  ];

  factory PrayerCardData.of(PrayerDay day, {String? city, NextPrayer? next}) {
    HijriCalendar.setLocal('ar');
    final h = HijriCalendar.fromDate(day.date);
    final now = DateTime.now();
    final sameDay = next != null &&
        next.time.year == now.year && next.time.month == now.month && next.time.day == now.day;
    return PrayerCardData(
      city: (city == null || city.trim().isEmpty) ? 'موقعي' : city.trim(),
      gregorian: ArabicUtils.toArabicDigits(DateFormat('EEEE d MMMM y', 'ar').format(day.date)),
      hijri: '${ArabicUtils.toArabicDigits(h.hDay)} ${h.longMonthName} ${ArabicUtils.toArabicDigits(h.hYear)} هـ',
      times: [for (final p in _order) (p.nameOn(day.date), ArabicUtils.formatTime(day[p]))],
      next: sameDay ? _order.indexOf(next.name) : -1,
    );
  }

  String get shareText => 'مواقيت الصلاة في $city • $gregorian • $hijri\n'
      '${times.map((t) => '${t.$1}: ${t.$2}').join('\n')}\n'
      'من تطبيق الهدى: ${AppConstants.shareUrl}';
}

/// Today's six times on black and gold, as in the app: 1080x1350, the shape
/// chats and posts show whole.
class PrayerCardPainter {
  final PrayerCardData data;
  final ui.Image? logo;

  PrayerCardPainter(this.data, {this.logo});

  static const w = 1080.0;
  static const h = 1350.0;
  static const gold = Color(0xFFE2C074);
  static const _dark = Color(0xFF1A1206);

  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / w, size.height / h);
    final r = Offset.zero & const Size(w, h);
    canvas.drawRect(
        r,
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, const Offset(0, h),
              const [Color(0xFF050505), Color(0xFF15100A), Color(0xFF2A1F0C)], const [0, 0.55, 1]));
    canvas.drawRect(
        r,
        Paint()
          ..shader = ui.Gradient.radial(const Offset(w / 2, 170), 620,
              [gold.withValues(alpha: 0.20), gold.withValues(alpha: 0)]));
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(34, 34, w - 68, h - 68), const Radius.circular(44)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = gold.withValues(alpha: 0.45));
    final l = logo;
    if (l != null) {
      final src = Offset.zero & Size(l.width.toDouble(), l.height.toDouble());
      canvas.drawImageRect(l, src, Rect.fromCenter(center: const Offset(w / 2, 640), width: 860, height: 860),
          Paint()..color = Colors.white.withValues(alpha: 0.05));
      canvas.drawImageRect(l, src, Rect.fromCenter(center: const Offset(w / 2, 128), width: 104, height: 104),
          Paint()..filterQuality = FilterQuality.high);
    }

    _text(canvas, 'مواقيت الصلاة', const Offset(w / 2, 252),
        const TextStyle(fontFamily: AppFonts.display, fontSize: 82, color: gold, fontWeight: FontWeight.w700));
    _text(canvas, data.city, const Offset(w / 2, 342),
        const TextStyle(fontFamily: AppFonts.ui, fontSize: 50, color: Colors.white, fontWeight: FontWeight.w800),
        maxWidth: w - 200);
    _text(canvas, data.gregorian, const Offset(w / 2, 404),
        TextStyle(fontFamily: AppFonts.ui, fontSize: 34, color: Colors.white.withValues(alpha: 0.72)));
    _text(canvas, data.hijri, const Offset(w / 2, 452),
        TextStyle(fontFamily: AppFonts.display, fontSize: 34, color: gold.withValues(alpha: 0.85), fontWeight: FontWeight.w700));

    // The six rows.
    const x = 110.0, rw = w - 220, rh = 104.0, gap = 14.0, y0 = 512.0;
    for (var i = 0; i < data.times.length; i++) {
      final y = y0 + i * (rh + gap);
      final on = i == data.next;
      final sunrise = i == 1;
      final box = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, rw, rh), const Radius.circular(30));
      canvas.drawRRect(
          box,
          Paint()
            ..color = on
                ? gold
                : sunrise
                    ? Colors.white.withValues(alpha: 0.035)
                    : gold.withValues(alpha: 0.08));
      if (!on) {
        canvas.drawRRect(
            box,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = gold.withValues(alpha: 0.22));
      }
      final ink = on ? _dark : sunrise ? Colors.white.withValues(alpha: 0.7) : Colors.white;
      final cy = y + rh / 2;
      final name = _layout(data.times[i].$1,
          TextStyle(fontFamily: AppFonts.ui, fontSize: sunrise ? 42 : 46, color: ink, fontWeight: FontWeight.w800));
      name.paint(canvas, Offset(x + rw - 44 - name.width, cy - name.height / 2));
      if (on) {
        final tag = _layout('القادمة',
            TextStyle(fontFamily: AppFonts.ui, fontSize: 28, color: _dark.withValues(alpha: 0.7), fontWeight: FontWeight.w800));
        tag.paint(canvas, Offset(x + rw - 44 - name.width - 28 - tag.width, cy - tag.height / 2));
        tag.dispose();
      }
      name.dispose();
      final time = _layout(data.times[i].$2,
          TextStyle(fontFamily: AppFonts.display, fontSize: sunrise ? 46 : 52, color: on ? _dark : gold, fontWeight: FontWeight.w700));
      time.paint(canvas, Offset(x + 44, cy - time.height / 2));
      time.dispose();
    }

    _text(canvas, 'تطبيق الهدى • ${AppConstants.shareUrl.replaceFirst('https://', '')}', const Offset(w / 2, h - 92),
        TextStyle(fontFamily: AppFonts.ui, fontSize: 34, color: gold.withValues(alpha: 0.9), fontWeight: FontWeight.w800));
    canvas.restore();
  }

  static TextPainter _layout(String s, TextStyle style, {double maxWidth = w}) => TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: maxWidth);

  static void _text(Canvas canvas, String s, Offset center, TextStyle style, {double maxWidth = w}) {
    final tp = _layout(s, style, maxWidth: maxWidth);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  Future<Uint8List> png() async {
    final rec = ui.PictureRecorder();
    paint(Canvas(rec), const Size(w, h));
    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return bytes!.buffer.asUint8List();
  }
}

/// Shares today's times as a picture (with the times as text too).
Future<bool> sharePrayerTimes(PrayerCardData data) async {
  try {
    ui.Image? logo;
    try {
      final bytes = await rootBundle.load('assets/icon/logo_mark.png');
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List(), targetWidth: 512);
      logo = (await codec.getNextFrame()).image;
    } catch (_) {}
    final png = await PrayerCardPainter(data, logo: logo).png();
    logo?.dispose();
    final now = DateTime.now();
    final name = 'mawaqit_${now.year}-${now.month}-${now.day}.png';
    if (kIsWeb) {
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(png, name: name, mimeType: 'image/png')],
        fileNameOverrides: [name],
        text: data.shareText,
      ));
      return true;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(png, flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'image/png')], text: data.shareText));
    return true;
  } catch (_) {
    return false;
  }
}
