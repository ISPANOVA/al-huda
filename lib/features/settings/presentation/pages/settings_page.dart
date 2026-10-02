import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_themes.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../audio/domain/reciter.dart';
import '../../../audio/presentation/widgets/mini_player.dart';
import '../../../prayer/presentation/widgets/adhan_settings.dart';
import '../../../prayer/presentation/widgets/prayer_calc_settings.dart';
import '../../../quran/presentation/widgets/ayah_sheets.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const SettingsPage());

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'الإعدادات',
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, s) {
          final cubit = context.read<SettingsCubit>();
          final glass = GlassTheme.of(context);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const GlassSectionTitle('المظهر الزجاجي'),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.6,
                children: [
                  for (final t in AppThemeType.values) _ThemeTile(type: t, selected: s.themeType == t),
                ],
              ),
              const SizedBox(height: 12),
              GlassContainer(
                padding: const EdgeInsets.all(8),
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('تلقائي'), icon: Icon(Icons.brightness_auto_rounded)),
                    ButtonSegment(value: ThemeMode.light, label: Text('فاتح'), icon: Icon(Icons.light_mode_rounded)),
                    ButtonSegment(value: ThemeMode.dark, label: Text('داكن'), icon: Icon(Icons.dark_mode_rounded)),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (v) => cubit.setThemeMode(v.first),
                ),
              ),
              if (s.themeType == AppThemeType.custom)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.palette_rounded),
                    label: const Text('تعديل ألواني'),
                    onPressed: () => showCustomColorsSheet(context),
                  ),
                ),
              if (AppThemes.palette(s.themeType).alwaysDark || AppThemes.palette(s.themeType).alwaysLight)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                      s.themeType == AppThemeType.custom
                          ? 'الوضع الفاتح أو الداكن يتحدد تلقائيًا من لون الخلفية الذي اخترته.'
                          : 'هذا الثيم داكن دائمًا بطبيعته.',
                      style: TextStyle(fontSize: 12, color: glass.onGlassMuted),
                      textAlign: TextAlign.center),
                ),
              const GlassSectionTitle('القراءة والخط'),
              GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.text_fields_rounded, color: glass.accent),
                  title: const Text('الخط العثماني، الحجم وتباعد الأسطر'),
                  subtitle: Text(s.quranFont.labelAr),
                  onTap: () => showReaderSettingsSheet(context),
                ),
              ),
              const GlassSectionTitle('التلاوة'),
              GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.record_voice_over_rounded, color: glass.accent),
                      title: const Text('القارئ الافتراضي'),
                      subtitle: Text(Reciters.byId(s.reciterId).nameAr),
                      onTap: () async {
                        final id = await showReciterPicker(context, s.reciterId);
                        if (id != null) await cubit.setReciter(id);
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('متابعة الآية تلقائيًا أثناء التلاوة'),
                      value: s.autoFollowAudio,
                      onChanged: cubit.setAutoFollowAudio,
                    ),
                  ],
                ),
              ),
              const GlassSectionTitle('مواقيت الصلاة'),
              const AdhanSettingsCard(),
              const SizedBox(height: 12),
              const PrayerCalculationSettings(),
              const GlassSectionTitle('التذكيرات'),
              GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('تذكير أذكار الصباح والمساء'),
                      subtitle: const Text('٦:٣٠ صباحًا و٥:٠٠ مساءً'),
                      value: s.athkarReminders,
                      onChanged: cubit.setAthkarReminders,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('الاهتزاز عند التسبيح والأذكار'),
                      value: s.hapticFeedback,
                      onChanged: cubit.setHapticFeedback,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text('${AppConstants.appName} • الإصدار 1.0.0',
                    style: TextStyle(color: glass.onGlassMuted, fontSize: 12)),
              ),
              Center(
                child: Text('النص القرآني والتفسير: alquran.cloud • التلاوات: Islamic Network CDN',
                    textAlign: TextAlign.center, style: TextStyle(color: glass.onGlassMuted, fontSize: 11)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final AppThemeType type;
  final bool selected;

  const _ThemeTile({required this.type, required this.selected});

  @override
  Widget build(BuildContext context) {
    final p = AppThemes.palette(type);
    final dark = Theme.of(context).brightness == Brightness.dark || p.alwaysDark;
    final colors = dark ? p.darkGradient : p.lightGradient;
    return GestureDetector(
      onTap: () async {
        await context.read<SettingsCubit>().setThemeType(type);
        if (type == AppThemeType.custom && context.mounted) showCustomColorsSheet(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(colors: colors, begin: Alignment.topRight, end: Alignment.bottomLeft),
          border: Border.all(color: selected ? p.accent : Colors.white24, width: selected ? 3 : 1),
          boxShadow: selected ? [BoxShadow(color: p.accent.withValues(alpha: 0.5), blurRadius: 16)] : null,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                for (final c in [p.primary, p.secondary, p.accent])
                  Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsetsDirectional.only(end: 4),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: c, border: Border.all(color: Colors.white54)),
                  ),
                const Spacer(),
                if (selected) Icon(Icons.check_circle_rounded, color: p.accent),
              ],
            ),
            Text(
              type == AppThemeType.custom ? '🎨 ${p.nameAr}' : p.nameAr,
              style: TextStyle(fontWeight: FontWeight.w900, color: dark ? Colors.white : const Color(0xFF0E1B17)),
            ),
          ],
        ),
      ),
    );
  }
}


const _swatches = [
  Color(0xFFC9A44C), Color(0xFFE2C275), Color(0xFFB8860B), Color(0xFFD4AF37),
  Color(0xFF1E7A5A), Color(0xFF2E9C78), Color(0xFF12807A), Color(0xFF0E6E69),
  Color(0xFF3B6EA8), Color(0xFF1D5FBF), Color(0xFF5B8CC4), Color(0xFF6C5CE7),
  Color(0xFF8B5CF6), Color(0xFFB0306A), Color(0xFFC0392B), Color(0xFFE67E22),
  Color(0xFF8A5A2B), Color(0xFFA8865A), Color(0xFF7F8C8D), Color(0xFFFFFFFF),
];

const _backgrounds = [
  Color(0xFF000000), Color(0xFF0B0B0B), Color(0xFF121212), Color(0xFF1A1A1A),
  Color(0xFF06110D), Color(0xFF041315), Color(0xFF04070D), Color(0xFF0B1424),
  Color(0xFF15100A), Color(0xFF1B1030), Color(0xFF2A0E14), Color(0xFF263238),
  Color(0xFFFFFFFF), Color(0xFFFBF6EA), Color(0xFFF4F1E6), Color(0xFFEEF3F8),
  Color(0xFFF1F8F7), Color(0xFFF7F0FA), Color(0xFFFDF2F2), Color(0xFFECEFF1),
];

/// Pick the app's three colours: main, accent and background.
Future<void> showCustomColorsSheet(BuildContext context) {
  return showGlassSheet<void>(context, builder: (ctx) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (ctx, s) {
        final cubit = ctx.read<SettingsCubit>();
        final glass = GlassTheme.of(ctx);
        Widget section(String title, String hint, List<Color> colors, int current, ValueChanged<Color> onPick) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(current),
                      border: Border.all(color: glass.onGlass.withValues(alpha: 0.4)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 10),
                child: Text(hint, style: TextStyle(fontSize: 12, color: glass.onGlassMuted)),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in colors)
                    GestureDetector(
                      onTap: () => onPick(c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c,
                          border: Border.all(
                            color: c.toARGB32() == current ? glass.accent : glass.onGlass.withValues(alpha: 0.25),
                            width: c.toARGB32() == current ? 3 : 1,
                          ),
                        ),
                        child: c.toARGB32() == current
                            ? Icon(Icons.check_rounded,
                                size: 20, color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                            : null,
                      ),
                    ),
                ],
              ),
            ],
          );
        }

        return SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.75,
          child: ListView(
            children: [
              Text('ألوان التطبيق',
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text('اختر ثلاثة ألوان ويتلوّن التطبيق كله بها فورًا',
                  textAlign: TextAlign.center, style: TextStyle(color: glass.onGlassMuted)),
              section('اللون الأساسي', 'الأزرار والشريط السفلي والعناصر المختارة', _swatches, s.customPrimary,
                  (c) => cubit.setCustomColors(primary: c)),
              section('اللون المميّز', 'أرقام الآيات والعناوين والأيقونات', _swatches, s.customAccent,
                  (c) => cubit.setCustomColors(accent: c)),
              section('لون الخلفية', 'الألوان الداكنة تجعل التطبيق داكنًا، والفاتحة تجعله فاتحًا', _backgrounds,
                  s.customBackground, (c) => cubit.setCustomColors(background: c)),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: () => cubit.setCustomColors(
                  primary: const Color(0xFFC9A44C),
                  accent: const Color(0xFFE2C275),
                  background: const Color(0xFF000000),
                ),
                child: const Text('إرجاع الألوان الافتراضية'),
              ),
            ],
          ),
        );
      },
    );
  });
}
