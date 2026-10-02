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

  TasmeeWord({required this.surah, required this.ayah, required this.text, required this.endsAyah})
      : key = TasmeeMatcher.key(text);

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
      if (_sim(h, e)) {
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

      // 6) A wrong word.
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
  }
}
