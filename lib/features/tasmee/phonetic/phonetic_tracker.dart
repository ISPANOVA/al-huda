import 'dart:math' as math;
import 'dart:typed_data';

import '../tasmee_engine.dart';
import '../tasmee_follower.dart';
import 'phonetic_text.dart';

/// One word's part of an alignment of what was heard with the text.
class _WordSpan {
  /// Heard range (normalized string, from the alignment's start).
  int hStart = -1;
  int hEnd = -1;
  double cost = 0;

  /// The alignment went past the end of this word.
  bool complete = false;

  /// Characters heard exactly as written in this word.
  int exact = 0;
}

class _Alignment {
  /// First word of the window (index in the Mushaf).
  final int first;
  final List<_WordSpan> spans;

  /// Word where the path begins (a repeat starts before the expected word).
  final int startWord;
  final double cost;

  /// Heard characters used (all of them: the path consumes the heard text).
  final int heard;

  _Alignment(this.first, this.spans, this.startWord, this.cost, this.heard);
}

/// Where a passage was found.
class PhoneticHit {
  final int word;

  /// Normalized heard index where the passage starts.
  final int heardFrom;
  final double costPerChar;
  final bool sure;

  const PhoneticHit(this.word, this.heardFrom, this.costPerChar, {this.sure = true});

  @override
  String toString() => 'PhoneticHit($word, from $heardFrom, ${costPerChar.toStringAsFixed(2)}, sure: $sure)';
}

/// The text of the Mushaf in the phonetic script, word by word, with an index
/// to find any passage from a few heard words.
class PhoneticQuran {
  /// Normalized phonemes of each word (empty: read with its neighbour).
  final List<String> ph;

  /// The word begins with a hamzat wasl at the start of an ayah: said when
  /// starting there, silent when the previous ayah is joined to it.
  final List<bool> waslStart;

  /// Last word of an ayah: its ending changes when the reciter joins it to
  /// the next ayah instead of stopping.
  final List<bool> ayahEnd;

  /// How a word may change when the reciter stops on it or starts from it
  /// (وقف وابتداء), which the table (read joined) doesn't show:
  /// [tanween]: its ending «ن» is dropped (or becomes a long «ا»);
  /// [taMarbuta]: its ending «ت» is read «ه»;
  /// [hamzatWasl]: it begins with a hamzat wasl, said when starting on it.
  final List<bool> tanween;
  final List<bool> taMarbuta;
  final List<bool> hamzatWasl;

  PhoneticQuran(this.ph, this.waslStart, this.ayahEnd, {List<bool>? tanween, List<bool>? taMarbuta, List<bool>? hamzatWasl})
      : tanween = tanween ?? List<bool>.filled(ph.length, false),
        taMarbuta = taMarbuta ?? List<bool>.filled(ph.length, false),
        hamzatWasl = hamzatWasl ?? List<bool>.filled(ph.length, false);

  static final _tanween = RegExp('[\u064B-\u064D\u08F0-\u08F2]');
  static final _marks = RegExp('[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u08F0-\u08F2]');

  /// From assets/tasmee/phonemes.txt ([lines]: one per ayah, one item per
  /// word) for the Mushaf's [words] in page order. [global]: the global
  /// number of an ayah.
  factory PhoneticQuran.build(List<TasmeeWord> words, List<String> lines, int Function(int surah, int ayah) global) {
    final ph = List<String>.filled(words.length, '');
    final wasl = List<bool>.filled(words.length, false);
    final end = List<bool>.filled(words.length, false);
    final tanween = List<bool>.filled(words.length, false);
    final ta = List<bool>.filled(words.length, false);
    final hamza = List<bool>.filled(words.length, false);
    var lastAyah = -1;
    var k = 0;
    List<String> items = const [];
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      final g = global(w.surah, w.ayah);
      if (g != lastAyah) {
        lastAyah = g;
        k = 0;
        items = g - 1 < lines.length ? lines[g - 1].trim().split(' ') : const [];
        wasl[i] = w.text.startsWith('ٱ');
      }
      final item = k < items.length ? items[k] : '';
      ph[i] = item == '-' ? '' : PhoneticText.normalize(item);
      end[i] = w.endsAyah;
      tanween[i] = _tanween.hasMatch(w.text);
      ta[i] = w.text.replaceAll(_marks, '').endsWith('ة');
      hamza[i] = w.text.startsWith('ٱ');
      k++;
    }
    return PhoneticQuran(ph, wasl, end, tanween: tanween, taMarbuta: ta, hamzatWasl: hamza);
  }

  // Index of consonant trigrams over the whole text.
  Int32List? _skel; // consonant codes
  Int32List? _skelWord; // word of each consonant
  Int32List? _keyStart; // offsets into _keyPos, by trigram key
  Int32List? _keyPos;

  static const _base = 64;
  static final Map<int, int> _alphabet = {};
  static int _code(int c) => _alphabet.putIfAbsent(c, () => _alphabet.length % (_base - 1) + 1);

  void _buildIndex() {
    if (_skel != null) return;
    var n = 0;
    for (final w in ph) {
      for (final c in w.codeUnits) {
        if (!PhoneticText.isVowel(c)) n++;
      }
    }
    final skel = Int32List(n);
    final skelWord = Int32List(n);
    var k = 0;
    for (var i = 0; i < ph.length; i++) {
      for (final c in ph[i].codeUnits) {
        if (PhoneticText.isVowel(c)) continue;
        skel[k] = _code(c);
        skelWord[k] = i;
        k++;
      }
    }
    const keys = _base * _base * _base;
    final count = Int32List(keys + 1);
    for (var i = 0; i + 2 < n; i++) {
      count[_key(skel, i) + 1]++;
    }
    for (var i = 1; i <= keys; i++) {
      count[i] += count[i - 1];
    }
    final pos = Int32List(math.max(0, n - 2));
    final fill = Int32List.fromList(count);
    for (var i = 0; i + 2 < n; i++) {
      pos[fill[_key(skel, i)]++] = i;
    }
    _skel = skel;
    _skelWord = skelWord;
    _keyStart = count;
    _keyPos = pos;
  }

  /// Builds the passage index ahead of the first search.
  void warmUp() => _buildIndex();

  static int _key(Int32List s, int i) => (s[i] * _base + s[i + 1]) * _base + s[i + 2];

  /// Candidate words where the heard consonants [q] could begin, best first.
  List<int> candidates(String q, {required int from, required int to, int max = 14}) {
    _buildIndex();
    final codes = [for (final c in q.codeUnits) _code(c)];
    if (codes.length < 3) return const [];
    final votes = <int, int>{};
    final starts = _keyStart!;
    final pos = _keyPos!;
    final skelWord = _skelWord!;
    for (var i = 0; i + 2 < codes.length; i++) {
      final key = (codes[i] * _base + codes[i + 1]) * _base + codes[i + 2];
      final a = starts[key], b = starts[key + 1];
      if (b - a > 6000) continue; // too common to tell anything
      for (var j = a; j < b; j++) {
        final p = pos[j];
        final w = skelWord[p];
        if (w < from || w >= to) continue;
        final diag = (p - i) ~/ 4;
        votes[diag] = (votes[diag] ?? 0) + 1;
      }
    }
    final ranked = votes.entries.where((e) => e.value >= 2).toList()..sort((a, b) => b.value.compareTo(a.value));
    final out = <int>[];
    for (final e in ranked) {
      final p = (e.key * 4).clamp(0, skelWord.length - 1);
      final w = skelWord[p];
      if (out.any((o) => (o - w).abs() <= 2)) continue;
      out.add(w);
      if (out.length >= max) break;
    }
    return out;
  }
}

/// Follows a recitation through the phonemes heard by the on-device model.
///
/// What was heard since the last judged word is aligned with the text from
/// the expected word (or a few words before it, when the reciter goes back to
/// repeat). A word is judged once the reciter has moved on to the next one
/// (or paused after it): right if its letters and harakat were heard, a
/// mistake if a letter is wrong, missing or added, or if it was skipped.
class PhoneticTracker implements TasmeeFollower {
  @override
  final List<TasmeeWord> words;
  final PhoneticQuran quran;
  final List<TasmeeMistake> mistakes;

  /// Phonemes of the isti'adha and the basmala (said before reciting).
  final List<String> openings;

  /// A word is wrong from this cost (one wrong letter, or two harakat).
  final double threshold;

  PhoneticTracker(
    this.words,
    this.quran,
    this.mistakes, {
    this.openings = const [],
    this.threshold = 1.0,
    int from = 0,
    int? to,
    this.near,
  })  : _from = from,
        _to = to ?? words.length;

  int _from;
  int _to;

  @override
  int? near;

  @override
  bool located = false;

  bool _sure = true;

  int _expected = 0;

  /// Normalized text of the current utterance and how much was used.
  String _heard = '';
  int _cut = 0;

  /// Index in [_heard] where the utterance's speech starts (after an
  /// isti'adha / basmala).
  int _speechStart = 0;
  bool _openingChecked = false;

  @override
  int get from => _from;
  @override
  int get to => _to;
  @override
  int get expected => _expected;
  @override
  bool get done => located && _expected >= _to;

  /// What was heard in the current utterance (readable).
  String get heardText => PhoneticText.readable(_heard);

  @override
  void setScope(int from, int to) {
    _from = from;
    _to = to;
    located = false;
    newUtterance();
  }

  @override
  void startAt(int index, {int? pageStart}) {
    _sure = true;
    if (pageStart != null) {
      for (var i = pageStart; i < index; i++) {
        if (words[i].state == TasmeeState.hidden) words[i].state = TasmeeState.given;
      }
    }
    _expected = index;
    located = true;
    _cut = _heard.length;
  }

  @override
  void newUtterance({bool manual = false}) {
    _heard = '';
    _cut = 0;
    _speechStart = 0;
    _openingChecked = false;
  }

  @override
  void hintNext() {
    if (done) return;
    words[_expected].state = TasmeeState.hinted;
    _expected++;
    _cut = _heard.length;
  }

  @override
  void revealAyah() {
    while (!done) {
      final w = words[_expected];
      w.state = TasmeeState.hinted;
      _expected++;
      if (w.endsAyah) break;
    }
    _cut = _heard.length;
  }

  // ------------------------------------------------------------ feeding ---

  /// [raw]: everything the model heard in the current utterance (it only
  /// grows until [newUtterance]). [isFinal]: the reciter paused.
  TasmeeFeed feed(String raw, {required bool isFinal}) {
    final h = PhoneticText.normalize(raw);
    if (h.length < _heard.length && !_heard.startsWith(h)) {
      // The recogniser started over without telling.
      newUtterance();
    }
    _heard = h;
    if (_cut > h.length) _cut = h.length;
    if (!_openingChecked) {
      final skip = _opening(h, isFinal);
      if (skip == null) return const TasmeeFeed(0, 0);
      _openingChecked = true;
      _speechStart = skip;
      if (_cut < skip) _cut = skip;
    }
    if (!located) {
      final hit = locate(h.substring(_cut), near: near);
      if (hit == null) return const TasmeeFeed(0, 0);
      _sure = hit.sure;
      located = true;
      _placeAt(hit.word, _cut + hit.heardFrom);
    } else if (!_sure) {
      // Found among places with the same words: what follows tells which.
      final hit = locate(h.substring(_speechStart), near: _expected);
      if (hit != null && hit.sure) {
        _sure = true;
        _restoreFrom(_speechStart);
        _placeAt(hit.word, _speechStart + hit.heardFrom);
      }
    }
    return _follow(isFinal);
  }

  /// Words judged since [index] in the current utterance are undone (the
  /// place was taken among equal ones and turned out to be another).
  void _restoreFrom(int index) {
    // Judgements are kept: the passage was the same words.
  }

  void _placeAt(int word, int heardIndex) {
    // Al-Fatiha's basmala is its first ayah: said, it is recited; not said,
    // it is shown as given.
    var w = word;
    if (words[w].surah == 1 && words[w].ayah == 2 && w > 0 && words[w - 1].surah == 1) {
      var start = w;
      while (start > 0 && words[start - 1].surah == 1 && words[start - 1].ayah == 1) {
        start--;
      }
      for (var i = start; i < w; i++) {
        if (words[i].state == TasmeeState.hidden) {
          words[i].state = _saidBasmala ? TasmeeState.correct : TasmeeState.given;
        }
      }
    }
    _expected = w;
    _cut = heardIndex;
  }

  bool _saidBasmala = false;

  /// Isti'adha and basmala at the start of an utterance: where the recited
  /// text begins, or null while it may still be one of them.
  int? _opening(String h, bool isFinal) {
    _saidBasmala = false;
    var at = 0;
    for (var round = 0; round < 2; round++) {
      var found = false;
      for (var o = 0; o < openings.length; o++) {
        final p = openings[o];
        if (p.isEmpty) continue;
        final rest = h.substring(at);
        // Expecting Al-Fatiha's first ayah: its basmala is the text itself.
        if (o == 1 && located && _expected < words.length && words[_expected].surah == 1 && words[_expected].ayah == 1) {
          continue;
        }
        final end = _prefixMatch(p, rest);
        if (end != null) {
          at += end;
          if (o == 1) _saidBasmala = true;
          found = true;
          break;
        }
        // Could still become it.
        if (!isFinal && rest.length < p.length + 3 && _couldStart(p, rest)) return null;
      }
      if (!found) break;
    }
    return at;
  }

  static bool _couldStart(String p, String rest) {
    if (rest.isEmpty) return true;
    final n = math.min(rest.length, p.length);
    final a = _align(rest.substring(0, n), p.substring(0, n));
    return a <= n * 0.3;
  }

  /// [p] fully at the start of [h]: the heard length it takes.
  static int? _prefixMatch(String p, String h) {
    if (h.length < p.length * 0.7) return null;
    final m = p.length;
    final n = math.min(h.length, (m * 1.5).ceil() + 2);
    var prev = Float64List(m + 1);
    for (var j = 1; j <= m; j++) {
      prev[j] = prev[j - 1] + PhoneticText.del(p.codeUnitAt(j - 1));
    }
    var best = double.infinity;
    var bestI = -1;
    if (prev[m] <= m * 0.25) {
      best = prev[m];
      bestI = 0;
    }
    for (var i = 1; i <= n; i++) {
      final cur = Float64List(m + 1);
      final hc = h.codeUnitAt(i - 1);
      cur[0] = prev[0] + PhoneticText.ins(hc);
      for (var j = 1; j <= m; j++) {
        final pc = p.codeUnitAt(j - 1);
        cur[j] = PhoneticText.min3(
          prev[j - 1] + PhoneticText.sub(pc, hc),
          prev[j] + PhoneticText.ins(hc),
          cur[j - 1] + PhoneticText.del(pc),
        );
      }
      if (cur[m] < best) {
        best = cur[m];
        bestI = i;
      }
      prev = cur;
    }
    return best <= m * 0.25 ? bestI : null;
  }

  /// Edit cost of [a] (heard) against [b] (text), whole strings.
  static double _align(String a, String b) {
    var prev = Float64List(b.length + 1);
    for (var j = 1; j <= b.length; j++) {
      prev[j] = prev[j - 1] + PhoneticText.del(b.codeUnitAt(j - 1));
    }
    for (var i = 1; i <= a.length; i++) {
      final cur = Float64List(b.length + 1);
      final hc = a.codeUnitAt(i - 1);
      cur[0] = prev[0] + PhoneticText.ins(hc);
      for (var j = 1; j <= b.length; j++) {
        final bc = b.codeUnitAt(j - 1);
        cur[j] = PhoneticText.min3(
          prev[j - 1] + PhoneticText.sub(bc, hc),
          prev[j] + PhoneticText.ins(hc),
          cur[j - 1] + PhoneticText.del(bc),
        );
      }
      prev = cur;
    }
    return prev[b.length];
  }

  // ---------------------------------------------------------- following ---

  TasmeeFeed _follow(bool isFinal) {
    final before = _expected;
    var newMistakes = 0;
    var flash = -1;
    var guard = 0;
    while (guard++ < 4 && _expected < _to) {
      final hs = _heard.substring(_cut);
      if (hs.isEmpty) break;
      final a = _alignHere(hs, utteranceStart: _cut == _speechStart);
      if (a == null) break;
      // Judge the words the reciter has moved past.
      var committed = -1;
      var cutAt = _cut;
      for (var k = 0; k < a.spans.length; k++) {
        final w = a.first + k;
        if (w < a.startWord) continue;
        final s = a.spans[k];
        if (!s.complete) break;
        var after = 0;
        for (var j = k + 1; j < a.spans.length && after < 2; j++) {
          after += a.spans[j].exact;
        }
        if (!isFinal && after < 2) break;
        if (w >= _expected) {
          final r = _judge(w, s, hs);
          if (r) {
            newMistakes++;
            flash = w;
          }
        }
        committed = w;
        if (s.hEnd >= 0) cutAt = _cut + s.hEnd;
      }
      if (committed >= 0) {
        _expected = math.max(_expected, committed + 1);
        _cut = cutAt;
      }
      // Nothing of this passage fits here: the reciter may have moved on to
      // another place (after a pause), or recites from elsewhere.
      final rest = _heard.length - _cut;
      if (committed < 0 && rest >= 14 && a.cost / a.heard > 0.45) {
        final hit = locate(_heard.substring(_cut), near: _expected);
        if (hit != null && hit.sure && (hit.word < _expected - 40 || hit.word > _expected + 3)) {
          final ayahStart = hit.word == 0 || words[hit.word - 1].endsAyah;
          final elsewhere = words[hit.word].surah != words[math.min(_expected, words.length - 1)].surah;
          if (ayahStart || elsewhere || hit.costPerChar < 0.15) {
            _placeAt(hit.word, _cut + hit.heardFrom);
            continue;
          }
        }
      }
      break;
    }
    return TasmeeFeed(math.max(0, _expected - before), newMistakes, flash);
  }

  /// Marks word [w]; true when it is a new mistake.
  bool _judge(int w, _WordSpan s, String hs) {
    final word = words[w];
    if (word.state == TasmeeState.hinted || word.state == TasmeeState.given) return false;
    final wrong = s.cost >= threshold;
    word.state = TasmeeState.correct;
    if (!wrong) return false;
    word.missed = true;
    final said = s.hStart >= 0 && s.hEnd > s.hStart ? PhoneticText.readable(hs.substring(s.hStart, s.hEnd)) : '';
    mistakes.add(TasmeeMistake(word.surah, word.ayah, word.text, said));
    return true;
  }

  /// Aligns [hs] with the text from the expected word (up to 8 words back:
  /// a repeat). The heard text is used whole; the text may end anywhere.
  _Alignment? _alignHere(String hs, {required bool utteranceStart}) {
    final back = math.min(8, _expected - _from);
    final first = _expected - back;
    // Enough text ahead for everything heard.
    var last = _expected;
    var chars = 0;
    while (last < _to && (chars < hs.length * 1.6 + 30 || last <= _expected)) {
      chars += quran.ph[last].length;
      last++;
    }
    if (first >= last) return null;
    return _dp(hs, first, last, startFrom: first, startTo: _expected, utteranceStart: utteranceStart);
  }

  /// Alignment of [hs] with words [first, last); the path may start at the
  /// beginning of any word in [startFrom, startTo].
  _Alignment _dp(String hs, int first, int last,
      {required int startFrom, required int startTo, bool utteranceStart = false}) {
    // The text window as code units, with the word of each.
    final codes = <int>[];
    final wordOf = <int>[];
    final starts = <int>[]; // text index where each word starts
    final del = <double>[];
    final alt = <int>[]; // a sound read instead at a stop (ت → ه), or 0
    for (var w = first; w < last; w++) {
      starts.add(codes.length);
      final p = quran.ph[w];
      // The ending of an ayah's last word (after its last consonant) changes
      // when the reciter joins it to the next ayah: not judged.
      var tail = p.length;
      if (quran.ayahEnd[w]) {
        while (tail > 0 && PhoneticText.isVowel(p.codeUnitAt(tail - 1))) {
          tail--;
        }
      }
      // Where the ending that changes at a stop begins: the tanween «ن» (and
      // the haraka after it), the ta marbuta.
      var stopFrom = p.length;
      var taAt = -1;
      if (quran.tanween[w] || quran.taMarbuta[w]) {
        var j = p.length;
        while (j > 0 && PhoneticText.isVowel(p.codeUnitAt(j - 1))) {
          j--;
        }
        if (quran.tanween[w] && j > 0 && p.codeUnitAt(j - 1) == 0x0646) {
          stopFrom = j - 1;
          j--;
          while (j > 0 && PhoneticText.isVowel(p.codeUnitAt(j - 1))) {
            j--;
          }
        }
        if (quran.taMarbuta[w] && j > 0 && p.codeUnitAt(j - 1) == 0x062A) taAt = j - 1;
      }
      for (var i = 0; i < p.length; i++) {
        final c = p.codeUnitAt(i);
        codes.add(c);
        wordOf.add(w - first);
        alt.add(i == taAt ? 0x0647 : 0);
        var d = PhoneticText.del(c);
        if (i >= stopFrom || (taAt >= 0 && i > taAt)) d = math.min(d, 0.25);
        if (i >= tail) d = 0;
        // A hamzat wasl that starts an ayah is silent when joined to the
        // previous ayah.
        if (quran.waslStart[w] && i < 2) d = 0;
        // The last haraka of a word is dropped when stopping on it.
        if (i == p.length - 1 && PhoneticText.isVowel(c) && d > 0.25) d = 0.25;
        // The same sound ending one word and starting the next is heard once
        // when they are joined (مِن نَّار): the second needs no sound of its own.
        if (i == 0 && codes.length >= 2 && codes[codes.length - 2] == c) d = 0;
        del.add(d);
      }
    }
    starts.add(codes.length);
    final m = codes.length;
    final n = hs.length;
    const inf = 1e9;
    final width = m + 1;
    final d = Float64List((n + 1) * width);
    final back = Uint8List((n + 1) * width); // 0 start, 1 diag, 2 ins, 3 del
    // Row 0: the path starts at an allowed word start, then may skip text.
    for (var r = 0; r <= m; r++) {
      d[r] = inf;
    }
    for (var w = startFrom; w <= startTo && w < last; w++) {
      d[starts[w - first]] = 0;
    }
    for (var r = 1; r <= m; r++) {
      final v = d[r - 1] + del[r - 1];
      if (v < d[r]) {
        d[r] = v;
        back[r] = 3;
      }
    }
    for (var i = 1; i <= n; i++) {
      final hc = hs.codeUnitAt(i - 1);
      // A breath or the hamza of starting at the very start costs little.
      final insCost = utteranceStart && i <= 2 && (hc == 0x0621 || PhoneticText.isVowel(hc)) ? 0.1 : PhoneticText.ins(hc);
      final row = i * width;
      final prow = (i - 1) * width;
      d[row] = d[prow] + insCost;
      back[row] = 2;
      for (var r = 1; r <= m; r++) {
        final rc = codes[r - 1];
        var best = d[prow + r - 1] + (alt[r - 1] == hc ? 0.25 : PhoneticText.sub(rc, hc));
        var how = 1;
        final ins = d[prow + r] + insCost;
        if (ins < best) {
          best = ins;
          how = 2;
        }
        final dl = d[row + r - 1] + del[r - 1];
        if (dl < best) {
          best = dl;
          how = 3;
        }
        d[row + r] = best;
        back[row + r] = how;
      }
    }
    // The heard text is used whole; the text may end anywhere (ties go to
    // the furthest point).
    var endR = 0;
    var endCost = inf;
    for (var r = 0; r <= m; r++) {
      final v = d[n * width + r];
      if (v <= endCost) {
        endCost = v;
        endR = r;
      }
    }
    // Back-trace: costs and heard ranges per word.
    final spans = [for (var w = first; w < last; w++) _WordSpan()];
    var i = n, r = endR;
    // Insertions waiting to be given to a word (a run at a word boundary).
    var pendingIns = 0.0;
    var pendingRun = 0;
    final pendingChars = <int>[];
    var startR = 0;
    void flushIns(int wordAfter) {
      if (pendingRun == 0) return;
      // A short run (a letter or a haraka added to the word) belongs to the
      // word after it; a long one is extra speech (a word repeated, a sound).
      final prevWord = wordAfter - 1;
      final afterAyahEnd = prevWord >= 0 && quran.ayahEnd[first + prevWord];
      // Only vowels (a stop on a tanween read «ا», a connecting haraka), or
      // the hamza of starting on a hamzat wasl: no mistake.
      final vowels = pendingChars.every(PhoneticText.isVowel);
      final startHamza = wordAfter < spans.length &&
          quran.hamzatWasl[first + wordAfter] &&
          pendingChars.every((c) => c == 0x0621 || PhoneticText.isVowel(c));
      if (pendingRun <= 2 && wordAfter < spans.length && !afterAyahEnd && !vowels && !startHamza) {
        spans[wordAfter].cost += pendingIns;
      }
      pendingIns = 0;
      pendingRun = 0;
      pendingChars.clear();
    }

    while (i > 0 || r > 0) {
      final how = back[i * width + r];
      if (i == 0 && (how == 0 || d[r] == 0)) {
        startR = r;
        break;
      }
      if (how == 1) {
        final w = wordOf[r - 1];
        final hc = hs.codeUnitAt(i - 1);
        final c = alt[r - 1] == hc ? 0.25 : PhoneticText.sub(codes[r - 1], hc);
        final s = spans[w];
        s.cost += c;
        if (c == 0) s.exact++;
        if (s.hEnd < 0) s.hEnd = i;
        s.hStart = i - 1;
        // Insertions just after this char (inside the word or at its end).
        if (pendingRun > 0) {
          final atBoundary = r < m && starts.contains(r);
          if (atBoundary) {
            flushIns(wordOf[r]);
          } else {
            s.cost += pendingIns;
            pendingIns = 0;
            pendingRun = 0;
            pendingChars.clear();
          }
        }
        i--;
        r--;
      } else if (how == 2) {
        final hc = hs.codeUnitAt(i - 1);
        final leading = utteranceStart && i <= 2 && (hc == 0x0621 || PhoneticText.isVowel(hc));
        if (!leading) {
          pendingIns += PhoneticText.ins(hc);
          pendingRun++;
          pendingChars.add(hc);
        }
        i--;
      } else {
        final w = wordOf[r - 1];
        spans[w].cost += del[r - 1];
        if (pendingRun > 0) {
          final atBoundary = r < m && starts.contains(r);
          if (atBoundary) {
            flushIns(wordOf[r]);
          } else {
            spans[w].cost += pendingIns;
            pendingIns = 0;
            pendingRun = 0;
            pendingChars.clear();
          }
        }
        r--;
      }
    }
    // Leading insertions (before the path's first text char) are noise.
    for (var k = 0; k < spans.length; k++) {
      spans[k].complete = starts[k + 1] <= endR;
    }
    // Words before the start were not recited in this passage.
    var startWord = first;
    for (var k = 0; k < spans.length; k++) {
      if (starts[k] <= startR) startWord = first + k;
    }
    for (var k = 0; k < startWord - first; k++) {
      spans[k].cost = 0;
    }
    return _Alignment(first, spans, startWord, endCost, n);
  }

  // ----------------------------------------------------------- locating ---

  /// Finds where [hs] (normalized) is recited in the scope.
  PhoneticHit? locate(String hs, {int? near}) {
    final q = PhoneticText.skeleton(hs);
    if (q.length < 6) return null;
    final cands = quran.candidates(q, from: _from, to: _to);
    if (cands.isEmpty) return null;
    final results = <(int word, double cpc, int heardFrom)>[];
    for (final c in cands) {
      final first = math.max(_from, c - 4);
      final startTo = math.min(_to - 1, c + 3);
      var last = startTo;
      var chars = 0;
      while (last < _to && chars < hs.length * 1.5 + 20) {
        chars += quran.ph[last].length;
        last++;
      }
      if (last <= first) continue;
      final a = _dp(hs, first, last, startFrom: first, startTo: startTo, utteranceStart: true);
      results.add((a.startWord, a.cost / math.max(1, hs.length), 0));
    }
    if (results.isEmpty) return null;
    results.sort((a, b) => a.$2.compareTo(b.$2));
    final best = results.first;
    final limit = q.length >= 10 ? 0.30 : 0.22;
    if (best.$2 > limit) return null;
    final ties = [
      for (final r in results.skip(1))
        if ((r.$1 - best.$1).abs() > 6 && r.$2 <= best.$2 + 0.06) r,
    ];
    if (ties.isEmpty) return PhoneticHit(best.$1, best.$3, best.$2);
    // The same words in several places: wait for what follows, unless the
    // passage is long already (then the nearest place is taken for now).
    if (q.length < 16) return null;
    var pick = best;
    if (near != null) {
      for (final r in ties) {
        if ((r.$1 - near).abs() < (pick.$1 - near).abs()) pick = r;
      }
    }
    return PhoneticHit(pick.$1, pick.$3, pick.$2, sure: false);
  }
}
