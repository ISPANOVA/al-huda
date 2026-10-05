import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_themes.dart';
import '../../../core/theme/tones.dart';
import '../../../core/utils/arabic_utils.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/noor_ui.dart';
import '../data/stats_repository.dart';
import '../domain/stats_entities.dart';

class StatsCubit extends Cubit<StatsSummary> {
  final StatsRepository _repo;
  late final StreamSubscription<void> _sub;
  Timer? _debounce;

  StatsCubit(this._repo) : super(_repo.summary()) {
    _sub = _repo.changes.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (!isClosed) emit(_repo.summary());
      });
    });
  }

  void refresh() => emit(_repo.summary());

  @override
  Future<void> close() async {
    _debounce?.cancel();
    await _sub.cancel();
    return super.close();
  }
}

extension StatTypeX on StatType {
  String get labelAr => switch (this) {
        StatType.quranAyahs => 'آيات مقروءة',
        StatType.listenedAyahs => 'آيات مسموعة',
        StatType.tasbeeh => 'تسبيحات',
        StatType.athkar => 'أذكار',
      };

  IconData get icon => switch (this) {
        StatType.quranAyahs => Icons.menu_book_rounded,
        StatType.listenedAyahs => Icons.headphones_rounded,
        StatType.tasbeeh => Icons.blur_circular_rounded,
        StatType.athkar => Icons.favorite_rounded,
      };

  /// The colour of each kind of worship on this page.
  Tone get tone => switch (this) {
        StatType.quranAyahs => Tone.emerald,
        StatType.listenedAyahs => Tone.amethyst,
        StatType.tasbeeh => Tone.teal,
        StatType.athkar => Tone.rose,
      };
}

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const StatsPage());

  static const _weekdays = ['إثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت', 'أحد'];

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    const tone = Tone.amber;
    return GlassScaffold(
      title: 'إحصائياتي',
      subtitle: 'المداومة والإنجاز',
      icon: Icons.insights_rounded,
      tone: tone,
      body: BlocBuilder<StatsCubit, StatsSummary>(
        builder: (context, s) {
          final maxDay = s.lastWeek.fold<int>(1, (m, d) => d.total > m ? d.total : m);
          final weekTotal = s.lastWeek.fold<int>(0, (a, d) => a + d.total);
          final weekActive = s.lastWeek.where((d) => d.isActive).length;
          const types = StatType.values;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              StreakCard(summary: s),
              const GlassSectionTitle('آخر ٧ أيام', tone: tone),
              NoorCard(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _MiniPill(
                          tone: tone,
                          icon: Icons.bolt_rounded,
                          text: 'مجموع الأسبوع: ${ArabicUtils.toArabicDigits(weekTotal)}',
                        ),
                        const SizedBox(width: 8),
                        _MiniPill(
                          tone: Tone.emerald,
                          icon: Icons.check_circle_rounded,
                          text: 'أيام نشطة: ${ArabicUtils.toArabicDigits(weekActive)}/${ArabicUtils.toArabicDigits(7)}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 190,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < s.lastWeek.length; i++)
                            Expanded(
                              child: _DayBar(
                                day: s.lastWeek[i],
                                label: _weekdays[s.lastWeek[i].date.weekday - 1],
                                isToday: i == s.lastWeek.length - 1,
                                maxDay: maxDay,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const GlassSectionTitle('المجموع الكلي', tone: tone),
              for (var r = 0; r < types.length; r += 2) ...[
                if (r > 0) const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _TotalTile(type: types[r], value: s.totals[types[r]] ?? 0)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: r + 1 < types.length
                          ? _TotalTile(type: types[r + 1], value: s.totals[types[r + 1]] ?? 0)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              ToneCard(
                tone: Tone.gold,
                ornament: true,
                child: Row(
                  children: [
                    const ToneIcon(Icons.event_available_rounded, tone: Tone.gold, size: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'أيام النشاط: ${ArabicUtils.toArabicDigits(s.activeDays)} يومًا',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: glass.onGlass),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '«أحب الأعمال إلى الله أدومها وإن قل»',
                            style: TextStyle(color: Tone.gold.ink(dark), height: 1.5, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One column of the weekly chart: value, bar and day name.
class _DayBar extends StatelessWidget {
  final DailyStat day;
  final String label;
  final bool isToday;
  final int maxDay;

  const _DayBar({required this.day, required this.label, required this.isToday, required this.maxDay});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    const tone = Tone.amber;
    final active = day.isActive;
    final gradient = isToday ? Tone.coral : tone;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            ArabicUtils.toArabicDigits(day.total),
            style: TextStyle(
              fontSize: isToday ? 12 : 10.5,
              fontWeight: isToday || active ? FontWeight.w900 : FontWeight.w600,
              color: active ? gradient.ink(dark) : glass.onGlassMuted,
            ),
          ),
        ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutBack,
          width: 26,
          height: 120 * (day.total / maxDay) + 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: active
                ? LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [gradient.deep, gradient.light],
                  )
                : null,
            color: active ? null : glass.onGlass.withValues(alpha: 0.09),
            border: isToday ? Border.all(color: gradient.light.withValues(alpha: 0.9), width: 1.4) : null,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: isToday
              ? BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: gradient.solid)
              : null,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
              color: isToday ? Colors.white : glass.onGlassMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// A total for one kind of worship: coloured icon, big number, label.
class _TotalTile extends StatelessWidget {
  final StatType type;
  final int value;

  const _TotalTile({required this.type, required this.value});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tone = type.tone;
    return ToneCard(
      tone: tone,
      radius: 22,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ToneIcon(type.icon, tone: tone, size: 38),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                ArabicUtils.toArabicDigits(value),
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: tone.ink(dark),
                ),
              ),
            ),
          ),
          Text(
            type.labelAr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: glass.onGlassMuted, fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final Tone tone;
  final IconData icon;
  final String text;

  const _MiniPill({required this.tone, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: tone.mid.withValues(alpha: dark ? 0.16 : 0.12),
          border: Border.all(color: tone.mid.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: tone.ink(dark)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tone.ink(dark)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StreakCard extends StatelessWidget {
  final StatsSummary summary;
  final VoidCallback? onTap;

  const StreakCard({super.key, required this.summary, this.onTap});

  @override
  Widget build(BuildContext context) {
    final week = summary.lastWeek;
    return ToneCard(
      tone: Tone.amber,
      solid: true,
      ornament: true,
      radius: 26,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.32), width: 1.4),
                ),
                child: const Center(child: Text('🔥', style: TextStyle(fontSize: 30))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سلسلة المواظبة',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              ArabicUtils.toArabicDigits(summary.currentStreak),
                              style: const TextStyle(
                                fontFamily: AppFonts.display,
                                fontSize: 48,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'يوم متتالٍ',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emoji_events_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'أطول سلسلة: ${ArabicUtils.toArabicDigits(summary.longestStreak)} يومًا',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < week.length; i++)
                    Container(
                      width: i == week.length - 1 ? 11 : 9,
                      height: i == week.length - 1 ? 11 : 9,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: week[i].isActive ? Colors.white : Colors.white.withValues(alpha: 0.24),
                        border: i == week.length - 1
                            ? Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5)
                            : null,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
