import 'dart:math' as math;

/// State of one word of the Mushaf during a recitation test (تسميع).
enum TasmeeState { hidden, correct, hinted, mistake }

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

  /// For the disjoint letters (الم، كهيعص…): the key of how they are recited,
  /// letter by letter («ألف لام ميم»). Null for every other word.
  final String? spoken;

  TasmeeWord({required this.surah, required this.ayah, required this.text, required this.endsAyah})
      : key = TasmeeMatcher.key(text),
        spoken = TasmeeMatcher.spokenLetters(surah, ayah, text);

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

  /// Letters only: no diacritics / Quranic marks, unified hamza & alef forms,
  /// and long-alef dropped (Uthmani often omits it: ٱلْكِتَٰبُ ≈ الكتاب).
  static String key(String s) {
    var k = s.replaceAll(_marks, '');
    k = k
        .replaceAll(RegExp('[ٱأإآٲٳ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ئ', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ة', 'ه')
        .replaceAll('ء', '');
    k = k.replaceAll(_nonLetters, '');
    return k.replaceAll('ا', '');
  }

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

  /// Heard [h] counts as expected [e].
  static bool similar(String h, String e) {
    if (h.isEmpty || e.isEmpty) return false;
    if (h == e) return true;
    // A leading و / ف the recogniser dropped or added.
    if (e.length >= 3 && (e[0] == 'و' || e[0] == 'ف') && h == e.substring(1)) return true;
    if (h.length >= 3 && (h[0] == 'و' || h[0] == 'ف') && e == h.substring(1)) return true;
    // Strict enough that a different Quranic word (يعلمون/يشعرون، يعلمون/يعملون)
    // is never accepted, loose enough for Uthmani vs plain spelling and for
    // letters the recogniser mishears.
    final tol = e.length <= 2 ? 0 : (e.length <= 6 ? 1 : 2);
    return soundDistance(h, e) <= tol;
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
  static bool letters(String acc, TasmeeWord w) =>
      acc == w.key || similar(acc, w.spoken!);

  /// [acc] could still grow into the disjoint letters of [w].
  static bool lettersPrefix(String acc, TasmeeWord w) {
    final sp = w.spoken!;
    if (sp.startsWith(acc) || w.key.startsWith(acc)) return true;
    if (acc.length < 3 || acc.length >= sp.length) return false;
    return distance(acc, sp.substring(0, acc.length)) <= 1;
  }

  /// A looser match used when the recogniser probably misheard a correct word.
  static bool close(String h, String e) {
    if (similar(h, e)) return true;
    return e.length >= 8 && distance(h, e) <= 3;
  }

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
  List<(TasmeeState, bool)> _snap = const [];
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

  /// Call when the recogniser starts a new utterance (its text restarts).
  /// The transcript is kept: if the next result simply continues it (the
  /// listening was restarted while the recogniser kept its text), only the
  /// new words are judged; if it starts over, it is detected in [feed].
  void newUtterance() {
    _commit();
    _offset = _lastHeard.length;
    _used = _offset;
  }

  /// Fixes what was judged so far; later results only judge what follows.
  void _commit() {
    _segMistakes.clear();
    _alerted.clear();
    _base = expected;
    _snapshot();
  }

  void _snapshot() {
    _snap = [for (var i = _base; i < words.length; i++) (words[i].state, words[i].missed)];
  }

  void _restore() {
    for (final m in _segMistakes) {
      mistakes.remove(m);
    }
    _segMistakes.clear();
    for (var i = _base; i < words.length; i++) {
      final s = _snap[i - _base];
      words[i].state = s.$1;
      words[i].missed = s.$2;
    }
    expected = _base;
  }

  bool _m(String h, int j) => j < words.length && TasmeeMatcher.similar(h, words[j].key);

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
    }

    var fresh = false;
    if (prev.isNotEmpty) {
      // A rewrite keeps most words in place; a fresh transcript doesn't.
      var same = 0;
      for (var p = 0; p < prev.length && p < heard.length; p++) {
        if (TasmeeMatcher.key(prev[p]) == TasmeeMatcher.key(heard[p])) same++;
      }
      fresh = same * 2 < prev.length;
    }
    if (!fresh && heard.length < _offset) fresh = true;
    if (fresh) settlePrevious();

    final before = expected;
    var r = _align(heard, isFinal: isFinal, alternates: alternates);
    // Never lose what was already recited: a transcript that would move the
    // reciter back is a fresh one, not a correction.
    if (!fresh && prev.isNotEmpty && expected + 2 < before) {
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
  }) {
    _lastHeard = heard;
    final before = expected;
    _restore();
    final k = [for (final w in heard) TasmeeMatcher.key(w)];
    final n = words.length;
    var i = math.min(_offset, k.length);
    var pos = _base;
    int? shadow; // reading position while repeating earlier words
    var newMistakes = 0;
    var flash = -1;

    void reveal(int j) => words[j].state = TasmeeState.correct;
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
      if (hNext != null && TasmeeMatcher.similar(h + hNext, e.key)) {
        reveal(pos++);
        i = ni + 1;
        continue;
      }
      if (pos + 1 < n && TasmeeMatcher.similar(h, e.key + words[pos + 1].key)) {
        reveal(pos++);
        reveal(pos++);
        i++;
        continue;
      }
      if (_inAlternates(alternates, i, e)) {
        reveal(pos++);
        i++;
        continue;
      }
      // Still being spoken: wait, unless it is clearly another word (not the
      // beginning of the expected one, nor a nearby word) — then say so now.
      if (last) {
        if (_clearlyWrong(h, pos)) {
          if (e.state != TasmeeState.mistake) miss(pos, heard[i]);
          i++;
        }
        break;
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
        i++;
        continue;
      }
      // Words skipped (by the reciter, or dropped by the recogniser).
      final to = _skipTo(h, hNext, pos, isFinal);
      if (to != null) {
        for (var s = pos; s < to; s++) {
          if (words[s].key.length > 3) {
            miss(s, '');
          }
          words[s].state = TasmeeState.correct;
        }
        pos = to;
        reveal(pos++);
        i++;
        continue;
      }
      // Isti'adha / basmala before an ayah.
      if (TasmeeMatcher.ignorable.contains(h) && (pos == 0 || words[pos - 1].endsAyah)) {
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
    expected = pos;
    _used = i;
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

  /// [h] (still being spoken) can't become the expected word or a word the
  /// reciter may be skipping to or repeating.
  bool _clearlyWrong(String h, int pos) {
    if (h.length < 3) return false;
    final e = words[pos].key;
    final head = e.length > h.length ? e.substring(0, h.length) : e;
    if (TasmeeMatcher.similar(h, head) || TasmeeMatcher.similar(h, e)) return false;
    if (TasmeeMatcher.ignorable.contains(h)) return false;
    for (var j = math.max(0, pos - 40); j < math.min(words.length, pos + 4); j++) {
      final k = words[j].key;
      final kh = k.length > h.length ? k.substring(0, h.length) : k;
      if (TasmeeMatcher.similar(h, kh)) return false;
    }
    return true;
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
  int? _skipTo(String h, String? hNext, int pos, bool isFinal) {
    for (var t = pos + 1; t <= pos + 3 && t < words.length; t++) {
      if (words[t].key.length < 2 || !_m(h, t)) continue;
      if (hNext != null && (t + 1 >= words.length || _m(hNext, t + 1))) return t;
      if (hNext == null && isFinal && t == pos + 1) return t;
    }
    return null;
  }

  bool _inAlternates(List<List<String>> alternates, int at, TasmeeWord e) {
    for (final alt in alternates) {
      if (at < alt.length && TasmeeMatcher.similar(TasmeeMatcher.key(alt[at]), e.key)) return true;
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
