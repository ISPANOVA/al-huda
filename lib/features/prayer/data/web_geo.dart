/// Location straight from the browser (web build only).
library;

export 'web_geo_stub.dart' if (dart.library.js_interop) 'web_geo_web.dart';
