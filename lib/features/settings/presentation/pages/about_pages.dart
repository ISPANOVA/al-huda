import 'package:flutter/material.dart';

import '../../../../core/theme/app_themes.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/gradient_background.dart';

class _Block extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;

  const _Block(this.icon, this.title, this.body);

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: glass.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
                const SizedBox(height: 4),
                Text(body, style: TextStyle(height: 1.75, color: glass.onGlassMuted, fontSize: 13.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// سياسة الخصوصية (same text as the public page used for Google Play).
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const PrivacyPage());

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'سياسة الخصوصية',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: const [
          _Block(Icons.verified_user_rounded, 'باختصار',
              'تطبيق الهدى لا يطلب حسابًا ولا يجمع أي بيانات شخصية، ولا يحتوي على إعلانات أو أدوات تتبّع. كل بياناتك تبقى على هاتفك.'),
          _Block(Icons.place_rounded, 'الموقع',
              'يُستخدم موقعك على الهاتف فقط لحساب مواقيت الصلاة واتجاه القبلة. لا يُرسل الموقع إلى أي خادم. قد يستخدم نظام الهاتف خدمة تحويل الإحداثيات إلى اسم المدينة الخاصة بالنظام.'),
          _Block(Icons.notifications_active_rounded, 'التنبيهات والمنبّهات',
              'تُستخدم لرفع الأذان والتذكير بالأذكار والورد في أوقاتها، وتُجدول محليًا على الهاتف.'),
          _Block(Icons.wifi_rounded, 'الإنترنت',
              'يتصل التطبيق بالإنترنت لتحميل التلاوات والتفاسير الإضافية وتشغيل الإذاعات والبث المباشر من مصادرها. لا تُرسل أي معلومات عنك في هذه الطلبات سوى ما يلزم تقنيًا لتحميل الملف.'),
          _Block(Icons.save_rounded, 'بياناتك',
              'العلامات والختمة والورد والإحصائيات والإعدادات محفوظة على هاتفك فقط. النسخة الاحتياطية ملف تنشئه أنت وتحتفظ به حيث تشاء، ويمكنك حذف كل البيانات بحذف التطبيق.'),
          _Block(Icons.child_care_rounded, 'الأطفال',
              'التطبيق مناسب لكل الأعمار ولا يجمع بيانات من أي مستخدم.'),
          _Block(Icons.mail_rounded, 'التواصل', 'لأي استفسار عن الخصوصية تواصل معنا عبر بريد المطوّر المذكور في صفحة التطبيق على Google Play.'),
        ],
      ),
    );
  }
}

/// المصادر والحقوق — where every piece of content comes from.
class SourcesPage extends StatelessWidget {
  const SourcesPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const SourcesPage());

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'المصادر والحقوق',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: const [
          _Block(Icons.menu_book_rounded, 'نص المصحف وخطه',
              'خط حفص العثماني من مجمع الملك فهد لطباعة المصحف الشريف (KFGQPC)، وترتيب صفحات مصحف المدينة من مشروعي mushaf-layout و quran-data-kfgqpc مفتوحي المصدر.'),
          _Block(Icons.auto_stories_rounded, 'التفاسير',
              'التفسير الميسر (مجمع الملك فهد) عبر alquran.cloud. التفاسير الإضافية (المختصر، السعدي، ابن كثير، البغوي، القرطبي، الطبري) من مستودع tafsir_api المفتوح.'),
          _Block(Icons.headphones_rounded, 'التلاوات',
              'تلاوة الآيات في المصحف من Islamic Network CDN، وتلاوات السور كاملة والإذاعات من موقع mp3quran.net.'),
          _Block(Icons.live_tv_rounded, 'البث المباشر',
              'قناتا القرآن الكريم والسنة النبوية من هيئة الإذاعة والتلفزيون السعودية، وإذاعة القرآن الكريم من القاهرة والسعودية عبر روابط البث العامة الرسمية.'),
          _Block(Icons.campaign_rounded, 'أصوات الأذان',
              'تسجيلات أذان لمؤذنين معروفين مضمّنة في التطبيق لتعمل دون إنترنت، وتُنسب لأصحابها.'),
          _Block(Icons.volunteer_activism_rounded, 'الأذكار والأدعية',
              'من كتاب حصن المسلم للشيخ سعيد بن علي بن وهف القحطاني رحمه الله، مع ذكر مصدر كل ذكر من القرآن والسنة.'),
          _Block(Icons.calculate_rounded, 'المواقيت والتقويم',
              'حساب مواقيت الصلاة بمكتبة adhan المفتوحة، والتقويم الهجري بحساب أم القرى (قد يختلف يومًا عن الرؤية المحلية).'),
          _Block(Icons.favorite_rounded, 'صدقة جارية',
              'التطبيق مجاني بالكامل بلا إعلانات، صدقة جارية عن روح والد المطوّر رحمه الله وجميع المسلمين.'),
        ],
      ),
    );
  }
}
