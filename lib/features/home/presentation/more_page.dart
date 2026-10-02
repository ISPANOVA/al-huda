import 'package:flutter/material.dart';

import '../../../core/theme/app_themes.dart';
import '../../../core/widgets/background_patterns.dart';
import '../../../core/widgets/noor_ui.dart';
import '../../settings/presentation/pages/appearance_page.dart';
import '../../audio/presentation/pages/downloads_page.dart';
import '../../audio/presentation/pages/memorization_page.dart';
import '../../audio/presentation/pages/player_page.dart';
import '../../khatmah/presentation/pages/khatmah_page.dart';
import '../../qibla/presentation/pages/qibla_page.dart';
import '../../settings/presentation/pages/settings_page.dart';
import '../../stats/presentation/stats_page.dart';
import '../../tasbeeh/presentation/pages/tasbeeh_page.dart';
import '../../virtues/virtues_pages.dart';

typedef _Item = ({IconData icon, String title, String subtitle, Route<void> Function() route});

/// المزيد — dedication banner, four featured tools, then tidy groups.
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final featured = <_Item>[
      (icon: Icons.blur_circular_rounded, title: 'المسبحة', subtitle: 'عداد ذكي', route: TasbeehPage.route),
      (icon: Icons.explore_rounded, title: 'القبلة', subtitle: 'بوصلة دقيقة', route: QiblaPage.route),
      (icon: Icons.flag_rounded, title: 'الختمة', subtitle: 'ورد وتذكير', route: KhatmahPage.route),
      (icon: Icons.repeat_on_rounded, title: 'الحفظ', subtitle: 'نطاق وتكرار', route: MemorizationPage.route),
    ];
    final groups = <(String, List<_Item>)>[
      (
        'نور القلب',
        [
          (icon: Icons.auto_awesome_rounded, title: 'الفضائل', subtitle: 'فضل الذكر والصلاة على النبي ﷺ', route: VirtuesPage.route),
          (icon: Icons.healing_rounded, title: 'الرقية الشرعية', subtitle: 'من القرآن والسنة', route: RuqyahPage.route),
        ]
      ),
      (
        'الاستماع',
        [
          (icon: Icons.headphones_rounded, title: 'المشغل', subtitle: 'التلاوة الحالية', route: PlayerPage.route),
          (icon: Icons.download_for_offline_rounded, title: 'تنزيلات المصحف', subtitle: 'استماع دون إنترنت', route: DownloadsPage.route),
        ]
      ),
      (
        'حسابي',
        [
          (icon: Icons.insights_rounded, title: 'إحصائياتي', subtitle: 'المداومة والإنجاز', route: StatsPage.route),
          (icon: Icons.palette_rounded, title: 'المظهر', subtitle: 'الألوان وزخرفة الخلفية', route: AppearancePage.route),
          (icon: Icons.settings_rounded, title: 'الإعدادات', subtitle: 'القراءة والتلاوة والتنبيهات', route: SettingsPage.route),
        ]
      ),
    ];
    final glass = GlassTheme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 130),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: [
        const NoorPageHeader('المزيد', subtitle: 'كل أدواتك في مكان واحد'),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: CreditsCard()),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            childAspectRatio: 0.8,
            children: [
              for (final f in featured)
                GestureDetector(
                  onTap: () => Navigator.of(context).push(f.route()),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [glass.accent.withValues(alpha: 0.28), glass.accent.withValues(alpha: 0.10)],
                          ),
                          border: Border.all(color: glass.accent.withValues(alpha: 0.3)),
                        ),
                        child: Icon(f.icon, color: glass.accent, size: 26),
                      ),
                      const SizedBox(height: 7),
                      Text(f.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      Text(f.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10.5, color: glass.onGlassMuted)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        for (final (title, items) in groups) ...[
          NoorSection(title),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: NoorCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) Divider(height: 1, indent: 70, color: glass.onGlass.withValues(alpha: 0.08)),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: glass.accent.withValues(alpha: 0.14),
                        ),
                        child: Icon(items[i].icon, color: glass.accent),
                      ),
                      title: Text(items[i].title, style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text(items[i].subtitle, style: TextStyle(fontSize: 12, color: glass.onGlassMuted)),
                      trailing: Icon(Icons.chevron_left_rounded, color: glass.onGlassMuted),
                      onTap: () => Navigator.of(context).push(items[i].route()),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 22),
        Center(
          child: Text('الهدى • الإصدار 1.0.0', style: TextStyle(color: glass.onGlassMuted, fontSize: 12)),
        ),
      ],
    );
  }
}

/// صدقة جارية — dedication and credits.
class CreditsCard extends StatelessWidget {
  const CreditsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF1A1407), Color(0xFF0A0804)],
        ),
        border: Border.all(color: glass.accent.withValues(alpha: 0.55)),
        boxShadow: [BoxShadow(color: glass.accent.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: PatternPainter(pattern: BgPattern.khatam, color: glass.accent.withValues(alpha: 0.18), scale: 0.6),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [glass.accent.withValues(alpha: 0.5), Colors.transparent]),
                  ),
                  child: const Icon(Icons.local_florist_rounded, color: Color(0xFFFFE3A3), size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('صدقة جارية',
                          style: TextStyle(color: Color(0xFFFFE3A3), fontSize: 13, fontWeight: FontWeight.w800)),
                      const Text('عن روح والدي رحمه الله وجميع المسلمين',
                          style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text('اللهم اغفر له وارحمه، واجعل كل حرف يُقرأ هنا في ميزان حسناته',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, height: 1.6)),
                      const SizedBox(height: 8),
                      Text('تطوير SMRH',
                          style: TextStyle(color: glass.accent, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
