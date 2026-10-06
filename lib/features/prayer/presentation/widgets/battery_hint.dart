import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_themes.dart';
import '../../../../core/theme/tones.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';

/// Battery saving on Samsung, Xiaomi, Huawei… can put the app to sleep and
/// hold the adhan back. This finds out whether the app is exempt and shows
/// the user, for their phone's maker, where to exempt it.
class BatteryHint {
  BatteryHint._();

  static const _channel = MethodChannel('alhuda/app');
  static const _doneKey = 'battery_hint_done';
  static const _shownKey = 'battery_hint_shown';

  /// Null until known (and always null on the web).
  static final status = ValueNotifier<({bool exempt, String maker})?>(null);

  /// The user said they already set it (some makers never report it).
  static final done = ValueNotifier<bool>(false);

  /// Makers known to stop apps in the background.
  static const _strict = ['samsung', 'xiaomi', 'redmi', 'poco', 'huawei', 'honor', 'oppo', 'realme', 'oneplus', 'vivo'];

  static Future<void> refresh(StorageService storage) async {
    if (kIsWeb) return;
    done.value = storage.settings.get(_doneKey) == true;
    try {
      final m = await _channel.invokeMapMethod<String, dynamic>('batteryStatus');
      if (m == null) return;
      status.value = (exempt: m['exempt'] == true, maker: (m['maker'] ?? '').toString());
    } catch (_) {}
  }

  static bool get needed {
    final s = status.value;
    return s != null && !s.exempt && !done.value;
  }

  /// Once, after the first adhan setup, on phones known to be strict.
  static Future<void> maybeShowOnce(BuildContext context) async {
    final storage = context.read<StorageService>();
    await refresh(storage);
    final s = status.value;
    if (s == null || !needed || storage.settings.get(_shownKey) == true) return;
    if (!_strict.any(s.maker.contains)) return;
    await storage.settings.put(_shownKey, true);
    if (context.mounted) await showGuide(context);
  }

  static Future<void> _openSettings() async {
    try {
      await _channel.invokeMethod<bool>('openAppSettings');
    } catch (_) {}
  }

  static List<String> _steps(String maker) {
    bool any(List<String> names) => names.any(maker.contains);
    if (any(['xiaomi', 'redmi', 'poco'])) {
      return ['افتح «معلومات التطبيق» من الزر بالأسفل', 'اضغط «توفير البطارية» واختر «بلا قيود»', 'ارجع وفعّل «التشغيل التلقائي»'];
    }
    if (any(['huawei', 'honor'])) {
      return ['افتح الإعدادات ← البطارية ← تشغيل التطبيقات', 'اختر «الهدى» وأوقف «الإدارة التلقائية»', 'فعّل التشغيل التلقائي والتشغيل في الخلفية'];
    }
    if (any(['oppo', 'realme', 'oneplus'])) {
      return ['افتح «معلومات التطبيق» من الزر بالأسفل', 'اضغط «استخدام البطارية»', 'فعّل «السماح بالنشاط في الخلفية»'];
    }
    if (any(['vivo'])) {
      return ['افتح «معلومات التطبيق» من الزر بالأسفل', 'اضغط «البطارية»', 'اختر «السماح باستهلاك عالٍ في الخلفية»'];
    }
    return ['افتح «معلومات التطبيق» من الزر بالأسفل', 'اضغط «البطارية»', 'اختر «غير مقيّد»'];
  }

  static Future<void> showGuide(BuildContext context) {
    final storage = context.read<StorageService>();
    final maker = status.value?.maker ?? '';
    final steps = _steps(maker);
    return showGlassSheet<void>(context, builder: (ctx) {
      final glass = GlassTheme.of(ctx);
      final dark = Theme.of(ctx).brightness == Brightness.dark;
      return SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: ToneIcon(Icons.battery_charging_full_rounded, tone: Tone.emerald, size: 60)),
          const SizedBox(height: 12),
          Text('خلّي الأذان يوصل في وقته',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: AppFonts.display, fontSize: 22, fontWeight: FontWeight.w700, color: glass.onGlass)),
          const SizedBox(height: 6),
          Text(
            'توفير البطارية في هاتفك قد يوقف التطبيق في الخلفية فيتأخر الأذان أو لا يُرفع. استثنِ «الهدى» مرة واحدة:',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.7, color: glass.onGlassMuted),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ToneCard(
                tone: Tone.emerald,
                radius: 18,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: Tone.emerald.gradient()),
                      child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(steps[i],
                          style: TextStyle(fontWeight: FontWeight.w700, height: 1.5, color: glass.onGlass)),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _openSettings,
              icon: const Icon(Icons.settings_rounded),
              label: const Text('فتح معلومات التطبيق', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () async {
              await storage.settings.put(_doneKey, true);
              done.value = true;
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text('تم، استثنيته', style: TextStyle(color: Tone.emerald.ink(dark), fontWeight: FontWeight.w800)),
          ),
        ],
        ),
      );
    });
  }
}

/// On the prayer page while battery saving may still hold the adhan back.
class BatteryBanner extends StatelessWidget {
  const BatteryBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    final enabled = context.select((SettingsCubit c) => c.state.prayerNotifications);
    return ListenableBuilder(
      listenable: Listenable.merge([BatteryHint.status, BatteryHint.done]),
      builder: (context, _) {
        if (!enabled || !BatteryHint.needed) return const SizedBox.shrink();
        final glass = GlassTheme.of(context);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ToneCard(
            tone: Tone.emerald,
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            onTap: () => BatteryHint.showGuide(context),
            child: Row(
              children: [
                const ToneIcon(Icons.battery_alert_rounded, tone: Tone.emerald, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('استثنِ الهدى من توفير البطارية',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5)),
                      Text('حتى لا يتأخر الأذان وهاتفك في وضع السكون',
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
