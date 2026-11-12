import 'dart:convert';

import 'package:flutter/services.dart';

/// أسباب النزول from three books (assets/quran/asbab.json): «صحيح أسباب
/// النزول» of Ibrahim al-Ali (the MIT-licensed mostafaahmed97 dataset),
/// «المحرر في أسباب النزول» of Khalid al-Muzaini and the «أسباب النزول» of
/// al-Wahidi (both from the Quranpedia dumps).
typedef AsbabEntry = ({int source, int surah, List<int> ayahs, List<String> texts});

class Asbab {
  Asbab._();

  static List<AsbabEntry> _items = const [];
  static Map<String, List<int>> _ayahs = const {};
  static List<String> sources = const [];
  static List<String> names = const [];
  static Future<void>? _loading;
  static bool get loaded => _loading != null && _items.isNotEmpty;

  static Future<void> load() => _loading ??= () async {
        final raw = jsonDecode(await rootBundle.loadString('assets/quran/asbab.json')) as Map<String, dynamic>;
        sources = [for (final x in raw['sources'] as List) x as String];
        names = [for (final x in raw['names'] as List) x as String];
        _items = [
          for (final e in raw['items'] as List)
            (
              source: (e as List)[0] as int,
              surah: e[1] as int,
              ayahs: [for (final a in e[2] as List) a as int],
              texts: [for (final t in e[3] as List) t as String],
            ),
        ];
        _ayahs = {
          for (final e in (raw['ayahs'] as Map<String, dynamic>).entries) e.key: [for (final i in e.value as List) i as int],
        };
      }();

  /// The occasions told for this ayah (each with the ayahs it covers).
  static List<AsbabEntry> of(int surah, int ayah) =>
      [for (final i in _ayahs['$surah:$ayah'] ?? const <int>[]) _items[i]];
}
