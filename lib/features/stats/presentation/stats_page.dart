import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/web_lite.dart';
import '../../../core/theme/app_themes.dart';
import '../../../core/utils/arabic_utils.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/gradient_background.dart';
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
}

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const StatsPage());

  static const _weekdays = ['إثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت', 'أحد'];

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return GlassScaffold(
      title: 'إحصائياتي',
      body: BlocBuilder<StatsCubit, StatsSummary>(
        builder: (context, s) {
          final maxDay = s.lastWeek.fold<int>(1, (m, d) => d.total > m ? d.total : m);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              StreakCard(summary: s),
              const GlassSectionTitle('آخر ٧ أيام'),
              GlassContainer(
                padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
                child: SizedBox(
                  height: 180,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final d in s.lastWeek)
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(ArabicUtils.toArabicDigits(d.total), style: TextStyle(fontSize: 10, color: glass.onGlassMuted)),
                              const SizedBox(height: 4),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOutBack,
                                height: 120 * (d.total / maxDay) + 4,
                                margin: const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: d.isActive
                                        ? [Theme.of(context).colorScheme.primary, glass.accent]
                                        : [glass.onGlass.withValues(alpha: 0.1), glass.onGlass.withValues(alpha: 0.15)],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(_weekdays[d.date.weekday - 1], style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const GlassSectionTitle('المجموع الكلي'),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: [
                  for (final t in StatType.values)
                    GlassContainer(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(t.icon, color: glass.accent),
                          const SizedBox(height: 6),
                          Text(ArabicUtils.toArabicDigits(s.totals[t] ?? 0),
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                          Text(t.labelAr, style: TextStyle(color: glass.onGlassMuted, fontSize: 12.5)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'أيام النشاط: ${ArabicUtils.toArabicDigits(s.activeDays)} يومًا — «أحب الأعمال إلى الله أدومها وإن قل»',
                textAlign: TextAlign.center,
                style: TextStyle(color: glass.onGlassMuted),
              ),
            ],
          );
        },
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
    final glass = GlassTheme.of(context);
    return GlassContainer(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.deepOrange.shade600]),
              boxShadow: liteShadows([BoxShadow(color: Colors.orange.withValues(alpha: 0.5), blurRadius: 18)]),
            ),
            child: const Center(child: Text('🔥', style: TextStyle(fontSize: 30))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${ArabicUtils.toArabicDigits(summary.currentStreak)} يوم متتالٍ',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                Text('أطول سلسلة: ${ArabicUtils.toArabicDigits(summary.longestStreak)} يومًا',
                    style: TextStyle(color: glass.onGlassMuted)),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final d in summary.lastWeek)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: d.isActive ? glass.accent : glass.onGlass.withValues(alpha: 0.2),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
