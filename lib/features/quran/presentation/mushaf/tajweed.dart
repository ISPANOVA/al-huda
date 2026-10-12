import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tajweed colours for the Mushaf (assets/quran/tajweed.txt, made by
/// tool/quran/tajweed.py from Quran.com's word data, matched letter by letter
/// to the app's KFGQPC text).
class Tajweed {
  Tajweed._();

  /// The rules in the order of the data file, with their colours on a light
  /// page and on a dark one (the same family, readable on both).
  static const rules = <TajweedRule>[
    TajweedRule('همزة الوصل', 'تُكتب ولا تُنطق عند الوصل', Color(0xFF9A9A9A), Color(0xFF8C8C8C)),
    TajweedRule('حرف لا يُنطق', 'حروف تُكتب ولا تُقرأ', Color(0xFF9A9A9A), Color(0xFF8C8C8C)),
    TajweedRule('اللام الشمسية', 'لام تُدغم فيما بعدها فلا تُنطق', Color(0xFF9A9A9A), Color(0xFF8C8C8C)),
    TajweedRule('مد طبيعي', 'حركتان', Color(0xFFB8860B), Color(0xFFE2C275)),
    TajweedRule('مد جائز منفصل', '٢ أو ٤ أو ٥ حركات', Color(0xFFE8590C), Color(0xFFFF9A3C)),
    TajweedRule('مد لازم', '٦ حركات', Color(0xFFB5121B), Color(0xFFFF5C63)),
    TajweedRule('مد واجب متصل', '٤ أو ٥ حركات', Color(0xFFD6336C), Color(0xFFFF7AA8)),
    TajweedRule('قلقلة', 'اضطراب الصوت عند السكون', Color(0xFF1C6FD1), Color(0xFF6FB2FF)),
    TajweedRule('إخفاء شفوي', 'ميم ساكنة قبل الباء مع غنة', Color(0xFFAE3EC9), Color(0xFFD99BFF)),
    TajweedRule('إخفاء', 'نون ساكنة أو تنوين بغنة', Color(0xFF9C36B5), Color(0xFFD08CF0)),
    TajweedRule('إدغام شفوي', 'ميم ساكنة في ميم بغنة', Color(0xFF2B8A3E), Color(0xFF69DB7C)),
    TajweedRule('إقلاب', 'النون الساكنة ميمًا قبل الباء', Color(0xFF1098AD), Color(0xFF3BC9DB)),
    TajweedRule('إدغام بغنة', 'في حروف (ينمو)', Color(0xFF087F5B), Color(0xFF38D9A9)),
    TajweedRule('إدغام بلا غنة', 'في اللام والراء', Color(0xFF5C7A5C), Color(0xFF9DBB9D)),
    TajweedRule('إدغام متجانسين', 'حرفان اتحدا مخرجًا', Color(0xFF868E96), Color(0xFFADB5BD)),
    TajweedRule('إدغام متقاربين', 'حرفان تقاربا مخرجًا', Color(0xFF868E96), Color(0xFFADB5BD)),
    TajweedRule('غنة', 'النون والميم المشددتان', Color(0xFF2F9E44), Color(0xFF8CE99A)),
  ];

  /// Per page: per word (in reading order), its runs (start, end, rule).
  static List<List<List<(int, int, int)>>>? _pages;
  static Future<void>? _loading;

  static bool get ready => _pages != null;

  static Future<void> load() => _loading ??= () async {
        final raw = await rootBundle.loadString('assets/quran/tajweed.txt');
        _pages = await compute(_parse, raw);
      }();

  static List<List<List<(int, int, int)>>> _parse(String raw) => [
        for (final line in raw.split('\n'))
          [
            for (final w in line.split('|'))
              [
                if (w.isNotEmpty)
                  for (final r in w.split(','))
                    if (r.split('.') case [final a, final b, final c]) (int.parse(a), int.parse(b), int.parse(c)),
              ],
          ],
      ];

  /// Runs of word [index] (counting the page's words in reading order) on [page].
  static List<(int, int, int)> runs(int page, int index) {
    final p = _pages;
    if (p == null || page < 1 || page > p.length) return const [];
    final words = p[page - 1];
    return index < words.length ? words[index] : const [];
  }
}

class TajweedRule {
  final String name;
  final String note;
  final Color light;
  final Color dark;

  const TajweedRule(this.name, this.note, this.light, this.dark);
}

/// The colour key, shown from the reading settings.
Future<void> showTajweedLegend(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final seen = <String>{};
  final items = [
    for (final r in Tajweed.rules)
      if (seen.add('${r.light.toARGB32()}${r.name}')) r,
  ];
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Text('ألوان التجويد', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          for (final r in items)
            ListTile(
              dense: true,
              leading: CircleAvatar(radius: 10, backgroundColor: dark ? r.dark : r.light),
              title: Text(r.name, style: TextStyle(fontWeight: FontWeight.w800, color: dark ? r.dark : r.light)),
              subtitle: Text(r.note),
            ),
          const Text('الألوان تقريبية مساعدة على التعلم، والعبرة بالتلقي من شيخ متقن.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
        ],
      ),
    ),
  );
}
