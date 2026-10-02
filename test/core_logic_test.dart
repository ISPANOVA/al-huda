import 'package:al_huda/core/data/surah_metadata.dart';
import 'package:al_huda/core/utils/arabic_utils.dart';
import 'package:al_huda/features/khatmah/domain/khatmah_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SurahMetadata', () {
    test('contains 114 surahs and 6236 ayahs', () {
      expect(SurahMetadata.all.length, 114);
      expect(SurahMetadata.all.fold<int>(0, (a, s) => a + s.ayahCount), 6236);
    });

    test('global ayah numbering round-trips', () {
      expect(SurahMetadata.globalAyah(1, 1), 1);
      expect(SurahMetadata.globalAyah(2, 255), 262); // Ayat Al-Kursi
      expect(SurahMetadata.globalAyah(114, 6), 6236);
      for (final g in [1, 7, 8, 262, 293, 3000, 6230, 6236]) {
        final r = SurahMetadata.fromGlobal(g);
        expect(SurahMetadata.globalAyah(r.surah, r.ayah), g);
      }
    });
  });

  group('ArabicUtils', () {
    test('eastern Arabic digits', () {
      expect(ArabicUtils.toArabicDigits(2026), '٢٠٢٦');
    });

    test('normalize strips diacritics and unifies alef', () {
      expect(ArabicUtils.normalize('ٱلرَّحْمَٰنِ'), 'الرحمن');
      expect(ArabicUtils.normalize('إِيَّاكَ'), 'اياك');
    });

    test('strips the Basmala prefix except for Al-Fatihah and At-Tawbah', () {
      const text = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ الٓمٓ';
      expect(ArabicUtils.stripBismillah(text, 2), 'الٓمٓ');
      expect(ArabicUtils.stripBismillah(text, 1), text);
    });
  });

  group('KhatmahPlan', () {
    test('30-day plan splits the Mushaf evenly', () {
      final plan = KhatmahPlan(startDate: DateTime.now(), targetDays: 30);
      expect(plan.baseDailyTarget, 208);
      final now = DateTime.now();
      expect(plan.todayFrom(now), 1);
      expect(plan.todayTo(now), 208);
      expect(plan.isTodayDone(now), isFalse);
    });

    test('marking progress completes today', () {
      final now = DateTime.now();
      final plan = KhatmahPlan(
        startDate: now,
        targetDays: 30,
        completedAyahs: 208,
        history: {KhatmahPlan.dayKey(now): 208},
      );
      expect(plan.isTodayDone(now), isTrue);
      expect(plan.todayProgress(now), 1.0);
    });
  });
}
