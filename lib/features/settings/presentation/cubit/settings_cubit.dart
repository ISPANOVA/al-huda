import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/home_widgets.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_themes.dart';
import '../../../../core/theme/theme_transition.dart';
import '../../../../core/widgets/background_patterns.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  static const _key = 'app_settings';

  final StorageService _storage;
  final NotificationService _notifications;

  SettingsCubit(this._storage, this._notifications)
      : super(SettingsState.fromMap(StorageService.asMap(_storage.settings.get(_key)))) {
    _applyCustom(state);
    // One-time switch to the new default black & gold theme.
    if (_storage.settings.get('noir_gold_default') != true) {
      _storage.settings.put('noir_gold_default', true);
      if (state.themeType != AppThemeType.custom) {
        final next = state.copyWith(themeType: AppThemeType.noirGold);
        emit(next);
        _storage.settings.put(_key, next.toMap());
      }
    }
    _notifications.accent = AppThemes.palette(state.themeType).primary;
    HomeWidgets.setStyle(opacity: state.widgetOpacity, textColor: state.widgetTextColor);
  }

  /// Home-screen widgets background (0 transparent … 1 solid).
  Future<void> setWidgetOpacity(double v) async {
    final next = state.copyWith(widgetOpacity: v.clamp(0.0, 1.0));
    await _save(next);
    await HomeWidgets.setStyle(opacity: next.widgetOpacity, textColor: next.widgetTextColor);
  }

  /// Home-screen widgets text colour (to suit the wallpaper).
  Future<void> setWidgetTextColor(Color c) async {
    final next = state.copyWith(widgetTextColor: c.toARGB32());
    await _save(next);
    await HomeWidgets.setStyle(opacity: next.widgetOpacity, textColor: next.widgetTextColor);
  }

  static void _applyCustom(SettingsState s) {
    BackgroundStyle.set(
      BgPattern.values[s.bgPattern.clamp(0, BgPattern.values.length - 1)],
      s.patternStrength,
    );
    AppThemes.custom = AppThemes.customFrom(Color(s.customPrimary), Color(s.customAccent), Color(s.customBackground));
  }

  /// Updates one or more of the user's own colours (live preview).
  Future<void> setCustomColors({Color? primary, Color? accent, Color? background}) async {
    final next = state.copyWith(
      themeType: AppThemeType.custom,
      customPrimary: primary?.toARGB32(),
      customAccent: accent?.toARGB32(),
      customBackground: background?.toARGB32(),
    );
    _applyCustom(next);
    _notifications.accent = AppThemes.custom.primary;
    await _save(next);
  }

  Future<void> setAdhanAlwaysPlay(bool v) => _save(state.copyWith(adhanAlwaysPlay: v));

  Future<void> setOccasionReminders(bool v) => _save(state.copyWith(occasionReminders: v));

  Future<void> setSunriseAlert(bool v) => _save(state.copyWith(sunriseAlert: v));

  Future<void> setBackgroundPattern(BgPattern pattern) async {
    final next = state.copyWith(bgPattern: pattern.index);
    _applyCustom(next);
    await _save(next);
  }

  /// Live preview while dragging the slider (saved on release).
  void previewPatternStrength(double v) => BackgroundStyle.set(
        BgPattern.values[state.bgPattern.clamp(0, BgPattern.values.length - 1)],
        v.clamp(0.4, 2.0),
      );

  Future<void> setPatternStrength(double v) async {
    final next = state.copyWith(patternStrength: v.clamp(0.4, 2.0));
    _applyCustom(next);
    await _save(next);
  }

  Future<void> _save(SettingsState next) async {
    emit(next);
    await _storage.settings.put(_key, next.toMap());
  }

  Future<void> setThemeType(AppThemeType type) async {
    if (type == state.themeType) return;
    _notifications.accent = AppThemes.palette(type).primary;
    await ThemeTransition.prepare();
    await _save(state.copyWith(themeType: type));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == state.themeMode) return;
    await ThemeTransition.prepare();
    await _save(state.copyWith(themeMode: mode));
  }
  Future<void> setQuranFontSize(double size) => _save(state.copyWith(quranFontSize: size.clamp(18, 48)));
  Future<void> setLineHeight(double height) => _save(state.copyWith(lineHeight: height.clamp(1.4, 3.0)));
  Future<void> setQuranFont(QuranFont font) => _save(state.copyWith(quranFont: font));
  Future<void> toggleTafseer() => _save(state.copyWith(showTafseer: !state.showTafseer));
  Future<void> setReciter(String id) => _save(state.copyWith(reciterId: id));
  Future<void> setPlaybackSpeed(double speed) => _save(state.copyWith(playbackSpeed: speed));
  Future<void> setAutoFollowAudio(bool value) => _save(state.copyWith(autoFollowAudio: value));
  Future<void> setCalcMethod(String method) => _save(state.copyWith(calcMethod: method));
  Future<void> setMadhab(String madhab) => _save(state.copyWith(madhab: madhab));
  Future<void> setPrayerNotifications(bool value) async {
    if (value) await _notifications.requestPermissions();
    await _save(state.copyWith(prayerNotifications: value));
  }

  Future<void> setPrayerAdjustment(int index, int minutes) {
    final list = List<int>.of(state.prayerAdjustments);
    list[index] = minutes.clamp(-30, 30);
    return _save(state.copyWith(prayerAdjustments: list));
  }

  Future<void> resetPrayerAdjustments() => _save(state.copyWith(prayerAdjustments: const [0, 0, 0, 0, 0, 0]));

  Future<void> setAdhanVoice(String id) => _save(state.copyWith(adhanVoice: id));
  Future<void> setAdhanFull(bool full) => _save(state.copyWith(adhanFull: full));
  Future<void> setPreAdhanEnabled(bool value) => _save(state.copyWith(preAdhanEnabled: value));
  Future<void> setPreAdhanMinutes(int minutes) => _save(state.copyWith(preAdhanMinutes: minutes.clamp(1, 60)));
  Future<void> setPrayerAlert(int index, bool value) {
    final list = List<bool>.of(state.prayerAlerts);
    if (index < 0 || index >= list.length) return Future.value();
    list[index] = value;
    return _save(state.copyWith(prayerAlerts: list));
  }

  Future<void> setPostPrayerAthkar(bool value) => _save(state.copyWith(postPrayerAthkar: value));
  Future<void> setIqamaReminder(bool value) => _save(state.copyWith(iqamaReminder: value));

  Future<void> setMushafPages(String value) => _save(state.copyWith(mushafPages: value));
  Future<void> setPostPrayerMinutes(int minutes) => _save(state.copyWith(postPrayerMinutes: minutes.clamp(1, 90)));
  Future<void> setWirdPages(int pages) => _save(state.copyWith(wirdPages: pages.clamp(0, 60)));

  Future<void> setHapticFeedback(bool value) => _save(state.copyWith(hapticFeedback: value));

  Future<void> setAthkarReminders(bool value) async {
    if (value) {
      await _notifications.requestPermissions();
      await _notifications.scheduleDaily(
        id: AppConstants.morningAthkarId,
        title: 'أذكار الصباح ☀️',
        body: 'ابدأ يومك بذكر الله، أذكار الصباح بانتظارك',
        hour: 6,
        minute: 30,
      );
      await _notifications.scheduleDaily(
        id: AppConstants.eveningAthkarId,
        title: 'أذكار المساء 🌙',
        body: 'حصّن نفسك بأذكار المساء',
        hour: 17,
        minute: 0,
      );
    } else {
      await _notifications.cancel(AppConstants.morningAthkarId);
      await _notifications.cancel(AppConstants.eveningAthkarId);
    }
    await _save(state.copyWith(athkarReminders: value));
  }
}
