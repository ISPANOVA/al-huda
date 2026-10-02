import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart';

import '../../../../core/utils/arabic_utils.dart';
import '../../domain/entities/mushaf_line.dart';
import '../models/ayah_model.dart';

/// The whole Mushaf, parsed and indexed.
class QuranBundle {
  /// 6236 ayahs ordered by global number (index = global - 1).
  final List<AyahModel> ayahs;

  /// Diacritics-free text of each ayah for instant searching.
  final List<String> normalized;

  /// pageStart[p] = index of the first ayah on page p (1..604); pageStart[605] = 6236.
  final List<int> pageStart;

  /// lines[p - 1] = printed lines of page p (Madinah 15-line layout).
  final List<List<MushafLine>> lines;

  /// Width (at font size 100) that ~95% of lines fit in; sizes the page font.
  final double referenceWidth;

  const QuranBundle(this.ayahs, this.normalized, this.pageStart, this.lines, this.referenceWidth);
}

/// Reads `assets/quran/quran.json` shipped inside the APK: KFGQPC Uthmani Hafs
/// text, Tafseer Al-Muyassar and page/juz/hizb metadata. No network needed.
class BundledQuranDataSource {
  static const String assetPath = 'assets/quran/quran.json';

  Future<QuranBundle>? _loading;
  QuranBundle? current;

  Future<QuranBundle> load() => _loading ??= _load();

  Future<QuranBundle> _load() async {
    final raw = await rootBundle.loadString(assetPath, cache: false);
    final bundle = await Isolate.run(() => parseQuranBundle(raw));
    current = bundle;
    return bundle;
  }
}

/// Runs in a background isolate.
QuranBundle parseQuranBundle(String raw) {
  final root = jsonDecode(raw) as Map<String, dynamic>;
  final rows = root['a'] as List<dynamic>;
  final ayahs = <AyahModel>[];
  final normalized = <String>[];
  final pageStart = List<int>.filled(606, -1);
  for (var i = 0; i < rows.length; i++) {
    final r = rows[i] as List<dynamic>;
    final page = r[5] as int;
    final ayah = AyahModel(
      number: i + 1,
      surah: r[0] as int,
      numberInSurah: r[1] as int,
      text: r[2] as String,
      tafseer: r[3] as String,
      juz: r[4] as int,
      page: page,
      hizbQuarter: r[6] as int,
      sajda: r[7] == 1,
    );
    ayahs.add(ayah);
    normalized.add(ArabicUtils.searchKey(r.length > 8 ? r[8] as String : ayah.text));
    if (pageStart[page] == -1) pageStart[page] = i;
  }
  pageStart[605] = ayahs.length;
  // Fill any gaps defensively (every page has ayahs in the Madinah Mushaf).
  for (var p = 604; p >= 1; p--) {
    if (pageStart[p] == -1) pageStart[p] = pageStart[p + 1];
  }
  final lines = <List<MushafLine>>[];
  for (final page in root['lines'] as List<dynamic>) {
    final pageLines = <MushafLine>[];
    for (final l in page as List<dynamic>) {
      final row = l as List<dynamic>;
      switch (row[0] as String) {
        case 'h':
          pageLines.add(MushafLine(MushafLineType.header, surah: row[1] as int));
        case 'b':
          pageLines.add(const MushafLine(MushafLineType.basmala));
        default:
          final words = <MushafWord>[
            for (var i = 2; i + 1 < row.length; i += 2) MushafWord(row[i] as int, row[i + 1] as String),
          ];
          pageLines.add(MushafLine(
            row[0] == 'c' ? MushafLineType.centered : MushafLineType.text,
            width100: (row[1] as num).toDouble(),
            words: words,
          ));
      }
    }
    lines.add(pageLines);
  }
  return QuranBundle(ayahs, normalized, pageStart, lines, (root['ref50'] as num? ?? root['ref'] as num? ?? 1540).toDouble());
}
