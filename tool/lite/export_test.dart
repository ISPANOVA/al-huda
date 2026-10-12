// Exports the app's content (written once, in Dart) as JSON for the light
// web version: `flutter test tool/lite/export_test.dart` with LITE_OUT set.
import 'dart:convert';
import 'dart:io';

import 'package:al_huda/core/data/surah_metadata.dart';
import 'package:al_huda/features/athkar/data/athkar_data.dart';
import 'package:al_huda/features/audio/domain/reciter.dart';
import 'package:al_huda/features/calendar/islamic_calendar.dart';
import 'package:al_huda/features/content/asma_data.dart';
import 'package:al_huda/features/content/nawawi_data.dart';
import 'package:al_huda/features/duas/duas_data.dart';
import 'package:al_huda/features/media/media_catalog.dart';
import 'package:al_huda/features/virtues/virtues_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('export', () {
    final out = Platform.environment['LITE_OUT'] ?? 'build/lite/data';
    Directory(out).createSync(recursive: true);
    void write(String name, Object data) =>
        File('$out/$name.json').writeAsStringSync(jsonEncode(data));

    write('surahs', [
      for (final s in SurahMetadata.all) [s.number, s.name, s.ayahCount, s.isMeccan ? 1 : 0, s.englishName],
    ]);
    write('athkar', [
      for (final c in AthkarData.categories)
        {
          'id': c.id,
          'title': c.title,
          'subtitle': c.subtitle,
          'items': [
            for (final t in c.items)
              {
                'id': t.id,
                'text': t.text,
                'count': t.count,
                'source': t.source,
                if (t.virtue != null) 'virtue': t.virtue,
                if (t.quran != null) 'quran': [t.quran!.surah, t.quran!.from, t.quran!.to],
              },
          ],
        },
    ]);
    write('asma', [for (final (n, m) in kAsmaUlHusna) [n, m]]);
    write('nawawi', [for (final (n, t, x) in kNawawi) [n, t, x]]);
    write('duas', [
      for (final c in kDuaCategories)
        {
          'id': c.id,
          'title': c.title,
          'items': [
            for (final d in c.items) {'text': d.text, 'source': d.source, if (d.note != null) 'note': d.note},
          ],
        },
    ]);
    write('virtues', [
      for (final c in VirtuesData.categories)
        {
          'title': c.title,
          'subtitle': c.subtitle,
          'items': [
            for (final v in c.items) {'text': v.text, 'source': v.source, if (v.isQuran) 'quran': true},
          ],
        },
    ]);
    write('reciters', [
      for (final r in Reciters.all) {'id': r.id, 'name': r.nameAr, 'style': r.style, 'bitrate': r.bitrate},
    ]);
    write('media', {
      'reciters': [
        for (final r in MediaCatalog.reciters)
          {'key': r.key, 'name': r.name, 'style': r.style, 'server': r.server, 'region': r.region.name},
      ],
      'featured': [for (final r in MediaCatalog.featured) r.key],
      'official': [for (final r in kOfficialRadios) _radio(r)],
      'reciterRadios': [for (final r in kReciterRadios) _radio(r)],
      'themeRadios': [for (final r in kThemeRadios) _radio(r)],
      'live': [
        {
          'title': 'الحرم المكي',
          'subtitle': 'المسجد الحرام • قناة القرآن الكريم',
          'urls': ['https://cdn-globecast.akamaized.net/live/eds/saudi_quran/hls_roku/index.m3u8'],
        },
        {
          'title': 'الحرم النبوي',
          'subtitle': 'المسجد النبوي • قناة السنة النبوية',
          'urls': ['https://cdn-globecast.akamaized.net/live/eds/saudi_sunnah/hls_roku/index.m3u8'],
        },
      ],
    });
    final occasions = <List<Object>>[];
    for (var m = 1; m <= 12; m++) {
      for (var d = 1; d <= 30; d++) {
        for (final o in IslamicCalendar.on(m, d)) {
          occasions.add([m, d, o.title, o.note, o.fast ? 1 : 0]);
        }
      }
    }
    write('calendar', {'months': IslamicCalendar.months, 'occasions': occasions});
  });
}

Map<String, Object?> _radio(MediaRadio r) => {
      'name': r.name,
      'urls': r.urls,
      if (r.reciterKey != null) 'reciter': r.reciterKey,
      if (r.subtitle != null) 'subtitle': r.subtitle,
    };
