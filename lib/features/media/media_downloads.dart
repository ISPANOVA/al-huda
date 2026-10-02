import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'media_catalog.dart';

/// Offline copies of full-surah recitations from the media section.
/// Files live in `<documents>/media/<reciterKey>/<sss>.mp3`; a file that
/// exists (without `.part`) is a finished download.
class MediaDownloads extends ChangeNotifier {
  MediaDownloads._();

  static final MediaDownloads instance = MediaDownloads._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(minutes: 2),
    headers: {'User-Agent': 'AlHuda/1.0 (Android)'},
  ));

  String? _root;
  final Set<String> _done = {};
  final Map<String, double> _progress = {};
  final Map<String, CancelToken> _tokens = {};
  final Set<String> _failed = {};

  static String _k(MediaReciter r, int s) => '${r.key}/$s';
  static String _file(int s) => '${s.toString().padLeft(3, '0')}.mp3';

  Future<void> init() async {
    if (_root != null) return;
    final docs = await getApplicationDocumentsDirectory();
    _root = '${docs.path}/media';
    final dir = Directory(_root!);
    await dir.create(recursive: true);
    await for (final e in dir.list(recursive: true, followLinks: false)) {
      if (e is! File || !e.path.endsWith('.mp3')) continue;
      final parts = e.path.split(Platform.pathSeparator);
      final s = int.tryParse(parts.last.replaceAll('.mp3', ''));
      if (s != null) _done.add('${parts[parts.length - 2]}/$s');
    }
    notifyListeners();
  }

  bool isDownloaded(MediaReciter r, int s) => _done.contains(_k(r, s));
  double? progress(MediaReciter r, int s) => _progress[_k(r, s)];
  bool failed(MediaReciter r, int s) => _failed.contains(_k(r, s));

  String? localPath(MediaReciter r, int s) =>
      _root != null && isDownloaded(r, s) ? '$_root/${r.key}/${_file(s)}' : null;

  int countFor(MediaReciter r) => _done.where((k) => k.startsWith('${r.key}/')).length;

  List<int> surahsFor(MediaReciter r) =>
      [for (final k in _done) if (k.startsWith('${r.key}/')) int.parse(k.split('/').last)]..sort();

  /// Reciters that have at least one downloaded surah.
  List<MediaReciter> get reciters => [
        for (final r in MediaCatalog.reciters)
          if (countFor(r) > 0) r,
      ];

  int get totalCount => _done.length;

  Future<void> download(MediaReciter r, int s) async {
    await init();
    final k = _k(r, s);
    if (_done.contains(k) || _tokens.containsKey(k)) return;
    final token = CancelToken();
    _tokens[k] = token;
    _failed.remove(k);
    _progress[k] = 0;
    notifyListeners();
    final dir = Directory('$_root/${r.key}');
    await dir.create(recursive: true);
    final target = '${dir.path}/${_file(s)}';
    final tmp = '$target.part';
    var lastTick = 0;
    try {
      await _dio.download(
        r.urlFor(s),
        tmp,
        cancelToken: token,
        onReceiveProgress: (got, total) {
          if (total <= 0) return;
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastTick < 120 && got < total) return;
          lastTick = now;
          _progress[k] = got / total;
          notifyListeners();
        },
      );
      await File(tmp).rename(target);
      _done.add(k);
    } catch (e) {
      if (!(e is DioException && CancelToken.isCancel(e))) _failed.add(k);
      final f = File(tmp);
      if (f.existsSync()) await f.delete();
    } finally {
      _tokens.remove(k);
      _progress.remove(k);
      notifyListeners();
    }
  }

  void cancel(MediaReciter r, int s) => _tokens[_k(r, s)]?.cancel();

  Future<void> delete(MediaReciter r, int s) async {
    await init();
    final f = File('$_root/${r.key}/${_file(s)}');
    if (f.existsSync()) await f.delete();
    _done.remove(_k(r, s));
    notifyListeners();
  }

  Future<int> totalBytes() async {
    await init();
    var total = 0;
    await for (final e in Directory(_root!).list(recursive: true, followLinks: false)) {
      if (e is File) total += await e.length();
    }
    return total;
  }
}
