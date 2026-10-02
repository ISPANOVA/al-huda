import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_themes.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/cubit/settings_state.dart';
import '../../domain/adhan_voices.dart';

/// Plays adhan samples from the bundled raw resources (one at a time).
class AdhanPreview {
  AdhanPreview._();

  static AudioPlayer? _player;
  static StreamSubscription<PlayerState>? _sub;

  /// "<voice>|<full>" currently playing, or null.
  static final ValueNotifier<String?> playing = ValueNotifier(null);

  static String key(String voice, bool full) => '$voice|$full';

  static Future<void> toggle(BuildContext context, String voice, bool full) async {
    final k = key(voice, full);
    if (playing.value == k) return stop();
    await stop();
    if (voice == 'default') return;
    final player = _player ??= AudioPlayer();
    _sub ??= player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) stop();
    });
    try {
      playing.value = k;
      await player.setAudioSource(AudioSource.uri(AdhanVoices.previewUri(voice, full: full)));
      await player.play();
    } catch (e) {
      playing.value = null;
      if (context.mounted) showGlassSnack(context, 'تعذر تشغيل الصوت');
    }
  }

  static Future<void> stop() async {
    playing.value = null;
    await _player?.stop();
  }
}

/// Adhan voice, full adhan / takbeers, preview, pre-adhan reminder and the
/// prayers that should alert.
class AdhanSettingsCard extends StatefulWidget {
  const AdhanSettingsCard({super.key});

  @override
  State<AdhanSettingsCard> createState() => _AdhanSettingsCardState();
}

class _AdhanSettingsCardState extends State<AdhanSettingsCard> {
  static const _prayers = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
  static const _minutes = [5, 10, 15, 20, 30];

  @override
  void dispose() {
    AdhanPreview.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (p, c) =>
          p.prayerNotifications != c.prayerNotifications ||
          p.adhanVoice != c.adhanVoice ||
          p.adhanFull != c.adhanFull ||
          p.preAdhanEnabled != c.preAdhanEnabled ||
          p.preAdhanMinutes != c.preAdhanMinutes ||
          p.prayerAlerts != c.prayerAlerts ||
          p.postPrayerAthkar != c.postPrayerAthkar ||
          p.postPrayerMinutes != c.postPrayerMinutes,
      builder: (context, s) {
        final cubit = context.read<SettingsCubit>();
        final glass = GlassTheme.of(context);
        final voice = AdhanVoices.byId(s.adhanVoice);
        final enabled = s.prayerNotifications;
        return GlassContainer(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(Icons.notifications_active_rounded, color: glass.accent),
                title: const Text('الأذان عند دخول وقت الصلاة', style: TextStyle(fontWeight: FontWeight.w700)),
                value: enabled,
                onChanged: cubit.setPrayerNotifications,
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 250),
                crossFadeState: enabled ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                secondChild: const SizedBox(width: double.infinity),
                firstChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('الصلوات التي يؤذَّن لها', style: TextStyle(fontSize: 13, color: glass.onGlassMuted)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < _prayers.length; i++)
                          FilterChip(
                            label: Text(_prayers[i]),
                            selected: s.prayerAlerts[i],
                            showCheckmark: false,
                            avatar: Icon(
                              s.prayerAlerts[i] ? Icons.notifications_rounded : Icons.notifications_off_outlined,
                              size: 18,
                            ),
                            onSelected: (v) => cubit.setPrayerAlert(i, v),
                          ),
                      ],
                    ),
                    const Divider(height: 22),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.record_voice_over_rounded, color: glass.accent),
                      title: const Text('صوت الأذان', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${voice.nameAr} • ${voice.origin}'),
                      trailing: const Icon(Icons.chevron_left_rounded),
                      onTap: () => _pickVoice(context, s),
                    ),
                    if (voice.id != 'default') ...[
                      const SizedBox(height: 4),
                      SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: true, label: Text('الأذان كاملًا'), icon: Icon(Icons.mosque_rounded)),
                          ButtonSegment(value: false, label: Text('التكبيرات فقط'), icon: Icon(Icons.short_text_rounded)),
                        ],
                        selected: {s.adhanFull},
                        onSelectionChanged: (v) => cubit.setAdhanFull(v.first),
                      ),
                      const SizedBox(height: 10),
                      _PreviewButton(voice: voice.id, full: s.adhanFull),
                    ],
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('تجربة التنبيه الحقيقي (بعد ١٠ ثوانٍ)'),
                      onPressed: () => _testAlert(context, s),
                    ),
                    const Divider(height: 22),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(Icons.volunteer_activism_outlined, color: glass.accent),
                      title: const Text('تذكير بأذكار بعد الصلاة', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(s.postPrayerAthkar
                          ? 'بعد الأذان بـ ${ArabicUtils.toArabicDigits(s.postPrayerMinutes)} دقيقة'
                          : 'غير مفعّل'),
                      value: s.postPrayerAthkar,
                      onChanged: cubit.setPostPrayerAthkar,
                    ),
                    if (s.postPrayerAthkar)
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final m in const [5, 10, 15, 20, 30])
                            ChoiceChip(
                              label: Text('${ArabicUtils.toArabicDigits(m)} د'),
                              selected: s.postPrayerMinutes == m,
                              onSelected: (_) => cubit.setPostPrayerMinutes(m),
                            ),
                        ],
                      ),
                    const Divider(height: 22),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(Icons.alarm_rounded, color: glass.accent),
                      title: const Text('تنبيه قبل الأذان', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(s.preAdhanEnabled
                          ? 'قبل الأذان بـ ${ArabicUtils.toArabicDigits(s.preAdhanMinutes)} دقيقة'
                          : 'غير مفعّل'),
                      value: s.preAdhanEnabled,
                      onChanged: cubit.setPreAdhanEnabled,
                    ),
                    if (s.preAdhanEnabled)
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final m in _minutes)
                            ChoiceChip(
                              label: Text('${ArabicUtils.toArabicDigits(m)} د'),
                              selected: s.preAdhanMinutes == m,
                              onSelected: (_) => cubit.setPreAdhanMinutes(m),
                            ),
                        ],
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

  Future<void> _testAlert(BuildContext context, SettingsState s) async {
    final n = context.read<NotificationService>();
    await AdhanPreview.stop();
    final allowed = await n.requestPermissions();
    await n.ensureExactAlarms();
    final voice = AdhanVoices.byId(s.adhanVoice);
    await n.scheduleAdhanTest(voice: voice.id, voiceName: voice.nameAr, full: s.adhanFull);
    if (!context.mounted) return;
    showGlassSnack(
      context,
      allowed
          ? 'سيصلك تنبيه الأذان بعد ١٠ ثوانٍ، يمكنك قفل الشاشة للتجربة'
          : 'فعّل إذن الإشعارات للتطبيق من إعدادات الجهاز ثم أعد المحاولة',
    );
  }

  Future<void> _pickVoice(BuildContext context, SettingsState s) async {
    final cubit = context.read<SettingsCubit>();
    final picked = await showGlassSheet<String>(context, builder: (ctx) {
      final glass = GlassTheme.of(ctx);
      return SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.68,
        child: Column(
          children: [
            Text('اختر صوت الأذان', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('اضغط ▶ للتجربة', style: TextStyle(fontSize: 12, color: glass.onGlassMuted)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final v in AdhanVoices.all)
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      tileColor: v.id == s.adhanVoice ? glass.accent.withValues(alpha: 0.14) : null,
                      leading: v.id == 'default'
                          ? Icon(Icons.notifications_rounded, color: glass.accent)
                          : ValueListenableBuilder<String?>(
                              valueListenable: AdhanPreview.playing,
                              builder: (_, playing, __) {
                                final on = playing == AdhanPreview.key(v.id, s.adhanFull);
                                return IconButton.filledTonal(
                                  icon: Icon(on ? Icons.stop_rounded : Icons.play_arrow_rounded),
                                  onPressed: () => AdhanPreview.toggle(ctx, v.id, s.adhanFull),
                                );
                              },
                            ),
                      title: Text(v.nameAr, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(v.origin),
                      trailing: v.id == s.adhanVoice ? Icon(Icons.check_circle_rounded, color: glass.accent) : null,
                      onTap: () => Navigator.of(ctx).pop(v.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    });
    await AdhanPreview.stop();
    if (picked != null) await cubit.setAdhanVoice(picked);
  }
}

class _PreviewButton extends StatelessWidget {
  final String voice;
  final bool full;

  const _PreviewButton({required this.voice, required this.full});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: AdhanPreview.playing,
      builder: (context, playing, _) {
        final on = playing == AdhanPreview.key(voice, full);
        return OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: Icon(on ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded),
          label: Text(on ? 'إيقاف التجربة' : 'تجربة صوت الأذان'),
          onPressed: () => AdhanPreview.toggle(context, voice, full),
        );
      },
    );
  }
}
