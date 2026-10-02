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
  final int mistakes;

  const TasmeeFeed(this.revealed, this.mistakes);
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

  /// Heard [h] counts as expected [e].
  static bool similar(String h, String e) {
    if (h.isEmpty || e.isEmpty) return false;
    if (h == e) return true;
    final tol = e.length <= 2 ? 0 : (e.length <= 5 ? 1 : 2);
    return distance(h, e) <= tol;
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
    if (e.length < 5) return false;
    final tol = e.length <= 7 ? 2 : 3;
    return distance(h, e) <= tol;
  }

  /// Words people say around a recitation (isti'adha, basmala, closing) that
  /// are not part of the tested text.
  static final ignorable = {
    for (final w in 'اعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم صدق العظيم'.split(' ')) key(w),
  };
}

/// Walks the expected words of one page while speech results arrive.
///
/// Forgiving by design:
/// * going back and reciting again (from the start of the surah or a few
///   words back) is followed silently and never counted as a mistake;
/// * the word being spoken right now is shown as soon as it matches, without
///   waiting for the next word or a pause;
/// * small words the recogniser tends to drop (و، في، من…) are not errors.
class TasmeeSession {
  final List<TasmeeWord> words;
  final List<TasmeeMistake> mistakes;
  int expected = 0;

  /// Recognised words already consumed in the current recogniser utterance.
  int _consumed = 0;

  /// While the reciter repeats earlier words: the index they are at.
  int? _shadow;

  /// Letter names heard so far for disjoint letters split across utterances.
  String _pending = '';

  TasmeeSession(this.words, this.mistakes, {int consumed = 0}) : _consumed = consumed;

  /// Carried into the next page's session within the same utterance.
  int get consumed => _consumed;

  bool get done => expected >= words.length;

  /// Call when the recogniser starts a new utterance (its text restarts).
  void newUtterance() => _consumed = 0;

  static bool _sim(String h, TasmeeWord w) => TasmeeMatcher.similar(h, w.key);

  /// [heard]: all words recognised in the current utterance so far.
  TasmeeFeed feed(List<String> heard, {required bool isFinal}) {
    var revealed = 0;
    var errors = 0;
    if (_consumed > heard.length) _consumed = heard.length;
    while (_consumed < heard.length && !done) {
      final last = _consumed == heard.length - 1 && !isFinal; // still being spoken
      final h = TasmeeMatcher.key(heard[_consumed]);
      if (h.isEmpty) {
        _consumed++;
        continue;
      }
      final hNext = _consumed + 1 < heard.length ? TasmeeMatcher.key(heard[_consumed + 1]) : null;

      // 1) Reciting earlier words again.
      final sh = _shadow;
      if (sh != null) {
        if (_sim(h, words[expected])) {
          _shadow = null; // caught up, fall through to the normal match
        } else if (sh < expected && _sim(h, words[sh])) {
          _shadow = sh + 1 >= expected ? null : sh + 1;
          _consumed++;
          continue;
        } else if (last) {
          break;
        } else {
          final j = _findBack(h);
          if (j != null) {
            _shadow = j + 1 >= expected ? null : j + 1;
            _consumed++;
            continue;
          }
          _shadow = null;
        }
      }

      final e = words[expected];
      // 2) The expected word (alone, split in two, or merged with the next).
      if (_sim(h, e) && _pending.isEmpty) {
        _reveal(expected);
        revealed++;
        _consumed++;
        continue;
      }
      if (hNext != null && TasmeeMatcher.similar(h + hNext, e.key)) {
        _reveal(expected);
        revealed++;
        _consumed += 2;
        continue;
      }
      if (expected + 1 < words.length && TasmeeMatcher.similar(h, e.key + words[expected + 1].key)) {
        _reveal(expected);
        _reveal(expected);
        revealed += 2;
        _consumed++;
        continue;
      }
      // Disjoint letters recited by their names: «ألف لام ميم».
      if (e.spoken != null) {
        var acc = _pending;
        var n = 0;
        var matched = false;
        for (var i = _consumed; i < heard.length && n < 8; i++) {
          n++;
          final k = TasmeeMatcher.key(heard[i]);
          if (k.isEmpty) continue;
          acc += k;
          if (TasmeeMatcher.letters(acc, e)) {
            matched = true;
            break;
          }
        }
        if (matched) {
          _reveal(expected);
          revealed++;
          _consumed += n;
          continue;
        }
        if (acc.isNotEmpty && _consumed + n >= heard.length && TasmeeMatcher.lettersPrefix(acc, e)) {
          if (isFinal) {
            _pending = acc; // the rest comes in the next utterance
            _consumed = heard.length;
          }
          break;
        }
        _pending = '';
      }
      // A partial word that doesn't match yet may still be completed.
      if (last) break;

      // 3) Words dropped by the recogniser or skipped by the reciter.
      final skip = _skipTo(h);
      if (skip != null) {
        for (var k = expected; k < skip; k++) {
          final w = words[k];
          if (w.key.length > 3) {
            _miss(w, '');
            errors++;
          }
          w.state = TasmeeState.correct;
        }
        expected = skip;
        _reveal(expected);
        revealed++;
        _consumed++;
        continue;
      }

      // 4) Going back to repeat.
      final j = _findBack(h);
      if (j != null) {
        _shadow = j + 1 >= expected ? null : j + 1;
        _consumed++;
        continue;
      }

      // 5) Isti'adha / basmala before an ayah.
      if (TasmeeMatcher.ignorable.contains(h) && _atAyahStart()) {
        _consumed++;
        continue;
      }

      // 6) Probably misheard: close to the expected word, or the next heard
      //    word is the next expected one.
      final nextOk = hNext != null && expected + 1 < words.length && _sim(hNext, words[expected + 1]);
      if (TasmeeMatcher.close(h, e.key) ||
          (nextOk && TasmeeMatcher.distance(h, e.key) <= math.max(2, e.key.length ~/ 2))) {
        _reveal(expected);
        revealed++;
        _consumed++;
        continue;
      }

      // 7) A wrong word.
      if (e.state != TasmeeState.mistake) {
        _miss(e, heard[_consumed]);
        errors++;
      }
      _consumed++;
    }
    return TasmeeFeed(revealed, errors);
  }

  /// Latest earlier word (this page, last ~40 words) that [h] could be.
  int? _findBack(String h) {
    if (h.length < 2) return null;
    for (var j = expected - 1; j >= 0 && j >= expected - 40; j--) {
      if (_sim(h, words[j])) return j;
    }
    return null;
  }

  /// Index of the word ahead (1–2 words) that [h] matches, if any.
  int? _skipTo(String h) {
    for (var k = expected + 1; k <= expected + 2 && k < words.length; k++) {
      if (words[k].key.length > 2 && _sim(h, words[k])) return k;
    }
    return null;
  }

  bool _atAyahStart() => expected == 0 || words[expected - 1].endsAyah;

  void _reveal(int index) {
    _pending = '';
    words[index].state = TasmeeState.correct;
    expected = index + 1;
  }

  void _miss(TasmeeWord w, String heard) {
    w.missed = true;
    w.state = TasmeeState.mistake;
    mistakes.add(TasmeeMistake(w.surah, w.ayah, w.text, heard));
  }

  /// Shows the next word (counts as a hint, not a mistake).
  void hintNext() {
    if (done) return;
    words[expected].state = TasmeeState.hinted;
    expected++;
    _shadow = null;
    _pending = '';
  }

  /// Shows the rest of the current ayah.
  void revealAyah() {
    while (!done) {
      final w = words[expected];
      w.state = TasmeeState.hinted;
      expected++;
      if (w.endsAyah) break;
    }
    _shadow = null;
    _pending = '';
  }
}
