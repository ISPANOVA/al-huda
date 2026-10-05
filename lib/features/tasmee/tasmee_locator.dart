import 'dart:math' as math;

import 'tasmee_engine.dart';

/// Where the recited words were found.
class TasmeeHit {
  /// Index (in the locator's word list) of the word matching [heardFrom].
  final int index;

  /// Index in the heard words of the first word that matched.
  final int heardFrom;

  /// Heard words that matched the text there.
  final int matched;

  /// No other place fits as well (false: the same words occur elsewhere too
  /// and the nearest place was taken).
  final bool sure;

  const TasmeeHit(this.index, this.heardFrom, this.matched, {this.sure = true});

  @override
  String toString() => 'TasmeeHit($index, from $heardFrom, $matched)';
}

/// Finds where in the Quran (or in one surah) the reciter is, from the words
/// heard so far, so the Tasmee can start wherever they start reciting.
///
/// Every heard word that is rare enough points at the places it occurs; each
/// place is then scored by how many of the heard words follow the text there
/// (tolerating the recogniser's dropped and extra words). A place is taken
/// only when it is clearly better than every other one; a passage that occurs
/// several times (فبأي آلاء ربكما تكذبان) is resolved by the following words,
/// or, when it is long enough to be sure it is one of them, by the place
/// nearest to where the reciter is.
class TasmeeLocator {
  final List<TasmeeWord> words;

  /// The searched range: [from] inclusive to [to] exclusive.
  final int from;
  final int to;

  final Map<String, List<int>> _index = {};

  TasmeeLocator(this.words, {this.from = 0, int? to}) : to = to ?? words.length {
    for (var i = from; i < this.to; i++) {
      final k = words[i].key;
      if (k.isEmpty) continue;
      (_index[k] ??= []).add(i);
    }
    if (from == 0 && this.to == words.length && words.length > 70000) {
      TasmeeMatcher.knownWords = _index.keys.toSet();
    }
  }

  static bool _m(String h, TasmeeWord w) {
    if (w.heardAs(h)) return true;
    final sp = w.spoken;
    return sp != null && (h == w.key || TasmeeMatcher.similar(h, sp));
  }

  /// [heard]: the recognised words (as said, not keys). [near]: index the
  /// reciter is probably close to (the page they opened, their last place),
  /// preferred between equally good places. [avoid]: a range where a hit is
  /// not a move (already the current place).
  TasmeeHit? locate(List<String> heard, {int? near, (int, int)? avoid}) {
    final k = [for (final w in heard) TasmeeMatcher.key(w)];
    // Isti'adha / basmala said before reciting are not part of the place
    // (al-Fatiha's own basmala is found from what follows it). Only the
    // whole formula: «الرحمن» alone begins surat al-Rahman.
    var start = 0;
    var formula = false;
    while (start < k.length && (k[start].isEmpty || TasmeeMatcher.ignorable.contains(k[start]))) {
      if (k[start] == 'بسم' || k[start] == 'عوذ') formula = true;
      start++;
    }
    if (start >= k.length && formula) return null;
    if (!formula) start = 0;
    final idx = [for (var j = start; j < k.length; j++) if (k[j].isNotEmpty) j];
    if (idx.length < 2) return null;

    // Anchors: (word index, heard index) pairs from the rarer heard words.
    // The rarest few of the first heard words are enough: the true place is
    // reached from any word of it.
    final rare = [
      for (final j in idx.take(10))
        if ((_index[k[j]]?.length ?? 0) case final c when c > 0 && c <= 600) (j, c),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final anchors = <(int, int)>[];
    for (final (j, _) in rare.take(4)) {
      for (final p in _index[k[j]]!) {
        anchors.add((p, j));
      }
    }
    if (anchors.isEmpty) {
      // Only very common words so far: try them anyway when they are many.
      if (idx.length < 4) return null;
      for (final j in idx.take(3)) {
        for (final p in _index[k[j]] ?? const <int>[]) {
          anchors.add((p, j));
        }
      }
    }

    // Score each anchor once per resulting start.
    final best = <int, ({int start, int from, int score, int gaps})>{};
    for (final (p, j) in anchors) {
      final r = _score(k, idx, p, j);
      if (r == null) continue;
      final old = best[r.start];
      if (old == null || r.score > old.score || (r.score == old.score && r.gaps < old.gaps)) best[r.start] = r;
    }
    if (best.isEmpty) return null;
    final ranked = best.values.toList()
      ..sort((a, b) {
        final c = b.score.compareTo(a.score);
        if (c != 0) return c;
        final g = a.gaps.compareTo(b.gaps);
        if (g != 0) return g;
        if (near == null) return a.start.compareTo(b.start);
        return (a.start - near).abs().compareTo((b.start - near).abs());
      });
    final top = ranked.first;
    // Enough of what was heard (from the first match) must follow the text.
    final heardSpan = idx.where((j) => j >= top.from).length;
    if (top.score < 2 || top.score * 10 < heardSpan * 6) return null;

    // The best other place (not just the same place shifted by a word).
    var second = 0;
    var tied = <({int start, int from, int score, int gaps})>[];
    for (final r in ranked.skip(1)) {
      if ((r.start - top.start).abs() <= 3) continue;
      if (r.score == top.score && r.gaps == top.gaps) tied.add(r);
      second = math.max(second, r.score);
    }
    var pick = top;
    var sure = true;
    if (second >= top.score) {
      sure = false;
      // The same words in several places: sure only once the passage is long
      // (then it doesn't matter which one until the words differ).
      if (top.score < 5) return null;
      if (near != null) {
        for (final r in tied) {
          if ((r.start - near).abs() < (pick.start - near).abs()) pick = r;
        }
      }
    } else {
      final distinct = _letters(k, idx, top.from, top.score);
      if (top.score == 2 && (second > 0 || distinct < 8)) return null;
      if (top.score == 3 && second >= 2 && distinct < 10) return null;
    }
    if (avoid != null && pick.start >= avoid.$1 && pick.start <= avoid.$2) return null;
    return TasmeeHit(pick.start, pick.from, pick.score, sure: sure);
  }

  /// Letters in the [n] heard words from [from]: two long distinctive words
  /// are enough to be sure, two short ones are not.
  static int _letters(List<String> k, List<int> idx, int from, int n) {
    var sum = 0;
    var c = 0;
    for (final j in idx) {
      if (j < from) continue;
      if (c++ >= n) break;
      sum += k[j].length;
    }
    return sum;
  }

  /// Greedy alignment of the heard words around anchor ([p] ↔ heard [j]).
  ({int start, int from, int score, int gaps})? _score(List<String> k, List<int> idx, int p, int j) {
    final at = idx.indexOf(j);
    if (at < 0) return null;
    var score = 1;
    var gaps = 0;
    // Forward.
    var e = p + 1;
    var h = at + 1;
    while (h < idx.length && e < to) {
      final hk = k[idx[h]];
      if (_m(hk, words[e])) {
        score++;
        e++;
        h++;
      } else if (e + 1 < to && _m(hk, words[e + 1])) {
        // A word the recogniser dropped.
        score++;
        gaps++;
        e += 2;
        h++;
      } else if (h + 1 < idx.length && TasmeeMatcher.similar(hk + k[idx[h + 1]], words[e].key)) {
        // One word heard as two.
        score++;
        e++;
        h += 2;
      } else if (h + 1 < idx.length && _m(k[idx[h + 1]], words[e])) {
        // An extra word heard.
        gaps++;
        h++;
      } else {
        gaps += 2;
        e++;
        h++;
      }
    }
    // Backward to the first heard word.
    var s = p;
    var first = j;
    e = p - 1;
    h = at - 1;
    while (h >= 0 && e >= from) {
      final hk = k[idx[h]];
      // Disjoint letters said by their names over several words (ألف لام ميم).
      if (words[e].spoken != null) {
        var n = 0;
        var acc = '';
        for (var m = 1; m <= 6 && h - m + 1 >= 0; m++) {
          acc = k[idx[h - m + 1]] + acc;
          if (TasmeeMatcher.letters(acc, words[e])) n = m;
        }
        if (n > 0) {
          score++;
          s = e;
          first = idx[h - n + 1];
          e--;
          h -= n;
          continue;
        }
      }
      if (_m(hk, words[e])) {
        score++;
        s = e;
        first = idx[h];
        e--;
        h--;
      } else if (e - 1 >= from && _m(hk, words[e - 1])) {
        score++;
        gaps++;
        s = e - 1;
        first = idx[h];
        e -= 2;
        h--;
      } else {
        gaps += 2;
        h--;
      }
    }
    return (start: s, from: first, score: score, gaps: gaps);
  }
}

/// A Tasmee over a range of the Quran (all of it, or one surah) that starts
/// wherever the reciter starts and follows them: the place is found from the
/// first words recited, and found again when, after a pause, they go on from
/// another ayah. Words recited stay shown wherever the reciter goes.
class TasmeeTracker {
  final List<TasmeeWord> words;
  final List<TasmeeMistake> mistakes;
  late final TasmeeSession session = TasmeeSession(words, mistakes);

  int _from;
  int _to;
  late TasmeeLocator _locator;

  /// The place is known (found, or chosen by the reciter).
  bool located = false;

  /// Where the reciter probably is before anything is found (the page they
  /// opened): preferred between equal places.
  int? near;

  TasmeeTracker(this.words, this.mistakes, {int from = 0, int? to, this.near})
      : _from = from,
        _to = to ?? words.length {
    _locator = TasmeeLocator(words, from: _from, to: _to);
  }

  int get from => _from;
  int get to => _to;
  int get expected => session.expected;
  bool get done => located && session.expected >= _to;

  /// Searches another range from now on (a chosen surah, or all).
  void setScope(int from, int to) {
    _from = from;
    _to = to;
    _locator = TasmeeLocator(words, from: from, to: to);
    located = false;
    session.newUtterance();
  }

  /// Starts at [index] (chosen by the reciter): words before it on the same
  /// page ([pageStart]) are shown as already read.
  void startAt(int index, {int? pageStart}) {
    _sure = true;
    if (pageStart != null) {
      for (var i = pageStart; i < index; i++) {
        if (words[i].state == TasmeeState.hidden) words[i].state = TasmeeState.given;
      }
    }
    session.startFrom(index);
    located = true;
  }

  /// The place found is the only one that fits (see [TasmeeHit.sure]).
  bool _sure = true;

  /// The reciter turned the microphone on themselves: they may start
  /// anywhere (another surah, the middle of an ayah).
  bool _anywhere = false;

  void newUtterance({bool manual = false}) {
    _sure = true;
    if (manual) _anywhere = true;
    session.newUtterance();
  }

  bool _ayahStart(int i) => i <= 0 || words[i - 1].endsAyah;

  /// Moves to [index]. Al-Fatiha's basmala is its first ayah: said before
  /// «الحمد لله», it is recited from it; not said, it is shown (not missed).
  TasmeeFeed _place(int index, List<String> heard, {required int keep, required int from, required bool isFinal}) {
    final w = words[index];
    if (w.surah == 1 && w.ayah == 2 && index > 0 && words[index - 1].ayah == 1) {
      var start = index;
      while (start > 0 && words[start - 1].surah == 1 && words[start - 1].ayah == 1) {
        start--;
      }
      var said = -1;
      for (var j = from - 1; j >= keep; j--) {
        if (TasmeeMatcher.key(heard[j]) == 'بسم') {
          said = j;
          break;
        }
      }
      if (said >= 0) {
        index = start;
        from = said;
      } else {
        for (var i = start; i < index; i++) {
          if (words[i].state == TasmeeState.hidden) words[i].state = TasmeeState.given;
        }
      }
    }
    return session.relocate(index, heard, keep: keep, from: from, isFinal: isFinal);
  }

  /// [h] is the expected word (or its beginning, while [partial]), one of
  /// the next few, or a word just recited (a repeat).
  bool _nearExpected(String h, {required bool partial}) {
    final e = session.expected;
    if (e < words.length) {
      final k = words[e].key;
      if (partial && h.length < k.length && TasmeeMatcher.similar(h, k.substring(0, h.length))) return true;
      if (words[e].spoken != null) return true;
    }
    // A short word (لم، من، في) is everywhere: only right here counts.
    final back = h.length <= 2 ? 2 : 40;
    for (var j = math.max(_from, e - back); j < math.min(_to, e + (h.length <= 2 ? 2 : 4)); j++) {
      if (words[j].heardAs(h)) return true;
    }
    return false;
  }

  TasmeeFeed feed(List<String> heard, {required bool isFinal, List<List<String>> alternates = const []}) {
    if (heard.isEmpty) return const TasmeeFeed(0, 0);
    if (!located) {
      final hit = _locator.locate(heard, near: near);
      if (hit == null) return const TasmeeFeed(0, 0);
      located = true;
      _sure = hit.sure;
      return _place(hit.index, heard, keep: 0, from: hit.heardFrom, isFinal: isFinal);
    }
    if (!_sure) {
      // Found among places with the same words: the words that follow tell
      // which one, while this utterance goes on.
      final hit = _locator.locate(heard, near: session.expected);
      if (hit != null && hit.sure) {
        _sure = true;
        return _place(hit.index, heard, keep: 0, from: hit.heardFrom, isFinal: isFinal);
      }
    }
    // A new utterance that doesn't begin with the expected words (nor a
    // repeat of what came just before): wait for a third word before judging,
    // it may be another ayah the reciter moved to.
    if (!isFinal && session.lastMatchHeard == session.utteranceStart) {
      final start = [
        for (final w in heard.skip(session.utteranceStart))
          if (TasmeeMatcher.key(w) case final k when k.isNotEmpty && !TasmeeMatcher.ignorable.contains(k)) k,
      ];
      final waitHere = _anywhere ? !(session.expected < words.length && words[session.expected].heardAs(start.firstOrNull ?? '')) : !_nearExpected(start.firstOrNull ?? '', partial: start.length == 1);
      if (start.isNotEmpty && start.length < 3 && waitHere) {
        return const TasmeeFeed(0, 0);
      }
    }
    final before = session.expected;
    final r = session.feed(heard, isFinal: isFinal, alternates: alternates);
    if (session.expected != before) _anywhere = false;
    // Nothing of this utterance matched the text here, yet it goes on: the
    // reciter may have continued from another ayah after a pause. Only then
    // (not in the middle of reciting, where landing on a similar ayah is the
    // very mistake the Tasmee must catch) and only at an ayah's beginning.
    final keep = session.lastMatchHeard;
    if (session.expected != before || keep != session.utteranceStart) return r;
    final tail = heard.sublist(keep);
    var count = 0;
    for (final w in tail) {
      final k = TasmeeMatcher.key(w);
      if (k.isNotEmpty && !TasmeeMatcher.ignorable.contains(k)) count++;
    }
    if (count < 3) return r;
    final e = session.expected;
    final hit = _locator.locate(tail, near: e, avoid: (e - 40, e + 3));
    if (hit == null || hit.matched < 3 || !hit.sure) return r;
    // In the middle of an ayah only when clearly elsewhere: after the reciter
    // turned the microphone on, in another surah, or a long passage.
    final elsewhere = _anywhere || words[hit.index].surah != words[math.min(e, words.length - 1)].surah;
    if (!_ayahStart(hit.index) && hit.matched < (elsewhere ? 4 : 8)) return r;
    _anywhere = false;
    final moved = _place(hit.index, heard, keep: keep, from: keep + hit.heardFrom, isFinal: isFinal);
    return TasmeeFeed(moved.revealed, moved.mistakes, moved.flash);
  }
}
