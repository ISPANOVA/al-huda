import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/services/notification_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_themes.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/gradient_background.dart';
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
  const _Slide(this.icon, this.title, this.body);
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;
  bool _notifGranted = false;
  bool _locationGranted = false;
  bool _busy = false;

  static const _slides = [
    _Slide(Icons.menu_book_rounded, 'مصحف كامل بين يديك',
        'المصحف الشريف بـ٦٠٤ صفحة مدمج في التطبيق دون إنترنت. اضغط مطولًا على أي آية لقراءة التفسير الميسر، وسيفتح لك التطبيق دائمًا من حيث توقفت.'),
    _Slide(Icons.headphones_rounded, 'استمع وراجع حفظك',
        'تلاوات لكبار القراء مع تتبع الآية المقروءة، وتكرار المقاطع للحفظ، وتحميل السور للاستماع دون إنترنت حتى والشاشة مغلقة.'),
    _Slide(Icons.access_time_filled_rounded, 'مواقيت الصلاة والقبلة',
        'مواقيت دقيقة حسب موقعك مع اختيار طريقة الحساب والمذهب، وتنبيه بالأذان، وبوصلة لتحديد اتجاه القبلة.'),
    _Slide(Icons.auto_graph_rounded, 'أذكار وختمة وإحصائيات',
        'أذكار الصباح والمساء، والسبحة، وخطة لختم القرآن بمواعيد تذكير، وإحصائيات تشجعك على المداومة.'),
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
    final primary = Theme.of(context).colorScheme.primary;
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
                          color: i == _page ? primary : glass.onGlass.withValues(alpha: 0.2),
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
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [primary.withValues(alpha: 0.45), primary.withValues(alpha: 0.08)]),
                border: Border.all(color: glass.accent.withValues(alpha: 0.6), width: 1.5),
              ),
              child: Icon(slide.icon, size: 68, color: glass.accent),
            ),
          ),
          const SizedBox(height: 40),
          Text(slide.title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: glass.onGlass)),
          const SizedBox(height: 16),
          Text(slide.body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.8, color: glass.onGlassMuted)),
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
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: glass.onGlass)),
          const SizedBox(height: 10),
          Text('اسمح بالإشعارات والموقع ليعمل الأذان وتذكير الختمة وتُحسب المواقيت تلقائيًا حسب مدينتك.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.8, color: glass.onGlassMuted)),
          const SizedBox(height: 28),
          _PermissionTile(
            icon: Icons.notifications_active_rounded,
            title: 'الإشعارات',
            subtitle: 'تنبيه الأذان والأذكار والختمة',
            granted: notifGranted,
            busy: busy,
            onTap: onNotifications,
          ),
          const SizedBox(height: 12),
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
