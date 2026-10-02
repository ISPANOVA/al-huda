import '../../../core/services/storage_service.dart';
import '../domain/stats_entities.dart';

/// Persists daily engagement counters and derives streaks.
/// Keys: `day:yyyy-MM-dd` -> {statType: count}, `totals` -> {statType: count}
class StatsRepository {
  final StorageService _storage;

  StatsRepository(this._storage);

  static String dayKey(DateTime d) =>
      'day:${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Stream<void> get changes => _storage.stats.watch().map((_) {});

  Future<void> log(StatType type, [int amount = 1]) async {
    if (amount <= 0) return;
    final box = _storage.stats;
    final key = dayKey(DateTime.now());
    final day = StorageService.asMap(box.get(key));
    day[type.name] = ((day[type.name] as num?)?.toInt() ?? 0) + amount;
    await box.put(key, day);

    final totals = StorageService.asMap(box.get('totals'));
    totals[type.name] = ((totals[type.name] as num?)?.toInt() ?? 0) + amount;
    await box.put('totals', totals);
  }

  DailyStat day(DateTime date) {
    final raw = StorageService.asMap(_storage.stats.get(dayKey(date)));
    return DailyStat(_dateOnly(date), {
      for (final t in StatType.values) t: (raw[t.name] as num?)?.toInt() ?? 0,
    });
  }

  bool _isActive(DateTime date) => day(date).isActive;

  StatsSummary summary() {
    final today = _dateOnly(DateTime.now());

    // Current streak: consecutive active days ending today (or yesterday if
    // today has no activity yet, so the streak isn't "lost" in the morning).
    var cursor = _isActive(today) ? today : today.subtract(const Duration(days: 1));
    var current = 0;
    while (_isActive(cursor)) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // Longest streak & active days across all stored days.
    final activeDates = _storage.stats.keys
        .whereType<String>()
        .where((k) => k.startsWith('day:'))
        .map((k) => DateTime.tryParse(k.substring(4)))
        .whereType<DateTime>()
        .where(_isActive)
        .toList()
      ..sort();
    var longest = 0, run = 0;
    DateTime? prev;
    for (final d in activeDates) {
      run = (prev != null && (d.difference(prev).inHours / 24).round() == 1) ? run + 1 : 1;
      if (run > longest) longest = run;
      prev = d;
    }

    final totalsRaw = StorageService.asMap(_storage.stats.get('totals'));
    return StatsSummary(
      currentStreak: current,
      longestStreak: longest < current ? current : longest,
      totals: {for (final t in StatType.values) t: (totalsRaw[t.name] as num?)?.toInt() ?? 0},
      lastWeek: List.generate(7, (i) => day(today.subtract(Duration(days: 6 - i)))),
      activeDays: activeDates.length,
    );
  }
}
