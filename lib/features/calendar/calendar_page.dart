import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_themes.dart';
import '../../core/theme/tones.dart';
import '../../core/utils/arabic_utils.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/noor_ui.dart';
import '../../core/widgets/state_views.dart';
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    const tone = Tone.sapphire;
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
      subtitle: 'المناسبات وتذكير الصيام',
      icon: Icons.calendar_month_rounded,
      tone: tone,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (IslamicCalendar.isRamadan || _today.hMonth == 8) ...[
            _RamadanCard(ramadanNow: IslamicCalendar.isRamadan),
            const SizedBox(height: 12),
          ],
          NoorCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // Month header in the page's sapphire.
                DecoratedBox(
                  decoration: BoxDecoration(gradient: tone.solid),
                  child: Stack(
                    children: [
                      PositionedDirectional(
                        top: -30,
                        end: -24,
                        child: IgnorePointer(
                          child: SizedBox.square(
                            dimension: 110,
                            child: CustomPaint(painter: KhatamPainter(Colors.white.withValues(alpha: 0.18))),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
                        child: Row(
                          children: [
                            _MonthNavButton(icon: Icons.chevron_right_rounded, onTap: () => _shift(-1)),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    '${IslamicCalendar.months[_month - 1]} ${ArabicUtils.toArabicDigits(_year)} هـ',
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: AppFonts.display,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      height: 1.3,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    first.month == lastGreg.month
                                        ? greg.format(first)
                                        : '${DateFormat('MMMM', 'ar').format(first)} – ${greg.format(lastGreg)}',
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            _MonthNavButton(icon: Icons.chevron_left_rounded, onTap: () => _shift(1)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          for (final w in const ['سبت', 'أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة'])
                            Expanded(
                              child: Text(w,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: w == 'جمعة' ? glass.accent : glass.onGlassMuted,
                                    fontWeight: FontWeight.w800,
                                  )),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: lead + days,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.82),
                        itemBuilder: (context, i) {
                          if (i < lead) return const SizedBox.shrink();
                          final d = i - lead + 1;
                          final g = first.add(Duration(days: d - 1));
                          final occ = IslamicCalendar.on(_month, d);
                          final isToday = _year == _today.hYear && _month == _today.hMonth && d == _today.hDay;
                          final friday = g.weekday == DateTime.friday;
                          final occTone = occ.isEmpty ? null : _occasionTone(occ.first);
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
                                gradient: isToday ? tone.solid : null,
                                color: isToday || occTone == null
                                    ? null
                                    : occTone.mid.withValues(alpha: dark ? 0.14 : 0.12),
                                border: isToday
                                    ? Border.all(color: Colors.white.withValues(alpha: 0.3))
                                    : occTone != null
                                        ? Border.all(color: occTone.mid.withValues(alpha: 0.32))
                                        : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(ArabicUtils.toArabicDigits(d),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: isToday
                                            ? Colors.white
                                            : (friday ? glass.accent : glass.onGlass),
                                      )),
                                  Text('${g.day}',
                                      style: TextStyle(
                                          fontSize: 9.5,
                                          color: isToday ? Colors.white.withValues(alpha: 0.82) : glass.onGlassMuted)),
                                  if (occ.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          for (final o in occ.take(3))
                                            Container(
                                              width: 5,
                                              height: 5,
                                              margin: const EdgeInsets.symmetric(horizontal: 1),
                                              decoration: BoxDecoration(
                                                color: isToday ? Colors.white : _occasionTone(o).ink(dark),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 14,
                        runSpacing: 6,
                        children: const [
                          _LegendDot(tone: Tone.sapphire, label: 'اليوم'),
                          _LegendDot(tone: Tone.emerald, label: 'صيام مستحب'),
                          _LegendDot(tone: Tone.sky, label: 'الأيام البيض'),
                          _LegendDot(tone: Tone.amber, label: 'الأعياد'),
                          _LegendDot(tone: Tone.amethyst, label: 'مواسم ومناسبات'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          NoorCard(
            padding: EdgeInsets.zero,
            child: InkWell(
              onTap: () {
                final v = !reminders;
                context.read<SettingsCubit>().setOccasionReminders(v);
                IslamicCalendar.scheduleReminders(context.read<NotificationService>(), enabled: v);
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Row(
                  children: [
                    const ToneIcon(Icons.notifications_active_rounded, tone: Tone.amber, size: 42),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('تذكيري بالمناسبات والصيام',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: glass.onGlass)),
                          Text('مساء اليوم السابق، وتذكير الكهف يوم الجمعة',
                              style: TextStyle(fontSize: 12, height: 1.4, color: glass.onGlassMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: reminders,
                      onChanged: (v) {
                        context.read<SettingsCubit>().setOccasionReminders(v);
                        IslamicCalendar.scheduleReminders(context.read<NotificationService>(), enabled: v);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const GlassSectionTitle('المناسبات القادمة', tone: tone),
          if (upcoming.isEmpty)
            NoorCard(
              child: Text('لا مناسبات في الأسابيع القادمة',
                  textAlign: TextAlign.center, style: TextStyle(color: glass.onGlassMuted)),
            ),
          for (final (date, h, o) in upcoming) ...[
            _OccasionCard(date: date, day: h.hDay, month: h.hMonth, occasion: o, inDays: _inDays(date)),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
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

/// The colour of an occasion by its kind: eids amber, white days sky,
/// recommended fasts emerald, blessed seasons and other days amethyst.
Tone _occasionTone(Occasion o) {
  if (o.title == 'الأيام البيض') return Tone.sky;
  if (o.title.startsWith('عيد') || o.title == 'أيام التشريق') return Tone.amber;
  if (o.fast) return Tone.emerald;
  return Tone.amethyst;
}

class _MonthNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MonthNavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.28))),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(dimension: 40, child: Icon(icon, color: Colors.white, size: 24)),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Tone tone;
  final String label;

  const _LegendDot({required this.tone, required this.label});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: tone.ink(dark)),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: glass.onGlassMuted)),
      ],
    );
  }
}

/// An upcoming occasion: a coloured date block, the title and note, and
/// how many days are left.
class _OccasionCard extends StatelessWidget {
  final DateTime date;
  final int day;
  final int month;
  final Occasion occasion;
  final String inDays;

  const _OccasionCard({
    required this.date,
    required this.day,
    required this.month,
    required this.occasion,
    required this.inDays,
  });

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tone = _occasionTone(occasion);
    return ToneCard(
      tone: tone,
      radius: 22,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: tone.solid,
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Column(
              children: [
                Text(ArabicUtils.toArabicDigits(day),
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: Colors.white,
                    )),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text(IslamicCalendar.months[month - 1],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.88))),
                ),
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
                    Icon(occasion.icon, size: 17, color: tone.ink(dark)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(occasion.title,
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: glass.onGlass)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: tone.mid.withValues(alpha: dark ? 0.18 : 0.14),
                        border: Border.all(color: tone.mid.withValues(alpha: 0.4)),
                      ),
                      child: Text(inDays,
                          maxLines: 1,
                          style: TextStyle(fontSize: 11.5, color: tone.ink(dark), fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(occasion.note, style: TextStyle(fontSize: 12.5, color: glass.onGlassMuted, height: 1.5)),
                const SizedBox(height: 2),
                Text(DateFormat('EEEE d MMMM', 'ar').format(date),
                    style: TextStyle(fontSize: 11, color: glass.onGlassMuted.withValues(alpha: 0.85))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RamadanCard extends StatelessWidget {
  final bool ramadanNow;

  const _RamadanCard({required this.ramadanNow});

  @override
  Widget build(BuildContext context) {
    return ToneCard(
      tone: Tone.amber,
      solid: true,
      ornament: true,
      radius: 26,
      padding: const EdgeInsets.all(18),
      onTap: () => Navigator.of(context).push(ImsakiyaPage.route()),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.4),
            ),
            child: const Icon(Icons.brightness_3_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ramadanNow ? 'رمضان كريم' : 'رمضان على الأبواب',
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    )),
                Text('إمساكية رمضان لمدينتك مع عدّاد الإفطار',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded, color: Colors.white),
        ],
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
      subtitle: 'السحور والإفطار لمدينتك',
      icon: Icons.brightness_3_rounded,
      tone: Tone.amber,
      body: rows.first.$3 == null
          ? const MessageView(
              icon: Icons.location_off_rounded,
              title: 'حدّد موقعك من صفحة الصلاة لحساب الإمساكية',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (todayRow != null) ...[
                  _countdown(todayRow.$3!, now),
                  const SizedBox(height: 4),
                ],
                const GlassSectionTitle('جدول الشهر', tone: Tone.amber),
                NoorCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(gradient: Tone.amber.solid),
                        child: _row(glass, ['اليوم', 'الإمساك', 'الفجر', 'المغرب'], header: true),
                      ),
                      const SizedBox(height: 4),
                      for (var j = 0; j < rows.length; j++)
                        _row(
                          glass,
                          [
                            '${ArabicUtils.toArabicDigits(rows[j].$1)} • ${DateFormat('d/M').format(rows[j].$2)}',
                            ArabicUtils.formatTime(rows[j].$3![PrayerName.fajr].subtract(const Duration(minutes: 10))),
                            ArabicUtils.formatTime(rows[j].$3![PrayerName.fajr]),
                            ArabicUtils.formatTime(rows[j].$3![PrayerName.maghrib]),
                          ],
                          highlight: DateUtils.isSameDay(rows[j].$2, now),
                          striped: j.isOdd,
                        ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text('الإمساك قبل الفجر بعشر دقائق احتياطًا، والعبرة بأذان الفجر.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: glass.onGlassMuted)),
              ],
            ),
    );
  }

  Widget _countdown(PrayerDay p, DateTime now) {
    final maghrib = p[PrayerName.maghrib];
    final fajr = p[PrayerName.fajr];
    final toIftar = now.isBefore(maghrib) && now.isAfter(fajr);
    final target = toIftar ? maghrib : (now.isBefore(fajr) ? fajr : fajr.add(const Duration(days: 1)));
    final left = target.difference(now);
    return ToneCard(
      tone: toIftar ? Tone.amber : Tone.sapphire,
      solid: true,
      ornament: true,
      radius: 28,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(toIftar ? Icons.wb_twilight_rounded : Icons.nights_stay_rounded,
                  size: 18, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(toIftar ? 'باقي على الإفطار' : 'باقي على الإمساك والفجر',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              ArabicUtils.formatDuration(left),
              style: const TextStyle(
                fontFamily: AppFonts.display,
                color: Colors.white,
                fontSize: 46,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withValues(alpha: 0.18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
              ),
              child: Text(
                toIftar ? 'المغرب ${ArabicUtils.formatTime(maghrib)}' : 'الفجر ${ArabicUtils.formatTime(target)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          if (toIftar) ...[
            const SizedBox(height: 12),
            Text('ذهب الظمأ، وابتلّت العروق، وثبت الأجر إن شاء الله',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 12.5)),
          ],
        ],
      ),
    );
  }

  Widget _row(GlassTheme glass, List<String> cells, {bool header = false, bool highlight = false, bool striped = false}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    const tone = Tone.amber;
    return Container(
      margin: header ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      padding: EdgeInsets.symmetric(vertical: header ? 11 : 8, horizontal: header ? 14 : 8),
      decoration: header
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: highlight ? tone.wash(dark) : null,
              color: highlight || !striped ? null : glass.onGlass.withValues(alpha: dark ? 0.035 : 0.03),
              border: highlight ? Border.all(color: tone.mid.withValues(alpha: 0.6), width: 1.2) : null,
            ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: i == 0 ? 5 : 4,
              child: Text(
                cells[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: i == 0 ? TextAlign.start : TextAlign.center,
                style: TextStyle(
                  fontSize: header ? 12.5 : 13,
                  fontWeight: header || highlight ? FontWeight.w900 : FontWeight.w600,
                  color: header
                      ? Colors.white
                      : highlight
                          ? tone.ink(dark)
                          : (i == 0 ? glass.onGlass : glass.onGlass.withValues(alpha: 0.9)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
