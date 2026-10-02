import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_themes.dart';
import '../../core/utils/arabic_utils.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/noor_ui.dart';
import '../prayer/domain/prayer_entities.dart';
import '../prayer/presentation/cubit/prayer_cubit.dart';
import '../settings/presentation/cubit/settings_cubit.dart';
import 'islamic_calendar.dart';
import '../../core/services/notification_service.dart';

/// التقويم الهجري: month grid, occasions, reminders, and the imsakiya.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const CalendarPage());

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late int _year;
  late int _month;
  late final _today = IslamicCalendar.hijriOf(DateTime.now());

  @override
  void initState() {
    super.initState();
    _year = _today.hYear;
    _month = _today.hMonth;
  }

  void _shift(int delta) {
    setState(() {
      _month += delta;
      if (_month > 12) {
        _month = 1;
        _year++;
      } else if (_month < 1) {
        _month = 12;
        _year--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final days = IslamicCalendar.daysInMonth(_year, _month);
    final first = IslamicCalendar.gregorianOf(_year, _month, 1);
    // Saturday-first week (common in Egypt / Gulf calendars).
    final lead = (first.weekday % 7 + 1) % 7; // Sat=0 … Fri=6
    final upcoming = IslamicCalendar.upcoming(days: 90);
    final reminders = context.select((SettingsCubit c) => c.state.occasionReminders);
    final greg = DateFormat('MMMM y', 'ar');
    final lastGreg = IslamicCalendar.gregorianOf(_year, _month, days);
    return GlassScaffold(
      title: 'التقويم الهجري',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (IslamicCalendar.isRamadan || _today.hMonth == 8) ...[
            _RamadanCard(ramadanNow: IslamicCalendar.isRamadan),
            const SizedBox(height: 12),
          ],
          GlassContainer(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_right_rounded)),
                    Expanded(
                      child: Column(
                        children: [
                          Text('${IslamicCalendar.months[_month - 1]} ${ArabicUtils.toArabicDigits(_year)} هـ',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          Text(
                            first.month == lastGreg.month
                                ? greg.format(first)
                                : '${DateFormat('MMMM', 'ar').format(first)} – ${greg.format(lastGreg)}',
                            style: TextStyle(color: glass.onGlassMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_left_rounded)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final w in const ['سبت', 'أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة'])
                      Expanded(
                        child: Text(w,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: glass.onGlassMuted, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: lead + days,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.82),
                  itemBuilder: (context, i) {
                    if (i < lead) return const SizedBox.shrink();
                    final d = i - lead + 1;
                    final g = first.add(Duration(days: d - 1));
                    final occ = IslamicCalendar.on(_month, d);
                    final isToday = _year == _today.hYear && _month == _today.hMonth && d == _today.hDay;
                    final friday = g.weekday == DateTime.friday;
                    return GestureDetector(
                      onTap: occ.isEmpty
                          ? null
                          : () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(occ.map((o) => '${o.title}: ${o.note}').join('\n')),
                              )),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isToday
                              ? glass.accent
                              : occ.isNotEmpty
                                  ? glass.accent.withValues(alpha: 0.14)
                                  : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(ArabicUtils.toArabicDigits(d),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: isToday ? Colors.black : (friday ? glass.accent : glass.onGlass),
                                )),
                            Text('${g.day}',
                                style: TextStyle(
                                    fontSize: 9.5, color: isToday ? Colors.black87 : glass.onGlassMuted)),
                            if (occ.isNotEmpty && !isToday)
                              Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.only(top: 2),
                                decoration: BoxDecoration(color: glass.accent, shape: BoxShape.circle),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(Icons.notifications_active_rounded, color: glass.accent),
              title: const Text('تذكيري بالمناسبات والصيام', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('مساء اليوم السابق، وتذكير الكهف يوم الجمعة'),
              value: reminders,
              onChanged: (v) {
                context.read<SettingsCubit>().setOccasionReminders(v);
                IslamicCalendar.scheduleReminders(context.read<NotificationService>(), enabled: v);
              },
            ),
          ),
          const GlassSectionTitle('المناسبات القادمة'),
          if (upcoming.isEmpty)
            Text('لا مناسبات في الأسابيع القادمة', style: TextStyle(color: glass.onGlassMuted)),
          for (final (date, h, o) in upcoming)
            GlassContainer(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: glass.accent.withValues(alpha: 0.14),
                    ),
                    child: Column(
                      children: [
                        Text(ArabicUtils.toArabicDigits(h.hDay),
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: glass.accent)),
                        Text(IslamicCalendar.months[h.hMonth - 1],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 9.5, color: glass.onGlassMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(o.icon, size: 16, color: glass.accent),
                            const SizedBox(width: 6),
                            Flexible(child: Text(o.title, style: const TextStyle(fontWeight: FontWeight.w900))),
                          ],
                        ),
                        Text(o.note, style: TextStyle(fontSize: 12.5, color: glass.onGlassMuted, height: 1.5)),
                      ],
                    ),
                  ),
                  Text(_inDays(date), style: TextStyle(fontSize: 12, color: glass.accent, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text('التقويم بحساب أم القرى، وقد يختلف يومًا عن رؤية الهلال في بلدك.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: glass.onGlassMuted)),
        ],
      ),
    );
  }

  String _inDays(DateTime d) {
    final now = DateTime.now();
    final diff = DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'غدًا';
    return 'بعد ${ArabicUtils.toArabicDigits(diff)} يوم';
  }
}

class _RamadanCard extends StatelessWidget {
  final bool ramadanNow;

  const _RamadanCard({required this.ramadanNow});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(ImsakiyaPage.route()),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(colors: skyColors(SkyPhase.sunset), begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: Row(
          children: [
            const Icon(Icons.brightness_3_rounded, color: Color(0xFFFFE3A3), size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ramadanNow ? 'رمضان كريم' : 'رمضان على الأبواب',
                      style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                  Text('إمساكية رمضان لمدينتك مع عدّاد الإفطار',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

/// إمساكية رمضان: imsak (10 min before Fajr), Fajr and Maghrib for every day,
/// with a live countdown to iftar / suhoor.
class ImsakiyaPage extends StatefulWidget {
  const ImsakiyaPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const ImsakiyaPage());

  @override
  State<ImsakiyaPage> createState() => _ImsakiyaPageState();
}

class _ImsakiyaPageState extends State<ImsakiyaPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final cubit = context.read<PrayerCubit>();
    final today = IslamicCalendar.hijriOf(DateTime.now());
    final year = today.hMonth > 9 ? today.hYear + 1 : today.hYear;
    final days = IslamicCalendar.daysInMonth(year, 9);
    final start = IslamicCalendar.gregorianOf(year, 9, 1);
    final rows = [
      for (var d = 1; d <= days; d++) (d, start.add(Duration(days: d - 1)), cubit.dayFor(start.add(Duration(days: d - 1)))),
    ];
    final now = DateTime.now();
    final todayRow = rows.where((r) => DateUtils.isSameDay(r.$2, now)).firstOrNull;
    return GlassScaffold(
      title: 'إمساكية رمضان ${ArabicUtils.toArabicDigits(year)}',
      body: rows.first.$3 == null
          ? Center(child: Text('حدّد موقعك من صفحة الصلاة لحساب الإمساكية', style: TextStyle(color: glass.onGlassMuted)))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (todayRow != null) _countdown(glass, todayRow.$3!, now),
                const SizedBox(height: 12),
                GlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    children: [
                      _row(glass, ['اليوم', 'الإمساك', 'الفجر', 'المغرب'], header: true),
                      for (final (d, g, p) in rows)
                        _row(
                          glass,
                          [
                            '${ArabicUtils.toArabicDigits(d)} • ${DateFormat('d/M').format(g)}',
                            ArabicUtils.formatTime(p![PrayerName.fajr].subtract(const Duration(minutes: 10))),
                            ArabicUtils.formatTime(p[PrayerName.fajr]),
                            ArabicUtils.formatTime(p[PrayerName.maghrib]),
                          ],
                          highlight: DateUtils.isSameDay(g, now),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text('الإمساك قبل الفجر بعشر دقائق احتياطًا، والعبرة بأذان الفجر.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: glass.onGlassMuted)),
              ],
            ),
    );
  }

  Widget _countdown(GlassTheme glass, PrayerDay p, DateTime now) {
    final maghrib = p[PrayerName.maghrib];
    final fajr = p[PrayerName.fajr];
    final toIftar = now.isBefore(maghrib) && now.isAfter(fajr);
    final target = toIftar ? maghrib : (now.isBefore(fajr) ? fajr : fajr.add(const Duration(days: 1)));
    final left = target.difference(now);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: skyColors(toIftar ? SkyPhase.sunset : SkyPhase.night),
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Text(toIftar ? 'باقي على الإفطار' : 'باقي على الإمساك والفجر',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w700)),
          Text(ArabicUtils.formatDuration(left),
              style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
          Text(toIftar ? 'المغرب ${ArabicUtils.formatTime(maghrib)}' : 'الفجر ${ArabicUtils.formatTime(target)}',
              style: const TextStyle(color: Color(0xFFFFE3A3), fontWeight: FontWeight.w800)),
          if (toIftar) ...[
            const SizedBox(height: 10),
            Text('ذهب الظمأ، وابتلّت العروق، وثبت الأجر إن شاء الله',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5)),
          ],
        ],
      ),
    );
  }

  Widget _row(GlassTheme glass, List<String> cells, {bool header = false, bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: highlight ? glass.accent.withValues(alpha: 0.18) : null,
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: i == 0 ? 5 : 4,
              child: Text(
                cells[i],
                textAlign: i == 0 ? TextAlign.start : TextAlign.center,
                style: TextStyle(
                  fontSize: header ? 12 : 13,
                  fontWeight: header || highlight ? FontWeight.w900 : FontWeight.w600,
                  color: header ? glass.accent : glass.onGlass,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
