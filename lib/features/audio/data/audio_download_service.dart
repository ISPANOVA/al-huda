import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/data/surah_metadata.dart';
import '../../../core/services/storage_service.dart';
import '../domain/reciter.dart';

class DownloadCancelledException implements Exception {
  const DownloadCancelledException();
}

/// Downloads per-ayah recitation files for offline playback.
/// Files live in `<app documents>/audio/<reciterId>/<globalAyah>.mp3`.
class AudioDownloadService {
  static const int _parallel = 4;

  final Dio _dio;
  final StorageService _storage;
  String? _rootPath;

  AudioDownloadService(this._dio, this._storage);

  Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    _rootPath = '${docs.path}/audio';
    await Directory(_rootPath!).create(recursive: true);
  }

  String _path(String reciterId, int global) => '$_rootPath/$reciterId/$global.mp3';

  /// Synchronous lookup used when building playlists.
  String? localFileIfExists(String reciterId, int global) {
    if (_rootPath == null) return null;
    final f = File(_path(reciterId, global));
    return f.existsSync() ? f.path : null;
  }

  String _key(String reciterId, int surah) => '$reciterId:$surah';

  bool isSurahDownloaded(String reciterId, int surah) => _storage.downloads.get(_key(reciterId, surah)) == true;

  Set<int> downloadedSurahs(String reciterId) => {
        for (var s = 1; s <= 114; s++)
          if (isSurahDownloaded(reciterId, s)) s,
      };

  /// Downloads every ayah of [surah] (plus the Basmala used as intro).
  /// Already-present files are skipped, so interrupted downloads resume.
  Future<void> downloadSurah(
    Reciter reciter,
    int surah, {
    void Function(int done, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (_rootPath == null) await init();
    await Directory('$_rootPath/${reciter.id}').create(recursive: true);

    final count = SurahMetadata.surah(surah).ayahCount;
    final globals = <int>{
      1, // Basmala (Al-Fatihah 1) played before each surah
      for (var a = 1; a <= count; a++) SurahMetadata.globalAyah(surah, a),
    }.toList();

    var done = 0;
    onProgress?.call(done, globals.length);
    for (var i = 0; i < globals.length; i += _parallel) {
      if (cancelToken?.isCancelled ?? false) throw const DownloadCancelledException();
      final batch = globals.skip(i).take(_parallel);
      await Future.wait(batch.map((g) async {
        final target = File(_path(reciter.id, g));
        if (!target.existsSync()) {
          final tmp = '${target.path}.part';
          await _dio.download(reciter.urlFor(g), tmp, cancelToken: cancelToken);
          await File(tmp).rename(target.path);
        }
        done++;
        onProgress?.call(done, globals.length);
      }));
    }
    await _storage.downloads.put(_key(reciter.id, surah), true);
  }

  Future<void> deleteSurah(Reciter reciter, int surah) async {
    final count = SurahMetadata.surah(surah).ayahCount;
    for (var a = 1; a <= count; a++) {
      final f = File(_path(reciter.id, SurahMetadata.globalAyah(surah, a)));
      if (f.existsSync()) await f.delete();
    }
    await _storage.downloads.delete(_key(reciter.id, surah));
  }

  Future<int> totalBytes() async {
    if (_rootPath == null) return 0;
    final dir = Directory(_rootPath!);
    if (!dir.existsSync()) return 0;
    var total = 0;
    await for (final e in dir.list(recursive: true, followLinks: false)) {
      if (e is File) total += await e.length();
    }
    return total;
  }
}
