import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_themes.dart';
import '../../../../core/theme/tones.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/noor_ui.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/cubit/settings_state.dart';
import '../../domain/prayer_entities.dart';
import '../prayer_tones.dart';

/// Calculation method, madhab and manual minute adjustments, under its own
/// «طريقة الحساب» heading (shown on the adhan & times settings page).
class PrayerCalculationSettings extends StatelessWidget {
  const PrayerCalculationSettings({super.key});

  static const _prayerLabels = ['الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء'];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (p, c) =>
          p.calcMethod != c.calcMethod ||
          p.madhab != c.madhab ||
          p.prayerNotifications != c.prayerNotifications ||
          p.prayerAdjustments != c.prayerAdjustments,
      builder: (context, s) {
        final cubit = context.read<SettingsCubit>();
        final glass = GlassTheme.of(context);
        final adjusted = s.prayerAdjustments.any((m) => m != 0);
        final divider = Divider(height: 1, indent: 70, color: glass.onGlass.withValues(alpha: 0.08));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const GlassSectionTitle('طريقة الحساب', tone: Tone.sapphire),
            NoorCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CalcRow(
                    icon: Icons.calculate_rounded,
                    tone: Tone.sapphire,
                    title: 'طريقة الحساب',
                    subtitle: kCalculationMethods[s.calcMethod] ?? s.calcMethod,
                    onTap: () => _pickMethod(context, s.calcMethod),
                  ),
                  divider,
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const ToneIcon(Icons.menu_book_rounded, tone: Tone.teal, size: 42),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('المذهب (لوقت العصر)',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: glass.onGlass)),
                                  Text(
                                    s.madhab == 'hanafi'
                                        ? 'العصر عندما يصير ظل الشيء مثليه.'
                                        : 'العصر عندما يصير ظل الشيء مثله (الجمهور).',
                                    style: TextStyle(fontSize: 12, height: 1.45, color: glass.onGlassMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 56, top: 10),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              for (final e in kMadhabs.entries)
                                ChoiceChip(
                                  label: Text(e.value),
                                  selected: s.madhab == e.key,
                                  onSelected: (_) => cubit.setMadhab(e.key),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  divider,
                  _CalcRow(
                    icon: Icons.tune_rounded,
                    tone: Tone.coral,
                    title: 'تعديل المواقيت يدويًا',
                    subtitle: adjusted ? _adjustSummary(s.prayerAdjustments) : 'بدون تعديل',
                    onTap: () => _editAdjustments(context),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _adjustSummary(List<int> adj) {
    final parts = <String>[];
    for (var i = 0; i < adj.length; i++) {
      if (adj[i] != 0) {
        parts.add('${_prayerLabels[i]} ${adj[i] > 0 ? '+' : '−'}${ArabicUtils.toArabicDigits(adj[i].abs())}');
      }
    }
    return parts.join(' • ');
  }

  Future<void> _pickMethod(BuildContext context, String current) async {
    final glass = GlassTheme.of(context);
    final picked = await showGlassSheet<String>(
      context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          Text('طريقة حساب المواقيت',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: AppFonts.display, fontSize: 20, fontWeight: FontWeight.w700, color: glass.onGlass)),
          const SizedBox(height: 8),
          for (final e in kCalculationMethods.entries)
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              tileColor: e.key == current ? Tone.sapphire.mid.withValues(alpha: 0.16) : null,
              title: Text(e.value,
                  style: TextStyle(fontWeight: e.key == current ? FontWeight.w800 : FontWeight.w500)),
              trailing: e.key == current ? Icon(Icons.check_circle_rounded, color: glass.accent) : null,
              onTap: () => Navigator.pop(ctx, e.key),
            ),
        ],
      ),
    );
    if (picked != null && context.mounted) await context.read<SettingsCubit>().setCalcMethod(picked);
  }

  Future<void> _editAdjustments(BuildContext context) {
    return showGlassSheet<void>(
      context,
      builder: (ctx) => BlocBuilder<SettingsCubit, SettingsState>(
        builder: (ctx, s) {
          final cubit = ctx.read<SettingsCubit>();
          final glass = GlassTheme.of(ctx);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('تعديل المواقيت بالدقائق',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: AppFonts.display, fontSize: 20, fontWeight: FontWeight.w700, color: glass.onGlass)),
              const SizedBox(height: 4),
              Text('لمطابقة مواقيت مسجدك أو تقويم بلدك',
                  textAlign: TextAlign.center, style: TextStyle(color: glass.onGlassMuted, fontSize: 12)),
              const SizedBox(height: 8),
              for (var i = 0; i < 6; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsetsDirectional.only(start: 4, end: 10),
                        decoration: BoxDecoration(shape: BoxShape.circle, gradient: PrayerName.values[i].tone.gradient()),
                      ),
                      Expanded(child: Text(_prayerLabels[i], style: const TextStyle(fontWeight: FontWeight.w700))),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                        onPressed: () => cubit.setPrayerAdjustment(i, s.prayerAdjustments[i] - 1),
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(
                          '${s.prayerAdjustments[i] > 0 ? '+' : s.prayerAdjustments[i] < 0 ? '−' : ''}${ArabicUtils.toArabicDigits(s.prayerAdjustments[i].abs())} د',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: AppFonts.display,
                              fontWeight: FontWeight.w700,
                              color: s.prayerAdjustments[i] == 0
                                  ? glass.onGlassMuted
                                  : PrayerName.values[i].tone.ink(Theme.of(ctx).brightness == Brightness.dark)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        onPressed: () => cubit.setPrayerAdjustment(i, s.prayerAdjustments[i] + 1),
                      ),
                    ],
                  ),
                ),
              TextButton(onPressed: cubit.resetPrayerAdjustments, child: const Text('إعادة الضبط')),
            ],
          );
        },
      ),
    );
  }
}

/// A row of the calculation card: coloured icon, title, value and chevron.
class _CalcRow extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CalcRow({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            ToneIcon(icon, tone: tone, size: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: glass.onGlass)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w700, color: tone.ink(dark))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_left_rounded, color: glass.onGlassMuted),
          ],
        ),
      ),
    );
  }
}
