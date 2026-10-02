import 'package:al_huda/core/theme/app_themes.dart';
import 'package:al_huda/core/widgets/gradient_background.dart';
import 'package:al_huda/core/widgets/noor_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('noor kit', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 2.625;
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppThemes.build(AppThemeType.noirGold, Brightness.dark),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(builder: (context) {
          final glass = GlassTheme.of(context);
          return GradientBackground(
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                for (final (ph, t, sun) in [
                  (SkyPhase.afternoon, 0.62, true),
                  (SkyPhase.sunset, 0.95, true),
                  (SkyPhase.night, 0.4, false),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(34),
                      child: SizedBox(
                        height: 220,
                        child: CustomPaint(
                          painter: SkyPainter(
                            phase: ph,
                            t: t,
                            sun: sun,
                            markers: const [0, 0.08, 0.45, 0.68, 0.92, 1],
                            highlighted: 3,
                            orbitTop: 0.36,
                          ),
                        ),
                      ),
                    ),
                  ),
                NoorCard(
                  child: Row(children: [
                    SizedBox(
                      width: 92,
                      height: 112,
                      child: ArchCard(
                        archHeight: 0.42,
                        padding: const EdgeInsets.fromLTRB(6, 26, 6, 8),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [glass.accent.withValues(alpha: 0.35), glass.accent.withValues(alpha: 0.08)],
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    const Spacer(),
                    NoorRing(value: 0.6, color: glass.accent, size: 58),
                  ]),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final c in [
                      [const Color(0xFF15426B), const Color(0xFF4F8DB6), const Color(0xFFF1D7A0)],
                      [const Color(0xFF1E1638), const Color(0xFF7E3048), const Color(0xFFF09A4A)],
                    ])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: SizedBox(
                            height: 210,
                            child: ArchCard(
                              archHeight: 0.42,
                              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: c),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/noor_kit.png'));
  });
}
