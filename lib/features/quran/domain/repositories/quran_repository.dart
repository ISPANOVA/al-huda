import '../entities/ayah.dart';
import '../entities/mushaf_line.dart';

abstract class QuranRepository {
  /// Number of pages in the Madinah Mushaf.
  static const int pageCount = 604;

  /// Loads the Mushaf bundled inside the app (parsed off the UI thread).
  /// Safe to call many times; completes immediately once loaded.
  Future<void> ensureLoaded();

  /// True once the bundled Mushaf is parsed and every page/search API is instant.
  bool get isReady;

  /// Ayahs of [surah] (Uthmani Hafs text + Tafseer Al-Muyassar).
  Future<List<Ayah>> getSurah(int surah);

  /// Single ayah lookup.
  Future<Ayah?> getAyah(int surah, int ayah);

  /// Ayahs printed on Mushaf page [page] (1..604). Empty until [isReady].
  List<Ayah> ayahsOnPage(int page);

  /// Printed lines of page [page] (empty until [isReady]).
  List<MushafLine> linesOnPage(int page);

  /// Line width at font size 100 used to size the Mushaf font.
  double get referenceLineWidth;

  /// Ayah by global number (1..6236); null until [isReady].
  Ayah? ayahByNumber(int number);

  /// Mushaf page containing the given ayah (1 when unknown).
  int pageOf(int surah, int ayah);

  /// First Mushaf page of [surah].
  int firstPageOfSurah(int surah);

  /// Diacritics-insensitive full-text search (synchronous over a prebuilt index).
  List<SearchResult> search(String query, {int limit = 300});
}
