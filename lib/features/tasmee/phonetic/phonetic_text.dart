import 'dart:math' as math;

/// The Quran phonetic script (quran-transcript) as the on-device model writes
/// it: Arabic letters and harakat, a long vowel or a doubled letter written as
/// a run of the same character, and a few signs for tajweed details.
///
/// The Tasmee compares words in a simpler form: tajweed signs and lengths
/// (madd, shadda, ghunna) are left out, because a word is wrong when a letter
/// or a haraka is wrong, not when a madd is a count short.
class PhoneticText {
  PhoneticText._();

  /// Short vowels, long vowels and the imala vowel.
  static const _vowels = 'َُِاۥۦٲ';

  /// Tajweed signs that don't change the word (qalqala, sakt, tarqeeq, ...).
  static const _signs = 'ڇؙ۪ۜـ';

  static bool isVowel(int c) => _vowels.contains(String.fromCharCode(c));

  /// Comparable form: signs removed, ikhfa noon / meem as plain letters,
  /// every run of one character written once.
  static String normalize(String s) {
    final out = StringBuffer();
    var last = -1;
    for (final r in s.runes) {
      var c = r;
      if (c == 0x20 || c == 0x2D) continue; // space, "-" placeholder
      if (_signs.contains(String.fromCharCode(c))) continue;
      if (c == 0x06BA) c = 0x0646; // ں → ن
      if (c == 0x06FE) c = 0x0645; // ۾ → م
      if (c == last) continue;
      out.writeCharCode(c);
      last = c;
    }
    return out.toString();
  }

  /// Consonants only (for finding the place of a passage).
  static String skeleton(String normalized) {
    final out = StringBuffer();
    for (final c in normalized.codeUnits) {
      if (!isVowel(c)) out.writeCharCode(c);
    }
    return out.toString();
  }

  /// Letters a recogniser (and a reciter's accent) brings close together.
  static const _close = ['سصث', 'تط', 'دض', 'ذظز', 'كق', 'حه', 'ءع', 'غخ'];

  static bool _closePair(int a, int b) {
    final x = String.fromCharCode(a), y = String.fromCharCode(b);
    for (final g in _close) {
      if (g.contains(x) && g.contains(y)) return true;
    }
    return false;
  }

  // Long vowel and the matching letter: «ي» heard for «ۦ».
  static bool _vowelLetter(int a, int b) =>
      (a == 0x06E6 && b == 0x064A) || (a == 0x064A && b == 0x06E6) ||
      (a == 0x06E5 && b == 0x0648) || (a == 0x0648 && b == 0x06E5);

  static bool _long(int c) => c == 0x0627 || c == 0x06E5 || c == 0x06E6 || c == 0x0672;

  /// Cost of hearing [h] where [e] is written.
  static double sub(int e, int h) {
    if (e == h) return 0;
    final ve = isVowel(e), vh = isVowel(h);
    if (ve && vh) return _long(e) == _long(h) ? 0.5 : 0.45;
    if (ve != vh) return _vowelLetter(e, h) ? 0.35 : 1.0;
    return _closePair(e, h) ? 0.6 : 1.0;
  }

  /// Cost of [e] not being heard.
  static double del(int e) {
    if (_long(e)) return 0.35;
    if (isVowel(e)) return 0.5;
    if (e == 0x0621) return 0.6; // hamza (often soft at a start)
    return 1.0;
  }

  /// Cost of hearing [h] that isn't written.
  static double ins(int h) {
    if (_long(h)) return 0.35;
    if (isVowel(h)) return 0.5;
    if (h == 0x0621) return 0.6;
    return 1.0;
  }

  /// Readable Arabic for what was heard (shown in the results).
  static String readable(String normalized) =>
      normalized.replaceAll('ۦ', 'ي').replaceAll('ۥ', 'و').replaceAll('ٲ', 'ا');

  static double min3(double a, double b, double c) => math.min(a, math.min(b, c));
}
