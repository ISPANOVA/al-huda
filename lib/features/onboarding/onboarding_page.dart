import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme/web_lite.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_themes.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/noor_ui.dart';
import '../prayer/presentation/cubit/prayer_cubit.dart';

/// First-launch walkthrough: a few feature slides then a permissions slide.
/// Shown once; completion is stored under settings['onboarded'].
class OnboardingPage extends StatefulWidget {
  final VoidCallback onDone;

  const OnboardingPage({super.key, required this.onDone});

  static const doneKey = 'onboarded';

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _Slide {
  final IconData icon;
  final String title;
  final String body;
  final SkyPhase sky;
  const _Slide(this.icon, this.title, this.body, this.sky);
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;
  bool _notifGranted = false;
  bool _locationGranted = false;
  bool _busy = false;

  static const _slides = [
    _Slide(Icons.menu_book_rounded, 'القرآن بين يديك',
        'مصحف المدينة كاملًا دون إنترنت بخط واضح، مع سبعة تفاسير وتلاوات لكبار القراء، ومراجعة لحفظك.', SkyPhase.morning),
    _Slide(Icons.mosque_rounded, 'صلاتك في وقتها',
        'مواقيت دقيقة حسب مدينتك، وأذان يُرفع حتى والهاتف صامت، وقبلة، وتقويم هجري بالمناسبات والإمساكية.', SkyPhase.sunset),
    _Slide(Icons.favorite_rounded, 'ذكر يطمئن به القلب',
        'أذكار الصباح والمساء والنوم، وأدعية مصنّفة، ومسبحة، وورد يومي يحتسب قراءتك تلقائيًا.', SkyPhase.night),
  ];

  int get _count => _slides.length + 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_page < _count - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await context.read<StorageService>().settings.put(OnboardingPage.doneKey, true);
    widget.onDone();
  }

  Future<void> _askNotifications() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ok = await context.read<NotificationService>().requestPermissions();
      if (mounted) setState(() => _notifGranted = ok);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _askLocation() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (kIsWeb) {
        // The browser asks by itself; the prayer cubit falls back to the
        // approximate city when it can't get the device location.
        final cubit = context.read<PrayerCubit>();
        await cubit.refreshLocation(silent: true);
        if (mounted) setState(() => _locationGranted = cubit.state.location != null);
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        await Geolocator.openLocationSettings();
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      final ok = p == LocationPermission.always || p == LocationPermission.whileInUse;
      if (ok && mounted) context.read<PrayerCubit>().refreshLocation(silent: true);
      if (mounted) setState(() => _locationGranted = ok);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final last = _page == _count - 1;
    return Stack(
      children: [
        const Positioned.fill(child: RepaintBoundary(child: GradientBackground(child: SizedBox.expand()))),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: AnimatedOpacity(
                    opacity: last ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: TextButton(
                      onPressed: last ? null : () => _controller.animateToPage(_count - 1,
                          duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic),
                      child: Text('تخطي', style: TextStyle(color: glass.onGlassMuted, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _count,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) {
                      if (i < _slides.length) return _SlideView(slide: _slides[i]);
                      return _PermissionsView(
                        notifGranted: _notifGranted,
                        locationGranted: _locationGranted,
                        busy: _busy,
                        onNotifications: _askNotifications,
                        onLocation: _askLocation,
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _count; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _page ? 26 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page ? glass.accent : glass.onGlass.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      onPressed: _next,
                      child: Text(last ? 'ابدأ الآن' : 'التالي'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final sun = slide.sky != SkyPhase.night;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, child) => Opacity(opacity: ((v - 0.85) / 0.15).clamp(0.0, 1.0), child: Transform.scale(scale: v, child: child)),
            child: Container(
              height: 260,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                boxShadow: liteShadows([BoxShadow(color: skyColors(slide.sky)[1].withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 12))]),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: SkyPainter(
                        phase: slide.sky,
                        t: slide.sky == SkyPhase.morning ? 0.3 : (slide.sky == SkyPhase.sunset ? 0.9 : 0.45),
                        sun: sun,
                        horizonAt: 0.82,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 18,
                    right: 18,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.3),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Icon(slide.icon, color: const Color(0xFFFFE3A3), size: 26),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 34),
          Text(slide.title,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: AppFonts.display, fontSize: 28, fontWeight: FontWeight.w700, color: glass.onGlass)),
          const SizedBox(height: 12),
          Text(slide.body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15.5, height: 1.85, color: glass.onGlassMuted)),
        ],
      ),
    );
  }
}

class _PermissionsView extends StatelessWidget {
  final bool notifGranted;
  final bool locationGranted;
  final bool busy;
  final VoidCallback onNotifications;
  final VoidCallback onLocation;

  const _PermissionsView({
    required this.notifGranted,
    required this.locationGranted,
    required this.busy,
    required this.onNotifications,
    required this.onLocation,
  });

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          Icon(Icons.verified_user_rounded, size: 64, color: glass.accent),
          const SizedBox(height: 20),
          Text('خطوة أخيرة',
              style: TextStyle(fontFamily: AppFonts.display, fontSize: 27, fontWeight: FontWeight.w700, color: glass.onGlass)),
          const SizedBox(height: 10),
          Text(
              kIsWeb
                  ? 'اسمح بالموقع لتُحسب المواقيت واتجاه القبلة تلقائيًا حسب مدينتك.'
                  : 'اسمح بالإشعارات والموقع ليعمل الأذان وتذكير الختمة وتُحسب المواقيت تلقائيًا حسب مدينتك.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.8, color: glass.onGlassMuted)),
          const SizedBox(height: 28),
          if (!kIsWeb) ...[
            _PermissionTile(
              icon: Icons.notifications_active_rounded,
              title: 'الإشعارات',
              subtitle: 'تنبيه الأذان والأذكار والختمة',
              granted: notifGranted,
              busy: busy,
              onTap: onNotifications,
            ),
            const SizedBox(height: 12),
          ],
          _PermissionTile(
            icon: Icons.my_location_rounded,
            title: 'الموقع',
            subtitle: 'تحديد المواقيت والقبلة تلقائيًا',
            granted: locationGranted,
            busy: busy,
            onTap: onLocation,
          ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final bool busy;
  final VoidCallback onTap;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return GlassContainer(
      blur: 0,
      padding: const EdgeInsets.all(14),
      onTap: granted || busy ? null : onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(shape: BoxShape.circle, color: primary.withValues(alpha: 0.18)),
            child: Icon(icon, color: glass.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: glass.onGlass)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 13, color: glass.onGlassMuted)),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: granted
                ? Icon(Icons.check_circle_rounded, key: const ValueKey('ok'), color: primary, size: 30)
                : Container(
                    key: const ValueKey('ask'),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(14)),
                    child: const Text('سماح', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
          ),
        ],
      ),
    );
  }
}
