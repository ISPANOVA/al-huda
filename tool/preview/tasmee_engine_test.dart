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

  test('a mistake judged after a pause is cancelled when the word is corrected', () {
    final s = TasmeeSession(_words('وَلَٰكِن لَّا يَعْلَمُونَ قَالُوا', surah: 2, ayah: 13), []);
    s.feed(['ولكن', 'لا', 'يعلم'], isFinal: false);
    s.feed(['ولكن', 'لا', 'يعلم'], isFinal: true); // pause
    expect(s.mistakes.length, 1);
    s.feed(['ولكن', 'لا', 'يعلمون'], isFinal: true); // recogniser corrects it
    expect(s.mistakes, isEmpty);
    expect(s.words[2].missed, isFalse);
    expect(s.expected, 3);
  });

  test('a real mistake after a pause stays', () {
    final s = TasmeeSession(_words('وَلَٰكِن لَّا يَعْلَمُونَ قَالُوا', surah: 2, ayah: 13), []);
    s.feed(['ولكن', 'لا', 'يشعرون'], isFinal: true);
    s.feed(['ولكن', 'لا', 'يشعرون'], isFinal: true);
    expect(s.mistakes.length, 1);
  });

  test('recogniser merging words does not shift the position', () {
    final s = TasmeeSession(_words('يَٰٓأَيُّهَا ٱلنَّاسُ ٱعْبُدُوا۟ رَبَّكُمُ ٱلَّذِى خَلَقَكُمْ', surah: 2, ayah: 21), []);
    s.feed(['يا', 'أيها', 'الناس'], isFinal: false);
    s.feed(['ياأيها', 'الناس', 'اعبدوا', 'ربكم', 'الذي', 'خلقكم'], isFinal: true);
    expect(s.mistakes, isEmpty);
    expect(s.done, isTrue);
  });

  test('another transcript of the recogniser is accepted', () {
    final s = TasmeeSession(_words('ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ'), []);
    s.feed(
      ['الحمد', 'لله', 'رب', 'العاملين'],
      isFinal: true,
      alternates: [
        ['الحمد', 'لله', 'رب', 'العالمين'],
      ],
    );
    expect(s.mistakes, isEmpty);
    expect(s.done, isTrue);
  });

  test('letters the recogniser confuses', () {
    expect(TasmeeMatcher.similar(TasmeeMatcher.key('الذين'), TasmeeMatcher.key('ٱلَّزِينَ')), isTrue);
    expect(TasmeeMatcher.similar(TasmeeMatcher.key('يعلمون'), TasmeeMatcher.key('يَشْعُرُونَ')), isFalse);
    expect(TasmeeMatcher.similar(TasmeeMatcher.key('يعملون'), TasmeeMatcher.key('يَعْلَمُونَ')), isFalse);
  });

  test('noise between correct words is not a mistake', () {
    final s = TasmeeSession(_words('ذَهَبَ ٱللَّهُ بِنُورِهِمْ وَتَرَكَهُمْ', surah: 2, ayah: 17), []);
    s.feed(['ذهب', 'اه', 'الله', 'بنورهم', 'وتركهم'], isFinal: true);
    expect(s.mistakes, isEmpty);
    expect(s.done, isTrue);
  });

  test('a rewritten transcript is judged again from scratch', () {
    final s = TasmeeSession(_words('صُمٌّ بُكْمٌ عُمْيٌ فَهُمْ لَا يَرْجِعُونَ', surah: 2, ayah: 18), []);
    s.feed(['صم', 'يبكون', 'عمي'], isFinal: false); // early guess
    s.feed(['صم', 'بكم', 'عمي', 'فهم'], isFinal: false); // recogniser corrected itself
    expect(s.mistakes, isEmpty);
    expect(s.expected, 4);
    expect(s.words[1].missed, isFalse);
  });

  test('words are not revealed unless they were heard', () {
    final s = TasmeeSession(
      _words('يَكَادُ ٱلْبَرْقُ يَخْطَفُ أَبْصَٰرَهُمْ كُلَّمَآ أَضَآءَ لَهُم مَّشَوْا۟ فِيهِ', surah: 2, ayah: 20),
      [],
    );
    s.feed(['يكاد', 'البرق', 'يخطف'], isFinal: true);
    expect(s.expected, 3);
    expect(s.words.skip(3).every((w) => w.state == TasmeeState.hidden), isTrue);
    s.newUtterance();
    s.feed(['أبصارهم', 'كلما', 'أضاء', 'لهم', 'مشوا', 'فيه'], isFinal: true);
    expect(s.mistakes, isEmpty);
    expect(s.done, isTrue);
  });

  test('a wrong word followed by the rest of the ayah is shown red and passed', () {
    final s = TasmeeSession(_words('صُمٌّ بُكْمٌ عُمْيٌ فَهُمْ لَا يَرْجِعُونَ', surah: 2, ayah: 18), []);
    s.feed(['صم', 'عرج', 'عمي', 'فهم', 'لا', 'يرجعون'], isFinal: true);
    expect(s.mistakes.length, 1);
    expect(s.words[1].missed, isTrue);
    expect(s.done, isTrue);
  });

  test('growing partial results with half-spoken last words make no mistakes', () {
    const uthmani = 'مَثَلُهُمْ كَمَثَلِ ٱلَّذِى ٱسْتَوْقَدَ نَارًا فَلَمَّآ أَضَآءَتْ مَا حَوْلَهُۥ ذَهَبَ ٱللَّهُ بِنُورِهِمْ وَتَرَكَهُمْ فِى ظُلُمَٰتٍ لَّا يُبْصِرُونَ';
    const plain = 'مثلهم كمثل الذي استوقد نارا فلما أضاءت ما حوله ذهب الله بنورهم وتركهم في ظلمات لا يبصرون';
    final s = TasmeeSession(_words(uthmani, surah: 2, ayah: 17), []);
    final said = plain.split(' ');
    for (var n = 1; n <= said.length; n++) {
      final w = said.sublist(0, n);
      final half = [...w.sublist(0, n - 1), w.last.substring(0, (w.last.length / 2).ceil())];
      s.feed(half, isFinal: false); // the word is still being spoken
      s.feed(w, isFinal: false);
    }
    s.feed(said, isFinal: true);
    expect(s.mistakes, isEmpty);
    expect(s.done, isTrue);
  });

  test('a fresh transcript mid-listening continues instead of starting over', () {
    final s = TasmeeSession(
      _words('قُلْ هُوَ ٱللَّهُ أَحَدٌ ٱللَّهُ ٱلصَّمَدُ', surah: 112) +
          _words('قُلْ أَعُوذُ بِرَبِّ ٱلْفَلَقِ', surah: 113),
      [],
    );
    s.feed('قل هو الله أحد الله الصمد'.split(' '), isFinal: false);
    expect(s.expected, 6);
    // The recogniser now reports only the new sentence (same utterance).
    s.feed(['قل'], isFinal: false);
    s.feed('قل أعوذ برب الفلق'.split(' '), isFinal: false);
    expect(s.mistakes, isEmpty);
    expect(s.done, isTrue);
    expect(s.words[1].state, TasmeeState.correct);
  });

  test('a fresh transcript right after a page change is read from its start', () {
    final first = TasmeeSession(_words('قُلْ هُوَ ٱللَّهُ ٱلصَّمَدُ', surah: 112), []);
    first.feed('قل هو الله الصمد'.split(' '), isFinal: false);
    expect(first.done, isTrue);
    final s = TasmeeSession(_words('قُلْ أَعُوذُ بِرَبِّ ٱلْفَلَقِ', surah: 113), [],
        consumed: first.consumed, heard: first.lastHeard);
    s.feed('قل أعوذ'.split(' '), isFinal: false);
    s.feed('قل أعوذ برب الفلق'.split(' '), isFinal: false);
    expect(s.mistakes, isEmpty);
    expect(s.done, isTrue);
  });

  List<TasmeeWord> ikhlasFalaq() =>
      _words('قُلْ هُوَ ٱللَّهُ أَحَدٌ ٱللَّهُ ٱلصَّمَدُ', surah: 112) + _words('قُلْ أَعُوذُ بِرَبِّ ٱلْفَلَقِ', surah: 113);

  test('an empty result between sentences does not erase progress', () {
    final s = TasmeeSession(ikhlasFalaq(), []);
    s.feed('قل هو الله أحد الله الصمد'.split(' '), isFinal: false);
    s.feed([], isFinal: false);
    s.feed('أعوذ برب الفلق'.split(' '), isFinal: false);
    expect(s.words.take(6).every((w) => w.state == TasmeeState.correct), isTrue);
    expect(s.mistakes, isEmpty);
    expect(s.done, isTrue);
  });

  test('listening restarted while the transcript continues', () {
    final s = TasmeeSession(ikhlasFalaq(), []);
    s.feed('قل هو الله أحد الله الصمد'.split(' '), isFinal: false);
    s.newUtterance();
    s.feed('قل هو الله أحد الله الصمد قل أعوذ برب الفلق'.split(' '), isFinal: false);
    expect(s.mistakes, isEmpty);
    expect(s.done, isTrue);
  });

  test('progress never goes back to an earlier surah', () {
    final s = TasmeeSession(ikhlasFalaq(), []);
    s.feed('قل هو الله أحد الله الصمد'.split(' '), isFinal: false);
    s.feed('قل هو أعوذ برب'.split(' '), isFinal: false); // odd rewrite
    expect(s.expected, greaterThanOrEqualTo(6));
    expect(s.words.take(6).every((w) => w.state == TasmeeState.correct), isTrue);
  });

  test('a word still being spoken is judged once the reciter goes on or pauses', () {
    final s = TasmeeSession(_words('ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ'), []);
    var r = s.feed(['الحمد', 'لله', 'رب', 'الكافرين'], isFinal: false);
    expect(r.mistakes, 0); // the recogniser may still rewrite its guess
    r = s.feed(['الحمد', 'لله', 'رب', 'الكافرين'], isFinal: true);
    expect(r.mistakes, 1);
    expect(s.words[3].state, TasmeeState.mistake);
  });

  test('the beginning of the expected word is not a mistake', () {
    final s = TasmeeSession(_words('ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ'), []);
    s.feed(['الحمد', 'لله', 'رب', 'العا'], isFinal: false);
    expect(s.mistakes, isEmpty);
  });

  test('short words differing by one letter are different words', () {
    final k = TasmeeMatcher.key;
    expect(TasmeeMatcher.similar(k('عليك'), k('إِلَيْكَ')), isFalse);
    expect(TasmeeMatcher.similar(k('عليهم'), k('إِلَيْهِمْ')), isFalse);
    expect(TasmeeMatcher.similar(k('لكم'), k('لَهُمْ')), isFalse);
    expect(TasmeeMatcher.similar(k('في'), k('عَلَىٰ')), isFalse);
    // …but spelling variants still match.
    expect(TasmeeMatcher.similar(k('إليك'), k('إِلَيْكَ')), isTrue);
    expect(TasmeeMatcher.similar(k('رؤوف'), k('رَءُوفٌ')), isTrue);
    expect(TasmeeMatcher.similar(k('الحياة'), k('ٱلْحَيَوٰةِ')), isTrue);
    expect(TasmeeMatcher.similar(k('الزكاة'), k('ٱلزَّكَوٰةَ')), isTrue);
    expect(TasmeeMatcher.similar(k('الربا'), k('ٱلرِّبَوٰا۟')), isTrue);
    expect(TasmeeMatcher.similar(k('السماوات'), k('ٱلسَّمَٰوَٰتِ')), isTrue);
    expect(TasmeeMatcher.similar(k('أولئك'), k('أُو۟لَٰٓئِكَ')), isTrue);
  });

  test('في instead of على is a mistake even if another transcript has على', () {
    final s = TasmeeSession(_words('أُو۟لَٰٓئِكَ عَلَىٰ هُدًى مِّن رَّبِّهِمْ', surah: 2, ayah: 5), []);
    s.feed(
      'اولئك في هدى من ربهم'.split(' '),
      isFinal: true,
      alternates: ['اولئك على هدى من ربهم'.split(' ')],
    );
    expect(s.mistakes.length, 1);
    expect(s.words[1].missed, isTrue);
    expect(s.done, isTrue);
  });

  test('عليك instead of إليك is a mistake', () {
    final s = TasmeeSession(_words('بِمَآ أُنزِلَ إِلَيْكَ وَمَآ أُنزِلَ مِن قَبْلِكَ', surah: 2, ayah: 4), []);
    s.feed(
      'بما انزل عليك وما انزل من قبلك'.split(' '),
      isFinal: true,
      alternates: ['بما انزل إليك وما انزل من قبلك'.split(' ')],
    );
    expect(s.mistakes.length, 1);
    expect(s.words[2].missed, isTrue);
    expect(s.done, isTrue);
  });

  test('the correct ayah still has no mistakes', () {
    final s = TasmeeSession(
      _words('وَٱلَّذِينَ يُؤْمِنُونَ بِمَآ أُنزِلَ إِلَيْكَ وَمَآ أُنزِلَ مِن قَبْلِكَ وَبِٱلْءَاخِرَةِ هُمْ يُوقِنُونَ', surah: 2, ayah: 4),
      [],
    );
    s.feed('والذين يؤمنون بما أنزل إليك وما أنزل من قبلك وبالآخرة هم يوقنون'.split(' '), isFinal: true);
    expect(s.mistakes, isEmpty);
    expect(s.done, isTrue);
  });
}
