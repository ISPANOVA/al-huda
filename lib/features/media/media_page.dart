import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import '../../core/data/surah_metadata.dart';
import '../../core/theme/app_themes.dart';
import '../../core/utils/arabic_utils.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/state_views.dart';
import '../audio/data/audio_download_service.dart';
import '../audio/domain/reciter.dart';
import '../audio/presentation/cubit/audio_cubit.dart';
import '../audio/presentation/cubit/audio_state.dart';
import '../audio/presentation/cubit/downloads_cubit.dart';
import '../audio/presentation/pages/downloads_page.dart';

// ------------------------------------------------------------ sources ---

class _Live {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;

  /// Tried in order until one plays.
  final List<String> urls;

  const _Live(this.title, this.subtitle, this.icon, this.colors, this.urls);
}

const _lives = [
  _Live('مباشر الحرم المكي', 'المسجد الحرام • قناة القرآن الكريم', Icons.mosque_rounded,
      [Color(0xFF1B3A2F), Color(0xFF0B1A14)], [
    'https://cdn-globecast.akamaized.net/live/eds/saudi_quran/hls_roku/index.m3u8',
    'http://m.live.net.sa:1935/live/quran/playlist.m3u8',
  ]),
  _Live('مباشر الحرم النبوي', 'المسجد النبوي • قناة السنة النبوية', Icons.location_city_rounded,
      [Color(0xFF213049), Color(0xFF0C1322)], [
    'https://cdn-globecast.akamaized.net/live/eds/saudi_sunnah/hls_roku/index.m3u8',
    'http://m.live.net.sa:1935/live/sunnah/playlist.m3u8',
  ]),
];

class _Radio {
  final String name;
  final String url;

  const _Radio(this.name, this.url);
}

const _radios = [
  _Radio('إذاعة القرآن الكريم | السعودية', 'https://stream.radiojar.com/0tpy1h0kxtzuv'),
  _Radio('إذاعة القرآن الكريم | القاهرة', 'https://stream.radiojar.com/8s5u82pmwtzuv'),
];

// ------------------------------------------------------------- page ---

/// الوسائط: downloads, reciters (full surahs), live Haram streams, Quran radio.
class MediaPage extends StatelessWidget {
  const MediaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
      children: [
        Text('الوسائط', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        _DownloadsCard(onTap: () => Navigator.of(context).push(DownloadsPage.route())),
        _SectionTitle(
          'القرّاء',
          action: 'عرض الكل',
          onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AllRecitersPage())),
        ),
        _ReciterGrid(reciters: Reciters.all.take(9).toList()),
        const _SectionTitle('البث المباشر'),
        for (final l in _lives) _LiveCard(live: l),
        const _SectionTitle('إذاعة القرآن الكريم'),
        const _RadioCard(),
        const SizedBox(height: 8),
        Text(
          'البث المباشر والإذاعة يحتاجان اتصالًا بالإنترنت.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: glass.onGlassMuted),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const _SectionTitle(this.title, {this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(action!, style: TextStyle(color: glass.onGlassMuted)),
                  Icon(Icons.chevron_left_rounded, color: glass.onGlassMuted, size: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DownloadsCard extends StatelessWidget {
  final VoidCallback onTap;

  const _DownloadsCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return Material(
      color: glass.onGlass.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: glass.accent.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: glass.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.download_for_offline_rounded, color: glass.accent, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('تنزيلاتي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    Text('السور التي نزّلتها — تُسمع بلا إنترنت', style: TextStyle(color: glass.onGlassMuted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: glass.onGlassMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- reciters ---

/// Monogram portrait (no photos are bundled): initials on a soft gradient.
class ReciterAvatar extends StatelessWidget {
  final Reciter reciter;
  final double size;

  const ReciterAvatar({super.key, required this.reciter, this.size = 92});

  static String _initials(String name) {
    final parts = name.split(' ').where((p) => p.isNotEmpty && p != 'عبد' && p != 'أبو' && p != 'بن').toList();
    if (parts.isEmpty) return name.characters.first;
    final a = parts.first.replaceFirst('ال', '').characters.first;
    final b = parts.length > 1 ? parts.last.replaceFirst('ال', '').characters.first : '';
    return '$a $b'.trim();
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final hue = (reciter.id.hashCode % 360).abs().toDouble();
    final tint = HSLColor.fromAHSL(1, hue, 0.35, 0.32).toColor();
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: glass.accent.withValues(alpha: 0.75), width: 2),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color.lerp(tint, primary, 0.4)!, Color.lerp(tint, Colors.black, 0.45)!],
          ),
        ),
        child: Center(
          child: Text(
            _initials(reciter.nameAr),
            style: TextStyle(
              fontSize: size * 0.27,
              fontWeight: FontWeight.w900,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReciterGrid extends StatelessWidget {
  final List<Reciter> reciters;

  const _ReciterGrid({required this.reciters});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reciters.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 14,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, i) {
        final r = reciters[i];
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(ReciterSurahsPage.route(r)),
          child: Column(
            children: [
              Expanded(child: FittedBox(child: ReciterAvatar(reciter: r))),
              const SizedBox(height: 8),
              Text(r.nameAr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              if (r.style != 'مرتل')
                Text(r.style, style: TextStyle(fontSize: 11, color: GlassTheme.of(context).onGlassMuted)),
            ],
          ),
        );
      },
    );
  }
}

class AllRecitersPage extends StatelessWidget {
  const AllRecitersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'كل القرّاء',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: _ReciterGrid(reciters: Reciters.all),
      ),
    );
  }
}

/// 114 surahs of one reciter: play or download each.
class ReciterSurahsPage extends StatefulWidget {
  final Reciter reciter;

  const ReciterSurahsPage({super.key, required this.reciter});

  static Route<void> route(Reciter r) => MaterialPageRoute(builder: (_) => ReciterSurahsPage(reciter: r));

  @override
  State<ReciterSurahsPage> createState() => _ReciterSurahsPageState();
}

class _ReciterSurahsPageState extends State<ReciterSurahsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final list = [
      for (final s in SurahMetadata.all)
        if (_query.isEmpty || ArabicUtils.normalize(s.name).contains(ArabicUtils.normalize(_query)) || '${s.number}' == _query)
          s,
    ];
    return BlocProvider(
      create: (ctx) => DownloadsCubit(ctx.read<AudioDownloadService>(), widget.reciter.id),
      child: GlassScaffold(
        title: widget.reciter.nameAr,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'اختر سورة للاستماع أو ابحث باسمها',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: BlocBuilder<DownloadsCubit, DownloadsState>(
                builder: (context, d) => BlocBuilder<AudioCubit, AudioState>(
                  buildWhen: (p, c) => p.surah != c.surah || p.playing != c.playing || p.reciterId != c.reciterId,
                  builder: (context, audio) => ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final s = list[i];
                      final playingThis = audio.playing && audio.surah == s.number && audio.reciterId == widget.reciter.id;
                      final progress = d.progress[s.number];
                      final downloaded = d.downloaded.contains(s.number);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(ArabicUtils.toArabicDigits(s.number),
                                  style: TextStyle(fontWeight: FontWeight.w800, color: glass.accent)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('سورة ${s.name}',
                                      style: QuranFont.amiriQuran.style(fontSize: 19, height: 1.5, color: glass.onGlass)),
                                  Text('${s.revelationAr} • ${ArabicUtils.toArabicDigits(s.ayahCount)} آية',
                                      style: TextStyle(fontSize: 12, color: glass.onGlassMuted)),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 44,
                              child: progress != null
                                  ? Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(value: progress, strokeWidth: 2.5),
                                      ),
                                    )
                                  : IconButton(
                                      tooltip: downloaded ? 'تم التنزيل' : 'تنزيل',
                                      icon: Icon(
                                        downloaded ? Icons.download_done_rounded : Icons.download_rounded,
                                        color: downloaded ? glass.accent : glass.onGlassMuted,
                                      ),
                                      onPressed: downloaded ? null : () => context.read<DownloadsCubit>().download(s.number),
                                    ),
                            ),
                            IconButton(
                              iconSize: 40,
                              icon: Icon(
                                playingThis ? Icons.pause_circle_rounded : Icons.play_circle_outline_rounded,
                                color: primary,
                              ),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                final audioCubit = context.read<AudioCubit>();
                                if (playingThis) {
                                  audioCubit.togglePlay();
                                } else {
                                  audioCubit.playSurahWith(widget.reciter, s.number);
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- live TV ---

class _LiveCard extends StatelessWidget {
  final _Live live;

  const _LiveCard({required this.live});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: glass.accent.withValues(alpha: 0.3)),
        ),
        child: InkWell(
          onTap: () => Navigator.of(context).push(LiveStreamPage.route(live.title, live.urls)),
          child: Ink(
            height: 190,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: live.colors),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: -20,
                  bottom: -30,
                  child: Icon(live.icon, size: 190, color: Colors.white.withValues(alpha: 0.06)),
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0xFFE5484D), borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 8, color: Colors.white),
                        SizedBox(width: 6),
                        Text('مباشر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.3),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 38),
                  ),
                ),
                Positioned(
                  right: 18,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(live.title,
                          style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                      Text(live.subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen-capable HLS player for the live Haram channels.
class LiveStreamPage extends StatefulWidget {
  final String title;
  final List<String> urls;

  const LiveStreamPage({super.key, required this.title, required this.urls});

  static Route<void> route(String title, List<String> urls) =>
      MaterialPageRoute(builder: (_) => LiveStreamPage(title: title, urls: urls));

  @override
  State<LiveStreamPage> createState() => _LiveStreamPageState();
}

class _LiveStreamPageState extends State<LiveStreamPage> {
  VideoPlayerController? _controller;
  bool _failed = false;
  bool _fullscreen = false;

  @override
  void initState() {
    super.initState();
    final audio = context.read<AudioCubit>();
    if (audio.state.playing) audio.togglePlay();
    _start();
  }

  Future<void> _start() async {
    setState(() => _failed = false);
    for (final url in widget.urls) {
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      try {
        await c.initialize().timeout(const Duration(seconds: 15));
        if (!mounted) {
          await c.dispose();
          return;
        }
        await c.play();
        setState(() => _controller = c);
        return;
      } catch (_) {
        await c.dispose();
      }
    }
    if (mounted) setState(() => _failed = true);
  }

  Future<void> _toggleFullscreen() async {
    _fullscreen = !_fullscreen;
    if (_fullscreen) {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    if (_fullscreen) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final Widget video = _failed
        ? MessageView(
            icon: Icons.wifi_off_rounded,
            title: 'تعذر تشغيل البث الآن',
            subtitle: 'تأكد من اتصالك بالإنترنت ثم أعد المحاولة.',
            actionLabel: 'إعادة المحاولة',
            onAction: _start,
          )
        : c == null
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Center(
                child: AspectRatio(
                  aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
                  child: VideoPlayer(c),
                ),
              );
    return PopScope(
      canPop: !_fullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _toggleFullscreen();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _fullscreen
            ? null
            : AppBar(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                title: Text(widget.title),
              ),
        body: Stack(
          children: [
            Positioned.fill(child: video),
            if (c != null)
              Positioned(
                left: 12,
                bottom: 12,
                child: SafeArea(
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        icon: Icon(c.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        onPressed: () async {
                          c.value.isPlaying ? await c.pause() : await c.play();
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: Icon(_fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded),
                        onPressed: _toggleFullscreen,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ radio ---

class _RadioCard extends StatefulWidget {
  const _RadioCard();

  @override
  State<_RadioCard> createState() => _RadioCardState();
}

class _RadioCardState extends State<_RadioCard> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final radio = _radios[_index];
    return BlocBuilder<AudioCubit, AudioState>(
      buildWhen: (p, c) => p.title != c.title || p.playing != c.playing || p.buffering != c.buffering,
      builder: (context, audio) {
        final isThis = audio.hasQueue && audio.title == radio.name;
        final playing = isThis && audio.playing;
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              colors: [Color.lerp(primary, Colors.black, 0.15)!, Color.lerp(primary, Colors.black, 0.5)!],
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.radio_rounded, color: Colors.white, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: PopupMenuButton<int>(
                  initialValue: _index,
                  onSelected: (i) => setState(() => _index = i),
                  itemBuilder: (_) => [
                    for (var i = 0; i < _radios.length; i++) PopupMenuItem(value: i, child: Text(_radios[i].name)),
                  ],
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              radio.name.replaceFirst('إذاعة ', ''),
                              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              playing ? 'يُبث الآن على مدار الساعة' : 'اضغط لاختيار الإذاعة',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down_rounded, color: Colors.white),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    final cubit = context.read<AudioCubit>();
                    if (isThis) {
                      cubit.togglePlay();
                    } else {
                      cubit.playRadio(radio.url, radio.name);
                    }
                  },
                  child: SizedBox(
                    width: 58,
                    height: 58,
                    child: isThis && audio.buffering
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: primary),
                          )
                        : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: primary, size: 34),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
