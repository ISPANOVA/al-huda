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
}
