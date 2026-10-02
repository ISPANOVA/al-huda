/// Static metadata for the 114 surahs (verified total: 6236 ayahs).
class SurahInfo {
  final int number;
  final String name;
  final String englishName;
  final int ayahCount;
  final bool isMeccan;

  const SurahInfo(this.number, this.name, this.englishName, this.ayahCount, this.isMeccan);

  String get revelationAr => isMeccan ? 'مكية' : 'مدنية';
}

class SurahMetadata {
  SurahMetadata._();

  static const int totalAyahs = 6236;

  static const List<SurahInfo> all = [
  SurahInfo(1, 'الفاتحة', 'Al-Fatihah', 7, true),
  SurahInfo(2, 'البقرة', 'Al-Baqarah', 286, false),
  SurahInfo(3, 'آل عمران', 'Aal-Imran', 200, false),
  SurahInfo(4, 'النساء', 'An-Nisa', 176, false),
  SurahInfo(5, 'المائدة', 'Al-Ma\'idah', 120, false),
  SurahInfo(6, 'الأنعام', 'Al-An\'am', 165, true),
  SurahInfo(7, 'الأعراف', 'Al-A\'raf', 206, true),
  SurahInfo(8, 'الأنفال', 'Al-Anfal', 75, false),
  SurahInfo(9, 'التوبة', 'At-Tawbah', 129, false),
  SurahInfo(10, 'يونس', 'Yunus', 109, true),
  SurahInfo(11, 'هود', 'Hud', 123, true),
  SurahInfo(12, 'يوسف', 'Yusuf', 111, true),
  SurahInfo(13, 'الرعد', 'Ar-Ra\'d', 43, false),
  SurahInfo(14, 'إبراهيم', 'Ibrahim', 52, true),
  SurahInfo(15, 'الحجر', 'Al-Hijr', 99, true),
  SurahInfo(16, 'النحل', 'An-Nahl', 128, true),
  SurahInfo(17, 'الإسراء', 'Al-Isra', 111, true),
  SurahInfo(18, 'الكهف', 'Al-Kahf', 110, true),
  SurahInfo(19, 'مريم', 'Maryam', 98, true),
  SurahInfo(20, 'طه', 'Ta-Ha', 135, true),
  SurahInfo(21, 'الأنبياء', 'Al-Anbiya', 112, true),
  SurahInfo(22, 'الحج', 'Al-Hajj', 78, false),
  SurahInfo(23, 'المؤمنون', 'Al-Mu\'minun', 118, true),
  SurahInfo(24, 'النور', 'An-Nur', 64, false),
  SurahInfo(25, 'الفرقان', 'Al-Furqan', 77, true),
  SurahInfo(26, 'الشعراء', 'Ash-Shu\'ara', 227, true),
  SurahInfo(27, 'النمل', 'An-Naml', 93, true),
  SurahInfo(28, 'القصص', 'Al-Qasas', 88, true),
  SurahInfo(29, 'العنكبوت', 'Al-Ankabut', 69, true),
  SurahInfo(30, 'الروم', 'Ar-Rum', 60, true),
  SurahInfo(31, 'لقمان', 'Luqman', 34, true),
  SurahInfo(32, 'السجدة', 'As-Sajdah', 30, true),
  SurahInfo(33, 'الأحزاب', 'Al-Ahzab', 73, false),
  SurahInfo(34, 'سبأ', 'Saba', 54, true),
  SurahInfo(35, 'فاطر', 'Fatir', 45, true),
  SurahInfo(36, 'يس', 'Ya-Sin', 83, true),
  SurahInfo(37, 'الصافات', 'As-Saffat', 182, true),
  SurahInfo(38, 'ص', 'Sad', 88, true),
  SurahInfo(39, 'الزمر', 'Az-Zumar', 75, true),
  SurahInfo(40, 'غافر', 'Ghafir', 85, true),
  SurahInfo(41, 'فصلت', 'Fussilat', 54, true),
  SurahInfo(42, 'الشورى', 'Ash-Shura', 53, true),
  SurahInfo(43, 'الزخرف', 'Az-Zukhruf', 89, true),
  SurahInfo(44, 'الدخان', 'Ad-Dukhan', 59, true),
  SurahInfo(45, 'الجاثية', 'Al-Jathiyah', 37, true),
  SurahInfo(46, 'الأحقاف', 'Al-Ahqaf', 35, true),
  SurahInfo(47, 'محمد', 'Muhammad', 38, false),
  SurahInfo(48, 'الفتح', 'Al-Fath', 29, false),
  SurahInfo(49, 'الحجرات', 'Al-Hujurat', 18, false),
  SurahInfo(50, 'ق', 'Qaf', 45, true),
  SurahInfo(51, 'الذاريات', 'Adh-Dhariyat', 60, true),
  SurahInfo(52, 'الطور', 'At-Tur', 49, true),
  SurahInfo(53, 'النجم', 'An-Najm', 62, true),
  SurahInfo(54, 'القمر', 'Al-Qamar', 55, true),
  SurahInfo(55, 'الرحمن', 'Ar-Rahman', 78, false),
  SurahInfo(56, 'الواقعة', 'Al-Waqi\'ah', 96, true),
  SurahInfo(57, 'الحديد', 'Al-Hadid', 29, false),
  SurahInfo(58, 'المجادلة', 'Al-Mujadilah', 22, false),
  SurahInfo(59, 'الحشر', 'Al-Hashr', 24, false),
  SurahInfo(60, 'الممتحنة', 'Al-Mumtahanah', 13, false),
  SurahInfo(61, 'الصف', 'As-Saff', 14, false),
  SurahInfo(62, 'الجمعة', 'Al-Jumu\'ah', 11, false),
  SurahInfo(63, 'المنافقون', 'Al-Munafiqun', 11, false),
  SurahInfo(64, 'التغابن', 'At-Taghabun', 18, false),
  SurahInfo(65, 'الطلاق', 'At-Talaq', 12, false),
  SurahInfo(66, 'التحريم', 'At-Tahrim', 12, false),
  SurahInfo(67, 'الملك', 'Al-Mulk', 30, true),
  SurahInfo(68, 'القلم', 'Al-Qalam', 52, true),
  SurahInfo(69, 'الحاقة', 'Al-Haqqah', 52, true),
  SurahInfo(70, 'المعارج', 'Al-Ma\'arij', 44, true),
  SurahInfo(71, 'نوح', 'Nuh', 28, true),
  SurahInfo(72, 'الجن', 'Al-Jinn', 28, true),
  SurahInfo(73, 'المزمل', 'Al-Muzzammil', 20, true),
  SurahInfo(74, 'المدثر', 'Al-Muddaththir', 56, true),
  SurahInfo(75, 'القيامة', 'Al-Qiyamah', 40, true),
  SurahInfo(76, 'الإنسان', 'Al-Insan', 31, false),
  SurahInfo(77, 'المرسلات', 'Al-Mursalat', 50, true),
  SurahInfo(78, 'النبأ', 'An-Naba', 40, true),
  SurahInfo(79, 'النازعات', 'An-Nazi\'at', 46, true),
  SurahInfo(80, 'عبس', 'Abasa', 42, true),
  SurahInfo(81, 'التكوير', 'At-Takwir', 29, true),
  SurahInfo(82, 'الانفطار', 'Al-Infitar', 19, true),
  SurahInfo(83, 'المطففين', 'Al-Mutaffifin', 36, true),
  SurahInfo(84, 'الانشقاق', 'Al-Inshiqaq', 25, true),
  SurahInfo(85, 'البروج', 'Al-Buruj', 22, true),
  SurahInfo(86, 'الطارق', 'At-Tariq', 17, true),
  SurahInfo(87, 'الأعلى', 'Al-A\'la', 19, true),
  SurahInfo(88, 'الغاشية', 'Al-Ghashiyah', 26, true),
  SurahInfo(89, 'الفجر', 'Al-Fajr', 30, true),
  SurahInfo(90, 'البلد', 'Al-Balad', 20, true),
  SurahInfo(91, 'الشمس', 'Ash-Shams', 15, true),
  SurahInfo(92, 'الليل', 'Al-Layl', 21, true),
  SurahInfo(93, 'الضحى', 'Ad-Duha', 11, true),
  SurahInfo(94, 'الشرح', 'Ash-Sharh', 8, true),
  SurahInfo(95, 'التين', 'At-Tin', 8, true),
  SurahInfo(96, 'العلق', 'Al-Alaq', 19, true),
  SurahInfo(97, 'القدر', 'Al-Qadr', 5, true),
  SurahInfo(98, 'البينة', 'Al-Bayyinah', 8, false),
  SurahInfo(99, 'الزلزلة', 'Az-Zalzalah', 8, false),
  SurahInfo(100, 'العاديات', 'Al-Adiyat', 11, true),
  SurahInfo(101, 'القارعة', 'Al-Qari\'ah', 11, true),
  SurahInfo(102, 'التكاثر', 'At-Takathur', 8, true),
  SurahInfo(103, 'العصر', 'Al-Asr', 3, true),
  SurahInfo(104, 'الهمزة', 'Al-Humazah', 9, true),
  SurahInfo(105, 'الفيل', 'Al-Fil', 5, true),
  SurahInfo(106, 'قريش', 'Quraysh', 4, true),
  SurahInfo(107, 'الماعون', 'Al-Ma\'un', 7, true),
  SurahInfo(108, 'الكوثر', 'Al-Kawthar', 3, true),
  SurahInfo(109, 'الكافرون', 'Al-Kafirun', 6, true),
  SurahInfo(110, 'النصر', 'An-Nasr', 3, false),
  SurahInfo(111, 'المسد', 'Al-Masad', 5, true),
  SurahInfo(112, 'الإخلاص', 'Al-Ikhlas', 4, true),
  SurahInfo(113, 'الفلق', 'Al-Falaq', 5, true),
  SurahInfo(114, 'الناس', 'An-Nas', 6, true),
  ];

  static final List<int> _offsets = _buildOffsets();

  static List<int> _buildOffsets() {
    final offsets = List<int>.filled(115, 0);
    for (var i = 1; i <= 114; i++) {
      offsets[i] = offsets[i - 1] + all[i - 1].ayahCount;
    }
    return offsets;
  }

  static SurahInfo surah(int number) => all[number - 1];

  /// Global ayah number (1..6236) used by audio CDNs.
  static int globalAyah(int surah, int ayah) => _offsets[surah - 1] + ayah;

  /// Converts a global ayah number back to (surah, ayah).
  static ({int surah, int ayah}) fromGlobal(int global) {
    final g = global.clamp(1, totalAyahs);
    var lo = 1, hi = 114;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_offsets[mid] < g) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return (surah: lo, ayah: g - _offsets[lo - 1]);
  }
}
