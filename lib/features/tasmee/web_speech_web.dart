import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';
import 'package:web/web.dart' as web;

@JS('SpeechRecognition')
extension type _Standard._(web.SpeechRecognition _) implements web.SpeechRecognition {
  external factory _Standard();
}

@JS('webkitSpeechRecognition')
extension type _Webkit._(web.SpeechRecognition _) implements web.SpeechRecognition {
  external factory _Webkit();
}

final bool _mobile = RegExp('Android|iPhone|iPad|iPod|Mobile', caseSensitive: false)
        .hasMatch(web.window.navigator.userAgent) ||
    // iPadOS reports a Mac.
    (web.window.navigator.userAgent.contains('Macintosh') && web.window.navigator.maxTouchPoints > 1);

bool get _hasStandard => web.window.hasProperty('SpeechRecognition'.toJS).toDart;
bool get _hasWebkit => web.window.hasProperty('webkitSpeechRecognition'.toJS).toDart;

/// Whether this browser can recognise speech at all (Chrome, Edge, Safari).
bool get webSpeechSupported => _hasStandard || _hasWebkit;

/// Replaces the plugin's web recognizer with one that behaves like the
/// Android recognizer the Tasmee was built on:
///
/// * one utterance per session (ends at a pause) — the page re-listens, just
///   as on the phone, so every result is the reciter's words from the start
///   of the utterance;
/// * the last words become a final result when the utterance ends;
/// * a start that is still waiting (Safari's microphone prompt) is not torn
///   down by the next listen call;
/// * browser error names are mapped to the Android ones the page knows.
void installWebSpeech() => SpeechToTextPlatform.instance = _BrowserSpeech();

class _BrowserSpeech extends SpeechToTextPlatform {
  web.SpeechRecognition? _rec;

  /// The current recognition was started and has not ended yet.
  bool _running = false;

  String _lastWords = '';
  double _lastConfidence = 0;
  bool _lastFinal = true;
  bool _gotResult = false;

  @override
  Future<bool> hasPermission() async => webSpeechSupported;

  @override
  Future<bool> initialize({debugLogging = false, List<SpeechConfigOption>? options}) async {
    if (!webSpeechSupported) {
      _error('error_recognizer_disabled', permanent: true);
      return false;
    }
    return true;
  }

  @override
  Future<List<dynamic>> locales() async => ['ar-SA:العربية (السعودية)', 'ar-EG:العربية (مصر)'];

  @override
  Future<bool> listen({
    String? localeId,
    partialResults = true,
    onDevice = false,
    int listenMode = 0,
    sampleRate = 0,
    SpeechListenOptions? options,
  }) async {
    if (!webSpeechSupported) return false;
    // Safari can take seconds to show / pass its microphone prompt.
    if (_running) return true;
    _detach();
    final rec = _hasStandard ? _Standard() : _Webkit();
    _rec = rec;
    rec.lang = (localeId ?? 'ar-SA').replaceAll('_', '-');
    rec.interimResults = options?.partialResults ?? partialResults as bool;
    // A computer's browser keeps listening across pauses (no words lost
    // while restarting); phones' browsers repeat results when continuous.
    rec.continuous = !_mobile;
    rec.maxAlternatives = 3;
    _lastWords = '';
    _lastFinal = true;
    _gotResult = false;

    rec.onstart = ((web.Event _) {
      if (identical(rec, _rec)) onStatus?.call('listening');
    }).toJS;
    rec.onspeechstart = ((web.Event _) {
      if (identical(rec, _rec)) onSoundLevel?.call(8);
    }).toJS;
    rec.onspeechend = ((web.Event _) {
      if (identical(rec, _rec)) onSoundLevel?.call(0);
    }).toJS;
    rec.onresult = ((web.SpeechRecognitionEvent e) {
      if (identical(rec, _rec)) _onResult(e);
    }).toJS;
    rec.onerror = ((web.SpeechRecognitionErrorEvent e) {
      if (identical(rec, _rec)) _onError(e.error);
    }).toJS;
    rec.onend = ((web.Event _) {
      if (identical(rec, _rec)) _onEnd();
    }).toJS;

    try {
      rec.start();
      _running = true;
    } catch (_) {
      _rec = null;
      return false;
    }
    onStatus?.call('listening');
    return true;
  }

  @override
  Future<void> stop() async {
    final rec = _rec;
    if (rec == null) return;
    try {
      rec.stop();
    } catch (_) {
      _onEnd();
    }
  }

  @override
  Future<void> cancel() async {
    _detach();
    onStatus?.call('notListening');
    onStatus?.call('doneNoResult');
  }

  void _detach() {
    final rec = _rec;
    _rec = null;
    _running = false;
    if (rec == null) return;
    try {
      rec.abort();
    } catch (_) {}
  }

  void _onResult(web.SpeechRecognitionEvent e) {
    final results = e.results;
    if (results.length == 0) return;
    var maxAlts = 1;
    for (var i = 0; i < results.length; i++) {
      if (results.item(i).length > maxAlts) maxAlts = results.item(i).length;
    }
    // Every result of this utterance, in order; alternative k of each.
    final alternates = <Map<String, dynamic>>[];
    for (var k = 0; k < maxAlts; k++) {
      final words = <String>[];
      var confidence = 1.0;
      for (var i = 0; i < results.length; i++) {
        final r = results.item(i);
        if (r.length == 0) continue;
        final alt = r.item(k < r.length ? k : r.length - 1);
        final t = alt.transcript.trim();
        if (t.isNotEmpty) words.add(t);
        final c = alt.confidence.toDouble();
        if (c > 0 && c < confidence) confidence = c;
      }
      final text = words.join(' ');
      if (k > 0 && alternates.any((a) => a['recognizedWords'] == text)) continue;
      alternates.add(_words(text, confidence));
    }
    final isFinal = results.item(results.length - 1).isFinal;
    _lastWords = alternates.first['recognizedWords'] as String;
    _lastConfidence = alternates.first['confidence'] as double;
    _lastFinal = isFinal;
    if (_lastWords.isNotEmpty) _gotResult = true;
    _send(alternates, isFinal);
  }

  void _onEnd() {
    _rec = null;
    _running = false;
    onSoundLevel?.call(0);
    // Like Android: the utterance closes with a final result.
    if (!_lastFinal && _lastWords.isNotEmpty) {
      _lastFinal = true;
      _send([_words(_lastWords, _lastConfidence)], true);
    }
    onStatus?.call('notListening');
    onStatus?.call(_gotResult ? 'done' : 'doneNoResult');
  }

  void _onError(String name) {
    switch (name) {
      case 'not-allowed':
        _error('error_permission', permanent: true);
      case 'service-not-allowed':
        _error('error_recognizer_disabled', permanent: false);
      case 'language-not-supported':
        _error('error_language_not_supported', permanent: false);
      case 'audio-capture':
        _error('error_audio', permanent: false);
      case 'network':
        _error('error_server', permanent: false);
      case 'no-speech':
        _error('error_speech_timeout', permanent: false);
      case 'aborted':
        // Our own restart: not an error.
        break;
      default:
        _error('error_client', permanent: false);
    }
  }

  static Map<String, dynamic> _words(String text, double confidence) =>
      {'recognizedWords': text, 'recognizedPhrases': null, 'confidence': confidence};

  void _send(List<Map<String, dynamic>> alternates, bool isFinal) {
    onTextRecognition?.call(jsonEncode({
      'alternates': alternates,
      // Both spellings: older and newer plugin versions read different keys.
      'resultType': isFinal ? 2 : 0,
      'finalResult': isFinal,
    }));
  }

  void _error(String message, {required bool permanent}) {
    onError?.call(jsonEncode({'errorMsg': message, 'permanent': permanent}));
  }
}
