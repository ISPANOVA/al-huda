// Renders a recitation-test page drawn by the Mushaf painter (CI preview).
import 'dart:io';

import 'package:al_huda/core/theme/app_themes.dart';
import 'package:al_huda/features/quran/data/datasources/bundled_quran_data_source.dart';
import 'package:al_huda/features/quran/data/repositories/quran_repository_impl.dart';
import 'package:al_huda/features/quran/presentation/mushaf/mushaf_page.dart';
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

void main() {
  setUpAll(() async {
    await _font('UthmanicHafs', ['assets/fonts/UthmanicHafs18.ttf']);
  });

  testWidgets('tasmee on the mushaf page', (tester) async {
    tester.view.physicalSize = const Size(1080, 1900);
    tester.view.devicePixelRatio = 2.625;
    final repo = QuranRepositoryImpl(BundledQuranDataSource());
    await tester.runAsync(() => repo.ensureLoaded());
    const page = 3;
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppThemes.build(AppThemeType.noirGold, Brightness.dark),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(builder: (context) {
          final style = MushafStyle.of(context);
          final glass = GlassTheme.of(context);
          return Scaffold(
            backgroundColor: Colors.black,
            body: Padding(
              padding: const EdgeInsets.all(10),
              child: MushafPageView(
                page: page,
                lines: repo.linesOnPage(page),
                referenceWidth: repo.referenceLineWidth,
                style: style,
                onAyahTap: (_) {},
                wordPaint: (k) {
                  if (k == 8) return const MushafWordPaint(color: Color(0xFFE5484D));
                  if (k == 12) return MushafWordPaint(color: glass.accent);
                  if (k < 30) return null;
                  if (k == 30) {
                    return MushafWordPaint(
                      hidden: true,
                      background: glass.accent.withValues(alpha: 0.10),
                      underline: glass.accent,
                      underlineWidth: 2.4,
                    );
                  }
                  if (k == 31) {
                    return const MushafWordPaint(hidden: true, underline: Color(0xFFE5484D), underlineWidth: 2.4);
                  }
                  return MushafWordPaint(hidden: true, underline: glass.onGlass.withValues(alpha: 0.22));
                },
              ),
            ),
          );
        }),
      ),
    ));
    await tester.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/tasmee_mushaf.png'));
  });
}
