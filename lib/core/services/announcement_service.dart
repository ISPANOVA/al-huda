import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../platform/web_env.dart';
import 'storage_service.dart';

/// A message the owner shows to everyone opening the app, written in
/// announce.json on the app's config site (edited from its admin page).
class Announcement {
  /// Changes whenever the message is edited: a message shown «once» comes
  /// back after an edit.
  final String id;
  final String title;
  final String message;

  /// Can't be closed: the app can't be used until the button is followed
  /// (a required update).
  final bool force;

  /// Shown on every start until edited (false: once per edit).
  final bool always;
  final String buttonText;
  final String buttonUrl;

  const Announcement({
    required this.id,
    required this.title,
    required this.message,
    required this.force,
    required this.always,
    required this.buttonText,
    required this.buttonUrl,
  });

  /// The message for this copy of the app, or null when it is off or meant
  /// for others (another platform, newer builds).
  static Announcement? forThisApp(Map<String, dynamic> j) {
    if (j['enabled'] != true) return null;
    final platforms = (j['platforms'] as List?)?.map((e) => e.toString()).toList() ?? const ['android', 'web'];
    if (!platforms.contains(AnnouncementService.platform)) return null;
    // «Builds older than N»: an update message stops once build N is in.
    final below = (j['belowBuild'] as num?)?.toInt() ?? 0;
    final build = AnnouncementService.appBuild;
    if (!kIsWeb && below > 0 && build > 0 && build >= below) return null;
    final title = (j['title'] ?? '').toString().trim();
    final message = (j['message'] ?? '').toString().trim();
    if (title.isEmpty && message.isEmpty) return null;
    return Announcement(
      id: (j['id'] ?? '$title|$message').toString(),
      title: title,
      message: message,
      force: j['mode'] == 'force',
      always: j['show'] != 'once',
      buttonText: (j['buttonText'] ?? '').toString().trim(),
      buttonUrl: (j['buttonUrl'] ?? '').toString().trim(),
    );
  }
}

class AnnouncementService {
  final Dio _dio;
  final StorageService _storage;

  AnnouncementService(this._dio, this._storage);

  static const url = 'https://al-huda-config.pages.dev/announce.json';

  /// Build number of this APK (set by the release build; 0 when unknown).
  static const appBuild = int.fromEnvironment('APP_BUILD');

  static String get platform => kIsWeb ? 'web' : 'android';

  static const _cacheKey = 'announcement_json';
  static const _seenKey = 'announcement_seen';
  static const _channel = MethodChannel('alhuda/app');

  /// The last message fetched (so a required update still holds offline).
  Announcement? cached() => _parse(_storage.settings.get(_cacheKey) as String?);

  /// The current message from the config site (null when there is none or
  /// it can't be reached; the cached one is kept for the latter).
  Future<Announcement?> fetch() async {
    try {
      final r = await _dio.get<String>(
        url,
        queryParameters: {'t': DateTime.now().millisecondsSinceEpoch},
        options: Options(
          responseType: ResponseType.plain,
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final body = r.data ?? '';
      jsonDecode(body); // only valid JSON replaces the cache
      await _storage.settings.put(_cacheKey, body);
      return _parse(body);
    } catch (_) {
      return cached();
    }
  }

  Announcement? _parse(String? body) {
    if (body == null || body.isEmpty) return null;
    try {
      final j = jsonDecode(body);
      return j is Map ? Announcement.forThisApp(StorageService.asMap(j)) : null;
    } catch (_) {
      return null;
    }
  }

  /// Whether [a] should be shown now.
  bool shouldShow(Announcement a) => a.force || a.always || _storage.settings.get(_seenKey) != a.id;

  Future<void> markSeen(Announcement a) => _storage.settings.put(_seenKey, a.id);

  /// Opens a link (the store, a download, a page) outside the app.
  static Future<bool> open(String link) async {
    if (link.isEmpty) return false;
    if (kIsWeb) return openInBrowser(link);
    try {
      return await _channel.invokeMethod<bool>('openUrl', {'url': link}) ?? false;
    } catch (_) {
      return false;
    }
  }
}
