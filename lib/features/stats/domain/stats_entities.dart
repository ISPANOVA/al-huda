import 'package:equatable/equatable.dart';

enum StatType { quranAyahs, listenedAyahs, tasbeeh, athkar }

class DailyStat extends Equatable {
  final DateTime date;
  final Map<StatType, int> values;

  const DailyStat(this.date, this.values);

  int get(StatType t) => values[t] ?? 0;
  bool get isActive => values.values.any((v) => v > 0);
  int get total => values.values.fold(0, (a, b) => a + b);

  @override
  List<Object?> get props => [date, values];
}

class StatsSummary extends Equatable {
  final int currentStreak;
  final int longestStreak;
  final Map<StatType, int> totals;
  final List<DailyStat> lastWeek;
  final int activeDays;

  const StatsSummary({
    required this.currentStreak,
    required this.longestStreak,
    required this.totals,
    required this.lastWeek,
    required this.activeDays,
  });

  @override
  List<Object?> get props => [currentStreak, longestStreak, totals, lastWeek, activeDays];
}
