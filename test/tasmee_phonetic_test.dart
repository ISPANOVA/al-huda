import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:al_huda/core/data/surah_metadata.dart';
import 'package:al_huda/features/tasmee/phonetic/phonetic_text.dart';
import 'package:al_huda/features/tasmee/phonetic/phonetic_tracker.dart';
import 'package:al_huda/features/tasmee/tasmee_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Mushaf's words in page order, as the Tasmee page builds them.
List<TasmeeWord> mushafWords() {
  final root = jsonDecode(File('assets/quran/quran.json').readAsStringSync()) as Map<String, dynamic>;
  final number = RegExp('[\\s ]+[٠-٩]+\$');
  final words = <TasmeeWord>[];
  for (final page in root['lines'] as List<dynamic>) {
    for (final l in page as List<dynamic>) {
      final row = l as List<dynamic>;
      if (row[0] == 'h' || row[0] == 'b') continue;
      for (var i = 2; i + 1 < row.length; i += 2) {
        final g = row[i] as int;
        if (g == 0) continue;
        final text = row[i + 1] as String;
        final ref = SurahMetadata.fromGlobal(g);
        final m = number.firstMatch(text);
        words.add(TasmeeWord(
          surah: ref.surah,
          ayah: ref.ayah,
          text: m == null ? text : text.substring(0, m.start),
          endsAyah: m != null,
        ));
      }
    }
  }
  return words;
}

late List<TasmeeWord> words;
late PhoneticQuran quran;
late List<String> raw; // raw phonemes per word
late List<String> openings;

void reset() {
  for (final w in words) {
    w.state = TasmeeState.hidden;
    w.missed = false;
  }
}

PhoneticTracker tracker(List<TasmeeMistake> mistakes) =>
    PhoneticTracker(words, quran, mistakes, openings: openings);

/// Feeds [text] the way the model does: growing a few characters at a time.
void recite(PhoneticTracker t, String text, {int step = 7, bool pauseAtEnd = true}) {
  for (var i = step; i < text.length; i += step) {
    t.feed(text.substring(0, i), isFinal: false);
  }
  t.feed(text, isFinal: pauseAtEnd);
}

String said(int from, int to) => [for (var i = from; i < to; i++) raw[i]].join();

void main() {
  setUpAll(() {
    words = mushafWords();
    final lines = File('assets/tasmee/phonemes.txt').readAsLinesSync();
    quran = PhoneticQuran.build(words, lines, SurahMetadata.globalAyah);
    raw = List<String>.filled(words.length, '');
    var lastAyah = -1, k = 0;
    List<String> items = const [];
    for (var i = 0; i < words.length; i++) {
      final g = SurahMetadata.globalAyah(words[i].surah, words[i].ayah);
      if (g != lastAyah) {
        lastAyah = g;
        k = 0;
        items = lines[g - 1].split(' ');
      }
      raw[i] = k < items.length && items[k] != '-' ? items[k] : '';
      k++;
    }
    final extra = jsonDecode(File('assets/tasmee/extra.json').readAsStringSync()) as Map<String, dynamic>;
    openings = [
      PhoneticText.normalize((extra['istiadha'] as List).join()),
      PhoneticText.normalize(lines[0].replaceAll(' ', '')),
    ];
  });

  setUp(reset);

  test('every word has its phonemes', () {
    expect(words.length, greaterThan(77000));
    final empty = [for (var i = 0; i < words.length; i++) if (quran.ph[i].isEmpty) i];
    // A few words are read together with their neighbour.
    expect(empty.length, lessThan(words.length * 0.01), reason: 'empty: ${empty.take(20).map((i) => words[i].text)}');
  });

  test('finds the place and follows a correct recitation', () {
    final rnd = math.Random(7);
    var found = 0, wrong = 0, total = 0;
    final failures = <String>[];
    for (var n = 0; n < 60; n++) {
      reset();
      // Start at an ayah's beginning somewhere in the Quran.
      var s = rnd.nextInt(words.length - 60);
      while (s > 0 && !words[s - 1].endsAyah) {
        s--;
      }
      final mistakes = <TasmeeMistake>[];
      final t = tracker(mistakes);
      recite(t, said(s, s + 25));
      total++;
      if (!t.located) {
        failures.add('not found: ${words[s].surah}:${words[s].ayah}');
        continue;
      }
      // An identical passage elsewhere is as good.
      final ok = t.words[s].state == TasmeeState.correct || quran.ph[t.expected - 1] == quran.ph[s + 24];
      if (ok) found++;
      if (mistakes.isNotEmpty) {
        wrong++;
        failures.add('${words[s].surah}:${words[s].ayah} mistakes: ${mistakes.map((m) => '${m.word}/${m.heard}').join(', ')}');
      }
    }
    // ignore: avoid_print
    print('found $found/$total, with false mistakes $wrong\n${failures.join('\n')}');
    expect(found, greaterThanOrEqualTo(total - 2));
    expect(wrong, lessThanOrEqualTo(2));
  });

  test('a skipped word is a mistake', () {
    final s = SurahMetadata.globalAyah(2, 255);
    final start = words.indexWhere((w) => w.surah == 2 && w.ayah == 255);
    expect(start, greaterThan(0), reason: '$s');
    final mistakes = <TasmeeMistake>[];
    final t = tracker(mistakes)..startAt(start);
    recite(t, said(start, start + 5) + said(start + 6, start + 14));
    expect(mistakes.map((m) => m.word), [words[start + 5].text]);
  });

  test('a wrong letter is a mistake', () {
    final start = words.indexWhere((w) => w.surah == 1 && w.ayah == 2);
    final mistakes = <TasmeeMistake>[];
    final t = tracker(mistakes)..startAt(start);
    // «رَبِّ» said as «رَدِّ».
    final wrongWord = raw[start + 2].replaceAll('ب', 'د');
    recite(t, said(start, start + 2) + wrongWord + said(start + 3, start + 12));
    expect(mistakes.map((m) => m.word), [words[start + 2].text]);
  });

  test('a wrong haraka is a mistake when two are wrong, not one', () {
    final start = words.indexWhere((w) => w.surah == 112 && w.ayah == 1);
    final mistakes = <TasmeeMistake>[];
    final t = tracker(mistakes)..startAt(start);
    final w = raw[start + 1]; // هُوَ
    final one = w.replaceFirst('ُ', 'َ');
    recite(t, said(start, start + 1) + one + said(start + 2, start + 8));
    expect(mistakes, isEmpty, reason: 'one haraka: ${mistakes.map((m) => m.heard)}');
  });

  test('going back to repeat is not a mistake', () {
    final start = words.indexWhere((w) => w.surah == 36 && w.ayah == 1);
    final mistakes = <TasmeeMistake>[];
    final t = tracker(mistakes)..startAt(start);
    recite(t, said(start, start + 8) + said(start + 4, start + 16));
    expect(mistakes, isEmpty, reason: mistakes.map((m) => '${m.word}/${m.heard}').join(', '));
    expect(t.expected, greaterThanOrEqualTo(start + 15));
  });

  test('a word said again right away is not a mistake', () {
    final start = words.indexWhere((w) => w.surah == 3 && w.ayah == 191);
    final mistakes = <TasmeeMistake>[];
    final t = tracker(mistakes)..startAt(start);
    // «… وَيَتَفَكَّرُونَ وَيَتَفَكَّرُونَ فِي خَلۡقِ …»
    final k = words.indexWhere((w) => w.text.startsWith('وَيَتَفَكَّرُونَ'), start);
    recite(t, said(start, k + 1) + said(k, k + 10));
    expect(mistakes, isEmpty, reason: mistakes.map((m) => '${m.word}/${m.heard}').join(', '));
    expect(t.expected, greaterThanOrEqualTo(k + 9));
  });

  test('a wrong word corrected at once counts as corrected', () {
    final start = words.indexWhere((w) => w.surah == 67 && w.ayah == 2);
    final mistakes = <TasmeeMistake>[];
    final t = tracker(mistakes)..startAt(start);
    // Says word 3 with a wrong letter, goes back two words and says it right.
    final wrong = raw[start + 3].replaceFirst(RegExp('[بتثجحخدذرزسشصضطظعغفقكلمنهوي]'), 'ف');
    recite(t, said(start, start + 3) + wrong + said(start + 1, start + 12));
    expect(mistakes, isEmpty, reason: mistakes.map((m) => '${m.word}/${m.heard}').join(', '));
  });

  test("isti'adha and basmala before reciting are not part of the text", () {
    final start = words.indexWhere((w) => w.surah == 67 && w.ayah == 1);
    final mistakes = <TasmeeMistake>[];
    final t = tracker(mistakes);
    recite(t, openings[0] + openings[1] + said(start, start + 20));
    expect(t.located, isTrue);
    expect(words[start].state, TasmeeState.correct);
    expect(mistakes, isEmpty, reason: mistakes.map((m) => '${m.word}/${m.heard}').join(', '));
  });

  test('pauses: each utterance continues where the last one ended', () {
    final start = words.indexWhere((w) => w.surah == 18 && w.ayah == 1);
    final mistakes = <TasmeeMistake>[];
    final t = tracker(mistakes);
    for (var k = 0; k < 4; k++) {
      t.newUtterance();
      recite(t, said(start + k * 9, start + k * 9 + 9));
    }
    expect(t.expected, greaterThanOrEqualTo(start + 35));
    expect(mistakes, isEmpty, reason: mistakes.map((m) => '${m.word}/${m.heard}').join(', '));
  });

  test('recogniser noise on harakat does not make mistakes', () {
    final rnd = math.Random(3);
    var wrong = 0, judged = 0;
    for (var n = 0; n < 30; n++) {
      reset();
      var s = rnd.nextInt(words.length - 40);
      while (s > 0 && !words[s - 1].endsAyah) {
        s--;
      }
      final mistakes = <TasmeeMistake>[];
      final t = tracker(mistakes)..startAt(s);
      // About one haraka in 40 swapped.
      final text = said(s, s + 30).split('').map((c) {
        if ('َُِ'.contains(c) && rnd.nextInt(40) == 0) return 'َُِ'[rnd.nextInt(3)];
        return c;
      }).join();
      recite(t, text);
      judged += t.expected - s;
      wrong += mistakes.length;
    }
    // ignore: avoid_print
    print('noise: $wrong false mistakes in $judged words');
    expect(wrong, lessThan(judged * 0.01 + 1));
  });
}
