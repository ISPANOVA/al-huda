import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_themes.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/reciter.dart';
import '../cubit/audio_cubit.dart';
import '../cubit/audio_state.dart';
import '../pages/player_page.dart';

/// Persistent compact player shown above the navigation bar.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioCubit, AudioState>(
      buildWhen: (p, c) =>
          p.hasQueue != c.hasQueue ||
          p.playing != c.playing ||
          p.buffering != c.buffering ||
          p.title != c.title ||
          p.duration != c.duration ||
          p.reciterId != c.reciterId,
      builder: (context, state) {
        if (!state.hasQueue) return const SizedBox.shrink();
        final glass = GlassTheme.of(context);
        final cubit = context.read<AudioCubit>();
        return _SolidCard(
          margin: const EdgeInsets.fromLTRB(14, 4, 14, 6),
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          onTap: () => Navigator.of(context).push(PlayerPage.route()),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [glass.accent, Theme.of(context).colorScheme.primary]),
                    ),
                    child: Icon(state.playing ? Icons.graphic_eq_rounded : Icons.headphones_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(state.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text(Reciters.byId(state.reciterId).nameAr,
                            maxLines: 1, style: TextStyle(fontSize: 12, color: glass.onGlassMuted)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.skip_next_rounded), onPressed: cubit.previous),
                  _PlayPauseButton(state: state, onTap: cubit.togglePlay),
                  IconButton(icon: const Icon(Icons.skip_previous_rounded), onPressed: cubit.next),
                  IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: cubit.stop),
                ],
              ),
              RepaintBoundary(
                child: StreamBuilder<Duration>(
                stream: cubit.positionStream,
                builder: (context, snap) {
                  final pos = snap.data ?? Duration.zero;
                  final total = state.duration.inMilliseconds;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: GlassProgressBar(value: total == 0 ? 0 : pos.inMilliseconds / total, height: 3),
                  );
                },
              ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final AudioState state;
  final VoidCallback onTap;

  const _PlayPauseButton({required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    if (state.buffering) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Padding(padding: const EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: glass.accent)),
      );
    }
    return IconButton(
      icon: Icon(state.playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
          size: 38, color: glass.accent),
      onPressed: onTap,
    );
  }
}

/// Reciter chooser used by the player & memorization screens.
Future<String?> showReciterPicker(BuildContext context, String currentId) {
  return showGlassSheet<String>(context, builder: (ctx) {
    final glass = GlassTheme.of(ctx);
    return SizedBox(
      height: MediaQuery.sizeOf(ctx).height * 0.7,
      child: Column(
        children: [
          Text('اختر القارئ', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: Reciters.all.length,
              itemBuilder: (ctx, i) {
                final r = Reciters.all[i];
                final selected = r.id == currentId;
                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  tileColor: selected ? glass.accent.withValues(alpha: 0.14) : null,
                  leading: CircleAvatar(
                    backgroundColor: glass.accent.withValues(alpha: 0.22),
                    child: Text(r.nameAr.characters.first, style: TextStyle(color: glass.onGlass)),
                  ),
                  title: Text(r.nameAr, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${r.style} • ${ArabicUtils.toArabicDigits(r.bitrate)} kbps'),
                  trailing: selected ? Icon(Icons.check_circle_rounded, color: glass.accent) : null,
                  onTap: () => Navigator.of(ctx).pop(r.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  });
}

/// Opaque card for the mini player so the Mushaf behind never shows through.
class _SolidCard extends StatelessWidget {
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final VoidCallback onTap;
  final Widget child;

  const _SolidCard({required this.margin, required this.padding, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: margin,
      child: Material(
        color: sheetSurface(context),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: glass.accent.withValues(alpha: dark ? 0.3 : 0.45)),
        ),
        clipBehavior: Clip.antiAlias,
        shadowColor: Colors.black,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
