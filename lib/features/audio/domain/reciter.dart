import 'package:equatable/equatable.dart';

import '../../../core/constants/app_constants.dart';

class Reciter extends Equatable {
  /// Identifier on the Islamic Network CDN.
  final String id;
  final String nameAr;
  final String style;
  final int bitrate;

  const Reciter({required this.id, required this.nameAr, required this.style, required this.bitrate});

  String urlFor(int globalAyah) => '${AppConstants.audioCdnBase}/$bitrate/$id/$globalAyah.mp3';

  @override
  List<Object?> get props => [id];
}

class Reciters {
  Reciters._();

  static const List<Reciter> all = [
    Reciter(id: 'ar.alafasy', nameAr: 'مشاري راشد العفاسي', style: 'مرتل', bitrate: 128),
    Reciter(id: 'ar.abdulbasitmurattal', nameAr: 'عبد الباسط عبد الصمد', style: 'مرتل', bitrate: 192),
    Reciter(id: 'ar.husary', nameAr: 'محمود خليل الحصري', style: 'مرتل', bitrate: 128),
    Reciter(id: 'ar.minshawi', nameAr: 'محمد صديق المنشاوي', style: 'مرتل', bitrate: 128),
    Reciter(id: 'ar.abdurrahmaansudais', nameAr: 'عبد الرحمن السديس', style: 'مرتل', bitrate: 192),
    Reciter(id: 'ar.saoodshuraym', nameAr: 'سعود الشريم', style: 'مرتل', bitrate: 64),
    Reciter(id: 'ar.mahermuaiqly', nameAr: 'ماهر المعيقلي', style: 'مرتل', bitrate: 128),
    Reciter(id: 'ar.ahmedajamy', nameAr: 'أحمد بن علي العجمي', style: 'مرتل', bitrate: 128),
    Reciter(id: 'ar.shaatree', nameAr: 'أبو بكر الشاطري', style: 'مرتل', bitrate: 128),
    Reciter(id: 'ar.hudhaify', nameAr: 'علي الحذيفي', style: 'مرتل', bitrate: 128),
    Reciter(id: 'ar.muhammadayyoub', nameAr: 'محمد أيوب', style: 'مرتل', bitrate: 128),
    Reciter(id: 'ar.abdullahbasfar', nameAr: 'عبد الله بصفر', style: 'مرتل', bitrate: 192),
    Reciter(id: 'ar.hanirifai', nameAr: 'هاني الرفاعي', style: 'مرتل', bitrate: 192),
    Reciter(id: 'ar.muhammadjibreel', nameAr: 'محمد جبريل', style: 'مرتل', bitrate: 128),
    Reciter(id: 'ar.husarymujawwad', nameAr: 'محمود خليل الحصري', style: 'مجوَّد', bitrate: 128),
  ];

  static Reciter byId(String id) => all.firstWhere((r) => r.id == id, orElse: () => all.first);
}

/// A memorization / listening range with repetition settings.
class PlaybackRange extends Equatable {
  final int startSurah;
  final int startAyah;
  final int endSurah;
  final int endAyah;

  /// How many times each ayah is repeated before moving on.
  final int ayahRepeat;

  /// How many times the whole range is played. 0 = infinite loop.
  final int rangeRepeat;

  const PlaybackRange({
    required this.startSurah,
    required this.startAyah,
    required this.endSurah,
    required this.endAyah,
    this.ayahRepeat = 1,
    this.rangeRepeat = 1,
  });

  @override
  List<Object?> get props => [startSurah, startAyah, endSurah, endAyah, ayahRepeat, rangeRepeat];
}
