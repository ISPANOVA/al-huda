import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:al_huda/core/data/surah_metadata.dart';
import 'package:al_huda/features/tasmee/tasmee_engine.dart';
import 'package:al_huda/features/tasmee/tasmee_locator.dart';
import 'package:flutter_test/flutter_test.dart';

/// The whole Mushaf's words, in page order, exactly as the Tasmee builds them.
List<TasmeeWord> _quran() {
  final d = jsonDecode(File('assets/quran/quran.json').readAsStringSync()) as Map<String, dynamic>;
  final number = RegExp('[\\s ]+[٠-٩]+\$');
  final out = <TasmeeWord>[];
  for (final page in d['lines'] as List) {
    for (final line in page as List) {
      final l = line as List;
      if (l[0] != 't' && l[0] != 'c') continue;
      for (var i = 2; i + 1 < l.length; i += 2) {
        final a = l[i] as int;
        if (a == 0) continue;
        final w = l[i + 1] as String;
        final m = number.firstMatch(w);
        final ref = SurahMetadata.fromGlobal(a);
        out.add(TasmeeWord(
          surah: ref.surah,
          ayah: ref.ayah,
          text: m == null ? w : w.substring(0, m.start),
          endsAyah: m != null,
        ));
      }
    }
  }
  return out;
}

void main() {
  final quran = _quran();
  void reset() {
    for (final w in quran) {
      w.state = TasmeeState.hidden;
      w.missed = false;
    }
  }

  int at(int surah, int ayah, [int word = 0]) =>
      quran.indexWhere((w) => w.surah == surah && w.ayah == ayah) + word;

  final locator = TasmeeLocator(quran);
  List<String> said(String s) => TasmeeMatcher.words(s);

  test('the Mushaf has all its words', () {
    expect(quran.length, greaterThan(77000));
    expect(quran.first.surah, 1);
    expect(quran.last.surah, 114);
  });

  test('finds the place of well-known openings', () {
    final cases = <String, (int, int)>{
      'تبارك الذي بيده الملك وهو على كل شيء قدير': (67, 1),
      'الرحمن علم القرآن خلق الإنسان': (55, 1),
      'ألم تر كيف فعل ربك بأصحاب الفيل': (105, 1),
      'ويسألونك عن الروح قل الروح من أمر ربي': (17, 85),
      'إنا أنزلناه في ليلة القدر': (97, 1),
      'والعصر إن الإنسان لفي خسر': (103, 1),
      'يا أيها المزمل قم الليل إلا قليلا': (73, 1),
      'الله لا إله إلا هو الحي القيوم لا تأخذه سنة ولا نوم': (2, 255),
    };
    cases.forEach((text, place) {
      final hit = locator.locate(said(text));
      expect(hit, isNotNull, reason: text);
      expect((quran[hit!.index].surah, quran[hit.index].ayah), place, reason: text);
    });
  });

  test('isti\'adha and basmala before the recitation are skipped', () {
    final hit = locator.locate(said('أعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم تبارك الذي بيده الملك'));
    expect(hit, isNotNull);
    expect(hit!.index, at(67, 1));
    expect(hit.heardFrom, 9);
  });

  test('a word dropped or misheard by the recogniser still finds the place', () {
    var hit = locator.locate(said('تبارك بيده الملك وهو على كل شيء قدير'));
    expect(hit?.index, at(67, 1));
    hit = locator.locate(said('الذي خلق الموت والحياة ليبلوكم أيكم أحسن عملا'));
    expect(quran[hit!.index].surah, 67);
    expect(quran[hit.index].ayah, 2);
  });

  test('too little to be sure: waits', () {
    expect(locator.locate(said('قل')), isNull);
    expect(locator.locate(said('إن الله')), isNull);
    expect(locator.locate(said('بسم الله الرحمن الرحيم')), isNull);
  });

  test('a repeated ayah is taken near the reciter', () {
    final near = at(55, 40);
    final hit = locator.locate(said('فبأي آلاء ربكما تكذبان يخرج منهما اللؤلؤ والمرجان'), near: near);
    expect(quran[hit!.index].surah, 55);
    expect(quran[hit.index].ayah, 21);
    final rep = locator.locate(said('فبأي آلاء ربكما تكذبان فبأي آلاء ربكما تكذبان'), near: near);
    // Only the repeated ayah: not sure where, but certainly al-Rahman.
    if (rep != null) expect(quran[rep.index].surah, 55);
  });

  test('a place is never wrong: random passages, read word by word', () {
    final rnd = math.Random(7);
    var found = 0;
    var tries = 0;
    var words = 0;
    for (var t = 0; t < 400; t++) {
      final p = rnd.nextInt(quran.length - 30);
      tries++;
      for (var n = 2; n <= 10; n++) {
        final heard = [for (var i = p; i < p + n; i++) quran[i].text];
        final hit = locator.locate(heard, near: p);
        if (hit == null) continue;
        // Right place, or the same words somewhere else (a repeated passage).
        final f = hit.heardFrom;
        String keys(int from, int len) =>
            [for (var i = from; i < from + len && i < quran.length; i++) quran[i].key].join(' ');
        final same = hit.index == p + f || keys(hit.index, n - f) == keys(p + f, n - f);
        expect(same, isTrue, reason: 'at $p: ${heard.join(' ')} -> ${hit.index}');
        found++;
        words += n;
        break;
      }
    }
    // ignore: avoid_print
    print('located $found / $tries, ${(words / math.max(1, found)).toStringAsFixed(1)} words on average');
    expect(found, greaterThan(tries * 0.95));
  });

  test('locating is fast', () {
    final sw = Stopwatch()..start();
    for (var i = 0; i < 50; i++) {
      locator.locate(said('ويسألونك عن الروح قل الروح من أمر ربي'));
    }
    // ignore: avoid_print
    print('locate: ${sw.elapsedMicroseconds / 50} µs');
    expect(sw.elapsedMilliseconds / 50, lessThan(60));
  });

  group('tracker', () {
    setUp(reset);

    test('starts wherever the reciter starts', () {
      final mistakes = <TasmeeMistake>[];
      final t = TasmeeTracker(quran, mistakes, near: at(36, 1));
      final words = said('يس والقرآن الحكيم إنك لمن المرسلين على صراط مستقيم');
      for (var n = 1; n <= words.length; n++) {
        t.feed(words.sublist(0, n), isFinal: n == words.length);
      }
      expect(t.located, isTrue);
      expect(quran[t.expected].surah, 36);
      expect(quran[t.expected].ayah, 5);
      expect(mistakes, isEmpty);
      expect(quran[at(36, 2)].state, TasmeeState.correct);
    });

    test('after a pause, another surah is followed', () {
      final mistakes = <TasmeeMistake>[];
      final t = TasmeeTracker(quran, mistakes);
      t.feed(said('الحمد لله رب العالمين الرحمن الرحيم مالك يوم الدين'), isFinal: true);
      expect(t.located, isTrue);
      t.newUtterance();
      final w = said('قل هو الله أحد الله الصمد');
      for (var n = 1; n <= w.length; n++) {
        t.feed(w.sublist(0, n), isFinal: n == w.length);
      }
      expect(quran[t.expected].surah, 112);
      expect(quran[t.expected].ayah, 3);
      expect(mistakes, isEmpty);
      // What was recited before stays shown.
      expect(quran[at(1, 2)].state, TasmeeState.correct);
    });

    test('drifting into another passage without a pause is a mistake, not a move', () {
      final mistakes = <TasmeeMistake>[];
      final t = TasmeeTracker(quran, mistakes);
      final w = said('الحمد لله رب العالمين قل هو الله أحد الله الصمد');
      for (var n = 1; n <= w.length; n++) {
        t.feed(w.sublist(0, n), isFinal: n == w.length);
      }
      expect(quran[t.expected].surah, 1);
      expect(mistakes, isNotEmpty);
    });

    test('words lost while the microphone restarts are not mistakes', () {
      final mistakes = <TasmeeMistake>[];
      final t = TasmeeTracker(quran, mistakes, near: at(67, 1));
      t.feed(said('تبارك الذي بيده الملك وهو على كل شيء قدير'), isFinal: true);
      t.newUtterance();
      // «الذي خلق» fell in the gap.
      final w = said('الموت والحياة ليبلوكم أيكم أحسن عملا');
      for (var n = 1; n <= w.length; n++) {
        t.feed(w.sublist(0, n), isFinal: n == w.length);
      }
      expect(mistakes, isEmpty);
      expect(quran[t.expected].ayah, 2);
      expect(quran[t.expected - 1].key, TasmeeMatcher.key('عملا'));
    });

    test('a surah chosen: only its ayahs are searched', () {
      final mistakes = <TasmeeMistake>[];
      final t = TasmeeTracker(quran, mistakes, from: at(55, 1), to: at(56, 1));
      t.feed(said('فبأي آلاء ربكما تكذبان'), isFinal: false);
      t.feed(said('فبأي آلاء ربكما تكذبان فبأي آلاء ربكما تكذبان'), isFinal: false);
      if (t.located) expect(quran[t.expected].surah, 55);
      t.feed(said('فبأي آلاء ربكما تكذبان خلق الإنسان من صلصال كالفخار'), isFinal: true);
      expect(t.located, isTrue);
      expect(quran[t.expected].surah, 55);
      expect(quran[t.expected].ayah, 15);
    });

    test('numbers written in digits', () {
      final mistakes = <TasmeeMistake>[];
      final t = TasmeeTracker(quran, mistakes);
      t.startAt(at(74, 30));
      t.feed(said('عليها 19'), isFinal: true);
      expect(mistakes, isEmpty);
      expect(quran[t.expected].ayah, 31);
    });

    test('a real wrong word is still caught', () {
      final mistakes = <TasmeeMistake>[];
      final t = TasmeeTracker(quran, mistakes);
      t.startAt(at(2, 5));
      t.feed(said('أولئك في هدى من ربهم وأولئك هم المفلحون'), isFinal: true);
      expect(mistakes.length, 1);
      expect(mistakes.first.heard, 'في');
    });
  });
}
