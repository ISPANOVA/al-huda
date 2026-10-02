import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_themes.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../audio/presentation/cubit/audio_cubit.dart';
import '../../../audio/presentation/widgets/mini_player.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../data/athkar_data.dart';
import '../cubit/athkar_cubit.dart';

/// Athkar tab: category grid with today's completion.
class AthkarHomePage extends StatelessWidget {
  const AthkarHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final state = context.watch<AthkarCubit>().state;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
      children: [
        Text('الأذكار', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        Text('﴿أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ﴾', style: TextStyle(color: glass.onGlassMuted)),
        const SizedBox(height: 14),
        for (final c in AthkarData.categories)
          GlassContainer(
            margin: const EdgeInsets.symmetric(vertical: 7),
            padding: const EdgeInsets.all(18),
            onTap: () => Navigator.of(context).push(AthkarListPage.route(c.id)),
            child: Row(
              children: [
                Text(c.emoji, style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      Text('${c.subtitle} • ${ArabicUtils.toArabicDigits(c.items.length)} ذكرًا',
                          style: TextStyle(color: glass.onGlassMuted, fontSize: 12.5)),
                      const SizedBox(height: 10),
                      GlassProgressBar(value: state.categoryProgress(c), height: 7),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${ArabicUtils.toArabicDigits((state.categoryProgress(c) * 100).round())}٪',
                  style: TextStyle(fontWeight: FontWeight.w900, color: glass.accent),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class AthkarListPage extends StatelessWidget {
  final String categoryId;

  const AthkarListPage({super.key, required this.categoryId});

  static Route<void> route(String id) => MaterialPageRoute(builder: (_) => AthkarListPage(categoryId: id));

  @override
  Widget build(BuildContext context) {
    final category = AthkarData.byId(categoryId);
    final progress = context.select<AthkarCubit, double>((c) => c.state.categoryProgress(category));
    return GlassScaffold(
      title: category.title,
      actions: [
        IconButton(
          tooltip: 'إعادة البدء',
          icon: const Icon(Icons.restart_alt_rounded),
          onPressed: () => context.read<AthkarCubit>().resetCategory(category),
        ),
      ],
      bottom: const MiniPlayer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: GlassProgressBar(value: progress),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              itemCount: category.items.length,
              itemBuilder: (context, i) => _ThikrCard(category: category, thikr: category.items[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThikrCard extends StatelessWidget {
  final AthkarCategory category;
  final Thikr thikr;

  const _ThikrCard({required this.category, required this.thikr});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final done = context.select<AthkarCubit, int>((c) => c.state.done(category.id, thikr.id));
    final completed = done >= thikr.count;
    final haptics = context.select((SettingsCubit c) => c.state.hapticFeedback);
    final font = context.select((SettingsCubit c) => c.state.quranFont);

    Future<void> tap() async {
      if (completed) return;
      final finished = await context.read<AthkarCubit>().increment(category, thikr);
      if (haptics) finished ? HapticFeedback.heavyImpact() : HapticFeedback.selectionClick();
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: completed ? 0.55 : 1,
      child: GlassContainer(
        blur: 0,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        onTap: tap,
        tint: completed ? glass.accent : null,
        opacity: completed ? 0.25 : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              thikr.text,
              textAlign: TextAlign.justify,
              style: thikr.quran != null
                  ? font.style(fontSize: 22, height: 2.0, color: glass.onGlass)
                  : const TextStyle(fontSize: 18.5, height: 1.95, fontWeight: FontWeight.w500),
            ),
            if (thikr.virtue != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: glass.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('✨ ${thikr.virtue!}', style: TextStyle(fontSize: 13, color: glass.onGlassMuted, height: 1.6)),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(thikr.source, style: TextStyle(fontSize: 12, color: glass.onGlassMuted)),
                ),
                if (thikr.quran != null)
                  IconButton(
                    tooltip: 'استماع',
                    icon: Icon(Icons.volume_up_rounded, color: glass.accent),
                    onPressed: () {
                      final q = thikr.quran!;
                      context.read<AudioCubit>().playAyahs(q.surah, q.from, q.to);
                    },
                  ),
                GestureDetector(
                  onTap: tap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(colors: [glass.accent, Theme.of(context).colorScheme.primary]),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(completed ? Icons.check_rounded : Icons.touch_app_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${ArabicUtils.toArabicDigits(done)} / ${ArabicUtils.toArabicDigits(thikr.count)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
