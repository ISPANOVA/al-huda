// Renders parts of the media section to PNGs (run in CI: see check.yml).
import 'dart:io';

import 'package:al_huda/core/theme/app_themes.dart';
import 'package:al_huda/features/media/media_catalog.dart';
import 'package:al_huda/features/media/media_page.dart';
import 'package:al_huda/features/media/media_widgets.dart';
import 'package:al_huda/features/media/reciter_pages.dart';
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

Widget _app(Widget child, Brightness b) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppThemes.build(AppThemeType.noirGold, b).copyWith(
        textTheme: AppThemes.build(AppThemeType.noirGold, b).textTheme.apply(fontFamily: 'Cairo'),
      ),
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

void main() {
  setUpAll(() async {
    final root = Platform.environment['FLUTTER_ROOT'] ?? '';
    await _font('MaterialIcons', ['$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    await _font('Cairo', ['/tmp/Cairo.ttf']);
    await _font('Roboto', ['/tmp/Cairo.ttf']);
    await _font('UthmanicHafs', ['assets/fonts/UthmanicHafs18.ttf']);
  });

  for (final b in Brightness.values) {
    testWidgets('hub ${b.name}', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.625;
      await tester.pumpWidget(_app(
        DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: 'Cairo'),
          child: Builder(
            builder: (context) => Scaffold(
              body: SafeArea(
                child: ListView(
                  children: [
                    const MediaHeader(),
                    const LiveCarousel(),
                    const MediaSectionHeader('الإذاعات', subtitle: 'بث متواصل على مدار الساعة'),
                    const MediaSectionHeader('القرّاء', subtitle: 'المصحف كاملًا', action: 'الكل (٤٨)'),
                    SizedBox(
                      height: 206,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          for (final r in MediaCatalog.featured.take(4))
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: SizedBox(width: 142, child: ReciterCard(reciter: r)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        StarNumber(number: 18, color: GlassTheme.of(context).accent),
                        Equalizer(playing: false, color: GlassTheme.of(context).accent, size: 22),
                        const LiveBadge(),
                        MonogramAvatar(name: 'محمد صديق المنشاوي', seed: 'minsh', size: 70),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        b,
      ));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/hub_${b.name}.png'));
    });
  }

  testWidgets('all reciters', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    await tester.pumpWidget(_app(const AllRecitersPage(), Brightness.dark));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/all_reciters.png'));
  });
}
