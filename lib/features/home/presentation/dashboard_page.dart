import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../core/data/surah_metadata.dart';
import '../../../core/services/home_widgets.dart';
import '../../../core/theme/app_themes.dart';
import '../../../core/utils/arabic_utils.dart';
import '../../../core/widgets/glass_container.dart';
import '../../audio/presentation/cubit/audio_cubit.dart';
import '../../khatmah/presentation/cubit/khatmah_cubit.dart';
import '../../khatmah/presentation/pages/khatmah_page.dart';
import '../../prayer/presentation/widgets/next_prayer_card.dart';
import '../../qibla/presentation/pages/qibla_page.dart';
import '../../quran/domain/entities/ayah.dart';
import '../../quran/domain/entities/ayah_ref.dart';
import '../../quran/domain/repositories/quran_repository.dart';
import '../../quran/presentation/cubit/bookmarks_cubit.dart';
import '../../quran/presentation/mushaf/mushaf_reader_page.dart';
import '../../settings/presentation/cubit/settings_cubit.dart';
import '../../stats/domain/stats_entities.dart';
import '../../stats/presentation/stats_page.dart';
import '../../wird/wird_card.dart';
import 'quick_actions.dart';

class DashboardPage extends StatelessWidget {
  final ValueChanged<int> onNavigate;

  const DashboardPage({super.key, required this.onNavigate});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'صباح الخير';
    if (h < 18) return 'طاب يومك';
    return 'مساء الخير';
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    HijriCalendar.setLocal('ar');
    final hijri = HijriCalendar.now();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_greeting()} 🌿', style: TextStyle(color: glass.onGlassMuted)),
                  Text('الهدى', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                  Text('${hijri.toFormat('dd MMMM yyyy')} هـ',
                      style: TextStyle(color: glass.accent, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            GlassIconButton(
              icon: Icons.explore_rounded,
              tooltip: 'القبلة',
              onPressed: () => Navigator.of(context).push(QiblaPage.route()),
            ),
          ],
        ),
        const SizedBox(height: 16),
        NextPrayerCard(onTap: () => onNavigate(3)),
        const SizedBox(height: 12),
        const _ContinueReadingCard(),
        const SizedBox(height: 12),
        const WirdCard(),
        const _KhatmahMiniCard(),
        const SizedBox(height: 12),
        BlocBuilder<StatsCubit, StatsSummary>(
          builder: (context, s) => StreakCard(summary: s, onTap: () => Navigator.of(context).push(StatsPage.route())),
        ),
        QuickActionsSection(onNavigate: onNavigate),
        const GlassSectionTitle('آية اليوم'),
        const _AyahOfTheDay(),
      ],
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard();

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final last = context.select<BookmarksCubit, AyahRef?>((c) => c.state.lastRead);
    final surah = last?.surah ?? 1;
    final ayah = last?.ayah ?? 1;
    final info = SurahMetadata.surah(surah);
    final percent = SurahMetadata.globalAyah(surah, ayah) / SurahMetadata.totalAyahs;
    return GlassContainer(
      onTap: () => MushafReaderPage.open(context, surah: surah, ayah: ayah),
      child: Row(
        children: [
          Icon(Icons.auto_stories_rounded, color: glass.accent, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(last == null ? 'ابدأ القراءة' : 'متابعة القراءة', style: TextStyle(color: glass.onGlassMuted)),
                Text('سورة ${info.name} • الآية ${ArabicUtils.toArabicDigits(ayah)}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                GlassProgressBar(value: percent, height: 6),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'استماع',
            icon: Icon(Icons.play_circle_fill_rounded, color: glass.accent, size: 40),
            onPressed: () => context.read<AudioCubit>().playSurah(surah, fromAyah: ayah),
          ),
        ],
      ),
    );
  }
}

class _KhatmahMiniCard extends StatelessWidget {
  const _KhatmahMiniCard();

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final plan = context.select((KhatmahCubit c) => c.state.plan);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GlassContainer(
        onTap: () => Navigator.of(context).push(KhatmahPage.route()),
        child: plan == null
            ? Row(
                children: [
                  Icon(Icons.flag_circle_rounded, color: glass.accent, size: 36),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text('خطط لختمتك: حدد المدة وسنقسّم وردك اليومي ونذكّرك به',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const Icon(Icons.chevron_left_rounded),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flag_rounded, color: glass.accent),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('ورد الختمة اليوم', style: TextStyle(fontWeight: FontWeight.w900))),
                      Text(
                        plan.isFinished
                            ? 'مكتملة 🎉'
                            : plan.isTodayDone(DateTime.now())
                                ? 'تم ✅'
                                : 'متبقٍ ${ArabicUtils.toArabicDigits(plan.todayRemaining(DateTime.now()))} آية',
                        style: TextStyle(color: glass.accent, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GlassProgressBar(value: plan.progress),
                  const SizedBox(height: 6),
                  Text(
                    'الإنجاز الكلي ${ArabicUtils.toArabicDigits((plan.progress * 100).toStringAsFixed(1))}٪',
                    style: TextStyle(color: glass.onGlassMuted, fontSize: 12.5),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Deterministic "ayah of the day" based on the date.
class _AyahOfTheDay extends StatefulWidget {
  const _AyahOfTheDay();

  @override
  State<_AyahOfTheDay> createState() => _AyahOfTheDayState();
}

class _AyahOfTheDayState extends State<_AyahOfTheDay> {
  late Future<Ayah?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Ayah?> _load() async {
    final repo = context.read<QuranRepository>();
    try {
      await repo.ensureLoaded();
      final g = dailyAyahNumber(DateTime.now(), (n) => repo.ayahByNumber(n)?.text.length ?? 0);
      return repo.ayahByNumber(g);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final font = context.select((SettingsCubit c) => c.state.quranFont);
    return FutureBuilder<Ayah?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const GlassContainer(child: SizedBox(height: 80, child: Center(child: CircularProgressIndicator())));
        }
        final ayah = snap.data;
        if (ayah == null) {
          return GlassContainer(
            onTap: () => setState(() => _future = _load()),
            child: Text(
              'تعذر جلب آية اليوم. اتصل بالإنترنت مرة واحدة أو نزّل المصحف كاملًا من صفحة البحث. اضغط لإعادة المحاولة.',
              style: TextStyle(color: glass.onGlassMuted),
            ),
          );
        }
        return GlassContainer(
          onTap: () => MushafReaderPage.open(context, surah: ayah.surah, ayah: ayah.numberInSurah),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${ayah.text} ${ArabicUtils.ornateAyahMarker(ayah.numberInSurah)}',
                textAlign: TextAlign.center,
                style: font.style(fontSize: 22, height: 2, color: glass.onGlass),
              ),
              const SizedBox(height: 8),
              Text(
                'سورة ${SurahMetadata.surah(ayah.surah).name} • ${ArabicUtils.toArabicDigits(ayah.numberInSurah)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: glass.accent, fontWeight: FontWeight.w800),
              ),
              if (ayah.tafseer.isNotEmpty) ...[
                const Divider(height: 22),
                Text(ayah.tafseer, style: TextStyle(color: glass.onGlassMuted, height: 1.7)),
              ],
            ],
          ),
        );
      },
    );
  }
}
