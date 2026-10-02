import 'package:flutter/foundation.dart';

import '../../core/services/storage_service.dart';

/// Smart daily wird: counts the Mushaf pages actually read each day (a page
/// counts after it stays on screen for a few seconds) — no manual logging.
class WirdTracker extends ChangeNotifier {
  final StorageService _storage;

  WirdTracker(this._storage);

  static String _day(DateTime d) => 'wird_${d.year}-${d.month}-${d.day}';

  Set<int> pagesOn(DateTime d) {
    final raw = _storage.settings.get(_day(d));
    return raw is List ? raw.map((e) => (e as num).toInt()).toSet() : <int>{};
  }

  int get todayCount => pagesOn(DateTime.now()).length;

  /// Records [page] as read today. Returns true when this page completes [goal].
  bool record(int page, int goal) {
    final now = DateTime.now();
    final pages = pagesOn(now);
    if (!pages.add(page)) return false;
    _storage.settings.put(_day(now), pages.toList());
    notifyListeners();
    return goal > 0 && pages.length == goal;
  }

  /// Consecutive days (ending today, or yesterday if today isn't done yet)
  /// on which the goal was met.
  int streak(int goal) {
    if (goal <= 0) return 0;
    var d = DateTime.now();
    if (pagesOn(d).length < goal) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (n < 3650 && pagesOn(d).length >= goal) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }
}
