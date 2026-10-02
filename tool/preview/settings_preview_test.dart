import 'package:al_huda/core/theme/app_themes.dart';
import 'package:al_huda/core/widgets/glass_container.dart';
import 'package:al_huda/core/widgets/gradient_background.dart';
import 'package:al_huda/core/widgets/noor_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('settings look ${b.name}', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 2.625;
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppThemes.build(AppThemeType.noirGold, b),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(builder: (context) {
            final glass = GlassTheme.of(context);
            return GradientBackground(
              child: Material(
                type: MaterialType.transparency,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const GlassSectionTitle('القراءة والخط'),
                    GlassContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Column(children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.text_fields_rounded, color: glass.accent),
                          title: const Text('xxxx'),
                          subtitle: const Text('yyyy'),
                        ),
                        SwitchListTile(contentPadding: EdgeInsets.zero, value: true, onChanged: (_) {}, title: const Text('zzzz')),
                      ]),
                    ),
                    const GlassSectionTitle('التنبيهات'),
                    GlassContainer(child: GlassProgressBar(value: 0.6)),
                    const SizedBox(height: 16),
                    GlassContainer(tint: glass.accent, opacity: 0.32, child: const SizedBox(height: 40)),
                    const SizedBox(height: 16),
                    Row(children: [
                      for (final i in [Icons.menu_book_rounded, Icons.favorite_rounded, Icons.explore_rounded, Icons.add_rounded])
                        Expanded(
                          child: Center(
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(19),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [glass.accent.withValues(alpha: 0.22), glass.accent.withValues(alpha: 0.08)],
                                ),
                                border: Border.all(color: glass.accent.withValues(alpha: 0.22)),
                              ),
                              child: Icon(i, color: glass.accent, size: 25),
                            ),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 150,
                      child: Row(children: [
                        Expanded(
                          child: ArchCard(
                            archHeight: 0.16,
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF15426B), Color(0xFF4F8DB6), Color(0xFFF1D7A0)],
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ArchCard(
                            archHeight: 0.16,
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF0B2A24), Color(0xFF1E5E4E), Color(0xFFC9A44C)],
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 130,
                      child: ArchCard(archHeight: 0.08, child: const SizedBox.expand()),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/settings_${b.name}.png'));
    });
  }
}
