import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/adhan_native.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/cubit/settings_state.dart';
import '../../../../core/services/home_widgets.dart';
import '../../data/location_service.dart';
import '../../domain/adhan_voices.dart';
import '../../data/prayer_repository.dart';
import '../../domain/prayer_entities.dart';

class PrayerState extends Equatable {
  final bool loading;
  final UserLocation? location;
  final PrayerDay? today;
  final PrayerDay? tomorrow;
  final NextPrayer? next;
  final Duration countdown;
  final String? error;

  const PrayerState({
    this.loading = false,
    this.location,
    this.today,
    this.tomorrow,
    this.next,
    this.countdown = Duration.zero,
    this.error,
  });

  bool get ready => today != null && next != null;

  PrayerState copyWith({
    bool? loading,
    UserLocation? location,
    PrayerDay? today,
    PrayerDay? tomorrow,
    NextPrayer? next,
    Duration? countdown,
    String? error,
    bool clearError = false,
  }) =>
      PrayerState(
        loading: loading ?? this.loading,
        location: location ?? this.location,
        today: today ?? this.today,
        tomorrow: tomorrow ?? this.tomorrow,
        next: next ?? this.next,
        countdown: countdown ?? this.countdown,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props => [loading, location, today, tomorrow, next, countdown, error];
}

class PrayerCubit extends Cubit<PrayerState> {
  final LocationService _location;
  final PrayerRepository _repo;
  final NotificationService _notifications;
  final SettingsCubit _settings;
  Timer? _ticker;
  StreamSubscription<SettingsState>? _settingsSub;
  String _lastSettingsKey = '';

  PrayerCubit(this._location, this._repo, this._notifications, this._settings, {bool autoLocate = true})
      : super(const PrayerState()) {
    _lastSettingsKey = _settingsKey(_settings.state);
    _settingsSub = _settings.stream.listen((s) {
      final key = _settingsKey(s);
      if (key != _lastSettingsKey) {
        _lastSettingsKey = key;
        _recalculate();
      }
    });
    final cached = _location.cached;
    if (cached != null) {
      emit(state.copyWith(location: cached));
      _recalculate();
    }
    if (autoLocate || cached != null) refreshLocation(silent: cached != null);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Prayer times for any date at the current location (imsakiya, calendar).
  PrayerDay? dayFor(DateTime date) {
    final loc = state.location;
    if (loc == null) return null;
    final s = _settings.state;
    return _repo.calculate(
      location: loc,
      date: date,
      method: s.calcMethod,
      madhab: s.madhab,
      adjustments: s.prayerAdjustments,
    );
  }

  String _settingsKey(SettingsState s) =>
      '${s.calcMethod}|${s.madhab}|${s.prayerNotifications}|${s.prayerAdjustments.join(',')}|'
      '${s.adhanVoice}|${s.adhanFull}|${s.preAdhanEnabled}|${s.preAdhanMinutes}|${s.prayerAlerts.join(',')}|'
      '${s.postPrayerAthkar}|${s.postPrayerMinutes}|${s.adhanAlwaysPlay}|${s.sunriseAlert}';

  Future<void> refreshLocation({bool silent = false}) async {
    if (!silent) emit(state.copyWith(loading: true, clearError: true));
    try {
      final loc = await _location.current();
      if (isClosed) return;
      emit(state.copyWith(location: loc, loading: false, clearError: true));
      _recalculate();
    } on LocationException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(loading: false, error: state.location == null ? e.message : null));
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(loading: false, error: state.location == null ? 'تعذر تحديد الموقع' : null));
    }
  }

  void _recalculate() {
    final loc = state.location;
    if (loc == null) return;
    final s = _settings.state;
    final now = DateTime.now();
    final today = _repo.calculate(
      location: loc,
      date: now,
      method: s.calcMethod,
      madhab: s.madhab,
      adjustments: s.prayerAdjustments,
    );
    final tomorrow = _repo.calculate(
      location: loc,
      date: now.add(const Duration(days: 1)),
      method: s.calcMethod,
      madhab: s.madhab,
      adjustments: s.prayerAdjustments,
    );
    final next = _repo.nextPrayer(today, tomorrow, now);
    emit(state.copyWith(today: today, tomorrow: tomorrow, next: next, countdown: next.time.difference(now)));
    _scheduleNotifications(today, tomorrow);
    _updateWidget(loc, now);
  }

  String? _widgetSignature;

  /// Sends a week of prayer times to the home-screen widget.
  void _updateWidget(UserLocation loc, DateTime now) {
    final s = _settings.state;
    final sig = '${_settingsKey(s)}|${now.year}-${now.month}-${now.day}|${loc.latitude}|${loc.longitude}';
    if (sig == _widgetSignature) return;
    _widgetSignature = sig;
    final prayers = PrayerName.values.where((p) => p.isPrayer).toList();
    final days = [
      for (var i = 0; i < 7; i++)
        () {
          final day = _repo.calculate(
            location: loc,
            date: now.add(Duration(days: i)),
            method: s.calcMethod,
            madhab: s.madhab,
            adjustments: s.prayerAdjustments,
          );
          return (
            date: day.date,
            prayers: [for (final p in prayers) (p.nameOn(day.date), day[p])],
            sunrise: day[PrayerName.sunrise],
          );
        }(),
    ];
    HomeWidgets.updatePrayers(city: loc.city ?? 'الهدى', days: days);
  }

  void _tick() {
    final next = state.next;
    if (next == null || isClosed) return;
    final now = DateTime.now();
    final remaining = next.time.difference(now);
    // Day rolled over or prayer time reached -> recompute.
    if (remaining.isNegative || (state.today != null && state.today!.date.day != now.day)) {
      _recalculate();
    } else {
      emit(state.copyWith(countdown: remaining));
    }
  }

  /// Signature of what is currently scheduled; rescheduling only happens when
  /// it changes. (Rescheduling at the very moment a prayer starts used to
  /// cancel the adhan that was about to ring.)
  String? _scheduledSignature;

  Future<void> _scheduleNotifications(PrayerDay today, PrayerDay tomorrow) async {
    const base = AppConstants.prayerNotificationBaseId;
    final s = _settings.state;
    final loc = state.location;
    final signature = '${_settingsKey(s)}|${today.date.year}-${today.date.month}-${today.date.day}|'
        '${loc?.latitude.toStringAsFixed(3)}|${loc?.longitude.toStringAsFixed(3)}';
    if (signature == _scheduledSignature) return;
    _scheduledSignature = signature;

    // 3 days × 5 prayers × (adhan, pre-adhan, post-prayer athkar).
    await _notifications.cancelPendingRange(base, 60);
    if (!s.prayerNotifications || loc == null) {
      await AdhanNative.cancelAll();
      return;
    }
    // "Always" mode: the native player rings on the alarm stream instead of a
    // notification sound, so silent / vibrate mode doesn't mute the adhan.
    final native = s.adhanAlwaysPlay && AdhanNative.supported;
    final nativeItems = <({int id, DateTime at, String sound, String title, String body})>[];
    final fallback = <Future<void> Function()>[];

    final days = <PrayerDay>[
      today,
      tomorrow,
      _repo.calculate(
        location: loc,
        date: today.date.add(const Duration(days: 2)),
        method: s.calcMethod,
        madhab: s.madhab,
        adjustments: s.prayerAdjustments,
      ),
    ];
    final voice = AdhanVoices.byId(s.adhanVoice);
    final prayers = PrayerName.values.where((p) => p.isPrayer).toList();
    final city = loc.city ?? 'الهدى';
    var slot = 0;
    var dayIndex = 0;
    for (final day in days) {
      if (s.sunriseAlert) {
        await _notifications.scheduleReminderAt(
          id: base + 50 + dayIndex,
          title: 'أشرقت الشمس ☀️',
          body: 'حان وقت الشروق ${ArabicUtils.formatTime(day[PrayerName.sunrise])} • تبدأ صلاة الضحى بعد ارتفاع الشمس بربع ساعة',
          when: day[PrayerName.sunrise],
        );
      }
      dayIndex++;
      for (var i = 0; i < prayers.length; i++, slot++) {
        final p = prayers[i];
        if (i < s.prayerAlerts.length && !s.prayerAlerts[i]) continue;
        final jumuah = p == PrayerName.dhuhr && day.date.weekday == DateTime.friday;
        final title = 'حان الآن موعد صلاة ${p.nameOn(day.date)} 🕌';
        final body = jumuah
            ? '${ArabicUtils.formatTime(day[p])} • $city — لا تنسَ قراءة سورة الكهف والصلاة على النبي ﷺ'
            : '${ArabicUtils.formatTime(day[p])} • $city';
        final id = base + slot;
        final when = day[p];
        Future<void> notify() => _notifications.scheduleAdhan(
              id: id,
              title: title,
              body: body,
              when: when,
              voice: voice.id,
              voiceName: voice.nameAr,
              full: s.adhanFull,
            );
        if (native) {
          nativeItems.add((id: slot, at: when, sound: AdhanNative.sound(voice.id, s.adhanFull), title: title, body: body));
          fallback.add(notify);
        } else {
          await notify();
        }
        if (s.postPrayerAthkar) {
          await _notifications.schedulePostPrayer(
            id: base + 40 + slot,
            title: 'أذكار بعد صلاة ${p.nameOn(day.date)} 🤲',
            body: 'لا تنسَ أذكار ما بعد الصلاة: أستغفر الله، وآية الكرسي، والتسبيح ٣٣',
            when: day[p].add(Duration(minutes: s.postPrayerMinutes)),
          );
        }
        if (s.preAdhanEnabled) {
          await _notifications.schedulePreAdhan(
            id: base + 20 + slot,
            title: 'اقترب موعد صلاة ${p.nameOn(day.date)}',
            body: 'باقي ${ArabicUtils.toArabicDigits(s.preAdhanMinutes)} دقيقة على الأذان • ${ArabicUtils.formatTime(day[p])}',
            when: day[p].subtract(Duration(minutes: s.preAdhanMinutes)),
          );
        }
      }
    }
    if (!native) {
      await AdhanNative.cancelAll();
    } else if (!await AdhanNative.schedule(nativeItems)) {
      for (final f in fallback) {
        await f();
      }
    }
  }

  @override
  Future<void> close() async {
    _ticker?.cancel();
    await _settingsSub?.cancel();
    return super.close();
  }
}
