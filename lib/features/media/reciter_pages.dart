import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/data/surah_metadata.dart';
import '../../core/theme/app_themes.dart';
import '../../core/utils/arabic_utils.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/state_views.dart';
import '../audio/presentation/cubit/audio_cubit.dart';
import '../audio/presentation/cubit/audio_state.dart';
import 'media_catalog.dart';
import 'media_downloads.dart';
import 'media_widgets.dart';

void playMediaSurah(BuildContext context, MediaReciter r, int surah) {
  HapticFeedback.selectionClick();
  final cubit = context.read<AudioCubit>();
  final s = cubit.state;
  if (s.hasQueue && s.reciterId == r.id && s.surah == surah) {
    cubit.togglePlay();
  } else {
    cubit.playMediaSurah(r, surah, localPath: (x) => MediaDownloads.instance.localPath(r, x));
  }
}

/// Tall reciter card used in carousels and the reciters grid.
class ReciterCard extends StatelessWidget {
  final MediaReciter reciter;

  const ReciterCard({super.key, required this.reciter});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final tint = mediaTint(reciter.key.replaceAll('_mj', ''));
    return Pressable(
      onTap: () => Navigator.of(context).push(ReciterSurahsPage.route(reciter)),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(tint, Colors.black, 0.25)!, Color.lerp(tint, Colors.black, 0.82)!],
          ),
          border: Border.all(color: glass.accent.withValues(alpha: 0.28)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: LatticePainter(color: glass.accent.withValues(alpha: 0.07), cell: 34)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 16, 10, 12),
              child: Column(
                children: [
                  Expanded(
                    child: FittedBox(
                      child: MonogramAvatar(name: reciter.name, seed: reciter.key.replaceAll('_mj', ''), size: 96),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    reciter.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, height: 1.3),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: reciter.mujawwad ? glass.accent : Colors.white.withValues(alpha: 0.14),
                    ),
                    child: Text(
                      reciter.style,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: reciter.mujawwad ? Colors.black : Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
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

// ------------------------------------------------------------ all reciters ---

class AllRecitersPage extends StatefulWidget {
  const AllRecitersPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const AllRecitersPage());

  @override
  State<AllRecitersPage> createState() => _AllRecitersPageState();
}

class _AllRecitersPageState extends State<AllRecitersPage> {
  String _query = '';
  int _filter = 0;
  static const _filters = ['الكل', 'قرّاء مصر', 'الحرمين والخليج', 'المجوَّد'];

  bool _match(MediaReciter r) {
    switch (_filter) {
      case 1:
        if (r.region != MediaRegion.eg) return false;
      case 2:
        if (r.region != MediaRegion.gulf) return false;
      case 3:
        if (!r.mujawwad) return false;
    }
    return _query.isEmpty || ArabicUtils.normalize(r.name).contains(ArabicUtils.normalize(_query));
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final list = MediaCatalog.reciters.where(_match).toList();
    return GlassScaffold(
      title: 'القرّاء',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'ابحث عن قارئ',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final on = i == _filter;
                return Pressable(
                  onTap: () => setState(() => _filter = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: on ? glass.accent : glass.onGlass.withValues(alpha: 0.06),
                    ),
                    child: Text(
                      _filters[i],
                      style: TextStyle(fontWeight: FontWeight.w800, color: on ? Colors.black : glass.onGlass),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: list.isEmpty
                ? const MessageView(icon: Icons.search_off_rounded, title: 'لا يوجد قارئ بهذا الاسم')
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    physics: const BouncingScrollPhysics(),
                    itemCount: list.length,
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 170,
                      mainAxisExtent: 206,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemBuilder: (context, i) => ReciterCard(reciter: list[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ one reciter ---

/// 114 surahs of one reciter: play (continues to the next surah) or download.
class ReciterSurahsPage extends StatefulWidget {
  final MediaReciter reciter;

  const ReciterSurahsPage({super.key, required this.reciter});

  static Route<void> route(MediaReciter r) => MaterialPageRoute(builder: (_) => ReciterSurahsPage(reciter: r));

  @override
  State<ReciterSurahsPage> createState() => _ReciterSurahsPageState();
}

class _ReciterSurahsPageState extends State<ReciterSurahsPage> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    MediaDownloads.instance.init();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reciter;
    final glass = GlassTheme.of(context);
    final tint = mediaTint(r.key.replaceAll('_mj', ''));
    final q = ArabicUtils.normalize(_query);
    final list = [
      for (final s in SurahMetadata.all)
        if (_query.isEmpty || ArabicUtils.normalize(s.name).contains(q) || '${s.number}' == _query) s,
    ];
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          const Positioned.fill(child: RepaintBoundary(child: GradientBackground(child: SizedBox.expand()))),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                stretch: true,
                expandedHeight: 345,
                backgroundColor: Color.lerp(tint, Colors.black, 0.75),
                foregroundColor: Colors.white,
                flexibleSpace: LayoutBuilder(
                  builder: (context, c) {
                    final top = MediaQuery.paddingOf(context).top;
                    final collapsed = c.maxHeight <= kToolbarHeight + top + 30;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        FlexibleSpaceBar(
                          stretchModes: const [StretchMode.zoomBackground],
                          background: _ReciterHero(reciter: r, tint: tint),
                        ),
                        PositionedDirectional(
                          top: top,
                          start: 56,
                          end: 16,
                          height: kToolbarHeight,
                          child: IgnorePointer(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: collapsed ? 1 : 0,
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(r.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'ابحث عن سورة',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: MediaDownloads.instance,
                builder: (context, _) => BlocBuilder<AudioCubit, AudioState>(
                  buildWhen: (p, c) =>
                      p.surah != c.surah || p.playing != c.playing || p.reciterId != c.reciterId || p.hasQueue != c.hasQueue,
                  builder: (context, audio) => SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 140),
                    sliver: SliverList.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final s = list[i];
                        final current = audio.hasQueue && audio.reciterId == r.id && audio.surah == s.number;
                        return _SurahTile(
                          reciter: r,
                          surah: s.number,
                          name: s.name,
                          meta: '${s.revelationAr} • ${ArabicUtils.toArabicDigits(s.ayahCount)} آية',
                          current: current,
                          playing: current && audio.playing,
                          glass: glass,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReciterHero extends StatelessWidget {
  final MediaReciter reciter;
  final Color tint;

  const _ReciterHero({required this.reciter, required this.tint});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(tint, Colors.black, 0.2)!, Color.lerp(tint, Colors.black, 0.88)!],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: LatticePainter(color: glass.accent.withValues(alpha: 0.08)))),
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 18),
                child: Column(
                  children: [
                    MonogramAvatar(name: reciter.name, seed: reciter.key.replaceAll('_mj', ''), size: 112),
                    const SizedBox(height: 12),
                    Text(reciter.name,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    ListenableBuilder(
                      listenable: MediaDownloads.instance,
                      builder: (context, _) {
                        final n = MediaDownloads.instance.countFor(reciter);
                        return Text(
                          'رواية حفص عن عاصم • ${reciter.style} • ١١٤ سورة'
                          '${n > 0 ? ' • ${ArabicUtils.toArabicDigits(n)} منزّلة' : ''}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 12.5),
                        );
                      },
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Pressable(
                            onTap: () => playMediaSurah(context, reciter, 1),
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF7E2A3), Color(0xFFE2C275), Color(0xFFA8812F)],
                                ),
                                boxShadow: [
                                  BoxShadow(color: const Color(0xFFE2C275).withValues(alpha: 0.35), blurRadius: 16),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.play_arrow_rounded, color: Colors.black, size: 28),
                                  SizedBox(width: 6),
                                  Text('تشغيل المصحف كاملًا',
                                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 15)),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _SurahTile extends StatelessWidget {
  final MediaReciter reciter;
  final int surah;
  final String name;
  final String meta;
  final bool current;
  final bool playing;
  final GlassTheme glass;

  const _SurahTile({
    required this.reciter,
    required this.surah,
    required this.name,
    required this.meta,
    required this.current,
    required this.playing,
    required this.glass,
  });

  @override
  Widget build(BuildContext context) {
    final dl = MediaDownloads.instance;
    final downloaded = dl.isDownloaded(reciter, surah);
    final progress = dl.progress(reciter, surah);
    final failed = dl.failed(reciter, surah);
    final primary = Theme.of(context).colorScheme.primary;

    Widget download;
    if (progress != null) {
      download = IconButton(
        tooltip: 'إلغاء التنزيل',
        onPressed: () => dl.cancel(reciter, surah),
        icon: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                value: progress == 0 ? null : progress,
                strokeWidth: 2.6,
                color: glass.accent,
                backgroundColor: glass.onGlass.withValues(alpha: 0.1),
              ),
            ),
            Icon(Icons.stop_rounded, size: 14, color: glass.accent),
          ],
        ),
      );
    } else if (downloaded) {
      download = IconButton(
        tooltip: 'محفوظة على الجهاز',
        onPressed: () => showGlassSnack(context, 'سورة $name محفوظة — تُسمع بدون إنترنت'),
        icon: Icon(Icons.offline_pin_rounded, color: glass.accent),
      );
    } else {
      download = IconButton(
        tooltip: failed ? 'إعادة المحاولة' : 'تنزيل',
        onPressed: () => dl.download(reciter, surah),
        icon: Icon(
          failed ? Icons.refresh_rounded : Icons.file_download_outlined,
          color: failed ? Colors.red.shade300 : glass.onGlassMuted,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Pressable(
        scale: 0.985,
        onTap: () => playMediaSurah(context, reciter, surah),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: current ? glass.accent.withValues(alpha: 0.14) : glass.onGlass.withValues(alpha: 0.045),
            border: Border.all(
              color: current ? glass.accent.withValues(alpha: 0.6) : glass.onGlass.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 46,
                child: current
                    ? Center(child: Equalizer(playing: playing, color: glass.accent, size: 22))
                    : StarNumber(number: surah, color: glass.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('سورة $name',
                        style: QuranFont.amiriQuran.style(
                            fontSize: 19, height: 1.45, color: current ? glass.accent : glass.onGlass)),
                    Text(meta, style: TextStyle(fontSize: 12, color: glass.onGlassMuted)),
                  ],
                ),
              ),
              download,
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: current ? glass.accent : primary.withValues(alpha: 0.16),
                ),
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: current ? Colors.black : glass.accent,
                  size: 26,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
