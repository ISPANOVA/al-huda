import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/web_lite.dart';
import '../../../../core/theme/app_themes.dart';
import '../../../../core/theme/tones.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/noor_ui.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../qibla/presentation/pages/qibla_page.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../domain/adhan_voices.dart';
import '../../domain/prayer_entities.dart';
import '../cubit/prayer_cubit.dart';
import '../prayer_tones.dart';
import '../widgets/adhan_settings.dart';
import '../widgets/prayer_calc_settings.dart';

/// الصلاة — the sun's path through today's prayers, a timeline of the
/// times, and a single entry to the adhan & calculation settings.
class PrayerTimesPage extends StatelessWidget {
  const PrayerTimesPage({super.key});

  @override
  Widget build(BuildContext context) {
    HijriCalendar.setLocal('ar');
    final hijri = HijriCalendar.now();
    final gregorian = DateFormat('EEEE d MMMM', 'ar').format(DateTime.now());
    return BlocBuilder<PrayerCubit, PrayerState>(
      buildWhen: (p, c) =>
          p.today != c.today || p.next != c.next || p.loading != c.loading || p.error != c.error || p.location != c.location,
      builder: (context, state) {
        final cubit = context.read<PrayerCubit>();
        return RefreshIndicator(
          onRefresh: () => cubit.refreshLocation(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 6, 0, 130),
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            children: [
              NoorPageHeader(
                'الصلاة',
                tone: Tone.sapphire,
                subtitle: '${hijri.toFormat('dd MMMM yyyy')} هـ • $gregorian',
                actions: [
                  NoorIconButton(
                    icon: Icons.explore_rounded,
                    tooltip: 'القبلة',
                    onTap: () => Navigator.of(context).push(QiblaPage.route()),
                  ),
                  NoorIconButton(
                    icon: Icons.tune_rounded,
                    tooltip: 'إعدادات الأذان',
                    onTap: () => Navigator.of(context).push(PrayerSettingsPage.route()),
                  ),
                ],
              ),
              if (!state.ready)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: state.error != null
                      ? MessageView(
                          icon: Icons.location_off_rounded,
                          title: 'الموقع غير متاح',
                          subtitle: state.error,
                          actionLabel: 'إعادة المحاولة',
                          onAction: () => cubit.refreshLocation(),
                        )
                      : const SizedBox(height: 240, child: Center(child: CircularProgressIndicator())),
                ),
              if (state.ready) ...[
                const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: _SunPathHero()),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: _Timeline(state: state),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: _LocationCard(state: state, onRefresh: () => cubit.refreshLocation()),
                ),
                const SizedBox(height: 12),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: _SettingsEntry()),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- hero ---

class _SunPathHero extends StatelessWidget {
  const _SunPathHero();

  static const _order = [
    PrayerName.fajr,
    PrayerName.sunrise,
    PrayerName.dhuhr,
    PrayerName.asr,
    PrayerName.maghrib,
    PrayerName.isha,
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PrayerCubit, PrayerState>(
      builder: (context, s) {
        final today = s.today!;
        final next = s.next!;
        final sunrise = today[PrayerName.sunrise];
        final maghrib = today[PrayerName.maghrib];
        double pos(DateTime t) {
          if (!t.isAfter(sunrise)) return t == sunrise ? 0.08 : 0.0;
          if (!t.isBefore(maghrib)) return t == maghrib ? 0.92 : 1.0;
          return 0.08 + 0.84 * t.difference(sunrise).inSeconds / maghrib.difference(sunrise).inSeconds;
        }

        final markers = [for (final p in _order) pos(today[p])];
        final sky = skyState(
          now: DateTime.now(),
          fajr: today[PrayerName.fajr],
          sunrise: sunrise,
          dhuhr: today[PrayerName.dhuhr],
          maghrib: maghrib,
          isha: today[PrayerName.isha],
        );
        final t = sky.sun && sky.phase != SkyPhase.dawn ? 0.08 + 0.84 * sky.t : sky.t;
        final hi = next.time.day == today.date.day ? _order.indexOf(next.name) : 0;
        return Container(
          height: 320,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            boxShadow: liteShadows([
              BoxShadow(color: skyColors(sky.phase)[1].withValues(alpha: 0.45), blurRadius: 30, offset: const Offset(0, 12)),
            ]),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: SkyPainter(
                      phase: sky.phase,
                      t: t,
                      sun: sky.sun,
                      markers: markers,
                      highlighted: hi,
                      orbitTop: 0.44,
                      horizonAt: 0.86,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Text(next.name.isPrayer ? 'باقي على صلاة ${next.name.nameOn(next.time)}' : 'باقي على الشروق',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w700)),
                    Text(
                      ArabicUtils.formatDuration(s.countdown),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.black.withValues(alpha: 0.3),
                      ),
                      child: Text('${next.name.nameOn(next.time)} • ${ArabicUtils.formatTime(next.time)}',
                          style: const TextStyle(color: Color(0xFFFFE3A3), fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------ timeline ---

class _Timeline extends StatelessWidget {
  final PrayerState state;

  const _Timeline({required this.state});

  static const _icons = {
    PrayerName.fajr: Icons.nights_stay_rounded,
    PrayerName.sunrise: Icons.wb_twilight_rounded,
    PrayerName.dhuhr: Icons.wb_sunny_rounded,
    PrayerName.asr: Icons.sunny_snowing,
    PrayerName.maghrib: Icons.wb_twighlight,
    PrayerName.isha: Icons.dark_mode_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final today = state.today!;
    final next = state.next!;
    final now = DateTime.now();
    final alerts = context.select((SettingsCubit c) => c.state.prayerAlerts);
    final enabled = context.select((SettingsCubit c) => c.state.prayerNotifications);
    final sunrise = context.select((SettingsCubit c) => c.state.sunriseAlert);
    final list = PrayerName.values;
    return NoorCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
      child: Column(
        children: [
          for (var i = 0; i < list.length; i++)
            _row(
              context,
              glass,
              name: list[i],
              time: today[list[i]],
              isNext: next.name == list[i] && next.time.day == today.date.day,
              passed: today[list[i]].isBefore(now),
              first: i == 0,
              last: i == list.length - 1,
              alert: list[i] == PrayerName.sunrise ? sunrise : enabled && _alertOn(alerts, list[i]),
              onToggleAlert: () => _toggle(context, list[i], enabled, alerts, sunrise),
            ),
        ],
      ),
    );
  }

  void _toggle(BuildContext context, PrayerName p, bool enabled, List<bool> alerts, bool sunrise) {
    final cubit = context.read<SettingsCubit>();
    if (p == PrayerName.sunrise) {
      cubit.setSunriseAlert(!sunrise);
      showGlassSnack(
        context,
        sunrise ? 'تم إيقاف تنبيه الشروق' : 'تم تفعيل تنبيه الشروق',
        icon: sunrise ? Icons.notifications_off_rounded : Icons.wb_twilight_rounded,
      );
      return;
    }
    final idx = PrayerName.values.where((e) => e.isPrayer).toList().indexOf(p);
    final on = enabled && _alertOn(alerts, p);
    if (!enabled) cubit.setPrayerNotifications(true);
    cubit.setPrayerAlert(idx, !on);
    showGlassSnack(
      context,
      on ? 'تم إيقاف أذان ${p.nameAr}' : 'تم تفعيل أذان ${p.nameAr} في موعده',
      icon: on ? Icons.notifications_off_rounded : Icons.notifications_active_rounded,
    );
  }

  bool _alertOn(List<bool> alerts, PrayerName p) {
    final idx = PrayerName.values.where((e) => e.isPrayer).toList().indexOf(p);
    return idx >= 0 && idx < alerts.length && alerts[idx];
  }

  Widget _row(
    BuildContext context,
    GlassTheme glass, {
    required PrayerName name,
    required DateTime time,
    required bool isNext,
    required bool passed,
    required bool first,
    required bool last,
    required bool alert,
    required VoidCallback onToggleAlert,
  }) {
    final muted = passed && !isNext;
    final friday = name == PrayerName.dhuhr && time.weekday == DateTime.friday;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tone = name.tone;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Expanded(
                  child: Container(width: 2, color: first ? Colors.transparent : tone.mid.withValues(alpha: 0.35)),
                ),
                Container(
                  width: isNext ? 40 : 32,
                  height: isNext ? 40 : 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: muted ? glass.onGlass.withValues(alpha: 0.06) : null,
                    gradient: muted ? null : tone.gradient(),
                    boxShadow: isNext && !kIsWeb ? [BoxShadow(color: tone.mid.withValues(alpha: 0.55), blurRadius: 14)] : null,
                  ),
                  child: Icon(
                    muted ? Icons.check_rounded : _icons[name],
                    size: isNext ? 22 : 17,
                    color: muted ? glass.onGlassMuted : Colors.white,
                  ),
                ),
                Expanded(
                  child: Container(width: 2, color: last ? Colors.transparent : tone.mid.withValues(alpha: 0.35)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(vertical: 5),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: isNext
                    ? LinearGradient(colors: [tone.mid.withValues(alpha: 0.30), tone.mid.withValues(alpha: 0.06)])
                    : null,
                border: isNext ? Border.all(color: tone.mid.withValues(alpha: 0.7)) : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.nameOn(time),
                          style: TextStyle(
                            fontSize: isNext ? 19 : 16.5,
                            fontWeight: isNext ? FontWeight.w900 : FontWeight.w800,
                            color: muted ? glass.onGlassMuted : glass.onGlass,
                          ),
                        ),
                        if (isNext || friday)
                          Text(
                            [
                              if (isNext) 'بعد ${ArabicUtils.formatDuration(state.countdown, withSeconds: false)}',
                              if (friday) 'اقرأ سورة الكهف',
                            ].join(' • '),
                            style: TextStyle(fontSize: 12, color: tone.ink(dark), fontWeight: FontWeight.w700),
                          ),
                      ],
                    ),
                  ),
                  // Fixed-width columns so times and bells line up row to row.
                  SizedBox(
                    width: 84,
                    child: Text(
                      ArabicUtils.formatTime(time),
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: isNext ? 18 : 16.5,
                        fontWeight: FontWeight.w900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: muted ? glass.onGlassMuted : (isNext ? tone.ink(dark) : glass.onGlass),
                      ),
                    ),
                  ),
                  // The browser can't ring at prayer time: no bells there.
                  if (!kIsWeb) ...[
                  const SizedBox(width: 6),
                  SizedBox.square(
                    dimension: 38,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: alert ? 'إيقاف التنبيه' : 'تشغيل التنبيه',
                      onPressed: onToggleAlert,
                      icon: Icon(
                        alert ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                        size: 20,
                        color: alert ? tone.ink(dark) : glass.onGlassMuted.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------- bottom cards ---

class _LocationCard extends StatelessWidget {
  final PrayerState state;
  final VoidCallback onRefresh;

  const _LocationCard({required this.state, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return NoorCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          const ToneIcon(Icons.place_rounded, tone: Tone.sapphire, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.location?.city ?? 'موقعك الحالي', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('اسحب للأسفل أو اضغط للتحديث', style: TextStyle(fontSize: 11.5, color: glass.onGlassMuted)),
              ],
            ),
          ),
          state.loading
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox.square(
                      dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: glass.accent)),
                )
              : IconButton(onPressed: onRefresh, icon: Icon(Icons.my_location_rounded, color: glass.accent)),
        ],
      ),
    );
  }
}

class _SettingsEntry extends StatelessWidget {
  const _SettingsEntry();

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final s = context.watch<SettingsCubit>().state;
    final voice = AdhanVoices.byId(s.adhanVoice);
    final chips = [
      s.prayerNotifications ? 'الأذان مفعّل' : 'الأذان متوقف',
      voice.nameAr,
      s.adhanAlwaysPlay ? 'يعمل في الصامت' : 'حسب وضع الهاتف',
    ];
    return NoorCard(
      onTap: () => Navigator.of(context).push(PrayerSettingsPage.route()),
      child: Row(
        children: [
          const ToneIcon(Icons.campaign_rounded, tone: Tone.sapphire, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الأذان والتنبيهات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final c in chips)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Tone.sapphire.mid.withValues(alpha: 0.16),
                        ),
                        child: Text(c,
                            style: TextStyle(
                                fontSize: 11,
                                color: Tone.sapphire.ink(Theme.of(context).brightness == Brightness.dark),
                                fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_left_rounded, color: glass.onGlassMuted),
        ],
      ),
    );
  }
}

/// Adhan voice / alerts and calculation method, on their own page.
class PrayerSettingsPage extends StatelessWidget {
  const PrayerSettingsPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const PrayerSettingsPage());

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'الأذان والمواقيت',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: const [
          NoorSection('الأذان والتنبيهات'),
          AdhanSettingsCard(),
          NoorSection('طريقة الحساب'),
          PrayerCalculationSettings(),
        ],
      ),
    );
  }
}
