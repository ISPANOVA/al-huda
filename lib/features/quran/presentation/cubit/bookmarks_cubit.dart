import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/bookmarks_repository.dart';
import '../../domain/entities/ayah_ref.dart';

class BookmarksState extends Equatable {
  final AyahRef? lastRead;
  final List<AyahRef> bookmarks;
  final List<AyahRef> favorites;

  const BookmarksState({this.lastRead, this.bookmarks = const [], this.favorites = const []});

  bool isBookmarked(int s, int a) => bookmarks.any((b) => b.sameAs(s, a));
  bool isFavorite(int s, int a) => favorites.any((b) => b.sameAs(s, a));

  @override
  List<Object?> get props => [lastRead, bookmarks, favorites];
}

class BookmarksCubit extends Cubit<BookmarksState> {
  final BookmarksRepository _repo;
  late final StreamSubscription<void> _sub;

  BookmarksCubit(this._repo) : super(const BookmarksState()) {
    _reload();
    _sub = _repo.changes.listen((_) => _reload());
  }

  void _reload() {
    if (isClosed) return;
    emit(BookmarksState(lastRead: _repo.lastRead, bookmarks: _repo.bookmarks, favorites: _repo.favorites));
  }

  Future<bool> toggleBookmark(int surah, int ayah, {String? text}) => _repo.toggleBookmark(surah, ayah, text: text);

  Future<bool> toggleFavorite(int surah, int ayah, {String? text}) => _repo.toggleFavorite(surah, ayah, text: text);

  Future<void> saveLastRead(int surah, int ayah) => _repo.saveLastRead(surah, ayah);

  int? get lastPage => _repo.lastPage;

  Future<void> saveLastPage(int page) => _repo.saveLastPage(page);

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
