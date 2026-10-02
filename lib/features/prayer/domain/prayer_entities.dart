import 'package:equatable/equatable.dart';

enum PrayerName { fajr, sunrise, dhuhr, asr, maghrib, isha }

extension PrayerNameX on PrayerName {
  String get nameAr => switch (this) {
        PrayerName.fajr => 'الفجر',
        PrayerName.sunrise => 'الشروق',
        PrayerName.dhuhr => 'الظهر',
        PrayerName.asr => 'العصر',
        PrayerName.maghrib => 'المغرب',
        PrayerName.isha => 'العشاء',
      };

  bool get isPrayer => this != PrayerName.sunrise;

  /// Name on a given day: Dhuhr is "الجمعة" on Fridays.
  String nameOn(DateTime day) =>
      this == PrayerName.dhuhr && day.weekday == DateTime.friday ? 'الجمعة' : nameAr;
}

class UserLocation extends Equatable {
  final double latitude;
  final double longitude;
  final String? city;

  const UserLocation({required this.latitude, required this.longitude, this.city});

  Map<String, dynamic> toMap() => {'lat': latitude, 'lng': longitude, 'city': city};

  factory UserLocation.fromMap(Map<String, dynamic> m) => UserLocation(
        latitude: (m['lat'] as num).toDouble(),
        longitude: (m['lng'] as num).toDouble(),
        city: m['city'] as String?,
      );

  @override
  List<Object?> get props => [latitude, longitude, city];
}

class PrayerDay extends Equatable {
  final DateTime date;
  final Map<PrayerName, DateTime> times;

  const PrayerDay(this.date, this.times);

  DateTime operator [](PrayerName p) => times[p]!;

  @override
  List<Object?> get props => [date, times];
}

class NextPrayer extends Equatable {
  final PrayerName name;
  final DateTime time;

  const NextPrayer(this.name, this.time);

  @override
  List<Object?> get props => [name, time];
}

/// Calculation methods supported by the `adhan` package (Arabic labels).
const Map<String, String> kCalculationMethods = {
  'egyptian': 'الهيئة المصرية العامة للمساحة (مصر)',
  'umm_al_qura': 'تقويم أم القرى (السعودية)',
  'muslim_world_league': 'رابطة العالم الإسلامي',
  'karachi': 'جامعة العلوم الإسلامية - كراتشي',
  'dubai': 'الإمارات (دبي)',
  'kuwait': 'الكويت',
  'qatar': 'قطر',
  'singapore': 'سنغافورة',
  'turkey': 'رئاسة الشؤون الدينية - تركيا',
  'tehran': 'معهد الجيوفيزياء - طهران',
  'north_america': 'أمريكا الشمالية (ISNA)',
  'moon_sighting_committee': 'لجنة رؤية الهلال',
};

/// Fiqh schools. Only the Hanafi school changes the Asr time (shadow = 2×);
/// Shafi'i, Maliki and Hanbali share the standard Asr (shadow = 1×).
const Map<String, String> kMadhabs = {
  'shafi': 'الشافعي',
  'maliki': 'المالكي',
  'hanbali': 'الحنبلي',
  'hanafi': 'الحنفي',
};
