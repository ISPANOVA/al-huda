import 'package:flutter/foundation.dart';

import '../../../core/services/storage_service.dart';

/// «متابعة الصلوات»: which of the five prayers were prayed each day, the
/// count of prayers to make up (القضاء), and Ramadan's fasts and taraweeh.
/// Kept in the stats box, so the backup carries it.
class PrayerLog extends ChangeNotifier {
  final StorageService _storage;

  PrayerLog(this._storage);

  static const prayers = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];

  static String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> _map(String key) => StorageService.asMap(_storage.stats.get(key));

  Set<int> doneOn(DateTime day) {
    final v = _map('prayer_log')[dayKey(day)];
    return v is List ? v.map((e) => (e as num).toInt()).toSet() : <int>{};
  }

  Future<void> toggle(DateTime day, int prayer) async {
    final all = _map('prayer_log');
    final set = doneOn(day);
    set.contains(prayer) ? set.remove(prayer) : set.add(prayer);
    all[dayKey(day)] = (set.toList()..sort());
    await _storage.stats.put('prayer_log', all);
    notifyListeners();
  }

  /// Days in a row (ending today, or yesterday while today is not done) with all five.
  int get fullDaysStreak {
    var d = DateTime.now();
    if (doneOn(d).length < 5) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (doneOn(d).length == 5) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// Prayed out of due over the last [days] days (today counts what is due so far).
  (int, int) lastDays(int days, {List<DateTime>? todayTimes}) {
    var done = 0, due = 0;
    final now = DateTime.now();
    for (var i = 0; i < days; i++) {
      final d = now.subtract(Duration(days: i));
      final set = doneOn(d);
      done += set.length;
      if (i == 0 && todayTimes != null) {
        due += todayTimes.where((t) => t.isBefore(now)).length.clamp(set.length, 5);
      } else {
        due += 5;
      }
    }
    return (done, due);
  }

  int get qada => (_storage.stats.get('prayer_qada') as num?)?.toInt() ?? 0;

  Future<void> setQada(int n) async {
    await _storage.stats.put('prayer_qada', n < 0 ? 0 : n);
    notifyListeners();
  }

  // ---------------------------------------------------------- Ramadan ---

  Set<int> _days(String key, int hijriYear) {
    final v = _map(key)['$hijriYear'];
    return v is List ? v.map((e) => (e as num).toInt()).toSet() : <int>{};
  }

  Set<int> fasts(int hijriYear) => _days('ramadan_fasts', hijriYear);
  Set<int> taraweeh(int hijriYear) => _days('ramadan_taraweeh', hijriYear);

  Future<void> toggleFast(int hijriYear, int day) => _toggleDay('ramadan_fasts', hijriYear, day);
  Future<void> toggleTaraweeh(int hijriYear, int day) => _toggleDay('ramadan_taraweeh', hijriYear, day);

  Future<void> _toggleDay(String key, int year, int day) async {
    final all = _map(key);
    final set = _days(key, year);
    set.contains(day) ? set.remove(day) : set.add(day);
    all['$year'] = (set.toList()..sort());
    await _storage.stats.put(key, all);
    notifyListeners();
  }
}
