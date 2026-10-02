import 'package:al_huda/core/theme/app_themes.dart';
import 'package:al_huda/core/widgets/background_patterns.dart';
import 'package:al_huda/core/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final b in [Brightness.dark, Brightness.light]) {
    for (final p in BgPattern.values) {
      if (p == BgPattern.none) continue;
      if (b == Brightness.light && p != BgPattern.khatam && p != BgPattern.mihrab) continue;
      testWidgets('pattern ${p.name} ${b.name}', (tester) async {
        tester.view.physicalSize = const Size(540, 1170);
        tester.view.devicePixelRatio = 1.3;
        BackgroundStyle.set(p, 1.0);
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppThemes.build(AppThemeType.noirGold, b),
          home: const GradientBackground(child: SizedBox.expand()),
        ));
        await expectLater(find.byType(GradientBackground), matchesGoldenFile('out/pat_${p.name}_${b.name}.png'));
      });
    }
  }
}
