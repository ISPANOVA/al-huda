// The light web version's shared logic, compiled to JavaScript
// (dart compile js): the same prayer-time calculation and Tasmee engine as
// the app, so both give the same results.
//
// window.alhuda.prayerTimes(lat, lng, y, m, d, method, madhab) -> [ms × 6]
// window.alhuda.tasmeeInit(wordsJson)            words: [[surah, ayah, text, endsAyah 0/1], …]
// window.alhuda.tasmeeFeed(transcript, isFinal) -> '{"expected":…,"located":…,"mistakes":…,"flash":…}'
// window.alhuda.tasmeeStates(from, to)          -> one character per word: h c n m g (hidden, correct, hinted, mistake, given) + upper case when missed
// window.alhuda.tasmeeNewUtterance(manual), tasmeeStartAt(index, pageStart), tasmeeHint(ayah), tasmeeScope(from, to), tasmeeMistakes()
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:adhan/adhan.dart' as adhan;
import 'package:al_huda/features/tasmee/tasmee_engine.dart';
import 'package:al_huda/features/tasmee/tasmee_locator.dart';

adhan.CalculationMethod _method(String key) => switch (key) {
      'umm_al_qura' => adhan.CalculationMethod.umm_al_qura,
      'muslim_world_league' => adhan.CalculationMethod.muslim_world_league,
      'karachi' => adhan.CalculationMethod.karachi,
      'dubai' => adhan.CalculationMethod.dubai,
      'kuwait' => adhan.CalculationMethod.kuwait,
      'qatar' => adhan.CalculationMethod.qatar,
      'singapore' => adhan.CalculationMethod.singapore,
      'turkey' => adhan.CalculationMethod.turkey,
      'tehran' => adhan.CalculationMethod.tehran,
      'north_america' => adhan.CalculationMethod.north_america,
      'moon_sighting_committee' => adhan.CalculationMethod.moon_sighting_committee,
      _ => adhan.CalculationMethod.egyptian,
    };

JSArray<JSNumber> _prayerTimes(JSNumber lat, JSNumber lng, JSNumber y, JSNumber m, JSNumber d, JSString method, JSString madhab) {
  final params = _method(method.toDart).getParameters();
  params.madhab = madhab.toDart == 'hanafi' ? adhan.Madhab.hanafi : adhan.Madhab.shafi;
  final pt = adhan.PrayerTimes(
    adhan.Coordinates(lat.toDartDouble, lng.toDartDouble),
    adhan.DateComponents(y.toDartInt, m.toDartInt, d.toDartInt),
    params,
  );
  return [pt.fajr, pt.sunrise, pt.dhuhr, pt.asr, pt.maghrib, pt.isha]
      .map((t) => t.millisecondsSinceEpoch.toJS)
      .toList()
      .toJS;
}

List<TasmeeWord> _words = [];
List<TasmeeMistake> _mistakes = [];
TasmeeTracker? _tracker;

void _tasmeeInit(JSString json) {
  final list = jsonDecode(json.toDart) as List<dynamic>;
  if (_words.isEmpty) {
    _words = [
      for (final w in list)
        TasmeeWord(
          surah: (w as List<dynamic>)[0] as int,
          ayah: w[1] as int,
          text: w[2] as String,
          endsAyah: w[3] == 1,
        ),
    ];
  } else {
    for (final w in _words) {
      w.state = TasmeeState.hidden;
      w.missed = false;
    }
  }
  _mistakes = [];
  _tracker = TasmeeTracker(_words, _mistakes);
}

JSString _tasmeeFeed(JSString transcript, JSBoolean isFinal) {
  final t = _tracker!;
  final wasLocated = t.located;
  final before = t.expected;
  final r = t.feed(TasmeeMatcher.words(transcript.toDart), isFinal: isFinal.toDart);
  return jsonEncode({
    'expected': t.expected,
    'located': t.located,
    'moved': t.located && (!wasLocated || (t.expected - before).abs() > 8),
    'mistakes': r.mistakes,
    'flash': r.flash,
    'done': t.done,
  }).toJS;
}

JSString _tasmeeStates(JSNumber from, JSNumber to) {
  final b = StringBuffer();
  final end = to.toDartInt.clamp(0, _words.length);
  for (var i = from.toDartInt.clamp(0, end); i < end; i++) {
    final w = _words[i];
    final c = switch (w.state) {
      TasmeeState.hidden => 'h',
      TasmeeState.correct => 'c',
      TasmeeState.hinted => 'n',
      TasmeeState.mistake => 'm',
      TasmeeState.given => 'g',
    };
    b.write(w.missed ? c.toUpperCase() : c);
  }
  return b.toString().toJS;
}

JSString _tasmeeMistakes() => jsonEncode([
      for (final m in _mistakes) [m.surah, m.ayah, m.word, m.heard],
    ]).toJS;

void main() {
  final api = JSObject();
  api['prayerTimes'] = _prayerTimes.toJS;
  api['tasmeeInit'] = _tasmeeInit.toJS;
  api['tasmeeFeed'] = _tasmeeFeed.toJS;
  api['tasmeeStates'] = _tasmeeStates.toJS;
  api['tasmeeMistakes'] = _tasmeeMistakes.toJS;
  api['tasmeeNewUtterance'] = ((JSBoolean manual) => _tracker?.newUtterance(manual: manual.toDart)).toJS;
  api['tasmeeStartAt'] = ((JSNumber index, JSNumber pageStart) =>
      _tracker?.startAt(index.toDartInt, pageStart: pageStart.toDartInt)).toJS;
  api['tasmeeHint'] = ((JSBoolean ayah) {
    final t = _tracker;
    if (t == null || t.done) return;
    if (ayah.toDart) {
      t.revealAyah();
    } else {
      t.hintNext();
    }
  }).toJS;
  api['tasmeeScope'] = ((JSNumber from, JSNumber to) => _tracker?.setScope(from.toDartInt, to.toDartInt)).toJS;
  api['tasmeeExpected'] = (() => (_tracker?.expected ?? 0).toJS).toJS;
  api['tasmeeLocated'] = (() => (_tracker?.located ?? false).toJS).toJS;
  globalContext['alhuda'] = api;
  globalContext.callMethod('alhudaReady'.toJS);
}
