/// Key-value storage backend.
///
/// Phones keep the original Hive, reading the very same files as every
/// earlier build. The browser build uses Hive CE, the maintained fork with
/// the same API that also runs under WebAssembly (Hive 2 does not).
library;

export 'package:hive_flutter/hive_flutter.dart' if (dart.library.js_interop) 'package:hive_ce_flutter/hive_flutter.dart';
