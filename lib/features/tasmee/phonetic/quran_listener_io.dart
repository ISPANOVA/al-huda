import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'pause_detector.dart';

/// The on-device Quran recogniser: a streaming phoneme model
/// (Quran-Lab zipformer_p-arabic-v3, run by sherpa-onnx) listening to the
/// microphone. Everything runs on the phone, without the internet.
///
/// The model and its tokens are bundled in assets/tasmee/ when the app is
/// built; they are copied to the app's files once (the runtime needs paths).
class QuranListener {
  static const _modelAsset = 'assets/tasmee/model.int8.onnx';
  static const _tokensAsset = 'assets/tasmee/tokens.txt';

  /// 16 kHz mono, sent to the model every 480 ms (its chunk).
  static const _rate = 16000;
  static const _chunkBytes = _rate * 2 * 480 ~/ 1000;

  static bool? _available;

  /// The model was bundled with this build.
  static Future<bool> available() async {
    if (_available != null) return _available!;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets();
      _available = assets.contains(_modelAsset) && assets.contains(_tokensAsset);
    } catch (_) {
      _available = false;
    }
    return _available!;
  }

  Isolate? _isolate;
  SendPort? _toModel;
  ReceivePort? _fromModel;
  Completer<bool>? _ready;

  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _mic;
  Uint8List _pending = Uint8List(0);
  bool _listening = false;

  void Function(String text, bool isFinal)? _onResult;
  void Function(double level)? _onLevel;
  void Function(String error)? _onError;

  bool get listening => _listening;

  /// Copies the model out of the app (first time only) and loads it in a
  /// background isolate. False when it can't run on this phone.
  Future<bool> prepare({void Function(double progress)? onProgress}) async {
    if (_ready != null) return _ready!.future;
    final ready = _ready = Completer<bool>();
    try {
      if (!await available()) {
        ready.complete(false);
        return false;
      }
      final model = await _extract(_modelAsset, onProgress);
      final tokens = await _extract(_tokensAsset, null);
      final port = _fromModel = ReceivePort();
      port.listen(_onMessage);
      _isolate = await Isolate.spawn(_modelMain, [port.sendPort, model, tokens]);
    } catch (e) {
      if (!ready.isCompleted) ready.complete(false);
      _onError?.call('$e');
    }
    return ready.future;
  }

  void _onMessage(dynamic m) {
    if (m is SendPort) {
      _toModel = m;
    } else if (m is List && m.isNotEmpty) {
      switch (m[0]) {
        case 'ready':
          if (!(_ready?.isCompleted ?? true)) _ready!.complete(true);
        case 'error':
          if (!(_ready?.isCompleted ?? true)) _ready!.complete(false);
          _onError?.call(m[1] as String);
        case 'result':
          _onResult?.call(m[1] as String, m[2] as bool);
      }
    }
  }

  /// Asset copied to the app's files (atomically: a broken copy from an
  /// interrupted first run is never used).
  static Future<String> _extract(String asset, void Function(double)? onProgress) async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/tasmee_${asset.split('/').last}');
    // Copied once per build of the app (an update may bring a new model).
    final mark = File('${file.path}.build');
    const build = String.fromEnvironment('APP_BUILD', defaultValue: 'dev');
    if (await file.exists() && await mark.exists() && (await mark.readAsString()) == build) {
      onProgress?.call(1);
      return file.path;
    }
    final data = await rootBundle.load(asset);
    final tmp = File('${file.path}.tmp');
    final sink = tmp.openWrite();
    const step = 4 << 20;
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    for (var o = 0; o < bytes.length; o += step) {
      sink.add(Uint8List.sublistView(bytes, o, math.min(bytes.length, o + step)));
      onProgress?.call(math.min(1, (o + step) / bytes.length));
      await Future<void>.delayed(Duration.zero);
    }
    await sink.flush();
    await sink.close();
    if (await tmp.length() != data.lengthInBytes) {
      await tmp.delete();
      throw StateError('copy of $asset incomplete');
    }
    await tmp.rename(file.path);
    await mark.writeAsString(build);
    return file.path;
  }

  /// Starts listening; false when the microphone isn't allowed or the model
  /// couldn't load.
  Future<bool> start({
    required void Function(String text, bool isFinal) onResult,
    void Function(double level)? onLevel,
    void Function(String error)? onError,
  }) async {
    _onResult = onResult;
    _onLevel = onLevel;
    _onError = onError;
    if (!await prepare()) return false;
    if (_listening) return true;
    final rec = _recorder ??= AudioRecorder();
    if (!await rec.hasPermission()) return false;
    _toModel?.send(const ['reset']);
    _pending = Uint8List(0);
    final stream = await rec.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _rate,
      numChannels: 1,
      // The model was trained on unprocessed audio: phone filters remove
      // the breathy letters (ه، ح).
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
    ));
    _listening = true;
    _mic = stream.listen(_onAudio, onError: (Object e) => _onError?.call('$e'));
    return true;
  }

  void _onAudio(Uint8List data) {
    var all = data;
    if (_pending.isNotEmpty) {
      all = Uint8List(_pending.length + data.length)
        ..setAll(0, _pending)
        ..setAll(_pending.length, data);
    }
    var o = 0;
    while (all.length - o >= _chunkBytes) {
      final bytes = Uint8List.fromList(Uint8List.sublistView(all, o, o + _chunkBytes));
      o += _chunkBytes;
      final pcm = Int16List.view(bytes.buffer);
      final samples = Float32List(pcm.length);
      var sum = 0.0;
      for (var i = 0; i < pcm.length; i++) {
        final v = pcm[i] / 32768.0;
        samples[i] = v;
        sum += v * v;
      }
      final rms = math.sqrt(sum / pcm.length);
      _onLevel?.call((rms * 8).clamp(0.0, 1.0));
      _toModel?.send(TransferableTypedData.fromList([samples]));
    }
    _pending = o < all.length ? Uint8List.fromList(Uint8List.sublistView(all, o)) : Uint8List(0);
  }

  /// Stops the microphone; what was said last is judged as a pause.
  Future<void> stop() async {
    if (!_listening) return;
    _listening = false;
    await _mic?.cancel();
    _mic = null;
    try {
      await _recorder?.stop();
    } catch (_) {}
    _toModel?.send(const ['flush']);
  }

  void dispose() {
    _listening = false;
    _mic?.cancel();
    _recorder?.dispose();
    _recorder = null;
    _toModel?.send(const ['quit']);
    final iso = _isolate;
    Future<void>.delayed(const Duration(milliseconds: 300), () => iso?.kill(priority: Isolate.immediate));
    _isolate = null;
    _fromModel?.close();
    _fromModel = null;
  }

  // ------------------------------------------------- the model isolate ---

  /// A new stream primed with the model's first chunk of silence, so the
  /// first sound said after a pause isn't lost.
  static sherpa.OnlineStream _primed(sherpa.OnlineRecognizer r) {
    final s = r.createStream();
    s.acceptWaveform(samples: Float32List(_rate * 480 ~/ 1000), sampleRate: _rate);
    while (r.isReady(s)) {
      r.decode(s);
    }
    return s;
  }

  static void _modelMain(List<dynamic> args) {
    final out = args[0] as SendPort;
    final port = ReceivePort();
    out.send(port.sendPort);
    sherpa.OnlineRecognizer? recognizer;
    sherpa.OnlineStream? stream;
    try {
      sherpa.initBindings();
      recognizer = sherpa.OnlineRecognizer(sherpa.OnlineRecognizerConfig(
        feat: sherpa.FeatureConfig(sampleRate: _rate, featureDim: 80),
        model: sherpa.OnlineModelConfig(
          zipformer2Ctc: sherpa.OnlineZipformer2CtcModelConfig(model: args[1] as String),
          tokens: args[2] as String,
          numThreads: 2,
          modelType: 'zipformer2_ctc',
          provider: 'cpu',
          debug: false,
        ),
        // Pauses are told from the sound (PauseDetector): the model is
        // silent through a long madd, its own endpoints would cut words.
        enableEndpoint: false,
      ));
      stream = _primed(recognizer);
      out.send(const ['ready']);
    } catch (e) {
      out.send(['error', '$e']);
      return;
    }
    var last = '';
    final pauses = PauseDetector();
    void emit({required bool end}) {
      final r = recognizer!;
      var s = stream!;
      if (end) {
        // The last frames are decoded only when the stream is finished:
        // finish it and go on with a new one.
        s.inputFinished();
      }
      while (r.isReady(s)) {
        r.decode(s);
      }
      final text = r.getResult(s).text;
      if (end) {
        if (text.isNotEmpty) out.send(['result', text, true]);
        s.free();
        s = stream = _primed(r);
        last = '';
      } else if (text != last) {
        last = text;
        out.send(['result', text, false]);
      }
    }

    port.listen((dynamic m) {
      final r = recognizer;
      final s = stream;
      if (r == null || s == null) return;
      if (m is TransferableTypedData) {
        final samples = m.materialize().asFloat32List();
        s.acceptWaveform(samples: samples, sampleRate: _rate);
        emit(end: pauses.feed(samples));
      } else if (m is List && m.isNotEmpty) {
        switch (m[0]) {
          case 'reset':
            s.free();
            stream = _primed(r);
            pauses.reset();
            last = '';
          case 'flush':
            // Half a second of silence lets the model finish the last word.
            s.acceptWaveform(samples: Float32List(_rate ~/ 2), sampleRate: _rate);
            emit(end: true);
          case 'quit':
            s.free();
            r.free();
            stream = null;
            recognizer = null;
            port.close();
        }
      }
    });
  }
}
