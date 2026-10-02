import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_themes.dart';
import '../../core/utils/arabic_utils.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/state_views.dart';
import '../quran/presentation/cubit/bookmarks_cubit.dart';
import '../quran/presentation/mushaf/mushaf_reader_page.dart';
import '../settings/presentation/cubit/settings_cubit.dart';
import 'wird_tracker.dart';

/// Dashboard card for the smart daily wird.
class WirdCard extends StatelessWidget {
  const WirdCard({super.key});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final goal = context.select((SettingsCubit c) => c.state.wirdPages);
    final tracker = context.read<WirdTracker>();

    if (goal <= 0) {
      return GlassContainer(
        blur: 0,
        onTap: () => showWirdSetup(context),
        child: Row(
          children: [
            Icon(Icons.auto_graph_rounded, color: glass.accent, size: 36),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ابدأ وردك اليومي', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  Text('حدد عدد الصفحات، وسنحسب قراءتك تلقائيًا من المصحف'),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded),
          ],
        ),
      );
    }

    return ListenableBuilder(
      listenable: tracker,
      builder: (context, _) {
        final done = tracker.todayCount;
        final complete = done >= goal;
        final streak = tracker.streak(goal);
        final progress = (done / goal).clamp(0.0, 1.0);
        final lastPage = context.read<BookmarksCubit>().lastPage ?? 1;
        return GlassContainer(
          blur: 0,
          onTap: () => MushafReaderPage.open(context, page: lastPage),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => CircularProgressIndicator(
                        value: v,
                        strokeWidth: 6,
                        strokeCap: StrokeCap.round,
                        backgroundColor: glass.onGlass.withValues(alpha: 0.1),
                        color: complete ? glass.accent : primary,
                      ),
                    ),
                    Center(
                      child: complete
                          ? Icon(Icons.check_rounded, color: glass.accent, size: 30)
                          : Text(
                              '${ArabicUtils.toArabicDigits(done)}/${ArabicUtils.toArabicDigits(goal)}',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(complete ? 'أتممت وردك اليوم 🌿' : 'وردك اليوم',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    Text(
                      complete
                          ? 'قرأت ${ArabicUtils.toArabicDigits(done)} صفحة، زادك الله حرصًا'
                          : 'باقي ${ArabicUtils.toArabicDigits(goal - done)} صفحة • أكمل من صفحة ${ArabicUtils.toArabicDigits(lastPage)}',
                      style: TextStyle(fontSize: 13, color: glass.onGlassMuted),
                    ),
                    if (streak > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('🔥 ${ArabicUtils.toArabicDigits(streak)} يوم متتالٍ',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: glass.accent)),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'تعديل الورد',
                icon: Icon(Icons.tune_rounded, color: glass.onGlassMuted),
                onPressed: () => showWirdSetup(context),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Choose pages per day; shows how long a full khatmah takes.
Future<void> showWirdSetup(BuildContext context) {
  final cubit = context.read<SettingsCubit>();
  const options = [
    (pages: 2, label: 'صفحتان', hint: 'بداية هادئة'),
    (pages: 5, label: '٥ صفحات', hint: 'صفحة بعد كل صلاة'),
    (pages: 10, label: '١٠ صفحات', hint: 'صفحتان بعد كل صلاة'),
    (pages: 20, label: '٢٠ صفحة', hint: 'جزء كل يوم • ختمة في شهر'),
  ];
  return showGlassSheet<void>(context, builder: (ctx) {
    final glass = GlassTheme.of(ctx);
    final current = cubit.state.wirdPages;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('الورد اليومي',
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'تُحسب الصفحة تلقائيًا عندما تبقى عليها في المصحف بضع ثوانٍ.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: glass.onGlassMuted),
          ),
          const SizedBox(height: 14),
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: glass.accent.withValues(alpha: o.pages == current ? 0.7 : 0.2)),
                ),
                tileColor: o.pages == current ? glass.accent.withValues(alpha: 0.12) : null,
                title: Text(o.label, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(
                  '${o.hint} • ختمة كل ${ArabicUtils.toArabicDigits((604 / o.pages).ceil())} يومًا',
                ),
                trailing: o.pages == current ? Icon(Icons.check_circle_rounded, color: glass.accent) : null,
                onTap: () {
                  cubit.setWirdPages(o.pages);
                  Navigator.pop(ctx);
                },
              ),
            ),
          if (current > 0)
            TextButton(
              onPressed: () {
                cubit.setWirdPages(0);
                Navigator.pop(ctx);
              },
              child: const Text('إيقاف الورد اليومي'),
            ),
        ],
      ),
    );
  });
}
