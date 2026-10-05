import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_themes.dart';
import '../../../../core/theme/tones.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../cubit/prayer_cubit.dart';

/// Explains why the adhan needs «المنبّهات والتذكيرات» and then opens the
/// system screen to allow it. Does nothing when it is already allowed.
Future<void> askExactAlarms(BuildContext context) async {
  final n = context.read<NotificationService>();
  if (kIsWeb || await n.canScheduleExact()) return;
  if (!context.mounted) return;
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final glass = GlassTheme.of(ctx);
      return AlertDialog(
        icon: const ToneIcon(Icons.alarm_on_rounded, tone: Tone.sapphire, size: 56),
        title: const Text('ليُرفع الأذان في وقته تمامًا', textAlign: TextAlign.center),
        content: Text(
          'اسمح للتطبيق بـ «المنبّهات والتذكيرات» في الصفحة التالية، حتى يُرفع الأذان في موعده بالدقيقة '
          'حتى مع توفير البطارية. بدونه قد يتأخر الأذان بضع دقائق.',
          textAlign: TextAlign.center,
          style: TextStyle(height: 1.7, color: glass.onGlassMuted),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لاحقًا')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تفعيل')),
        ],
      );
    },
  );
  if (go != true || !context.mounted) return;
  final prayer = context.read<PrayerCubit>();
  if (await n.ensureExactAlarms()) prayer.reschedule();
}

/// A hint on the prayer page while exact alarms are not allowed (the adhan
/// may then come a few minutes late).
class ExactAlarmBanner extends StatelessWidget {
  const ExactAlarmBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    final enabled = context.select((SettingsCubit c) => c.state.prayerNotifications);
    return ValueListenableBuilder<bool>(
      valueListenable: NotificationService.exactAllowed,
      builder: (context, allowed, _) {
        if (allowed || !enabled) return const SizedBox.shrink();
        final glass = GlassTheme.of(context);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ToneCard(
            tone: Tone.amber,
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            onTap: () => askExactAlarms(context),
            child: Row(
              children: [
                const ToneIcon(Icons.alarm_add_rounded, tone: Tone.amber, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('فعّل المنبّهات ليُرفع الأذان في وقته',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5)),
                      Text('بدونها قد يتأخر الأذان بضع دقائق',
                          style: TextStyle(fontSize: 12, color: glass.onGlassMuted)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_left_rounded, color: glass.onGlassMuted),
              ],
            ),
          ),
        );
      },
    );
  }
}
