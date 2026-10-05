import 'dart:io';

import 'package:al_huda/features/media/waving_flag.dart';
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
  setUpAll(() => _font('ReemKufi', ['assets/fonts/ReemKufi-Bold.ttf']));
  for (final kind in FlagKind.values) {
    for (final waving in [false, true]) {
      testWidgets('flag ${kind.name} ${waving ? 'waving' : 'still'}', (tester) async {
        tester.view.physicalSize = const Size(720, 400);
        tester.view.devicePixelRatio = 2;
        final key = GlobalKey();
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(width: 360, height: 200, child: WavingFlag(kind: kind, waving: waving)),
            ),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 450));
        await expectLater(find.byKey(key), matchesGoldenFile('out/flag_${kind.name}_${waving ? 'waving' : 'still'}.png'));
      });
    }
  }
}
