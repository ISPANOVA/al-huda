import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/platform/web_env.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_themes.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/background_patterns.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../audio/domain/reciter.dart';
import '../../../audio/presentation/widgets/mini_player.dart';
import '../../../prayer/presentation/widgets/adhan_settings.dart';
import '../../../prayer/presentation/widgets/prayer_calc_settings.dart';
import '../../../quran/presentation/widgets/ayah_sheets.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';
import 'appearance_page.dart';
import 'about_pages.dart';
import '../../../../core/services/backup_service.dart';
import '../../../../core/services/storage_service.dart';
import 'package:flutter/services.dart';

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
              _AppearanceEntry(settings: s),
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
                    if (!kIsWeb) // reminders are phone notifications
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
              const GlassSectionTitle('النسخ الاحتياطي'),
              const _BackupCard(),
              const GlassSectionTitle('الخصوصية والمصادر'),
              GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.privacy_tip_rounded, color: glass.accent),
                      title: const Text('سياسة الخصوصية'),
                      trailing: const Icon(Icons.chevron_left_rounded),
                      onTap: () => Navigator.of(context).push(PrivacyPage.route()),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.library_books_rounded, color: glass.accent),
                      title: const Text('المصادر والحقوق'),
                      trailing: const Icon(Icons.chevron_left_rounded),
                      onTap: () => Navigator.of(context).push(SourcesPage.route()),
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
                child: Text('النص القرآني والتفسير: alquran.cloud • تلاوات المصحف: Islamic Network • الوسائط والإذاعات: mp3quran.net',
                    textAlign: TextAlign.center, style: TextStyle(color: glass.onGlassMuted, fontSize: 11)),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Export / restore all personal data as one file.
class _BackupCard extends StatefulWidget {
  const _BackupCard();

  @override
  State<_BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends State<_BackupCard> {
  bool _busy = false;

  BackupService get _service => BackupService(context.read<StorageService>());

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      await _service.export();
    } catch (_) {
      if (mounted) showGlassSnack(context, 'تعذر إنشاء النسخة الاحتياطية');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استعادة نسخة احتياطية'),
        content: const Text('ستُستبدل بياناتك الحالية (العلامات، الختمة، الورد، الإحصائيات، الإعدادات) بما في الملف. متابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('اختيار الملف')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final done = await _service.pickAndRestore();
      if (done == true && mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('تمت الاستعادة ✅'),
            content: const Text(kIsWeb
                ? 'ستُعاد تحميل الصفحة الآن لتظهر بياناتك.'
                : 'سيُغلق التطبيق الآن، افتحه مرة أخرى لتظهر بياناتك.'),
            actions: [
              FilledButton(
                  onPressed: () => kIsWeb ? reloadPage() : SystemNavigator.pop(), child: const Text('حسنًا')),
            ],
          ),
        );
      }
    } on FormatException {
      if (mounted) showGlassSnack(context, 'الملف ليس نسخة احتياطية من تطبيق الهدى');
    } catch (_) {
      if (mounted) showGlassSnack(context, 'تعذر قراءة الملف');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_sync_rounded, color: glass.accent, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'احفظ علاماتك وختمتك ووردك وإعداداتك في ملف، واسترجعها على أي جهاز أو بعد إعادة التثبيت.',
                  style: TextStyle(fontSize: 13, height: 1.6, color: glass.onGlassMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_busy)
            const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _export,
                    icon: const Icon(Icons.upload_rounded),
                    label: const Text('نسخ احتياطي'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _restore,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('استعادة'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Single entry that opens the dedicated Appearance page.
class _AppearanceEntry extends StatelessWidget {
  final SettingsState settings;

  const _AppearanceEntry({required this.settings});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final p = AppThemes.palette(settings.themeType);
    final pattern = BgPattern.values[settings.bgPattern.clamp(0, BgPattern.values.length - 1)];
    final mode = switch (settings.themeMode) {
      ThemeMode.light => 'فاتح',
      ThemeMode.dark => 'داكن',
      ThemeMode.system => 'تلقائي',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: GlassContainer(
        padding: EdgeInsets.zero,
        onTap: () => Navigator.of(context).push(AppearancePage.route()),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(colors: glass.backgroundGradient),
                  border: Border.all(color: glass.accent.withValues(alpha: 0.6)),
                ),
                child: CustomPaint(
                  painter: PatternPainter(pattern: pattern, color: glass.accent.withValues(alpha: 0.6), scale: 0.4),
                  child: Center(child: Icon(Icons.palette_rounded, color: glass.accent, size: 28)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('المظهر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text('الألوان والوضع الليلي وزخرفة الخلفية',
                        style: TextStyle(fontSize: 12.5, color: glass.onGlassMuted)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final t in [p.nameAr, mode, pattern.labelAr])
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: glass.accent.withValues(alpha: 0.13),
                            ),
                            child: Text(t,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: glass.accent)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: glass.onGlassMuted),
            ],
          ),
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
