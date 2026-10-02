import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/surah_metadata.dart';
import '../../../../core/theme/app_themes.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/state_views.dart';
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

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return GlassScaffold(
      title: 'المشغل',
      actions: [
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
            return MessageView(
              icon: Icons.headphones_rounded,
              title: 'لا توجد تلاوة قيد التشغيل',
              subtitle: 'اختر سورة من فهرس القرآن أو ابدأ جلسة حفظ.',
              actionLabel: 'تشغيل سورة الفاتحة',
              onAction: () => cubit.playSurah(1),
            );
          }
          final surahInfo = state.surah != null ? SurahMetadata.surah(state.surah!) : null;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassContainer(
                opacity: 0.94,
                tint: sheetSurface(context),
                borderRadius: 32,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () async {
                        final id = await showReciterPicker(context, state.reciterId);
                        if (id != null && context.mounted) await context.read<AudioCubit>().changeReciter(id);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.record_voice_over_rounded, color: glass.accent, size: 20),
                            const SizedBox(width: 8),
                            Text(Reciters.byId(state.reciterId).nameAr,
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                            const Icon(Icons.expand_more_rounded),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [glass.accent.withValues(alpha: 0.6), Colors.transparent]),
                        border: Border.all(color: glass.accent, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        surahInfo?.name ?? '',
                        textAlign: TextAlign.center,
                        style: context
                            .read<SettingsCubit>()
                            .state
                            .quranFont
                            .style(fontSize: 36, height: 1.5, color: glass.onGlass, weight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(state.title ?? '', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    if (state.isMemorization) ...[
                      const SizedBox(height: 6),
                      Text(
                        state.infiniteLoop
                            ? 'وضع الحفظ • تكرار مستمر'
                            : 'وضع الحفظ • التكرارات المتبقية للنطاق: ${ArabicUtils.toArabicDigits(state.loopsRemaining)}',
                        style: TextStyle(color: glass.accent, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _CurrentAyahText(surah: state.surah, ayah: state.ayah),
              const SizedBox(height: 14),
              _PositionSlider(duration: state.duration),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GlassIconButton(icon: Icons.skip_next_rounded, size: 56, onPressed: cubit.previous, tooltip: 'السابقة'),
                  const SizedBox(width: 18),
                  GlassIconButton(
                    icon: state.buffering
                        ? Icons.hourglass_top_rounded
                        : (state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    size: 80,
                    highlighted: true,
                    onPressed: cubit.togglePlay,
                  ),
                  const SizedBox(width: 18),
                  GlassIconButton(icon: Icons.skip_previous_rounded, size: 56, onPressed: cubit.next, tooltip: 'التالية'),
                ],
              ),
              const SizedBox(height: 18),
              const GlassSectionTitle('سرعة التلاوة'),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  for (final s in speeds)
                    ChoiceChip(
                      label: Text('${ArabicUtils.toArabicDigits(s)}×'),
                      selected: (state.speed - s).abs() < 0.01,
                      onSelected: (_) => cubit.setSpeed(s),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (state.surah != null)
                OutlinedButton.icon(
                  onPressed: () => MushafReaderPage.open(context, surah: state.surah!, ayah: (state.ayah ?? 1).clamp(1, 286)),
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text('فتح المصحف مع تظليل الآية'),
                ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: cubit.stop,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('إيقاف التلاوة'),
              ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
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

class _PositionSlider extends StatelessWidget {
  final Duration duration;

  const _PositionSlider({required this.duration});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AudioCubit>();
    final glass = GlassTheme.of(context);
    return StreamBuilder<Duration>(
      stream: cubit.positionStream,
      builder: (context, snap) {
        final total = duration.inMilliseconds.toDouble();
        final pos = (snap.data ?? Duration.zero).inMilliseconds.toDouble().clamp(0.0, total <= 0 ? 0.0 : total);
        return Column(
          children: [
            Slider(
              value: total <= 0 ? 0 : pos,
              max: total <= 0 ? 1 : total,
              onChanged: total <= 0 ? null : (v) => cubit.seek(Duration(milliseconds: v.round())),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(ArabicUtils.formatDuration(Duration(milliseconds: pos.round())),
                      style: TextStyle(color: glass.onGlassMuted)),
                  Text(ArabicUtils.formatDuration(duration), style: TextStyle(color: glass.onGlassMuted)),
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
    if (ayah == 0) {
      return GlassContainer(
                opacity: 0.94,
                tint: sheetSurface(context),
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
          child: GlassContainer(
                opacity: 0.94,
                tint: sheetSurface(context),
            key: ValueKey(text),
            child: text == null
                ? const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()))
                : Text('$text ${ArabicUtils.ayahMarker(ayah!)}', textAlign: TextAlign.center, style: style),
          ),
        );
      },
    );
  }
}
