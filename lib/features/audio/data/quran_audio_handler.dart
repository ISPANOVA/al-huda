import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Background-capable player exposed to the OS media session
/// (notification, lock screen, headset buttons, Bluetooth controls).
///
/// The queue is a list of *per-ayah* sources which gives us exact
/// verse-level synchronisation for highlighting, plus memorization loops.
class QuranAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  int _loopsRemaining = 0;
  bool _infiniteLoop = false;

  QuranAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());

    // Pause on interruptions (calls) and when headphones are unplugged.
    session.becomingNoisyEventStream.listen((_) => _player.pause());

    _player.playbackEventStream.listen(
      _broadcastState,
      onError: (Object e, StackTrace st) {
        debugPrint('Audio playback error: $e');
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
          errorMessage: e.toString(),
        ));
      },
    );

    _player.currentIndexStream.listen((index) {
      final q = queue.value;
      if (index != null && index < q.length) mediaItem.add(q[index]);
    });

    _player.durationStream.listen((duration) {
      final item = mediaItem.value;
      if (item != null && duration != null && item.duration != duration) {
        mediaItem.add(item.copyWith(duration: duration));
      }
    });

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) _onRangeCompleted();
    });
  }

  int get loopsRemaining => _loopsRemaining;
  bool get isInfiniteLoop => _infiniteLoop;

  /// Loads a new queue. [rangeRepeat] <= 0 loops forever.
  Future<void> loadPlaylist({
    required List<MediaItem> items,
    required List<AudioSource> sources,
    int initialIndex = 0,
    int rangeRepeat = 1,
    double speed = 1.0,
    bool autoPlay = true,
  }) async {
    assert(items.length == sources.length);
    if (items.isEmpty) return;
    _infiniteLoop = rangeRepeat <= 0;
    _loopsRemaining = _infiniteLoop ? 0 : rangeRepeat - 1;
    _emitLoopState();

    final start = initialIndex.clamp(0, items.length - 1);
    queue.add(items);
    mediaItem.add(items[start]);
    await _player.setSpeed(speed);
    await _player.setAudioSources(sources, initialIndex: start, initialPosition: Duration.zero);
    if (autoPlay) unawaited(_player.play());
  }

  /// Live radio stream (single item, no looping).
  Future<void> playStream({required String url, required String title, required String artist}) async {
    _infiniteLoop = false;
    _loopsRemaining = 0;
    _emitLoopState();
    final item = MediaItem(
      id: url,
      title: title,
      artist: artist,
      album: 'بث مباشر',
      extras: <String, dynamic>{'live': true},
    );
    queue.add([item]);
    mediaItem.add(item);
    await _player.setSpeed(1);
    await _player.setAudioSource(AudioSource.uri(Uri.parse(url), tag: item));
    unawaited(_player.play());
  }

  Future<void> _onRangeCompleted() async {
    if (queue.value.isEmpty) return;
    if (_infiniteLoop || _loopsRemaining > 0) {
      if (!_infiniteLoop) _loopsRemaining--;
      _emitLoopState();
      await _player.seek(Duration.zero, index: 0);
      unawaited(_player.play());
    } else {
      await _player.pause();
      await _player.seek(Duration.zero, index: 0);
    }
  }

  void _emitLoopState() {
    customState.add(<String, dynamic>{'loopsRemaining': _loopsRemaining, 'infinite': _infiniteLoop});
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() async {
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seekToPrevious();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    await _player.seek(Duration.zero, index: index);
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> stop() async {
    await _player.stop();
    queue.add(const []);
    mediaItem.add(null);
    playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.idle, playing: false));
    await super.stop();
  }

  @override
  Future<void> onTaskRemoved() => stop();

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }
}
