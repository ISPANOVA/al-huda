import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android-only bridge to the native adhan player (AdhanAlarm.kt). It plays on
/// the alarm stream, so the adhan is heard even in silent / vibrate mode.
class AdhanNative {
  AdhanNative._();

  static const _ch = MethodChannel('alhuda/adhan');

  static bool get supported => !kIsWeb && Platform.isAndroid;

  /// Raw resource name for a voice ('default' falls back to the system alarm tone).
  static String sound(String voice, bool full) => voice == 'default' ? '' : '${full ? 'adhan' : 'takbeer'}_$voice';

  /// Replaces the whole native schedule.
  static Future<bool> schedule(List<({int id, DateTime at, String sound, String title, String body})> items) async {
    if (!supported) return false;
    try {
      await _ch.invokeMethod('schedule', {
        'items': [
          for (final i in items)
            {'id': i.id, 'at': i.at.millisecondsSinceEpoch, 'sound': i.sound, 'title': i.title, 'body': i.body},
        ],
      });
      return true;
    } catch (e) {
      debugPrint('AdhanNative.schedule failed: $e');
      return false;
    }
  }

  static Future<void> cancelAll() async {
    if (!supported) return;
    try {
      await _ch.invokeMethod('cancelAll');
    } catch (_) {}
  }

  static Future<bool> test({required String sound, int seconds = 10}) async {
    if (!supported) return false;
    try {
      await _ch.invokeMethod('test', {
        'seconds': seconds,
        'sound': sound,
        'title': 'تجربة الأذان 🕌',
        'body': 'هكذا سيُرفع الأذان حتى لو كان الهاتف صامتًا',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stop() async {
    if (!supported) return;
    try {
      await _ch.invokeMethod('stop');
    } catch (_) {}
  }
}
