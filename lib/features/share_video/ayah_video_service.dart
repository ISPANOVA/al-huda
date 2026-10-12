import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/data/surah_metadata.dart';
import '../../core/utils/arabic_utils.dart';
import '../audio/data/audio_download_service.dart';
import '../audio/domain/reciter.dart';
import '../quran/domain/repositories/quran_repository.dart';
import 'video_frames.dart';

/// Where the work is, for the progress bar.
class VideoProgress {
  final String label;
  final double value; // 0..1

  const VideoProgress(this.label, this.value);
}

/// Builds the ayah video: downloads the recitation of each ayah, draws its
/// frames (Flutter, the Mushaf font) and hands both to the phone's encoder.
class AyahVideoService {
  static const _channel = MethodChannel('alhuda/video');
  static const fps = 24;

  final Dio dio;
  final AudioDownloadService downloads;
  final QuranRepository quran;

  AyahVideoService({required this.dio, required this.downloads, required this.quran});

  static Future<List<int>> supportedSize() async {
    try {
      final s = await _channel.invokeListMethod<int>('size');
      if (s != null && s.length == 2) return s;
    } catch (_) {}
    return const [720, 1280];
  }

  static Future<ui.Image?> loadAsset(String path) async {
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      return (await codec.getNextFrame()).image;
    } catch (_) {
      return null;
    }
  }

  static Future<ui.Image?> loadFile(String path, {int maxSide = 2200}) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: null, targetHeight: null);
      final img = (await codec.getNextFrame()).image;
      if (img.width <= maxSide && img.height <= maxSide) return img;
      img.dispose();
      final scale = maxSide / (img.width > img.height ? img.width : img.height);
      final c2 = await ui.instantiateImageCodec(bytes, targetWidth: (img.width * scale).round());
      return (await c2.getNextFrame()).image;
    } catch (_) {
      return null;
    }
  }

  Future<String> _audio(Reciter reciter, int global, Directory dir) async {
    final local = downloads.localFileIfExists(reciter.id, global);
    if (local != null) return local;
    final f = File('${dir.path}/${reciter.id}_$global.mp3');
    if (await f.exists() && await f.length() > 0) return f.path;
    await dio.download(reciter.urlFor(global), f.path);
    return f.path;
  }

  Future<String> _png(ui.Picture picture, int width, int height, String path) async {
    final img = await picture.toImage(width, height);
    picture.dispose();
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    await File(path).writeAsBytes(data!.buffer.asUint8List(), flush: true);
    return path;
  }

  /// Renders surah [surah], ayahs [from]..[to]: the MP4's path and length.
  Future<(String, Duration)> build({
    required int surah,
    required int from,
    required int to,
    required Reciter reciter,
    required VideoFramePainter painter,
    required void Function(VideoProgress) onProgress,
  }) async {
    final size = await supportedSize();
    final width = size[0], height = size[1];
    final tmp = await getTemporaryDirectory();
    final work = Directory('${tmp.path}/video_work');
    final audioDir = Directory('${tmp.path}/video_audio');
    final outDir = Directory('${tmp.path}/videos');
    for (final d in [work, audioDir, outDir]) {
      await d.create(recursive: true);
    }
    for (final f in work.listSync()) {
      f.deleteSync(recursive: true);
    }
    for (final f in outDir.listSync()) {
      f.deleteSync(recursive: true);
    }

    final info = SurahMetadata.surah(surah);
    final ayahs = (await quran.getSurah(surah)).where((a) => a.numberInSurah >= from && a.numberInSurah <= to).toList();
    final surahTitle = 'سورة ${info.name}';

    // 1. The recitation, ayah by ayah (with the basmala before ayah 1).
    final withBasmala = from == 1 && surah != 1 && surah != 9;
    final globals = <int>[if (withBasmala) 1, for (final a in ayahs) a.number];
    final audio = <String>[];
    for (var i = 0; i < globals.length; i++) {
      onProgress(VideoProgress('تحميل التلاوة ${ArabicUtils.toArabicDigits(i + 1)} من ${ArabicUtils.toArabicDigits(globals.length)}',
          0.25 * i / globals.length));
      audio.add(await _audio(reciter, globals[i], audioDir));
    }

    // 2. The frames.
    final segments = <Map<String, Object?>>[];
    var n = 0;
    Future<String> frame(FrameContent c) {
      final rec = ui.PictureRecorder();
      painter.paintFrame(Canvas(rec), Size(width.toDouble(), height.toDouble()), c);
      return _png(rec.endRecording(), width, height, '${work.path}/f${n++}.png');
    }

    var ai = 0;
    if (withBasmala) {
      onProgress(const VideoProgress('تجهيز الصور', 0.25));
      final path = await frame(FrameContent(
          text: AppConstants.bismillah, ayahNumber: null, surahName: surahTitle, reciterName: reciter.nameAr, caption: 'البسملة'));
      segments.add({'audio': audio[ai++], 'silenceMs': 250, 'shots': [{'image': path, 'weight': 1.0}]});
    }
    for (var i = 0; i < ayahs.length; i++) {
      final a = ayahs[i];
      onProgress(VideoProgress('تجهيز الصور', 0.25 + 0.15 * i / ayahs.length));
      final pages = VideoFramePainter.split(a.text, a.numberInSurah);
      final shots = <Map<String, Object?>>[];
      for (var p = 0; p < pages.length; p++) {
        final last = p == pages.length - 1;
        final path = await frame(FrameContent(
          text: pages[p],
          ayahNumber: last ? a.numberInSurah : null,
          surahName: surahTitle,
          reciterName: reciter.nameAr,
          caption: 'الآية ${ArabicUtils.toArabicDigits(a.numberInSurah)}',
        ));
        shots.add({'image': path, 'weight': pages[p].length.toDouble()});
      }
      segments.add({'audio': audio[ai++], 'silenceMs': 250, 'shots': shots});
    }
    final rec = ui.PictureRecorder();
    painter.paintOutro(Canvas(rec), Size(width.toDouble(), height.toDouble()));
    final outro = await _png(rec.endRecording(), width, height, '${work.path}/outro.png');
    segments.add({'audio': null, 'silenceMs': 2600, 'shots': [{'image': outro, 'weight': 1.0}]});

    // 3. The phone's encoder.
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final out = '${outDir.path}/alhuda_${surah}_${from}_${to}_$stamp.mp4';
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'progress') {
        onProgress(VideoProgress('إنشاء الفيديو', 0.4 + 0.6 * (call.arguments as num).toDouble()));
      }
    });
    int ms;
    try {
      ms = await _channel.invokeMethod<int>('render', {
        'segments': segments,
        'out': out,
        'width': width,
        'height': height,
        'fps': fps,
      }) ?? 0;
    } finally {
      _channel.setMethodCallHandler(null);
      for (final f in work.listSync()) {
        f.deleteSync(recursive: true);
      }
    }
    return (out, Duration(milliseconds: ms));
  }

  static String shareText(String surahName, int from, int to, String reciter) {
    final range = from == to
        ? 'الآية ${ArabicUtils.toArabicDigits(from)}'
        : 'الآيات ${ArabicUtils.toArabicDigits(from)}–${ArabicUtils.toArabicDigits(to)}';
    return 'سورة $surahName • $range • بصوت $reciter\nمن تطبيق الهدى: ${AppConstants.shareUrl}';
  }

  /// [target]: whatsapp, instagram, facebook, or null for every app.
  static Future<bool> share(String path, String? target, String text) async {
    try {
      for (final pkg in switch (target) {
        'whatsapp' => ['com.whatsapp', 'com.whatsapp.w4b'],
        'instagram' => ['com.instagram.android'],
        'facebook' => ['com.facebook.katana', 'com.facebook.lite'],
        _ => <String>[],
      }) {
        if (await _channel.invokeMethod<bool>('share', {'path': path, 'package': pkg, 'text': text}) == true) return true;
      }
      if (target != null) return false;
      return await _channel.invokeMethod<bool>('share', {'path': path, 'package': null, 'text': text}) == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> saveToGallery(String path) async {
    try {
      return await _channel.invokeMethod<bool>('save', {'path': path}) == true;
    } catch (_) {
      return false;
    }
  }
}
