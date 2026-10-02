import 'package:hive_flutter/hive_flutter.dart';

/// Thin wrapper around Hive. All boxes store plain JSON-like values
/// (maps, lists, primitives) so no code generation / adapters are needed.
class StorageService {
  static const String settingsBox = 'settings';
  static const String quranBox = 'quran_cache';
  static const String bookmarksBox = 'bookmarks';
  static const String khatmahBox = 'khatmah';
  static const String statsBox = 'stats';
  static const String tasbeehBox = 'tasbeeh';
  static const String athkarBox = 'athkar';
  static const String downloadsBox = 'downloads';

  static const List<String> _boxes = [
    settingsBox,
    quranBox,
    bookmarksBox,
    khatmahBox,
    statsBox,
    tasbeehBox,
    athkarBox,
    downloadsBox,
  ];

  Future<void> init() async {
    await Hive.initFlutter('al_huda');
    for (final name in _boxes) {
      await Hive.openBox<dynamic>(name);
    }
  }

  Box<dynamic> box(String name) => Hive.box<dynamic>(name);

  Box<dynamic> get settings => box(settingsBox);
  Box<dynamic> get quran => box(quranBox);
  Box<dynamic> get bookmarks => box(bookmarksBox);
  Box<dynamic> get khatmah => box(khatmahBox);
  Box<dynamic> get stats => box(statsBox);
  Box<dynamic> get tasbeeh => box(tasbeehBox);
  Box<dynamic> get athkar => box(athkarBox);
  Box<dynamic> get downloads => box(downloadsBox);

  /// Hive returns `Map<dynamic, dynamic>`; convert deeply to `Map<String, dynamic>`.
  static Map<String, dynamic> asMap(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _deep(v)));
    }
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> asMapList(dynamic value) {
    if (value is List) return value.map(asMap).toList();
    return <Map<String, dynamic>>[];
  }

  static dynamic _deep(dynamic v) {
    if (v is Map) return asMap(v);
    if (v is List) return v.map(_deep).toList();
    return v;
  }
}
