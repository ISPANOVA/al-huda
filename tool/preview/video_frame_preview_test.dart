// Renders the ayah-video frames to PNGs (run in CI: see check.yml).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:al_huda/core/theme/app_themes.dart';
import 'package:al_huda/features/share_video/video_frames.dart';
import 'package:flutter/material.dart';
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

Future<ui.Image> _image(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

void main() {
  setUpAll(() async {
    await _font('UthmanicHafs', ['assets/fonts/UthmanicHafs18.ttf']);
    await _font(AppFonts.display, ['assets/fonts/ReemKufi-Bold.ttf']);
    await _font(AppFonts.ui, ['assets/fonts/Tajawal-Bold.ttf', 'assets/fonts/Tajawal-ExtraBold.ttf']);
  });

  const kursi =
      'ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ ٱلۡحَيُّ ٱلۡقَيُّومُۚ لَا تَأۡخُذُهُۥ سِنَةٞ وَلَا نَوۡمٞۚ لَّهُۥ مَا فِي ٱلسَّمَٰوَٰتِ وَمَا فِي ٱلۡأَرۡضِۗ مَن ذَا ٱلَّذِي يَشۡفَعُ عِندَهُۥٓ إِلَّا بِإِذۡنِهِۦۚ يَعۡلَمُ مَا بَيۡنَ أَيۡدِيهِمۡ وَمَا خَلۡفَهُمۡۖ وَلَا يُحِيطُونَ بِشَيۡءٖ مِّنۡ عِلۡمِهِۦٓ إِلَّا بِمَا شَآءَۚ وَسِعَ كُرۡسِيُّهُ ٱلسَّمَٰوَٰتِ وَٱلۡأَرۡضَۖ وَلَا يَـُٔودُهُۥ حِفۡظُهُمَاۚ وَهُوَ ٱلۡعَلِيُّ ٱلۡعَظِيمُ';
  const short = 'ٱلۡحَمۡدُ لِلَّهِ رَبِّ ٱلۡعَٰلَمِينَ';

  testWidgets('video frames', (tester) async {
    await tester.runAsync(() async {
      final logo = await _image('assets/icon/logo_mark.png');
      final photo = File('assets/reciters/afs.jpg').existsSync() ? await _image('assets/reciters/afs.jpg') : null;
      Directory('tool/preview/out').createSync(recursive: true);
      Future<void> save(String name, void Function(Canvas, Size) paint) async {
        final rec = ui.PictureRecorder();
        paint(Canvas(rec), const Size(540, 960));
        final img = await rec.endRecording().toImage(540, 960);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        File('tool/preview/out/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      }

      for (final bg in VideoBackground.all.where((b) => b.id != VideoBackground.custom)) {
        final p = VideoFramePainter(bg: bg, logo: logo, reciterPhoto: photo);
        await save('video_${bg.id}', (c, s) => p.paintFrame(c, s,
            const FrameContent(text: short, ayahNumber: 2, surahName: 'سورة الفاتحة', reciterName: 'مشاري راشد العفاسي', caption: 'الآية ٢')));
      }
      final gold = VideoFramePainter(bg: VideoBackground.byId('gold'), logo: logo, reciterPhoto: photo);
      final pages = VideoFramePainter.split(kursi, 255);
      expect(pages.join(' ').split(' ').length, kursi.split(' ').length);
      for (var i = 0; i < pages.length; i++) {
        await save('video_kursi_$i', (c, s) => gold.paintFrame(c, s,
            FrameContent(text: pages[i], ayahNumber: i == pages.length - 1 ? 255 : null, surahName: 'سورة البقرة', reciterName: 'محمود خليل الحصري', caption: 'الآية ٢٥٥')));
      }
      await save('video_short', (c, s) => gold.paintFrame(c, s,
          const FrameContent(text: 'الٓمٓ', ayahNumber: 1, surahName: 'سورة البقرة', reciterName: 'مشاري راشد العفاسي', caption: 'الآية ١')));
      await save('video_outro', (c, s) => gold.paintOutro(c, s));
    });
  });
}
