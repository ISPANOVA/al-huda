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
class TasmeeSession {
  final List<TasmeeWord> words;
  final List<TasmeeMistake> mistakes;
  int expected = 0;

  /// Recognised words already consumed in the current recogniser session.
  int _consumed = 0;

  TasmeeSession(this.words, this.mistakes, {int consumed = 0}) : _consumed = consumed;

  /// Carried into the next page's session within the same utterance.
  int get consumed => _consumed;

  bool get done => expected >= words.length;

  /// Call when the recogniser starts a new utterance (its text restarts).
  void newUtterance() => _consumed = 0;

  /// [heard]: all words recognised in the current utterance so far.
  TasmeeFeed feed(List<String> heard, {required bool isFinal}) {
    var revealed = 0;
    var errors = 0;
    final limit = isFinal ? heard.length : heard.length - 1; // last partial word may still change
    if (_consumed > heard.length) _consumed = heard.length;
    while (_consumed < limit && !done) {
      final h = TasmeeMatcher.key(heard[_consumed]);
      if (h.isEmpty) {
        _consumed++;
        continue;
      }
      final e = words[expected];
      final next = expected + 1 < words.length ? words[expected + 1] : null;
      final hNext = _consumed + 1 < limit ? TasmeeMatcher.key(heard[_consumed + 1]) : null;

      if (TasmeeMatcher.similar(h, e.key)) {
        _reveal(e);
        revealed++;
        _consumed++;
      } else if (hNext != null && TasmeeMatcher.similar(h + hNext, e.key)) {
        _reveal(e);
        revealed++;
        _consumed += 2;
      } else if (next != null && TasmeeMatcher.similar(h, e.key + next.key)) {
        _reveal(e);
        _reveal(next);
        revealed += 2;
        _consumed++;
      } else if (next != null && TasmeeMatcher.similar(h, next.key) && next.key.length > 2) {
        // The expected word was skipped.
        _miss(e, '');
        errors++;
        e.state = TasmeeState.correct;
        expected++;
        _reveal(next);
        revealed++;
        _consumed++;
      } else if (TasmeeMatcher.ignorable.contains(h) && _atAyahStart()) {
        _consumed++;
      } else {
        if (e.state != TasmeeState.mistake) {
          _miss(e, heard[_consumed]);
          errors++;
        }
        _consumed++;
      }
    }
    return TasmeeFeed(revealed, errors);
  }

  bool _atAyahStart() => expected == 0 || words[expected - 1].endsAyah;

  void _reveal(TasmeeWord w) {
    w.state = TasmeeState.correct;
    if (identical(w, words[expected])) {
      expected++;
    } else {
      expected = words.indexOf(w) + 1;
    }
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
  }

  /// Shows the rest of the current ayah.
  void revealAyah() {
    while (!done) {
      final w = words[expected];
      w.state = TasmeeState.hinted;
      expected++;
      if (w.endsAyah) break;
    }
  }
}
