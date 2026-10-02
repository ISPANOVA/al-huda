import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_themes.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/cubit/settings_state.dart';
import '../../domain/prayer_entities.dart';

/// Calculation method, madhab, manual minute adjustments and alerts.
/// Shared by the prayer times page and the settings page.
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
        return GlassContainer(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.calculate_rounded, color: glass.accent),
                title: const Text('طريقة الحساب', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(kCalculationMethods[s.calcMethod] ?? s.calcMethod),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => _pickMethod(context, s.calcMethod),
              ),
              const Divider(height: 8),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.menu_book_outlined, color: glass.accent, size: 22),
                    const SizedBox(width: 14),
                    const Text('المذهب (لوقت العصر)', style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Wrap(
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
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  s.madhab == 'hanafi'
                      ? 'العصر عندما يصير ظل الشيء مثليه.'
                      : 'العصر عندما يصير ظل الشيء مثله (الجمهور).',
                  style: TextStyle(fontSize: 12, color: glass.onGlassMuted),
                ),
              ),
              const Divider(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.tune_rounded, color: glass.accent),
                title: const Text('تعديل المواقيت يدويًا', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(adjusted ? _adjustSummary(s.prayerAdjustments) : 'بدون تعديل'),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => _editAdjustments(context),
              ),
            ],
          ),
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
              textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final e in kCalculationMethods.entries)
            ListTile(
              title: Text(e.value),
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
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('لمطابقة مواقيت مسجدك أو تقويم بلدك',
                  textAlign: TextAlign.center, style: TextStyle(color: glass.onGlassMuted, fontSize: 12)),
              const SizedBox(height: 8),
              for (var i = 0; i < 6; i++)
                Row(
                  children: [
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
                        style: TextStyle(fontWeight: FontWeight.w800, color: glass.accent),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      onPressed: () => cubit.setPrayerAdjustment(i, s.prayerAdjustments[i] + 1),
                    ),
                  ],
                ),
              TextButton(onPressed: cubit.resetPrayerAdjustments, child: const Text('إعادة الضبط')),
            ],
          );
        },
      ),
    );
  }
}
