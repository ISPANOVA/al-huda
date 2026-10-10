import 'dart:math' as math;

/// State of one word of the Mushaf during a recitation test (تسميع).
/// [given]: shown without being recited (before the ayah the test started at).
enum TasmeeState { hidden, correct, hinted, mistake, given }

class TasmeeWord {
  final int surah;
  final int ayah;

  /// Index of the ayah's last word marker follows this word when true.
  final bool endsAyah;
  final String text;
  final String key;
  TasmeeState state = TasmeeState.hidden;

  /// The reciter got this word wrong at least once (shown in red when revealed).
  bool missed = false;

  /// One letter of it may have been wrong (the model isn't sure): shown in
  /// amber, not counted as a mistake.
  bool doubtful = false;

  /// For the disjoint letters (الم، كهيعص…): the key of how they are recited,
  /// letter by letter («ألف لام ميم»). Null for every other word.
  final String? spoken;

  /// Other correct ways the word is written: with the small letters the
  /// Uthmani script adds (أُحۡيِۦ ← أحيي, دَاوُۥدَ ← داوود), and without the
  /// vocative «يا» merged into it (يَٰمُوسَىٰٓ ← موسى). Empty for most words.
  final List<String> alts;

  TasmeeWord({required this.surah, required this.ayah, required this.text, required this.endsAyah})
      : key = TasmeeMatcher.key(text),
        spoken = TasmeeMatcher.spokenLetters(surah, ayah, text),
        alts = TasmeeMatcher.altKeys(text);

  /// Heard key [h] is this word.
  bool heardAs(String h) {
    if (TasmeeMatcher.similar(h, key)) return true;
    for (final a in alts) {
      if (TasmeeMatcher.similar(h, a)) return true;
    }
    return false;
  }

  bool get revealed => state != TasmeeState.hidden && state != TasmeeState.mistake;
}

class TasmeeMistake {
  final int surah;
  final int ayah;
  final String word;

  /// What the reciter said instead (empty when the word was skipped).
  final String heard;

  const TasmeeMistake(this.surah, this.ayah, this.word, this.heard);
}

/// Result of feeding recognised speech.
class TasmeeFeed {
  final int revealed;

  /// New mistakes (not alerted before) found by this result.
  final int mistakes;

  /// Index of the latest new mistake (for the red flash), or -1.
  final int flash;

  const TasmeeFeed(this.revealed, this.mistakes, [this.flash = -1]);
}

/// Compares what the reciter says with the expected words, tolerating the
/// differences between the Uthmani spelling and ordinary Arabic.
class TasmeeMatcher {
  TasmeeMatcher._();

  static final _marks = RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]');
  static final _nonLetters = RegExp('[^ء-ي]');

  static const _units = ['', 'واحد', 'اثنين', 'ثلاث', 'اربع', 'خمس', 'ست', 'سبع', 'ثماني', 'تسع'];
  static const _tens = ['', 'عشر', 'عشرين', 'ثلاثين', 'اربعين', 'خمسين', 'ستين', 'سبعين', 'ثمانين', 'تسعين'];

  /// A number the recogniser wrote in digits («19», «١٠٠٠»), as words.
  static List<String> numberWords(String token) {
    final digits = token.replaceAllMapped(RegExp('[٠-٩]'), (m) => '${m[0]!.codeUnitAt(0) - 0x0660}');
    final n = int.tryParse(digits);
    if (n == null || n < 0) return [token];
    if (n == 0) return ['صفر'];
    final out = <String>[];
    var rest = n;
    if (rest >= 1000) {
      final t = rest ~/ 1000;
      rest %= 1000;
      out.addAll(t == 1 ? ['الف'] : t == 2 ? ['الفين'] : [...numberWords('$t'), t <= 10 ? 'الاف' : 'الف']);
    }
    if (rest >= 100) {
      final h = rest ~/ 100;
      rest %= 100;
      out.add(h == 1 ? 'مائة' : h == 2 ? 'مائتين' : '${_units[h]}مائة');
    }
    if (rest > 0) {
      if (rest < 10) {
        out.add(_units[rest]);
      } else if (rest == 10) {
        out.add('عشر');
      } else if (rest < 20) {
        out.addAll([rest == 11 ? 'احد' : rest == 12 ? 'اثني' : _units[rest - 10], 'عشر']);
      } else {
        if (rest % 10 > 0) out.addAll([_units[rest % 10], 'و${_tens[rest ~/ 10]}']);
        else out.add(_tens[rest ~/ 10]);
      }
    }
    return out;
  }

  /// Splits a transcript into words, digits written out.
  static List<String> words(String transcript) => [
        for (final w in transcript.split(RegExp(r'\s+')))
          if (w.isNotEmpty) ...(RegExp(r'^[0-9٠-٩]+$').hasMatch(w) ? numberWords(w) : [w]),
      ];

  /// Letters only: no diacritics / Quranic marks, unified hamza & alef forms,
  /// and long-alef dropped (Uthmani often omits it: ٱلْكِتَٰبُ ≈ الكتاب).
  static String key(String s) => _key(s, small: false);

  /// Other keys of an Uthmani word (see [TasmeeWord.alts]).
  static List<String> altKeys(String text) {
    final out = <String>[];
    final k = key(text);
    void add(String a) {
      if (a.isNotEmpty && a != k && !out.contains(a)) out.add(a);
    }

    if (_smallLetters.hasMatch(text)) add(_key(text, small: true));
    // A letter with a round sukun is written but not read: سَأُوْرِيكُمۡ ← سأريكم,
    // بِأَيۡيْدٖ ← بأيد (أُوْلِي keeps it in ordinary spelling too).
    if (text.contains('ْ')) add(key(text.replaceAll(RegExp('[وي]ْ'), '')));
    // A ṣād with a small sīn is read as sīn: بَصۜۡطَةٗ ← بسطة.
    if (text.contains('صۜ')) add(key(text.replaceAll('صۜ', 'س')));
    // A final alef read as alef maqsura: وَنَـَٔا ← ونأى, تَتۡرَا ← تترى.
    final bare = text.replaceAll(_marks, '');
    if (bare == 'ونا' || bare == 'تترا') add('${k}ي');
    // «أن لو» written as one word: وَأَلَّوِ ← وأن لو.
    if (bare == 'وألو') add('ونلو');
    if (text.startsWith('يَٰ') && k.length >= 4) out.add(k.substring(1));
    return out;
  }

  static final _smallLetters = RegExp('[ۥۦۧۨ]');

  static String _key(String s, {required bool small}) {
    // Uthmani wāw written for a long ā (ٱلصَّلَوٰة، ٱلزَّكَوٰة، ٱلْحَيَوٰة) is read as alef.
    var k = s.replaceAll('وٰ', 'ا');
    if (k.length != _plainLength(k)) k = _uthmaniLetters(k, small: small);
    k = k.replaceAll(_marks, '');
    k = k
        .replaceAll(RegExp('[ٱأإآٲٳ]'), 'ا')
        .replaceAll('ى', 'ي')
        // Hamza on a yā' seat is often written on a bare tooth (شَيۡـٔٗا،
        // ءَابَآءِي): like the hamza itself, it is not compared.
        .replaceAll('ئ', '')
        .replaceAll('ؤ', '')
        .replaceAll('ة', 'ه')
        .replaceAll('ء', '');
    k = k.replaceAll(_nonLetters, '');
    return k.replaceAll('ا', '');
  }

  static final _small = RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]');
  static int _plainLength(String s) => s.length - _small.allMatches(s).length;

  /// Letters the Uthmani script writes small or on a bare seat, as ordinary
  /// spelling writes them (otherwise common words never match: شيئا، أحيي،
  /// رأى، آناء، ننجي).
  static String _uthmaniLetters(String s, {bool small = false}) => (small
          ? s.replaceAll('ۦ', 'ي').replaceAll('ۧ', 'ي').replaceAll('ۥ', 'و').replaceAll('ۨ', 'ن')
          : s)
      // Alef maqsura with a small alef inside a word is a long ā written as
      // alef: هَدَىٰكُمۡ ← هداكم, ٱلتَّوۡرَىٰةَ ← التوراة (but عَلَىٰ ← على).
      .replaceAll(RegExp('ىٰ(?=[ؐ-ًؚ-ٰٟۖ-ۭ]*[ء-ي])'), 'ا')
      // Hamza below a yā' seat after a long ā: ءَانَآيِٕ ← آناء, وَرَآيِٕ ← وراء
      // (but ٱمۡرِيٕ ← امرئ keeps its yā').
      .replaceAllMapped(RegExp('([اآ]ٓ?)ي[ِ]?ٕ[ِ]?'), (m) => '${m[1]}ء')
      // A yā' / wāw seat carrying a hamza below is the hamza alone:
      // ٱمۡرِيٕٖ ← امرئ, ٱلسَّيِّيِٕ ← السيئ, ٱللُّؤۡلُوِٕ ← اللؤلؤ.
      .replaceAllMapped(RegExp('[يو]([ًٌٍَُِّْ]*)ٕ'), (m) => m[1]!)
      // Hamza carried by a written yā': وَمَلَإِيْهِۦ ← وملئه.
      .replaceAll('إِيْ', 'ئ')
      // Alef written for alef maqsura: رَءَا ← رأى, تَرَٰٓءَا ← تراءى, لَدَا ← لدى, ٱلۡأَقۡصَا ← الأقصى.
      .replaceAllMapped(RegExp('(رّ?َ?ٰ?ٓ?ءَ?[آا]ٓ?|^لَدَا|^طَغَا|قۡصَا|نَـَٔا)\$'), (m) => '${m[0]!.substring(0, m[0]!.length - 1)}ى');

  static int distance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        cur[j] = math.min(math.min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
      }
      prev = cur;
    }
    return prev[b.length];
  }

  /// Letters the recogniser tends to confuse (close sounds): swapping them
  /// costs half an edit.
  static const _confusable = ['ثسص', 'ذزظ', 'ضدظ', 'طت', 'قك', 'حه'];

  static bool _close(int a, int b) {
    final x = String.fromCharCode(a), y = String.fromCharCode(b);
    for (final g in _confusable) {
      if (g.contains(x) && g.contains(y)) return true;
    }
    return false;
  }

  /// Edit distance where confusable letters cost 0.5.
  static double soundDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length.toDouble();
    if (b.isEmpty) return a.length.toDouble();
    var prev = List<double>.generate(b.length + 1, (i) => i.toDouble());
    for (var i = 1; i <= a.length; i++) {
      final cur = List<double>.filled(b.length + 1, 0)..[0] = i.toDouble();
      for (var j = 1; j <= b.length; j++) {
        final ca = a.codeUnitAt(i - 1), cb = b.codeUnitAt(j - 1);
        final cost = ca == cb ? 0.0 : (_close(ca, cb) ? 0.5 : 1.0);
        cur[j] = math.min(math.min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
      }
      prev = cur;
    }
    return prev[b.length];
  }

  /// Different first letters make different short words (إليك / عليك،
  /// لهم / عليهم), unless the recogniser confuses the two sounds.
  static bool _sameStart(String h, String e) =>
      math.min(h.length, e.length) > 5 || h[0] == e[0] || _close(h.codeUnitAt(0), e.codeUnitAt(0));

  /// Heard [h] counts as expected [e].
  static bool similar(String h, String e) {
    if (h.isEmpty || e.isEmpty) return false;
    if (h == e) return true;
    // The Uthmani script writes الليل، اللاتي، اللائي، اللذان with one lām.
    if (h.length >= 3 && e.length >= 2) {
      final i = h.indexOf('لل');
      if (i >= 0 && i <= 2 && h.replaceFirst('لل', 'ل', i) == e && _oneLam.any((st) => e.startsWith(st, i))) {
        return true;
      }
    }
    // Counted things: ثلاث / ثلاثة, سبع / سبعة (the recogniser picks either).
    if (h.length >= 3 && (h + 'ه' == e || e + 'ه' == h) && _numberish.contains(h.length < e.length ? h : e)) {
      return true;
    }
    // A doubled yā' / wāw the Uthmani script writes once: يحيي / يُحۡيِ.
    if (h.length == e.length + 1) {
      for (final d in const ['يي', 'وو']) {
        final i = h.indexOf(d);
        if (i >= 0 && h.replaceRange(i, i + 1, '') == e) return true;
      }
    }
    // Otherwise the letters must be the same: one letter added, dropped or
    // changed is a different word (وَبِٱلۡيَوۡمِ / واليوم، فقال / قال،
    // يعملون / تعملون، ربي / رب). Only a sound the recogniser confuses
    // (ذ/ز، ث/س، ض/ظ، ط/ت، ق/ك، ح/ه) may differ, letter for letter, and only
    // when what was heard is not itself another word of the Quran.
    if (h.length != e.length || knownWords.contains(h)) return false;
    var diffs = 0;
    for (var i = 0; i < e.length; i++) {
      final a = h.codeUnitAt(i), b = e.codeUnitAt(i);
      if (a == b) continue;
      if (!_close(a, b)) return false;
      diffs++;
    }
    return diffs <= (e.length <= 5 ? 1 : 2);
  }

  /// Keys of every word of the Quran (filled when the whole Mushaf is
  /// loaded): a heard word that is one of them was said, not misheard.
  static Set<String> knownWords = const {};

  static const _oneLam = ['ليل', 'لتي', 'لي', 'لذن', 'لذين'];

  static final _numberish = {
    for (final w in ['ثلاث', 'اربع', 'خمس', 'ست', 'سبع', 'ثماني', 'تسع', 'عشر', 'ثمن']) key(w),
  };

  /// What was heard could be the recogniser mishearing [e] (so another of its
  /// transcripts may be trusted): close in sound, same first letter. A clearly
  /// different word (في for على، عليك for إليك) is what the reciter said.
  static bool couldBe(String h, String e) {
    if (h.isEmpty || e.isEmpty) return false;
    if (!_sameStart(h, e)) return false;
    return soundDistance(h, e) <= math.max(1.0, e.length * 0.4);
  }

  /// Opening disjoint letters, as written (alef kept) and the surahs that
  /// start with them.
  static const _muqattaat = {
    'الم', 'المص', 'الر', 'المر', 'كهيعص', 'طه', 'طسم', 'طس', 'يس', 'ص', 'حم', 'عسق', 'ق', 'ن',
  };
  static const _muqattaatSurahs = {
    2, 3, 7, 10, 11, 12, 13, 14, 15, 19, 20, 26, 27, 28, 29, 30, 31, 32, 36, 38, //
    40, 41, 42, 43, 44, 45, 46, 50, 68,
  };

  /// Keys of the letter names: ألف لام ميم صاد را كاف ها يا عين طا سين حا قاف نون.
  static const _letterNames = {
    'ا': 'لف', 'ل': 'لم', 'م': 'ميم', 'ص': 'صد', 'ر': 'ر', 'ك': 'كف', 'ه': 'ه', //
    'ي': 'ي', 'ع': 'عين', 'ط': 'ط', 'س': 'سين', 'ح': 'ح', 'ق': 'قف', 'ن': 'نون',
  };

  static String? spokenLetters(int surah, int ayah, String text) {
    if (!_muqattaatSurahs.contains(surah)) return null;
    if (ayah != 1 && !(surah == 42 && ayah == 2)) return null;
    final k = text.replaceAll(_marks, '').replaceAll(RegExp('[ٱأإآ]'), 'ا').replaceAll(_nonLetters, '');
    if (!_muqattaat.contains(k)) return null;
    return k.split('').map((c) => _letterNames[c] ?? c).join();
  }

  /// Heard letters [acc] (keys joined) are the disjoint letters of [w].
  static bool letters(String acc, TasmeeWord w) {
    if (acc == w.key || similar(acc, w.spoken!)) return true;
    // Letter names are spelled many ways (ألف لام ميم، الف لاميم، ا ل م).
    final sp = w.spoken!;
    return acc.length >= 3 && soundDistance(acc, sp) <= (sp.length <= 4 ? 1 : 2);
  }

  /// [acc] could still grow into the disjoint letters of [w].
  static bool lettersPrefix(String acc, TasmeeWord w) {
    final sp = w.spoken!;
    if (sp.startsWith(acc) || w.key.startsWith(acc)) return true;
    if (acc.length < 3 || acc.length >= sp.length) return false;
    return distance(acc, sp.substring(0, acc.length)) <= 1;
  }

  /// Small words (their keys) a recogniser may lose: لا، ما، إن، من، في…
  static final particles = {
    for (final w in 'إن أن لا ما و ف من في عن لن لم قد ثم بل لو أو يا إذ إلى على هو هي هم'.split(' ')) key(w),
  };

  /// Words people say around a recitation (isti'adha, basmala, closing) that
  /// are not part of the tested text.
  static final ignorable = {
    for (final w in 'اعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم صدق العظيم'.split(' ')) key(w),
  };
}

/// Walks the expected words of one page while speech results arrive.
///
/// Every recogniser result is re-aligned from the start of the current
/// utterance, so when the recogniser rewrites its transcript (which it does
/// constantly while listening) the judgement follows the latest version and
/// a word is never judged on a stale guess.
///
/// Careful by design:
/// * a word is shown only when it was heard (or confirmed by what follows);
/// * a mistake needs evidence: a wrong word followed by the next words of the
///   ayah, or a pause after it; noise between correct words is ignored;
/// * going back to repeat (a few words or from the start) is followed
///   silently and never counted;
/// * small words the recogniser tends to drop (و، في، من…) are not errors.
class TasmeeSession {
  final List<TasmeeWord> words;
  final List<TasmeeMistake> mistakes;

  /// Next word to recite.
  int expected = 0;

  /// [expected] when the current segment (utterance part) began.
  int _base = 0;

  /// Words of the utterance used before the segment began.
  int _offset;

  /// Heard words used by the latest alignment (absolute index).
  int _used;

  List<String> _lastHeard;

  /// States of the words from [_base] while a segment is judged (a window:
  /// the session may span the whole Quran).
  List<(TasmeeState, bool)> _snap = const [];
  static const _window = 3000;

  /// The microphone restarted and no result has come yet.
  bool _restarted = false;

  /// Heard index (absolute) just after the last word that matched.
  int _lastMatch = 0;
  final List<TasmeeMistake> _segMistakes = [];
  final Set<int> _alerted = {};

  /// [consumed] words of the current utterance belong to the previous page,
  /// whose latest transcript is [heard].
  TasmeeSession(this.words, this.mistakes, {int consumed = 0, List<String> heard = const []})
      : _offset = consumed,
        _used = consumed,
        _lastHeard = heard {
    _snapshot();
  }

  /// The latest transcript of the current utterance.
  List<String> get lastHeard => _lastHeard;

  /// Carried into the next page's session within the same utterance.
  int get consumed => _used;

  /// Heard index where the current utterance's own words begin.
  int get utteranceStart => _offset;

  /// Heard words of the current utterance up to the last one that matched
  /// the text: what follows (when it keeps growing) may be a jump elsewhere.
  int get lastMatchHeard => _lastMatch;

  bool get done => expected >= words.length;

  /// Words recited correctly on this page from [from].
  int correctCount([int from = 0]) {
    var c = 0;
    for (var i = from; i < words.length; i++) {
      if (words[i].state == TasmeeState.correct && !words[i].missed) c++;
    }
    return c;
  }

  /// Starts reciting at [index] (words before it are shown as already read).
  void startFrom(int index) {
    expected = index;
    _commit();
  }

  /// The reciter moved elsewhere (found by the locator): the first [keep]
  /// heard words are judged where they were, the words from [from] on from
  /// [index] on (anything between is dropped).
  TasmeeFeed relocate(int index, List<String> heard, {required int keep, required int from, bool isFinal = false}) {
    _restore();
    if (keep > _offset) _align(heard.sublist(0, keep), isFinal: true, alternates: const [], quiet: true);
    _commit();
    expected = index;
    _base = index;
    _offset = from;
    _used = from;
    _lastMatch = from;
    _lastHeard = heard;
    _snapshot();
    return _align(heard, isFinal: isFinal, alternates: const []);
  }

  /// Call when the recogniser starts a new utterance (its text restarts).
  /// The transcript is kept: if the next result simply continues it (the
  /// listening was restarted while the recogniser kept its text), only the
  /// new words are judged; if it starts over, it is detected in [feed].
  void newUtterance() {
    _restarted = true;
    _commit();
    _offset = _lastHeard.length;
    _used = _offset;
    _lastMatch = _offset;
  }

  /// Fixes what was judged so far; later results only judge what follows.
  void _commit() {
    _segMistakes.clear();
    _alerted.clear();
    _base = expected;
    _snapshot();
  }

  void _snapshot() {
    final end = math.min(words.length, _base + _window);
    _snap = [for (var i = _base; i < end; i++) (words[i].state, words[i].missed)];
  }

  void _restore() {
    for (final m in _segMistakes) {
      mistakes.remove(m);
    }
    _segMistakes.clear();
    for (var i = _base; i < _base + _snap.length; i++) {
      final s = _snap[i - _base];
      words[i].state = s.$1;
      words[i].missed = s.$2;
    }
    expected = _base;
  }

  bool _m(String h, int j) => j < words.length && words[j].heardAs(h);

  /// [heard]: all words recognised in the current utterance so far.
  /// [alternates]: other transcripts the recogniser considered.
  TasmeeFeed feed(
    List<String> heard, {
    required bool isFinal,
    List<List<String>> alternates = const [],
  }) {
    // An empty result (sent by some recognisers between sentences) carries
    // nothing; it must not erase the transcript that was judged.
    if (heard.isEmpty) return const TasmeeFeed(0, 0);
    var extra = 0;
    var extraFlash = -1;
    final prev = _lastHeard;

    // Some recognisers start a fresh transcript in the middle of listening
    // (only the latest sentence, e.g. «اعوذ برب الفلق» after the whole of
    // Al-Ikhlas). That is a new segment, not a rewrite of what was judged:
    // settle the previous one and continue from where it reached.
    void settlePrevious() {
      if (prev.length > _offset) {
        final r = _align(prev, isFinal: false, alternates: const []);
        extra += r.mistakes;
        if (r.flash >= 0) extraFlash = r.flash;
      }
      _commit();
      _offset = 0;
      _used = 0;
      _lastMatch = 0;
    }

    var fresh = false;
    if (prev.isNotEmpty) {
      // A rewrite keeps most words in place; a fresh transcript doesn't.
      var same = 0;
      for (var p = 0; p < prev.length && p < heard.length; p++) {
        if (TasmeeMatcher.key(prev[p]) == TasmeeMatcher.key(heard[p])) same++;
      }
      // Right after the microphone restarted, the old text is carried only if
      // it comes back nearly whole (consecutive ayahs often share words at the
      // same places: that is a new ayah, not the old transcript).
      fresh = _restarted ? same * 10 < prev.length * 8 : same * 2 < prev.length;
    }
    if (!fresh && heard.length < _offset) fresh = true;
    _restarted = false;
    if (fresh) settlePrevious();

    final before = expected;
    var r = _align(heard, isFinal: isFinal, alternates: alternates);
    // Never lose what was already recited: a transcript that would move the
    // reciter back is a fresh one, not a correction.
    if (!fresh && prev.isNotEmpty && expected + 2 < before && heard.length + 1 < prev.length) {
      settlePrevious();
      r = _align(heard, isFinal: isFinal, alternates: alternates);
    }
    if (extra == 0) return r;
    return TasmeeFeed(r.revealed, r.mistakes + extra, r.flash >= 0 ? r.flash : extraFlash);
  }

  TasmeeFeed _align(
    List<String> heard, {
    required bool isFinal,
    required List<List<String>> alternates,
    bool quiet = false,
  }) {
    if (!quiet) _lastHeard = heard;
    final before = expected;
    _restore();
    final k = [for (final w in heard) TasmeeMatcher.key(w)];
    // Never past the window kept for undoing (a whole-Quran session).
    final n = math.min(words.length, _base + _snap.length);
    var lastMatch = math.min(_offset, k.length);
    var i = math.min(_offset, k.length);
    var pos = _base;
    int? shadow; // reading position while repeating earlier words
    var newMistakes = 0;
    var flash = -1;

    var matched = false;
    void reveal(int j) {
      words[j].state = TasmeeState.correct;
      matched = true;
    }

    void miss(int j, String said) {
      final w = words[j];
      w.missed = true;
      w.state = TasmeeState.mistake;
      final m = TasmeeMistake(w.surah, w.ayah, w.text, said);
      mistakes.add(m);
      _segMistakes.add(m);
      if (_alerted.add(j)) {
        newMistakes++;
        flash = j;
      }
    }

    while (i < k.length && pos < n) {
      if (matched) {
        lastMatch = i;
        matched = false;
      }
      final h = k[i];
      if (h.isEmpty) {
        i++;
        continue;
      }
      final last = i == k.length - 1 && !isFinal; // still being spoken
      var ni = i + 1;
      while (ni < k.length && k[ni].isEmpty) {
        ni++;
      }
      final hNext = ni < k.length ? k[ni] : null;

      // Repeating earlier words: follow silently until caught up.
      final sh = shadow;
      if (sh != null) {
        if (_m(h, pos)) {
          shadow = null;
        } else if (sh < pos && _m(h, sh)) {
          shadow = sh + 1 >= pos ? null : sh + 1;
          matched = true;
          i++;
          continue;
        } else if (last) {
          break;
        } else {
          shadow = null;
        }
      }

      final e = words[pos];
      // Disjoint letters recited by their names («ألف لام ميم»).
      if (e.spoken != null) {
        final r = _letters(k, i, e, isFinal, atStart: i == _offset);
        if (r > 0) {
          reveal(pos++);
          i += r;
          continue;
        }
        if (r < 0) break;
      }
      // The expected word: alone, split in two, merged with the next one,
      // or in another transcript of the recogniser.
      if (_m(h, pos)) {
        reveal(pos++);
        i++;
        continue;
      }
      if (hNext != null && e.heardAs(h + hNext)) {
        reveal(pos++);
        i = ni + 1;
        continue;
      }
      // Three words written as one (يَبۡنَؤُمَّ ← يا ابن أم).
      if (hNext != null && ni + 1 < k.length && e.key.length >= 4 &&
          e.heardAs(h + hNext + k[ni + 1])) {
        reveal(pos++);
        i = ni + 2;
        continue;
      }
      if (pos + 1 < n && TasmeeMatcher.similar(h, e.key + words[pos + 1].key)) {
        reveal(pos++);
        reveal(pos++);
        i++;
        continue;
      }
      if (!TasmeeMatcher.knownWords.contains(h) && TasmeeMatcher.couldBe(h, e.key) && _inAlternates(alternates, i, e)) {
        reveal(pos++);
        i++;
        continue;
      }
      // Still being spoken: the recogniser often rewrites its last guess,
      // so a word is judged wrong only once the next one is heard (or the
      // reciter pauses) — a correct word is never flashed red by a guess.
      if (last) break;

      // Isti'adha / basmala before an ayah.
      if (TasmeeMatcher.ignorable.contains(h) && (pos == 0 || words[pos - 1].endsAyah)) {
        i++;
        continue;
      }
      // Noise or a self-correction just before the expected word.
      if (hNext != null && _m(hNext, pos)) {
        i++;
        continue;
      }
      // Going back to repeat.
      final j = _findBack(h, hNext, pos);
      if (j != null) {
        shadow = j + 1 >= pos ? null : j + 1;
        matched = true;
        i++;
        continue;
      }
      // Words skipped (by the reciter, or dropped by the recogniser). Right
      // after the microphone restarted, the first words may simply not have
      // been captured: those are not counted.
      final atStart = i == _offset || (lastMatch == _offset && pos == _base);
      final to = _skipTo(h, hNext, pos, isFinal, far: atStart);
      if (to != null) {
        for (var s = pos; s < to; s++) {
          if (!atStart && _countsWhenSkipped(s, to - pos, alternates)) {
            miss(s, '');
          }
          words[s].state = TasmeeState.correct;
        }
        pos = to;
        reveal(pos++);
        i++;
        continue;
      }
      // A one-letter fragment is recogniser noise.
      if (h.length <= 1 && e.key.length > 1) {
        i++;
        continue;
      }
      // A wrong word. If the reciter carried on with the next words, show it
      // in red and move on; otherwise wait for them to say it correctly.
      if (e.state != TasmeeState.mistake) miss(pos, heard[i]);
      if (hNext != null && (_m(hNext, pos + 1) || _m(hNext, pos + 2))) {
        words[pos].state = TasmeeState.correct;
        pos++;
      }
      i++;
    }
    if (matched) lastMatch = i;
    expected = pos;
    _used = i;
    if (!quiet) _lastMatch = lastMatch;
    return TasmeeFeed(math.max(0, expected - before), newMistakes, flash);
  }

  /// Heard words from [i] spelling the disjoint letters of [e]: the count
  /// used, -1 to wait for more, 0 when they don't.
  int _letters(List<String> k, int i, TasmeeWord e, bool isFinal, {required bool atStart}) {
    var acc = '';
    var used = 0;
    for (var j = i; j < k.length && used < 8; j++) {
      used++;
      if (k[j].isEmpty) continue;
      acc += k[j];
      if (TasmeeMatcher.letters(acc, e)) return used;
      // The first letters said before a pause, the rest now.
      if (atStart && acc.length >= 3 && e.spoken!.endsWith(acc)) return used;
    }
    if (acc.isNotEmpty && !isFinal && i + used >= k.length && TasmeeMatcher.lettersPrefix(acc, e)) return -1;
    return 0;
  }

  /// Earlier word the reciter went back to: the word just recited, or one
  /// whose following word is heard next. A wrong word that merely exists
  /// earlier on the page (يشعرون instead of يعلمون) stays a mistake.
  int? _findBack(String h, String? hNext, int pos) {
    if (h.length < 2) return null;
    for (var j = pos - 1; j >= 0 && j >= pos - 40; j--) {
      if (!_m(h, j)) continue;
      if (j == pos - 1) return j;
      if (hNext != null && _m(hNext, j + 1)) return j;
    }
    return null;
  }

  /// Word 1–3 ahead that [h] is, confirmed by the next heard word (or by the
  /// end of speech right after a single dropped word).
  int? _skipTo(String h, String? hNext, int pos, bool isFinal, {bool far = false}) {
    for (var t = pos + 1; t <= pos + (far ? 8 : 3) && t < words.length; t++) {
      if (words[t].key.length < 2 || !_m(h, t)) continue;
      if (hNext != null && (t + 1 >= words.length || _m(hNext, t + 1))) return t;
      if (hNext == null && isFinal && t == pos + 1) return t;
      // A particle (و، في، من، إن…) dropped before a word heard exactly.
      if (t == pos + 1 && TasmeeMatcher.particles.contains(words[pos].key) && h.length >= 3 && h == words[t].key) {
        return t;
      }
    }
    return null;
  }

  /// A skipped word is a mistake (even لا or في: leaving one out changes the
  /// meaning), unless another transcript of the recogniser has it there.
  bool _countsWhenSkipped(int s, int run, List<List<String>> alternates) {
    for (final alt in alternates) {
      for (final w in alt) {
        if (words[s].heardAs(TasmeeMatcher.key(w))) return false;
      }
    }
    return true;
  }

  bool _inAlternates(List<List<String>> alternates, int at, TasmeeWord e) {
    for (final alt in alternates) {
      if (at < alt.length && e.heardAs(TasmeeMatcher.key(alt[at]))) return true;
    }
    return false;
  }

  /// Shows the next word (counts as a hint, not a mistake).
  void hintNext() {
    if (done) return;
    words[expected].state = TasmeeState.hinted;
    expected++;
    _afterHint();
  }

  /// Shows the rest of the current ayah.
  void revealAyah() {
    while (!done) {
      final w = words[expected];
      w.state = TasmeeState.hinted;
      expected++;
      if (w.endsAyah) break;
    }
    _afterHint();
  }

  /// What was said before a hint is settled; listening continues after it.
  void _afterHint() {
    _offset = _lastHeard.length;
    _used = _offset;
    _commit();
  }
}
