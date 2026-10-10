import 'dart:async';

/// No on-device model on this platform.
class QuranListener {
  static Future<bool> available() async => false;

  /// Prepares the model; false when it can't run here.
  Future<bool> prepare({void Function(double progress)? onProgress}) async => false;

  /// Starts the microphone. [onResult]: everything heard in the current
  /// utterance (grows) and whether the reciter paused (then the next result
  /// starts a new utterance). [onLevel]: microphone level 0..1.
  Future<bool> start({
    required void Function(String text, bool isFinal) onResult,
    void Function(double level)? onLevel,
    void Function(String error)? onError,
  }) async =>
      false;

  Future<void> stop() async {}

  bool get listening => false;

  void dispose() {}
}
