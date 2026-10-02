import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/storage_service.dart';
import '../../../stats/data/stats_repository.dart';
import '../../../stats/domain/stats_entities.dart';

class TasbeehState extends Equatable {
  final List<String> phrases;
  final int selected;
  final int count;
  final int target;
  final int rounds;
  final int lifetime;

  const TasbeehState({
    required this.phrases,
    this.selected = 0,
    this.count = 0,
    this.target = 33,
    this.rounds = 0,
    this.lifetime = 0,
  });

  String get phrase => phrases[selected.clamp(0, phrases.length - 1)];

  TasbeehState copyWith({List<String>? phrases, int? selected, int? count, int? target, int? rounds, int? lifetime}) =>
      TasbeehState(
        phrases: phrases ?? this.phrases,
        selected: selected ?? this.selected,
        count: count ?? this.count,
        target: target ?? this.target,
        rounds: rounds ?? this.rounds,
        lifetime: lifetime ?? this.lifetime,
      );

  Map<String, dynamic> toMap() =>
      {'phrases': phrases, 'selected': selected, 'count': count, 'target': target, 'rounds': rounds, 'lifetime': lifetime};

  @override
  List<Object?> get props => [phrases, selected, count, target, rounds, lifetime];
}

class TasbeehCubit extends Cubit<TasbeehState> {
  static const _key = 'state';
  static const defaultPhrases = [
    'سُبْحَانَ اللَّهِ',
    'الْحَمْدُ لِلَّهِ',
    'اللَّهُ أَكْبَرُ',
    'لَا إِلَٰهَ إِلَّا اللَّهُ',
    'أَسْتَغْفِرُ اللَّهَ',
    'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ',
    'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
    'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ',
  ];

  final StorageService _storage;
  final StatsRepository _stats;
  int _unloggedTaps = 0;

  TasbeehCubit(this._storage, this._stats) : super(const TasbeehState(phrases: defaultPhrases)) {
    final m = StorageService.asMap(_storage.tasbeeh.get(_key));
    if (m.isNotEmpty) {
      final phrases = (m['phrases'] as List?)?.cast<String>() ?? defaultPhrases;
      emit(TasbeehState(
        phrases: phrases.isEmpty ? defaultPhrases : phrases,
        selected: (m['selected'] as num?)?.toInt() ?? 0,
        count: (m['count'] as num?)?.toInt() ?? 0,
        target: (m['target'] as num?)?.toInt() ?? 33,
        rounds: (m['rounds'] as num?)?.toInt() ?? 0,
        lifetime: (m['lifetime'] as num?)?.toInt() ?? 0,
      ));
    }
  }

  void _persist() => _storage.tasbeeh.put(_key, state.toMap());

  /// Returns true when a round (target) was just completed.
  bool tap() {
    var count = state.count + 1;
    var rounds = state.rounds;
    var completedRound = false;
    if (state.target > 0 && count >= state.target) {
      completedRound = true;
      rounds++;
      count = 0;
    }
    emit(state.copyWith(count: count, rounds: rounds, lifetime: state.lifetime + 1));
    _persist();
    // Batch stats writes.
    if (++_unloggedTaps >= 10 || completedRound) {
      _stats.log(StatType.tasbeeh, _unloggedTaps);
      _unloggedTaps = 0;
    }
    return completedRound;
  }

  void reset() {
    emit(state.copyWith(count: 0, rounds: 0));
    _persist();
  }

  void setTarget(int target) {
    emit(state.copyWith(target: target, count: 0));
    _persist();
  }

  void selectPhrase(int index) {
    emit(state.copyWith(selected: index, count: 0, rounds: 0));
    _persist();
  }

  void addPhrase(String phrase) {
    final p = phrase.trim();
    if (p.isEmpty) return;
    emit(state.copyWith(phrases: [...state.phrases, p], selected: state.phrases.length, count: 0, rounds: 0));
    _persist();
  }

  void removePhrase(int index) {
    if (state.phrases.length <= 1) return;
    final list = [...state.phrases]..removeAt(index);
    emit(state.copyWith(phrases: list, selected: 0, count: 0, rounds: 0));
    _persist();
  }

  @override
  Future<void> close() async {
    if (_unloggedTaps > 0) await _stats.log(StatType.tasbeeh, _unloggedTaps);
    return super.close();
  }
}
