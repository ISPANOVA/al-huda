import '../../../../core/services/storage_service.dart';
import '../../domain/entities/ayah_ref.dart';

/// Bookmarks, favourite verses and the last-read position.
class BookmarksRepository {
  static const _lastReadKey = 'last_read';
  static const _bookmarksKey = 'bookmarks';
  static const _favoritesKey = 'favorites';
  static const _lastPageKey = 'last_page';

  final StorageService _storage;

  BookmarksRepository(this._storage);

  Stream<void> get changes => _storage.bookmarks.watch().map((_) {});

  AyahRef? get lastRead {
    final raw = _storage.bookmarks.get(_lastReadKey);
    return raw == null ? null : AyahRef.fromMap(StorageService.asMap(raw));
  }

  Future<void> saveLastRead(int surah, int ayah) =>
      _storage.bookmarks.put(_lastReadKey, AyahRef(surah: surah, ayah: ayah, savedAt: DateTime.now()).toMap());

  /// Last Mushaf page the user was on (null = never opened the Mushaf).
  int? get lastPage => (_storage.bookmarks.get(_lastPageKey) as num?)?.toInt();

  Future<void> saveLastPage(int page) => _storage.bookmarks.put(_lastPageKey, page);

  List<AyahRef> get bookmarks => _list(_bookmarksKey);
  List<AyahRef> get favorites => _list(_favoritesKey);

  List<AyahRef> _list(String key) =>
      StorageService.asMapList(_storage.bookmarks.get(key)).map(AyahRef.fromMap).toList()
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));

  bool isBookmarked(int surah, int ayah) => bookmarks.any((b) => b.sameAs(surah, ayah));
  bool isFavorite(int surah, int ayah) => favorites.any((b) => b.sameAs(surah, ayah));

  Future<bool> toggleBookmark(int surah, int ayah, {String? text, String? note}) =>
      _toggle(_bookmarksKey, surah, ayah, text: text, note: note);

  Future<bool> toggleFavorite(int surah, int ayah, {String? text}) => _toggle(_favoritesKey, surah, ayah, text: text);

  /// Returns true when the item is now saved.
  Future<bool> _toggle(String key, int surah, int ayah, {String? text, String? note}) async {
    final list = _list(key);
    final exists = list.any((r) => r.sameAs(surah, ayah));
    if (exists) {
      list.removeWhere((r) => r.sameAs(surah, ayah));
    } else {
      list.add(AyahRef(surah: surah, ayah: ayah, text: text, note: note, savedAt: DateTime.now()));
    }
    await _storage.bookmarks.put(key, list.map((r) => r.toMap()).toList());
    return !exists;
  }
}
