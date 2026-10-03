import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/data/surah_metadata.dart';
import '../../core/theme/app_themes.dart';
import '../../core/utils/arabic_utils.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/noor_ui.dart';
import '../../core/widgets/state_views.dart';
import '../audio/presentation/cubit/audio_cubit.dart';
import '../quran/domain/repositories/quran_repository.dart';
import '../quran/presentation/mushaf/mushaf_page.dart' show kBasmala;
import 'tasmee_engine.dart';

/// التسميع: the page's words are hidden; recite from memory and each word
/// appears as you say it. A wrong word stays hidden with a red line and a
/// warning tone. Pages turn by themselves until you stop.
class TasmeePage extends StatefulWidget {
  final int startPage;

  /// Optional global ayah number to start from (earlier ayahs are shown).
  final int? startAyah;

  const TasmeePage({super.key, required this.startPage, this.startAyah});

  static Route<void> route({required int page, int? ayah}) =>
      MaterialPageRoute(builder: (_) => TasmeePage(startPage: page, startAyah: ayah));

  @override
  State<TasmeePage> createState() => _TasmeePageState();
}

class _TasmeePageState extends State<TasmeePage> {
  final SpeechToText _stt = SpeechToText();
  // No audio-session activation: a beep must not steal focus from the mic.
  final AudioPlayer _fx = AudioPlayer(handleAudioSessionActivation: false);
  Timer? _watchdog;
  bool _starting = false;
  String _heard = '';
  double _level = 0;
  final List<TasmeeMistake> _mistakes = [];
  late int _page = widget.startPage;
  TasmeeSession? _session;
  bool _ready = false;
  bool _active = false; // user wants to listen
  bool _listening = false;
  bool _peek = false;
  String _status = 'اضغط على الميكروفون وابدأ التلاوة من حفظك';
  String? _localeId;
  int _flashIndex = -1;
  Timer? _flashTimer;

  /// Last partial result of the current utterance. Android often closes an
  /// utterance after a pause without a final result, so the last word said
  /// before the pause is judged when speech settles (or the utterance ends).
  List<String> _pendingWords = const [];

  /// Keeps the word being recited in view, so the reciter never scrolls.
  final _scroll = ScrollController();
  int _loadSeq = 0;
  final _wordKeys = <int, GlobalKey>{};
  GlobalKey get _currentKey => _wordKeys.putIfAbsent(_loadSeq, () => GlobalKey());
  int _heardCount = 0;
  Timer? _settleTimer;
  /// Correct words on finished pages, and words shown before the start ayah
  /// on the current page (not recited, so not counted).
  int _prevCorrect = 0;
  int _preRevealed = 0;
  int get _revealedTotal => _prevCorrect + (_session?.correctCount(_preRevealed) ?? 0);
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    final audio = context.read<AudioCubit>();
    if (audio.state.playing) audio.togglePlay();
    _loadPage(_page, startAyah: widget.startAyah);
  }

  @override
  void dispose() {
    _active = false;
    _watchdog?.cancel();
    _flashTimer?.cancel();
    _settleTimer?.cancel();
    _stt.cancel();
    _scroll.dispose();
    _fx.dispose();
    super.dispose();
  }

  /// [consumed]: words of the current utterance already used. Null when the
  /// reciter changes page by hand: everything heard so far belongs to the old
  /// page.
  Future<void> _loadPage(int page, {int? startAyah, int? consumed}) async {
    if (consumed == null) {
      _settleTimer?.cancel();
      _pendingWords = const [];
    }
    consumed ??= _heardCount;
    final repo = context.read<QuranRepository>();
    await repo.ensureLoaded();
    final ayahs = repo.ayahsOnPage(page);
    final words = <TasmeeWord>[];
    for (final a in ayahs) {
      final parts = a.text.split(' ').where((w) => w.trim().isNotEmpty).toList();
      for (var i = 0; i < parts.length; i++) {
        words.add(TasmeeWord(surah: a.surah, ayah: a.numberInSurah, text: parts[i], endsAyah: i == parts.length - 1));
      }
    }
    final old = _session;
    if (old != null) _prevCorrect += old.correctCount(_preRevealed);
    var pre = 0;
    final session = TasmeeSession(words, _mistakes, consumed: consumed, heard: old?.lastHeard ?? const []);
    if (startAyah != null) {
      final first = ayahs.indexWhere((a) => a.number == startAyah);
      if (first > 0) {
        final ref = ayahs[first];
        for (final w in words) {
          if (w.surah == ref.surah && w.ayah == ref.numberInSurah) break;
          w.state = TasmeeState.correct;
          session.expected++;
          pre++;
        }
        session.startFrom(session.expected);
      }
    }
    if (!mounted) return;
    setState(() {
      _page = page;
      _session = session;
      _preRevealed = pre;
      _loadSeq++;
    });
    // A new page always starts from its top.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(0);
      _follow();
    });
  }

  /// Scrolls so the next word to recite stays in the upper part of the view.
  void _follow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final box = _currentKey.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) return;
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport == null) return;
      final top = viewport.getOffsetToReveal(box, 0).offset; // word at the top
      final view = _scroll.position.viewportDimension;
      final y = top - _scroll.offset; // word position inside the view
      if (y >= 0 && y <= view * 0.55) return;
      final target = (top - view * 0.28).clamp(0.0, _scroll.position.maxScrollExtent);
      if ((target - _scroll.offset).abs() < 4) return;
      _scroll.animateTo(target, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    });
  }

  // ------------------------------------------------------------ speech ---

  Future<bool> _init() async {
    if (_ready) return true;
    _ready = await _stt.initialize(onStatus: _onStatus, onError: _onError);
    if (!_ready) return false;
    try {
      final locales = await _stt.locales();
      final ar = locales.where((l) => l.localeId.toLowerCase().startsWith('ar')).toList();
      String? pick(String id) => ar.where((l) => l.localeId.replaceAll('-', '_') == id).firstOrNull?.localeId;
      _localeId = pick('ar_SA') ?? pick('ar_EG') ?? (ar.isNotEmpty ? ar.first.localeId : 'ar_SA');
    } catch (_) {
      _localeId = 'ar_SA';
    }
    return true;
  }

  Future<void> _toggleMic() async {
    if (_active) {
      _active = false;
      _watchdog?.cancel();
      await _stt.stop();
      setState(() {
        _listening = false;
        _level = 0;
        _status = 'متوقف مؤقتًا • اضغط للمتابعة';
      });
      return;
    }
    if (!await _init()) {
      if (mounted) {
        setState(() => _status = 'تعذر تشغيل التعرف على الصوت. اسمح للتطبيق باستخدام الميكروفون، '
            'وتأكد من وجود خدمة Google للتعرف على الكلام.');
      }
      return;
    }
    _active = true;
    // Android closes each utterance after a pause; keep the mic open while active.
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (_active && !_starting && !_stt.isListening) _listen();
    });
    await _listen();
  }

  Future<void> _listen() async {
    if (!_active || !mounted || _starting) return;
    _starting = true;
    _settle();
    _session?.newUtterance();
    _heardCount = 0;
    try {
      await _stt.listen(
        onResult: _onResult,
        onSoundLevelChange: (l) {
          if (mounted) setState(() => _level = ((l + 2) / 12).clamp(0.0, 1.0));
        },
        localeId: _localeId,
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 30),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
      if (mounted) {
        setState(() {
          _listening = true;
          _status = 'أستمع إليك… اقرأ من حفظك';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _status = 'جارٍ إعادة الاتصال بالميكروفون…');
    } finally {
      _starting = false;
    }
  }

  void _onStatus(String status) {
    if (!mounted) return;
    if (status == 'done' || status == 'notListening') {
      _settle();
      setState(() {
        _listening = false;
        _level = 0;
      });
      if (_active) Future.delayed(const Duration(milliseconds: 40), _listen);
    } else if (status == 'listening') {
      setState(() => _listening = true);
    }
  }

  void _onError(SpeechRecognitionError e) {
    if (!mounted) return;
    if (e.errorMsg.contains('permission')) {
      _active = false;
      _watchdog?.cancel();
      setState(() => _status = 'يحتاج التسميع إذن الميكروفون من إعدادات التطبيق');
    }
    // Other errors (silence, no match, busy) are recovered by the watchdog.
  }

  void _onResult(SpeechRecognitionResult r) {
    if (_session == null || !mounted) return;
    _heard = r.recognizedWords;
    final heard = r.recognizedWords.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    _heardCount = heard.length;
    _settleTimer?.cancel();
    if (r.finalResult) {
      _pendingWords = const [];
    } else {
      _pendingWords = heard;
      _settleTimer = Timer(const Duration(milliseconds: 1800), _settle);
    }
    final alternates = [
      for (final a in r.alternates.skip(1))
        a.recognizedWords.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList(),
    ];
    _apply(heard, isFinal: r.finalResult, alternates: alternates);
  }

  /// Judges the last word heard once the reciter paused after it.
  void _settle() {
    _settleTimer?.cancel();
    final words = _pendingWords;
    _pendingWords = const [];
    if (words.isEmpty || _session == null || !mounted) return;
    _apply(words, isFinal: true);
  }

  void _apply(
    List<String> heard, {
    required bool isFinal,
    List<List<String>> alternates = const [],
  }) {
    final s = _session;
    if (s == null || !mounted) return;
    final wasDone = s.done;
    final res = s.feed(heard, isFinal: isFinal, alternates: alternates);
    if (res.mistakes > 0) _onMistake(res.flash);
    setState(() {});
    _follow();
    if (s.done && !wasDone) _pageDone(s);
  }

  Future<void> _onMistake(int idx) async {
    HapticFeedback.heavyImpact();
    _flashTimer?.cancel();
    setState(() => _flashIndex = idx);
    _flashTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _flashIndex = -1);
    });
    try {
      await _fx.setAsset('assets/sounds/tasmee_error.wav');
      await _fx.play();
    } catch (_) {}
  }

  /// Next page right away, continuing the same utterance: words already
  /// heard for this page are not fed to the next one.
  Future<void> _pageDone(TasmeeSession finished) async {
    HapticFeedback.mediumImpact();
    if (_page >= 604) {
      _active = false;
      _watchdog?.cancel();
      await _stt.stop();
      if (mounted) _showSummary(finished: true);
      return;
    }
    if (!mounted) return;
    await _loadPage(_page + 1, consumed: finished.consumed);
  }

  // -------------------------------------------------------- navigation ---

  /// Direction of the last page change (for the slide animation).
  bool _forward = true;

  void _goTo(int page, {int? startAyah}) {
    if (page < 1 || page > 604) return;
    HapticFeedback.selectionClick();
    _forward = page >= _page;
    _loadPage(page, startAyah: startAyah);
  }

  Future<void> _openSearch() async {
    final target = await showModalBottomSheet<({int surah, int ayah})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _GoToSheet(),
    );
    if (target == null || !mounted) return;
    final repo = context.read<QuranRepository>();
    final page = repo.pageOf(target.surah, target.ayah);
    _goTo(page, startAyah: SurahMetadata.globalAyah(target.surah, target.ayah));
  }

  // ------------------------------------------------------------- hints ---

  void _hintWord() {
    _session?.hintNext();
    HapticFeedback.selectionClick();
    setState(() {});
    _follow();
    if (_session?.done ?? false) _pageDone(_session!);
  }

  void _hintAyah() {
    _session?.revealAyah();
    HapticFeedback.selectionClick();
    setState(() {});
    _follow();
    if (_session?.done ?? false) _pageDone(_session!);
  }

  Future<void> _showSummary({bool finished = false}) {
    final glass = GlassTheme.of(context);
    return showGlassSheet<void>(context, builder: (ctx) {
      return SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(finished ? 'أتممت التسميع، بارك الله فيك' : 'نتيجة التسميع',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _stat(glass, '${ArabicUtils.toArabicDigits(_revealedTotal)}', 'كلمة صحيحة'),
                const SizedBox(width: 12),
                _stat(glass, '${ArabicUtils.toArabicDigits(_mistakes.length)}', 'خطأ', error: true),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _mistakes.isEmpty
                  ? Center(child: Text('لا أخطاء، ما شاء الله 🌿', style: TextStyle(color: glass.onGlassMuted)))
                  : ListView.separated(
                      itemCount: _mistakes.length,
                      separatorBuilder: (_, _) => Divider(height: 1, color: glass.onGlass.withValues(alpha: 0.08)),
                      itemBuilder: (_, i) {
                        final m = _mistakes[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.close_rounded, color: Color(0xFFE5484D)),
                          title: Text(m.word, style: QuranFont.amiriQuran.style(fontSize: 20, height: 1.6, color: glass.onGlass)),
                          subtitle: Text(
                            'سورة ${SurahMetadata.surah(m.surah).name} • الآية ${ArabicUtils.toArabicDigits(m.ayah)}'
                            '${m.heard.isEmpty ? ' • كلمة متروكة' : ' • قلت: ${m.heard}'}',
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    });
  }

  Widget _stat(GlassTheme glass, String value, String label, {bool error = false}) {
    final c = error ? const Color(0xFFE5484D) : glass.accent;
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: c.withValues(alpha: 0.12),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: c)),
          Text(label, style: TextStyle(color: glass.onGlassMuted)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- UI ---

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final s = _session;
    return PopScope(
      canPop: _leaving || (_mistakes.isEmpty && _revealedTotal == 0),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _active = false;
        _stt.stop();
        _showSummaryThenLeave();
      },
      child: GlassScaffold(
        title: 'التسميع',
        actions: [
          IconButton(
            tooltip: 'انتقل إلى سورة أو آية',
            icon: const Icon(Icons.search_rounded),
            onPressed: _openSearch,
          ),
          IconButton(
            tooltip: _peek ? 'إخفاء النص' : 'إظهار النص للمراجعة',
            icon: Icon(_peek ? Icons.visibility_off_rounded : Icons.visibility_rounded),
            onPressed: () => setState(() => _peek = !_peek),
          ),
          IconButton(
            tooltip: 'النتيجة',
            icon: Badge(
              isLabelVisible: _mistakes.isNotEmpty,
              label: Text(ArabicUtils.toArabicDigits(_mistakes.length)),
              child: const Icon(Icons.fact_check_rounded),
            ),
            onPressed: () => _showSummary(),
          ),
        ],
        body: s == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _topBar(glass, s),
                  Expanded(
                    child: GestureDetector(
                      // Swipe to turn pages like a mushaf: right = next.
                      onHorizontalDragEnd: (d) {
                        final v = d.primaryVelocity ?? 0;
                        if (v > 350) _goTo(_page + 1);
                        if (v < -350) _goTo(_page - 1);
                      },
                      child: SingleChildScrollView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 380),
                        switchInCurve: Curves.easeOutCubic,
                        transitionBuilder: (child, a) => SlideTransition(
                          position: Tween(begin: Offset(_forward ? 0.2 : -0.2, 0), end: Offset.zero).animate(a),
                          child: FadeTransition(opacity: a, child: child),
                        ),
                        child: NoorCard(
                          key: ValueKey(_page),
                          padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
                          child: _pageText(glass, s),
                        ),
                      ),
                    ),
                    ),
                  ),
                  _controls(glass, s),
                ],
              ),
      ),
    );
  }

  Future<void> _showSummaryThenLeave() async {
    await _showSummary();
    if (!mounted) return;
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Widget _topBar(GlassTheme glass, TasmeeSession s) {
    final first = s.words.isEmpty ? null : s.words.first;
    final progress = s.words.isEmpty ? 0.0 : s.expected / s.words.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                first == null ? '' : 'سورة ${SurahMetadata.surah(first.surah).name}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const Spacer(),
              Text('صفحة ${ArabicUtils.toArabicDigits(_page)}',
                  style: TextStyle(color: glass.onGlassMuted, fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: (_mistakes.isEmpty ? glass.accent : const Color(0xFFE5484D)).withValues(alpha: 0.15),
                ),
                child: Text(
                  'الأخطاء ${ArabicUtils.toArabicDigits(_mistakes.length)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: _mistakes.isEmpty ? glass.accent : const Color(0xFFE5484D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              color: glass.accent,
              backgroundColor: glass.onGlass.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageText(GlassTheme glass, TasmeeSession s) {
    final base = QuranFont.amiriQuran.style(fontSize: 23, height: 2.0, color: glass.onGlass);
    final children = <Widget>[];
    var line = <Widget>[];
    void flush() {
      if (line.isEmpty) return;
      children.add(Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: 7,
        runSpacing: 2,
        children: line,
      ));
      line = <Widget>[];
    }

    for (var i = 0; i < s.words.length; i++) {
      final w = s.words[i];
      final startsSurah = w.ayah == 1 && (i == 0 || s.words[i - 1].ayah != 1 || s.words[i - 1].surah != w.surah);
      if (startsSurah && (i == 0 || s.words[i - 1].endsAyah)) {
        flush();
        children.add(_surahBanner(glass, w.surah));
      }
      final word = _word(glass, base, w, i == s.expected && _active, i == _flashIndex);
      line.add(i == s.expected ? KeyedSubtree(key: _currentKey, child: word) : word);
      if (w.endsAyah) {
        line.add(Text(ArabicUtils.ornateAyahMarker(w.ayah), style: base.copyWith(color: glass.accent)));
      }
    }
    flush();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget _surahBanner(GlassTheme glass, int surah) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: glass.accent.withValues(alpha: 0.12),
              border: Border.all(color: glass.accent.withValues(alpha: 0.4)),
            ),
            alignment: Alignment.center,
            child: Text('سورة ${SurahMetadata.surah(surah).name}',
                style: QuranFont.amiriQuran.style(fontSize: 22, height: 1.6, color: glass.accent)),
          ),
          if (surah != 1 && surah != 9)
            Text(kBasmala,
                textAlign: TextAlign.center,
                style: QuranFont.amiriQuran.style(fontSize: 21, height: 2, color: glass.onGlass)),
        ],
      ),
    );
  }

  Widget _word(GlassTheme glass, TextStyle base, TasmeeWord w, bool current, bool flash) {
    const red = Color(0xFFE5484D);
    final hidden = !w.revealed;
    Color color;
    if (!hidden) {
      color = w.missed ? red : (w.state == TasmeeState.hinted ? glass.accent : glass.onGlass);
    } else {
      color = _peek ? glass.onGlass.withValues(alpha: 0.28) : Colors.transparent;
    }
    final mistake = w.state == TasmeeState.mistake;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: flash
            ? red.withValues(alpha: 0.18)
            : current
                ? glass.accent.withValues(alpha: 0.10)
                : null,
        borderRadius: BorderRadius.circular(6),
        border: Border(
          bottom: BorderSide(
            color: mistake || flash
                ? red
                : hidden
                    ? (current ? glass.accent : glass.onGlass.withValues(alpha: 0.22))
                    : Colors.transparent,
            width: mistake || flash || current ? 2.4 : 1.2,
          ),
        ),
      ),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 260),
        style: base.copyWith(color: color),
        child: Text(w.text),
      ),
    );
  }

  /// Icon above a one-line label: same size whatever the text or screen width.
  Widget _hintButton(GlassTheme glass, IconData icon, String label, VoidCallback? onTap) {
    final color = onTap == null ? glass.onGlassMuted.withValues(alpha: 0.5) : glass.accent;
    return SizedBox(
      height: 64,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls(GlassTheme glass, TasmeeSession s) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: noorSurface(context),
        border: Border(top: BorderSide(color: glass.accent.withValues(alpha: 0.18))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 38,
            child: Center(
              child: Text(_status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: glass.onGlassMuted, fontSize: 12.5, height: 1.5)),
            ),
          ),
          // Fixed height so the page above never jumps while speaking.
          SizedBox(
            height: 24,
            child: Center(
              child: Text(
                _active && _heard.isNotEmpty
                    ? '«${_heard.split(' ').reversed.take(7).toList().reversed.join(' ')}»'
                    : '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: glass.accent.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _hintButton(glass, Icons.lightbulb_outline_rounded, 'الكلمة التالية', s.done ? null : _hintWord),
              ),
              const SizedBox(width: 12),
              // The mic keeps a fixed footprint; the sound level only scales
              // its painting, so the buttons beside it never move.
              SizedBox(
                width: 88,
                height: 88,
                child: Center(
                  child: GestureDetector(
                    onTap: _toggleMic,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 120),
                      scale: 1 + (_active ? _level * 0.12 : 0),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _active ? const Color(0xFFE5484D) : glass.accent,
                          boxShadow: [
                            BoxShadow(
                              color: (_active ? const Color(0xFFE5484D) : glass.accent)
                                  .withValues(alpha: _listening ? 0.6 : 0.3),
                              blurRadius: _listening ? 18 + _level * 22 : 12,
                            ),
                          ],
                        ),
                        child: Icon(_active ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.black, size: 36),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _hintButton(glass, Icons.subject_rounded, 'باقي الآية', s.done ? null : _hintAyah),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('اسحب يمينًا أو يسارًا لتقليب الصفحات',
              style: TextStyle(fontSize: 11, color: glass.onGlassMuted.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

/// Pick a surah (search by name or number) and optionally an ayah.
class _GoToSheet extends StatefulWidget {
  const _GoToSheet();

  @override
  State<_GoToSheet> createState() => _GoToSheetState();
}

class _GoToSheetState extends State<_GoToSheet> {
  String _q = '';
  SurahInfo? _surah;
  final _ayah = TextEditingController();

  @override
  void dispose() {
    _ayah.dispose();
    super.dispose();
  }

  static String _norm(String s) => s
      .replaceAll(RegExp('[ً-ْٰـ]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'^(سوره|سورة)\s*'), '')
      .trim();

  int? _num(String s) {
    const ar = '٠١٢٣٤٥٦٧٨٩';
    final western = s.split('').map((c) => ar.contains(c) ? ar.indexOf(c).toString() : c).join();
    return int.tryParse(western.trim());
  }

  void _go() {
    final s = _surah;
    if (s == null) return;
    final a = (_num(_ayah.text) ?? 1).clamp(1, s.ayahCount);
    Navigator.of(context).pop((surah: s.number, ayah: a));
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final q = _norm(_q);
    final n = _num(_q);
    final list = SurahMetadata.all
        .where((s) => q.isEmpty || _norm(s.name).contains(q) || (n != null && s.number == n))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: noorSurface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(color: glass.accent.withValues(alpha: 0.25)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: glass.onGlass.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(_surah == null ? 'انتقل إلى سورة' : 'سورة ${_surah!.name}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 12),
            if (_surah == null) ...[
              TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: 'اسم السورة أو رقمها',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: glass.onGlass.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final s = list[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                      leading: CircleAvatar(
                        radius: 17,
                        backgroundColor: glass.accent.withValues(alpha: 0.14),
                        child: Text(ArabicUtils.toArabicDigits(s.number),
                            style: TextStyle(color: glass.accent, fontWeight: FontWeight.w800, fontSize: 13)),
                      ),
                      title: Text('سورة ${s.name}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${s.revelationAr} • ${ArabicUtils.toArabicDigits(s.ayahCount)} آية',
                          style: TextStyle(color: glass.onGlassMuted, fontSize: 12)),
                      trailing: TextButton(
                        onPressed: () => Navigator.of(context).pop((surah: s.number, ayah: 1)),
                        child: const Text('من أولها'),
                      ),
                      onTap: () => setState(() => _surah = s),
                    );
                  },
                ),
              ),
            ] else ...[
              TextField(
                controller: _ayah,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                onSubmitted: (_) => _go(),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                decoration: InputDecoration(
                  hintText: 'رقم الآية (١ – ${ArabicUtils.toArabicDigits(_surah!.ayahCount)})',
                  filled: true,
                  fillColor: glass.onGlass.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _surah = null),
                      child: const Text('رجوع'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _go,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('ابدأ التسميع من هنا'),
                    ),
                  ),
                ],
              ),
              const Spacer(),
            ],
          ],
        ),
      ),
    );
  }
}
