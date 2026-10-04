import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/web_lite.dart';
import '../../../core/data/surah_metadata.dart';
import '../../../core/services/home_widgets.dart';
import '../../../core/theme/app_themes.dart';
import '../../../core/utils/arabic_utils.dart';
import '../../../core/widgets/noor_ui.dart';
import '../../audio/presentation/cubit/audio_cubit.dart';
import '../../khatmah/presentation/cubit/khatmah_cubit.dart';
import '../../khatmah/presentation/pages/khatmah_page.dart';
import '../../prayer/domain/prayer_entities.dart';
import '../../prayer/presentation/cubit/prayer_cubit.dart';
import '../../qibla/presentation/pages/qibla_page.dart';
import '../../quran/domain/entities/ayah.dart';
import '../../quran/domain/entities/ayah_ref.dart';
import '../../quran/domain/repositories/quran_repository.dart';
import '../../quran/presentation/cubit/bookmarks_cubit.dart';
import '../../quran/presentation/mushaf/mushaf_reader_page.dart';
import '../../quran/presentation/pages/ayah_image_page.dart';
import '../../settings/presentation/cubit/settings_cubit.dart';
import '../../stats/domain/stats_entities.dart';
import '../../stats/presentation/stats_page.dart';
import '../../wird/wird_card.dart';
import '../../wird/wird_tracker.dart';
import 'quick_actions.dart';
import '../../calendar/calendar_page.dart';
import '../../calendar/islamic_calendar.dart';

/// الرئيسية — a living sky that follows the prayer day, then the user's
/// reading, daily goals, shortcuts and the ayah of the day.
class DashboardPage extends StatelessWidget {
  final ValueChanged<int> onNavigate;

  const DashboardPage({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 130),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: HomeSkyHero(onTap: () => onNavigate(3)),
        ),
        const SizedBox(height: 16),
        const _SeasonalCards(),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: _ContinueReading()),
        const SizedBox(height: 12),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: _GoalsRow()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: QuickActionsSection(onNavigate: onNavigate),
        ),
        const NoorSection('آية اليوم'),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: _AyahOfTheDay()),
      ],
    );
  }
}

// --------------------------------------------------------------- hero ---

class HomeSkyHero extends StatelessWidget {
  final VoidCallback? onTap;

  const HomeSkyHero({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    HijriCalendar.setLocal('ar');
    final hijri = HijriCalendar.now();
    final greg = DateFormat('EEEE d MMMM', 'ar').format(DateTime.now());
    return BlocBuilder<PrayerCubit, PrayerState>(
      builder: (context, s) {
        final today = s.today;
        final sky = skyState(
          now: DateTime.now(),
          fajr: today?[PrayerName.fajr],
          sunrise: today?[PrayerName.sunrise],
          dhuhr: today?[PrayerName.dhuhr],
          maghrib: today?[PrayerName.maghrib],
          isha: today?[PrayerName.isha],
        );
        return GestureDetector(
          onTap: onTap,
          child: Container(
            height: 300,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34),
              boxShadow: liteShadows([
                BoxShadow(
                  color: skyColors(sky.phase)[1].withValues(alpha: 0.45),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ]),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: SkyPainter(phase: sky.phase, t: sky.t, sun: sky.sun, orbitTop: 0.2, horizonAt: 0.68)),
                  ),
                ),
                Positioned(
                  top: 18,
                  left: 18,
                  right: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(skyGreeting(sky.phase),
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
                            const Text('الهدى',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, height: 1.2)),
                            Text('${hijri.toFormat('dd MMMM yyyy')} هـ',
                                style: const TextStyle(
                                    color: Color(0xFFFFE3A3), fontWeight: FontWeight.w800, fontSize: 13.5)),
                            Text(greg, style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12)),
                          ],
                        ),
                      ),
                      NoorIconButton(
                        icon: Icons.explore_rounded,
                        tooltip: 'القبلة',
                        onDark: true,
                        onTap: () => Navigator.of(context).push(QiblaPage.route()),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: _NextPrayerGlass(state: s),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NextPrayerGlass extends StatelessWidget {
  final PrayerState state;

  const _NextPrayerGlass({required this.state});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final next = state.next;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.black.withValues(alpha: 0.38),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: next == null
          ? Row(
              children: [
                const Icon(Icons.location_searching_rounded, color: Colors.white70),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    state.error ?? (state.loading ? 'جارٍ تحديد موقعك لحساب المواقيت…' : 'اضغط لتحديد الموقع'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(next.name.isPrayer ? 'الصلاة القادمة' : 'الشروق',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(next.name.nameOn(next.time),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.2)),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(ArabicUtils.formatTime(next.time),
                                style: const TextStyle(color: Color(0xFFFFE3A3), fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      if (state.location?.city != null)
                        Text(state.location!.city!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11.5)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: glass.accent,
                  ),
                  child: Column(
                    children: [
                      Text(ArabicUtils.formatDuration(state.countdown),
                          style: const TextStyle(
                              color: Colors.black, fontWeight: FontWeight.w900, fontSize: 17, height: 1.1)),
                      const Text('متبقٍ', style: TextStyle(color: Colors.black87, fontSize: 10.5)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// --------------------------------------------------------- seasonal ---

/// Friday reminder (Al-Kahf & salawat) and, in Ramadan, the iftar countdown.
class _SeasonalCards extends StatelessWidget {
  const _SeasonalCards();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final friday = now.weekday == DateTime.friday;
    final ramadan = IslamicCalendar.isRamadan;
    if (!friday && !ramadan) return const SizedBox.shrink();
    return Column(
      children: [
        if (ramadan)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: BlocBuilder<PrayerCubit, PrayerState>(
              buildWhen: (p, c) => p.countdown.inMinutes != c.countdown.inMinutes || p.today != c.today,
              builder: (context, s) {
                final maghrib = s.today?[PrayerName.maghrib];
                final fajr = s.today?[PrayerName.fajr];
                final fasting = maghrib != null && fajr != null && now.isAfter(fajr) && now.isBefore(maghrib);
                return _BannerCard(
                  colors: skyColors(SkyPhase.sunset),
                  icon: Icons.brightness_3_rounded,
                  title: 'رمضان كريم',
                  subtitle: fasting
                      ? 'باقي على الإفطار ${ArabicUtils.formatDuration(maghrib.difference(now), withSeconds: false)}'
                      : 'الإمساكية ومواعيد السحور والإفطار',
                  onTap: () => Navigator.of(context).push(ImsakiyaPage.route()),
                );
              },
            ),
          ),
        if (friday)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: _BannerCard(
              colors: const [Color(0xFF0B2A24), Color(0xFF1E5E4E), Color(0xFFC9A44C)],
              icon: Icons.mosque_rounded,
              title: 'جمعة مباركة',
              subtitle: 'اقرأ سورة الكهف، وأكثر من الصلاة على النبي ﷺ',
              onTap: () => MushafReaderPage.open(context, surah: 18, ayah: 1),
            ),
          ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  final List<Color> colors;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BannerCard({
    required this.colors,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: colors),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFFFE3A3), size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 12.5)),
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

// --------------------------------------------------------- reading ---

class _ContinueReading extends StatelessWidget {
  const _ContinueReading();

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final font = context.select((SettingsCubit c) => c.state.quranFont);
    final last = context.select<BookmarksCubit, AyahRef?>((c) => c.state.lastRead);
    final surah = last?.surah ?? 1;
    final ayah = last?.ayah ?? 1;
    final info = SurahMetadata.surah(surah);
    final percent = SurahMetadata.globalAyah(surah, ayah) / SurahMetadata.totalAyahs;
    return NoorCard(
      padding: const EdgeInsets.all(12),
      onTap: () => MushafReaderPage.open(context, surah: surah, ayah: ayah),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            height: 84,
            child: ArchCard(
              archHeight: 0.3,
              padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [glass.accent.withValues(alpha: 0.35), glass.accent.withValues(alpha: 0.08)],
              ),
              child: FittedBox(
                child: Text(info.name, style: font.style(fontSize: 26, height: 1.4, color: glass.onGlass)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(last == null ? 'ابدأ رحلتك مع القرآن' : 'تابع من حيث توقفت',
                    style: TextStyle(color: glass.onGlassMuted, fontSize: 12.5)),
                const SizedBox(height: 2),
                Text('سورة ${info.name}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                Text('الآية ${ArabicUtils.toArabicDigits(ayah)} • ${info.revelationAr}',
                    style: TextStyle(color: glass.accent, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 6,
                    color: glass.accent,
                    backgroundColor: glass.onGlass.withValues(alpha: 0.08),
                  ),
                ),
                const SizedBox(height: 4),
                Text('${ArabicUtils.toArabicDigits((percent * 100).toStringAsFixed(1))}٪ من المصحف',
                    style: TextStyle(fontSize: 11, color: glass.onGlassMuted)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: glass.accent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.read<AudioCubit>().playSurah(surah, fromAyah: ayah),
              child: const SizedBox.square(
                dimension: 46,
                child: Icon(Icons.play_arrow_rounded, color: Colors.black, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- goals ---

class _GoalsRow extends StatelessWidget {
  const _GoalsRow();

  @override
  Widget build(BuildContext context) {
    return const IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _WirdTile()),
          SizedBox(width: 10),
          Expanded(child: _KhatmahTile()),
          SizedBox(width: 10),
          Expanded(child: _StreakTile()),
        ],
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  final double value;
  final Widget center;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _GoalTile({
    required this.value,
    required this.center,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return NoorCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      onTap: onTap,
      child: Column(
        children: [
          NoorRing(value: value, color: glass.accent, size: 58, stroke: 5, child: center),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          Text(subtitle,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, height: 1.3, color: glass.onGlassMuted)),
        ],
      ),
    );
  }
}

class _WirdTile extends StatelessWidget {
  const _WirdTile();

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final goal = context.select((SettingsCubit c) => c.state.wirdPages);
    final tracker = context.read<WirdTracker>();
    return ListenableBuilder(
      listenable: tracker,
      builder: (context, _) {
        final done = tracker.todayCount;
        if (goal <= 0) {
          return _GoalTile(
            value: 0,
            center: Icon(Icons.add_rounded, color: glass.accent),
            title: 'الورد اليومي',
            subtitle: 'حدّد هدفك',
            onTap: () => showWirdSetup(context),
          );
        }
        final complete = done >= goal;
        return _GoalTile(
          value: done / goal,
          center: complete
              ? Icon(Icons.check_rounded, color: glass.accent)
              : Text('${ArabicUtils.toArabicDigits(done)}/${ArabicUtils.toArabicDigits(goal)}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          title: 'وردي',
          subtitle: complete ? 'أتممته اليوم' : 'صفحات اليوم',
          onTap: () {
            final page = context.read<BookmarksCubit>().lastPage ?? 1;
            MushafReaderPage.open(context, page: page);
          },
        );
      },
    );
  }
}

class _KhatmahTile extends StatelessWidget {
  const _KhatmahTile();

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final plan = context.select((KhatmahCubit c) => c.state.plan);
    final now = DateTime.now();
    return _GoalTile(
      value: plan?.progress ?? 0,
      center: plan == null
          ? Icon(Icons.flag_rounded, color: glass.accent)
          : Text('${ArabicUtils.toArabicDigits((plan.progress * 100).round())}٪',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
      title: 'الختمة',
      subtitle: plan == null
          ? 'خطّط لختمتك'
          : plan.isFinished
              ? 'مكتملة 🎉'
              : plan.isTodayDone(now)
                  ? 'ورد اليوم تم'
                  : 'باقي ${ArabicUtils.toArabicDigits(plan.todayRemaining(now))} آية',
      onTap: () => Navigator.of(context).push(KhatmahPage.route()),
    );
  }
}

class _StreakTile extends StatelessWidget {
  const _StreakTile();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StatsCubit, StatsSummary>(
      builder: (context, s) => _GoalTile(
        value: (s.currentStreak / 7).clamp(0.0, 1.0),
        center: Text('🔥${ArabicUtils.toArabicDigits(s.currentStreak)}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
        title: 'المداومة',
        subtitle: 'أيام متتالية',
        onTap: () => Navigator.of(context).push(StatsPage.route()),
      ),
    );
  }
}

// ---------------------------------------------------- ayah of the day ---

class _AyahOfTheDay extends StatefulWidget {
  const _AyahOfTheDay();

  @override
  State<_AyahOfTheDay> createState() => _AyahOfTheDayState();
}

class _AyahOfTheDayState extends State<_AyahOfTheDay> {
  late Future<Ayah?> _future = _load();

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
          return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
        }
        final ayah = snap.data;
        if (ayah == null) {
          return NoorCard(
            onTap: () => setState(() => _future = _load()),
            child: Text('تعذر جلب آية اليوم، اضغط لإعادة المحاولة.', style: TextStyle(color: glass.onGlassMuted)),
          );
        }
        return GestureDetector(
          onTap: () => MushafReaderPage.open(context, surah: ayah.surah, ayah: ayah.numberInSurah),
          child: ArchCard(
            archHeight: 0.08,
            padding: const EdgeInsets.fromLTRB(22, 34, 22, 14),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [glass.accent.withValues(alpha: 0.16), glass.accent.withValues(alpha: 0.02)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${ayah.text} ${ArabicUtils.ornateAyahMarker(ayah.numberInSurah)}',
                  textAlign: TextAlign.center,
                  style: font.style(fontSize: 23, height: 2.0, color: glass.onGlass),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 24, height: 1, color: glass.accent),
                    const SizedBox(width: 8),
                    Text(
                      'سورة ${SurahMetadata.surah(ayah.surah).name} • ${ArabicUtils.toArabicDigits(ayah.numberInSurah)}',
                      style: TextStyle(color: glass.accent, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 8),
                    Container(width: 24, height: 1, color: glass.accent),
                  ],
                ),
                if (ayah.tafseer.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(ayah.tafseer,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: glass.onGlassMuted, height: 1.7, fontSize: 13.5)),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () => context.read<AudioCubit>().playAyahs(ayah.surah, ayah.numberInSurah, ayah.numberInSurah),
                      icon: Icon(Icons.volume_up_rounded, color: glass.accent),
                      label: Text('استماع', style: TextStyle(color: glass.accent, fontWeight: FontWeight.w800)),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(AyahImagePage.route(ayah)),
                      icon: Icon(Icons.ios_share_rounded, color: glass.accent),
                      label: Text('مشاركة', style: TextStyle(color: glass.accent, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
