import 'package:flutter/material.dart';

/// Full-surah recitations (one MP3 per surah) served by mp3quran.net.
/// URLs were verified from the mp3quran v3 API (Hafs, all 114 surahs).
enum MediaRegion { eg, gulf, other }

class MediaReciter {
  final String key;
  final String name;
  final String style;
  final String server;
  final MediaRegion region;

  const MediaReciter(this.key, this.name, this.style, this.server, this.region);

  /// Id used in the audio queue / downloads (kept apart from per-ayah reciters).
  String get id => 'mp3q:$key';

  bool get mujawwad => style != 'مرتل';

  String urlFor(int surah) => '$server${surah.toString().padLeft(3, '0')}.mp3';
}

class MediaRadio {
  final String name;

  /// Tried in order until one plays.
  final List<String> urls;
  final String? reciterKey;
  final IconData icon;
  final String? subtitle;

  const MediaRadio(this.name, this.urls, {this.reciterKey, this.icon = Icons.radio_rounded, this.subtitle});
}

class MediaCatalog {
  MediaCatalog._();

  static const reciters = [
  MediaReciter('basit', 'عبد الباسط عبد الصمد', 'مرتل', 'https://server7.mp3quran.net/basit/', MediaRegion.eg),
  MediaReciter('basit_mj', 'عبد الباسط عبد الصمد', 'مجوَّد', 'https://server7.mp3quran.net/basit/Almusshaf-Al-Mojawwad/', MediaRegion.eg),
  MediaReciter('minsh', 'محمد صديق المنشاوي', 'مرتل', 'https://server10.mp3quran.net/minsh/', MediaRegion.eg),
  MediaReciter('minsh_mj', 'محمد صديق المنشاوي', 'مجوَّد', 'https://server10.mp3quran.net/minsh/Almusshaf-Al-Mojawwad/', MediaRegion.eg),
  MediaReciter('husr', 'محمود خليل الحصري', 'مرتل', 'https://server13.mp3quran.net/husr/', MediaRegion.eg),
  MediaReciter('husr_mj', 'محمود خليل الحصري', 'مجوَّد', 'https://server13.mp3quran.net/husr/Almusshaf-Al-Mojawwad/', MediaRegion.eg),
  MediaReciter('mustafa', 'مصطفى إسماعيل', 'مرتل', 'https://server8.mp3quran.net/mustafa/', MediaRegion.eg),
  MediaReciter('mustafa_mj', 'مصطفى إسماعيل', 'مجوَّد', 'https://server8.mp3quran.net/mustafa/Almusshaf-Al-Mojawwad/', MediaRegion.eg),
  MediaReciter('bna', 'محمود علي البنا', 'مرتل', 'https://server8.mp3quran.net/bna/', MediaRegion.eg),
  MediaReciter('bna_mj', 'محمود علي البنا', 'مجوَّد', 'https://server8.mp3quran.net/bna/Almusshaf-Al-Mojawwad/', MediaRegion.eg),
  MediaReciter('tblawi', 'محمد محمود الطبلاوي', 'مرتل', 'https://server12.mp3quran.net/tblawi/', MediaRegion.eg),
  MediaReciter('tblawi_mj', 'محمد محمود الطبلاوي', 'مجوَّد', 'https://server12.mp3quran.net/tblawi/Al-Mojawwad/', MediaRegion.eg),
  MediaReciter('nuaina', 'أحمد نعينع', 'مرتل', 'https://server11.mp3quran.net/ahmad_nu/', MediaRegion.eg),
  MediaReciter('shahhat', 'عبد الرحمن الشحات', 'مرتل', 'https://server16.mp3quran.net/a_alshahhat/Rewayat-Hafs-A-n-Assem/', MediaRegion.eg),
  MediaReciter('afs', 'مشاري راشد العفاسي', 'مرتل', 'https://server8.mp3quran.net/afs/', MediaRegion.gulf),
  MediaReciter('yasser', 'ياسر الدوسري', 'مرتل', 'https://server11.mp3quran.net/yasser/', MediaRegion.gulf),
  MediaReciter('maher', 'ماهر المعيقلي', 'مرتل', 'https://server12.mp3quran.net/maher/', MediaRegion.gulf),
  MediaReciter('sds', 'عبد الرحمن السديس', 'مرتل', 'https://server11.mp3quran.net/sds/', MediaRegion.gulf),
  MediaReciter('shur', 'سعود الشريم', 'مرتل', 'https://server7.mp3quran.net/shur/', MediaRegion.gulf),
  MediaReciter('qtm', 'ناصر القطامي', 'مرتل', 'https://server6.mp3quran.net/qtm/', MediaRegion.gulf),
  MediaReciter('ajm', 'أحمد بن علي العجمي', 'مرتل', 'https://server10.mp3quran.net/ajm/', MediaRegion.gulf),
  MediaReciter('shatri', 'أبو بكر الشاطري', 'مرتل', 'https://server11.mp3quran.net/shatri/', MediaRegion.gulf),
  MediaReciter('hthfi', 'علي الحذيفي', 'مرتل', 'https://server9.mp3quran.net/hthfi/', MediaRegion.gulf),
  MediaReciter('ayyub', 'محمد أيوب', 'مرتل', 'https://server8.mp3quran.net/ayyub/', MediaRegion.gulf),
  MediaReciter('bsfr', 'عبد الله بصفر', 'مرتل', 'https://server6.mp3quran.net/bsfr/', MediaRegion.gulf),
  MediaReciter('hani', 'هاني الرفاعي', 'مرتل', 'https://server8.mp3quran.net/hani/', MediaRegion.gulf),
  MediaReciter('jbrl', 'محمد جبريل', 'مرتل', 'https://server8.mp3quran.net/jbrl/', MediaRegion.eg),
  MediaReciter('abkr', 'إدريس أبكر', 'مرتل', 'https://server6.mp3quran.net/abkr/', MediaRegion.gulf),
  MediaReciter('frs', 'فارس عباد', 'مرتل', 'https://server8.mp3quran.net/frs_a/', MediaRegion.gulf),
  MediaReciter('gmd', 'سعد الغامدي', 'مرتل', 'https://server7.mp3quran.net/s_gmd/', MediaRegion.gulf),
  MediaReciter('jleel', 'خالد الجليل', 'مرتل', 'https://server10.mp3quran.net/jleel/', MediaRegion.gulf),
  MediaReciter('lhdan', 'محمد اللحيدان', 'مرتل', 'https://server8.mp3quran.net/lhdan/', MediaRegion.gulf),
  MediaReciter('klb', 'عادل الكلباني', 'مرتل', 'https://server8.mp3quran.net/a_klb/', MediaRegion.gulf),
  MediaReciter('jhn', 'عبد الله الجهني', 'مرتل', 'https://server13.mp3quran.net/jhn/', MediaRegion.gulf),
  MediaReciter('kyat', 'عبد الله خياط', 'مرتل', 'https://server12.mp3quran.net/kyat/', MediaRegion.gulf),
  MediaReciter('bud', 'صلاح البدير', 'مرتل', 'https://server6.mp3quran.net/s_bud/', MediaRegion.gulf),
  MediaReciter('qasm', 'عبد المحسن القاسم', 'مرتل', 'https://server8.mp3quran.net/qasm/', MediaRegion.gulf),
  MediaReciter('akdr', 'إبراهيم الأخضر', 'مرتل', 'https://server6.mp3quran.net/akdr/', MediaRegion.gulf),
  MediaReciter('bader', 'بدر التركي', 'مرتل', 'https://server10.mp3quran.net/bader/Rewayat-Hafs-A-n-Assem/', MediaRegion.gulf),
  MediaReciter('tnjy', 'خليفة الطنيجي', 'مرتل', 'https://server12.mp3quran.net/tnjy/', MediaRegion.gulf),
  MediaReciter('mansor', 'منصور السالمي', 'مرتل', 'https://server14.mp3quran.net/mansor/', MediaRegion.gulf),
  MediaReciter('aloosi', 'عبد الرحمن العوسي', 'مرتل', 'https://server6.mp3quran.net/aloosi/', MediaRegion.gulf),
  MediaReciter('nabil', 'نبيل الرفاعي', 'مرتل', 'https://server9.mp3quran.net/nabil/', MediaRegion.gulf),
  MediaReciter('ajbr', 'علي جابر', 'مرتل', 'https://server11.mp3quran.net/a_jbr/', MediaRegion.gulf),
  MediaReciter('mtrod', 'عبد الله المطرود', 'مرتل', 'https://server8.mp3quran.net/mtrod/', MediaRegion.gulf),
  MediaReciter('dosri', 'إبراهيم الدوسري', 'مرتل', 'https://server10.mp3quran.net/ibrahim_dosri/Rewayat-Hafs-A-n-Assem/', MediaRegion.gulf),
  MediaReciter('mrifai', 'محمود الرفاعي', 'مرتل', 'https://server11.mp3quran.net/mrifai/', MediaRegion.gulf),
  MediaReciter('alzain', 'الزين محمد أحمد', 'مرتل', 'https://server9.mp3quran.net/alzain/', MediaRegion.other),
  ];

  static MediaReciter? byId(String id) {
    final key = id.startsWith('mp3q:') ? id.substring(5) : id;
    for (final r in reciters) {
      if (r.key == key) return r;
    }
    return null;
  }

  static List<MediaReciter> get featured => [
        for (final k in const ['basit', 'minsh', 'husr', 'mustafa', 'afs', 'yasser', 'maher', 'sds', 'bna', 'tblawi'])
          byId(k)!,
      ];
}

/// Official 24/7 Quran stations.
const kOfficialRadios = [
  MediaRadio('إذاعة القرآن الكريم من القاهرة', [
    'https://stream.radiojar.com/8s5u5tpdtwzuv',
    'https://n0b.radiojar.com/8s5u5tpdtwzuv',
  ], icon: Icons.cell_tower_rounded, subtitle: 'مصر • ٩٨٫٢ FM'),
  MediaRadio('إذاعة القرآن الكريم من السعودية', [
    'https://stream.radiojar.com/0tpy1h0kxtzuv',
  ], icon: Icons.cell_tower_rounded, subtitle: 'المملكة العربية السعودية'),
];

const kReciterRadios = [
  MediaRadio('عبد الباسط عبد الصمد', ['https://qurango.net/radio/abdulbasit_abdulsamad', 'https://backup.qurango.net/radio/abdulbasit_abdulsamad'], reciterKey: 'basit'),
  MediaRadio('عبد الباسط • مجوَّد', ['https://qurango.net/radio/abdulbasit_abdulsamad_mojawwad', 'https://backup.qurango.net/radio/abdulbasit_abdulsamad_mojawwad'], reciterKey: 'basit_mj'),
  MediaRadio('محمد صديق المنشاوي', ['https://qurango.net/radio/mohammed_siddiq_alminshawi', 'https://backup.qurango.net/radio/mohammed_siddiq_alminshawi'], reciterKey: 'minsh'),
  MediaRadio('المنشاوي • مجوَّد', ['https://qurango.net/radio/mohammed_siddiq_alminshawi_mojawwad', 'https://backup.qurango.net/radio/mohammed_siddiq_alminshawi_mojawwad'], reciterKey: 'minsh_mj'),
  MediaRadio('محمود خليل الحصري', ['https://qurango.net/radio/mahmoud_khalil_alhussary', 'https://backup.qurango.net/radio/mahmoud_khalil_alhussary'], reciterKey: 'husr'),
  MediaRadio('الحصري • مجوَّد', ['https://qurango.net/radio/mahmoud_khalil_alhussary_mojawwad', 'https://backup.qurango.net/radio/mahmoud_khalil_alhussary_mojawwad'], reciterKey: 'husr_mj'),
  MediaRadio('مصطفى إسماعيل', ['https://qurango.net/radio/mustafa_ismail', 'https://backup.qurango.net/radio/mustafa_ismail'], reciterKey: 'mustafa'),
  MediaRadio('محمود علي البنا', ['https://qurango.net/radio/mahmoud_ali__albanna', 'https://backup.qurango.net/radio/mahmoud_ali__albanna'], reciterKey: 'bna'),
  MediaRadio('محمد الطبلاوي', ['https://qurango.net/radio/mohammad_altablaway', 'https://backup.qurango.net/radio/mohammad_altablaway'], reciterKey: 'tblawi'),
  MediaRadio('أحمد نعينع', ['https://qurango.net/radio/ahmad_nauina', 'https://backup.qurango.net/radio/ahmad_nauina'], reciterKey: 'nuaina'),
  MediaRadio('مشاري العفاسي', ['https://qurango.net/radio/mishary_alafasi', 'https://backup.qurango.net/radio/mishary_alafasi'], reciterKey: 'afs'),
  MediaRadio('ياسر الدوسري', ['https://qurango.net/radio/yasser_aldosari', 'https://backup.qurango.net/radio/yasser_aldosari'], reciterKey: 'yasser'),
  MediaRadio('ماهر المعيقلي', ['https://qurango.net/radio/maher', 'https://backup.qurango.net/radio/maher'], reciterKey: 'maher'),
  MediaRadio('عبد الرحمن السديس', ['https://qurango.net/radio/abdulrahman_alsudaes', 'https://backup.qurango.net/radio/abdulrahman_alsudaes'], reciterKey: 'sds'),
  MediaRadio('سعود الشريم', ['https://qurango.net/radio/saud_alshuraim', 'https://backup.qurango.net/radio/saud_alshuraim'], reciterKey: 'shur'),
  MediaRadio('ناصر القطامي', ['https://qurango.net/radio/nasser_alqatami', 'https://backup.qurango.net/radio/nasser_alqatami'], reciterKey: 'qtm'),
  MediaRadio('أحمد العجمي', ['https://qurango.net/radio/ahmad_alajmy', 'https://backup.qurango.net/radio/ahmad_alajmy'], reciterKey: 'ajm'),
  MediaRadio('محمد جبريل', ['https://qurango.net/radio/mohammed_jibreel', 'https://backup.qurango.net/radio/mohammed_jibreel'], reciterKey: 'jbrl'),
  MediaRadio('إدريس أبكر', ['https://qurango.net/radio/idrees_abkr', 'https://backup.qurango.net/radio/idrees_abkr'], reciterKey: 'abkr'),
  MediaRadio('فارس عباد', ['https://qurango.net/radio/fares_abbad', 'https://backup.qurango.net/radio/fares_abbad'], reciterKey: 'frs'),
];

const kThemeRadios = [
  MediaRadio('تراتيل قصيرة متميزة', ['https://qurango.net/radio/tarateel', 'https://backup.qurango.net/radio/tarateel'], icon: Icons.auto_awesome_rounded),
  MediaRadio('آيات السكينة', ['https://qurango.net/radio/sakeenah', 'https://backup.qurango.net/radio/sakeenah'], icon: Icons.spa_rounded),
  MediaRadio('تلاوات خاشعة', ['https://qurango.net/radio/salma', 'https://backup.qurango.net/radio/salma'], icon: Icons.nights_stay_rounded),
  MediaRadio('إذاعة متنوعة لمختلف القرّاء', ['https://qurango.net/radio/mix', 'https://backup.qurango.net/radio/mix'], icon: Icons.queue_music_rounded),
  MediaRadio('الرقية الشرعية', ['https://qurango.net/radio/roqiah', 'https://backup.qurango.net/radio/roqiah'], icon: Icons.shield_moon_rounded),
  MediaRadio('أذكار الصباح', ['https://qurango.net/radio/athkar_sabah', 'https://backup.qurango.net/radio/athkar_sabah'], icon: Icons.wb_sunny_rounded),
  MediaRadio('أذكار المساء', ['https://qurango.net/radio/athkar_masa', 'https://backup.qurango.net/radio/athkar_masa'], icon: Icons.bedtime_rounded),
  MediaRadio('تفسير القرآن الكريم', ['https://qurango.net/radio/tafseer', 'https://backup.qurango.net/radio/tafseer'], icon: Icons.menu_book_rounded),
  MediaRadio('المختصر في التفسير', ['https://qurango.net/radio/mukhtasartafsir', 'https://backup.qurango.net/radio/mukhtasartafsir'], icon: Icons.auto_stories_rounded),
  MediaRadio('قصص الأنبياء', ['https://qurango.net/radio/alanbiya', 'https://backup.qurango.net/radio/alanbiya'], icon: Icons.history_edu_rounded),
  MediaRadio('من حياة الصحابة', ['https://qurango.net/radio/sahabah', 'https://backup.qurango.net/radio/sahabah'], icon: Icons.groups_rounded),
];
