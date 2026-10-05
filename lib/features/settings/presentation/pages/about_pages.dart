import 'package:flutter/material.dart';

import '../../../../core/theme/app_themes.dart';
import '../../../../core/theme/tones.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/gradient_background.dart';

/// One titled paragraph: a coloured icon, the title and the text, on a card
/// washed with the same colour.
class _Block extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final Tone tone;

  const _Block(this.icon, this.title, this.body, {required this.tone});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ToneCard(
        tone: tone,
        radius: 22,
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ToneIcon(icon, tone: tone, size: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, color: glass.onGlass)),
                  const SizedBox(height: 6),
                  Text(body, style: TextStyle(height: 1.75, color: glass.onGlassMuted, fontSize: 13.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The opening (or closing) statement of the page, filled with its colour.
class _Hero extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final Tone tone;

  const _Hero(this.icon, this.title, this.body, {required this.tone});

  @override
  Widget build(BuildContext context) {
    return ToneCard(
      tone: tone,
      solid: true,
      ornament: true,
      radius: 26,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontFamily: AppFonts.display, fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(body,
              style: TextStyle(height: 1.8, fontSize: 14.5, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.92))),
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
      subtitle: 'بياناتك تبقى على هاتفك',
      icon: Icons.shield_rounded,
      tone: Tone.sky,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: const [
          _Hero(Icons.verified_user_rounded, 'باختصار',
              'تطبيق الهدى لا يطلب حسابًا ولا يجمع أي بيانات شخصية، ولا يحتوي على إعلانات أو أدوات تتبّع. كل بياناتك تبقى على هاتفك.',
              tone: Tone.sky),
          GlassSectionTitle('ما يستخدمه التطبيق', tone: Tone.sky),
          _Block(Icons.place_rounded, 'الموقع',
              'يُستخدم موقعك لحساب مواقيت الصلاة واتجاه القبلة، والحساب نفسه يتم على هاتفك. لمعرفة اسم مدينتك فقط تُرسل الإحداثيات التقريبية إلى خدمة تحويل الإحداثيات في نظام الهاتف، أو إلى خدمة BigDataCloud إن لم تتوفر، ولا تُحفظ عندنا ولا تُربط بك.',
              tone: Tone.emerald),
          _Block(Icons.mic_rounded, 'الميكروفون (التسميع)',
              'يُستخدم الميكروفون فقط أثناء التسميع وأنت تضغط زر التسجيل، ليتعرّف على قراءتك ويقارنها بالمصحف. يتم التعرّف بخدمة التعرّف على الكلام في هاتفك (على أغلب الأجهزة خدمة Google)، وقد تعالج هذه الخدمة الصوت على خوادمها وفق سياستها. لا يحفظ التطبيق تسجيلات صوتك ولا يرسلها لأي جهة أخرى.',
              tone: Tone.coral),
          _Block(Icons.notifications_active_rounded, 'التنبيهات والمنبّهات',
              'تُستخدم لرفع الأذان والتذكير بالأذكار والورد في أوقاتها، وتُجدول محليًا على الهاتف.',
              tone: Tone.amber),
          _Block(Icons.wifi_rounded, 'الإنترنت',
              'يتصل التطبيق بالإنترنت لتحميل التلاوات والتفاسير الإضافية وتشغيل الإذاعات والبث المباشر من مصادرها، ولقراءة رسائل التطبيق (مثل التنبيه بوجود تحديث). لا تُرسل أي معلومات عنك في هذه الطلبات سوى ما يلزم تقنيًا لتحميل الملف.',
              tone: Tone.sapphire),
          GlassSectionTitle('بياناتك وحقوقك', tone: Tone.sky),
          _Block(Icons.save_rounded, 'بياناتك',
              'العلامات والختمة والورد والإحصائيات والإعدادات محفوظة على هاتفك فقط. النسخة الاحتياطية ملف تنشئه أنت وتحتفظ به حيث تشاء، ويمكنك حذف كل البيانات بحذف التطبيق.',
              tone: Tone.teal),
          _Block(Icons.child_care_rounded, 'الأطفال',
              'التطبيق مناسب لكل الأعمار ولا يجمع بيانات من أي مستخدم.',
              tone: Tone.rose),
          _Block(Icons.mail_rounded, 'التواصل',
              'لأي استفسار عن الخصوصية تواصل معنا عبر بريد المطوّر المذكور في صفحة التطبيق على Google Play.',
              tone: Tone.amethyst),
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
      subtitle: 'مصدر كل محتوى في التطبيق',
      icon: Icons.library_books_rounded,
      tone: Tone.gold,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: const [
          GlassSectionTitle('القرآن والتفسير', tone: Tone.gold),
          _Block(Icons.menu_book_rounded, 'نص المصحف وخطه',
              'خط حفص العثماني من مجمع الملك فهد لطباعة المصحف الشريف (KFGQPC)، وترتيب صفحات مصحف المدينة من مشروعي mushaf-layout و quran-data-kfgqpc مفتوحي المصدر.',
              tone: Tone.emerald),
          _Block(Icons.auto_stories_rounded, 'التفاسير',
              'التفسير الميسر (مجمع الملك فهد) عبر alquran.cloud. التفاسير الإضافية (المختصر، السعدي، ابن كثير، البغوي، القرطبي، الطبري) من مستودع tafsir_api المفتوح.',
              tone: Tone.gold),
          GlassSectionTitle('الصوتيات والبث', tone: Tone.gold),
          _Block(Icons.headphones_rounded, 'التلاوات',
              'تلاوة الآيات في المصحف من Islamic Network CDN، وتلاوات السور كاملة والإذاعات من موقع mp3quran.net.',
              tone: Tone.amethyst),
          _Block(Icons.live_tv_rounded, 'البث المباشر',
              'قناتا القرآن الكريم والسنة النبوية من هيئة الإذاعة والتلفزيون السعودية، وإذاعة القرآن الكريم من القاهرة والسعودية عبر روابط البث العامة الرسمية.',
              tone: Tone.coral),
          _Block(Icons.campaign_rounded, 'أصوات الأذان',
              'تسجيلات أذان لمؤذنين معروفين مضمّنة في التطبيق لتعمل دون إنترنت، وتُنسب لأصحابها.',
              tone: Tone.sapphire),
          GlassSectionTitle('الأذكار والمواقيت', tone: Tone.gold),
          _Block(Icons.volunteer_activism_rounded, 'الأذكار والأدعية',
              'من كتاب حصن المسلم للشيخ سعيد بن علي بن وهف القحطاني رحمه الله، مع ذكر مصدر كل ذكر من القرآن والسنة.',
              tone: Tone.rose),
          _Block(Icons.calculate_rounded, 'المواقيت والتقويم',
              'حساب مواقيت الصلاة بمكتبة adhan المفتوحة، والتقويم الهجري بحساب أم القرى (قد يختلف يومًا عن الرؤية المحلية).',
              tone: Tone.teal),
          SizedBox(height: 10),
          _Hero(Icons.favorite_rounded, 'صدقة جارية',
              'التطبيق مجاني بالكامل بلا إعلانات، صدقة جارية عن روح والد المطوّر رحمه الله وجميع المسلمين.',
              tone: Tone.gold),
        ],
      ),
    );
  }
}
