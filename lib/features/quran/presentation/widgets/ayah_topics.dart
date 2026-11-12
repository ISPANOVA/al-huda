import 'dart:convert';

import 'package:flutter/services.dart';

/// موضوع الآية: the Quranic topics each ayah belongs to, from Quranpedia's
/// «الموضوعات القرآنية» (assets/quran/topics.json). Ayahs the index leaves out
/// borrow the topics of the nearest indexed ayah around them (up to
/// [reach] ayahs away), marked as such.
class AyahTopics {
  AyahTopics._();

  static const reach = 5;
  static List<(String, String?)> _topics = const [];
  static Map<String, List<int>> _ayahs = const {};
  static String source = '';
  static Future<void>? _loading;

  static Future<void> load() => _loading ??= () async {
        final raw = jsonDecode(await rootBundle.loadString('assets/quran/topics.json')) as Map<String, dynamic>;
        source = raw['source'] as String? ?? '';
        _topics = [
          for (final t in raw['topics'] as List) ((t as List)[0] as String, t.length > 1 ? t[1] as String : null),
        ];
        _ayahs = {
          for (final e in (raw['ayahs'] as Map<String, dynamic>).entries) e.key: [for (final i in e.value as List) i as int],
        };
      }();

  /// The topics (name, parent) and the ayah they come from: [ayah] itself,
  /// or a neighbour within [reach] when the index has none for it.
  static ({int from, List<(String, String?)> topics})? of(int surah, int ayah) {
    for (var d = 0; d <= reach; d++) {
      for (final a in d == 0 ? [ayah] : [ayah - d, ayah + d]) {
        final ids = _ayahs['$surah:$a'];
        if (ids != null) return (from: a, topics: [for (final i in ids) _topics[i]]);
      }
    }
    return null;
  }
}
