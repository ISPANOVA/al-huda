import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_themes.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../qibla/presentation/pages/qibla_page.dart';
import '../../domain/prayer_entities.dart';
import '../cubit/prayer_cubit.dart';
import '../widgets/next_prayer_card.dart';
import '../widgets/adhan_settings.dart';
import '../widgets/prayer_calc_settings.dart';

/// Prayer tab: countdown, today's times, method & location controls.
class PrayerTimesPage extends StatelessWidget {
  const PrayerTimesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    HijriCalendar.setLocal('ar');
    final hijri = HijriCalendar.now();
    final gregorian = DateFormat('EEEE d MMMM y', 'ar').format(DateTime.now());

    return BlocBuilder<PrayerCubit, PrayerState>(
      buildWhen: (p, c) =>
          p.today != c.today || p.next != c.next || p.loading != c.loading || p.error != c.error || p.location != c.location,
      builder: (context, state) {
        final cubit = context.read<PrayerCubit>();
        return RefreshIndicator(
          onRefresh: () => cubit.refreshLocation(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('مواقيت الصلاة',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                        Text('${hijri.toFormat('dd MMMM yyyy')} هـ • $gregorian',
                            style: TextStyle(color: glass.onGlassMuted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  GlassIconButton(
                    icon: Icons.explore_rounded,
                    tooltip: 'القبلة',
                    onPressed: () => Navigator.of(context).push(QiblaPage.route()),
                  ),
                  const SizedBox(width: 8),
                  GlassIconButton(
                    icon: Icons.my_location_rounded,
                    tooltip: 'تحديث الموقع',
                    onPressed: () => cubit.refreshLocation(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const NextPrayerCard(),
              if (state.error != null && !state.ready)
                MessageView(
                  icon: Icons.location_off_rounded,
                  title: 'الموقع غير متاح',
                  subtitle: state.error,
                  actionLabel: 'إعادة المحاولة',
                  onAction: () => cubit.refreshLocation(),
                ),
              if (state.ready) ...[
                const GlassSectionTitle('مواقيت اليوم'),
                for (final p in PrayerName.values)
                  _PrayerRow(
                    name: p,
                    time: state.today![p],
                    isNext: state.next!.name == p && state.next!.time.day == state.today!.date.day,
                  ),
                const SizedBox(height: 8),
                const GlassSectionTitle('الأذان والتنبيهات'),
                const AdhanSettingsCard(),
                const SizedBox(height: 8),
                const GlassSectionTitle('إعدادات الحساب'),
                const PrayerCalculationSettings(),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PrayerRow extends StatelessWidget {
  final PrayerName name;
  final DateTime time;
  final bool isNext;

  const _PrayerRow({required this.name, required this.time, required this.isNext});

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
    final passed = time.isBefore(DateTime.now());
    return GlassContainer(
      blur: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      tint: isNext ? glass.accent : null,
      opacity: isNext ? 0.32 : null,
      borderColor: isNext ? glass.accent : null,
      child: Row(
        children: [
          Icon(_icons[name], color: isNext ? glass.onGlass : glass.accent),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              name.nameAr,
              style: TextStyle(
                fontSize: 17,
                fontWeight: isNext ? FontWeight.w900 : FontWeight.w700,
                color: passed && !isNext ? glass.onGlassMuted : glass.onGlass,
              ),
            ),
          ),
          Text(
            ArabicUtils.formatTime(time),
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: passed && !isNext ? glass.onGlassMuted : null),
          ),
        ],
      ),
    );
  }
}
