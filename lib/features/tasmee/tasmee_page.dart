import 'dart:async';

import 'package:flutter/material.dart';
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
import '../quran/domain/entities/mushaf_line.dart';
import '../quran/presentation/mushaf/mushaf_page.dart' show MushafPageView, MushafStyle, MushafWordPaint;
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

  /// Errors before any word was heard: a phone or emulator without a working
  /// speech service only ever reports errors.
  int _earlyErrors = 0;
  bool _gotResult = false;
  bool _noArabic = false;
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
  /// Pages are swiped like the Mushaf; [_turning] marks a page change made
  /// by the app (auto-advance, search) so it isn't taken for a manual swipe.
  late final PageController _pages = PageController(initialPage: widget.startPage - 1);
  int? _turning;

  /// Changes whenever the drawing of the current page must refresh.
  int _revision = 0;
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
    _pages.dispose();
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
    // The words exactly as the Mushaf page draws them (same order).
    final words = <TasmeeWord>[];
    final globals = <int>[];
    for (final line in repo.linesOnPage(page)) {
      if (line.type != MushafLineType.text && line.type != MushafLineType.centered) continue;
      for (final w in line.words) {
        if (w.ayah == 0) continue;
        final ref = SurahMetadata.fromGlobal(w.ayah);
        final number = _ayahNumber.firstMatch(w.text);
        words.add(TasmeeWord(
          surah: ref.surah,
          ayah: ref.ayah,
          text: number == null ? w.text : w.text.substring(0, number.start),
          endsAyah: number != null,
        ));
        globals.add(w.ayah);
      }
    }
    final old = _session;
    if (old != null) _prevCorrect += old.correctCount(_preRevealed);
    var pre = 0;
    final session = TasmeeSession(words, _mistakes, consumed: consumed, heard: old?.lastHeard ?? const []);
    if (startAyah != null) {
      final first = globals.indexOf(startAyah);
      if (first > 0) {
        for (var i = 0; i < first; i++) {
          words[i].state = TasmeeState.correct;
        }
        pre = first;
        session.expected = first;
        session.startFrom(first);
      }
    }
    if (!mounted) return;
    setState(() {
      _page = page;
      _session = session;
      _preRevealed = pre;
      _revision++;
    });
  }

  static final _ayahNumber = RegExp('[\\s\u00A0]+[٠-٩]+\$');

  /// Turns the Mushaf to [page] (as the app, not a swipe).
  void _showPage(int page, {bool animate = true}) {
    if (!_pages.hasClients) return;
    final target = page - 1;
    if ((_pages.page ?? target).round() == target) return;
    _turning = target;
    if (animate && ((_pages.page ?? 0) - target).abs() <= 1.5) {
      _pages.animateToPage(target, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    } else {
      _pages.jumpToPage(target);
    }
  }

  void _onSwiped(int index) {
    if (_turning != null) {
      if (index == _turning) _turning = null;
      return;
    }
    if (index + 1 != _page) _loadPage(index + 1);
  }

  // ------------------------------------------------------------ speech ---

  Future<bool> _init() async {
    if (_ready) return true;
    try {
      _ready = await _stt
          .initialize(onStatus: _onStatus, onError: _onError)
          .timeout(const Duration(seconds: 8), onTimeout: () => false);
    } catch (_) {
      _ready = false;
    }
    if (!_ready) return false;
    try {
      final locales = await _stt.locales();
      final ar = locales.where((l) => l.localeId.toLowerCase().startsWith('ar')).toList();
      _noArabic = locales.isNotEmpty && ar.isEmpty;
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
        setState(() => _status = 'تعذر تشغيل التعرف على الصوت على هذا الجهاز');
        _showSpeechHelp();
      }
      return;
    }
    if (_noArabic && mounted) _showSpeechHelp(noArabic: true);
    _active = true;
    _earlyErrors = 0;
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
      _showSpeechHelp();
      return;
    }
    // Other errors (silence, no match, busy) are recovered by the watchdog,
    // unless nothing was ever heard: then the device can't recognise speech.
    if (!_gotResult && e.errorMsg != 'error_no_match' && e.errorMsg != 'error_speech_timeout') {
      _earlyErrors++;
      if (_earlyErrors >= 4 && _active) {
        _active = false;
        _watchdog?.cancel();
        _stt.stop();
        setState(() {
          _listening = false;
          _status = 'خدمة التعرف على الكلام لا تعمل على هذا الجهاز';
        });
        _showSpeechHelp(error: e.errorMsg);
      }
    }
  }

  /// Why the microphone can't work here and how to fix it (phones without
  /// Google's speech service, emulators such as LDPlayer).
  void _showSpeechHelp({bool noArabic = false, String? error}) {
    final glass = GlassTheme.of(context);
    Widget step(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: glass.accent, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: TextStyle(height: 1.6, color: glass.onGlass))),
            ],
          ),
        );
    showGlassSheet<void>(context, builder: (ctx) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(noArabic ? 'العربية غير مثبتة في التعرف على الكلام' : 'الميكروفون لا يعمل للتسميع',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            'التسميع يعتمد على خدمة «التعرف على الكلام» من Google الموجودة في الهاتف. '
            'غالبًا تكون غير موجودة أو متوقفة، خصوصًا في المحاكيات مثل LDPlayer.',
            style: TextStyle(color: glass.onGlassMuted, height: 1.6),
          ),
          const SizedBox(height: 16),
          step(Icons.shop_rounded, 'ثبّت أو حدّث تطبيق «Google» و«خدمات الكلام من Google» من متجر Play.'),
          step(Icons.translate_rounded,
              'أضف العربية: تطبيق Google ← الإعدادات ← الصوت ← لغات التعرف على الصوت ← العربية.'),
          step(Icons.mic_rounded, 'اسمح للتطبيق باستخدام الميكروفون من إعدادات الهاتف ← التطبيقات ← الهدى ← الأذونات.'),
          step(Icons.computer_rounded,
              'على المحاكي (LDPlayer وغيره): فعّل الميكروفون من إعدادات المحاكي، وتأكد أن ويندوز يسمح له باستخدام الميكروفون.'),
          if (error != null)
            Text('رمز الخطأ: $error', style: TextStyle(fontSize: 11, color: glass.onGlassMuted)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('حسنًا')),
          ),
        ],
      );
    });
  }

  void _onResult(SpeechRecognitionResult r) {
    if (_session == null || !mounted) return;
    if (r.recognizedWords.trim().isNotEmpty) _gotResult = true;
    _heard = r.recognizedWords;
    final heard = r.recognizedWords.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    _heardCount = heard.length;
    _settleTimer?.cancel();
    if (r.finalResult) {
      _pendingWords = const [];
    } else {
      _pendingWords = heard;
      _settleTimer = Timer(const Duration(milliseconds: 1000), _settle);
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
    setState(() => _revision++);
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
    final next = _page + 1;
    await _loadPage(next, consumed: finished.consumed);
    _showPage(next);
  }

  // -------------------------------------------------------- navigation ---

  void _goTo(int page, {int? startAyah}) {
    if (page < 1 || page > 604) return;
    HapticFeedback.selectionClick();
    _loadPage(page, startAyah: startAyah);
    _showPage(page, animate: false);
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
    setState(() => _revision++);
    if (_session?.done ?? false) _pageDone(_session!);
  }

  void _hintAyah() {
    _session?.revealAyah();
    HapticFeedback.selectionClick();
    setState(() => _revision++);
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
                  Expanded(child: _mushaf(glass)),
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

  /// The Mushaf itself, page by page, swiped exactly like the reader.
  Widget _mushaf(GlassTheme glass) {
    final repo = context.read<QuranRepository>();
    final style = MushafStyle.of(context);
    return PageView.builder(
      controller: _pages,
      itemCount: 604,
      allowImplicitScrolling: true,
      onPageChanged: _onSwiped,
      itemBuilder: (context, i) {
        final page = i + 1;
        final s = _session;
        final current = s != null && page == _page;
        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
            child: MushafPageView(
              page: page,
              lines: repo.linesOnPage(page),
              referenceWidth: repo.referenceLineWidth,
              style: style,
              onAyahTap: (_) {},
              revision: current ? _revision * 4 + (_peek ? 1 : 0) + (_active ? 2 : 0) : (_peek ? 1 : 0),
              wordPaint: current ? (k) => _paintWord(glass, s, k) : (_) => _hiddenPaint(glass),
            ),
          ),
        );
      },
    );
  }

  MushafWordPaint _hiddenPaint(GlassTheme glass) => MushafWordPaint(
        hidden: true,
        peekOpacity: _peek ? 0.28 : 0,
        underline: glass.onGlass.withValues(alpha: 0.22),
      );

  MushafWordPaint? _paintWord(GlassTheme glass, TasmeeSession s, int k) {
    if (k >= s.words.length) return _hiddenPaint(glass);
    const red = Color(0xFFE5484D);
    final w = s.words[k];
    final flash = k == _flashIndex;
    final current = k == s.expected && _active;
    final bg = flash ? red.withValues(alpha: 0.18) : (current ? glass.accent.withValues(alpha: 0.10) : null);
    if (w.revealed) {
      if (w.missed) return MushafWordPaint(color: red, background: bg);
      if (w.state == TasmeeState.hinted) return MushafWordPaint(color: glass.accent, background: bg);
      return bg == null ? null : MushafWordPaint(background: bg);
    }
    final mistake = w.state == TasmeeState.mistake;
    return MushafWordPaint(
      hidden: true,
      peekOpacity: _peek ? 0.28 : 0,
      background: bg,
      underline: mistake || flash ? red : (current ? glass.accent : glass.onGlass.withValues(alpha: 0.22)),
      underlineWidth: mistake || flash || current ? 2.4 : 1.2,
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
