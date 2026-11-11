import 'dart:convert';

import 'package:flutter/services.dart';

/// أسباب النزول: the authenticated occasions of revelation, from «صحيح أسباب
/// النزول» of Ibrahim Muhammad al-Ali (assets/quran/asbab.json, made from
/// the MIT-licensed mostafaahmed97/asbab-al-nuzul-dataset).
class Asbab {
  Asbab._();

  static List<({int surah, List<int> ayahs, List<String> texts})> _items = const [];
  static Map<String, List<int>> _ayahs = const {};
  static String source = '';
  static Future<void>? _loading;
  static bool get loaded => _loading != null && _items.isNotEmpty;

  static Future<void> load() => _loading ??= () async {
        final raw = jsonDecode(await rootBundle.loadString('assets/quran/asbab.json')) as Map<String, dynamic>;
        source = raw['source'] as String? ?? '';
        _items = [
          for (final e in raw['items'] as List)
            (
              surah: (e as List)[0] as int,
              ayahs: [for (final a in e[1] as List) a as int],
              texts: [for (final t in e[2] as List) t as String],
            ),
        ];
        _ayahs = {
          for (final e in (raw['ayahs'] as Map<String, dynamic>).entries) e.key: [for (final i in e.value as List) i as int],
        };
      }();

  /// The occasions told for this ayah (each with the ayahs it covers).
  static List<({int surah, List<int> ayahs, List<String> texts})> of(int surah, int ayah) =>
      [for (final i in _ayahs['$surah:$ayah'] ?? const <int>[]) _items[i]];
}
