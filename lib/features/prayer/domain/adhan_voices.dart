/// Adhan voices bundled as Android raw resources (adhan_<id>.mp3 for the
/// full adhan, takbeer_<id>.mp3 for the opening takbeers only).
class AdhanVoice {
  final String id;
  final String nameAr;
  final String origin;

  const AdhanVoice(this.id, this.nameAr, this.origin);
}

class AdhanVoices {
  AdhanVoices._();

  static const String defaultId = 'makkah';

  static const List<AdhanVoice> all = [
    AdhanVoice('makkah', 'أذان الحرم المكي', 'مكة المكرمة'),
    AdhanVoice('madinah', 'أذان المسجد النبوي', 'المدينة المنورة'),
    AdhanVoice('refaat', 'الشيخ محمد رفعت', 'مصر'),
    AdhanVoice('abdulbasit', 'الشيخ عبد الباسط عبد الصمد', 'مصر'),
    AdhanVoice('menshawy', 'الشيخ محمد صديق المنشاوي', 'مصر'),
    AdhanVoice('alafasy', 'الشيخ مشاري العفاسي', 'الكويت'),
    AdhanVoice('qatami', 'الشيخ ناصر القطامي', 'السعودية'),
    AdhanVoice('tobar', 'الشيخ نصر الدين طوبار', 'مصر • وأذان خاص للفجر'),
    AdhanVoice('default', 'نغمة الإشعار العادية', 'بدون أذان'),
  ];

  static AdhanVoice byId(String id) => all.firstWhere((v) => v.id == id, orElse: () => all.first);

  /// Voices with their own Fajr adhan («الصلاة خير من النوم»): adhan_<id>_fajr.
  static const fajrVoices = {'tobar'};

  /// The sound id for a prayer: the voice's Fajr adhan at Fajr when it has one.
  static String forPrayer(String id, {required bool fajr}) => fajr && fajrVoices.contains(id) ? '${id}_fajr' : id;

  /// Uri of the bundled sound for previews (Android raw resource).
  static Uri previewUri(String id, {required bool full}) =>
      Uri.parse('android.resource://com.alhuda.islamic.app/raw/${full ? 'adhan' : 'takbeer'}_$id');
}
