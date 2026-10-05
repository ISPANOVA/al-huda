import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/surah_metadata.dart';
import '../../../../core/theme/app_themes.dart';
import '../../../../core/theme/tones.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/noor_ui.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../data/audio_download_service.dart';
import '../../domain/reciter.dart';
import '../cubit/downloads_cubit.dart';
import '../widgets/mini_player.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const DownloadsPage());

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => DownloadsCubit(ctx.read<AudioDownloadService>(), ctx.read<SettingsCubit>().state.reciterId),
      child: const _DownloadsView(),
    );
  }
}

class _DownloadsView extends StatelessWidget {
  const _DownloadsView();

  static const _tone = Tone.teal;

  String _size(int bytes) {
    if (bytes < 1024 * 1024) return '${ArabicUtils.toArabicDigits((bytes / 1024).toStringAsFixed(0))} ك.ب';
    return '${ArabicUtils.toArabicDigits((bytes / (1024 * 1024)).toStringAsFixed(1))} م.ب';
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return GlassScaffold(
      title: 'التلاوات دون إنترنت',
      subtitle: 'تلاوة آية بآية للمصحف والحفظ',
      icon: Icons.download_for_offline_rounded,
      tone: _tone,
      bottom: const MiniPlayer(),
      body: BlocBuilder<DownloadsCubit, DownloadsState>(
        builder: (context, state) {
          final cubit = context.read<DownloadsCubit>();
          final reciter = Reciters.byId(state.reciterId);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: 114 + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                final n = state.downloaded.length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ToneCard(
                      tone: _tone,
                      solid: true,
                      ornament: true,
                      radius: 26,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('المحمّل لهذا القارئ',
                                        style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.85),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800)),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(ArabicUtils.toArabicDigits(n),
                                            style: const TextStyle(
                                                fontFamily: AppFonts.display,
                                                fontSize: 40,
                                                fontWeight: FontWeight.w700,
                                                height: 1.3,
                                                color: Colors.white)),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text('/ ١١٤ سورة',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  color: Colors.white.withValues(alpha: 0.85),
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700)),
                                        ),
                                      ],
                                    ),
                                    Text('المساحة المستخدمة لكل القرّاء: ${_size(state.totalBytes)}',
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              NoorRing(
                                value: n / 114,
                                color: Colors.white,
                                track: Colors.white.withValues(alpha: 0.2),
                                size: 72,
                                stroke: 6,
                                child: Text('${ArabicUtils.toArabicDigits((n * 100 / 114).round())}٪',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Material(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(18),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () async {
                                final id = await showReciterPicker(context, state.reciterId);
                                if (id != null) cubit.changeReciter(id);
                              },
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.18)),
                                      child: const Icon(Icons.record_voice_over_rounded, color: Colors.white, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(reciter.nameAr,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                                          Text('اضغط لتغيير القارئ',
                                              style: TextStyle(
                                                  color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.swap_horiz_rounded, color: Colors.white),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GlassSectionTitle(
                      'السور',
                      tone: _tone,
                      trailing: Text('١١٤ سورة', style: TextStyle(fontSize: 12.5, color: glass.onGlassMuted)),
                    ),
                  ],
                );
              }
              final surah = i;
              final info = SurahMetadata.surah(surah);
              return _SurahRow(
                surah: surah,
                name: info.name,
                ayahCount: info.ayahCount,
                progress: state.progress[surah],
                done: state.downloaded.contains(surah),
                error: state.errors[surah],
                onCancel: () => cubit.cancel(surah),
                onDelete: () => cubit.delete(surah),
                onDownload: () => cubit.download(surah),
              );
            },
          );
        },
      ),
    );
  }
}

class _SurahRow extends StatelessWidget {
  final int surah;
  final String name;
  final int ayahCount;
  final double? progress;
  final bool done;
  final String? error;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onDownload;

  const _SurahRow({
    required this.surah,
    required this.name,
    required this.ayahCount,
    required this.progress,
    required this.done,
    required this.error,
    required this.onCancel,
    required this.onDelete,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    const tone = Tone.teal;
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = noorSurface(context);
    final progress = this.progress;

    Widget trailing;
    if (progress != null) {
      trailing = IconButton(
        tooltip: 'إلغاء',
        icon: Icon(Icons.cancel_outlined, color: Tone.rose.ink(dark)),
        onPressed: onCancel,
      );
    } else if (done) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.offline_pin_rounded, color: tone.ink(dark)),
          IconButton(
            tooltip: 'حذف',
            icon: Icon(Icons.delete_outline_rounded, color: glass.onGlassMuted),
            onPressed: onDelete,
          ),
        ],
      );
    } else {
      trailing = IconButton(
        tooltip: 'تحميل',
        style: IconButton.styleFrom(
          backgroundColor: tone.mid.withValues(alpha: dark ? 0.18 : 0.12),
          foregroundColor: tone.ink(dark),
        ),
        icon: const Icon(Icons.download_rounded),
        onPressed: onDownload,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 6, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: done ? Color.alphaBlend(tone.mid.withValues(alpha: dark ? 0.10 : 0.07), surface) : surface,
          border: Border.all(
            color: error != null
                ? Colors.red.shade300.withValues(alpha: 0.45)
                : (done || progress != null)
                    ? tone.mid.withValues(alpha: 0.45)
                    : glass.onGlass.withValues(alpha: 0.07),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    gradient: done ? tone.gradient() : null,
                    color: done ? null : tone.mid.withValues(alpha: dark ? 0.14 : 0.10),
                  ),
                  child: Text(
                    ArabicUtils.toArabicDigits(surah),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: done ? Colors.white : tone.ink(dark),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('سورة $name', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(
                        error ?? '${ArabicUtils.toArabicDigits(ayahCount)} آية',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: error != null ? Colors.red.shade300 : glass.onGlassMuted),
                      ),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: _ToneBar(value: progress, tone: tone),
              ),
              const SizedBox(height: 2),
            ],
          ],
        ),
      ),
    );
  }
}

/// Thin progress bar in a tone.
class _ToneBar extends StatelessWidget {
  final double value;
  final Tone tone;

  const _ToneBar({required this.value, required this.tone});

  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: tone.mid.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: v,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: LinearGradient(colors: [tone.light, tone.deep]),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}
