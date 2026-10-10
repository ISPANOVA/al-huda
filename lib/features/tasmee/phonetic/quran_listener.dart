/// The on-device Quran recogniser (Android); the web build has none and
/// keeps the browser's speech recognition.
export 'quran_listener_stub.dart' if (dart.library.ffi) 'quran_listener_io.dart';
