import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/ayah.dart';
import '../../domain/repositories/quran_repository.dart';

class QuranSearchState extends Equatable {
  final String query;
  final List<SearchResult> results;
  final bool searching;

  const QuranSearchState({this.query = '', this.results = const [], this.searching = false});

  QuranSearchState copyWith({String? query, List<SearchResult>? results, bool? searching}) => QuranSearchState(
        query: query ?? this.query,
        results: results ?? this.results,
        searching: searching ?? this.searching,
      );

  @override
  List<Object?> get props => [query, results, searching];
}

/// Instant, offline search over the bundled Mushaf (prebuilt normalized index).
class QuranSearchCubit extends Cubit<QuranSearchState> {
  final QuranRepository _repo;
  Timer? _debounce;

  QuranSearchCubit(this._repo) : super(const QuranSearchState());

  /// Called on every keystroke; only the debounced query reaches the state so
  /// typing never rebuilds the results list.
  void onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      if (state.query.isNotEmpty || state.results.isNotEmpty) emit(const QuranSearchState());
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (!_repo.isReady) {
      emit(state.copyWith(query: query, searching: true));
      await _repo.ensureLoaded();
    }
    if (isClosed) return;
    emit(QuranSearchState(query: query, results: _repo.search(query)));
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
