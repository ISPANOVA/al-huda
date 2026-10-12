// Renders the shared prayer-times picture to a PNG (run in CI: see check.yml).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:al_huda/core/theme/app_themes.dart';
import 'package:al_huda/core/widgets/share_card.dart';
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
    await _font('UthmanicHafs', ['assets/fonts/UthmanicHafs18.ttf']);
  });

  Future<ui.Image> logo() async {
    final codec = await ui.instantiateImageCodec(File('assets/icon/logo_mark.png').readAsBytesSync(), targetWidth: 512);
    return (await codec.getNextFrame()).image;
  }

  testWidgets('share cards', (tester) async {
    await tester.runAsync(() async {
      final l = await logo();
      final cards = {
        'card_thikr': const ShareCard(
            title: 'أذكار الصباح',
            body: 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
            source: 'رواه مسلم'),
        'card_asma': const ShareCard(title: 'من أسماء الله الحسنى', big: 'الرَّحْمَٰنُ', body: 'ذو الرحمة الواسعة التي وسعت كل شيء'),
        'card_quran': const ShareCard(
            title: 'آية الكرسي',
            body: 'ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ ٱلۡحَيُّ ٱلۡقَيُّومُۚ لَا تَأۡخُذُهُۥ سِنَةٞ وَلَا نَوۡمٞۚ لَّهُۥ مَا فِي ٱلسَّمَٰوَٰتِ وَمَا فِي ٱلۡأَرۡضِۗ مَن ذَا ٱلَّذِي يَشۡفَعُ عِندَهُۥٓ إِلَّا بِإِذۡنِهِۦۚ يَعۡلَمُ مَا بَيۡنَ أَيۡدِيهِمۡ وَمَا خَلۡفَهُمۡۖ وَلَا يُحِيطُونَ بِشَيۡءٖ مِّنۡ عِلۡمِهِۦٓ إِلَّا بِمَا شَآءَۚ وَسِعَ كُرۡسِيُّهُ ٱلسَّمَٰوَٰتِ وَٱلۡأَرۡضَۖ وَلَا يَـُٔودُهُۥ حِفۡظُهُمَاۚ وَهُوَ ٱلۡعَلِيُّ ٱلۡعَظِيمُ',
            source: 'البقرة: ٢٥٥',
            quran: true),
        'card_long': ShareCard(title: 'الأربعون النووية • ٢', body: List.filled(14, 'بينما نحن جلوس عند رسول الله صلى الله عليه وسلم ذات يوم إذ طلع علينا رجل شديد بياض الثياب').join('، '), source: 'رواه مسلم'),
      };
      Directory('tool/preview/out').createSync(recursive: true);
      for (final e in cards.entries) {
        File('tool/preview/out/${e.key}.png').writeAsBytesSync(await ShareCardPainter(e.value, logo: l).png());
      }
      final table = TimetableCardPainter(
        title: 'إمساكية رمضان ١٤٤٨ هـ',
        subtitle: 'القاهرة',
        header: const ['اليوم', 'الإمساك', 'الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'],
        rows: [for (var d = 1; d <= 30; d++) ['${d} • ${d}/2', '٤:٢٠', '٤:٣٠', '١٢:٠٥', '٣:٢٥', '٥:٥٢', '٧:١٠']],
        highlight: 4,
        logo: l,
      );
      File('tool/preview/out/imsakiya.png').writeAsBytesSync(await table.png());
    });
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
