import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/data/surah_metadata.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/arabic_utils.dart';
import '../../media/media_catalog.dart';
import '../../media/media_downloads.dart';
import '../../quran/presentation/mushaf/mushaf_page.dart' show juzName;
import '../domain/reciter.dart';
import 'playlist_builder.dart';
import 'quran_audio_handler.dart';

/// The library shown in Android Auto (and any other media browser):
///
/// * القرآن الكريم — the 114 surahs with the reciter chosen in the app;
/// * المشايخ — every full-surah reciter, then his 114 surahs;
/// * الإذاعات — the Quran radios (official, reciters, themes).
///
/// It works without the app's screens, so it uses the data layer directly.
///
/// The look: every surah has its own tile (tool/car/make_car_art.py), the
/// reciters are a grid of their photos, and the long lists are split under
/// headings (the juz, the region, the kind of radio).
class CarMedia {
  final QuranAudioHandler _handler;
  final PlaylistBuilder _builder;
  final StorageService _storage;

  CarMedia(this._handler, this._builder, this._storage);

  static const _quran = 'quran';
  static const _reciters = 'reciters';
  static const _radios = 'radios';

  // Plain PNG drawables: Android Auto cannot draw the adaptive launcher icon
  // (it showed white squares).
  static Uri _icon(String name) => Uri.parse('android.resource://com.alhuda.islamic.app/drawable/car_$name');
  static final _radioArt = _icon('radio');
  static final _art = _icon('surah');
  static Uri _surahArt(int surah) => _icon('s_$surah');
  // Every catalog reciter has a tile: his photo, or his name in gold.
  static Uri _reciterArt(String key) => _icon('r_${key.replaceAll('_mj', '')}');

  // Android Auto's content-style extras (androidx.media.utils.MediaConstants).
  static const _browsableHint = 'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT';
  static const _playableHint = 'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT';
  static const _groupTitle = 'android.media.browse.CONTENT_STYLE_GROUP_TITLE_HINT';
  static const _list = 1;
  static const _grid = 2;

  /// The juz each surah starts in: the surah lists are grouped by it.
  static const _startJuz = [
    1, 1, 3, 4, 6, 7, 8, 9, 10, 11, 11, 12, 13, 13, 14, 14, 15, 15, 16, 16, //
    17, 17, 18, 18, 18, 19, 19, 20, 20, 21, 21, 21, 21, 22, 22, 22, 23, 23, 23, 24, //
    24, 25, 25, 25, 25, 26, 26, 26, 26, 26, 26, 27, 27, 27, 27, 27, 27, 28, 28, 28, //
    28, 28, 28, 28, 28, 28, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29,
  ];
  static int _juz(int surah) => surah <= _startJuz.length ? _startJuz[surah - 1] : 30;

  static const _regions = {
    MediaRegion.eg: 'قراء مصر',
    MediaRegion.gulf: 'قراء الحرمين والخليج',
    MediaRegion.other: 'قراء آخرون',
  };

  static List<MediaRadio> get _allRadios => [...kOfficialRadios, ...kReciterRadios, ...kThemeRadios];

  Map<String, dynamic> get _settings {
    final raw = _storage.settings.get('app_settings');
    return raw is Map ? Map<String, dynamic>.from(raw) : const {};
  }

  Reciter get _appReciter => Reciters.byId(_settings['reciterId'] as String? ?? 'ar.alafasy');

  double get _speed => (_settings['playbackSpeed'] as num?)?.toDouble() ?? 1.0;

  MediaItem _folder(String id, String title, {String? subtitle, Uri? art, Map<String, dynamic>? extras}) =>
      MediaItem(id: id, title: title, displaySubtitle: subtitle, artUri: art ?? _art, playable: false, extras: extras);

  MediaItem _surahItem(String id, int surah, String reciter, {bool grouped = false}) {
    final info = SurahMetadata.surah(surah);
    return MediaItem(
      id: id,
      title: 'سورة ${info.name}',
      artist: reciter,
      displaySubtitle: '${info.revelationAr} • ${_ayahs(info.ayahCount)} • $reciter',
      artUri: _surahArt(surah),
      playable: true,
      extras: grouped ? {_groupTitle: juzName(_juz(surah))} : null,
    );
  }

  static String _ayahs(int n) {
    final d = ArabicUtils.toArabicDigits(n);
    if (n == 1) return 'آية';
    if (n == 2) return 'آيتان';
    return n % 100 >= 3 && n % 100 <= 10 ? '$d آيات' : '$d آية';
  }

  List<MediaItem> children(String parent) {
    if (parent == AudioService.browsableRootId) {
      return [
        // Root tabs: Android Auto tints these, so they must be white vectors.
        _folder(_quran, 'القرآن الكريم', subtitle: _appReciter.nameAr, art: _icon('tab_quran'), extras: {_playableHint: _list}),
        // The reciters as a grid of their photos.
        _folder(_reciters, 'المشايخ',
            subtitle: 'المصحف كاملًا بأصوات كبار القراء', art: _icon('tab_reciter'), extras: {_browsableHint: _grid}),
        _folder(_radios, 'الإذاعات', subtitle: 'بث مباشر على مدار الساعة', art: _icon('tab_radio'), extras: {_playableHint: _list}),
      ];
    }
    if (parent == AudioService.recentRootId) {
      final now = _handler.mediaItem.value;
      return now == null ? const [] : [now.copyWith(playable: true)];
    }
    if (parent == _quran) {
      final r = _appReciter;
      return [for (var s = 1; s <= 114; s++) _surahItem('surah:$s', s, r.nameAr, grouped: true)];
    }
    if (parent == _reciters) {
      return [
        // Grouped by region, the same order as the app's reciters page.
        for (final region in MediaRegion.values)
          for (final r in MediaCatalog.reciters.where((r) => r.region == region))
            // Same reciter, two recitations: name the style so they differ.
            _folder('reciter:${r.key}', r.mujawwad ? '${r.name} • ${r.style}' : r.name,
                subtitle: r.style,
                art: _reciterArt(r.key),
                extras: {_groupTitle: _regions[region]!, _playableHint: _list}),
      ];
    }
    if (parent.startsWith('reciter:')) {
      final r = MediaCatalog.byId(parent.substring(8));
      if (r == null) return const [];
      return [for (var s = 1; s <= 114; s++) _surahItem('msurah:${r.key}:$s', s, r.name, grouped: true)];
    }
    if (parent == _radios) {
      final groups = [
        ('الإذاعات الرسمية', kOfficialRadios),
        ('إذاعات القراء', kReciterRadios),
        ('إذاعات متنوعة', kThemeRadios),
      ];
      var i = 0;
      return [
        for (final (title, radios) in groups)
          for (final radio in radios) _radioItem(i++, radio, title),
      ];
    }
    return const [];
  }

  MediaItem _radioItem(int i, MediaRadio radio, [String? group]) => MediaItem(
        id: 'radio:$i',
        title: radio.name,
        displaySubtitle: radio.subtitle ?? (radio.reciterKey != null ? 'تلاوات على مدار الساعة' : 'بث مباشر'),
        artUri: radio.reciterKey != null ? _reciterArt(radio.reciterKey!) : _radioArt,
        playable: true,
        extras: group == null ? null : {_groupTitle: group},
      );

  MediaItem? item(String id) {
    for (final parent in [_quran, _radios]) {
      for (final m in children(parent)) {
        if (m.id == id) return m;
      }
    }
    if (id.startsWith('msurah:')) {
      final p = id.split(':');
      final r = MediaCatalog.byId(p[1]);
      final s = int.tryParse(p[2]);
      if (r != null && s != null) return _surahItem(id, s, r.name);
    }
    return null;
  }

  Future<void> play(String id) async {
    try {
      await _play(id);
    } catch (_) {
      _handler.reportError('تعذر التشغيل الآن، تحقق من الاتصال');
    }
  }

  Future<void> _play(String id) async {
    final p = id.split(':');
    switch (p.first) {
      case 'surah':
        await _playSurah(int.parse(p[1]));
      case 'msurah':
        final r = MediaCatalog.byId(p[1]);
        if (r != null) await _playMediaSurah(r, int.parse(p[2]));
      case 'radio':
        final i = int.parse(p[1]);
        final all = _allRadios;
        if (i >= 0 && i < all.length) await _playRadio(all[i]);
    }
  }

  /// Voice: «شغّل سورة الكهف»، «سورة يس للمنشاوي»، «إذاعة القرآن الكريم».
  Future<void> search(String query) async {
    final q = ArabicUtils.normalize(query);
    final surah = _findSurah(q);
    final reciter = _findReciter(q);
    if (reciter != null) return _playMediaSurah(reciter, surah ?? 1);
    if (surah != null) return _playSurah(surah);
    final radios = _allRadios;
    for (final r in radios) {
      if (q.contains(ArabicUtils.normalize(r.name))) return _playRadio(r);
    }
    if (q.contains('اذاعه') || q.contains('راديو')) return _playRadio(radios.first);
    await _playSurah(1);
  }

  List<MediaItem> searchItems(String query) {
    final q = ArabicUtils.normalize(query);
    final out = <MediaItem>[];
    final s = _findSurah(q);
    if (s != null) out.add(_surahItem('surah:$s', s, _appReciter.nameAr));
    final r = _findReciter(q);
    if (r != null) out.add(_surahItem('msurah:${r.key}:${s ?? 1}', s ?? 1, r.name));
    final radios = _allRadios;
    for (var i = 0; i < radios.length; i++) {
      if (ArabicUtils.normalize(radios[i].name).contains(q)) {
        out.add(_radioItem(i, radios[i]));
      }
    }
    return out;
  }

  int? _findSurah(String q) {
    int? best;
    var bestLen = 0;
    for (final s in SurahMetadata.all) {
      final name = ArabicUtils.normalize(s.name);
      if (name.length > bestLen && q.contains(name)) {
        best = s.number;
        bestLen = name.length;
      }
    }
    return best;
  }

  MediaReciter? _findReciter(String q) {
    for (final r in MediaCatalog.reciters) {
      final parts = ArabicUtils.normalize(r.name).split(' ');
      // The family name is what people say: «المنشاوي»، «للحصري»، «العفاسي».
      final last = parts.last.startsWith('ال') ? parts.last.substring(2) : parts.last;
      if (last.length >= 3 && q.contains(last)) return r;
      if (q.contains(ArabicUtils.normalize(r.name))) return r;
    }
    return null;
  }

  Future<void> _playSurah(int surah) async {
    final info = SurahMetadata.surah(surah);
    final playlist = _builder.build(
      reciter: _appReciter,
      fromGlobal: SurahMetadata.globalAyah(surah, 1),
      toGlobal: SurahMetadata.globalAyah(surah, info.ayahCount),
    );
    if (playlist.isEmpty) return;
    await _handler.loadPlaylist(items: playlist.items, sources: playlist.sources, speed: _speed);
  }

  Future<void> _playMediaSurah(MediaReciter reciter, int surah) async {
    await MediaDownloads.instance.init();
    final items = <MediaItem>[];
    final sources = <AudioSource>[];
    for (var s = surah; s <= 114; s++) {
      final info = SurahMetadata.surah(s);
      final item = MediaItem(
        id: '${reciter.id}:$s',
        title: 'سورة ${info.name}',
        album: 'القرآن الكريم',
        artist: reciter.mujawwad ? '${reciter.name} • ${reciter.style}' : reciter.name,
        extras: <String, dynamic>{'surah': s, 'reciter': reciter.id},
      );
      final local = MediaDownloads.instance.localPath(reciter, s);
      items.add(item);
      sources.add(local != null ? AudioSource.file(local, tag: item) : AudioSource.uri(Uri.parse(reciter.urlFor(s)), tag: item));
    }
    await _handler.loadPlaylist(items: items, sources: sources, speed: _speed);
  }

  Future<void> _playRadio(MediaRadio radio) async {
    for (final url in radio.urls) {
      try {
        await _handler.playStream(
          url: url,
          title: radio.name,
          artist: radio.subtitle ?? 'بث مباشر',
          reciter: radio.reciterKey,
        );
        return;
      } catch (_) {
        // next mirror
      }
    }
    _handler.reportError('تعذر تشغيل ${radio.name} الآن، تحقق من الاتصال');
  }
}
