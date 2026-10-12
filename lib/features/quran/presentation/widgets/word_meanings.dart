import 'dart:convert';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../../../core/theme/app_themes.dart';
import '../../domain/entities/ayah.dart';
import '../../../../core/i18n/text.dart';

/// غريب الكلمات: the meanings of an ayah's uncommon words, from two classical
/// books: «التبيان» of Ibn al-Haim (d. 815 AH), else «تذكرة الأريب» of Ibn
/// al-Jawzi (d. 597 AH), digitised by Quranpedia (assets/quran/gharib.json,
/// extracted in CI by probe.yml).
class Gharib {
  Gharib._();

  static Map<String, List<(String, String)>>? _ayahs;
  static Map<String, String> _books = const {};
  static final Map<String, String> _bookOf = {};
  static String _via = '';
  static Future<void>? _loading;

  static Future<void> load() => _loading ??= () async {
        final raw = jsonDecode(await rootBundle.loadString('assets/quran/gharib.json')) as Map<String, dynamic>;
        final src = raw['source'] as Map<String, dynamic>;
        _via = src['via'] as String? ?? '';
        _books = {for (final e in src.entries) if (e.key != 'via') e.key: e.value as String};
        final map = <String, List<(String, String)>>{};
        for (final e in (raw['ayahs'] as Map<String, dynamic>).entries) {
          final v = e.value as List;
          _bookOf[e.key] = v.first as String;
          map[e.key] = [for (final w in v.skip(1)) ((w as List)[0] as String, w[1] as String)];
        }
        _ayahs = map;
      }();

  static List<(String, String)> of(int surah, int ayah) => _ayahs?['$surah:$ayah'] ?? const [];

  /// The book the meanings of this ayah come from, and the digitiser.
  static String sourceOf(int surah, int ayah) => '${_books[_bookOf['$surah:$ayah']] ?? ''}، عبر $_via';
}

/// A folded box under the tafsir: the ayah's words and their meanings.
class WordMeaningsPanel extends StatefulWidget {
  final Ayah ayah;

  const WordMeaningsPanel({super.key, required this.ayah});

  @override
  State<WordMeaningsPanel> createState() => _WordMeaningsPanelState();
}

class _WordMeaningsPanelState extends State<WordMeaningsPanel> {
  @override
  void initState() {
    super.initState();
    Gharib.load().then((_) => mounted ? setState(() {}) : null).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final words = Gharib.of(widget.ayah.surah, widget.ayah.numberInSurah);
    if (words.isEmpty) return const SizedBox.shrink();
    final glass = GlassTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        decoration: BoxDecoration(
          color: glass.onGlass.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: glass.accent.withValues(alpha: 0.25)),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            shape: const RoundedRectangleBorder(),
            leading: Icon(Icons.translate_rounded, color: glass.accent),
            title: const Text('معاني الكلمات', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${words.length} من غريب الآية', style: TextStyle(fontSize: 12, color: glass.onGlassMuted)),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            children: [
              for (final (w, m) in words)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: '$w: ',
                          style: TextStyle(fontFamily: 'UthmanicHafs', fontSize: 19, color: glass.accent, fontWeight: FontWeight.w700)),
                      TextSpan(text: m, style: TextStyle(fontSize: 15, height: 1.8, color: glass.onGlass)),
                    ]),
                  ),
                ),
              Text(Gharib.sourceOf(widget.ayah.surah, widget.ayah.numberInSurah), style: TextStyle(fontSize: 11, color: glass.onGlassMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
