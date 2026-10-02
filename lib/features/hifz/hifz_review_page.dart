import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/data/surah_metadata.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_themes.dart';
import '../../core/utils/arabic_utils.dart';
import '../../core/widgets/glass_container.dart';
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

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final scores = _scores();
    final q = ArabicUtils.normalize(_query);
    final list = [
      for (final s in SurahMetadata.all)
        if (_query.isEmpty || ArabicUtils.normalize(s.name).contains(q) || '${s.number}' == _query) s,
    ];
    return GlassScaffold(
      title: 'مراجعة الحفظ',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: GlassContainer(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('اختر السورة التي تحفظها، وسنخفي بعض كلماتها لتسترجعها من ذاكرتك.',
                      style: TextStyle(color: glass.onGlassMuted, height: 1.6, fontSize: 13)),
                  const SizedBox(height: 10),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [
                      for (var i = 0; i < _levels.length; i++) ButtonSegment(value: i, label: Text(_levels[i])),
                    ],
                    selected: {_level},
                    onSelectionChanged: (v) => setState(() => _level = v.first),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'ابحث عن سورة',
                prefixIcon: Icon(Icons.search_rounded),
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
                return GlassContainer(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => _ReviewSession(surah: s.number, level: _level),
                    ));
                    if (mounted) setState(() {});
                  },
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(ArabicUtils.toArabicDigits(s.number),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: glass.accent, fontWeight: FontWeight.w900)),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('سورة ${s.name}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            Text('${ArabicUtils.toArabicDigits(s.ayahCount)} آية',
                                style: TextStyle(color: glass.onGlassMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                      if (best != null)
                        NoorRing(
                          value: best / 100,
                          color: glass.accent,
                          size: 40,
                          stroke: 3.5,
                          child: Text(ArabicUtils.toArabicDigits(best),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                        )
                      else
                        Icon(Icons.chevron_left_rounded, color: glass.onGlassMuted),
                    ],
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
    final font = context.select((SettingsCubit c) => c.state.quranFont);
    final info = SurahMetadata.surah(widget.surah);
    return GlassScaffold(
      title: 'مراجعة سورة ${info.name}',
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
                  Text('الآية ${ArabicUtils.toArabicDigits(a.numberInSurah)} من ${ArabicUtils.toArabicDigits(ayahs.length)}',
                      style: TextStyle(color: glass.onGlassMuted, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('✓ ${ArabicUtils.toArabicDigits(_correct)}',
                      style: TextStyle(color: glass.accent, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (_index) / ayahs.length,
                  minHeight: 6,
                  color: glass.accent,
                  backgroundColor: glass.onGlass.withValues(alpha: 0.08),
                ),
              ),
              const SizedBox(height: 16),
              GlassContainer(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
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
                                  borderRadius: BorderRadius.circular(10),
                                  color: glass.accent.withValues(alpha: 0.16),
                                  border: Border.all(color: glass.accent.withValues(alpha: 0.5)),
                                ),
                                child: Icon(Icons.visibility_rounded, size: 16, color: glass.accent),
                              ),
                            )
                          : Text(
                              words[i],
                              style: font.style(
                                fontSize: 24,
                                height: 1.9,
                                color: _hidden.contains(i) ? glass.accent : glass.onGlass,
                              ),
                            ),
                    Text(ArabicUtils.ornateAyahMarker(a.numberInSurah),
                        style: font.style(fontSize: 24, height: 1.9, color: glass.accent)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                allShown ? 'هل كان استرجاعك صحيحًا؟' : 'استرجع الكلمات المخفية في ذهنك، ثم اضغط عليها للتحقق.',
                textAlign: TextAlign.center,
                style: TextStyle(color: glass.onGlassMuted),
              ),
              const SizedBox(height: 14),
              if (!allShown)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _revealed.addAll(_hidden)),
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text('إظهار كل الكلمات'),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _grade(true, ayahs.length),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('حفظتها'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NoorRing(
              value: score / 100,
              color: glass.accent,
              size: 150,
              stroke: 10,
              child: Text('${ArabicUtils.toArabicDigits(score)}٪',
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 18),
            Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('${ArabicUtils.toArabicDigits(_correct)} من ${ArabicUtils.toArabicDigits(total)} آية',
                style: TextStyle(color: glass.onGlassMuted)),
            const SizedBox(height: 20),
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
    );
  }
}
