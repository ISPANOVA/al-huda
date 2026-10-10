// What the on-device model heard from real recitations (written by
// tool/tasmee/eval_model.py in the Tasmee lab), followed by the Tasmee.
// Skipped when that file isn't there.
import 'dart:convert';
import 'dart:io';

import 'package:al_huda/core/data/surah_metadata.dart';
import 'package:al_huda/features/tasmee/phonetic/phonetic_text.dart';
import 'package:al_huda/features/tasmee/phonetic/phonetic_tracker.dart';
import 'package:al_huda/features/tasmee/tasmee_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tasmee_phonetic_test.dart' show mushafWords;

void main() {
  final path = Platform.environment['TASMEE_EVENTS'] ?? 'tool/tasmee/out/model_events.json';
  final file = File(path);
  test('real recitations through the model', () {
    final words = mushafWords();
    final lines = File('assets/tasmee/phonemes.txt').readAsLinesSync();
    final quran = PhoneticQuran.build(words, lines, SurahMetadata.globalAyah);
    final extra = jsonDecode(File('assets/tasmee/extra.json').readAsStringSync()) as Map<String, dynamic>;
    final openings = [
      PhoneticText.normalize((extra['istiadha'] as List).join()),
      PhoneticText.normalize(lines[0].replaceAll(' ', '')),
    ];
    final sets = jsonDecode(file.readAsStringSync()) as List<dynamic>;
    var judgedAll = 0, wrongAll = 0, foundAll = 0, doubtAll = 0;
    final report = StringBuffer();
    for (final s in sets) {
      final m = s as Map<String, dynamic>;
      for (final w in words) {
        w.state = TasmeeState.hidden;
        w.missed = false;
        w.doubtful = false;
      }
      final surah = m['surah'] as int, a1 = m['from'] as int, a2 = m['to'] as int;
      final first = words.indexWhere((w) => w.surah == surah && w.ayah == a1);
      final last = words.lastIndexWhere((w) => w.surah == surah && w.ayah == a2);
      final mistakes = <TasmeeMistake>[];
      final doubts = <TasmeeMistake>[];
      final t = PhoneticTracker(words, quran, mistakes, openings: openings, doubts: doubts);
      final sw = Stopwatch()..start();
      var full = '';
      for (final e in m['events'] as List<dynamic>) {
        final ev = e as List<dynamic>;
        final text = ev[0] as String;
        final fin = ev[1] as bool;
        t.feed(text, isFinal: fin);
        if (fin) {
          full += '$text | ';
          t.newUtterance();
        }
      }
      sw.stop();
      var judged = 0;
      for (var i = first; i <= last; i++) {
        if (words[i].state == TasmeeState.correct) judged++;
      }
      // Found: most words of the first ayah were followed.
      final firstAyahEnd = words.indexWhere((w) => w.endsAyah, first);
      var firstOk = 0;
      for (var i = first; i <= firstAyahEnd; i++) {
        if (words[i].state != TasmeeState.hidden) firstOk++;
      }
      final found = firstOk * 2 > firstAyahEnd - first + 1;
      if (found) foundAll++;
      judgedAll += judged;
      wrongAll += mistakes.length;
      doubtAll += doubts.length;
      report.writeln('${m['name']}: found $found, judged $judged/${last - first + 1}, '
          'mistakes ${mistakes.length}${mistakes.isEmpty ? '' : ': ${mistakes.map((x) => '${x.word} ← ${x.heard}').join('، ')}'}'
          '${doubts.isEmpty ? '' : ' | doubts ${doubts.length}: ${doubts.map((x) => '${x.word} ← ${x.heard}').join('، ')}'}'
          ' (${sw.elapsedMilliseconds} ms)');
      if (mistakes.isNotEmpty || !found) {
        report.writeln('   heard: $full');
        report.writeln('   text : ${[for (var i = first; i <= last; i++) quran.ph[i]].join(' ')}');
      }
    }
    // ignore: avoid_print
    print('$report\nfound $foundAll/${sets.length}; false mistakes $wrongAll in $judgedAll words '
        '(${(wrongAll * 100 / (judgedAll == 0 ? 1 : judgedAll)).toStringAsFixed(1)}%), '
        'doubts $doubtAll (${(doubtAll * 100 / (judgedAll == 0 ? 1 : judgedAll)).toStringAsFixed(1)}%)');
  }, skip: file.existsSync() ? false : 'no model events');
}
