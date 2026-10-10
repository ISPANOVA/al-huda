import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/data/surah_metadata.dart';
import '../../core/platform/web_env.dart';
import '../../core/theme/app_themes.dart';
import '../../core/utils/arabic_utils.dart';
import '../../core/widgets/noor_ui.dart';
import '../../core/widgets/state_views.dart';
import '../audio/presentation/cubit/audio_cubit.dart';
import '../settings/presentation/cubit/settings_cubit.dart';
import '../quran/domain/repositories/quran_repository.dart';
import '../quran/domain/entities/mushaf_line.dart';
import '../quran/presentation/mushaf/mushaf_page.dart' show MushafPageView, MushafStyle, MushafWordPaint;
import '../quran/presentation/mushaf/mushaf_reader_page.dart' show MushafChip, MushafPageProportion, MushafToolIcon, mushafPaperColor;
import 'phonetic/phonetic_text.dart';
import 'phonetic/phonetic_tracker.dart';
import 'phonetic/quran_listener.dart';
import 'tasmee_engine.dart';
import 'tasmee_follower.dart';
import 'tasmee_locator.dart';
import 'web_speech.dart';

/// التسميع: the Mushaf's words are hidden; recite from memory from anywhere
/// (the surah and ayah are found from what you say) and each word appears as
/// you say it. A wrong word stays hidden with a red line and a warning tone.
/// Pages turn by themselves, and pages already recited stay shown.
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

  /// Words with one doubtful letter (on-device model): to review, not counted.
  final List<TasmeeMistake> _doubts = [];
  late int _page = widget.startPage;
  TasmeeFollower? _tracker;
  bool _ready = false;

  /// The on-device Quran model listens (Android); otherwise the platform's
  /// speech recognition (the browser's, on the web).
  bool _phonetic = false;
  QuranListener? _listener;
  static PhoneticQuran? _phQuran;
  static List<String> _openings = const [];

  /// The surah being tested (null: the whole Quran).
  int? _scopeSurah;

  /// Errors before any word was heard: a phone or emulator without a working
  /// speech service only ever reports errors.
  int _earlyErrors = 0;
  bool _gotResult = false;
  bool _helpShown = false;
  bool _active = false; // user wants to listen
  bool _listening = false;
  late String _status = _idleStatus;
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

  /// Changes whenever the drawing must refresh.
  int _revision = 0;
  Timer? _settleTimer;
  bool _leaving = false;

  String get _idleStatus => _scopeSurah == null
      ? 'اضغط الميكروفون واقرأ من أي موضع، وسأعرف مكانك'
      : 'اضغط الميكروفون واقرأ من أي آية في سورة ${SurahMetadata.surah(_scopeSurah!).name}';

  @override
  void initState() {
    super.initState();
    final audio = context.read<AudioCubit>();
    if (audio.state.playing) audio.togglePlay();
    _prepare();
  }

  @override
  void dispose() {
    _active = false;
    _watchdog?.cancel();
    _flashTimer?.cancel();
    _settleTimer?.cancel();
    _statusTimer?.cancel();
    _stt.cancel();
    _listener?.dispose();
    _pages.dispose();
    _fx.dispose();
    super.dispose();
  }

  // -------------------------------------------------------- the words ---

  /// Every word of the Mushaf in page order (built once per run of the app;
  /// only the states are reset for a new Tasmee).
  static List<TasmeeWord>? _all;

  /// Index of each page's first word (1-based pages; [605] is the end).
  static List<int> _pageStart = const [];

  /// Searches the whole Quran (to tell the reciter when they recite outside
  /// the chosen surah).
  static TasmeeLocator? _fullLocator;

  /// Index of each ayah's first word, by global ayah number.
  static List<int> _ayahStart = const [];

  static final _ayahNumber = RegExp('[\\s\u00A0]+[٠-٩]+\$');

  Future<void> _prepare() async {
    final repo = context.read<QuranRepository>();
    await repo.ensureLoaded();
    var words = _all;
    if (words == null) {
      words = <TasmeeWord>[];
      final pageStart = List<int>.filled(QuranRepository.pageCount + 2, 0);
      final ayahStart = List<int>.filled(6237, -1);
      for (var page = 1; page <= QuranRepository.pageCount; page++) {
        pageStart[page] = words.length;
        for (final line in repo.linesOnPage(page)) {
          if (line.type != MushafLineType.text && line.type != MushafLineType.centered) continue;
          for (final w in line.words) {
            if (w.ayah == 0) continue;
            final ref = SurahMetadata.fromGlobal(w.ayah);
            final number = _ayahNumber.firstMatch(w.text);
            if (w.ayah < ayahStart.length && ayahStart[w.ayah] < 0) ayahStart[w.ayah] = words.length;
            words.add(TasmeeWord(
              surah: ref.surah,
              ayah: ref.ayah,
              text: number == null ? w.text : w.text.substring(0, number.start),
              endsAyah: number != null,
            ));
          }
        }
        // Keep the screen responsive while the words are prepared.
        if (page % 40 == 0) await Future<void>.delayed(Duration.zero);
      }
      pageStart[QuranRepository.pageCount + 1] = words.length;
      _all = words;
      _pageStart = pageStart;
      _ayahStart = ayahStart;
    } else {
      for (final w in words) {
        w.state = TasmeeState.hidden;
        w.missed = false;
        w.doubtful = false;
      }
    }
    if (!mounted) return;
    // The on-device model when this build has it.
    if (!kIsWeb && await QuranListener.available()) {
      try {
        _phQuran ??= await _loadPhonetics(words);
        _phonetic = true;
        // Ready before the first words are recited.
        final ph = _phQuran!;
        Future<void>.delayed(const Duration(milliseconds: 400), ph.warmUp);
      } catch (_) {
        _phonetic = false;
      }
    }
    if (!mounted) return;
    final TasmeeFollower tracker = _phonetic
        ? PhoneticTracker(words, _phQuran!, _mistakes,
            openings: _openings,
            doubts: _doubts,
            strict: context.read<SettingsCubit>().state.tasmeeStrict,
            near: _pageStart[widget.startPage])
        : TasmeeTracker(words, _mistakes, near: _pageStart[widget.startPage]);
    final start = widget.startAyah;
    if (start != null && start < _ayahStart.length && _ayahStart[start] >= 0) {
      tracker.startAt(_ayahStart[start], pageStart: _pageStart[widget.startPage]);
    }
    setState(() {
      _tracker = tracker;
      _revision++;
    });
  }

  /// The phonetic script of every word (assets/tasmee/phonemes.txt).
  static Future<PhoneticQuran> _loadPhonetics(List<TasmeeWord> words) async {
    final text = await rootBundle.loadString('assets/tasmee/phonemes.txt');
    final lines = text.split('\n');
    final extra = jsonDecode(await rootBundle.loadString('assets/tasmee/extra.json')) as Map<String, dynamic>;
    _openings = [
      PhoneticText.normalize((extra['istiadha'] as List).join()),
      PhoneticText.normalize(lines.first.replaceAll(' ', '')),
    ];
    return PhoneticQuran.build(words, lines, SurahMetadata.globalAyah);
  }

  /// Page showing word [index].
  int _pageOf(int index) {
    var lo = 1, hi = QuranRepository.pageCount;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (_pageStart[mid] <= index) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  int _surahStart(int surah) => _ayahStart[SurahMetadata.globalAyah(surah, 1)];
  int _surahEnd(int surah) => surah >= 114 ? _all!.length : _surahStart(surah + 1);

  /// Turns the Mushaf to [page] (as the app, not a swipe).
  void _showPage(int page, {bool animate = true}) {
    if (_page != page && mounted) setState(() => _page = page);
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
    // Looking at another page: before the place is found, it is the likely
    // one (between ayahs that occur more than once).
    setState(() => _page = index + 1);
    final t = _tracker;
    if (t != null && !t.located) t.near = _pageStart[_page];
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

      String? pick(String id) => ar.where((l) => l.localeId.replaceAll('-', '_') == id).firstOrNull?.localeId;
      _localeId = pick('ar_SA') ?? pick('ar_EG') ?? (ar.isNotEmpty ? ar.first.localeId : 'ar_SA');
    } catch (_) {
      _localeId = 'ar_SA';
    }
    return true;
  }

  Future<void> _toggleMic() async {
    if (_phonetic) return _togglePhonetic();
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
    _active = true;
    _earlyErrors = 0;
    // Android closes each utterance after a pause; keep the mic open while active.
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (_active && !_starting && !_stt.isListening) _listen();
    });
    await _listen(manual: true);
  }

  // ---------------------------------------------- the on-device model ---

  Future<void> _togglePhonetic() async {
    final t = _tracker;
    if (t is! PhoneticTracker) return;
    if (_active) {
      _active = false;
      await _listener?.stop();
      if (!mounted) return;
      setState(() {
        _listening = false;
        _level = 0;
        _status = 'متوقف مؤقتًا • اضغط للمتابعة';
      });
      return;
    }
    final listener = _listener ??= QuranListener();
    // The model is downloaded once, the first time (it isn't in the app).
    if (!await QuranListener.modelReady()) {
      if (!mounted || !await _askDownload()) return;
      if (!mounted) return;
      setState(() => _status = 'جارٍ تحميل ملف التسميع…');
      final got = await QuranListener.download(onProgress: (p) {
        if (mounted) {
          setState(() => _status = 'جارٍ تحميل ملف التسميع (مرة واحدة فقط)… ${ArabicUtils.toArabicDigits((p * 100).floor())}٪');
        }
      });
      if (!mounted) return;
      if (!got) {
        setState(() => _status = 'تعذر التحميل، تأكد من الإنترنت ثم اضغط الميكروفون مرة أخرى');
        return;
      }
    }
    setState(() => _status = 'جارٍ تجهيز التسميع…');
    final ok = await listener.prepare();
    if (!mounted) return;
    if (!ok) {
      setState(() => _status = 'تعذر تشغيل التسميع على هذا الهاتف');
      return;
    }
    t.newUtterance(manual: true);
    final started = await listener.start(
      onResult: _onPhonemes,
      onLevel: (l) {
        if (mounted && _active) setState(() => _level = l);
      },
    );
    if (!mounted) return;
    if (!started) {
      setState(() => _status = 'يحتاج التسميع إذن الميكروفون من إعدادات التطبيق');
      return;
    }
    setState(() {
      _active = true;
      _listening = true;
      _status = _listeningStatus;
    });
  }

  /// Asks before the one-time download of the model.
  Future<bool> _askDownload() async {
    final glass = GlassTheme.of(context);
    final yes = await showGlassSheet<bool>(context, builder: (ctx) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('تحميل التسميع', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 10),
          Text(
            'التسميع يعمل على هاتفك نفسه دون إنترنت، ويحتاج تحميل ملف التعرّف على التلاوة مرة واحدة فقط '
            '(حوالي ${ArabicUtils.toArabicDigits(QuranListener.downloadMb)} ميجابايت). يُفضّل التحميل على شبكة Wi-Fi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: glass.onGlassMuted, height: 1.6),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.download_rounded),
            label: const Text('تحميل الآن'),
          ),
          const SizedBox(height: 6),
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('لاحقًا')),
        ],
      );
    });
    return yes ?? false;
  }

  void _onPhonemes(String text, bool isFinal) {
    final t = _tracker;
    if (t is! PhoneticTracker || !mounted) return;
    final wasLocated = t.located;
    final before = t.expected;
    final res = t.feed(text, isFinal: isFinal);
    _heard = t.heardText;
    if (isFinal) t.newUtterance();
    _afterFeed(t, res, wasLocated: wasLocated, before: before);
  }

  Future<void> _stopListening() async {
    _active = false;
    _watchdog?.cancel();
    if (_phonetic) {
      await _listener?.stop();
    } else {
      await _stt.stop();
    }
  }

  /// When the current listening started: an end reported right after it
  /// belongs to the previous one (stopped by the reciter) and is ignored.
  DateTime _listenStarted = DateTime(2000);

  Future<void> _listen({bool manual = false}) async {
    if (!_active || !mounted || _starting) return;
    _starting = true;
    _settle();
    _listenStarted = DateTime.now();
    _tracker?.newUtterance(manual: manual);
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
          _status = _listeningStatus;
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
      // The end of the listening the reciter just stopped, arriving after the
      // new one began: restarting now would cut the new recitation.
      if (_active && DateTime.now().difference(_listenStarted) < const Duration(milliseconds: 800)) return;
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
      setState(() => _status =
          kIsWeb ? 'يحتاج التسميع إذن الميكروفون من المتصفح' : 'يحتاج التسميع إذن الميكروفون من إعدادات التطبيق');
      _showSpeechHelp();
      return;
    }
    // Other errors (silence, no match, busy) are recovered by the watchdog,
    // unless nothing was ever heard: then the device can't recognise speech.
    // Only errors that mean «this device can't recognise speech» count;
    // silence, no match, busy and client errors happen on every phone.
    const fatal = {
      'error_audio',
      'error_recognizer_disabled',
      'error_language_not_supported',
      'error_language_unavailable',
      'error_server',
      'error_server_disconnected',
    };
    if (!_gotResult && fatal.contains(e.errorMsg)) {
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
  void _showSpeechHelp({String? error}) {
    if (_helpShown) return;
    _helpShown = true;
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
          Text('الميكروفون لا يعمل للتسميع',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 8),
          if (kIsWeb) ..._webHelp(step, glass) else ...[
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
          ],
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

  /// The same help for the web build: the browser does the recognition.
  List<Widget> _webHelp(Widget Function(IconData, String) step, GlassTheme glass) {
    final ios = isIosBrowser;
    return [
      Text(
        !webSpeechSupported
            ? 'هذا المتصفح لا يدعم التعرف على الكلام. افتح الصفحة من ${ios ? 'Safari' : 'Google Chrome'}.'
            : 'التسميع في المتصفح يعتمد على خدمة التعرف على الكلام في ${ios ? 'Safari (خدمة الإملاء من Apple)' : 'Chrome (خدمة Google)'}، ويحتاج اتصالًا بالإنترنت.',
        style: TextStyle(color: glass.onGlassMuted, height: 1.6),
      ),
      const SizedBox(height: 16),
      if (ios) ...[
        step(Icons.public_rounded, 'افتح الصفحة من Safari نفسه، فهو الأضمن للتسميع على آيفون.'),
        step(Icons.keyboard_voice_rounded, 'فعّل الإملاء: الإعدادات، ثم عام، ثم لوحة المفاتيح، ثم «تفعيل الإملاء».'),
        step(Icons.mic_rounded, 'اسمح بالميكروفون: الإعدادات، ثم Safari، ثم الميكروفون، ثم «سماح»، وبعدها أعد تحميل الصفحة.'),
      ] else ...[
        step(Icons.public_rounded, 'استخدم Google Chrome أو Microsoft Edge (فايرفوكس لا يدعم التسميع).'),
        step(Icons.mic_rounded, 'اسمح بالميكروفون: اضغط رمز القفل بجوار عنوان الصفحة، ثم الميكروفون، ثم «سماح»، وبعدها أعد تحميل الصفحة.'),
      ],
      step(Icons.wifi_rounded, 'تأكد من الاتصال بالإنترنت.'),
    ];
  }

  /// The reciter is reciting outside the chosen surah (where they are).
  String? _outside;

  String get _listeningStatus => _tracker?.located ?? false
      ? 'أستمع إليك… اقرأ من حفظك'
      : _outside ?? (_scopeSurah == null
          ? 'أستمع… اقرأ من أي موضع'
          : 'أستمع… اقرأ من أي آية في سورة ${SurahMetadata.surah(_scopeSurah!).name}');

  void _onResult(SpeechRecognitionResult r) {
    if (_tracker == null || !mounted) return;
    if (r.recognizedWords.trim().isNotEmpty) _gotResult = true;
    _heard = r.recognizedWords;
    final heard = TasmeeMatcher.words(r.recognizedWords);
    _settleTimer?.cancel();
    if (r.finalResult) {
      _pendingWords = const [];
    } else {
      _pendingWords = heard;
      _settleTimer = Timer(const Duration(milliseconds: 1000), _settle);
    }
    final alternates = [for (final a in r.alternates.skip(1)) TasmeeMatcher.words(a.recognizedWords)];
    _apply(heard, isFinal: r.finalResult, alternates: alternates);
  }

  /// Judges the last word heard once the reciter paused after it.
  void _settle() {
    _settleTimer?.cancel();
    final words = _pendingWords;
    _pendingWords = const [];
    if (words.isEmpty || _tracker == null || !mounted) return;
    _apply(words, isFinal: true);
  }

  void _apply(
    List<String> heard, {
    required bool isFinal,
    List<List<String>> alternates = const [],
  }) {
    final t = _tracker;
    if (t is! TasmeeTracker || !mounted) return;
    final wasLocated = t.located;
    final before = t.expected;
    final res = t.feed(heard, isFinal: isFinal, alternates: alternates);
    // A surah was chosen but the reciter is in another one: say where.
    if (!t.located && _scopeSurah != null && heard.length >= 5) {
      final hit = (_fullLocator ??= TasmeeLocator(t.words)).locate(heard);
      if (hit != null && hit.sure) {
        final w = t.words[hit.index];
        _outside = 'هذه من سورة ${SurahMetadata.surah(w.surah).name}، وأنت تسمّع سورة '
            '${SurahMetadata.surah(_scopeSurah!).name}. غيّر الاختيار من الأعلى';
        _status = _outside!;
      }
    }
    _afterFeed(t, res, wasLocated: wasLocated, before: before);
  }

  /// What follows a result: the warning for a mistake, where the reciter
  /// is, the page turned to the word being recited.
  void _afterFeed(TasmeeFollower t, TasmeeFeed res, {required bool wasLocated, required int before}) {
    if (res.mistakes > 0) _onMistake(res.flash);
    if (t.located && (!wasLocated || (t.expected - before).abs() > 8)) {
      // Found (or moved to) the place being recited.
      HapticFeedback.mediumImpact();
      final w = t.words[math.min(t.expected, t.words.length - 1)];
      _status = 'سورة ${SurahMetadata.surah(w.surah).name} • الآية ${ArabicUtils.toArabicDigits(w.ayah)}';
      _statusTimer?.cancel();
      _statusTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _active) setState(() => _status = _listeningStatus);
      });
    }
    setState(() => _revision++);
    if (t.located && t.expected < t.words.length) _showPage(_pageOf(t.expected));
    if (t.done && t.expected != before) _finished();
  }

  Timer? _statusTimer;

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

  /// The whole range (the surah, or the Quran) was recited.
  Future<void> _finished() async {
    HapticFeedback.mediumImpact();
    await _stopListening();
    if (mounted) _showSummary(finished: true);
  }

  // -------------------------------------------------------- navigation ---

  void _goTo(int page, {required int startAyah}) {
    final t = _tracker;
    if (t == null || page < 1 || page > 604) return;
    HapticFeedback.selectionClick();
    final index = _ayahStart[startAyah];
    if (index < t.from || index >= t.to) _setScope(null);
    t.startAt(index, pageStart: _pageStart[page]);
    setState(() {
      _page = page;
      _revision++;
    });
    _showPage(page, animate: false);
  }

  /// Tests one surah (or, with null, the whole Quran): the place is found
  /// within it.
  void _setScope(int? surah) {
    final t = _tracker;
    if (t == null) return;
    _scopeSurah = surah;
    _outside = null;
    if (surah == null) {
      t.setScope(0, t.words.length);
      t.near = _pageStart[_page];
    } else {
      t.setScope(_surahStart(surah), _surahEnd(surah));
      t.near = _surahStart(surah);
      _showPage(_pageOf(_surahStart(surah)), animate: false);
      _page = _pageOf(_surahStart(surah));
    }
    setState(() {
      _status = _active ? _listeningStatus : _idleStatus;
      _revision++;
    });
  }

  Future<void> _openScope() async {
    final surah = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScopeSheet(current: _scopeSurah),
    );
    if (surah == null || !mounted) return;
    _setScope(surah == 0 ? null : surah);
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

  void _hint(void Function(TasmeeFollower t) reveal) {
    final t = _tracker;
    if (t == null || t.done) return;
    // Before the place is known, a hint starts from the page on screen.
    if (!t.located) t.startAt(_pageStart[_page]);
    reveal(t);
    HapticFeedback.selectionClick();
    setState(() => _revision++);
    if (t.expected < t.words.length) _showPage(_pageOf(t.expected));
    if (t.done) _finished();
  }

  void _hintWord() => _hint((t) => t.hintNext());
  void _hintAyah() => _hint((t) => t.revealAyah());

  /// Words recited correctly (not hinted, not missed).
  int get _correctTotal {
    var c = 0;
    for (final w in _tracker?.words ?? const <TasmeeWord>[]) {
      if (w.state == TasmeeState.correct && !w.missed) c++;
    }
    return c;
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
                _stat(glass, '${ArabicUtils.toArabicDigits(_correctTotal)}', 'كلمة صحيحة'),
                const SizedBox(width: 12),
                _stat(glass, '${ArabicUtils.toArabicDigits(_mistakes.length)}', 'خطأ', error: true),
                if (_doubts.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  _stat(glass, '${ArabicUtils.toArabicDigits(_doubts.length)}', 'للمراجعة', color: _amber),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _mistakes.isEmpty && _doubts.isEmpty
                  ? Center(child: Text('لا أخطاء، ما شاء الله', style: TextStyle(color: glass.onGlassMuted)))
                  : ListView.separated(
                      itemCount: _mistakes.length + _doubts.length,
                      separatorBuilder: (_, _) => Divider(height: 1, color: glass.onGlass.withValues(alpha: 0.08)),
                      itemBuilder: (_, i) {
                        final doubt = i >= _mistakes.length;
                        final m = doubt ? _doubts[i - _mistakes.length] : _mistakes[i];
                        return ListTile(
                          dense: true,
                          leading: doubt
                              ? const Icon(Icons.help_outline_rounded, color: _amber)
                              : const Icon(Icons.close_rounded, color: Color(0xFFE5484D)),
                          title: Text(m.word, style: QuranFont.amiriQuran.style(fontSize: 20, height: 1.6, color: glass.onGlass)),
                          subtitle: Text(
                            'سورة ${SurahMetadata.surah(m.surah).name} • الآية ${ArabicUtils.toArabicDigits(m.ayah)}'
                            '${m.heard.isEmpty ? ' • كلمة متروكة' : ' • سُمع: ${m.heard}'}'
                            '${doubt ? '\nحرف قد يكون غير صحيح، راجعه' : ''}',
                          ),
                        );
                      },
                    ),
            ),
            if (_phonetic) ...[
              StatefulBuilder(builder: (ctx, setInner) {
                final strict = ctx.read<SettingsCubit>().state.tasmeeStrict;
                return SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: strict,
                  title: const Text('دقة عالية جدًا', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('احسب الكلمة التي فيها حرف مشكوك فيه خطأً',
                      style: TextStyle(color: glass.onGlassMuted, fontSize: 12)),
                  onChanged: (v) {
                    ctx.read<SettingsCubit>().setTasmeeStrict(v);
                    final t = _tracker;
                    if (t is PhoneticTracker) t.strict = v;
                    setInner(() {});
                  },
                );
              }),
              Text('التصحيح الآلي قد يخطئ، ولا يغني عن القراءة على شيخ متقن.',
                  textAlign: TextAlign.center, style: TextStyle(color: glass.onGlassMuted, fontSize: 11.5)),
            ],
          ],
        ),
      );
    });
  }

  static const _amber = Color(0xFFF5A524);

  Widget _stat(GlassTheme glass, String value, String label, {bool error = false, Color? color}) {
    final c = color ?? (error ? const Color(0xFFE5484D) : glass.accent);
    return Container(
      width: 104,
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
    final style = MushafStyle.of(context);
    final t = _tracker;
    return PopScope(
      canPop: _leaving || (_mistakes.isEmpty && !(t?.located ?? false)),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _stopListening();
        _showSummaryThenLeave();
      },
      // The same page as the Mushaf reader: flat paper colour, the page at
      // full height with the same proportions, chips and icons above it.
      child: Scaffold(
        backgroundColor: mushafPaperColor(context),
        body: SafeArea(
          child: t == null
              ? const LoadingView()
              : Column(
                  children: [
                    _topBar(glass, style, t),
                    Expanded(child: _mushaf(glass, style, t)),
                    _controls(glass, style, t),
                  ],
                ),
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

  /// Like the reader's header: back • what is tested ▾ • tools.
  Widget _topBar(GlassTheme glass, MushafStyle style, TasmeeFollower t) {
    final start = _pageStart[_page];
    final end = _pageStart[_page + 1];
    var recited = 0;
    for (var i = start; i < end; i++) {
      if (t.words[i].revealed) recited++;
    }
    final progress = end > start ? recited / (end - start) : 0.0;
    final first = start < end ? t.words[start] : null;
    const red = Color(0xFFE5484D);
    return SizedBox(
      height: 52,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  MushafToolIcon(
                    icon: Icons.arrow_forward_rounded,
                    color: style.accent,
                    tooltip: 'رجوع',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  MushafChip(
                    style: style,
                    onTap: _openScope,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _scopeSurah == null ? 'القرآن كله' : SurahMetadata.surah(_scopeSurah!).name,
                          maxLines: 1,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: style.accent),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: style.accent),
                      ],
                    ),
                  ),
                  // Where the page is: surah • page number.
                  Expanded(
                    child: Text(
                      first == null
                          ? ''
                          : '${SurahMetadata.surah(first.surah).name} • صفحة ${ArabicUtils.toArabicDigits(_page)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: style.muted, fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                  ),
                  MushafToolIcon(
                    icon: Icons.search_rounded,
                    color: style.accent,
                    tooltip: 'انتقل إلى سورة أو آية',
                    onTap: _openSearch,
                  ),
                  MushafToolIcon(
                    icon: _hide ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    color: style.accent,
                    tooltip: _hide ? 'إظهار الآيات' : 'إخفاء الآيات (اختبار الحفظ)',
                    onTap: () => setState(() => _hide = !_hide),
                  ),
                  IconButton(
                    tooltip: 'النتيجة',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _showSummary(),
                    icon: Badge(
                      isLabelVisible: _mistakes.isNotEmpty,
                      backgroundColor: red,
                      label: Text(ArabicUtils.toArabicDigits(_mistakes.length)),
                      child: Icon(Icons.fact_check_rounded, color: style.accent, size: 24),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // The page's progress, as a hairline under the header.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 2,
                color: style.accent,
                backgroundColor: style.accent.withValues(alpha: 0.10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The Mushaf itself, page by page, exactly as in the reader.
  Widget _mushaf(GlassTheme glass, MushafStyle style, TasmeeFollower t) {
    final repo = context.read<QuranRepository>();
    return PageView.builder(
      controller: _pages,
      itemCount: 604,
      allowImplicitScrolling: true,
      onPageChanged: _onSwiped,
      itemBuilder: (context, i) {
        final page = i + 1;
        final base = _pageStart[page];
        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
            child: MushafPageProportion(
              child: MushafPageView(
                page: page,
                lines: repo.linesOnPage(page),
                referenceWidth: repo.referenceLineWidth,
                style: style,
                onAyahTap: (_) {},
                revision: _revision * 4 + (_hide ? 1 : 0) + (_active ? 2 : 0),
                wordPaint: (k) => _paintWord(style, t, base + k),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Shown (default): the page reads like the Mushaf; the word to recite is
  /// marked, mistakes are red, hints gold. Hidden: a memorisation test, each
  /// word appears when it is recited.
  static bool _hide = false;

  MushafWordPaint? _paintWord(MushafStyle style, TasmeeFollower t, int k) {
    const red = Color(0xFFE5484D);
    if (k >= t.words.length) return _hide ? MushafWordPaint(hidden: true, underline: style.ink.withValues(alpha: 0.12)) : null;
    final w = t.words[k];
    final flash = k == _flashIndex;
    final current = k == t.expected && _active && t.located;
    final bg = flash ? red.withValues(alpha: 0.20) : (current ? style.highlight : null);
    final wrong = w.missed || w.state == TasmeeState.mistake;
    if (w.revealed || !_hide) {
      if (wrong) return MushafWordPaint(color: red, background: bg);
      if (w.doubtful) return MushafWordPaint(color: _amber, background: bg);
      if (w.state == TasmeeState.hinted) return MushafWordPaint(color: style.accent, background: bg);
      return bg == null ? null : MushafWordPaint(background: bg);
    }
    return MushafWordPaint(
      hidden: true,
      background: bg,
      underline: wrong || flash ? red : (current ? style.accent : style.ink.withValues(alpha: 0.12)),
      underlineWidth: wrong || flash || current ? 2.2 : 1,
    );
  }

  /// A small tool under the page: icon above a one-line label.
  Widget _hintButton(MushafStyle style, IconData icon, String label, VoidCallback? onTap) {
    final color = onTap == null ? style.muted.withValues(alpha: 0.5) : style.accent;
    return SizedBox(
      height: 54,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls(GlassTheme glass, MushafStyle style, TasmeeFollower t) {
    final canHint = !t.done;
    final heard = !_active || _heard.isEmpty
        ? ''
        : _phonetic
            // The model hears sounds, not words: the last ones heard.
            ? (_heard.length > 34 ? '…${_heard.substring(_heard.length - 34)}' : _heard)
            : _heard.split(' ').reversed.take(6).toList().reversed.join(' ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // One fixed-height line, so the page above never moves.
          SizedBox(
            height: 34,
            child: Center(
              child: Text(
                heard.isNotEmpty && t.located ? '«$heard»' : _status,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: heard.isNotEmpty && t.located ? style.accent.withValues(alpha: 0.9) : style.muted,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _hintButton(style, Icons.lightbulb_outline_rounded, 'الكلمة التالية', canHint ? _hintWord : null),
              ),
              // The mic keeps a fixed footprint; the sound level only scales
              // its painting, so the buttons beside it never move.
              SizedBox(
                width: 76,
                height: 64,
                child: Center(
                  child: Semantics(
                    button: true,
                    label: _active ? 'إيقاف الاستماع' : 'ابدأ التسميع بالميكروفون',
                    child: GestureDetector(
                    onTap: _toggleMic,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 120),
                      scale: 1 + (_active ? _level * 0.12 : 0),
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _active ? const Color(0xFFE5484D) : style.accent,
                          boxShadow: [
                            BoxShadow(
                              color: (_active ? const Color(0xFFE5484D) : style.accent)
                                  .withValues(alpha: _listening ? 0.55 : 0.25),
                              blurRadius: _listening ? 14 + _level * 18 : 10,
                            ),
                          ],
                        ),
                        child: Icon(_active ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.black, size: 30),
                      ),
                    ),
                  ),
                  ),
                ),
              ),
              Expanded(
                child: _hintButton(style, Icons.subject_rounded, 'باقي الآية', canHint ? _hintAyah : null),
              ),
            ],
          ),
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

/// What to test: the whole Quran (the place is found from the recitation) or
/// one surah. Pops 0 for the whole Quran, or the surah number.
class _ScopeSheet extends StatefulWidget {
  final int? current;

  const _ScopeSheet({required this.current});

  @override
  State<_ScopeSheet> createState() => _ScopeSheetState();
}

class _ScopeSheetState extends State<_ScopeSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final q = _GoToSheetState._norm(_q);
    final n = int.tryParse(q);
    final list = SurahMetadata.all
        .where((s) => q.isEmpty || _GoToSheetState._norm(s.name).contains(q) || (n != null && s.number == n))
        .toList();
    Widget option({required bool selected, required Widget leading, required String title, String? subtitle, required int value}) =>
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 6),
          leading: leading,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: subtitle == null ? null : Text(subtitle, style: TextStyle(color: glass.onGlassMuted, fontSize: 12)),
          trailing: selected ? Icon(Icons.check_circle_rounded, color: glass.accent) : null,
          onTap: () => Navigator.of(context).pop(value),
        );
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
            const Text('ماذا تسمّع؟', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 4),
            Text('اقرأ من أي موضع، وسأحدد السورة والآية من تلاوتك',
                style: TextStyle(color: glass.onGlassMuted, fontSize: 12.5)),
            const SizedBox(height: 10),
            option(
              selected: widget.current == null,
              leading: CircleAvatar(
                radius: 17,
                backgroundColor: glass.accent.withValues(alpha: 0.14),
                child: Icon(Icons.menu_book_rounded, color: glass.accent, size: 18),
              ),
              title: 'القرآن كله',
              subtitle: 'ابدأ من أي سورة وأي آية',
              value: 0,
            ),
            const SizedBox(height: 6),
            TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: 'أو اختر سورة: اسمها أو رقمها',
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
                  return option(
                    selected: widget.current == s.number,
                    leading: CircleAvatar(
                      radius: 17,
                      backgroundColor: glass.accent.withValues(alpha: 0.14),
                      child: Text(ArabicUtils.toArabicDigits(s.number),
                          style: TextStyle(color: glass.accent, fontWeight: FontWeight.w800, fontSize: 13)),
                    ),
                    title: 'سورة ${s.name}',
                    subtitle: '${s.revelationAr} • ${ArabicUtils.toArabicDigits(s.ayahCount)} آية',
                    value: s.number,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
