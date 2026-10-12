import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' as w;

/// The interface in English: every Arabic string the app shows is looked up
/// in assets/i18n/en.json (the website uses the same file). The Quran, athkar,
/// duas and hadith stay in Arabic: whatever has no English entry is shown as it is.
///
/// A string is matched exactly; or with its numbers taken out («الآية ٣» →
/// «الآية {}»); or against a pattern whose gaps are themselves translated
/// («سورة {}» with a surah name); or piece by piece across « • », «، »…; or,
/// for dates and times, word by word. Arabic digits become Latin ones.
class I18n {
  I18n._();

  static bool en = false;
  static final Map<String, String> _map = {};
  static final List<(String, String)> _vocab = [];
  static final List<(RegExp, String, bool)> _patterns = [];
  static final Map<String, String> _cache = {};

  static w.TextDirection get direction => en ? w.TextDirection.ltr : w.TextDirection.rtl;
  static String get dateLocale => en ? 'en' : 'ar';

  static Future<void> load(String lang) async {
    _cache.clear();
    if (lang != 'en') {
      en = false;
      return;
    }
    try {
      final j = jsonDecode(await rootBundle.loadString('assets/i18n/en.json')) as Map<String, dynamic>;
      setData(Map<String, String>.from(j['map'] as Map), Map<String, String>.from(j['vocab'] as Map));
      en = true;
    } catch (_) {
      en = false;
    }
  }

  /// The dictionary itself (also used by tests).
  static void setData(Map<String, String> map, Map<String, String> vocab) {
    _cache.clear();
    _map
      ..clear()
      ..addAll(map);
    _vocab
      ..clear()
      ..addAll(vocab.entries.map((e) => (e.key, e.value)))
      ..sort((a, b) => b.$1.length.compareTo(a.$1.length));
    _patterns
      ..clear()
      ..addAll([
        for (final e in map.entries)
          if (e.key.contains('{}') && _letters.hasMatch(e.key.replaceAll('{}', '')))
            (
              RegExp('^${e.key.split('{}').map(RegExp.escape).join('(.+?)')}\$'),
              e.value,
              // Enough words around the gap to be sure a name may fill it.
              _letters.allMatches(e.key.replaceAll('{}', '')).length >= 5,
            ),
      ])
      // The most specific (longest literal text) first.
      ..sort((a, b) => b.$1.pattern.length.compareTo(a.$1.pattern.length));
  }

  static final _letters = RegExp('[ء-ي]');
  static final _number = RegExp(r'[0-9٠-٩]+(?:[:.,/٫][0-9٠-٩]+)*');
  static final _separators = RegExp(r'( • | · |، |\n| - | — | \| |: )');

  static String tr(String s) {
    if (!en || s.isEmpty) return s;
    final hit = _cache[s];
    if (hit != null) return hit;
    if (_cache.length > 6000) _cache.clear();
    return _cache[s] = _translate(s, 0) ?? s;
  }

  static String latinDigits(String s) {
    final b = StringBuffer();
    for (final c in s.runes) {
      if (c >= 0x0660 && c <= 0x0669) {
        b.writeCharCode(c - 0x0660 + 0x30);
      } else if (c == 0x066B) {
        b.write('.');
      } else if (c == 0x066C) {
        b.write(',');
      } else {
        b.writeCharCode(c);
      }
    }
    return b.toString();
  }

  static String _fill(String template, List<String> parts) {
    var i = 0;
    return template.replaceAllMapped('{}', (_) => i < parts.length ? parts[i++] : '');
  }

  static String? _translate(String s, int depth) {
    if (!_letters.hasMatch(s)) return latinDigits(s);
    final t = s.trim();
    if (t.length != s.length) {
      final r = _translate(t, depth);
      return r == null ? null : s.replaceFirst(t, r);
    }
    final exact = _map[t];
    if (exact != null) return exact;
    if (depth > 3) return null;

    // «الآية ٣» → «الآية {}»
    final numbers = <String>[];
    final key = t.replaceAllMapped(_number, (m) {
      numbers.add(latinDigits(m[0]!));
      return '{}';
    });
    if (numbers.isNotEmpty) {
      final e = _map[key];
      if (e != null) return _fill(e, numbers);
    }

    // «سورة {}», «باقٍ {} على الفجر ({})»: each gap translated in turn; a
    // short name with no entry (a city) is kept as it is.
    for (final (re, english, lenient) in _patterns) {
      final m = re.firstMatch(t);
      if (m == null) continue;
      final parts = <String>[];
      var ok = true;
      for (var i = 1; i <= m.groupCount; i++) {
        final g = m[i]!;
        final r = _translate(g, depth + 1) ?? (lenient && g.split(' ').length <= 3 ? g : null);
        if (r == null) {
          ok = false;
          break;
        }
        parts.add(r);
      }
      if (ok) return _fill(english, parts);
    }

    // «الفجر • ٤:٣٠ ص»: every piece must translate.
    final pieces = t.split(_separators);
    if (pieces.length > 1) {
      final seps = _separators.allMatches(t).map((m) => m[0]!).toList();
      final out = StringBuffer();
      for (var i = 0; i < pieces.length; i++) {
        final p = pieces[i];
        final r = p.isEmpty ? '' : _translate(p, depth + 1);
        if (r == null) return _words(t);
        out.write(r);
        if (i < seps.length) out.write(seps[i] == '، ' ? ', ' : seps[i]);
      }
      return out.toString();
    }
    return _words(t);
  }

  /// Dates and times: month and day names, «هـ», «ص/م», word by word.
  static String? _words(String t) {
    var v = ' $t ';
    for (final (ar, english) in _vocab) {
      if (!v.contains(ar)) continue;
      v = v.replaceAllMapped(RegExp('(?<=[\\s,،(])${RegExp.escape(ar)}(?=[\\s,،)])'), (_) => english);
    }
    v = v.replaceAll('،', ',').trim();
    if (_letters.hasMatch(v)) return null;
    return latinDigits(v);
  }
}

/// The current interface language's text for [s] (Arabic as it is).
String tr(String s) => I18n.tr(s);
