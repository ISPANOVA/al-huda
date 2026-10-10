import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'pause_detector.dart';

/// The on-device Quran recogniser: a streaming phoneme model
/// (Quran-Lab zipformer_p-arabic-v3.1, run by sherpa-onnx) listening to the
/// microphone. Everything runs on the phone, without the internet.
///
/// The model (about 70 MB) isn't in the app, to keep it small: it is
/// downloaded once, the first time the Tasmee is used, and checked
/// (SHA-256) before it is used.
class QuranListener {
  static const _base = 'https://github.com/ISPANOVA/al-huda/releases/download/tasmee-model-v3.1';
  static const _files = {
    'model.int8.onnx': (size: 72705392, sha: '31755836528da336a6192121cd7bc82cb41752dddb65566fd000b89c8686da6b'),
    'tokens.txt': (size: 2346, sha: '252c10687e442aa9291973065fae19fa39bcd681c4f5612ec496a647e20b43a1'),
  };

  /// Size of the download, for the question shown before it.
  static const downloadMb = 70;

  /// 16 kHz mono, sent to the model every 480 ms (its chunk).
  static const _rate = 16000;
  static const _chunkBytes = _rate * 2 * 480 ~/ 1000;

  /// The on-device Tasmee runs on this platform.
  static Future<bool> available() async => true;

  static Future<File> _file(String name) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/tasmee_v31_$name');
  }

  /// The model was downloaded (and checked) already.
  static Future<bool> modelReady() async {
    for (final e in _files.entries) {
      final f = await _file(e.key);
      final ok = File('${f.path}.ok');
      if (!await f.exists() || !await ok.exists() || await f.length() != e.value.size) return false;
    }
    return true;
  }

  /// Downloads the model (resuming an interrupted download); false without
  /// the internet or when the file isn't right.
  static Future<bool> download({void Function(double progress)? onProgress}) async {
    try {
      // Files of the test build that had the model inside (no longer used).
      final dir = await getApplicationSupportDirectory();
      for (final old in ['tasmee_model.int8.onnx', 'tasmee_tokens.txt']) {
        for (final f in [File('${dir.path}/$old'), File('${dir.path}/$old.build')]) {
          if (await f.exists()) await f.delete();
        }
      }
      final total = _files.values.fold<int>(0, (a, b) => a + b.size);
      var done = 0;
      for (final e in _files.entries) {
        final f = await _file(e.key);
        final ok = File('${f.path}.ok');
        if (await f.exists() && await ok.exists() && await f.length() == e.value.size) {
          done += e.value.size;
          continue;
        }
        final part = File('${f.path}.part');
        var have = await part.exists() ? await part.length() : 0;
        if (have > e.value.size) {
          await part.delete();
          have = 0;
        }
        if (have < e.value.size) {
          final dio = Dio();
          await dio.download(
            '$_base/${e.key}',
            part.path,
            deleteOnError: false,
            fileAccessMode: have > 0 ? FileAccessMode.append : FileAccessMode.write,
            options: Options(headers: have > 0 ? {'Range': 'bytes=$have-'} : null),
            onReceiveProgress: (r, _) => onProgress?.call(((done + have + r) / total).clamp(0.0, 1.0)),
          );
        }
        final path = part.path;
        final sha = await Isolate.run(() => sha256.convert(File(path).readAsBytesSync()).toString());
        if (sha != e.value.sha) {
          await part.delete();
          return false;
        }
        await part.rename(f.path);
        await ok.writeAsString(sha);
        done += e.value.size;
        onProgress?.call(done / total);
      }
      return true;
    } catch (_) {
      return false;
    }
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

  /// Loads the (downloaded) model in a background isolate. False when it
  /// isn't downloaded or can't run on this phone.
  Future<bool> prepare({void Function(double progress)? onProgress}) async {
    if (_ready != null) return _ready!.future;
    if (!await modelReady()) return false;
    final ready = _ready = Completer<bool>();
    try {
      final model = (await _file('model.int8.onnx')).path;
      final tokens = (await _file('tokens.txt')).path;
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
    // One stream for the whole listening: a new stream would lose the first
    // sound said after a pause (the model needs what came before). A pause
    // only marks where the next utterance's text begins.
    var base = 0;
    final pauses = PauseDetector();
    void emit({required bool end, bool finish = false}) {
      final r = recognizer!;
      final s = stream!;
      if (finish) s.inputFinished();
      while (r.isReady(s)) {
        r.decode(s);
      }
      final full = r.getResult(s).text;
      final text = full.length >= base ? full.substring(base) : full;
      if (end) {
        if (text.isNotEmpty) out.send(['result', text, true]);
        base = full.length;
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
            base = 0;
            last = '';
          case 'flush':
            // Half a second of silence lets the model finish the last word.
            s.acceptWaveform(samples: Float32List(_rate ~/ 2), sampleRate: _rate);
            emit(end: true, finish: true);
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
