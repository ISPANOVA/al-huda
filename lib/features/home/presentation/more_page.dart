import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/web_lite.dart';
import '../../../core/theme/app_themes.dart';
import '../../../core/theme/tones.dart';
import '../../../core/widgets/background_patterns.dart';
import '../../../core/widgets/noor_ui.dart';
import '../../settings/presentation/pages/appearance_page.dart';
import '../../calendar/calendar_page.dart';
import '../../duas/duas_page.dart';
import '../../hifz/hifz_review_page.dart';
import '../../audio/presentation/pages/downloads_page.dart';
import '../../audio/presentation/pages/memorization_page.dart';
import '../../audio/presentation/pages/player_page.dart';
import '../../khatmah/presentation/pages/khatmah_page.dart';
import '../../qibla/presentation/pages/qibla_page.dart';
import '../../settings/presentation/pages/settings_page.dart';
import '../../stats/presentation/stats_page.dart';
import '../../tasbeeh/presentation/pages/tasbeeh_page.dart';
import '../../virtues/virtues_pages.dart';

typedef _Item = ({String id, IconData icon, String title, String subtitle, Route<void> Function() route});

/// المزيد — dedication banner, four featured tools in colour, then tidy
/// groups (each tool keeps its colour across the app).
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final featured = <_Item>[
      (id: 'tasbeeh', icon: Icons.blur_circular_rounded, title: 'المسبحة', subtitle: 'عداد ذكي', route: TasbeehPage.route),
      (id: 'qibla', icon: Icons.explore_rounded, title: 'القبلة', subtitle: 'بوصلة دقيقة', route: QiblaPage.route),
      (id: 'khatmah', icon: Icons.flag_rounded, title: 'الختمة', subtitle: 'ورد وتذكير', route: KhatmahPage.route),
      (id: 'hifz', icon: Icons.repeat_on_rounded, title: 'الحفظ', subtitle: 'نطاق وتكرار', route: MemorizationPage.route),
    ];
    final groups = <(String, List<_Item>)>[
      (
        'نور القلب',
        [
          (id: 'virtues', icon: Icons.auto_awesome_rounded, title: 'الفضائل', subtitle: 'فضل الذكر والصلاة على النبي ﷺ', route: VirtuesPage.route),
          (id: 'ruqyah', icon: Icons.healing_rounded, title: 'الرقية الشرعية', subtitle: 'من القرآن والسنة', route: RuqyahPage.route),
          (id: 'duas', icon: Icons.back_hand_rounded, title: 'الأدعية', subtitle: 'للكرب والسفر والمرض والاستخارة', route: DuasPage.route),
        ]
      ),
      (
        'القرآن والتقويم',
        [
          (id: 'review', icon: Icons.psychology_rounded, title: 'مراجعة الحفظ', subtitle: 'اختبر حفظك بإخفاء الكلمات', route: HifzReviewPage.route),
          (id: 'calendar', icon: Icons.calendar_month_rounded, title: 'التقويم الهجري', subtitle: 'المناسبات وتذكير الصيام', route: CalendarPage.route),
          (id: 'imsakiya', icon: Icons.brightness_3_rounded, title: 'إمساكية رمضان', subtitle: 'السحور والإفطار لمدينتك', route: ImsakiyaPage.route),
        ]
      ),
      (
        'الاستماع',
        [
          (id: 'player', icon: Icons.headphones_rounded, title: 'المشغل', subtitle: 'التلاوة الحالية', route: PlayerPage.route),
          if (!kIsWeb)
          (id: 'downloads', icon: Icons.download_for_offline_rounded, title: 'تنزيلات المصحف', subtitle: 'استماع دون إنترنت', route: DownloadsPage.route),
        ]
      ),
      (
        'حسابي',
        [
          (id: 'stats', icon: Icons.insights_rounded, title: 'إحصائياتي', subtitle: 'المداومة والإنجاز', route: StatsPage.route),
          (id: 'appearance', icon: Icons.palette_rounded, title: 'المظهر', subtitle: 'الألوان وزخرفة الخلفية', route: AppearancePage.route),
          (id: 'settings', icon: Icons.settings_rounded, title: 'الإعدادات', subtitle: 'القراءة والتلاوة والتنبيهات', route: SettingsPage.route),
        ]
      ),
    ];
    final glass = GlassTheme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 130),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: [
        const NoorPageHeader('المزيد', subtitle: 'كل أدواتك في مكان واحد', tone: Tone.teal, icon: Icons.grid_view_rounded),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: CreditsCard()),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: LayoutBuilder(builder: (context, box) {
            final columns = box.maxWidth >= 640 ? 4 : 2;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: columns == 2 ? 1.45 : 1.75,
              children: [for (final f in featured) _FeaturedTile(item: f)],
            );
          }),
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
                    if (i > 0) Divider(height: 1, indent: 72, color: glass.onGlass.withValues(alpha: 0.08)),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: ToneIcon(items[i].icon, tone: Tone.of(items[i].id), size: 44),
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

/// One of the four main tools: a card filled with the tool's colour.
class _FeaturedTile extends StatelessWidget {
  final _Item item;

  const _FeaturedTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ToneCard(
      tone: Tone.of(item.id),
      solid: true,
      ornament: true,
      radius: 26,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      onTap: () => Navigator.of(context).push(item.route()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Icon(item.icon, color: Colors.white, size: 24),
          ),
          const Spacer(),
          Text(item.title,
              maxLines: 1,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  shadows: [Shadow(color: Color(0x55000000), blurRadius: 6)])),
          Text(item.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 12)),
        ],
      ),
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
        boxShadow: liteShadows([BoxShadow(color: glass.accent.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 8))]),
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
