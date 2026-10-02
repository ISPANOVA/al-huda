import 'dart:math';

import 'package:equatable/equatable.dart';

import '../../../core/data/surah_metadata.dart';

/// Ayah-based Khatmah plan: the Mushaf (6236 ayahs) is split across
/// [targetDays]; today's portion adapts if the reader falls behind or gets ahead.
class KhatmahPlan extends Equatable {
  static const int total = SurahMetadata.totalAyahs;

  final DateTime startDate;
  final int targetDays;
  final int completedAyahs;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final int completedKhatmat;

  /// yyyy-MM-dd -> ayahs read that day.
  final Map<String, int> history;

  const KhatmahPlan({
    required this.startDate,
    required this.targetDays,
    this.completedAyahs = 0,
    this.reminderEnabled = true,
    this.reminderHour = 20,
    this.reminderMinute = 0,
    this.completedKhatmat = 0,
    this.history = const {},
  });

  static DateTime _d(DateTime t) => DateTime(t.year, t.month, t.day);
  static String dayKey(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  int get baseDailyTarget => (total / targetDays).ceil();
  int get remainingAyahs => max(0, total - completedAyahs);
  bool get isFinished => completedAyahs >= total;
  double get progress => completedAyahs / total;
  DateTime get endDate => _d(startDate).add(Duration(days: targetDays - 1));

  int daysElapsed(DateTime now) => max(0, (_d(now).difference(_d(startDate)).inHours / 24).round());
  int daysRemaining(DateTime now) => max(1, targetDays - daysElapsed(now));
  int readOn(DateTime day) => history[dayKey(day)] ?? 0;

  /// Today's goal = what's left at the start of today spread over remaining days.
  int todayGoal(DateTime now) {
    final remainingAtDayStart = remainingAyahs + readOn(now);
    return max(1, (remainingAtDayStart / daysRemaining(now)).ceil());
  }

  int todayFrom(DateTime now) => min(total, completedAyahs - readOn(now) + 1);
  int todayTo(DateTime now) => min(total, completedAyahs - readOn(now) + todayGoal(now));
  int todayRemaining(DateTime now) => max(0, todayTo(now) - completedAyahs);
  double todayProgress(DateTime now) {
    final goal = todayTo(now) - todayFrom(now) + 1;
    return goal <= 0 ? 1 : (readOn(now) / goal).clamp(0.0, 1.0);
  }

  bool isTodayDone(DateTime now) => todayRemaining(now) == 0;

  /// Positive: ahead of schedule by N ayahs, negative: behind.
  int scheduleDelta(DateTime now) => completedAyahs - min(total, daysElapsed(now) * baseDailyTarget);

  KhatmahPlan copyWith({
    DateTime? startDate,
    int? targetDays,
    int? completedAyahs,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    int? completedKhatmat,
    Map<String, int>? history,
  }) =>
      KhatmahPlan(
        startDate: startDate ?? this.startDate,
        targetDays: targetDays ?? this.targetDays,
        completedAyahs: completedAyahs ?? this.completedAyahs,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        reminderHour: reminderHour ?? this.reminderHour,
        reminderMinute: reminderMinute ?? this.reminderMinute,
        completedKhatmat: completedKhatmat ?? this.completedKhatmat,
        history: history ?? this.history,
      );

  Map<String, dynamic> toMap() => {
        'start': startDate.millisecondsSinceEpoch,
        'days': targetDays,
        'done': completedAyahs,
        'reminder': reminderEnabled,
        'hour': reminderHour,
        'minute': reminderMinute,
        'khatmat': completedKhatmat,
        'history': history,
      };

  factory KhatmahPlan.fromMap(Map<String, dynamic> m) => KhatmahPlan(
        startDate: DateTime.fromMillisecondsSinceEpoch((m['start'] as num).toInt()),
        targetDays: (m['days'] as num).toInt(),
        completedAyahs: (m['done'] as num?)?.toInt() ?? 0,
        reminderEnabled: m['reminder'] as bool? ?? true,
        reminderHour: (m['hour'] as num?)?.toInt() ?? 20,
        reminderMinute: (m['minute'] as num?)?.toInt() ?? 0,
        completedKhatmat: (m['khatmat'] as num?)?.toInt() ?? 0,
        history: ((m['history'] as Map?) ?? const {}).map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      );

  @override
  List<Object?> get props =>
      [startDate, targetDays, completedAyahs, reminderEnabled, reminderHour, reminderMinute, completedKhatmat, history];
}
