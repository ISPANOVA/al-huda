import '../../../../core/data/surah_metadata.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/mushaf_line.dart';
import '../../domain/repositories/quran_repository.dart';
import '../datasources/bundled_quran_data_source.dart';

class QuranRepositoryImpl implements QuranRepository {
  final BundledQuranDataSource _data;
  final Map<int, List<Ayah>> _pageCache = {};

  QuranRepositoryImpl(this._data);

  QuranBundle? get _b => _data.current;

  @override
  Future<void> ensureLoaded() => _data.load();

  @override
  bool get isReady => _b != null;

  @override
  Future<List<Ayah>> getSurah(int surah) async {
    final b = await _data.load();
    final start = SurahMetadata.globalAyah(surah, 1) - 1;
    final end = start + SurahMetadata.surah(surah).ayahCount;
    return b.ayahs.sublist(start, end);
  }

  @override
  Future<Ayah?> getAyah(int surah, int ayah) async {
    final b = await _data.load();
    if (ayah < 1 || ayah > SurahMetadata.surah(surah).ayahCount) return null;
    return b.ayahs[SurahMetadata.globalAyah(surah, ayah) - 1];
  }

  @override
  List<Ayah> ayahsOnPage(int page) {
    final b = _b;
    if (b == null || page < 1 || page > QuranRepository.pageCount) return const [];
    return _pageCache.putIfAbsent(page, () => b.ayahs.sublist(b.pageStart[page], b.pageStart[page + 1]));
  }

  @override
  List<MushafLine> linesOnPage(int page) {
    final b = _b;
    if (b == null || page < 1 || page > b.lines.length) return const [];
    return b.lines[page - 1];
  }

  @override
  double get referenceLineWidth => _b?.referenceWidth ?? 1828;

  @override
  Ayah? ayahByNumber(int number) {
    final b = _b;
    if (b == null || number < 1 || number > b.ayahs.length) return null;
    return b.ayahs[number - 1];
  }

  @override
  int pageOf(int surah, int ayah) {
    final b = _b;
    if (b == null) return 1;
    final i = SurahMetadata.globalAyah(surah, ayah.clamp(1, SurahMetadata.surah(surah).ayahCount)) - 1;
    return b.ayahs[i].page;
  }

  @override
  int firstPageOfSurah(int surah) => pageOf(surah, 1);

  @override
  List<SearchResult> search(String query, {int limit = 300}) {
    final b = _b;
    final q = ArabicUtils.searchKey(query);
    if (b == null || q.isEmpty) return const [];
    final results = <SearchResult>[];
    for (var i = 0; i < b.normalized.length && results.length < limit; i++) {
      if (b.normalized[i].contains(q)) {
        final a = b.ayahs[i];
        results.add(SearchResult(a, SurahMetadata.surah(a.surah).name));
      }
    }
    return results;
  }
}
