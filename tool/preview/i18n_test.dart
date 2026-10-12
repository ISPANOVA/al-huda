// The English interface: the dictionary loads and typical strings translate
// (writes tool/preview/out/i18n.txt for a look).
import 'dart:convert';
import 'dart:io';

import 'package:al_huda/core/i18n/i18n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('english interface', () {
    final j = jsonDecode(File('assets/i18n/en.json').readAsStringSync()) as Map<String, dynamic>;
    I18n.setData(Map<String, String>.from(j['map'] as Map), Map<String, String>.from(j['vocab'] as Map));
    I18n.en = true;
    final samples = {
      'الإعدادات': 'Settings',
      'الآية ٣': 'Ayah 3',
      'سورة البقرة': 'Surah Al-Baqarah',
      '١٢ آية': '12 ayahs',
      'الفجر • ٤:٣٠ ص': 'Fajr • 4:30 AM',
      'مواقيت الصلاة في القاهرة • الثلاثاء ١٣ أكتوبر • ٢ جمادى الأولى ١٤٤٨ هـ': null,
      '١٥ رمضان ١٤٤٨ هـ': '15 Ramadan 1448 AH',
      'أتمّه سمير': 'Finished by سمير',
      'رمضان كريم • اليوم ٥': 'Ramadan Kareem • Day 5',
      'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ': 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ',
      'من حفظك': 'من حفظك',
    };
    final out = StringBuffer();
    var bad = 0;
    for (final e in samples.entries) {
      final got = I18n.tr(e.key);
      out.writeln('${e.key}  =>  $got');
      if (e.value != null && got != e.value) {
        bad++;
        out.writeln('   !! expected ${e.value}');
      }
    }
    Directory('tool/preview/out').createSync(recursive: true);
    File('tool/preview/out/i18n.txt').writeAsStringSync(out.toString());
    expect(bad, 0, reason: out.toString());
  });
}
