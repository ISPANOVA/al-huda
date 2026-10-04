/// Browser facts for the web build; on phones every value is false / no-op.
library;

export 'web_env_stub.dart' if (dart.library.js_interop) 'web_env_web.dart';
