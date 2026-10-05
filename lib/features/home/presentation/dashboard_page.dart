import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/web_lite.dart';
import '../../../core/data/surah_metadata.dart';
import '../../../core/services/home_widgets.dart';
import '../../../core/theme/app_themes.dart';
import '../../../core/theme/tones.dart';
import '../../../core/utils/arabic_utils.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/noor_ui.dart';
import '../../audio/presentation/cubit/audio_cubit.dart';
import '../../khatmah/presentation/cubit/khatmah_cubit.dart';
import '../../khatmah/presentation/pages/khatmah_page.dart';
import '../../prayer/domain/prayer_entities.dart';
import '../../prayer/presentation/cubit/prayer_cubit.dart';
import '../../prayer/presentation/prayer_tones.dart';
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
    const physics = BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
    if (Adaptive.isWide(context)) {
      // Tablet / computer: the sky, today's prayers and the ayah of the day
      // beside the reading, goals and shortcuts.
      return ListView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 120),
        physics: physics,
        children: [
          MaxWidth(
            maxWidth: 1280,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Rise(0, child: HomeSkyHero(height: 360, onTap: () => onNavigate(3))),
                      const SizedBox(height: 14),
                      _Rise(1, child: TodayPrayersStrip(onTap: () => onNavigate(3))),
                      const NoorSection('آية اليوم'),
                      const _Rise(3, child: _AyahOfTheDay()),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Rise(1, child: _ContinueReading()),
                      const SizedBox(height: 14),
                      const _Rise(2, child: _GoalsRow()),
                      const SizedBox(height: 14),
                      const _SeasonalCards(padding: EdgeInsets.only(bottom: 12)),
                      _Rise(3, child: QuickActionsSection(onNavigate: onNavigate)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (n) {
        if (n.depth == 0) scroll.value = n.metrics.pixels;
        return false;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 130),
        physics: physics,
        children: [
          // The sky runs from edge to edge, under the status bar.
          HomeSkyHero(onTap: () => onNavigate(3), fullBleed: true, height: 350),
          const SizedBox(height: 14),
          _Rise(
            1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TodayPrayersStrip(onTap: () => onNavigate(3)),
            ),
          ),
          const SizedBox(height: 16),
          const _SeasonalCards(),
          const _Rise(2, child: Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: _ContinueReading())),
          const SizedBox(height: 12),
          const _Rise(3, child: Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: _GoalsRow())),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: QuickActionsSection(onNavigate: onNavigate),
          ),
          const NoorSection('آية اليوم'),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: _AyahOfTheDay()),
        ],
      ),
    );
  }

  /// How far the phone home is scrolled (the status-bar strip above it
  /// takes the sky's colour while the sky is in view).
  static final scroll = ValueNotifier<double>(0);
}

/// Phone: the strip behind the status bar, in the colour of the top of the
/// sky so the home's sky reaches the top edge; it fades as the page scrolls.
class HomeSkyStrip extends StatelessWidget {
  const HomeSkyStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PrayerCubit, PrayerState>(
      buildWhen: (p, c) => p.today != c.today || p.next != c.next,
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
        final color = skyColors(sky.phase).first;
        return ValueListenableBuilder<double>(
          valueListenable: DashboardPage.scroll,
          builder: (context, y, _) => ColoredBox(
            color: color.withValues(alpha: 1 - (y / 90).clamp(0.0, 1.0)),
          ),
        );
      },
    );
  }
}

/// Sections rise into place one after another when the home first appears
/// (opacity and position only: cheap on every device).
class _Rise extends StatelessWidget {
  final int order;
  final Widget child;

  const _Rise(this.order, {required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + order * 90),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: child),
      ),
      child: child,
    );
  }
}

// ------------------------------------------------------ today's prayers ---

/// The five prayers of today in a row: those passed fade, the next shines.
class TodayPrayersStrip extends StatelessWidget {
  final VoidCallback? onTap;

  const TodayPrayersStrip({super.key, this.onTap});

  static const _order = [PrayerName.fajr, PrayerName.dhuhr, PrayerName.asr, PrayerName.maghrib, PrayerName.isha];

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return BlocBuilder<PrayerCubit, PrayerState>(
      buildWhen: (p, c) => p.today != c.today || p.next != c.next,
      builder: (context, s) {
        final today = s.today;
        if (today == null) return const SizedBox.shrink();
        final now = DateTime.now();
        return GestureDetector(
          onTap: onTap,
          child: Row(
            children: [
              for (var i = 0; i < _order.length; i++) ...[
                if (i > 0) const SizedBox(width: 7),
                Expanded(
                  child: Builder(builder: (context) {
                    final p = _order[i];
                    final t = today[p];
                    final isNext = s.next?.name == p && s.next!.time.day == t.day;
                    final passed = !isNext && t.isBefore(now);
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: isNext ? p.tone.solid : null,
                        color: isNext ? null : noorSurface(context),
                        border: Border.all(
                          color: isNext
                              ? Colors.white.withValues(alpha: 0.2)
                              : p.tone.mid.withValues(alpha: dark ? 0.32 : 0.4),
                        ),
                      ),
                      child: Opacity(
                        opacity: passed ? 0.5 : 1,
                        child: Column(
                          children: [
                            Text(p.nameOn(t),
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isNext ? Colors.white.withValues(alpha: 0.85) : glass.onGlassMuted,
                                )),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(ArabicUtils.formatTime(t),
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                    color: isNext ? Colors.white : glass.onGlass,
                                  )),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// --------------------------------------------------------------- hero ---

class HomeSkyHero extends StatelessWidget {
  final VoidCallback? onTap;
  final double height;

  /// Edge to edge with only the bottom corners rounded (phone home).
  final bool fullBleed;

  const HomeSkyHero({super.key, this.onTap, this.height = 330, this.fullBleed = false});

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
            height: height,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: fullBleed
                  ? const BorderRadius.vertical(bottom: Radius.circular(36))
                  : BorderRadius.circular(34),
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
                  top: fullBleed ? 10 : 18,
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
                            Text('الهدى',
                                style: TextStyle(
                                    fontFamily: AppFonts.display,
                                    color: Colors.white,
                                    fontSize: fullBleed ? 42 : 36,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                    shadows: const [Shadow(color: Color(0x66F3D58A), blurRadius: 18)])),
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
                  bottom: fullBleed ? 16 : 14,
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

  /// Share of the time between the previous prayer and the next one gone.
  static double _elapsed(PrayerState s) {
    final next = s.next;
    final today = s.today;
    if (next == null || today == null) return 0;
    final now = DateTime.now();
    DateTime? prev;
    for (final t in today.times.values) {
      if (!t.isAfter(now) && (prev == null || t.isAfter(prev))) prev = t;
    }
    // Before Fajr: from last night's Isha (about the same time yesterday).
    prev ??= today[PrayerName.isha].subtract(const Duration(days: 1));
    final span = next.time.difference(prev).inSeconds;
    if (span <= 0) return 0;
    return (1 - s.countdown.inSeconds / span).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final next = state.next;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
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
                                  fontFamily: AppFonts.display,
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25)),
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
                // Time left, inside a ring that fills from the last prayer to
                // the next one.
                NoorRing(
                  value: _elapsed(state),
                  color: glass.accent,
                  track: Colors.white.withValues(alpha: 0.16),
                  size: 72,
                  stroke: 4.5,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(ArabicUtils.formatDuration(state.countdown),
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, height: 1.1)),
                        ),
                      ),
                      Text('متبقٍ', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10.5)),
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
  final EdgeInsetsGeometry padding;

  const _SeasonalCards({this.padding = const EdgeInsets.fromLTRB(14, 0, 14, 12)});

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
            padding: padding,
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
            padding: padding,
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    const tone = Tone.emerald;
    final font = context.select((SettingsCubit c) => c.state.quranFont);
    final last = context.select<BookmarksCubit, AyahRef?>((c) => c.state.lastRead);
    final surah = last?.surah ?? 1;
    final ayah = last?.ayah ?? 1;
    final info = SurahMetadata.surah(surah);
    final percent = SurahMetadata.globalAyah(surah, ayah) / SurahMetadata.totalAyahs;
    return ToneCard(
      tone: tone,
      ornament: true,
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
                colors: [tone.mid.withValues(alpha: 0.45), tone.mid.withValues(alpha: 0.10)],
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
                    style: TextStyle(color: tone.ink(dark), fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: glass.onGlass.withValues(alpha: 0.08),
                  ),
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: percent.clamp(0.02, 1.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), gradient: tone.gradient()),
                      child: const SizedBox.expand(),
                    ),
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
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: tone.gradient()),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.read<AudioCubit>().playSurah(surah, fromAyah: ayah),
                child: const SizedBox.square(
                  dimension: 48,
                  child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                ),
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
  final Tone tone;
  final double value;
  final Widget center;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _GoalTile({
    required this.tone,
    required this.value,
    required this.center,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ToneCard(
      tone: tone,
      radius: 22,
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      onTap: onTap,
      child: Column(
        children: [
          NoorRing(
            value: value,
            color: tone.ink(dark),
            track: tone.mid.withValues(alpha: 0.18),
            size: 58,
            stroke: 5,
            child: IconTheme.merge(data: IconThemeData(color: tone.ink(dark)), child: center),
          ),
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
    final goal = context.select((SettingsCubit c) => c.state.wirdPages);
    final tracker = context.read<WirdTracker>();
    return ListenableBuilder(
      listenable: tracker,
      builder: (context, _) {
        final done = tracker.todayCount;
        if (goal <= 0) {
          return _GoalTile(
            tone: Tone.emerald,
            value: 0,
            center: const Icon(Icons.add_rounded),
            title: 'الورد اليومي',
            subtitle: 'حدّد هدفك',
            onTap: () => showWirdSetup(context),
          );
        }
        final complete = done >= goal;
        return _GoalTile(
          tone: Tone.emerald,
          value: done / goal,
          center: complete
              ? const Icon(Icons.check_rounded)
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
    final plan = context.select((KhatmahCubit c) => c.state.plan);
    final now = DateTime.now();
    return _GoalTile(
      tone: Tone.gold,
      value: plan?.progress ?? 0,
      center: plan == null
          ? const Icon(Icons.flag_rounded)
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
        tone: Tone.amber,
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
