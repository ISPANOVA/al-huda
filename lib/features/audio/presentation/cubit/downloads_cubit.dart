import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/audio_download_service.dart';
import '../../domain/reciter.dart';

class DownloadsState extends Equatable {
  final String reciterId;
  final Set<int> downloaded;

  /// surah -> 0..1 for active downloads.
  final Map<int, double> progress;
  final Map<int, String> errors;
  final int totalBytes;

  const DownloadsState({
    required this.reciterId,
    this.downloaded = const {},
    this.progress = const {},
    this.errors = const {},
    this.totalBytes = 0,
  });

  DownloadsState copyWith({
    String? reciterId,
    Set<int>? downloaded,
    Map<int, double>? progress,
    Map<int, String>? errors,
    int? totalBytes,
  }) =>
      DownloadsState(
        reciterId: reciterId ?? this.reciterId,
        downloaded: downloaded ?? this.downloaded,
        progress: progress ?? this.progress,
        errors: errors ?? this.errors,
        totalBytes: totalBytes ?? this.totalBytes,
      );

  @override
  List<Object?> get props => [reciterId, downloaded, progress, errors, totalBytes];
}

class DownloadsCubit extends Cubit<DownloadsState> {
  final AudioDownloadService _service;
  final Map<int, CancelToken> _tokens = {};

  DownloadsCubit(this._service, String reciterId) : super(DownloadsState(reciterId: reciterId)) {
    _refresh();
  }

  Reciter get reciter => Reciters.byId(state.reciterId);

  Future<void> _refresh() async {
    final bytes = await _service.totalBytes();
    if (isClosed) return;
    emit(state.copyWith(downloaded: _service.downloadedSurahs(state.reciterId), totalBytes: bytes));
  }

  void changeReciter(String id) {
    for (final t in _tokens.values) {
      t.cancel();
    }
    _tokens.clear();
    emit(DownloadsState(reciterId: id));
    _refresh();
  }

  Future<void> download(int surah) async {
    if (_tokens.containsKey(surah)) return;
    final token = CancelToken();
    _tokens[surah] = token;
    final reciterAtStart = reciter;
    emit(state.copyWith(
      progress: {...state.progress, surah: 0},
      errors: Map.of(state.errors)..remove(surah),
    ));
    try {
      await _service.downloadSurah(
        reciterAtStart,
        surah,
        cancelToken: token,
        onProgress: (done, total) {
          if (isClosed || state.reciterId != reciterAtStart.id) return;
          emit(state.copyWith(progress: {...state.progress, surah: total == 0 ? 0 : done / total}));
        },
      );
    } on DownloadCancelledException {
      // user cancelled
    } on DioException catch (e) {
      if (!CancelToken.isCancel(e) && !isClosed) {
        emit(state.copyWith(errors: {...state.errors, surah: 'تعذر التحميل، تحقق من الاتصال'}));
      }
    } catch (_) {
      if (!isClosed) emit(state.copyWith(errors: {...state.errors, surah: 'حدث خطأ أثناء التحميل'}));
    } finally {
      _tokens.remove(surah);
      if (!isClosed && state.reciterId == reciterAtStart.id) {
        emit(state.copyWith(progress: Map.of(state.progress)..remove(surah)));
        await _refresh();
      }
    }
  }

  void cancel(int surah) => _tokens[surah]?.cancel();

  Future<void> delete(int surah) async {
    await _service.deleteSurah(reciter, surah);
    await _refresh();
  }

  @override
  Future<void> close() {
    for (final t in _tokens.values) {
      t.cancel();
    }
    return super.close();
  }
}
