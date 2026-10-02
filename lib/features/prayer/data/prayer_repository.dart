import 'dart:math' as math;

import 'package:adhan/adhan.dart' as adhan;

import '../domain/prayer_entities.dart';

/// Astronomical prayer-time calculation (offline) using the `adhan` package.
class PrayerRepository {
  static const double _kaabaLat = 21.422487;
  static const double _kaabaLng = 39.826206;

  adhan.CalculationMethod _method(String key) => switch (key) {
        'umm_al_qura' => adhan.CalculationMethod.umm_al_qura,
        'muslim_world_league' => adhan.CalculationMethod.muslim_world_league,
        'karachi' => adhan.CalculationMethod.karachi,
        'dubai' => adhan.CalculationMethod.dubai,
        'kuwait' => adhan.CalculationMethod.kuwait,
        'qatar' => adhan.CalculationMethod.qatar,
        'singapore' => adhan.CalculationMethod.singapore,
        'turkey' => adhan.CalculationMethod.turkey,
        'tehran' => adhan.CalculationMethod.tehran,
        'north_america' => adhan.CalculationMethod.north_america,
        'moon_sighting_committee' => adhan.CalculationMethod.moon_sighting_committee,
        _ => adhan.CalculationMethod.egyptian,
      };

  PrayerDay calculate({
    required UserLocation location,
    required DateTime date,
    required String method,
    required String madhab,
    List<int> adjustments = const [0, 0, 0, 0, 0, 0],
  }) {
    final params = _method(method).getParameters();
    params.madhab = madhab == 'hanafi' ? adhan.Madhab.hanafi : adhan.Madhab.shafi;
    params.adjustments = adhan.PrayerAdjustments(
      fajr: adjustments[0],
      sunrise: adjustments[1],
      dhuhr: adjustments[2],
      asr: adjustments[3],
      maghrib: adjustments[4],
      isha: adjustments[5],
    );
    final pt = adhan.PrayerTimes(
      adhan.Coordinates(location.latitude, location.longitude),
      adhan.DateComponents.from(date),
      params,
    );
    return PrayerDay(DateTime(date.year, date.month, date.day), {
      PrayerName.fajr: pt.fajr.toLocal(),
      PrayerName.sunrise: pt.sunrise.toLocal(),
      PrayerName.dhuhr: pt.dhuhr.toLocal(),
      PrayerName.asr: pt.asr.toLocal(),
      PrayerName.maghrib: pt.maghrib.toLocal(),
      PrayerName.isha: pt.isha.toLocal(),
    });
  }

  /// Next upcoming time (prayers + sunrise) after [now], looking into tomorrow if needed.
  NextPrayer nextPrayer(PrayerDay today, PrayerDay tomorrow, DateTime now) {
    for (final p in PrayerName.values) {
      if (today[p].isAfter(now)) return NextPrayer(p, today[p]);
    }
    return NextPrayer(PrayerName.fajr, tomorrow[PrayerName.fajr]);
  }

  /// Great-circle initial bearing from the user to the Kaaba (degrees from true north).
  static double qiblaDirection(double lat, double lng) {
    final phi1 = _rad(lat);
    final phi2 = _rad(_kaabaLat);
    final dLambda = _rad(_kaabaLng - lng);
    final y = math.sin(dLambda);
    final x = math.cos(phi1) * math.tan(phi2) - math.sin(phi1) * math.cos(dLambda);
    final bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  /// Distance to the Kaaba in km (haversine).
  static double distanceToKaaba(double lat, double lng) {
    const r = 6371.0;
    final dLat = _rad(_kaabaLat - lat);
    final dLng = _rad(_kaabaLng - lng);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(lat)) * math.cos(_rad(_kaabaLat)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
