import 'dart:math' as math;
import 'dart:typed_data';

/// Tells a pause in the recitation from the sound itself (not from the
/// model, which stays silent through a long madd and would cut the word).
///
/// The same rules are used by tool/tasmee/eval_model.py.
class PauseDetector {
  /// 30 ms frames at 16 kHz.
  static const frame = 480;

  /// Silence this long after speech is a pause.
  static const pauseMs = 1100;

  double _noise = 0.003;
  int _silentFrames = 0;
  bool _speech = false;

  /// Feeds samples; true when a pause has just been reached.
  bool feed(Float32List samples) {
    var paused = false;
    for (var o = 0; o + frame <= samples.length; o += frame) {
      var sum = 0.0;
      for (var i = o; i < o + frame; i++) {
        sum += samples[i] * samples[i];
      }
      final rms = math.sqrt(sum / frame);
      // Background level: follows quieter frames quickly, rises only with
      // frames close to it (a fan, a street), never with the voice.
      if (rms < _noise) {
        _noise = math.max(0.0003, 0.9 * rms + 0.1 * _noise);
      } else if (rms < _noise * 2) {
        _noise = 0.99 * _noise + 0.01 * rms;
      }
      // Low enough for a ghunna hummed with closed lips (quiet but speech).
      final loud = rms > math.max(0.0015, _noise * 3);
      if (loud) {
        _speech = true;
        _silentFrames = 0;
      } else if (_speech) {
        _silentFrames++;
        if (_silentFrames * 30 >= pauseMs) {
          _speech = false;
          _silentFrames = 0;
          paused = true;
        }
      }
    }
    return paused;
  }

  void reset() {
    _silentFrames = 0;
    _speech = false;
  }
}
