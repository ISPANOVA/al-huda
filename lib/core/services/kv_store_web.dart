import 'package:hive_ce/hive_ce.dart';

export 'package:hive_ce/hive_ce.dart';

/// Same call as hive_flutter's `initFlutter`; in the browser Hive CE keeps
/// its boxes in IndexedDB, so there is no directory to resolve.
extension HiveWebInit on HiveInterface {
  Future<void> initFlutter([String? subDir]) async => init(null);
}
