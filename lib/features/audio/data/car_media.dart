import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/data/surah_metadata.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/arabic_utils.dart';
import '../../media/media_catalog.dart';
import '../../media/media_downloads.dart';
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
class CarMedia {
  final QuranAudioHandler _handler;
  final PlaylistBuilder _builder;
  final StorageService _storage;

  CarMedia(this._handler, this._builder, this._storage);

  static const _quran = 'quran';
  static const _reciters = 'reciters';
  static const _radios = 'radios';

  static final _art = Uri.parse('android.resource://com.alhuda.islamic.app/mipmap/ic_launcher');

  static List<MediaRadio> get _allRadios => [...kOfficialRadios, ...kReciterRadios, ...kThemeRadios];

  Map<String, dynamic> get _settings {
    final raw = _storage.settings.get('app_settings');
    return raw is Map ? Map<String, dynamic>.from(raw) : const {};
  }

  Reciter get _appReciter => Reciters.byId(_settings['reciterId'] as String? ?? 'ar.alafasy');

  double get _speed => (_settings['playbackSpeed'] as num?)?.toDouble() ?? 1.0;

  MediaItem _folder(String id, String title, {String? subtitle}) =>
      MediaItem(id: id, title: title, displaySubtitle: subtitle, artUri: _art, playable: false);

  MediaItem _surahItem(String id, int surah, String reciter) {
    final info = SurahMetadata.surah(surah);
    return MediaItem(
      id: id,
      title: '${ArabicUtils.toArabicDigits(surah)}. سورة ${info.name}',
      artist: reciter,
      displaySubtitle: '$reciter • ${info.revelationAr} • ${ArabicUtils.toArabicDigits(info.ayahCount)} آية',
      artUri: _art,
      playable: true,
    );
  }

  List<MediaItem> children(String parent) {
    if (parent == AudioService.browsableRootId) {
      return [
        _folder(_quran, 'القرآن الكريم', subtitle: _appReciter.nameAr),
        _folder(_reciters, 'المشايخ', subtitle: 'المصحف كاملًا بأصوات كبار القراء'),
        _folder(_radios, 'الإذاعات', subtitle: 'بث مباشر على مدار الساعة'),
      ];
    }
    if (parent == AudioService.recentRootId) {
      final now = _handler.mediaItem.value;
      return now == null ? const [] : [now.copyWith(playable: true)];
    }
    if (parent == _quran) {
      final r = _appReciter;
      return [for (var s = 1; s <= 114; s++) _surahItem('surah:$s', s, r.nameAr)];
    }
    if (parent == _reciters) {
      return [
        for (final r in MediaCatalog.reciters)
          _folder('reciter:${r.key}', r.name, subtitle: r.style),
      ];
    }
    if (parent.startsWith('reciter:')) {
      final r = MediaCatalog.byId(parent.substring(8));
      if (r == null) return const [];
      return [for (var s = 1; s <= 114; s++) _surahItem('msurah:${r.key}:$s', s, r.name)];
    }
    if (parent == _radios) {
      final all = _allRadios;
      return [
        for (var i = 0; i < all.length; i++)
          MediaItem(
            id: 'radio:$i',
            title: all[i].name,
            displaySubtitle: all[i].subtitle ?? 'بث مباشر',
            artUri: _art,
            playable: true,
          ),
      ];
    }
    return const [];
  }

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
        out.add(MediaItem(id: 'radio:$i', title: radios[i].name, artUri: _art, playable: true));
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
      // The family name is what people say: «المنشاوي»، «الحصري»، «العفاسي».
      final last = parts.last;
      if (last.length >= 4 && q.contains(last)) return r;
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
        artUri: _art,
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
        await _handler.playStream(url: url, title: radio.name, artist: radio.subtitle ?? 'بث مباشر');
        return;
      } catch (_) {
        // next mirror
      }
    }
  }
}
