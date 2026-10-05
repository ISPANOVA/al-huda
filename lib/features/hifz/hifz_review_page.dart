import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/data/surah_metadata.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_themes.dart';
import '../../core/theme/tones.dart';
import '../../core/utils/arabic_utils.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/noor_ui.dart';
import '../quran/domain/entities/ayah.dart';
import '../quran/domain/repositories/quran_repository.dart';
import '../settings/presentation/cubit/settings_cubit.dart';

const _scoresKey = 'hifz_scores';

/// مراجعة الحفظ — pick a surah, words are hidden, recall them, then grade
/// yourself ayah by ayah. The best score per surah is remembered.
class HifzReviewPage extends StatefulWidget {
  const HifzReviewPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const HifzReviewPage());

  @override
  State<HifzReviewPage> createState() => _HifzReviewPageState();
}

class _HifzReviewPageState extends State<HifzReviewPage> {
  String _query = '';
  int _level = 1; // 0: ربع، 1: نصف، 2: كل الكلمات
  static const _levels = ['سهل', 'متوسط', 'صعب'];

  Map<String, dynamic> _scores() => StorageService.asMap(context.read<StorageService>().settings.get(_scoresKey));

  /// Each level in its own colour, with how much of the ayah it hides.
  static const _levelTones = [Tone.emerald, Tone.amber, Tone.rose];
  static const _levelHints = ['ربع الكلمات', 'نصف الكلمات', 'كل الكلمات'];

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scores = _scores();
    final q = ArabicUtils.normalize(_query);
    final list = [
      for (final s in SurahMetadata.all)
        if (_query.isEmpty || ArabicUtils.normalize(s.name).contains(q) || '${s.number}' == _query) s,
    ];
    final fieldRadius = BorderRadius.circular(18);
    return GlassScaffold(
      title: 'مراجعة الحفظ',
      subtitle: 'اختبر حفظك سورةً سورة',
      icon: Icons.psychology_rounded,
      tone: Tone.coral,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: ToneCard(
              tone: Tone.coral,
              ornament: true,
              radius: 24,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ToneIcon(Icons.visibility_off_rounded, tone: Tone.coral, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('اختر السورة التي تحفظها، وسنخفي بعض كلماتها لتسترجعها من ذاكرتك.',
                            style: TextStyle(color: glass.onGlass, height: 1.6, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (var i = 0; i < _levels.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        _LevelTile(
                          label: _levels[i],
                          hint: _levelHints[i],
                          tone: _levelTones[i],
                          selected: _level == i,
                          onTap: () => setState(() => _level = i),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'ابحث عن سورة',
                filled: true,
                fillColor: noorSurface(context),
                prefixIcon: Icon(Icons.search_rounded, color: Tone.coral.ink(dark)),
                border: OutlineInputBorder(
                  borderRadius: fieldRadius,
                  borderSide: BorderSide(color: Tone.coral.mid.withValues(alpha: 0.35)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: fieldRadius,
                  borderSide: BorderSide(color: Tone.coral.mid.withValues(alpha: 0.35)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: fieldRadius,
                  borderSide: BorderSide(color: Tone.coral.mid, width: 1.6),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final s = list[i];
                final best = (scores['${s.number}'] as num?)?.toInt();
                final scoreTone = best == null
                    ? Tone.coral
                    : best >= 90
                        ? Tone.emerald
                        : best >= 60
                            ? Tone.amber
                            : Tone.coral;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Material(
                    color: noorSurface(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Tone.coral.mid.withValues(alpha: dark ? 0.22 : 0.28)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => _ReviewSession(surah: s.number, level: _level),
                        ));
                        if (mounted) setState(() {});
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                        child: Row(
                          children: [
                            SizedBox.square(
                              dimension: 40,
                              child: CustomPaint(
                                painter: KhatamPainter(Tone.coral.ink(dark).withValues(alpha: 0.75), stroke: 1.2),
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(9),
                                    child: FittedBox(
                                      child: Text(ArabicUtils.toArabicDigits(s.number),
                                          style: TextStyle(color: Tone.coral.ink(dark), fontWeight: FontWeight.w900)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('سورة ${s.name}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: glass.onGlass)),
                                  Text('${ArabicUtils.toArabicDigits(s.ayahCount)} آية',
                                      style: TextStyle(color: glass.onGlassMuted, fontSize: 12)),
                                ],
                              ),
                            ),
                            if (best != null)
                              NoorRing(
                                value: best / 100,
                                color: scoreTone.ink(dark),
                                size: 42,
                                stroke: 3.5,
                                child: Text(ArabicUtils.toArabicDigits(best),
                                    style: TextStyle(
                                        fontSize: 11, fontWeight: FontWeight.w900, color: scoreTone.ink(dark))),
                              )
                            else
                              Icon(Icons.chevron_left_rounded, color: glass.onGlassMuted),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One difficulty level: filled with its colour when chosen.
class _LevelTile extends StatelessWidget {
  final String label;
  final String hint;
  final Tone tone;
  final bool selected;
  final VoidCallback onTap;

  const _LevelTile({
    required this.label,
    required this.hint,
    required this.tone,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: selected ? tone.solid : null,
              color: selected ? null : glass.onGlass.withValues(alpha: dark ? 0.05 : 0.04),
              border: Border.all(
                color: selected ? Colors.white.withValues(alpha: 0.2) : tone.mid.withValues(alpha: dark ? 0.35 : 0.4),
              ),
            ),
            child: Column(
              children: [
                Text(label,
                    maxLines: 1,
                    style: TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 14, color: selected ? Colors.white : tone.ink(dark))),
                Text(hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.5, color: selected ? Colors.white.withValues(alpha: 0.8) : glass.onGlassMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewSession extends StatefulWidget {
  final int surah;
  final int level;

  const _ReviewSession({required this.surah, required this.level});

  @override
  State<_ReviewSession> createState() => _ReviewSessionState();
}

class _ReviewSessionState extends State<_ReviewSession> {
  late final Future<List<Ayah>> _ayahs = context.read<QuranRepository>().getSurah(widget.surah);
  final _rnd = math.Random();
  int _index = 0;
  int _correct = 0;
  int _graded = 0;
  Set<int> _hidden = {};
  final Set<int> _revealed = {};
  bool _finished = false;

  void _prepare(Ayah a) {
    final words = a.text.split(' ').where((w) => w.trim().isNotEmpty).toList();
    final ratio = const [0.25, 0.5, 1.0][widget.level];
    final count = math.max(1, (words.length * ratio).round());
    final idx = List<int>.generate(words.length, (i) => i)..shuffle(_rnd);
    _hidden = idx.take(count).toSet();
    _revealed.clear();
  }

  void _grade(bool ok, int total) {
    HapticFeedback.selectionClick();
    setState(() {
      _graded++;
      if (ok) _correct++;
      if (_index + 1 >= total) {
        _finished = true;
        _saveScore();
      } else {
        _index++;
        _hidden = {};
      }
    });
  }

  void _saveScore() {
    final storage = context.read<StorageService>();
    final scores = StorageService.asMap(storage.settings.get(_scoresKey));
    final score = _graded == 0 ? 0 : (_correct * 100 / _graded).round();
    final prev = (scores['${widget.surah}'] as num?)?.toInt() ?? 0;
    if (score >= prev) {
      scores['${widget.surah}'] = score;
      storage.settings.put(_scoresKey, scores);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final font = context.select((SettingsCubit c) => c.state.quranFont);
    final info = SurahMetadata.surah(widget.surah);
    const tone = Tone.coral;
    return GlassScaffold(
      title: 'مراجعة سورة ${info.name}',
      subtitle: const ['مستوى سهل', 'مستوى متوسط', 'مستوى صعب'][widget.level],
      icon: Icons.psychology_rounded,
      tone: tone,
      body: FutureBuilder<List<Ayah>>(
        future: _ayahs,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final ayahs = snap.data!;
          if (ayahs.isEmpty) return const Center(child: Text('تعذر تحميل السورة'));
          if (_finished) return _result(glass, ayahs.length);
          final a = ayahs[_index];
          if (_hidden.isEmpty) _prepare(a);
          final words = a.text.split(' ').where((w) => w.trim().isNotEmpty).toList();
          final allShown = _hidden.every(_revealed.contains);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Row(
                children: [
                  Flexible(
                    child: _Badge(
                      icon: Icons.format_list_numbered_rounded,
                      text:
                          'الآية ${ArabicUtils.toArabicDigits(a.numberInSurah)} من ${ArabicUtils.toArabicDigits(ayahs.length)}',
                      tone: tone,
                    ),
                  ),
                  const Spacer(),
                  _Badge(icon: Icons.check_rounded, text: ArabicUtils.toArabicDigits(_correct), tone: Tone.emerald),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (_index) / ayahs.length,
                  minHeight: 7,
                  color: tone.ink(dark),
                  backgroundColor: tone.mid.withValues(alpha: 0.14),
                ),
              ),
              const SizedBox(height: 16),
              NoorCard(
                radius: 26,
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < words.length; i++)
                      _hidden.contains(i) && !_revealed.contains(i)
                          ? GestureDetector(
                              onTap: () => setState(() => _revealed.add(i)),
                              child: Container(
                                width: 18.0 + words[i].length * 7,
                                height: 40,
                                margin: const EdgeInsets.only(top: 6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: tone.wash(dark),
                                  border: Border.all(color: tone.mid.withValues(alpha: 0.6)),
                                ),
                                child: Icon(Icons.visibility_rounded, size: 16, color: tone.ink(dark)),
                              ),
                            )
                          : Text(
                              words[i],
                              style: font.style(
                                fontSize: 24,
                                height: 1.9,
                                color: _hidden.contains(i) ? tone.ink(dark) : glass.onGlass,
                              ),
                            ),
                    Text(ArabicUtils.ornateAyahMarker(a.numberInSurah),
                        style: font.style(fontSize: 24, height: 1.9, color: glass.accent)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(allShown ? Icons.help_outline_rounded : Icons.touch_app_rounded,
                      size: 18, color: tone.ink(dark)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      allShown ? 'هل كان استرجاعك صحيحًا؟' : 'استرجع الكلمات المخفية في ذهنك، ثم اضغط عليها للتحقق.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: allShown ? glass.onGlass : glass.onGlassMuted,
                          fontWeight: allShown ? FontWeight.w800 : FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (!allShown)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tone.ink(dark),
                    side: BorderSide(color: tone.mid.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => setState(() => _revealed.addAll(_hidden)),
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text('إظهار كل الكلمات'),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => _grade(true, ayahs.length),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('حفظتها'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: tone.ink(dark),
                          side: BorderSide(color: tone.mid.withValues(alpha: 0.6)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => _grade(false, ayahs.length),
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('تحتاج مراجعة'),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _result(GlassTheme glass, int total) {
    final score = _graded == 0 ? 0 : (_correct * 100 / _graded).round();
    final msg = score >= 90
        ? 'ما شاء الله! حفظ متقن، زادك الله.'
        : score >= 60
            ? 'أحسنت، راجع الآيات التي تعثرت فيها.'
            : 'تحتاج السورة إلى مراجعة، والتكرار مفتاح الإتقان.';
    final tone = score >= 90
        ? Tone.emerald
        : score >= 60
            ? Tone.amber
            : Tone.coral;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ToneCard(
          tone: tone,
          solid: true,
          ornament: true,
          radius: 28,
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NoorRing(
                value: score / 100,
                color: Colors.white,
                track: Colors.white.withValues(alpha: 0.2),
                size: 150,
                stroke: 10,
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: FittedBox(
                    child: Text('${ArabicUtils.toArabicDigits(score)}٪',
                        style: const TextStyle(
                            fontFamily: AppFonts.display,
                            fontSize: 38,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, height: 1.5, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withValues(alpha: 0.16),
                ),
                child: Text('${ArabicUtils.toArabicDigits(_correct)} من ${ArabicUtils.toArabicDigits(total)} آية',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () => setState(() {
                  _index = 0;
                  _correct = 0;
                  _graded = 0;
                  _hidden = {};
                  _finished = false;
                }),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('مراجعة مرة أخرى'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small rounded label with an icon, in a tone.
class _Badge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Tone tone;

  const _Badge({required this.icon, required this.text, required this.tone});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: tone.mid.withValues(alpha: dark ? 0.16 : 0.12),
        border: Border.all(color: tone.mid.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: tone.ink(dark)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: tone.ink(dark))),
          ),
        ],
      ),
    );
  }
}
