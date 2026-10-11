import 'dart:io';

import 'package:al_huda/features/audio/data/reciter_art.dart';
import 'package:al_huda/features/media/media_catalog.dart';
import 'package:al_huda/features/media/reciter_photos.dart';
import 'package:flutter_test/flutter_test.dart';

/// Android Auto names its pictures by resource: each one must exist, or the
/// car shows an empty square.
void main() {
  const dir = 'tool/android_res/drawable-nodpi';

  test('every surah has its tile', () {
    for (var s = 1; s <= 114; s++) {
      expect(File('$dir/car_s_$s.webp').existsSync(), isTrue, reason: 'car_s_$s');
    }
  });

  test('every reciter and reciter radio has a tile', () {
    final keys = {
      for (final r in MediaCatalog.reciters) r.key.replaceAll('_mj', ''),
      for (final r in kReciterRadios)
        if (r.reciterKey != null) r.reciterKey!.replaceAll('_mj', ''),
    };
    for (final k in keys) {
      expect(File('$dir/car_r_$k.webp').existsSync(), isTrue, reason: 'car_r_$k');
    }
  });

  test('photo keys', () {
    for (final k in kReciterPhotos) {
      expect(File('assets/reciters/$k.jpg').existsSync(), isTrue, reason: k);
      expect(ReciterArt.keyFor(k), k);
      expect(ReciterArt.keyFor('mp3q:$k'), k);
      expect(ReciterArt.keyFor('${k}_mj'), k);
    }
    expect(ReciterArt.keyFor('ar.alafasy'), kReciterPhotos.contains('afs') ? 'afs' : null);
    expect(ReciterArt.keyFor('nobody'), isNull);
    expect(ReciterArt.keyFor(null), isNull);
  });
}
