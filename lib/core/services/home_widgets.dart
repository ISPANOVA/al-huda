import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/surah_metadata.dart';
import '../utils/arabic_utils.dart';

/// Pushes data to the Android home-screen widgets (prayer times with a live
/// countdown, and the daily ayah). The native side lives in
/// tool/android_kotlin/HomeWidgets.kt.
class HomeWidgets {
  HomeWidgets._();

  static const _channel = MethodChannel('alhuda/widgets');

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// [days]: for each day, the five prayers as (name, time).
  static Future<void> updatePrayers({
    required String city,
    required List<({DateTime date, List<(String, DateTime)> prayers})> days,
  }) async {
    if (!Platform.isAndroid) return;
    final payload = jsonEncode({
      'city': city,
      'days': [
        for (final d in days)
          {
            'd': _day(d.date),
            'n': [for (final p in d.prayers) p.$1],
            't': [for (final p in d.prayers) p.$2.millisecondsSinceEpoch],
          },
      ],
    });
    try {
      await _channel.invokeMethod('update', {'prayers': payload});
    } catch (e) {
      debugPrint('Widget update failed: $e');
    }
  }

  /// Daily ayahs for the next [count] days.
  static Future<void> updateAyahs(List<({DateTime date, String text, int surah, int ayah})> items) async {
    if (!Platform.isAndroid) return;
    final payload = jsonEncode([
      for (final a in items)
        {
          'd': _day(a.date),
          't': a.text,
          'r': 'سورة ${SurahMetadata.surah(a.surah).name} • ${ArabicUtils.toArabicDigits(a.ayah)}',
        },
    ]);
    try {
      await _channel.invokeMethod('update', {'ayahs': payload});
    } catch (e) {
      debugPrint('Widget update failed: $e');
    }
  }
}

/// Deterministic "ayah of the day" (global number), skipping very long ayahs
/// so it fits the dashboard card and the home-screen widget.
int dailyAyahNumber(DateTime date, int Function(int global) lengthOf) {
  final seed = date.year * 372 + date.month * 31 + date.day;
  var global = (seed * 7919) % SurahMetadata.totalAyahs + 1;
  for (var i = 0; i < 400 && lengthOf(global) > 160; i++) {
    global = global % SurahMetadata.totalAyahs + 1;
  }
  return global;
}
