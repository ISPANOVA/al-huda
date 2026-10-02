import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_themes.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/noor_ui.dart';
import '../../../tasbeeh/presentation/pages/tasbeeh_page.dart';
import '../../../virtues/virtues_pages.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../audio/presentation/cubit/audio_cubit.dart';
import '../../../audio/presentation/widgets/mini_player.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../data/athkar_data.dart';
import '../cubit/athkar_cubit.dart';

/// Look of each category: sky gradient and icon.
({List<Color> colors, IconData icon}) athkarLook(String id) => switch (id) {
      'morning' => (colors: const [Color(0xFF15426B), Color(0xFF4F8DB6), Color(0xFFF1D7A0)], icon: Icons.wb_sunny_rounded),
      'evening' => (colors: const [Color(0xFF1E1638), Color(0xFF7E3048), Color(0xFFF09A4A)], icon: Icons.wb_twilight_rounded),
      'prayer' => (colors: const [Color(0xFF0B2A24), Color(0xFF1E5E4E), Color(0xFFC9A44C)], icon: Icons.mosque_rounded),
      'sleep' => (colors: const [Color(0xFF03050F), Color(0xFF0A1230), Color(0xFF2B2F5A)], icon: Icons.bedtime_rounded),
      _ => (colors: const [Color(0xFF2A2210), Color(0xFF5A4520), Color(0xFFC9A44C)], icon: Icons.auto_awesome_rounded),
    };

/// Which athkar fit the current hour.
String suggestedAthkar(DateTime now) {
  final h = now.hour;
  if (h >= 4 && h < 12) return 'morning';
  if (h >= 15 && h < 20) return 'evening';
  if (h >= 21 || h < 4) return 'sleep';
  return 'prayer';
}

/// الأذكار — a featured card for the current time, today's overall
/// progress, and mihrab-shaped category tiles.
class AthkarHomePage extends StatelessWidget {
  const AthkarHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final state = context.watch<AthkarCubit>().state;
    final cats = AthkarData.categories;
    final featured = AthkarData.byId(suggestedAthkar(DateTime.now()));
    final overall = cats.fold<double>(0, (a, c) => a + state.categoryProgress(c)) / cats.length;
    final completed = cats.where((c) => state.categoryProgress(c) >= 1).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 130),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: [
        NoorPageHeader(
          'الأذكار',
          subtitle: 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
          actions: [
            NoorRing(
              value: overall,
              color: glass.accent,
              size: 54,
              stroke: 4.5,
              child: Text('${ArabicUtils.toArabicDigits(completed)}/${ArabicUtils.toArabicDigits(cats.length)}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _FeaturedAthkar(category: featured, progress: state.categoryProgress(featured)),
        ),
        const NoorSection('كل الأذكار'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.08,
            children: [
              for (final c in cats) _CategoryArch(category: c, progress: state.categoryProgress(c)),
            ],
          ),
        ),
        const NoorSection('رفيقك في الذكر'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              for (final (i, item) in [
                (Icons.blur_circular_rounded, 'المسبحة', TasbeehPage.route),
                (Icons.healing_rounded, 'الرقية', RuqyahPage.route),
                (Icons.auto_awesome_rounded, 'الفضائل', VirtuesPage.route),
              ].indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: NoorCard(
                    radius: 20,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    onTap: () => Navigator.of(context).push(item.$3()),
                    child: Column(
                      children: [
                        Icon(item.$1, color: glass.accent, size: 28),
                        const SizedBox(height: 6),
                        Text(item.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FeaturedAthkar extends StatelessWidget {
  final AthkarCategory category;
  final double progress;

  const _FeaturedAthkar({required this.category, required this.progress});

  @override
  Widget build(BuildContext context) {
    final look = athkarLook(category.id);
    final done = progress >= 1;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(AthkarListPage.route(category.id)),
      child: Container(
        height: 170,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: look.colors),
          boxShadow: [BoxShadow(color: look.colors[1].withValues(alpha: 0.45), blurRadius: 26, offset: const Offset(0, 10))],
        ),
        child: Stack(
          children: [
            PositionedDirectional(
              end: -30,
              bottom: -30,
              child: Icon(look.icon, size: 160, color: Colors.white.withValues(alpha: 0.08)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          child: const Text('وقتها الآن',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(height: 10),
                        Text(category.title,
                            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                        Text(category.subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(done ? Icons.check_rounded : Icons.play_arrow_rounded, color: look.colors.first),
                              const SizedBox(width: 4),
                              Text(done ? 'أتممتها، بارك الله فيك' : (progress > 0 ? 'أكمل الأذكار' : 'ابدأ الآن'),
                                  style: TextStyle(color: look.colors.first, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  NoorRing(
                    value: progress,
                    color: Colors.white,
                    track: Colors.white.withValues(alpha: 0.2),
                    size: 80,
                    stroke: 6,
                    child: Text('${ArabicUtils.toArabicDigits((progress * 100).round())}٪',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryArch extends StatelessWidget {
  final AthkarCategory category;
  final double progress;

  const _CategoryArch({required this.category, required this.progress});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final look = athkarLook(category.id);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(AthkarListPage.route(category.id)),
      child: ArchCard(
        archHeight: 0.16,
        padding: const EdgeInsets.fromLTRB(14, 22, 14, 12),
        borderColor: glass.accent.withValues(alpha: 0.35),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: look.colors),
        child: Column(
          children: [
            Icon(look.icon, color: Colors.white.withValues(alpha: 0.9), size: 26),
            const Spacer(),
            Text(category.title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
            Text('${ArabicUtils.toArabicDigits(category.items.length)} ذكرًا',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 4),
            Text(progress >= 1 ? 'تمت ✓' : '${ArabicUtils.toArabicDigits((progress * 100).round())}٪',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                color: GlassTheme.of(context).accent,
                backgroundColor: GlassTheme.of(context).onGlass.withValues(alpha: 0.08),
              ),
            ),
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

    final ratio = thikr.count == 0 ? 0.0 : done / thikr.count;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: completed ? 0.6 : 1,
      child: NoorCard(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        highlighted: !completed && done > 0,
        onTap: tap,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              thikr.text,
              textAlign: TextAlign.center,
              style: thikr.quran != null
                  ? font.style(fontSize: 22, height: 2.0, color: glass.onGlass)
                  : TextStyle(fontSize: 18.5, height: 1.95, fontWeight: FontWeight.w600, color: glass.onGlass),
            ),
            if (thikr.virtue != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: glass.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: BorderDirectional(start: BorderSide(color: glass.accent, width: 3)),
                ),
                child: Text(thikr.virtue!, style: TextStyle(fontSize: 13, color: glass.onGlassMuted, height: 1.6)),
              ),
            ],
            const SizedBox(height: 12),
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
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: tap,
                  child: NoorRing(
                    value: ratio,
                    color: glass.accent,
                    size: 62,
                    stroke: 5,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: completed
                          ? Icon(Icons.check_rounded, key: const ValueKey('done'), color: glass.accent, size: 30)
                          : Column(
                              key: ValueKey(done),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(ArabicUtils.toArabicDigits(done),
                                    style: TextStyle(
                                        fontSize: 18, fontWeight: FontWeight.w900, color: glass.onGlass, height: 1.1)),
                                Text('من ${ArabicUtils.toArabicDigits(thikr.count)}',
                                    style: TextStyle(fontSize: 10, color: glass.onGlassMuted)),
                              ],
                            ),
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
