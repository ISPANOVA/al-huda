import '../../../core/theme/tones.dart';
import '../domain/prayer_entities.dart';

/// Each prayer in the colour of its sky: violet before dawn, amber sunrise,
/// golden noon, coral afternoon, rose sunset and sapphire night.
extension PrayerTone on PrayerName {
  Tone get tone => switch (this) {
        PrayerName.fajr => Tone.amethyst,
        PrayerName.sunrise => Tone.amber,
        PrayerName.dhuhr => Tone.gold,
        PrayerName.asr => Tone.coral,
        PrayerName.maghrib => Tone.rose,
        PrayerName.isha => Tone.sapphire,
      };
}
