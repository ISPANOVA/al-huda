import '../../../../core/utils/arabic_utils.dart';
import '../../domain/entities/ayah.dart';

class AyahModel extends Ayah {
  const AyahModel({
    required super.number,
    required super.surah,
    required super.numberInSurah,
    required super.text,
    required super.tafseer,
    required super.juz,
    required super.page,
    required super.sajda,
    super.hizbQuarter,
  });

  /// Merges an Uthmani ayah JSON and its Tafseer counterpart from alquran.cloud.
  factory AyahModel.fromApi(Map<String, dynamic> textJson, Map<String, dynamic>? tafseerJson, int surah) {
    final sajda = textJson['sajda'];
    return AyahModel(
      number: (textJson['number'] as num).toInt(),
      surah: surah,
      numberInSurah: (textJson['numberInSurah'] as num).toInt(),
      text: ArabicUtils.stripBismillah(textJson['text'] as String? ?? '', surah),
      tafseer: (tafseerJson?['text'] as String? ?? '').trim(),
      juz: (textJson['juz'] as num?)?.toInt() ?? 0,
      page: (textJson['page'] as num?)?.toInt() ?? 0,
      sajda: sajda is Map || sajda == true,
      hizbQuarter: (textJson['hizbQuarter'] as num?)?.toInt() ?? 0,
    );
  }

  factory AyahModel.fromMap(Map<String, dynamic> m) => AyahModel(
        number: (m['n'] as num).toInt(),
        surah: (m['s'] as num).toInt(),
        numberInSurah: (m['a'] as num).toInt(),
        text: m['t'] as String,
        tafseer: m['f'] as String? ?? '',
        juz: (m['j'] as num?)?.toInt() ?? 0,
        page: (m['p'] as num?)?.toInt() ?? 0,
        sajda: m['sj'] as bool? ?? false,
        hizbQuarter: (m['hq'] as num?)?.toInt() ?? 0,
      );

  /// Compact keys keep the Hive cache small (~6 MB for the whole Mushaf + Tafseer).
  Map<String, dynamic> toMap() => {
        'n': number,
        's': surah,
        'a': numberInSurah,
        't': text,
        'f': tafseer,
        'j': juz,
        'p': page,
        'sj': sajda,
        'hq': hizbQuarter,
      };
}
