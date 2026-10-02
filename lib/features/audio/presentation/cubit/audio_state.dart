import 'package:equatable/equatable.dart';

class AudioState extends Equatable {
  final bool hasQueue;
  final bool playing;
  final bool buffering;
  final int? surah;

  /// 0 means the Basmala intro.
  final int? ayah;
  final String? title;
  final Duration duration;
  final int queueIndex;
  final int queueLength;
  final String reciterId;
  final double speed;
  final int loopsRemaining;
  final bool infiniteLoop;
  final bool isMemorization;
  final String? error;

  const AudioState({
    this.hasQueue = false,
    this.playing = false,
    this.buffering = false,
    this.surah,
    this.ayah,
    this.title,
    this.duration = Duration.zero,
    this.queueIndex = 0,
    this.queueLength = 0,
    this.reciterId = 'ar.alafasy',
    this.speed = 1.0,
    this.loopsRemaining = 0,
    this.infiniteLoop = false,
    this.isMemorization = false,
    this.error,
  });

  bool isCurrent(int s, int a) => hasQueue && surah == s && ayah == a;

  AudioState copyWith({
    bool? hasQueue,
    bool? playing,
    bool? buffering,
    int? surah,
    int? ayah,
    String? title,
    Duration? duration,
    int? queueIndex,
    int? queueLength,
    String? reciterId,
    double? speed,
    int? loopsRemaining,
    bool? infiniteLoop,
    bool? isMemorization,
    String? error,
    bool clearError = false,
  }) {
    return AudioState(
      hasQueue: hasQueue ?? this.hasQueue,
      playing: playing ?? this.playing,
      buffering: buffering ?? this.buffering,
      surah: surah ?? this.surah,
      ayah: ayah ?? this.ayah,
      title: title ?? this.title,
      duration: duration ?? this.duration,
      queueIndex: queueIndex ?? this.queueIndex,
      queueLength: queueLength ?? this.queueLength,
      reciterId: reciterId ?? this.reciterId,
      speed: speed ?? this.speed,
      loopsRemaining: loopsRemaining ?? this.loopsRemaining,
      infiniteLoop: infiniteLoop ?? this.infiniteLoop,
      isMemorization: isMemorization ?? this.isMemorization,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        hasQueue,
        playing,
        buffering,
        surah,
        ayah,
        title,
        duration,
        queueIndex,
        queueLength,
        reciterId,
        speed,
        loopsRemaining,
        infiniteLoop,
        isMemorization,
        error,
      ];
}
