class AppConstants {
  AppConstants._();

  static const String appName = 'الهدى';
  static const String appNameEn = 'Al-Huda';

  // alquran.cloud public API (text + Tafseer Al-Muyassar)
  static const String quranApiBase = 'https://api.alquran.cloud/v1';
  static const String textEdition = 'quran-uthmani';
  static const String tafseerEdition = 'ar.muyassar';

  // Islamic Network CDN – per-ayah recitations addressed by global ayah number
  static const String audioCdnBase = 'https://cdn.islamic.network/quran/audio';

  // Notification IDs
  static const int khatmahReminderId = 1;
  static const int morningAthkarId = 2;
  static const int eveningAthkarId = 3;
  static const int prayerNotificationBaseId = 100;

  static const String bismillah = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';
}
