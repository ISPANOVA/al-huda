import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/web_lite.dart';
import '../../core/theme/app_themes.dart';
import '../../core/utils/arabic_utils.dart';
import '../../core/widgets/state_views.dart';
import '../audio/presentation/cubit/audio_cubit.dart';
import '../audio/presentation/cubit/audio_state.dart';
import 'live_stream_page.dart';
import 'media_catalog.dart';
import 'media_downloads.dart';
import 'media_downloads_page.dart';
import 'media_widgets.dart';
import 'reciter_pages.dart';

class _Live {
  final String title;
  final String subtitle;
  final bool makkah;
  final List<Color> colors;
  final List<String> urls;

  const _Live(this.title, this.subtitle, this.makkah, this.colors, this.urls);
}

const _lives = [
  _Live('الحرم المكي', 'المسجد الحرام • قناة القرآن الكريم', true, [Color(0xFF2A2210), Color(0xFF0A0906)], [
    'https://cdn-globecast.akamaized.net/live/eds/saudi_quran/hls_roku/index.m3u8',
  ]),
  _Live('الحرم النبوي', 'المسجد النبوي • قناة السنة النبوية', false, [Color(0xFF0E2A22), Color(0xFF05100D)], [
    'https://cdn-globecast.akamaized.net/live/eds/saudi_sunnah/hls_roku/index.m3u8',
  ]),
];

Future<void> playStation(BuildContext context, MediaRadio radio) async {
  HapticFeedback.selectionClick();
  final cubit = context.read<AudioCubit>();
  final s = cubit.state;
  if (s.hasQueue && s.isLive && s.title == radio.name) {
    cubit.togglePlay();
    return;
  }
  final ok = await cubit.playRadio(radio.urls, radio.name, artist: radio.subtitle ?? 'بث مباشر على مدار الساعة');
  if (!ok && context.mounted) showGlassSnack(context, 'تعذر تشغيل ${radio.name} الآن، حاول مرة أخرى');
}

/// الوسائط — live Haram channels, Quran radio and full-surah recitations.
class MediaPage extends StatefulWidget {
  const MediaPage({super.key});

  @override
  State<MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<MediaPage> {
  @override
  void initState() {
    super.initState();
    MediaDownloads.instance.init();
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        const SliverToBoxAdapter(child: MediaHeader()),
        const SliverToBoxAdapter(child: LiveCarousel()),
        const SliverToBoxAdapter(
          child: MediaSectionHeader('الإذاعات', subtitle: 'بث متواصل على مدار الساعة'),
        ),
        const SliverToBoxAdapter(child: _OfficialStations()),
        SliverToBoxAdapter(
          child: MediaSectionHeader(
            'القرّاء',
            subtitle: kIsWeb ? 'المصحف كاملًا بأصوات كبار القراء' : 'المصحف كاملًا • استمع أو حمّل للاستماع بلا إنترنت',
            action: 'الكل (${ArabicUtils.toArabicDigits(MediaCatalog.reciters.length)})',
            onAction: () => Navigator.of(context).push(AllRecitersPage.route()),
          ),
        ),
        const SliverToBoxAdapter(child: _FeaturedReciters()),
        const SliverToBoxAdapter(
          child: MediaSectionHeader('إذاعات القرّاء', subtitle: 'تلاوات متواصلة لقارئك المفضل'),
        ),
        const SliverToBoxAdapter(child: _ReciterRadios()),
        const SliverToBoxAdapter(child: MediaSectionHeader('إذاعات منوعة')),
        const SliverPadding(padding: EdgeInsets.symmetric(horizontal: 16), sliver: _ThemeRadiosGrid()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 140),
            child: Text(
              'البث المباشر والإذاعات تحتاج اتصالًا بالإنترنت • التلاوات مقدّمة من mp3quran.net',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: glass.onGlassMuted),
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ header ---

class MediaHeader extends StatelessWidget {
  const MediaHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (r) => LinearGradient(
                    colors: [glass.accent, Color.lerp(glass.accent, glass.onGlass, 0.45)!],
                  ).createShader(r),
                  child: const Text('الوسائط', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1.2)),
                ),
                Text(kIsWeb ? 'استمع • شاهد' : 'استمع • شاهد • حمّل', style: TextStyle(color: glass.onGlassMuted, letterSpacing: 0.3)),
              ],
            ),
          ),
          if (MediaDownloads.supported)
          ListenableBuilder(
            listenable: MediaDownloads.instance,
            builder: (context, _) {
              final n = MediaDownloads.instance.totalCount;
              return Pressable(
                onTap: () => Navigator.of(context).push(MediaDownloadsPage.route()),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: glass.accent.withValues(alpha: 0.12),
                    border: Border.all(color: glass.accent.withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.download_for_offline_rounded, color: glass.accent),
                      const SizedBox(width: 6),
                      Text('تنزيلاتي', style: TextStyle(fontWeight: FontWeight.w800, color: glass.onGlass)),
                      if (n > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(color: glass.accent, borderRadius: BorderRadius.circular(10)),
                          child: Text(ArabicUtils.toArabicDigits(n),
                              style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------- live TV ---

class LiveCarousel extends StatefulWidget {
  const LiveCarousel({super.key});

  @override
  State<LiveCarousel> createState() => _LiveCarouselState();
}

class _LiveCarouselState extends State<LiveCarousel> {
  final _controller = PageController(viewportFraction: 0.88);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return Column(
      children: [
        SizedBox(
          height: 238,
          child: PageView.builder(
            controller: _controller,
            itemCount: _lives.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                var delta = 0.0;
                if (_controller.hasClients && _controller.position.haveDimensions) {
                  delta = ((_controller.page ?? 0) - i).abs().clamp(0.0, 1.0);
                }
                return Transform.scale(scale: 1 - delta * 0.06, child: child);
              },
              child: _LiveCard(live: _lives[i]),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _lives.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: i == _page ? glass.accent : glass.onGlass.withValues(alpha: 0.2),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _LiveCard extends StatelessWidget {
  final _Live live;

  const _LiveCard({required this.live});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE2C275);
    return Pressable(
      onTap: () => Navigator.of(context).push(LiveStreamPage.route(live.title, live.urls)),
      child: Container(
        margin: const EdgeInsets.fromLTRB(6, 4, 6, 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: live.colors),
          border: Border.all(color: gold.withValues(alpha: 0.35)),
          boxShadow: liteShadows([BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))]),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: LatticePainter(color: Color(0x14E2C275)))),
            // moon glow
            Positioned(
              top: -40,
              left: -30,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [gold.withValues(alpha: 0.28), Colors.transparent]),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 100,
              child: CustomPaint(painter: SkylinePainter(color: gold.withValues(alpha: 0.26), makkah: live.makkah)),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.82)],
                    stops: const [0.35, 1],
                  ),
                ),
              ),
            ),
            const PositionedDirectional(top: 16, start: 16, child: LiveBadge()),
            PositionedDirectional(
              top: 14,
              end: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hd_rounded, size: 16, color: Colors.white70),
                    SizedBox(width: 4),
                    Text('بث فيديو', style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            PositionedDirectional(
              start: 20,
              end: 20,
              bottom: 18,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('مباشر من', style: TextStyle(color: gold.withValues(alpha: 0.9), fontWeight: FontWeight.w700)),
                        Text(live.title,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1.25)),
                        Text(live.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12.5)),
                      ],
                    ),
                  ),
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [Color(0xFFF7E2A3), gold, Color(0xFFA8812F)]),
                      boxShadow: liteShadows([BoxShadow(color: gold.withValues(alpha: 0.5), blurRadius: 18)]),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 36),
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

// ------------------------------------------------------ radio stations ---

class _OfficialStations extends StatefulWidget {
  const _OfficialStations();

  @override
  State<_OfficialStations> createState() => _OfficialStationsState();
}

class _OfficialStationsState extends State<_OfficialStations> with SingleTickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _waves = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void dispose() {
    _waves.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final station = kOfficialRadios[_index];
    return BlocBuilder<AudioCubit, AudioState>(
      buildWhen: (p, c) =>
          p.title != c.title || p.playing != c.playing || p.buffering != c.buffering || p.isLive != c.isLive,
      builder: (context, audio) {
        final isThis = audio.hasQueue && audio.isLive && audio.title == station.name;
        final playing = isThis && audio.playing;
        if (playing && animateDecorations && !_waves.isAnimating) {
          _waves.repeat();
        } else if (!playing && _waves.isAnimating) {
          _waves.stop();
        }
        final dark = Color.lerp(primary, Colors.black, 0.78)!;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color.lerp(primary, Colors.black, 0.45)!, dark],
              ),
              border: Border.all(color: glass.accent.withValues(alpha: 0.35)),
            ),
            child: Stack(
              children: [
                PositionedDirectional(
                  end: -50,
                  top: -50,
                  child: RepaintBoundary(
                    child: SizedBox(
                      width: 230,
                      height: 230,
                      child: CustomPaint(painter: _WavesPainter(_waves, glass.accent)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              color: glass.accent.withValues(alpha: 0.18),
                            ),
                            child: Icon(Icons.radio_rounded, color: glass.accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  child: Text(
                                    station.name,
                                    key: ValueKey(station.name),
                                    style: const TextStyle(color: Colors.white, fontSize: 17.5, fontWeight: FontWeight.w900),
                                  ),
                                ),
                                Row(
                                  children: [
                                    if (playing) ...[
                                      Equalizer(playing: true, color: glass.accent, size: 13),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      playing
                                          ? 'يُبث الآن'
                                          : (isThis && audio.buffering ? 'جارٍ الاتصال…' : station.subtitle ?? ''),
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12.5),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Pressable(
                            onTap: () => playStation(context, station),
                            child: Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: glass.accent,
                                boxShadow: liteShadows([BoxShadow(color: glass.accent.withValues(alpha: 0.45), blurRadius: 18)]),
                              ),
                              child: isThis && audio.buffering
                                  ? const Padding(
                                      padding: EdgeInsets.all(19),
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                                    )
                                  : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      color: Colors.black, size: 36),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          for (var i = 0; i < kOfficialRadios.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: Pressable(
                                onTap: () => setState(() => _index = i),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: i == _index ? Colors.white : Colors.white.withValues(alpha: 0.08),
                                  ),
                                  child: Text(
                                    kOfficialRadios[i].name.contains('القاهرة') ? 'القاهرة' : 'السعودية',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: i == _index ? dark : Colors.white.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WavesPainter extends CustomPainter {
  final AnimationController t;
  final Color color;

  _WavesPainter(this.t, this.color) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final max = size.width / 2;
    for (var i = 0; i < 4; i++) {
      final f = (t.value + i / 4) % 1;
      final r = max * (0.25 + 0.75 * f);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = color.withValues(alpha: (t.isAnimating ? 0.35 : 0.12) * (1 - f)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavesPainter old) => old.color != color;
}

class _ReciterRadios extends StatelessWidget {
  const _ReciterRadios();

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return SizedBox(
      height: 124,
      child: BlocBuilder<AudioCubit, AudioState>(
        buildWhen: (p, c) => p.title != c.title || p.playing != c.playing || p.isLive != c.isLive,
        builder: (context, audio) => ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: kReciterRadios.length,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (context, i) {
            final radio = kReciterRadios[i];
            final playing = audio.hasQueue && audio.isLive && audio.title == radio.name && audio.playing;
            return Pressable(
              onTap: () => playStation(context, radio),
              child: SizedBox(
                width: 78,
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: playing ? glass.accent : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: MonogramAvatar(name: radio.name, seed: radio.reciterKey ?? radio.name, size: 70),
                        ),
                        if (playing)
                          PositionedDirectional(
                            bottom: -2,
                            end: -2,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(color: glass.accent, shape: BoxShape.circle),
                              child: const Equalizer(playing: true, color: Colors.black, size: 13),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      radio.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        color: playing ? glass.accent : glass.onGlass,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ThemeRadiosGrid extends StatelessWidget {
  const _ThemeRadiosGrid();

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return BlocBuilder<AudioCubit, AudioState>(
      buildWhen: (p, c) => p.title != c.title || p.playing != c.playing || p.isLive != c.isLive,
      builder: (context, audio) => SliverGrid.builder(
        itemCount: kThemeRadios.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 70,
        ),
        itemBuilder: (context, i) {
          final radio = kThemeRadios[i];
          final playing = audio.hasQueue && audio.isLive && audio.title == radio.name && audio.playing;
          final tint = mediaTint(radio.name, s: 0.5, l: 0.42);
          return Pressable(
            onTap: () => playStation(context, radio),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: playing ? glass.accent.withValues(alpha: 0.16) : glass.onGlass.withValues(alpha: 0.05),
                border: Border.all(
                  color: playing ? glass.accent.withValues(alpha: 0.7) : glass.onGlass.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(colors: [tint, Color.lerp(tint, Colors.black, 0.5)!]),
                    ),
                    child: Icon(radio.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      radio.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w800, color: glass.onGlass),
                    ),
                  ),
                  if (playing) Equalizer(playing: true, color: glass.accent, size: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// -------------------------------------------------------- reciters ---

class _FeaturedReciters extends StatelessWidget {
  const _FeaturedReciters();

  @override
  Widget build(BuildContext context) {
    final list = MediaCatalog.featured;
    return SizedBox(
      height: 206,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => SizedBox(width: 142, child: ReciterCard(reciter: list[i])),
      ),
    );
  }
}
