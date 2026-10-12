import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../core/theme/app_themes.dart';
import '../../../core/theme/tones.dart';
import '../../../core/utils/arabic_utils.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/noor_ui.dart';
import '../../calendar/islamic_calendar.dart';
import '../data/prayer_log.dart';
import '../domain/prayer_entities.dart';
import 'cubit/prayer_cubit.dart';
import 'prayer_tones.dart';

const _tone = Tone.sapphire;
const _days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];

String _dayName(DateTime d) => _days[d.weekday % 7];

/// Today's five prayers to tick, on the prayer page.
class PrayerLogCard extends StatelessWidget {
  const PrayerLogCard({super.key});

  @override
  Widget build(BuildContext context) {
    final log = context.read<PrayerLog>();
    final glass = GlassTheme.of(context);
    return ListenableBuilder(
      listenable: log,
      builder: (context, _) {
        final today = DateTime.now();
        final done = log.doneOn(today);
        final (d7, due7) = log.lastDays(7, todayTimes: _todayTimes(context));
        return NoorCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          onTap: () => Navigator.of(context).push(PrayerLogPage.route()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const ToneIcon(Icons.task_alt_rounded, tone: _tone, size: 36),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('صلواتي اليوم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                  Text('${ArabicUtils.toArabicDigits(done.length)} / ٥',
                      style: const TextStyle(fontFamily: AppFonts.display, fontSize: 18)),
                  Icon(Icons.chevron_left_rounded, color: glass.onGlassMuted),
                ],
              ),
              const SizedBox(height: 12),
              PrayerTicks(day: today),
              const SizedBox(height: 10),
              Text(
                'آخر ٧ أيام: ${ArabicUtils.toArabicDigits(d7)} من ${ArabicUtils.toArabicDigits(due7)}'
                '${log.fullDaysStreak > 0 ? ' • ${ArabicUtils.toArabicDigits(log.fullDaysStreak)} يوم كامل متتالي' : ''}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: glass.onGlassMuted),
              ),
            ],
          ),
        );
      },
    );
  }
}

List<DateTime>? _todayTimes(BuildContext context) {
  final t = context.read<PrayerCubit>().state.today;
  if (t == null) return null;
  return [for (final p in PrayerName.values.where((p) => p.isPrayer)) t[p]];
}

/// The five prayers of [day] as round buttons: tap to mark prayed.
class PrayerTicks extends StatelessWidget {
  final DateTime day;
  final double size;

  const PrayerTicks({super.key, required this.day, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final log = context.read<PrayerLog>();
    final glass = GlassTheme.of(context);
    final done = log.doneOn(day);
    final prayerNames = PrayerName.values.where((p) => p.isPrayer).toList();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        for (var i = 0; i < 5; i++)
          InkWell(
            borderRadius: BorderRadius.circular(size),
            onTap: () => log.toggle(day, i),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: done.contains(i) ? prayerNames[i].tone.gradient() : null,
                    border: done.contains(i) ? null : Border.all(color: glass.onGlass.withValues(alpha: 0.18), width: 2),
                  ),
                  child: Icon(done.contains(i) ? Icons.check_rounded : Icons.circle_outlined,
                      color: done.contains(i) ? Colors.white : glass.onGlass.withValues(alpha: 0.25), size: size * 0.5),
                ),
                const SizedBox(height: 4),
                Text(PrayerLog.prayers[i], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }
}

/// «متابعة الصلوات»: the last four weeks, the make-up count and Ramadan.
class PrayerLogPage extends StatelessWidget {
  const PrayerLogPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const PrayerLogPage());

  @override
  Widget build(BuildContext context) {
    final log = context.read<PrayerLog>();
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GlassScaffold(
      title: 'متابعة الصلوات',
      subtitle: 'حافظوا على الصلوات',
      icon: Icons.task_alt_rounded,
      tone: _tone,
      body: ListenableBuilder(
        listenable: log,
        builder: (context, _) {
          final now = DateTime.now();
          final (d7, due7) = log.lastDays(7, todayTimes: _todayTimes(context));
          final (d30, due30) = log.lastDays(30, todayTimes: _todayTimes(context));
          final hijri = HijriCalendar.now();
          final showRamadan = hijri.hMonth >= 9 || IslamicCalendar.isRamadan;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              NoorCard(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                child: Column(
                  children: [
                    Text('اليوم • ${_dayName(now)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 12),
                    PrayerTicks(day: now, size: 56),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _Stat('آخر ٧ أيام', due7 == 0 ? '—' : '${ArabicUtils.toArabicDigits((d7 * 100 / due7).round())}٪', Tone.sapphire)),
                  const SizedBox(width: 10),
                  Expanded(child: _Stat('آخر ٣٠ يومًا', due30 == 0 ? '—' : '${ArabicUtils.toArabicDigits((d30 * 100 / due30).round())}٪', Tone.emerald)),
                  const SizedBox(width: 10),
                  Expanded(child: _Stat('أيام كاملة متتالية', ArabicUtils.toArabicDigits(log.fullDaysStreak), Tone.amber)),
                ],
              ),
              const GlassSectionTitle('آخر أسبوعين', tone: _tone),
              NoorCard(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 92),
                        for (final p in PrayerLog.prayers)
                          Expanded(child: Text(p, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: glass.onGlassMuted))),
                      ],
                    ),
                    for (var i = 1; i < 15; i++) _DayRow(day: now.subtract(Duration(days: i))),
                  ],
                ),
              ),
              const GlassSectionTitle('صلوات القضاء', tone: _tone),
              NoorCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Text('سجّل عدد الصلوات الفائتة، وانقص منها كلما قضيت صلاة.',
                        textAlign: TextAlign.center, style: TextStyle(color: glass.onGlassMuted, fontSize: 13)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filledTonal(onPressed: () => log.setQada(log.qada + 1), icon: const Icon(Icons.add_rounded)),
                        const SizedBox(width: 18),
                        Text(ArabicUtils.toArabicDigits(log.qada), style: const TextStyle(fontFamily: AppFonts.display, fontSize: 40)),
                        const SizedBox(width: 18),
                        IconButton.filledTonal(
                            onPressed: log.qada > 0 ? () => log.setQada(log.qada - 1) : null, icon: const Icon(Icons.remove_rounded)),
                      ],
                    ),
                    if (log.qada > 0)
                      Text('صلاة متبقية', style: TextStyle(color: _tone.ink(dark), fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              if (showRamadan) ...[
                GlassSectionTitle('رمضان ${ArabicUtils.toArabicDigits(hijri.hYear)} هـ', tone: Tone.amber),
                RamadanTracker(year: hijri.hYear, today: IslamicCalendar.isRamadan ? hijri.hDay : null),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Tone tone;

  const _Stat(this.label, this.value, this.tone);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ToneCard(
      tone: tone,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontFamily: AppFonts.display, fontSize: 24, color: tone.ink(dark))),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final DateTime day;

  const _DayRow({required this.day});

  @override
  Widget build(BuildContext context) {
    final log = context.read<PrayerLog>();
    final glass = GlassTheme.of(context);
    final done = log.doneOn(day);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text('${_dayName(day)} ${ArabicUtils.toArabicDigits(day.day)}/${ArabicUtils.toArabicDigits(day.month)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          for (var i = 0; i < 5; i++)
            Expanded(
              child: Center(
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => log.toggle(day, i),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      done.contains(i) ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 24,
                      color: done.contains(i) ? Tone.emerald.mid : glass.onGlass.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ramadan's thirty days: the fast and the taraweeh of each.
class RamadanTracker extends StatelessWidget {
  final int year;
  final int? today;

  const RamadanTracker({super.key, required this.year, this.today});

  @override
  Widget build(BuildContext context) {
    final log = context.read<PrayerLog>();
    final glass = GlassTheme.of(context);
    return ListenableBuilder(
      listenable: log,
      builder: (context, _) {
        final fasts = log.fasts(year);
        final taraweeh = log.taraweeh(year);
        return NoorCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                'الصيام ${ArabicUtils.toArabicDigits(fasts.length)} يومًا • التراويح ${ArabicUtils.toArabicDigits(taraweeh.length)} ليلة',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text('اضغط على اليوم لتسجيل الصيام، وعلى القمر للتراويح',
                  style: TextStyle(fontSize: 12, color: glass.onGlassMuted)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 6,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 0.78,
                children: [
                  for (var d = 1; d <= 30; d++)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: d == today ? Tone.amber.mid : glass.onGlass.withValues(alpha: 0.08), width: d == today ? 2 : 1),
                        gradient: fasts.contains(d) ? Tone.amber.gradient(opacity: 0.85) : null,
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => log.toggleFast(year, d),
                              child: Center(
                                child: Text(ArabicUtils.toArabicDigits(d),
                                    style: TextStyle(
                                        fontFamily: AppFonts.display,
                                        fontSize: 17,
                                        color: fasts.contains(d) ? Colors.white : glass.onGlass)),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => log.toggleTaraweeh(year, d),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Icon(taraweeh.contains(d) ? Icons.nightlight_round : Icons.nightlight_outlined,
                                  size: 16, color: taraweeh.contains(d) ? const Color(0xFFFFE3A3) : glass.onGlass.withValues(alpha: 0.35)),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
