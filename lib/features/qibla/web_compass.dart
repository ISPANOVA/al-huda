/// Compass heading in the browser (deviceorientation events); unused on
/// phones, where flutter_compass reads the sensor directly.
library;

export 'web_compass_stub.dart' if (dart.library.js_interop) 'web_compass_web.dart';
