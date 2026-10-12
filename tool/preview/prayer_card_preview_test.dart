// Renders the shared prayer-times picture to a PNG (run in CI: see check.yml).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:al_huda/core/theme/app_themes.dart';
import 'package:al_huda/features/prayer/presentation/prayer_share.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _font(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    final f = File(p);
    if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _font(AppFonts.display, ['assets/fonts/ReemKufi-Bold.ttf']);
    await _font(AppFonts.ui, ['assets/fonts/Tajawal-Bold.ttf', 'assets/fonts/Tajawal-ExtraBold.ttf']);
  });

  testWidgets('prayer card', (tester) async {
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(File('assets/icon/logo_mark.png').readAsBytesSync(), targetWidth: 512);
      final logo = (await codec.getNextFrame()).image;
      const data = PrayerCardData(
        city: 'القاهرة',
        gregorian: 'الثلاثاء ١٣ أكتوبر ٢٠٢٦',
        hijri: '٢ جمادى الأولى ١٤٤٨ هـ',
        times: [('الفجر', '٥:٢٨ ص'), ('الشروق', '٦:٥٥ ص'), ('الظهر', '١٢:٤٣ م'), ('العصر', '٣:٥٩ م'), ('المغرب', '٦:٢٨ م'), ('العشاء', '٧:٤٥ م')],
        next: 3,
      );
      final png = await PrayerCardPainter(data, logo: logo).png();
      Directory('tool/preview/out').createSync(recursive: true);
      File('tool/preview/out/prayer_card.png').writeAsBytesSync(png);
      expect(data.shareText, contains('القاهرة'));
    });
  });
}
