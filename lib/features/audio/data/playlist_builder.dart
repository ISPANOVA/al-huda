import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/data/surah_metadata.dart';
import '../../../core/utils/arabic_utils.dart';
import '../domain/reciter.dart';
import 'audio_download_service.dart';

class BuiltPlaylist {
  final List<MediaItem> items;
  final List<AudioSource> sources;

  const BuiltPlaylist(this.items, this.sources);

  bool get isEmpty => items.isEmpty;
}

/// Turns an ayah range into a per-ayah playlist. Local files are used when
/// downloaded, otherwise the CDN stream. Before ayah 1 of every surah
/// (except Al-Fatihah and At-Tawbah) the Basmala is inserted with `ayah = 0`.
class PlaylistBuilder {
  final AudioDownloadService _downloads;

  PlaylistBuilder(this._downloads);

  BuiltPlaylist build({
    required Reciter reciter,
    required int fromGlobal,
    required int toGlobal,
    int ayahRepeat = 1,
    bool includeBasmala = true,
  }) {
    final items = <MediaItem>[];
    final sources = <AudioSource>[];
    final repeat = ayahRepeat < 1 ? 1 : ayahRepeat;
    final start = fromGlobal.clamp(1, SurahMetadata.totalAyahs);
    final end = toGlobal.clamp(start, SurahMetadata.totalAyahs);

    void add(int global, int surah, int ayah) {
      final info = SurahMetadata.surah(surah);
      final item = MediaItem(
        id: '${reciter.id}:$global:${items.length}',
        title: ayah == 0
            ? 'سورة ${info.name} • البسملة'
            : 'سورة ${info.name} • الآية ${ArabicUtils.toArabicDigits(ayah)}',
        album: 'القرآن الكريم',
        artist: reciter.nameAr,
        extras: <String, dynamic>{'surah': surah, 'ayah': ayah, 'global': global, 'reciter': reciter.id},
      );
      final local = _downloads.localFileIfExists(reciter.id, global);
      items.add(item);
      sources.add(local != null ? AudioSource.file(local, tag: item) : AudioSource.uri(Uri.parse(reciter.urlFor(global)), tag: item));
    }

    for (var g = start; g <= end; g++) {
      final ref = SurahMetadata.fromGlobal(g);
      if (includeBasmala && ref.ayah == 1 && ref.surah != 1 && ref.surah != 9) {
        add(1, ref.surah, 0);
      }
      for (var r = 0; r < repeat; r++) {
        add(g, ref.surah, ref.ayah);
      }
    }
    return BuiltPlaylist(items, sources);
  }
}
