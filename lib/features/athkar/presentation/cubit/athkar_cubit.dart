import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/storage_service.dart';
import '../../../stats/data/stats_repository.dart';
import '../../../stats/domain/stats_entities.dart';
import '../../data/athkar_data.dart';

class AthkarState extends Equatable {
  /// categoryId -> thikrId -> count done today.
  final Map<String, Map<String, int>> progress;

  const AthkarState(this.progress);

  int done(String category, String thikrId) => progress[category]?[thikrId] ?? 0;

  double categoryProgress(AthkarCategory c) {
    final total = c.items.fold<int>(0, (a, t) => a + t.count);
    final done = c.items.fold<int>(0, (a, t) => a + this.done(c.id, t.id).clamp(0, t.count));
    return total == 0 ? 0 : done / total;
  }

  @override
  List<Object?> get props => [progress];
}

/// Daily counters for every thikr; resets automatically each new day.
class AthkarCubit extends Cubit<AthkarState> {
  final StorageService _storage;
  final StatsRepository _stats;

  AthkarCubit(this._storage, this._stats) : super(const AthkarState({})) {
    _load();
  }

  String get _todayKey {
    final d = DateTime.now();
    return 'progress:${d.year}-${d.month}-${d.day}';
  }

  void _load() {
    final raw = StorageService.asMap(_storage.athkar.get(_todayKey));
    emit(AthkarState({
      for (final e in raw.entries)
        e.key: (e.value as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
    }));
  }

  /// Call when returning to the app to roll over to a new day.
  void refreshDay() => _load();

  Future<bool> increment(AthkarCategory category, Thikr thikr) async {
    final current = state.done(category.id, thikr.id);
    if (current >= thikr.count) return true;
    final next = Map<String, Map<String, int>>.from(
      state.progress.map((k, v) => MapEntry(k, Map<String, int>.from(v))),
    );
    next.putIfAbsent(category.id, () => {})[thikr.id] = current + 1;
    emit(AthkarState(next));
    await _storage.athkar.put(_todayKey, next);
    await _stats.log(StatType.athkar);
    return current + 1 >= thikr.count;
  }

  Future<void> resetCategory(AthkarCategory category) async {
    final next = Map<String, Map<String, int>>.from(state.progress)..remove(category.id);
    emit(AthkarState(next));
    await _storage.athkar.put(_todayKey, next);
  }
}
