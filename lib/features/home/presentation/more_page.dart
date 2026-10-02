import 'package:flutter/material.dart';

import '../../../core/theme/app_themes.dart';
import '../../../core/widgets/glass_container.dart';
import '../../audio/presentation/pages/downloads_page.dart';
import '../../audio/presentation/pages/memorization_page.dart';
import '../../audio/presentation/pages/player_page.dart';
import '../../khatmah/presentation/pages/khatmah_page.dart';
import '../../qibla/presentation/pages/qibla_page.dart';
import '../../settings/presentation/pages/settings_page.dart';
import '../../stats/presentation/stats_page.dart';
import '../../tasbeeh/presentation/pages/tasbeeh_page.dart';
import '../../virtues/virtues_pages.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String title, String subtitle, Route<void> Function() route})>[
      (icon: Icons.auto_awesome_rounded, title: 'الفضائل', subtitle: 'فضل الذكر والصلاة على النبي ﷺ', route: VirtuesPage.route),
      (icon: Icons.healing_rounded, title: 'الرقية الشرعية', subtitle: 'من القرآن والسنة', route: RuqyahPage.route),
      (icon: Icons.blur_circular_rounded, title: 'المسبحة', subtitle: 'تسبيح إلكتروني بعداد ذكي', route: TasbeehPage.route),
      (icon: Icons.explore_rounded, title: 'القبلة', subtitle: 'بوصلة ثلاثية الأبعاد', route: QiblaPage.route),
      (icon: Icons.flag_rounded, title: 'مخطط الختمة', subtitle: 'ورد يومي وتذكير', route: KhatmahPage.route),
      (icon: Icons.repeat_on_rounded, title: 'وضع الحفظ', subtitle: 'نطاق مخصص وتكرار', route: MemorizationPage.route),
      (icon: Icons.headphones_rounded, title: 'المشغل', subtitle: 'التلاوة الحالية', route: PlayerPage.route),
      (icon: Icons.download_for_offline_rounded, title: 'التحميلات', subtitle: 'استماع دون إنترنت', route: DownloadsPage.route),
      (icon: Icons.insights_rounded, title: 'إحصائياتي', subtitle: 'السلسلة اليومية والإنجاز', route: StatsPage.route),
      (icon: Icons.settings_rounded, title: 'الإعدادات', subtitle: 'الثيمات والخطوط والتنبيهات', route: SettingsPage.route),
    ];
    final glass = GlassTheme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
      children: [
        Text('المزيد', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
          ),
          itemBuilder: (context, i) {
            final item = items[i];
            return GlassContainer(
              onTap: () => Navigator.of(context).push(item.route()),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(colors: [glass.accent, Theme.of(context).colorScheme.primary]),
                    ),
                    child: Icon(item.icon, color: Colors.white),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      Text(item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: glass.onGlassMuted)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        const CreditsCard(),
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
    return GlassContainer(
      blur: 0,
      borderColor: glass.accent.withValues(alpha: 0.5),
      child: Column(
        children: [
          Icon(Icons.volunteer_activism_rounded, color: glass.accent, size: 30),
          const SizedBox(height: 10),
          Text(
            'صدقة جارية عن روح والدي رحمه الله\nوعن جميع موتى المسلمين',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.8, fontWeight: FontWeight.w800, color: glass.onGlass),
          ),
          const SizedBox(height: 6),
          Text(
            'اللهم اغفر له وارحمه، واجعل كل حرف يُقرأ في هذا التطبيق في ميزان حسناته',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.7, color: glass.onGlassMuted),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: glass.accent.withValues(alpha: 0.6)),
            ),
            child: Text(
              'تطوير SMRH',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5, color: glass.accent),
            ),
          ),
        ],
      ),
    );
  }
}
