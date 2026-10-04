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
import '../../../core/theme/page_transitions.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../athkar/presentation/cubit/athkar_cubit.dart';
import '../../athkar/presentation/pages/athkar_pages.dart';
import '../../media/media_page.dart';
import '../../calendar/islamic_calendar.dart';
import '../../settings/presentation/cubit/settings_cubit.dart';
import '../../audio/presentation/widgets/mini_player.dart';
import '../../prayer/presentation/pages/prayer_times_page.dart';
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

  static const _tabs = [
    (icon: Icons.home_outlined, active: Icons.home_rounded, label: 'الرئيسية'),
    (icon: Icons.menu_book_outlined, active: Icons.menu_book_rounded, label: 'المصحف'),
    (icon: Icons.headphones_outlined, active: Icons.headphones_rounded, label: 'الوسائط'),
    (icon: Icons.access_time, active: Icons.access_time_filled_rounded, label: 'الصلاة'),
    (icon: Icons.favorite_border_rounded, active: Icons.favorite_rounded, label: 'الأذكار'),
    (icon: Icons.grid_view_outlined, active: Icons.grid_view_rounded, label: 'المزيد'),
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
      await n.ensureExactAlarms();
    }
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

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
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
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: FadeThroughIndexedStack(
                            index: _index,
                            children: [
                              DashboardPage(onNavigate: _go),
                              const MushafReaderPage(embedded: true),
                              const MediaPage(),
                              const PrayerTimesPage(),
                              const AthkarHomePage(),
                              const MorePage(),
                            ],
                          ),
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

/// Floating, pill-style navigation: the selected tab grows into a capsule
/// with its label; the others show icons only.
class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final primary = Theme.of(context).colorScheme.primary;
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
                      gradient: i == index
                          ? LinearGradient(colors: [
                              primary.withValues(alpha: dark ? 0.55 : 0.85),
                              Color.lerp(primary, glass.accent, 0.45)!.withValues(alpha: dark ? 0.45 : 0.75),
                            ])
                          : null,
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
                              color: i == index ? Colors.white : glass.onGlassMuted,
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
  final Widget child;

  const _StableTopInset({required this.quranTab, required this.child});

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
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: _top,
          color: widget.quranTab ? paper : Colors.transparent,
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
