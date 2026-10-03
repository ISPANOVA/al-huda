import 'package:al_huda/features/tasmee/tasmee_engine.dart';
import 'package:flutter_test/flutter_test.dart';

List<TasmeeWord> _words(String uthmani, {int surah = 1, int ayah = 1}) {
  final parts = uthmani.split(' ');
  return [
    for (var i = 0; i < parts.length; i++)
      TasmeeWord(surah: surah, ayah: ayah, text: parts[i], endsAyah: i == parts.length - 1),
  ];
}

void main() {
  test('uthmani vs plain spelling', () {
    expect(TasmeeMatcher.similar(TasmeeMatcher.key('الكتاب'), TasmeeMatcher.key('ٱلْكِتَٰبُ')), isTrue);
    expect(TasmeeMatcher.similar(TasmeeMatcher.key('الصلاة'), TasmeeMatcher.key('ٱلصَّلَوٰةَ')), isTrue);
    expect(TasmeeMatcher.similar(TasmeeMatcher.key('الرحمن'), TasmeeMatcher.key('ٱلرَّحْمَٰنِ')), isTrue);
    expect(TasmeeMatcher.similar(TasmeeMatcher.key('العالمين'), TasmeeMatcher.key('ٱلْعَٰلَمِينَ')), isTrue);
    expect(TasmeeMatcher.similar(TasmeeMatcher.key('الكافرين'), TasmeeMatcher.key('ٱلْعَٰلَمِينَ')), isFalse);
  });

  test('reveals words as they are recited', () {
    final s = TasmeeSession(_words('ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ'), []);
    s.feed(['الحمد', 'لله', 'رب'], isFinal: false);
    expect(s.expected, 3); // the word being spoken shows as soon as it matches
    s.feed(['الحمد', 'لله', 'رب', 'العالمين'], isFinal: true);
    expect(s.done, isTrue);
    expect(s.mistakes, isEmpty);
  });

  test('wrong word is a mistake and stays hidden', () {
    final s = TasmeeSession(_words('ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ'), []);
    final r = s.feed(['الحمد', 'لله', 'رب', 'الكافرين'], isFinal: true);
    expect(r.mistakes, 1);
    expect(s.words[3].state, TasmeeState.mistake);
    s.newUtterance();
    s.feed(['العالمين'], isFinal: true);
    expect(s.done, isTrue);
    expect(s.words[3].missed, isTrue);
  });

  test('ya ayyuha split and basmala ignored', () {
    final s = TasmeeSession(_words('يَٰٓأَيُّهَا ٱلنَّاسُ ٱتَّقُوا۟ رَبَّكُمُ', surah: 4), []);
    s.feed(['بسم', 'الله', 'الرحمن', 'الرحيم', 'يا', 'أيها', 'الناس', 'اتقوا', 'ربكم'], isFinal: true);
    expect(s.done, isTrue);
    expect(s.mistakes, isEmpty);
  });

  test('dropped short word is not a mistake', () {
    final s = TasmeeSession(_words('قُلْ هُوَ ٱللَّهُ أَحَدٌ', surah: 112), []);
    s.feed(['قل', 'الله', 'أحد'], isFinal: true);
    expect(s.done, isTrue);
    expect(s.mistakes, isEmpty);
  });

  test('skipped long word is a mistake', () {
    final s = TasmeeSession(_words('إِنَّآ أَعْطَيْنَٰكَ ٱلْكَوْثَرَ', surah: 108), []);
    s.feed(['إنا', 'الكوثر'], isFinal: true);
    expect(s.done, isTrue);
    expect(s.mistakes.length, 1);
    expect(s.words[1].missed, isTrue);
  });

  test('last word shows while still speaking', () {
    final s = TasmeeSession(_words('ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ'), []);
    s.feed(['الحمد', 'لله', 'رب', 'العالمين'], isFinal: false);
    expect(s.done, isTrue);
  });

  test('restarting from the beginning is not a mistake', () {
    final s = TasmeeSession(
      _words('بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ مَٰلِكِ يَوْمِ ٱلدِّينِ'),
      [],
    );
    s.feed(
      'بسم الله الرحمن الرحيم الحمد لله رب العالمين الرحمن الرحيم بسم الله الرحمن الرحيم الحمد لله رب العالمين الرحمن الرحيم مالك يوم الدين'
          .split(' '),
      isFinal: true,
    );
    expect(s.mistakes, isEmpty);
    expect(s.done, isTrue);
  });

  test('repeating the last few words is not a mistake', () {
    final s = TasmeeSession(_words('ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ'), []);
    s.feed('الحمد لله رب العالمين رب العالمين الرحمن الرحيم'.split(' '), isFinal: true);
    expect(s.mistakes, isEmpty);
    expect(s.done, isTrue);
  });

  test('a new utterance continues where it stopped', () {
    final s = TasmeeSession(_words('ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ'), []);
    s.feed(['الحمد', 'لله'], isFinal: true);
    s.newUtterance();
    s.feed(['رب', 'العالمين'], isFinal: true);
    expect(s.done, isTrue);
    expect(s.mistakes, isEmpty);
  });

  test('disjoint letters recited by their names', () {
    for (final heard in [
      ['ألف', 'لام', 'ميم'],
      ['الف', 'لام', 'ميم'],
      ['الم'],
      ['ألم'],
      ['ا', 'ل', 'م'],
      ['الف', 'لاميم'],
    ]) {
      final s = TasmeeSession(_words('الٓمٓ ذَٰلِكَ ٱلْكِتَٰبُ لَا رَيْبَ', surah: 2), []);
      s.feed([...heard, 'ذلك', 'الكتاب', 'لا', 'ريب'], isFinal: true);
      expect(s.done, isTrue, reason: heard.join(' '));
      expect(s.mistakes, isEmpty, reason: heard.join(' '));
    }
  });

  test('disjoint letters while still speaking and across utterances', () {
    final s = TasmeeSession(_words('الٓمٓ ذَٰلِكَ ٱلْكِتَٰبُ', surah: 2), []);
    s.feed(['ألف', 'لام'], isFinal: false);
    expect(s.mistakes, isEmpty);
    expect(s.expected, 0);
    s.feed(['ألف', 'لام'], isFinal: true);
    expect(s.mistakes, isEmpty);
    s.newUtterance();
    s.feed(['ميم', 'ذلك', 'الكتاب'], isFinal: true);
    expect(s.done, isTrue);
    expect(s.mistakes, isEmpty);
  });

  test('other disjoint letters', () {
    final cases = {
      'كٓهيعٓصٓ': (19, ['كاف', 'ها', 'يا', 'عين', 'صاد']),
      'طه': (20, ['طاها']),
      'يسٓ': (36, ['ياسين']),
      'حمٓ': (40, ['حا', 'ميم']),
      'طسٓمٓ': (26, ['طا', 'سين', 'ميم']),
      'قٓۚ': (50, ['قاف']),
      'نٓۚ': (68, ['نون']),
      'الٓرۚ': (10, ['الف', 'لام', 'را']),
    };
    cases.forEach((text, c) {
      final s = TasmeeSession(_words(text, surah: c.$1), []);
      s.feed(c.$2, isFinal: true);
      expect(s.done, isTrue, reason: text);
      expect(s.mistakes, isEmpty, reason: text);
    });
  });

  test('a similar but different word is a mistake', () {
    final s = TasmeeSession(_words('وَلَٰكِن لَّا يَعْلَمُونَ', surah: 2, ayah: 13), []);
    s.feed(['ولكن', 'لا', 'يعملون'], isFinal: true);
    expect(s.mistakes.length, 1);
    expect(s.words[2].state, TasmeeState.mistake);
  });

  test('a wrong word that appears earlier on the page is a mistake', () {
    final w = [
      ..._words('وَمَا يَشْعُرُونَ', surah: 2, ayah: 12),
      ..._words('وَلَٰكِن لَّا يَعْلَمُونَ', surah: 2, ayah: 13),
    ];
    final s = TasmeeSession(w, []);
    s.feed(['وما', 'يشعرون', 'ولكن', 'لا'], isFinal: false);
    s.feed(['وما', 'يشعرون', 'ولكن', 'لا', 'يشعرون'], isFinal: false);
    expect(s.mistakes, isEmpty); // still being spoken
    s.feed(['وما', 'يشعرون', 'ولكن', 'لا', 'يشعرون'], isFinal: true); // pause
    expect(s.mistakes.length, 1);
    expect(s.words[4].state, TasmeeState.mistake);
  });

  test('wrong word then correcting it', () {
    final s = TasmeeSession(
      _words('ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ مَٰلِكِ يَوْمِ ٱلدِّينِ'),
      [],
    );
    s.feed('الحمد لله رب العالمين الرحمن الغفور'.split(' '), isFinal: true);
    expect(s.mistakes.length, 1);
    expect(s.words[5].state, TasmeeState.mistake);
    s.newUtterance();
    s.feed('الرحمن الرحيم مالك يوم الدين'.split(' '), isFinal: true);
    expect(s.done, isTrue);
    expect(s.mistakes.length, 1);
    expect(s.words[5].missed, isTrue);
  });
}
