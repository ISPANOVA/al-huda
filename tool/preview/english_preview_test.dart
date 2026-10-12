// The More page in English (left to right) and in Arabic, as PNGs.
import 'dart:convert';
import 'dart:io';

import 'package:al_huda/core/i18n/i18n.dart';
import 'package:al_huda/core/theme/app_themes.dart';
import 'package:al_huda/core/widgets/gradient_background.dart';
import 'package:al_huda/features/home/presentation/more_page.dart';
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
    await _font(AppFonts.display, ['assets/fonts/ReemKufi-Bold.ttf']);
    await _font(AppFonts.ui, ['assets/fonts/Tajawal-Regular.ttf', 'assets/fonts/Tajawal-Bold.ttf', 'assets/fonts/Tajawal-ExtraBold.ttf']);
    final root = Platform.environment['FLUTTER_ROOT'] ?? '';
    await _font('MaterialIcons', ['$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  });

  for (final lang in ['en', 'ar']) {
    testWidgets('more page $lang', (tester) async {
      final j = jsonDecode(File('assets/i18n/en.json').readAsStringSync()) as Map<String, dynamic>;
      I18n.setData(Map<String, String>.from(j['map'] as Map), Map<String, String>.from(j['vocab'] as Map));
      I18n.en = lang == 'en';
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.625;
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppThemes.build(AppThemeType.noirGold, Brightness.dark),
        home: Directionality(
          textDirection: I18n.direction,
          child: const GradientBackground(child: Material(type: MaterialType.transparency, child: MorePage())),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
      await expectLater(find.byType(MorePage), matchesGoldenFile('out/more_$lang.png'));
      I18n.en = false;
    });
  }
}
