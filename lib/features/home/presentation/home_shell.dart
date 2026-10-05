import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/web_lite.dart';
import '../../../core/services/home_widgets.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/arabic_utils.dart';
import '../../quran/domain/repositories/quran_repository.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_themes.dart';
import '../../../core/theme/tones.dart';
import '../../../core/theme/page_transitions.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../athkar/presentation/cubit/athkar_cubit.dart';
import '../../athkar/presentation/pages/athkar_pages.dart';
import '../../media/media_page.dart';
import '../../calendar/islamic_calendar.dart';
import '../../settings/presentation/cubit/settings_cubit.dart';
import '../../audio/presentation/widgets/mini_player.dart';
import '../../prayer/domain/prayer_entities.dart';
import '../../prayer/presentation/cubit/prayer_cubit.dart';
import '../../prayer/presentation/pages/prayer_times_page.dart';
import '../../prayer/presentation/widgets/exact_alarm_prompt.dart';
import '../../quran/presentation/cubit/quran_nav_cubit.dart';
import '../../quran/presentation/mushaf/mushaf_reader_page.dart';
import '../../quran/presentation/mushaf/reader_guide.dart';
import '../../stats/presentation/stats_page.dart';
import 'dashboard_page.dart';
import 'more_page.dart';

/// Root scaffold: gradient background, tab pages, mini player and the
/// bottom navigation bar (attached to the screen edge, part of the page).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const _lastTabKey = 'last_tab';
  static const quranTab = 1;

  late int _index;

  /// Each tab has its colour (the same one its shortcuts and cards use).
  static const _tabs = [
    (icon: Icons.home_outlined, active: Icons.home_rounded, label: 'الرئيسية', tone: Tone.gold),
    (icon: Icons.menu_book_outlined, active: Icons.menu_book_rounded, label: 'المصحف', tone: Tone.emerald),
    (icon: Icons.headphones_outlined, active: Icons.headphones_rounded, label: 'الوسائط', tone: Tone.amethyst),
    (icon: Icons.access_time, active: Icons.access_time_filled_rounded, label: 'الصلاة', tone: Tone.sapphire),
    (icon: Icons.favorite_border_rounded, active: Icons.favorite_rounded, label: 'الأذكار', tone: Tone.rose),
    (icon: Icons.grid_view_outlined, active: Icons.grid_view_rounded, label: 'المزيد', tone: Tone.teal),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MushafReaderPage.immersive.addListener(_onImmersive);
    NotificationService.openRequest.addListener(_onNotificationOpen);
    // Reopen the Quran where the reader left it if the app was closed there.
    final saved = (context.read<StorageService>().settings.get(_lastTabKey) as num?)?.toInt();
    _index = saved == quranTab ? quranTab : 0;
    // Ask for notification permission on open (no-op once granted); the
    // location prompt is triggered by PrayerCubit when it locates the user.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _askAlertPermissions();
      if (mounted && _index == quranTab) _guide();
      _onNotificationOpen();
      if (mounted) _pushDailyAyahs();
      if (mounted) {
        IslamicCalendar.scheduleReminders(
          context.read<NotificationService>(),
          enabled: context.read<SettingsCubit>().state.occasionReminders,
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    MushafReaderPage.immersive.removeListener(_onImmersive);
    NotificationService.openRequest.removeListener(_onNotificationOpen);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AthkarCubit>().refreshDay();
      context.read<StatsCubit>().refresh();
      _recheckExactAlarms();
    }
  }

  /// Two months of "ayah of the day" for the home-screen widget.
  Future<void> _pushDailyAyahs() async {
    final repo = context.read<QuranRepository>();
    await repo.ensureLoaded();
    final now = DateTime.now();
    final items = <({DateTime date, String text, int surah, int ayah})>[];
    for (var i = 0; i < 60; i++) {
      final date = DateTime(now.year, now.month, now.day + i);
      final g = dailyAyahNumber(date, (n) => repo.ayahByNumber(n)?.text.length ?? 0);
      final a = repo.ayahByNumber(g);
      if (a == null) continue;
      items.add((date: date, text: '${a.text}\u00A0${ArabicUtils.toArabicDigits(a.numberInSurah)}', surah: a.surah, ayah: a.numberInSurah));
    }
    await HomeWidgets.updateAyahs(items);
  }

  Future<void> _askAlertPermissions() async {
    final n = context.read<NotificationService>();
    final settings = context.read<StorageService>().settings;
    await n.requestPermissions();
    // Exact alarms make the adhan ring on time; ask once if the system denies them.
    if (settings.get('exact_alarm_asked') != true && !await n.canScheduleExact()) {
      await settings.put('exact_alarm_asked', true);
      if (mounted) await askExactAlarms(context);
    }
  }

  /// Back from the system settings: once exact alarms are allowed, the
  /// adhan is scheduled again to the minute.
  Future<void> _recheckExactAlarms() async {
    final before = NotificationService.exactAllowed.value;
    final ok = await context.read<NotificationService>().canScheduleExact();
    if (!before && ok && mounted) context.read<PrayerCubit>().reschedule();
  }

  void _onImmersive() {}

  /// First visit to the Mushaf: a short tour of how it works.
  void _guide() {
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted && _index == quranTab) ReaderGuide.showOnce(context);
    });
  }

  /// Opens the screen a tapped notification points to.
  void _onNotificationOpen() {
    final payload = NotificationService.openRequest.value;
    if (payload == null || !mounted) return;
    NotificationService.openRequest.value = null;
    if (payload.startsWith('athkar:')) {
      Navigator.of(context).push(AthkarListPage.route(payload.substring(7)));
    }
  }

  Widget _bar() => RepaintBoundary(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [const MiniPlayer(), _BottomNav(index: _index, onTap: _go)],
        ),
      );

  void _go(int i) {
    if (i == _index) return;
    MushafReaderPage.setImmersive(false);
    setState(() => _index = i);
    context.read<StorageService>().settings.put(_lastTabKey, i);
    if (i == quranTab) _guide();
  }

  List<Widget> get _pages => [
        DashboardPage(onNavigate: _go),
        const MushafReaderPage(embedded: true),
        const MediaPage(),
        const PrayerTimesPage(),
        const AthkarHomePage(),
        const MorePage(),
      ];

  /// Tablet / computer: navigation on the side, pages use the width.
  Widget _wideBody() {
    final expanded = MediaQuery.sizeOf(context).width >= Adaptive.expanded;
    return Row(
      children: [
        _SideNav(index: _index, onTap: _go, expanded: expanded),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: FadeThroughIndexedStack(
                  index: _index,
                  children: [
                    DashboardPage(onNavigate: _go),
                    const MushafReaderPage(embedded: true),
                    const MaxWidth(maxWidth: 1100, child: MediaPage()),
                    const MaxWidth(maxWidth: 960, child: PrayerTimesPage()),
                    const MaxWidth(maxWidth: 1100, child: AthkarHomePage()),
                    const MaxWidth(maxWidth: 1000, child: MorePage()),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MaxWidth(
                  maxWidth: 720,
                  child: _SizeReporter(
                    onHeight: (h) => MushafReaderPage.bottomOverlayHeight.value = h,
                    child: const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: RepaintBoundary(child: MiniPlayer()),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final wide = Adaptive.isWide(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The phone home's sky is dark at the top: light status-bar icons.
      value: dark || (_index == 0 && !wide) ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: BlocListener<QuranNavCubit, QuranNavRequest?>(
        listener: (_, r) {
          if (r != null) _go(quranTab);
        },
        child: ValueListenableBuilder<bool>(
          valueListenable: MushafReaderPage.immersive,
          builder: (context, hidden, child) => PopScope(
            canPop: _index == 0 && !hidden,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (MushafReaderPage.immersive.value) {
                MushafReaderPage.setImmersive(false);
              } else {
                _go(0);
              }
            },
            child: child!,
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: GradientBackground(
              child: _StableTopInset(
                quranTab: _index == quranTab,
                homeSky: _index == 0 && !wide,
                child: wide ? _wideBody() : Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: FadeThroughIndexedStack(index: _index, children: _pages),
                        ),
                      ],
                    ),
                    // The bar floats over every tab (pages keep their size, so
                    // switching tabs never re-lays out the Mushaf) and
                    // disappears entirely in Mushaf focus mode.
                    Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: ValueListenableBuilder<bool>(
                          valueListenable: MushafReaderPage.immersive,
                          builder: (context, immersive, child) {
                            final hidden = immersive && _index == quranTab;
                            return IgnorePointer(
                            ignoring: hidden,
                            child: AnimatedSlide(
                              offset: hidden ? const Offset(0, 1) : Offset.zero,
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOutCubic,
                              child: AnimatedOpacity(
                                opacity: hidden ? 0 : 1,
                                duration: const Duration(milliseconds: 200),
                                child: child,
                              ),
                            ),
                          );
                          },
                          child: _SizeReporter(
                            onHeight: (h) => MushafReaderPage.bottomOverlayHeight.value = h,
                            child: _bar(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Side navigation for tablets and computers: the app's name, then the tabs
/// (labels beside the icons when there is room, under them otherwise).
class _SideNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final bool expanded;

  const _SideNav({required this.index, required this.onTap, required this.expanded});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = glass.backgroundGradient.last;
    final surface = dark ? Color.lerp(base, Colors.black, 0.35)! : Color.lerp(base, Colors.white, 0.7)!;
    const tabs = _HomeShellState._tabs;
    final width = expanded ? 236.0 : 96.0;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.92),
        border: BorderDirectional(end: BorderSide(color: glass.accent.withValues(alpha: dark ? 0.16 : 0.28))),
      ),
      child: SafeArea(
        right: false,
        left: false,
        child: Column(
          children: [
            const SizedBox(height: 22),
            Image.asset('assets/icon/logo_mark.png', width: expanded ? 64 : 48, height: expanded ? 64 : 48),
            if (expanded) ...[
              const SizedBox(height: 8),
              Text('الهدى',
                  style: TextStyle(fontFamily: AppFonts.display, fontSize: 30, fontWeight: FontWeight.w700, color: glass.accent)),
              Text('رفيقك اليومي مع القرآن', style: TextStyle(fontSize: 12.5, color: glass.onGlassMuted)),
            ],
            const SizedBox(height: 22),
            for (var i = 0; i < tabs.length; i++)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: expanded ? 14 : 10, vertical: 4),
                child: _SideNavItem(
                  icon: i == index ? tabs[i].active : tabs[i].icon,
                  label: tabs[i].label,
                  selected: i == index,
                  expanded: expanded,
                  tone: tabs[i].tone,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTap(i);
                  },
                ),
              ),
            const Spacer(),
            if (expanded) const _RailNextPrayer(),
          ],
        ),
      ),
    );
  }
}

/// The next prayer at the foot of the side navigation.
class _RailNextPrayer extends StatelessWidget {
  const _RailNextPrayer();

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return BlocBuilder<PrayerCubit, PrayerState>(
      buildWhen: (p, c) => p.next != c.next || p.countdown.inMinutes != c.countdown.inMinutes,
      builder: (context, s) {
        final next = s.next;
        if (next == null) return const SizedBox(height: 16);
        return Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 18),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: glass.accent.withValues(alpha: 0.10),
            border: Border.all(color: glass.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.access_time_filled_rounded, color: glass.accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${next.name.nameOn(next.time)} • ${ArabicUtils.formatTime(next.time)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w800, color: glass.onGlass)),
                    Text('باقي ${ArabicUtils.formatDuration(s.countdown, withSeconds: false)}',
                        style: TextStyle(fontSize: 12, color: glass.onGlassMuted)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SideNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool expanded;
  final Tone tone;
  final VoidCallback onTap;

  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.tone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = selected ? Colors.white : glass.onGlassMuted;
    final iconColor = selected ? Colors.white : (dark ? tone.light : tone.deep).withValues(alpha: 0.85);
    final content = expanded
        ? Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 14),
              Text(label, style: TextStyle(color: fg, fontSize: 15.5, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(height: 4),
              Text(label,
                  maxLines: 1,
                  style: TextStyle(color: fg, fontSize: 11, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
            ],
          );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          height: expanded ? 52 : 66,
          padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 4),
          alignment: expanded ? AlignmentDirectional.centerStart : Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: selected ? tone.gradient() : null,
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Floating, pill-style navigation: the selected tab grows into a capsule
/// with its label; the others show icons only.
class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = glass.backgroundGradient.last;
    final surface = dark ? Color.lerp(base, Colors.black, 0.45)! : Color.lerp(base, Colors.white, 0.75)!;
    final bottom = MediaQuery.paddingOf(context).bottom;
    const tabs = _HomeShellState._tabs;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 4, 14, 10 + bottom),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: glass.accent.withValues(alpha: dark ? 0.18 : 0.3)),
          boxShadow: liteShadows([
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.45 : 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ]),
        ),
        padding: const EdgeInsets.all(7),
        child: LayoutBuilder(builder: (context, c) {
          final selectedW = c.maxWidth * 0.31;
          final otherW = (c.maxWidth - selectedW) / (tabs.length - 1);
          return Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTap(i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 360),
                    curve: Curves.easeOutCubic,
                    width: i == index ? selectedW : otherW,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: i == index ? tabs[i].tone.gradient() : null,
                    ),
                    child: ClipRect(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            scale: i == index ? 1.08 : 1,
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              i == index ? tabs[i].active : tabs[i].icon,
                              size: 23,
                              color: i == index
                                  ? Colors.white
                                  : (dark ? tabs[i].tone.light : tabs[i].tone.deep).withValues(alpha: 0.72),
                            ),
                          ),
                          if (i == index)
                            Flexible(
                              child: Padding(
                                padding: const EdgeInsetsDirectional.only(start: 6),
                                child: TweenAnimationBuilder<double>(
                                  key: ValueKey(index),
                                  tween: Tween(begin: 0, end: 1),
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeOut,
                                  builder: (context, v, child) => Opacity(opacity: v, child: child),
                                  child: Text(
                                    tabs[i].label,
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    softWrap: false,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

/// Top safe-area padding that never shrinks while the app runs, so hiding the
/// status bar (Mushaf focus mode) doesn't push the whole layout up and down.
/// On the Quran tab the strip is painted in the Mushaf paper colour.
class _StableTopInset extends StatefulWidget {
  final bool quranTab;

  /// Phone home: the strip takes the colour of the sky beneath it.
  final bool homeSky;
  final Widget child;

  const _StableTopInset({required this.quranTab, this.homeSky = false, required this.child});

  @override
  State<_StableTopInset> createState() => _StableTopInsetState();
}

class _StableTopInsetState extends State<_StableTopInset> {
  double _top = 0;
  Orientation? _orientation;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.viewPaddingOf(context).top;
    // A tablet turned around (or the wide-screen frame opening) starts over:
    // the inset of the old layout must not stay as a gap at the top.
    final orientation = MediaQuery.orientationOf(context);
    if (orientation != _orientation) {
      _orientation = orientation;
      _top = top;
    }
    if (top > _top) _top = top;
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final g = glass.backgroundGradient;
    final paper = dark ? Color.lerp(g[0], g[1], 0.45)! : Color.lerp(g[0], Colors.white, 0.35)!;
    return Column(
      children: [
        SizedBox(
          height: _top,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                color: widget.quranTab ? paper : Colors.transparent,
              ),
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: widget.homeSky ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: const HomeSkyStrip(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(context: context, removeTop: true, child: widget.child),
        ),
      ],
    );
  }
}

/// Reports its child's height after layout (used to place the Mushaf footer
/// above the floating bottom bar).
class _SizeReporter extends SingleChildRenderObjectWidget {
  final ValueChanged<double> onHeight;

  const _SizeReporter({required this.onHeight, required Widget child}) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSizeReporter(onHeight);

  @override
  void updateRenderObject(BuildContext context, _RenderSizeReporter renderObject) => renderObject.onHeight = onHeight;
}

class _RenderSizeReporter extends RenderProxyBox {
  ValueChanged<double> onHeight;
  double? _last;

  _RenderSizeReporter(this.onHeight);

  @override
  void performLayout() {
    super.performLayout();
    final h = size.height;
    if (h != _last) {
      _last = h;
      WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(h));
    }
  }
}
