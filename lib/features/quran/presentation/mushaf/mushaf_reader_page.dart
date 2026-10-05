import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/surah_metadata.dart';
import '../../../../core/theme/app_themes.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/web_frame.dart';
import '../../../audio/presentation/cubit/audio_cubit.dart';
import '../../../audio/presentation/cubit/audio_state.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../stats/data/stats_repository.dart';
import '../../../stats/domain/stats_entities.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/ayah_ref.dart';
import '../../domain/repositories/quran_repository.dart';
import '../cubit/bookmarks_cubit.dart';
import '../cubit/quran_nav_cubit.dart';
import '../pages/quran_search_page.dart';
import '../../../tasmee/tasmee_page.dart';
import '../widgets/ayah_sheets.dart';
import '../../../wird/wird_tracker.dart';
import 'mushaf_page.dart';

/// The Mushaf: 604 swipeable pages in the app's theme.
///
/// Embedded as the Quran tab it remembers the exact page across tab switches
/// and app restarts. Other screens open it at a position with [open].
class MushafReaderPage extends StatefulWidget {
  final bool embedded;
  final int? page;
  final int? surah;
  final int? ayah;

  const MushafReaderPage({super.key, this.embedded = false, this.page, this.surah, this.ayah});

  /// Focus mode: header, footer and the app's bottom bar are hidden so only
  /// the Mushaf text remains. Toggled by tapping an empty spot on the page.
  static final ValueNotifier<bool> immersive = ValueNotifier(false);

  static void setImmersive(bool value) {
    if (immersive.value == value) return;
    immersive.value = value;
    // Hide only the status bar (the app keeps the top inset fixed, see
    // StableTopInset, so nothing re-lays out when it disappears).
    // Full focus: status bar and the system navigation/gesture bar hide too.
    // Insets are kept fixed by the app, so the Mushaf never re-lays out.
    SystemChrome.setEnabledSystemUIMode(value ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  /// Height of the app's bottom bar (+ mini player) floating over the Mushaf,
  /// reported by the home shell so the footer can sit above it.
  static final ValueNotifier<double> bottomOverlayHeight = ValueNotifier(0);

  /// Switches to the Quran tab at the given position (closing pushed screens).
  static void open(BuildContext context, {int? surah, int? ayah, int? page}) {
    context.read<QuranNavCubit>().openAt(page: page, surah: surah, ayah: ayah);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// Standalone full-screen reader (kept for compatibility).
  static Route<void> route({int? surah, int? ayah, int? page}) => MaterialPageRoute(
        builder: (_) => MushafReaderPage(surah: surah, ayah: ayah, page: page),
      );

  @override
  State<MushafReaderPage> createState() => _MushafReaderPageState();
}

class _MushafReaderPageState extends State<MushafReaderPage> {
  late final QuranRepository _repo = context.read<QuranRepository>();
  PageController? _controller;

  /// The controller counts spreads (two pages) instead of pages.
  bool _controllerSpread = false;
  int _page = 1;
  int? _selected;
  QuranNavRequest? _pending;
  final Set<int> _loggedPages = {};

  /// Largest bottom system inset seen; kept so hiding the gesture bar never
  /// changes the page size.
  double _bottomInset = 0;

  @override
  void initState() {
    super.initState();
    if (_repo.isReady) {
      _setup();
    } else {
      _repo.ensureLoaded().then((_) {
        if (mounted) setState(_setup);
      });
    }
  }

  void _setup() {
    var start = widget.page ?? 0;
    if (start == 0 && widget.surah != null) start = _repo.pageOf(widget.surah!, widget.ayah ?? 1);
    if (start == 0) start = context.read<BookmarksCubit>().lastPage ?? 1;
    start = start.clamp(1, QuranRepository.pageCount);
    _controller = PageController(initialPage: start - 1);
    _page = start;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onPageShown(_page);
    });
    if (widget.surah != null && widget.ayah != null) _flashSelection(SurahMetadata.globalAyah(widget.surah!, widget.ayah!));
    final pending = _pending ?? context.read<QuranNavCubit>().state;
    if (pending != null && widget.embedded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleRequest(pending));
    }
  }

  @override
  void dispose() {
    _wirdTimer?.cancel();
    _controller?.dispose();
    // Not during unmounting: the frame rebuilds at the end of this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => WebFrame.wide.value = false);
    if (!widget.embedded) MushafReaderPage.setImmersive(false);
    super.dispose();
  }

  void _flashSelection(int global) {
    _selected = global;
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && _selected == global) setState(() => _selected = null);
    });
  }

  void _handleRequest(QuranNavRequest r) {
    if (_controller == null) {
      _pending = r;
      return;
    }
    _pending = null;
    var target = r.page ?? 0;
    if (target == 0 && r.surah != null) target = _repo.pageOf(r.surah!, r.ayah ?? 1);
    if (target == 0) return;
    if (r.surah != null && r.ayah != null) setState(() => _flashSelection(SurahMetadata.globalAyah(r.surah!, r.ayah!)));
    _goTo(target, animate: false);
  }

  Timer? _wirdTimer;

  /// A page counts toward the daily wird after 4 seconds on screen.
  void _trackWird(int page) {
    _wirdTimer?.cancel();
    _wirdTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || _page != page) return;
      // Only while the Quran tab is actually on screen.
      if (widget.embedded && !TickerMode.of(context)) return;
      final goal = context.read<SettingsCubit>().state.wirdPages;
      final done = context.read<WirdTracker>().record(page, goal);
      if (done) showGlassSnack(context, 'أتممت وردك اليوم، تقبّل الله منك');
    });
  }

  void _onPageShown(int page, {bool withNext = false}) {
    if (withNext && page + 1 <= QuranRepository.pageCount) {
      final next = _repo.ayahsOnPage(page + 1);
      if (next.isNotEmpty && _loggedPages.add(page + 1)) {
        context.read<StatsRepository>().log(StatType.quranAyahs, next.length);
      }
      for (final p in [page + 2, page + 3]) {
        if (p <= QuranRepository.pageCount) MushafPageView.prewarm(p, _repo.linesOnPage(p));
      }
    }
    _trackWird(page);
    // Pre-build the neighbouring pages while the user reads this one.
    for (final p in [page + 1, page - 1, page + 2, page - 2]) {
      if (p >= 1 && p <= QuranRepository.pageCount) MushafPageView.prewarm(p, _repo.linesOnPage(p));
    }
    final ayahs = _repo.ayahsOnPage(page);
    if (ayahs.isEmpty) return;
    final bookmarks = context.read<BookmarksCubit>();
    bookmarks.saveLastPage(page);
    bookmarks.saveLastRead(ayahs.first.surah, ayahs.first.numberInSurah);
    if (_loggedPages.add(page)) context.read<StatsRepository>().log(StatType.quranAyahs, ayahs.length);
  }

  /// Controller index of [page] (its spread in two-page mode).
  int _indexOf(int page) {
    final p = page.clamp(1, QuranRepository.pageCount) - 1;
    return _controllerSpread ? p ~/ 2 : p;
  }

  /// Two pages side by side: 'double' on any screen wide enough, 'auto' only
  /// in landscape on a large screen (tablet, unfolded phone, computer).
  static bool _useSpread(String mode, double width, double height) => switch (mode) {
        'single' => false,
        'double' => width >= 600,
        _ => width >= 700 && width > height * 1.1,
      };

  PageController _controllerFor(bool spread) {
    final current = _controller!;
    if (spread == _controllerSpread) return current;
    _controllerSpread = spread;
    // keepPage off: the page view under the other key must not restore the
    // index it had before the switch.
    final next = PageController(initialPage: _indexOf(_page), keepPage: false);
    _controller = next;
    WidgetsBinding.instance.addPostFrameCallback((_) => current.dispose());
    return next;
  }

  void _goTo(int page, {bool animate = true}) {
    final c = _controller;
    if (c == null || !c.hasClients) return;
    final target = _indexOf(page);
    if (!animate || (target - (c.page ?? 0).round()).abs() > 2) {
      c.jumpToPage(target);
    } else {
      c.animateToPage(target, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    }
  }

  Future<void> _onAyahTap(int global) async {
    final a = _repo.ayahByNumber(global);
    if (a == null) return;
    HapticFeedback.selectionClick();
    setState(() => _selected = a.number);
    await showAyahActions(context, a);
    if (mounted) setState(() => _selected = null);
  }

  void _followAudio(AudioState audio) {
    if (!_repo.isReady || audio.surah == null || audio.ayah == null || audio.ayah! < 1) return;
    if (!context.read<SettingsCubit>().state.autoFollowAudio) return;
    final target = _repo.pageOf(audio.surah!, audio.ayah!);
    if (_indexOf(target) != _indexOf(_page)) _goTo(target);
  }

  void _playPage(int page) {
    final ayahs = _repo.ayahsOnPage(page);
    if (ayahs.isEmpty) return;
    context.read<AudioCubit>().playFromAyah(ayahs.first.surah, ayahs.first.numberInSurah);
  }

  Future<void> _openIndex([int tab = 0]) async {
    final page = await showGlassSheet<int>(
      context,
      builder: (ctx) => _IndexSheet(repo: _repo, currentPage: _page, initialTab: tab),
    );
    if (page != null) _goTo(page, animate: false);
  }

  /// Opens the wide-screen frame to the full width while the Mushaf is the
  /// visible screen (its tab, with nothing pushed over it but a sheet or a
  /// dialog).
  void _syncWideFrame() {
    final route = ModalRoute.of(context);
    final visible = TickerMode.of(context) &&
        (route == null || route.isCurrent || (route.isActive && WebFrame.popupOnTop));
    if (WebFrame.wide.value == visible) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) WebFrame.wide.value = visible;
    });
  }

  @override
  Widget build(BuildContext context) {
    _syncWideFrame();
    final style = MushafStyle.of(context);
    const headerH = 50.0;
    const footerH = 48.0;
    final sysBottom = MediaQuery.viewPaddingOf(context).bottom;
    if (sysBottom > _bottomInset) _bottomInset = sysBottom;
    final bottomInset = widget.embedded ? _bottomInset : 0.0;

    final highlighted = context.select<AudioCubit, int?>((c) {
      final s = c.state;
      if (!s.hasQueue || s.surah == null || s.ayah == null || s.ayah! < 1) return null;
      return SurahMetadata.globalAyah(s.surah!, s.ayah!);
    });

    final pagesMode = context.select<SettingsCubit, String>((c) => c.state.mushafPages);
    Widget pageView(int page) => MushafPageView(
          page: page,
          lines: _repo.linesOnPage(page),
          referenceWidth: _repo.referenceLineWidth,
          style: style,
          highlightedAyah: highlighted,
          selectedAyah: _selected,
          onAyahTap: _onAyahTap,
        );

    Widget pages = _controller == null
        ? const LoadingView()
        : LayoutBuilder(builder: (context, box) {
            final spread = _useSpread(pagesMode, box.maxWidth, box.maxHeight);
            final controller = _controllerFor(spread);
            return PageView.builder(
              key: ValueKey(spread),
              controller: controller,
              itemCount: spread ? (QuranRepository.pageCount + 1) ~/ 2 : QuranRepository.pageCount,
              allowImplicitScrolling: true,
              onPageChanged: (i) {
                final page = spread ? i * 2 + 1 : i + 1;
                setState(() => _page = page);
                _onPageShown(page, withNext: spread);
              },
              itemBuilder: (context, i) => RepaintBoundary(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(10, headerH, 10, footerH + bottomInset),
                  child: spread
                      ? _MushafSpread(
                          right: pageView(i * 2 + 1),
                          left: i * 2 + 2 <= QuranRepository.pageCount ? pageView(i * 2 + 2) : null,
                          divider: style.accent,
                        )
                      : _PageProportion(child: pageView(i + 1)),
                ),
              ),
            );
          });

    final ayahs = _controller == null ? const <Ayah>[] : _repo.ayahsOnPage(_page);
    Widget content = Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => MushafReaderPage.setImmersive(!MushafReaderPage.immersive.value),
            child: pages,
          ),
        ),
        if (ayahs.isNotEmpty)
          ValueListenableBuilder<bool>(
            valueListenable: MushafReaderPage.immersive,
            builder: (context, hidden, _) {
              final first = ayahs.first;
              Widget fade(Widget child) => IgnorePointer(
                    ignoring: hidden,
                    child: AnimatedOpacity(
                      opacity: hidden ? 0 : 1,
                      duration: const Duration(milliseconds: 220),
                      child: child,
                    ),
                  );
              return Stack(
                children: [
                  // Tools float over the page; the Mushaf just dims behind them.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: hidden ? 0 : 1,
                        duration: const Duration(milliseconds: 220),
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x99000000), Color(0x40000000), Color(0x40000000), Color(0xB3000000)],
                              stops: [0, 0.18, 0.7, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: headerH,
                    child: _Header(
                      first: first,
                      ayahs: ayahs,
                      style: style,
                      fade: fade,
                      onSurahs: () => _openIndex(0),
                      onIndex: () => _openIndex(0),
                      onSearch: () => Navigator.of(context).push(QuranSearchPage.route()),
                      onTasmee: () => Navigator.of(context).push(TasmeePage.route(page: first.page)),
                    ),
                  ),
                  ValueListenableBuilder<double>(
                    valueListenable: MushafReaderPage.bottomOverlayHeight,
                    builder: (context, navH, _) => AnimatedPositioned(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      left: 0,
                      right: 0,
                      height: footerH,
                      bottom: hidden || !widget.embedded ? bottomInset : navH,
                      child: _Footer(
                        page: _page,
                        first: first,
                        style: style,
                        fade: fade,
                        onJuz: () => _openIndex(1),
                        onPlay: () => _playPage(_page),
                        onSettings: () => showReaderSettingsSheet(context),
                        onClose: widget.embedded ? null : () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
    // Calm, flat page colour behind the text (no glows or patterns).
    content = DecoratedBox(
      decoration: BoxDecoration(color: _paperColor(context)),
      child: content,
    );
    content = SafeArea(bottom: !widget.embedded, child: content);

    content = MultiBlocListener(
      listeners: [
        BlocListener<AudioCubit, AudioState>(
          listenWhen: (p, c) => p.ayah != c.ayah || p.surah != c.surah,
          listener: (_, audio) => _followAudio(audio),
        ),
        BlocListener<QuranNavCubit, QuranNavRequest?>(
          listenWhen: (p, c) => c != null && widget.embedded,
          listener: (_, r) => _handleRequest(r!),
        ),
      ],
      child: content,
    );

    if (widget.embedded) return content;
    return Scaffold(backgroundColor: Colors.transparent, body: GradientBackground(child: content));
  }
}

Color _paperColor(BuildContext context) {
  final g = GlassTheme.of(context).backgroundGradient;
  final dark = Theme.of(context).brightness == Brightness.dark;
  return dark ? Color.lerp(g[0], g[1], 0.45)! : Color.lerp(g[0], Colors.white, 0.35)!;
}

/// Right: surah ▾ + search • centre: index • left: juz + bookmark.
/// In focus mode only the surah and juz chips stay.
class _Header extends StatelessWidget {
  final Ayah first;
  final List<Ayah> ayahs;
  final MushafStyle style;
  final VoidCallback onSurahs;
  final VoidCallback onIndex;
  final VoidCallback onSearch;
  final VoidCallback onTasmee;
  final Widget Function(Widget) fade;

  const _Header({
    required this.first,
    required this.ayahs,
    required this.style,
    required this.fade,
    required this.onSurahs,
    required this.onIndex,
    required this.onSearch,
    required this.onTasmee,
  });

  @override
  Widget build(BuildContext context) {
    final bookmarked = context.select<BookmarksCubit, bool>(
      (c) => ayahs.any((a) => c.state.isBookmarked(a.surah, a.numberInSurah)),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          _Chip(
            style: style,
            onTap: onSurahs,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  SurahMetadata.surah(first.surah).name,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: style.accent),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: style.accent),
              ],
            ),
          ),
          _ToolIcon(icon: Icons.search_rounded, color: style.accent, onTap: onSearch, tooltip: 'بحث'),
          const Spacer(),
          fade(_ToolIcon(icon: Icons.mic_rounded, color: style.accent, onTap: onTasmee, tooltip: 'التسميع')),
          fade(_ToolIcon(icon: Icons.grid_view_rounded, color: style.accent, onTap: onIndex, tooltip: 'الفهرس')),
          const Spacer(),
          _Chip(
            style: style,
            child: Text(
              juzName(first.juz),
              maxLines: 1,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: style.accent),
            ),
          ),
          _ToolIcon(
            icon: bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: style.accent,
            tooltip: 'حفظ موضع القراءة',
            onTap: () => context.read<BookmarksCubit>().toggleBookmark(first.surah, first.numberInSurah, text: first.text),
          ),
        ],
      ),
    );
  }
}

/// Right: page • hizb ▾ (opens the juz list) • left: settings + play.
class _Footer extends StatelessWidget {
  final int page;
  final Ayah first;
  final MushafStyle style;
  final Widget Function(Widget) fade;
  final VoidCallback onJuz;
  final VoidCallback onPlay;
  final VoidCallback onSettings;
  final VoidCallback? onClose;

  const _Footer({
    required this.page,
    required this.first,
    required this.style,
    required this.fade,
    required this.onJuz,
    required this.onPlay,
    required this.onSettings,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          _Chip(
            style: style,
            onTap: onJuz,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  first.hizb > 0
                      ? '${ArabicUtils.toArabicDigits(page)}   ${_hizbLabel(first)}'
                      : ArabicUtils.toArabicDigits(page),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: style.accent),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: style.accent),
              ],
            ),
          ),
          const Spacer(),
          fade(Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToolIcon(icon: Icons.tune_rounded, color: style.accent, onTap: onSettings, tooltip: 'إعدادات القراءة'),
              const SizedBox(width: 4),
              Material(
                color: style.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPlay,
                  child: const SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ),
              if (onClose != null) ...[
                const SizedBox(width: 4),
                _ToolIcon(icon: Icons.close_rounded, color: style.accent, onTap: onClose!, tooltip: 'إغلاق'),
              ],
            ],
          )),
        ],
      ),
    );
  }
}

String _hizbLabel(Ayah a) {
  const quarters = ['', '¼ ', '½ ', '¾ '];
  return '${quarters[a.quarterInHizb]}الحزب ${ArabicUtils.toArabicDigits(a.hizb)}';
}

class _Chip extends StatelessWidget {
  final Widget child;
  final MushafStyle style;
  final VoidCallback? onTap;

  const _Chip({required this.child, required this.style, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: style.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: style.accent.withValues(alpha: 0.55)),
        ),
        child: child,
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _ToolIcon({required this.icon, required this.color, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: color, size: 24),
      onPressed: onTap,
    );
  }
}

/// Surah / Juz / Bookmarks index.
class _IndexSheet extends StatefulWidget {
  final QuranRepository repo;
  final int currentPage;
  final int initialTab;

  const _IndexSheet({required this.repo, required this.currentPage, this.initialTab = 0});

  @override
  State<_IndexSheet> createState() => _IndexSheetState();
}

class _IndexSheetState extends State<_IndexSheet> {
  late int _tab = widget.initialTab;
  String _query = '';

  bool _matches(String text, int number) {
    final q = _query.trim();
    if (q.isEmpty) return true;
    final digits = q.replaceAllMapped(RegExp('[٠-٩]'), (m) => '${m[0]!.codeUnitAt(0) - 0x0660}');
    if (int.tryParse(digits) case final n?) return n == number;
    return ArabicUtils.normalize(text).contains(ArabicUtils.normalize(q));
  }

  List<({int juz, int page})> _juzStarts() {
    final result = <({int juz, int page})>[];
    var lastJuz = 0;
    for (var p = 1; p <= QuranRepository.pageCount; p++) {
      for (final a in widget.repo.ayahsOnPage(p)) {
        if (a.juz > lastJuz) {
          lastJuz = a.juz;
          result.add((juz: a.juz, page: p));
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: Column(
        children: [
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('السور')),
              ButtonSegment(value: 1, label: Text('الأجزاء')),
              ButtonSegment(value: 2, label: Text('العلامات')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          if (_tab != 2)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: _tab == 0 ? 'ابحث باسم السورة أو رقمها' : 'ابحث برقم الجزء أو اسمه',
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: switch (_tab) {
              0 => Builder(builder: (context) {
                  final list = [for (final info in SurahMetadata.all) if (_matches(info.name, info.number)) info];
                  return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final info = list[i];
                    final page = widget.repo.firstPageOfSurah(info.number);
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: glass.accent.withValues(alpha: 0.18),
                        child: Text(ArabicUtils.toArabicDigits(info.number),
                            style: TextStyle(fontSize: 12, color: glass.onGlass, fontWeight: FontWeight.w700)),
                      ),
                      title: Text('سورة ${info.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${info.revelationAr} • ${ArabicUtils.toArabicDigits(info.ayahCount)} آية'),
                      trailing: Text('ص ${ArabicUtils.toArabicDigits(page)}', style: TextStyle(color: glass.accent)),
                      onTap: () => Navigator.pop(context, page),
                    );
                  },
                );
                }),
              1 => Builder(builder: (context) {
                  final starts = [for (final j in _juzStarts()) if (_matches(juzName(j.juz), j.juz)) j];
                  return ListView.builder(
                    itemCount: starts.length,
                    itemBuilder: (context, i) {
                      final s = starts[i];
                      return ListTile(
                        dense: true,
                        title: Text(juzName(s.juz), style: const TextStyle(fontWeight: FontWeight.w700)),
                        trailing: Text('ص ${ArabicUtils.toArabicDigits(s.page)}', style: TextStyle(color: glass.accent)),
                        onTap: () => Navigator.pop(context, s.page),
                      );
                    },
                  );
                }),
              _ => BlocBuilder<BookmarksCubit, BookmarksState>(
                  builder: (context, state) {
                    final refs = <(AyahRef, bool)>[
                      for (final b in state.bookmarks) (b, false),
                      for (final f in state.favorites) (f, true),
                    ];
                    if (refs.isEmpty) {
                      return const MessageView(
                        icon: Icons.bookmark_border_rounded,
                        title: 'لا توجد علامات بعد',
                        subtitle: 'اضغط مطولًا على أي آية ثم «علامة» أو «مفضلة».',
                      );
                    }
                    return ListView.builder(
                      itemCount: refs.length,
                      itemBuilder: (context, i) {
                        final (r, fav) = refs[i];
                        final page = widget.repo.pageOf(r.surah, r.ayah);
                        return ListTile(
                          dense: true,
                          leading: Icon(fav ? Icons.favorite_rounded : Icons.bookmark_rounded, color: glass.accent),
                          title: Text(
                            'سورة ${SurahMetadata.surah(r.surah).name} • الآية ${ArabicUtils.toArabicDigits(r.ayah)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: r.text == null ? null : Text(r.text!, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Text('ص ${ArabicUtils.toArabicDigits(page)}', style: TextStyle(color: glass.accent)),
                          onTap: () => Navigator.pop(context, page),
                        );
                      },
                    );
                  },
                ),
            },
          ),
        ],
      ),
    );
  }
}

/// Mushaf page proportions (≈ 2:3). On a wide area (landscape, tablets) the
/// page keeps its shape in the centre instead of stretching its lines.
const double _pageAspect = 0.66;

class _PageProportion extends StatelessWidget {
  final Widget child;

  const _PageProportion({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (!c.hasBoundedHeight || c.maxWidth <= c.maxHeight * 0.72) return child;
      return Center(child: SizedBox(width: c.maxHeight * _pageAspect, height: c.maxHeight, child: child));
    });
  }
}

/// Two pages side by side like an open Mushaf: the odd page on the right.
class _MushafSpread extends StatelessWidget {
  final Widget right;
  final Widget? left;
  final Color divider;

  const _MushafSpread({required this.right, required this.left, required this.divider});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gutter = 22.0;
      final pageW = ((c.maxWidth - gutter) / 2).clamp(0.0, c.maxHeight * _pageAspect);
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: pageW, height: c.maxHeight, child: right),
            SizedBox(
              width: gutter,
              height: c.maxHeight * 0.9,
              child: Center(
                child: Container(
                  width: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [divider.withValues(alpha: 0), divider.withValues(alpha: 0.35), divider.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: pageW, height: c.maxHeight, child: left ?? const SizedBox.shrink()),
          ],
        ),
      );
    });
  }
}
