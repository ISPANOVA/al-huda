/// Browser speech recognition for the Tasmee on the web build; a no-op on
/// phones, where the speech_to_text plugin talks to the system recognizer.
library;

export 'web_speech_stub.dart' if (dart.library.js_interop) 'web_speech_web.dart';
