import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/surah_metadata.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../stats/data/stats_repository.dart';
import '../../../stats/domain/stats_entities.dart';
import '../../data/playlist_builder.dart';
import '../../data/quran_audio_handler.dart';
import '../../domain/reciter.dart';
import 'audio_state.dart';

class AudioCubit extends Cubit<AudioState> {
  final QuranAudioHandler _handler;
  final PlaylistBuilder _builder;
  final StatsRepository _stats;
  final SettingsCubit _settings;
  final List<StreamSubscription<dynamic>> _subs = [];
  int? _lastLoggedGlobal;

  AudioCubit(this._handler, this._builder, this._stats, this._settings)
      : super(AudioState(reciterId: _settings.state.reciterId, speed: _settings.state.playbackSpeed)) {
    _subs.add(_handler.playbackState.listen(_onPlaybackState));
    _subs.add(_handler.mediaItem.listen(_onMediaItem));
    _subs.add(_handler.queue.listen((q) => emit(state.copyWith(hasQueue: q.isNotEmpty, queueLength: q.length))));
    _subs.add(_handler.customState.listen((custom) {
      if (custom is Map) {
        emit(state.copyWith(
          loopsRemaining: (custom['loopsRemaining'] as num?)?.toInt() ?? 0,
          infiniteLoop: custom['infinite'] == true,
        ));
      }
    }));
  }

  /// Position stream for sliders (kept out of the state to avoid rebuild storms).
  Stream<Duration> get positionStream => AudioService.position;

  Reciter get reciter => Reciters.byId(_settings.state.reciterId);

  void _onPlaybackState(PlaybackState ps) {
    final buffering =
        ps.processingState == AudioProcessingState.loading || ps.processingState == AudioProcessingState.buffering;
    emit(state.copyWith(
      playing: ps.playing,
      buffering: buffering,
      queueIndex: ps.queueIndex ?? state.queueIndex,
      speed: ps.speed,
      error: ps.processingState == AudioProcessingState.error ? (ps.errorMessage ?? 'تعذر تشغيل التلاوة') : null,
      clearError: ps.processingState != AudioProcessingState.error,
    ));
  }

  void _onMediaItem(MediaItem? item) {
    if (item == null) {
      emit(const AudioState().copyWith(reciterId: state.reciterId, speed: state.speed));
      return;
    }
    final extras = item.extras ?? const {};
    final surah = (extras['surah'] as num?)?.toInt();
    final ayah = (extras['ayah'] as num?)?.toInt();
    final global = (extras['global'] as num?)?.toInt();
    emit(state.copyWith(
      surah: surah,
      ayah: ayah,
      title: item.title,
      duration: item.duration ?? Duration.zero,
      reciterId: extras['reciter'] as String? ?? state.reciterId,
    ));
    if (ayah != null && ayah > 0 && global != null && global != _lastLoggedGlobal) {
      _lastLoggedGlobal = global;
      _stats.log(StatType.listenedAyahs);
    }
  }

  Future<void> _load(
    int fromGlobal,
    int toGlobal, {
    int ayahRepeat = 1,
    int rangeRepeat = 1,
    bool memorization = false,
    Reciter? reciterOverride,
  }) async {
    final r = reciterOverride ?? reciter;
    final playlist = _builder.build(reciter: r, fromGlobal: fromGlobal, toGlobal: toGlobal, ayahRepeat: ayahRepeat);
    if (playlist.isEmpty) return;
    emit(state.copyWith(isMemorization: memorization, reciterId: r.id, clearError: true));
    await _handler.loadPlaylist(
      items: playlist.items,
      sources: playlist.sources,
      rangeRepeat: rangeRepeat,
      speed: _settings.state.playbackSpeed,
    );
  }

  /// Plays a whole surah starting at [fromAyah].
  Future<void> playSurah(int surah, {int fromAyah = 1}) {
    final info = SurahMetadata.surah(surah);
    final start = fromAyah.clamp(1, info.ayahCount);
    return _load(SurahMetadata.globalAyah(surah, start), SurahMetadata.globalAyah(surah, info.ayahCount));
  }

  /// Plays an arbitrary contiguous range (used by Athkar & Khatmah).
  Future<void> playAyahs(int surah, int fromAyah, int toAyah) =>
      _load(SurahMetadata.globalAyah(surah, fromAyah), SurahMetadata.globalAyah(surah, toAyah));

  /// Memorization mode: custom cross-surah range with repetition.
  Future<void> playRange(PlaybackRange range, {Reciter? reciter}) {
    final from = SurahMetadata.globalAyah(range.startSurah, range.startAyah);
    final to = SurahMetadata.globalAyah(range.endSurah, range.endAyah);
    return _load(
      from <= to ? from : to,
      from <= to ? to : from,
      ayahRepeat: range.ayahRepeat,
      rangeRepeat: range.rangeRepeat,
      memorization: true,
      reciterOverride: reciter,
    );
  }

  /// Jumps to an ayah if it's in the current queue, otherwise starts the surah there.
  Future<void> playFromAyah(int surah, int ayah) async {
    final q = _handler.queue.value;
    final index = q.indexWhere((m) => m.extras?['surah'] == surah && m.extras?['ayah'] == ayah);
    if (index >= 0 && !state.isMemorization) {
      await _handler.skipToQueueItem(index);
      if (!state.playing) unawaited(_handler.play());
    } else {
      await playSurah(surah, fromAyah: ayah);
    }
  }

  /// Plays a 24/7 Quran radio station.
  Future<void> playRadio(String url, String title) async {
    emit(state.copyWith(isMemorization: false, clearError: true));
    await _handler.playStream(url: url, title: title, artist: 'إذاعة القرآن الكريم');
  }

  /// Whole surah with a given reciter (media section).
  Future<void> playSurahWith(Reciter reciter, int surah) {
    final info = SurahMetadata.surah(surah);
    return _load(
      SurahMetadata.globalAyah(surah, 1),
      SurahMetadata.globalAyah(surah, info.ayahCount),
      reciterOverride: reciter,
    );
  }

  void togglePlay() {
    if (!state.hasQueue) return;
    if (state.playing) {
      _handler.pause();
    } else {
      unawaited(_handler.play());
    }
  }

  Future<void> next() => _handler.skipToNext();
  Future<void> previous() => _handler.skipToPrevious();
  Future<void> seek(Duration d) => _handler.seek(d);
  Future<void> stop() => _handler.stop();

  Future<void> setSpeed(double speed) async {
    await _settings.setPlaybackSpeed(speed);
    await _handler.setSpeed(speed);
  }

  /// Changes reciter and restarts from the current ayah.
  Future<void> changeReciter(String id) async {
    await _settings.setReciter(id);
    emit(state.copyWith(reciterId: id));
    if (state.hasQueue && !state.isMemorization && state.surah != null) {
      await playSurah(state.surah!, fromAyah: (state.ayah ?? 1).clamp(1, 286));
    }
  }

  @override
  Future<void> close() async {
    for (final s in _subs) {
      await s.cancel();
    }
    return super.close();
  }
}
