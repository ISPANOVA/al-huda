import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'storage_service.dart';

/// Exports the user's own data (settings, bookmarks, khatmah, stats,
/// tasbeeh, athkar progress and daily wird) to one JSON file, and restores it.
class BackupService {
  final StorageService _storage;

  BackupService(this._storage);

  static const _boxes = [
    StorageService.settingsBox,
    StorageService.bookmarksBox,
    StorageService.khatmahBox,
    StorageService.statsBox,
    StorageService.tasbeehBox,
    StorageService.athkarBox,
  ];

  static dynamic _plain(dynamic v) {
    if (v is Map) return {for (final e in v.entries) e.key.toString(): _plain(e.value)};
    if (v is List) return v.map(_plain).toList();
    if (v == null || v is num || v is String || v is bool) return v;
    if (v is DateTime) return v.toIso8601String();
    return v.toString();
  }

  Map<String, dynamic> snapshot() => {
        'app': 'al_huda',
        'version': 1,
        'created': DateTime.now().toIso8601String(),
        'boxes': {
          for (final name in _boxes)
            name: [
              for (final k in _storage.box(name).keys)
                {'k': k is int ? k : k.toString(), 'i': k is int, 'v': _plain(_storage.box(name).get(k))},
            ],
        },
      };

  /// Writes the backup and opens the share sheet (save to Drive, Files, WhatsApp…).
  Future<void> export() async {
    final dir = await getTemporaryDirectory();
    final d = DateTime.now();
    final name = 'alhuda_backup_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.json';
    final file = File('${dir.path}/$name');
    await file.writeAsString(const JsonEncoder.withIndent(' ').convert(snapshot()), flush: true);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      text: 'نسخة احتياطية من تطبيق الهدى',
    ));
  }

  /// Lets the user pick a backup file and restores it. Returns null when
  /// cancelled, true on success; throws [FormatException] on a bad file.
  Future<bool?> pickAndRestore() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.single;
    final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
    if (bytes == null) throw const FormatException('empty');
    final data = jsonDecode(utf8.decode(bytes));
    if (data is! Map || data['app'] != 'al_huda' || data['boxes'] is! Map) {
      throw const FormatException('not an al_huda backup');
    }
    final boxes = data['boxes'] as Map;
    for (final name in _boxes) {
      final entries = boxes[name];
      if (entries is! List) continue;
      final box = _storage.box(name);
      await box.clear();
      for (final e in entries) {
        if (e is! Map) continue;
        final key = e['i'] == true ? (e['k'] as num).toInt() : e['k'].toString();
        await box.put(key, e['v']);
      }
    }
    return true;
  }
}
