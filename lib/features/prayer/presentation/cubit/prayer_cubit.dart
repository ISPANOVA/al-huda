import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

  String _settingsKey(SettingsState s) =>
      '${s.calcMethod}|${s.madhab}|${s.prayerNotifications}|${s.prayerAdjustments.join(',')}|'
      '${s.adhanVoice}|${s.adhanFull}|${s.preAdhanEnabled}|${s.preAdhanMinutes}|${s.prayerAlerts.join(',')}|'
      '${s.postPrayerAthkar}|${s.postPrayerMinutes}';

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
          return (date: day.date, prayers: [for (final p in prayers) (p.nameAr, day[p])]);
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
    if (!s.prayerNotifications || loc == null) return;

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
    for (final day in days) {
      for (var i = 0; i < prayers.length; i++, slot++) {
        final p = prayers[i];
        if (i < s.prayerAlerts.length && !s.prayerAlerts[i]) continue;
        await _notifications.scheduleAdhan(
          id: base + slot,
          title: 'حان الآن موعد صلاة ${p.nameAr} 🕌',
          body: '${ArabicUtils.formatTime(day[p])} • $city',
          when: day[p],
          voice: voice.id,
          voiceName: voice.nameAr,
          full: s.adhanFull,
        );
        if (s.postPrayerAthkar) {
          await _notifications.schedulePostPrayer(
            id: base + 40 + slot,
            title: 'أذكار بعد صلاة ${p.nameAr} 🤲',
            body: 'لا تنسَ أذكار ما بعد الصلاة: أستغفر الله، وآية الكرسي، والتسبيح ٣٣',
            when: day[p].add(Duration(minutes: s.postPrayerMinutes)),
          );
        }
        if (s.preAdhanEnabled) {
          await _notifications.schedulePreAdhan(
            id: base + 20 + slot,
            title: 'اقترب موعد صلاة ${p.nameAr}',
            body: 'باقي ${ArabicUtils.toArabicDigits(s.preAdhanMinutes)} دقيقة على الأذان • ${ArabicUtils.formatTime(day[p])}',
            when: day[p].subtract(Duration(minutes: s.preAdhanMinutes)),
          );
        }
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
