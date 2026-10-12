import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/surah_metadata.dart';
import '../../../../core/theme/app_themes.dart';
import '../../../../core/theme/tones.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/noor_ui.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/repositories/quran_repository.dart';
import '../mushaf/mushaf_reader_page.dart';

/// المتشابهات اللفظية: ayahs that share a run of words, computed from the
/// Mushaf text by tool/quran/mutashabihat.py (assets/quran/mutashabihat.json).
class Mutashabihat {
  Mutashabihat._();

  static Map<int, List<int>>? _index;

  static Future<Map<int, List<int>>> load() async {
    if (_index != null) return _index!;
    final raw = jsonDecode(await rootBundle.loadString('assets/quran/mutashabihat.json')) as Map<String, dynamic>;
    return _index = {for (final e in raw.entries) int.parse(e.key): (e.value as List).map((x) => (x as num).toInt()).toList()};
  }

  static Map<int, List<int>>? get loaded => _index;

  static final _marks = RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]');

  static String _norm(String w) {
    var t = w.replaceAll(_marks, '');
    const map = {'ٱ': 'ا', 'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ى': 'ي', 'ة': 'ه', 'ؤ': 'و', 'ئ': 'ي', 'ۥ': '', 'ۦ': ''};
    map.forEach((a, b) => t = t.replaceAll(a, b));
    return t;
  }

  static List<String> words(String text) =>
      text.replaceAll(RegExp(r'[ \s]+[٠-٩]+$'), '').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  /// Which words of [b] belong to a run of two or more words also in [a].
  static List<bool> shared(String a, String b) {
    final aw = words(a).map(_norm).toList();
    final bw = words(b).map(_norm).toList();
    final pairs = <String>{for (var i = 0; i + 1 < aw.length; i++) '${aw[i]} ${aw[i + 1]}'};
    final out = List<bool>.filled(bw.length, false);
    for (var i = 0; i + 1 < bw.length; i++) {
      if (pairs.contains('${bw[i]} ${bw[i + 1]}')) out[i] = out[i + 1] = true;
    }
    if (bw.length == 1 && aw.length == 1 && aw.first == bw.first) out[0] = true;
    return out;
  }
}

/// The ayahs similar to [ayah], the shared words in colour.
Future<void> showSimilarAyahs(BuildContext context, Ayah ayah) async {
  final index = await Mutashabihat.load();
  if (!context.mounted) return;
  final repo = context.read<QuranRepository>();
  final others = [for (final g in index[ayah.number] ?? const <int>[]) repo.ayahByNumber(g)].whereType<Ayah>().toList();
  if (others.isEmpty) {
    showGlassSnack(context, 'لا توجد آيات متشابهة لفظيًا مع هذه الآية');
    return;
  }
  await showGlassSheet<void>(context, builder: (ctx) {
    return SizedBox(
      height: MediaQuery.sizeOf(ctx).height * 0.75,
      child: Column(
        children: [
          Text('آيات متشابهة', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text('${ArabicUtils.toArabicDigits(others.length)} آية تشترك في ألفاظها مع ${_ref(ayah)}',
              style: TextStyle(fontSize: 12.5, color: GlassTheme.of(ctx).onGlassMuted)),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: [
                _AyahCompare(ayah: ayah, other: null),
                const Divider(),
                for (final o in others) _AyahCompare(ayah: o, other: ayah),
              ],
            ),
          ),
        ],
      ),
    );
  });
}

String _ref(Ayah a) => 'سورة ${SurahMetadata.surah(a.surah).name} ${ArabicUtils.toArabicDigits(a.numberInSurah)}';

class _AyahCompare extends StatelessWidget {
  final Ayah ayah;
  final Ayah? other; // the ayah it is compared with (null: the ayah itself)

  const _AyahCompare({required this.ayah, required this.other});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final w = Mutashabihat.words(ayah.text);
    final mark = other == null ? List<bool>.filled(w.length, false) : Mutashabihat.shared(other!.text, ayah.text);
    final hi = Tone.coral.ink(dark);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).pop();
        MushafReaderPage.open(context, surah: ayah.surah, ayah: ayah.numberInSurah);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_ref(ayah),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: other == null ? glass.accent : glass.onGlassMuted)),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(children: [
                for (var i = 0; i < w.length; i++)
                  TextSpan(text: '${w[i]} ', style: mark[i] ? TextStyle(color: hi) : null),
              ]),
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: 'UthmanicHafs', fontSize: 21, height: 1.9, color: glass.onGlass),
            ),
          ],
        ),
      ),
    );
  }
}

/// «المتشابهات»: a surah's ayahs that resemble others, for revision.
class SimilarAyahsPage extends StatefulWidget {
  const SimilarAyahsPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const SimilarAyahsPage());

  @override
  State<SimilarAyahsPage> createState() => _SimilarAyahsPageState();
}

class _SimilarAyahsPageState extends State<SimilarAyahsPage> {
  int _surah = 2;

  @override
  void initState() {
    super.initState();
    Mutashabihat.load().then((_) => mounted ? setState(() {}) : null);
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final index = Mutashabihat.loaded;
    final repo = context.read<QuranRepository>();
    final info = SurahMetadata.surah(_surah);
    final first = SurahMetadata.globalAyah(_surah, 1);
    final ayahs = [
      for (var g = first; g < first + info.ayahCount; g++)
        if ((index?[g] ?? const []).isNotEmpty) g,
    ];
    return GlassScaffold(
      title: 'المتشابهات اللفظية',
      subtitle: 'آيات تتشابه ألفاظها، لتثبيت الحفظ',
      icon: Icons.compare_arrows_rounded,
      tone: Tone.coral,
      body: index == null || !repo.isReady
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                NoorCard(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ListTile(
                    leading: const ToneIcon(Icons.menu_book_rounded, tone: Tone.coral, size: 40),
                    title: Text('سورة ${info.name}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${ArabicUtils.toArabicDigits(ayahs.length)} آية لها متشابهات'),
                    trailing: DropdownButton<int>(
                      value: _surah,
                      underline: const SizedBox.shrink(),
                      menuMaxHeight: 420,
                      items: [
                        for (var s = 1; s <= 114; s++)
                          DropdownMenuItem(value: s, child: Text('${ArabicUtils.toArabicDigits(s)}. ${SurahMetadata.surah(s).name}')),
                      ],
                      onChanged: (v) => setState(() => _surah = v ?? _surah),
                    ),
                  ),
                ),
                const GlassSectionTitle('الآيات', tone: Tone.coral),
                if (ayahs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('لا توجد متشابهات لفظية في هذه السورة', textAlign: TextAlign.center, style: TextStyle(color: glass.onGlassMuted)),
                  ),
                for (final g in ayahs)
                  if (repo.ayahByNumber(g) case final a?)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: NoorCard(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        onTap: () => showSimilarAyahs(context, a),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('الآية ${ArabicUtils.toArabicDigits(a.numberInSurah)}',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: glass.accent)),
                                  Text(a.text,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontFamily: 'UthmanicHafs', fontSize: 19, height: 1.8, color: glass.onGlass)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Tone.coral.mid.withValues(alpha: 0.25),
                              child: Text(ArabicUtils.toArabicDigits(index[g]!.length), style: const TextStyle(fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
    );
  }
}
