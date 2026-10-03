import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_themes.dart';

class SettingsState extends Equatable {
  final AppThemeType themeType;
  final ThemeMode themeMode;
  final double quranFontSize;
  final double lineHeight;
  final QuranFont quranFont;
  final bool showTafseer;
  final String reciterId;
  final double playbackSpeed;
  final bool autoFollowAudio;
  final String calcMethod;
  final String madhab;
  final bool prayerNotifications;
  final bool athkarReminders;
  final bool hapticFeedback;

  /// Minute offsets for [fajr, sunrise, dhuhr, asr, maghrib, isha].
  final List<int> prayerAdjustments;

  /// Adhan voice id (see AdhanVoices) and full adhan vs. takbeers only.
  final String adhanVoice;
  final bool adhanFull;

  /// Optional reminder N minutes before each adhan.
  final bool preAdhanEnabled;
  final int preAdhanMinutes;

  /// Per-prayer alerts for [fajr, dhuhr, asr, maghrib, isha].
  final List<bool> prayerAlerts;

  /// Reminder to read the post-prayer athkar N minutes after each adhan.
  final bool postPrayerAthkar;

  /// Silent reminder at the usual iqama time.
  final bool iqamaReminder;
  final int postPrayerMinutes;

  /// Smart daily wird: pages per day (0 = off).
  final int wirdPages;

  /// The user's own theme colours (ARGB): primary, accent, background.
  final int customPrimary;
  final int customAccent;
  final int customBackground;

  /// Index into BgPattern and its intensity (0.4 – 2.0).
  final int bgPattern;

  /// Play the adhan on the alarm stream so silent/vibrate mode doesn't mute it.
  final bool adhanAlwaysPlay;

  /// Reminders the evening before occasions / recommended fasts, and Friday.
  final bool occasionReminders;

  /// Optional reminder at sunrise (الشروق).
  final bool sunriseAlert;
  final double patternStrength;

  /// Home-screen widgets background: 0 = transparent, 1 = solid card.
  final double widgetOpacity;

  /// Home-screen widgets text colour (ARGB).
  final int widgetTextColor;

  const SettingsState({
    this.themeType = AppThemeType.noirGold,
    this.themeMode = ThemeMode.dark,
    this.quranFontSize = 26,
    this.lineHeight = 2.0,
    this.quranFont = QuranFont.amiriQuran,
    this.showTafseer = false,
    this.reciterId = 'ar.alafasy',
    this.playbackSpeed = 1.0,
    this.autoFollowAudio = true,
    this.calcMethod = 'egyptian',
    this.madhab = 'shafi',
    this.prayerNotifications = true,
    this.athkarReminders = false,
    this.hapticFeedback = true,
    this.prayerAdjustments = const [0, 0, 0, 0, 0, 0],
    this.adhanVoice = 'makkah',
    this.adhanFull = true,
    this.preAdhanEnabled = false,
    this.preAdhanMinutes = 10,
    this.prayerAlerts = const [true, true, true, true, true],
    this.postPrayerAthkar = true,
    this.iqamaReminder = true,
    this.postPrayerMinutes = 15,
    this.wirdPages = 0,
    this.customPrimary = 0xFFC9A44C,
    this.customAccent = 0xFFE2C275,
    this.customBackground = 0xFF000000,
    this.bgPattern = 1,
    this.adhanAlwaysPlay = true,
    this.occasionReminders = true,
    this.sunriseAlert = false,
    this.patternStrength = 1.0,
    this.widgetOpacity = 1.0,
    this.widgetTextColor = 0xFFFFFFFF,
  });

  SettingsState copyWith({
    AppThemeType? themeType,
    ThemeMode? themeMode,
    double? quranFontSize,
    double? lineHeight,
    QuranFont? quranFont,
    bool? showTafseer,
    String? reciterId,
    double? playbackSpeed,
    bool? autoFollowAudio,
    String? calcMethod,
    String? madhab,
    bool? prayerNotifications,
    bool? athkarReminders,
    bool? hapticFeedback,
    List<int>? prayerAdjustments,
    String? adhanVoice,
    bool? adhanFull,
    bool? preAdhanEnabled,
    int? preAdhanMinutes,
    List<bool>? prayerAlerts,
    bool? postPrayerAthkar,
    bool? iqamaReminder,
    int? postPrayerMinutes,
    int? wirdPages,
    int? customPrimary,
    int? customAccent,
    int? customBackground,
    int? bgPattern,
    bool? adhanAlwaysPlay,
    bool? occasionReminders,
    bool? sunriseAlert,
    double? patternStrength,
    double? widgetOpacity,
    int? widgetTextColor,
  }) {
    return SettingsState(
      themeType: themeType ?? this.themeType,
      themeMode: themeMode ?? this.themeMode,
      quranFontSize: quranFontSize ?? this.quranFontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      quranFont: quranFont ?? this.quranFont,
      showTafseer: showTafseer ?? this.showTafseer,
      reciterId: reciterId ?? this.reciterId,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      autoFollowAudio: autoFollowAudio ?? this.autoFollowAudio,
      calcMethod: calcMethod ?? this.calcMethod,
      madhab: madhab ?? this.madhab,
      prayerNotifications: prayerNotifications ?? this.prayerNotifications,
      athkarReminders: athkarReminders ?? this.athkarReminders,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      prayerAdjustments: prayerAdjustments ?? this.prayerAdjustments,
      adhanVoice: adhanVoice ?? this.adhanVoice,
      adhanFull: adhanFull ?? this.adhanFull,
      preAdhanEnabled: preAdhanEnabled ?? this.preAdhanEnabled,
      preAdhanMinutes: preAdhanMinutes ?? this.preAdhanMinutes,
      prayerAlerts: prayerAlerts ?? this.prayerAlerts,
      postPrayerAthkar: postPrayerAthkar ?? this.postPrayerAthkar,
      iqamaReminder: iqamaReminder ?? this.iqamaReminder,
      postPrayerMinutes: postPrayerMinutes ?? this.postPrayerMinutes,
      wirdPages: wirdPages ?? this.wirdPages,
      customPrimary: customPrimary ?? this.customPrimary,
      customAccent: customAccent ?? this.customAccent,
      customBackground: customBackground ?? this.customBackground,
      bgPattern: bgPattern ?? this.bgPattern,
      adhanAlwaysPlay: adhanAlwaysPlay ?? this.adhanAlwaysPlay,
      occasionReminders: occasionReminders ?? this.occasionReminders,
      sunriseAlert: sunriseAlert ?? this.sunriseAlert,
      patternStrength: patternStrength ?? this.patternStrength,
      widgetOpacity: widgetOpacity ?? this.widgetOpacity,
      widgetTextColor: widgetTextColor ?? this.widgetTextColor,
    );
  }

  Map<String, dynamic> toMap() => {
        'themeType': themeType.name,
        'themeMode': themeMode.name,
        'quranFontSize': quranFontSize,
        'lineHeight': lineHeight,
        'quranFont': quranFont.name,
        'showTafseer': showTafseer,
        'reciterId': reciterId,
        'playbackSpeed': playbackSpeed,
        'autoFollowAudio': autoFollowAudio,
        'calcMethod': calcMethod,
        'madhab': madhab,
        'prayerNotifications': prayerNotifications,
        'athkarReminders': athkarReminders,
        'hapticFeedback': hapticFeedback,
        'prayerAdjustments': prayerAdjustments,
        'adhanVoice': adhanVoice,
        'adhanFull': adhanFull,
        'preAdhanEnabled': preAdhanEnabled,
        'preAdhanMinutes': preAdhanMinutes,
        'prayerAlerts': prayerAlerts,
        'postPrayerAthkar': postPrayerAthkar,
        'iqamaReminder': iqamaReminder,
        'postPrayerMinutes': postPrayerMinutes,
        'wirdPages': wirdPages,
        'customPrimary': customPrimary,
        'customAccent': customAccent,
        'customBackground': customBackground,
        'bgPattern': bgPattern,
        'adhanAlwaysPlay': adhanAlwaysPlay,
        'occasionReminders': occasionReminders,
        'sunriseAlert': sunriseAlert,
        'patternStrength': patternStrength,
        'widgetOpacity': widgetOpacity,
        'widgetTextColor': widgetTextColor,
      };

  factory SettingsState.fromMap(Map<String, dynamic> m) {
    const d = SettingsState();
    T byName<T extends Enum>(List<T> values, dynamic name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);
    return SettingsState(
      themeType: byName(AppThemeType.values, m['themeType'], d.themeType),
      themeMode: byName(ThemeMode.values, m['themeMode'], d.themeMode),
      quranFontSize: (m['quranFontSize'] as num?)?.toDouble() ?? d.quranFontSize,
      lineHeight: (m['lineHeight'] as num?)?.toDouble() ?? d.lineHeight,
      quranFont: byName(QuranFont.values, m['quranFont'], d.quranFont),
      showTafseer: m['showTafseer'] as bool? ?? d.showTafseer,
      reciterId: m['reciterId'] as String? ?? d.reciterId,
      playbackSpeed: (m['playbackSpeed'] as num?)?.toDouble() ?? d.playbackSpeed,
      autoFollowAudio: m['autoFollowAudio'] as bool? ?? d.autoFollowAudio,
      calcMethod: m['calcMethod'] as String? ?? d.calcMethod,
      madhab: m['madhab'] as String? ?? d.madhab,
      prayerNotifications: m['prayerNotifications'] as bool? ?? d.prayerNotifications,
      athkarReminders: m['athkarReminders'] as bool? ?? d.athkarReminders,
      hapticFeedback: m['hapticFeedback'] as bool? ?? d.hapticFeedback,
      prayerAdjustments: (m['prayerAdjustments'] is List && (m['prayerAdjustments'] as List).length == 6)
          ? (m['prayerAdjustments'] as List).map((e) => (e as num).toInt()).toList()
          : d.prayerAdjustments,
      adhanVoice: m['adhanVoice'] as String? ?? d.adhanVoice,
      adhanFull: m['adhanFull'] as bool? ?? d.adhanFull,
      preAdhanEnabled: m['preAdhanEnabled'] as bool? ?? d.preAdhanEnabled,
      preAdhanMinutes: (m['preAdhanMinutes'] as num?)?.toInt() ?? d.preAdhanMinutes,
      prayerAlerts: (m['prayerAlerts'] is List && (m['prayerAlerts'] as List).length == 5)
          ? (m['prayerAlerts'] as List).map((e) => e == true).toList()
          : d.prayerAlerts,
      postPrayerAthkar: m['postPrayerAthkar'] as bool? ?? d.postPrayerAthkar,
      iqamaReminder: m['iqamaReminder'] as bool? ?? d.iqamaReminder,
      postPrayerMinutes: (m['postPrayerMinutes'] as num?)?.toInt() ?? d.postPrayerMinutes,
      wirdPages: (m['wirdPages'] as num?)?.toInt() ?? d.wirdPages,
      customPrimary: (m['customPrimary'] as num?)?.toInt() ?? d.customPrimary,
      customAccent: (m['customAccent'] as num?)?.toInt() ?? d.customAccent,
      customBackground: (m['customBackground'] as num?)?.toInt() ?? d.customBackground,
      bgPattern: (m['bgPattern'] as num?)?.toInt() ?? d.bgPattern,
      adhanAlwaysPlay: m['adhanAlwaysPlay'] as bool? ?? d.adhanAlwaysPlay,
      occasionReminders: m['occasionReminders'] as bool? ?? d.occasionReminders,
      sunriseAlert: m['sunriseAlert'] as bool? ?? d.sunriseAlert,
      patternStrength: (m['patternStrength'] as num?)?.toDouble() ?? d.patternStrength,
      widgetOpacity: (m['widgetOpacity'] as num?)?.toDouble() ?? d.widgetOpacity,
      widgetTextColor: (m['widgetTextColor'] as num?)?.toInt() ?? d.widgetTextColor,
    );
  }

  @override
  List<Object?> get props => [
        themeType,
        themeMode,
        quranFontSize,
        lineHeight,
        quranFont,
        showTafseer,
        reciterId,
        playbackSpeed,
        autoFollowAudio,
        calcMethod,
        madhab,
        prayerNotifications,
        athkarReminders,
        hapticFeedback,
        prayerAdjustments,
        adhanVoice,
        adhanFull,
        preAdhanEnabled,
        preAdhanMinutes,
        prayerAlerts,
        postPrayerAthkar,
        iqamaReminder,
        postPrayerMinutes,
        wirdPages,
        customPrimary,
        customAccent,
        customBackground,
        bgPattern,
        adhanAlwaysPlay,
        occasionReminders,
        sunriseAlert,
        patternStrength,
        widgetOpacity,
        widgetTextColor,
      ];
}
