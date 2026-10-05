import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/surah_metadata.dart';
import '../../../../core/theme/app_themes.dart';
import '../../../../core/theme/tones.dart';
import '../../../../core/theme/web_lite.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/noor_ui.dart';
import '../../../quran/domain/entities/ayah.dart';
import '../../../quran/domain/repositories/quran_repository.dart';
import '../../../quran/presentation/mushaf/mushaf_reader_page.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../domain/reciter.dart';
import '../cubit/audio_cubit.dart';
import '../cubit/audio_state.dart';
import '../widgets/mini_player.dart';
import 'downloads_page.dart';
import 'memorization_page.dart';

class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const PlayerPage());

  static const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  static const _tone = Tone.amethyst;

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GlassScaffold(
      title: 'المشغل',
      subtitle: 'استمع وتابع الآيات',
      icon: Icons.headphones_rounded,
      tone: _tone,
      actions: [
        if (!kIsWeb) // no offline files in the browser
        IconButton(
          tooltip: 'التحميلات',
          icon: const Icon(Icons.download_for_offline_outlined),
          onPressed: () => Navigator.of(context).push(DownloadsPage.route()),
        ),
        IconButton(
          tooltip: 'وضع الحفظ',
          icon: const Icon(Icons.repeat_on_rounded),
          onPressed: () => Navigator.of(context).push(MemorizationPage.route()),
        ),
      ],
      body: BlocBuilder<AudioCubit, AudioState>(
        builder: (context, state) {
          final cubit = context.read<AudioCubit>();
          if (!state.hasQueue) {
            return _EmptyPlayer(onPlay: () => cubit.playSurah(1));
          }
          final surahInfo = state.surah != null ? SurahMetadata.surah(state.surah!) : null;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              // ------------------------------------------- now playing ---
              ToneCard(
                tone: _tone,
                ornament: true,
                radius: 30,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: state.isMedia
                          ? null
                          : () async {
                        final id = await showReciterPicker(context, state.reciterId);
                        if (id != null && context.mounted) await context.read<AudioCubit>().changeReciter(id);
                      },
                      child: Container(
                        padding: const EdgeInsetsDirectional.fromSTEB(5, 5, 12, 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: _tone.mid.withValues(alpha: dark ? 0.16 : 0.10),
                          border: Border.all(color: _tone.mid.withValues(alpha: 0.32)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const ToneIcon(Icons.record_voice_over_rounded, tone: _tone, size: 30),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(state.artist ?? Reciters.byId(state.reciterId).nameAr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w800)),
                            ),
                            if (!state.isMedia) Icon(Icons.expand_more_rounded, color: _tone.ink(dark)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Disc(
                      tone: _tone,
                      child: surahInfo == null
                          ? Icon(Icons.radio_rounded, size: 64, color: _tone.ink(dark))
                          : Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  surahInfo.name,
                                  textAlign: TextAlign.center,
                                  style: context
                                      .read<SettingsCubit>()
                                      .state
                                      .quranFont
                                      .style(fontSize: 36, height: 1.5, color: glass.onGlass, weight: FontWeight.w700),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.title ?? '',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: AppFonts.display, fontSize: 21, fontWeight: FontWeight.w700),
                    ),
                    if (state.isMemorization) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Tone.coral.mid.withValues(alpha: dark ? 0.18 : 0.12),
                          border: Border.all(color: Tone.coral.mid.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.repeat_on_rounded, size: 16, color: Tone.coral.ink(dark)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                state.infiniteLoop
                                    ? 'وضع الحفظ • تكرار مستمر'
                                    : 'وضع الحفظ • التكرارات المتبقية للنطاق: ${ArabicUtils.toArabicDigits(state.loopsRemaining)}',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Tone.coral.ink(dark), fontWeight: FontWeight.w700, fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _CurrentAyahText(surah: state.surah, ayah: state.ayah),
              const SizedBox(height: 10),

              // ---------------------------------------------- controls ---
              _PositionSlider(duration: state.duration, tone: _tone),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RoundControl(
                      icon: Icons.skip_next_rounded, size: 58, tone: _tone, onTap: cubit.previous, tooltip: 'السابقة'),
                  const SizedBox(width: 22),
                  _RoundControl(
                    icon: state.buffering
                        ? Icons.hourglass_top_rounded
                        : (state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    size: 84,
                    tone: _tone,
                    primary: true,
                    onTap: cubit.togglePlay,
                  ),
                  const SizedBox(width: 22),
                  _RoundControl(
                      icon: Icons.skip_previous_rounded, size: 58, tone: _tone, onTap: cubit.next, tooltip: 'التالية'),
                ],
              ),

              // ------------------------------------------------- speed ---
              const GlassSectionTitle('سرعة التلاوة', tone: _tone),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in speeds)
                    ChoiceChip(
                      label: Text('${ArabicUtils.toArabicDigits(s)}×'),
                      selected: (state.speed - s).abs() < 0.01,
                      onSelected: (_) => cubit.setSpeed(s),
                    ),
                ],
              ),
              const SizedBox(height: 22),

              // ----------------------------------------------- actions ---
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.surah != null) ...[
                      Expanded(
                        child: _ActionTile(
                          tone: Tone.emerald,
                          icon: Icons.menu_book_rounded,
                          label: state.isMedia ? 'فتح السورة في المصحف' : 'فتح المصحف مع تظليل الآية',
                          onTap: () =>
                              MushafReaderPage.open(context, surah: state.surah!, ayah: (state.ayah ?? 1).clamp(1, 286)),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: _ActionTile(
                        tone: Tone.rose,
                        icon: Icons.stop_rounded,
                        label: 'إيقاف التلاوة',
                        onTap: cubit.stop,
                      ),
                    ),
                  ],
                ),
              ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('تعذر تشغيل المقطع: تحقق من الاتصال أو حمّل السورة للاستماع دون إنترنت.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade300)),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Nothing is playing: a large, inviting card with a glowing icon.
class _EmptyPlayer extends StatelessWidget {
  final VoidCallback onPlay;

  const _EmptyPlayer({required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    const tone = Tone.amethyst;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ToneCard(
            tone: tone,
            ornament: true,
            radius: 30,
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 176,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [tone.mid.withValues(alpha: 0.42), tone.mid.withValues(alpha: 0)],
                            ),
                          ),
                        ),
                      ),
                      SizedBox.square(
                        dimension: 140,
                        child: CustomPaint(painter: KhatamPainter(tone.mid.withValues(alpha: 0.5), stroke: 1.5)),
                      ),
                      const ToneIcon(Icons.headphones_rounded, tone: tone, size: 78),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'لا توجد تلاوة قيد التشغيل',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    color: glass.onGlass,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'اختر سورة من فهرس القرآن أو ابدأ جلسة حفظ.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: glass.onGlassMuted, height: 1.6),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow_rounded, size: 26),
                  label: const Text('تشغيل سورة الفاتحة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: () => Navigator.of(context).push(MemorizationPage.route()),
                  icon: const Icon(Icons.repeat_on_rounded),
                  label: const Text('وضع الحفظ والتكرار', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The round "record" in the middle of the player: a tone ring with a soft
/// glow, a faint eight-pointed star and the surah name.
class _Disc extends StatelessWidget {
  final Tone tone;
  final Widget child;

  const _Disc({required this.tone, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox.square(
      dimension: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [tone.mid.withValues(alpha: dark ? 0.40 : 0.28), tone.mid.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          Container(
            width: 172,
            height: 172,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: tone.gradient()),
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: noorSurface(context)),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [tone.mid.withValues(alpha: dark ? 0.30 : 0.18), tone.mid.withValues(alpha: 0.03)],
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: CustomPaint(painter: KhatamPainter(tone.mid.withValues(alpha: 0.28))),
                      ),
                    ),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Round player button: a tone wash (secondary) or a solid tone (play).
class _RoundControl extends StatelessWidget {
  final IconData icon;
  final double size;
  final Tone tone;
  final VoidCallback onTap;
  final String? tooltip;
  final bool primary;

  const _RoundControl({
    required this.icon,
    required this.size,
    required this.tone,
    required this.onTap,
    this.tooltip,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final button = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: primary
            ? liteShadows([BoxShadow(color: tone.mid.withValues(alpha: 0.45), blurRadius: 22, offset: const Offset(0, 6))])
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: primary ? tone.gradient() : null,
            color: primary ? null : tone.mid.withValues(alpha: dark ? 0.16 : 0.10),
            border: Border.all(
              color: primary ? Colors.white.withValues(alpha: 0.22) : tone.mid.withValues(alpha: 0.4),
            ),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(
              dimension: size,
              child: Icon(icon, size: size * 0.5, color: primary ? Colors.white : tone.ink(dark)),
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Secondary action under the controls: a tone tile with icon and label.
class _ActionTile extends StatelessWidget {
  final Tone tone;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({required this.tone, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ToneCard(
      tone: tone,
      radius: 20,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          ToneIcon(icon, tone: tone, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

class _PositionSlider extends StatelessWidget {
  final Duration duration;
  final Tone tone;

  const _PositionSlider({required this.duration, required this.tone});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AudioCubit>();
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final timeStyle = TextStyle(color: glass.onGlassMuted, fontSize: 12.5, fontWeight: FontWeight.w600);
    return StreamBuilder<Duration>(
      stream: cubit.positionStream,
      builder: (context, snap) {
        final total = duration.inMilliseconds.toDouble();
        final pos = (snap.data ?? Duration.zero).inMilliseconds.toDouble().clamp(0.0, total <= 0 ? 0.0 : total);
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 5,
                activeTrackColor: tone.ink(dark),
                inactiveTrackColor: tone.mid.withValues(alpha: 0.20),
                thumbColor: tone.light,
                overlayColor: tone.mid.withValues(alpha: 0.18),
              ),
              child: Slider(
                value: total <= 0 ? 0 : pos,
                max: total <= 0 ? 1 : total,
                onChanged: total <= 0 ? null : (v) => cubit.seek(Duration(milliseconds: v.round())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(ArabicUtils.formatDuration(Duration(milliseconds: pos.round())), style: timeStyle),
                  Text(ArabicUtils.formatDuration(duration), style: timeStyle),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Shows the text of the ayah currently being recited.
class _CurrentAyahText extends StatelessWidget {
  final int? surah;
  final int? ayah;

  const _CurrentAyahText({required this.surah, required this.ayah});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final settings = context.read<SettingsCubit>().state;
    if (surah == null || ayah == null) return const SizedBox.shrink();
    final style = settings.quranFont.style(fontSize: 24, height: 2, color: glass.onGlass);
    const padding = EdgeInsets.fromLTRB(18, 14, 18, 14);
    if (ayah == 0) {
      return NoorCard(
        padding: padding,
        child: Text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ', textAlign: TextAlign.center, style: style),
      );
    }
    return FutureBuilder<Ayah?>(
      key: ValueKey('$surah:$ayah'),
      future: context.read<QuranRepository>().getAyah(surah!, ayah!),
      builder: (context, snap) {
        final text = snap.data?.text;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: NoorCard(
            key: ValueKey(text),
            padding: padding,
            child: text == null
                ? const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()))
                : Text('$text ${ArabicUtils.ayahMarker(ayah!)}', textAlign: TextAlign.center, style: style),
          ),
        );
      },
    );
  }
}
