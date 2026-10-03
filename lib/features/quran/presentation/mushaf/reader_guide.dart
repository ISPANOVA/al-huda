import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_themes.dart';
import '../../../../core/widgets/state_views.dart';

/// A short tour of the Mushaf, shown once the first time it is opened.
class ReaderGuide {
  ReaderGuide._();

  static const _key = 'reader_guide_seen';
  static bool _showing = false;

  static Future<void> showOnce(BuildContext context) async {
    final settings = context.read<StorageService>().settings;
    if (_showing || settings.get(_key) == true) return;
    _showing = true;
    await settings.put(_key, true);
    if (!context.mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => const _GuideDialog(),
      transitionBuilder: (_, a, __, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
      ),
    );
    _showing = false;
  }
}

class _Step {
  final IconData icon;
  final String title;
  final String body;
  final _Motion motion;

  const _Step(this.icon, this.title, this.body, this.motion);
}

enum _Motion { swipe, press, pulse, none }

const _steps = [
  _Step(Icons.swipe_rounded, 'قلّب الصفحات',
      'اسحب يمينًا أو يسارًا للانتقال بين صفحات المصحف، تمامًا كالمصحف الورقي.', _Motion.swipe),
  _Step(Icons.touch_app_rounded, 'اضغط على أي آية',
      'اضغط على الآية أو اضغط عليها مطوّلًا لتظهر أدواتها: التفسير، الاستماع، العلامة، المفضلة، النسخ، ومشاركتها كصورة.',
      _Motion.press),
  _Step(Icons.mic_rounded, 'التسميع',
      'زر الميكروفون في الأعلى يفتح التسميع: يُخفى النص وتقرأ من حفظك، فتظهر الكلمات مع قراءتك ويُنبهك عند الخطأ.',
      _Motion.pulse),
  _Step(Icons.center_focus_strong_rounded, 'وضع التركيز',
      'اضغط على مكان فارغ في الصفحة لإخفاء الأدوات والقراءة بلا تشتيت، واضغط مرة أخرى لإظهارها.', _Motion.press),
  _Step(Icons.grid_view_rounded, 'الفهرس والبحث والعلامة',
      'اضغط اسم السورة أو أيقونة الفهرس للتنقل بين السور والأجزاء، والعدسة للبحث في القرآن، والعلامة لحفظ موضع قراءتك. وفي الأسفل: تشغيل تلاوة الصفحة وإعدادات الخط.',
      _Motion.none),
];

class _GuideDialog extends StatefulWidget {
  const _GuideDialog();

  @override
  State<_GuideDialog> createState() => _GuideDialogState();
}

class _GuideDialogState extends State<_GuideDialog> with SingleTickerProviderStateMixin {
  final _pages = PageController();
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();
  int _i = 0;

  @override
  void dispose() {
    _pages.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _next() {
    if (_i == _steps.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    _pages.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  Widget _illustration(GlassTheme glass, _Step s) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) {
        final t = _anim.value;
        var dx = 0.0;
        var scale = 1.0;
        switch (s.motion) {
          case _Motion.swipe:
            dx = math.sin(t * 2 * math.pi) * 26;
          case _Motion.press:
            scale = 1 - 0.12 * math.max(0, math.sin(t * 2 * math.pi));
          case _Motion.pulse:
            scale = 1 + 0.08 * math.sin(t * 2 * math.pi);
          case _Motion.none:
            break;
        }
        return Transform.translate(offset: Offset(dx, 0), child: Transform.scale(scale: scale, child: child));
      },
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [glass.accent.withValues(alpha: 0.32), glass.accent.withValues(alpha: 0.06)]),
          border: Border.all(color: glass.accent.withValues(alpha: 0.55), width: 1.4),
        ),
        child: Icon(s.icon, size: 46, color: glass.accent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final last = _i == _steps.length - 1;
    return SafeArea(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: math.min(MediaQuery.of(context).size.width - 40, 420),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              color: sheetSurface(context),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: glass.accent.withValues(alpha: 0.4), width: 1.2),
              boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 30, offset: Offset(0, 12))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text('دليل المصحف', style: TextStyle(color: glass.accent, fontWeight: FontWeight.w900, fontSize: 15)),
                    const Spacer(),
                    if (!last)
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('تخطي', style: TextStyle(color: glass.onGlassMuted)),
                      ),
                  ],
                ),
                SizedBox(
                  height: 300,
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: _steps.length,
                    onPageChanged: (i) => setState(() => _i = i),
                    itemBuilder: (_, i) {
                      final s = _steps[i];
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _illustration(glass, s),
                          const SizedBox(height: 22),
                          Text(s.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: glass.onGlass, fontWeight: FontWeight.w900, fontSize: 20)),
                          const SizedBox(height: 10),
                          Text(s.body,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: glass.onGlassMuted, fontSize: 14.5, height: 1.7)),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var k = 0; k < _steps.length; k++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: k == _i ? 20 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: k == _i ? glass.accent : glass.onGlass.withValues(alpha: 0.2),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: _next,
                    child: Text(last ? 'ابدأ القراءة' : 'التالي',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
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
