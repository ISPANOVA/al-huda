import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications: prayer alerts, Khatmah and Athkar daily reminders.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Payload of a tapped notification (e.g. 'athkar:prayer'); the home shell
  /// listens and opens the matching screen.
  static final ValueNotifier<String?> openRequest = ValueNotifier(null);

  /// Small status-bar icon (white crescent) copied into the Android project by
  /// tool/configure_platforms.dart.
  static const String smallIcon = 'ic_stat_alhuda';

  /// Accent colour of notifications; follows the selected app theme.
  Color accent = const Color(0xFF0F9D74);

  AndroidNotificationDetails get _prayerChannel => AndroidNotificationDetails(
        'alhuda_prayer',
        'مواقيت الصلاة',
        channelDescription: 'تنبيهات دخول وقت الصلاة',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        icon: smallIcon,
        color: accent,
        colorized: true,
      );

  AndroidNotificationDetails get _reminderChannel => AndroidNotificationDetails(
        'alhuda_reminders',
        'التذكيرات اليومية',
        channelDescription: 'تذكير ورد الختمة والأذكار',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: smallIcon,
        color: accent,
      );

  /// Adhan channel for a voice + mode. Android fixes a channel's sound when
  /// it is created, so every voice/mode combination has its own channel.
  AndroidNotificationDetails _adhanChannel(String voice, String voiceName, bool full) {
    final useDefault = voice == 'default';
    final sound = '${full ? 'adhan' : 'takbeer'}_$voice';
    return AndroidNotificationDetails(
      useDefault ? 'alhuda_prayer' : 'alhuda_adhan_${sound}_v1',
      useDefault ? 'مواقيت الصلاة' : 'الأذان (${full ? 'كامل' : 'تكبيرات'}) – $voiceName',
      channelDescription: 'تنبيه الأذان عند دخول وقت الصلاة',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      sound: useDefault ? null : RawResourceAndroidNotificationSound(sound),
      audioAttributesUsage: useDefault ? AudioAttributesUsage.notification : AudioAttributesUsage.alarm,
      icon: smallIcon,
      color: accent,
      colorized: true,
    );
  }

  /// Prayer-time notification with the chosen adhan voice (exact timing).
  Future<void> scheduleAdhan({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String voice,
    required String voiceName,
    required bool full,
  }) async {
    if (when.isBefore(DateTime.now())) return;
    final details = NotificationDetails(android: _adhanChannel(voice, voiceName, full), iOS: _darwin);
    await _schedule(id, title, body, when, details);
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Whether exact alarms are allowed (Android 12+). Without it an exact
  /// schedule is silently dropped by the plugin, so we fall back to inexact.
  Future<bool> canScheduleExact() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _android?.canScheduleExactNotifications() ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Opens the system screen to allow exact alarms when it is not granted.
  Future<bool> ensureExactAlarms() async {
    if (await canScheduleExact()) return true;
    try {
      await _android?.requestExactAlarmsPermission();
    } catch (_) {}
    return canScheduleExact();
  }

  Future<void> _schedule(int id, String title, String body, DateTime when, NotificationDetails details,
      {String? payload}) async {
    final exact = await canScheduleExact();
    final date = tz.TZDateTime.from(when, tz.local);
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: date,
        notificationDetails: details,
        androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Exact schedule failed, falling back to inexact: $e');
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: date,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    }
  }

  /// "أذكار بعد الصلاة" reminder; tapping it opens the athkar list.
  Future<void> schedulePostPrayer({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    if (when.isBefore(DateTime.now())) return;
    await _schedule(id, title, body, when, NotificationDetails(android: _reminderChannel, iOS: _darwin),
        payload: 'athkar:prayer');
  }

  /// Schedules a test adhan [seconds] from now (checks the whole pipeline).
  Future<void> scheduleAdhanTest({
    required String voice,
    required String voiceName,
    required bool full,
    int seconds = 10,
  }) async {
    await _schedule(
      98,
      'تجربة الأذان 🕌',
      'هكذا سيصلك التنبيه عند دخول وقت الصلاة',
      DateTime.now().add(Duration(seconds: seconds)),
      NotificationDetails(android: _adhanChannel(voice, voiceName, full), iOS: _darwin),
    );
  }

  /// "X minutes before the adhan" reminder (normal notification sound).
  Future<void> schedulePreAdhan({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    if (when.isBefore(DateTime.now())) return;
    await _schedule(id, title, body, when, NotificationDetails(android: _preAdhanChannel, iOS: _darwin));
  }

  AndroidNotificationDetails get _preAdhanChannel => AndroidNotificationDetails(
        'alhuda_pre_adhan',
        'تنبيه قبل الأذان',
        channelDescription: 'تذكير قبل دخول وقت الصلاة',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        icon: smallIcon,
        color: accent,
      );

  static const _darwin = DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBadge: false);

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Timezone fallback to UTC: $e');
      tz.setLocalLocation(tz.UTC);
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/$smallIcon'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (r) => openRequest.value = r.payload,
    );
    _initialized = true;
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) openRequest.value = launch!.notificationResponse?.payload;
    } catch (_) {}
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, badge: false, sound: true) ?? false;
    }
    return false;
  }

  /// One-shot notification at an absolute time (used for prayer times).
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    if (when.isBefore(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: NotificationDetails(android: _prayerChannel, iOS: _darwin),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Repeats every day at [hour]:[minute] local time.
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: next,
      notificationDetails: NotificationDetails(android: _reminderChannel, iOS: _darwin),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Immediately shows a prayer alert with the chosen adhan (settings test).
  Future<void> showAdhanNow({required String voice, required String voiceName, required bool full}) async {
    await _plugin.show(
      id: 99,
      title: 'تجربة تنبيه الأذان 🕌',
      body: 'هكذا سيصلك التنبيه عند دخول وقت الصلاة',
      notificationDetails: NotificationDetails(android: _adhanChannel(voice, voiceName, full), iOS: _darwin),
    );
  }

  /// Cancels only notifications in [fromId, fromId + count) that are still
  /// waiting to fire. Already-delivered ones (an adhan that is ringing right
  /// now) are left alone.
  Future<void> cancelPendingRange(int fromId, int count) async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.id >= fromId && p.id < fromId + count) await _plugin.cancel(id: p.id);
      }
    } catch (e) {
      debugPrint('pendingNotificationRequests failed: $e');
    }
  }

  Future<void> cancel(int id) => _plugin.cancel(id: id);

  Future<void> cancelRange(int fromId, int count) async {
    for (var i = 0; i < count; i++) {
      await _plugin.cancel(id: fromId + i);
    }
  }
}
