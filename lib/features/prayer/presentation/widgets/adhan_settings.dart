import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/services/adhan_native.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_themes.dart';
import '../../../../core/theme/tones.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/noor_ui.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/cubit/settings_state.dart';
import '../../domain/adhan_voices.dart';
import '../../domain/prayer_entities.dart';
import '../prayer_tones.dart';

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
/// prayers that should alert — laid out as titled sections: the adhan
/// itself, the prayers, how it behaves on a silent phone, and reminders.
class AdhanSettingsCard extends StatefulWidget {
  const AdhanSettingsCard({super.key});

  @override
  State<AdhanSettingsCard> createState() => _AdhanSettingsCardState();
}

class _AdhanSettingsCardState extends State<AdhanSettingsCard> {
  /// The five prayers in the order of `prayerAlerts`.
  static const _alertPrayers = [PrayerName.fajr, PrayerName.dhuhr, PrayerName.asr, PrayerName.maghrib, PrayerName.isha];
  static const _minutes = [5, 10, 15, 20, 30];

  @override
  void dispose() {
    AdhanPreview.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [GlassSectionTitle('الأذان', tone: Tone.sapphire), _WebAdhanNotice()],
      );
    }
    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (p, c) =>
          p.prayerNotifications != c.prayerNotifications ||
          p.adhanVoice != c.adhanVoice ||
          p.adhanFull != c.adhanFull ||
          p.preAdhanEnabled != c.preAdhanEnabled ||
          p.preAdhanMinutes != c.preAdhanMinutes ||
          p.prayerAlerts != c.prayerAlerts ||
          p.postPrayerAthkar != c.postPrayerAthkar ||
          p.postPrayerMinutes != c.postPrayerMinutes ||
          p.adhanAlwaysPlay != c.adhanAlwaysPlay ||
          p.iqamaReminder != c.iqamaReminder ||
          p.sunriseAlert != c.sunriseAlert,
      builder: (context, s) {
        final cubit = context.read<SettingsCubit>();
        final glass = GlassTheme.of(context);
        final voice = AdhanVoices.byId(s.adhanVoice);
        final enabled = s.prayerNotifications;
        final divider = Divider(height: 1, indent: 70, color: glass.onGlass.withValues(alpha: 0.08));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ------------------------------------------ master switch ---
            const GlassSectionTitle('الأذان', tone: Tone.sapphire),
            _MasterSwitch(
              enabled: enabled,
              voiceName: voice.nameAr,
              onChanged: cubit.setPrayerNotifications,
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: enabled ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              secondChild: const SizedBox(width: double.infinity),
              firstChild: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ------------------------------------------ voice ---
                  const SizedBox(height: 12),
                  NoorCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SettingRow(
                          icon: Icons.record_voice_over_rounded,
                          tone: Tone.amethyst,
                          title: 'صوت الأذان',
                          subtitle: '${voice.nameAr} • ${voice.origin}',
                          onTap: () => _pickVoice(context, s),
                        ),
                        if (voice.id != 'default') ...[
                          divider,
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    _ChoiceTile(
                                      icon: Icons.mosque_rounded,
                                      label: 'الأذان كاملًا',
                                      tone: Tone.amethyst,
                                      selected: s.adhanFull,
                                      onTap: () => cubit.setAdhanFull(true),
                                    ),
                                    const SizedBox(width: 8),
                                    _ChoiceTile(
                                      icon: Icons.short_text_rounded,
                                      label: 'التكبيرات فقط',
                                      tone: Tone.amethyst,
                                      selected: !s.adhanFull,
                                      onTap: () => cubit.setAdhanFull(false),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _PreviewButton(voice: voice.id, full: s.adhanFull),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ---------------------------------------- prayers ---
                  const GlassSectionTitle('الصلوات', tone: Tone.sapphire),
                  NoorCard(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 10),
                          child: Text('الصلوات التي يؤذَّن لها',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: glass.onGlassMuted)),
                        ),
                        Row(
                          children: [
                            _PrayerPill(
                              prayer: PrayerName.fajr,
                              on: s.prayerAlerts[0],
                              onTap: () => cubit.setPrayerAlert(0, !s.prayerAlerts[0]),
                            ),
                            const SizedBox(width: 8),
                            _PrayerPill(
                              prayer: PrayerName.sunrise,
                              on: s.sunriseAlert,
                              onTap: () => cubit.setSunriseAlert(!s.sunriseAlert),
                            ),
                            const SizedBox(width: 8),
                            _PrayerPill(
                              prayer: _alertPrayers[1],
                              on: s.prayerAlerts[1],
                              onTap: () => cubit.setPrayerAlert(1, !s.prayerAlerts[1]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (var i = 2; i < _alertPrayers.length; i++) ...[
                              if (i > 2) const SizedBox(width: 8),
                              _PrayerPill(
                                prayer: _alertPrayers[i],
                                on: s.prayerAlerts[i],
                                onTap: () => cubit.setPrayerAlert(i, !s.prayerAlerts[i]),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: glass.onGlassMuted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text('الشروق تنبيه هادئ وليس أذانًا • يوم الجمعة تظهر صلاة الظهر باسم «الجمعة»',
                                  style: TextStyle(fontSize: 11.5, height: 1.5, color: glass.onGlassMuted)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ------------------------------- silent-phone mode ---
                  const GlassSectionTitle('سلوك الأذان', tone: Tone.sapphire),
                  NoorCard(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const ToneIcon(Icons.volume_up_rounded, tone: Tone.teal, size: 42),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text('عندما يكون الهاتف صامتًا أو على الاهتزاز',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: glass.onGlass)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _ModeOption(
                          selected: s.adhanAlwaysPlay,
                          icon: Icons.campaign_rounded,
                          tone: Tone.teal,
                          title: 'يُرفع الأذان دائمًا',
                          subtitle: 'يعمل كالمنبّه حتى في الصامت والاهتزاز (بصوت المنبّه)',
                          onTap: () => cubit.setAdhanAlwaysPlay(true),
                        ),
                        const SizedBox(height: 8),
                        _ModeOption(
                          selected: !s.adhanAlwaysPlay,
                          icon: Icons.vibration_rounded,
                          tone: Tone.slate,
                          title: 'حسب وضع الهاتف',
                          subtitle: 'لا يؤذّن إلا إذا كان صوت الهاتف مفتوحًا',
                          onTap: () => cubit.setAdhanAlwaysPlay(false),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: const Text('تجربة التنبيه الحقيقي (بعد ١٠ ثوانٍ)'),
                          onPressed: () => _testAlert(context, s),
                        ),
                      ],
                    ),
                  ),

                  // ---------------------------------------- reminders ---
                  const GlassSectionTitle('التذكيرات', tone: Tone.sapphire),
                  NoorCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SettingRow(
                          icon: Icons.groups_rounded,
                          tone: Tone.emerald,
                          title: 'تذكير بالإقامة',
                          subtitle: s.iqamaReminder
                              ? 'تنبيه صامت: الفجر بعد ٢٠ د، المغرب ١٠ د، وباقي الصلوات ١٥ د'
                              : 'غير مفعّل',
                          value: s.iqamaReminder,
                          onChanged: cubit.setIqamaReminder,
                        ),
                        divider,
                        _SettingRow(
                          icon: Icons.volunteer_activism_rounded,
                          tone: Tone.rose,
                          title: 'تذكير بأذكار بعد الصلاة',
                          subtitle: s.postPrayerAthkar
                              ? 'بعد الأذان بـ ${ArabicUtils.minutes(s.postPrayerMinutes, afterPreposition: true)}'
                              : 'غير مفعّل',
                          value: s.postPrayerAthkar,
                          onChanged: cubit.setPostPrayerAthkar,
                        ),
                        if (s.postPrayerAthkar)
                          _MinuteChips(
                            values: const [5, 10, 15, 20, 30],
                            selected: s.postPrayerMinutes,
                            onSelected: cubit.setPostPrayerMinutes,
                          ),
                        divider,
                        _SettingRow(
                          icon: Icons.alarm_rounded,
                          tone: Tone.amber,
                          title: 'تنبيه قبل الأذان',
                          subtitle: s.preAdhanEnabled
                              ? 'قبل الأذان بـ ${ArabicUtils.minutes(s.preAdhanMinutes, afterPreposition: true)}'
                              : 'غير مفعّل',
                          value: s.preAdhanEnabled,
                          onChanged: cubit.setPreAdhanEnabled,
                        ),
                        if (s.preAdhanEnabled)
                          _MinuteChips(
                            values: _minutes,
                            selected: s.preAdhanMinutes,
                            onSelected: cubit.setPreAdhanMinutes,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    if (s.adhanAlwaysPlay && AdhanNative.supported) {
      await AdhanNative.test(sound: AdhanNative.sound(voice.id, s.adhanFull));
    } else {
      await n.scheduleAdhanTest(voice: voice.id, voiceName: voice.nameAr, full: s.adhanFull);
    }
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
            Text('اختر صوت الأذان',
                style: TextStyle(
                    fontFamily: AppFonts.display, fontSize: 21, fontWeight: FontWeight.w700, color: glass.onGlass)),
            const SizedBox(height: 4),
            Text('اضغط ▶ للتجربة', style: TextStyle(fontSize: 12, color: glass.onGlassMuted)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final v in AdhanVoices.all)
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      tileColor: v.id == s.adhanVoice ? Tone.amethyst.mid.withValues(alpha: 0.16) : null,
                      leading: v.id == 'default'
                          ? const ToneIcon(Icons.notifications_rounded, tone: Tone.sapphire, size: 40)
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
                      trailing: v.id == s.adhanVoice
                          ? Icon(Icons.check_circle_rounded,
                              color: Tone.amethyst.ink(Theme.of(ctx).brightness == Brightness.dark))
                          : null,
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

/// The big on/off card for the adhan: filled with sapphire while it is on.
class _MasterSwitch extends StatelessWidget {
  final bool enabled;
  final String voiceName;
  final ValueChanged<bool> onChanged;

  const _MasterSwitch({required this.enabled, required this.voiceName, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return ToneCard(
      tone: Tone.sapphire,
      solid: enabled,
      ornament: true,
      radius: 24,
      padding: const EdgeInsets.fromLTRB(14, 16, 10, 16),
      onTap: () => onChanged(!enabled),
      child: Row(
        children: [
          if (enabled)
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 26),
            )
          else
            const ToneIcon(Icons.notifications_off_rounded, tone: Tone.sapphire, size: 50),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الأذان عند دخول وقت الصلاة',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900, color: enabled ? Colors.white : glass.onGlass)),
                const SizedBox(height: 3),
                Text(enabled ? 'مفعّل • $voiceName' : 'غير مفعّل',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: enabled ? Colors.white.withValues(alpha: 0.85) : glass.onGlassMuted)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Switch(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// A settings row: coloured icon, title, subtitle and a switch or chevron.
class _SettingRow extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool? value;
  final ValueChanged<bool>? onChanged;

  const _SettingRow({
    required this.icon,
    required this.tone,
    required this.title,
    this.subtitle,
    this.onTap,
    this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final toggle = value != null;
    return InkWell(
      onTap: toggle ? () => onChanged?.call(!value!) : onTap,
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
                  if (subtitle != null)
                    Text(subtitle!, style: TextStyle(fontSize: 12, height: 1.45, color: glass.onGlassMuted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (toggle)
              Switch(value: value!, onChanged: onChanged)
            else
              Icon(Icons.chevron_left_rounded, color: glass.onGlassMuted),
          ],
        ),
      ),
    );
  }
}

/// One prayer as a colourful pill: filled with the prayer's own colour when
/// the adhan is on for it, a soft outline when it is off.
class _PrayerPill extends StatelessWidget {
  final PrayerName prayer;
  final bool on;
  final VoidCallback onTap;

  const _PrayerPill({required this.prayer, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tone = prayer.tone;
    final icon = !on
        ? Icons.notifications_off_outlined
        : prayer == PrayerName.sunrise
            ? Icons.wb_twilight_rounded
            : Icons.notifications_active_rounded;
    return Expanded(
      child: Semantics(
        button: true,
        toggled: on,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: on ? tone.solid : null,
              color: on ? null : glass.onGlass.withValues(alpha: dark ? 0.04 : 0.03),
              border: Border.all(
                color: on ? Colors.white.withValues(alpha: 0.2) : tone.mid.withValues(alpha: dark ? 0.35 : 0.4),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: on ? Colors.white : tone.ink(dark).withValues(alpha: 0.75)),
                const SizedBox(height: 4),
                Text(prayer.nameAr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w900, color: on ? Colors.white : glass.onGlass)),
                Text(on ? 'مفعّل' : 'متوقف',
                    maxLines: 1,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: on ? Colors.white.withValues(alpha: 0.8) : glass.onGlassMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Two-way choice (full adhan / takbeers only) as side-by-side tiles.
class _ChoiceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Tone tone;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.icon,
    required this.label,
    required this.tone,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: selected ? tone.solid : tone.wash(dark),
              border: Border.all(
                color: selected ? Colors.white.withValues(alpha: 0.2) : tone.mid.withValues(alpha: dark ? 0.28 : 0.32),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: selected ? Colors.white : tone.ink(dark)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : glass.onGlass)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Minutes to choose from, under a reminder row.
class _MinuteChips extends StatelessWidget {
  final List<int> values;
  final int selected;
  final ValueChanged<int> onSelected;

  const _MinuteChips({required this.values, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(70, 0, 12, 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final m in values)
            ChoiceChip(
              label: Text('${ArabicUtils.toArabicDigits(m)} د'),
              selected: selected == m,
              onSelected: (_) => onSelected(m),
            ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final Tone tone;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeOption({
    required this.selected,
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
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: selected ? tone.wash(dark) : null,
          color: selected ? null : glass.onGlass.withValues(alpha: 0.03),
          border: Border.all(
            color: selected ? tone.mid : glass.onGlass.withValues(alpha: 0.10),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: selected ? 1.0 : 0.55,
              child: ToneIcon(icon, tone: tone, size: 38),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(fontWeight: FontWeight.w800, color: selected ? tone.ink(dark) : glass.onGlass)),
                  Text(subtitle, style: TextStyle(fontSize: 12, height: 1.4, color: glass.onGlassMuted)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? tone.ink(dark) : glass.onGlassMuted),
          ],
        ),
      ),
    );
  }
}

class _PreviewButton extends StatelessWidget {
  final String voice;
  final bool full;

  const _PreviewButton({required this.voice, required this.full});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = Tone.amethyst.ink(dark);
    return ValueListenableBuilder<String?>(
      valueListenable: AdhanPreview.playing,
      builder: (context, playing, _) {
        final on = playing == AdhanPreview.key(voice, full);
        return OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: ink,
            side: BorderSide(color: Tone.amethyst.mid.withValues(alpha: on ? 0.9 : 0.5), width: on ? 1.6 : 1),
            backgroundColor: on ? Tone.amethyst.mid.withValues(alpha: 0.14) : null,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: Icon(on ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded),
          label: Text(on ? 'إيقاف التجربة' : 'تجربة صوت الأذان', style: const TextStyle(fontWeight: FontWeight.w800)),
          onPressed: () => AdhanPreview.toggle(context, voice, full),
        );
      },
    );
  }
}

/// The browser can't ring at a set time while the page is closed.
class _WebAdhanNotice extends StatelessWidget {
  const _WebAdhanNotice();

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return ToneCard(
      tone: Tone.sapphire,
      ornament: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ToneIcon(Icons.notifications_off_rounded, tone: Tone.sapphire, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'الأذان والتنبيهات تعمل في تطبيق أندرويد فقط؛ المتصفح لا يستطيع التنبيه والصفحة مغلقة. '
              'هنا تظهر المواقيت والعدّاد للصلاة القادمة.',
              style: TextStyle(height: 1.7, color: glass.onGlass),
            ),
          ),
        ],
      ),
    );
  }
}
