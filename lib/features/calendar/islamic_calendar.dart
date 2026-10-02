import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../core/services/notification_service.dart';

/// A day in the Islamic year worth remembering.
class Occasion {
  final String title;
  final String note;
  final IconData icon;

  /// A recommended (sunnah) fast — used for the evening-before reminder.
  final bool fast;

  const Occasion(this.title, this.note, this.icon, {this.fast = false});
}

class IslamicCalendar {
  IslamicCalendar._();

  static HijriCalendar hijriOf(DateTime d) {
    HijriCalendar.setLocal('ar');
    return HijriCalendar.fromDate(DateTime(d.year, d.month, d.day));
  }

  static DateTime gregorianOf(int y, int m, int d) => HijriCalendar().hijriToGregorian(y, m, d);

  static int daysInMonth(int y, int m) => HijriCalendar().getDaysInMonth(y, m);

  static const months = [
    'محرّم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
    'رجب', 'شعبان', 'رمضان', 'شوّال', 'ذو القعدة', 'ذو الحجة',
  ];

  /// Occasions that fall on hijri [m]/[d].
  static List<Occasion> on(int m, int d) {
    final out = <Occasion>[];
    if (m == 1 && d == 1) out.add(const Occasion('رأس السنة الهجرية', 'بداية عام هجري جديد', Icons.celebration_rounded));
    if (m == 1 && d == 9) {
      out.add(const Occasion('تاسوعاء', 'يُستحب صيامه مع عاشوراء', Icons.nights_stay_rounded, fast: true));
    }
    if (m == 1 && d == 10) {
      out.add(const Occasion('يوم عاشوراء', 'صيامه يكفّر السنة التي قبله', Icons.wb_sunny_rounded, fast: true));
    }
    if (m == 9 && d == 1) out.add(const Occasion('بداية شهر رمضان', 'شهر الصيام والقيام والقرآن', Icons.brightness_3_rounded));
    if (m == 9 && d == 21) {
      out.add(const Occasion('العشر الأواخر', 'تحرَّوا ليلة القدر في الوتر منها', Icons.auto_awesome_rounded));
    }
    if (m == 10 && d == 1) out.add(const Occasion('عيد الفطر', 'تقبّل الله منا ومنكم', Icons.celebration_rounded));
    if (m == 10 && d == 2) {
      out.add(const Occasion('صيام الست من شوال', 'من صام رمضان وأتبعه ستًّا من شوال كان كصيام الدهر',
          Icons.event_repeat_rounded, fast: true));
    }
    if (m == 12 && d == 1) {
      out.add(const Occasion('العشر من ذي الحجة', 'أفضل أيام الدنيا، أكثر فيها من الذكر والعمل الصالح', Icons.auto_awesome_rounded));
    }
    if (m == 12 && d == 9) {
      out.add(const Occasion('يوم عرفة', 'صيامه يكفّر السنة الماضية والباقية', Icons.landscape_rounded, fast: true));
    }
    if (m == 12 && d == 10) out.add(const Occasion('عيد الأضحى', 'تقبّل الله منا ومنكم', Icons.celebration_rounded));
    if (m == 12 && (d == 11 || d == 12 || d == 13)) {
      out.add(const Occasion('أيام التشريق', 'أيام أكل وشرب وذكر لله', Icons.restaurant_rounded));
    }
    // الأيام البيض (not in Ramadan, not during the days of Tashreeq)
    if ((d == 13 || d == 14 || d == 15) && m != 9 && !(m == 12 && d == 13)) {
      out.add(const Occasion('الأيام البيض', 'صيام ثلاثة أيام من كل شهر', Icons.brightness_7_rounded, fast: true));
    }
    return out;
  }

  /// Occasions in the next [days] days, keyed by Gregorian date.
  static List<(DateTime, HijriCalendar, Occasion)> upcoming({DateTime? from, int days = 60}) {
    final start = from ?? DateTime.now();
    final out = <(DateTime, HijriCalendar, Occasion)>[];
    for (var i = 0; i < days; i++) {
      final d = DateTime(start.year, start.month, start.day).add(Duration(days: i));
      final h = hijriOf(d);
      for (final o in on(h.hMonth, h.hDay)) {
        // Only the first of the white days / tashreeq needs to be listed.
        if (o.title == 'الأيام البيض' && h.hDay != 13) continue;
        if (o.title == 'أيام التشريق' && h.hDay != 11) continue;
        out.add((d, h, o));
      }
    }
    return out;
  }

  static bool get isRamadan => hijriOf(DateTime.now()).hMonth == 9;

  static const _baseId = 500;

  /// Evening-before reminders for the next weeks, plus Friday (Al-Kahf).
  static Future<void> scheduleReminders(NotificationService n, {required bool enabled}) async {
    for (var i = 0; i < 80; i++) {
      await n.cancel(_baseId + i);
    }
    if (!enabled) return;
    var id = _baseId;
    final now = DateTime.now();
    for (var i = 1; i <= 45 && id < _baseId + 60; i++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: i));
      final h = hijriOf(day);
      for (final o in on(h.hMonth, h.hDay)) {
        final eve = day.subtract(const Duration(days: 1)).add(const Duration(hours: 20));
        if (!eve.isAfter(now)) continue;
        await n.scheduleReminderAt(
          id: id++,
          title: o.fast ? 'غدًا ${o.title} 🌙' : 'غدًا: ${o.title}',
          body: o.fast ? '${o.note}. انوِ الصيام من الليل.' : o.note,
          when: eve,
        );
      }
    }
    // The next four Fridays: Surat Al-Kahf and salawat.
    var fri = DateTime(now.year, now.month, now.day);
    while (fri.weekday != DateTime.friday) {
      fri = fri.add(const Duration(days: 1));
    }
    for (var k = 0; k < 4; k++) {
      final when = fri.add(Duration(days: 7 * k, hours: 9));
      if (!when.isAfter(now)) continue;
      await n.scheduleReminderAt(
        id: _baseId + 70 + k,
        title: 'جمعة مباركة 🌿',
        body: 'لا تنسَ قراءة سورة الكهف والإكثار من الصلاة على النبي ﷺ',
        when: when,
      );
    }
  }
}
