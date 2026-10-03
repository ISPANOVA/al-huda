import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';

import '../../features/audio/data/audio_download_service.dart';
import '../../features/audio/data/car_media.dart';
import '../../features/audio/data/playlist_builder.dart';
import '../../features/audio/data/quran_audio_handler.dart';
import '../../features/khatmah/data/khatmah_repository.dart';
import '../../features/prayer/data/location_service.dart';
import '../../features/prayer/data/prayer_repository.dart';
import '../../features/quran/data/datasources/bundled_quran_data_source.dart';
import '../../features/quran/data/repositories/bookmarks_repository.dart';
import '../../features/quran/data/repositories/quran_repository_impl.dart';
import '../../features/quran/domain/repositories/quran_repository.dart';
import '../../features/stats/data/stats_repository.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

/// Composition root: builds every service once at startup.
class AppDependencies {
  final StorageService storage;
  final NotificationService notifications;
  final Dio dio;
  final QuranRepository quranRepository;
  final BookmarksRepository bookmarksRepository;
  final StatsRepository statsRepository;
  final KhatmahRepository khatmahRepository;
  final AudioDownloadService downloadService;
  final PlaylistBuilder playlistBuilder;
  final QuranAudioHandler audioHandler;
  final LocationService locationService;
  final PrayerRepository prayerRepository;

  AppDependencies._({
    required this.storage,
    required this.notifications,
    required this.dio,
    required this.quranRepository,
    required this.bookmarksRepository,
    required this.statsRepository,
    required this.khatmahRepository,
    required this.downloadService,
    required this.playlistBuilder,
    required this.audioHandler,
    required this.locationService,
    required this.prayerRepository,
  });

  static Future<AppDependencies> init() async {
    debugPrint('ALHUDA init: storage');
    final storage = StorageService();
    await storage.init();

    debugPrint('ALHUDA init: notifications');
    final notifications = NotificationService();
    try {
      await notifications.init();
    } catch (e) {
      debugPrint('ALHUDA notifications init failed: $e');
    }

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 2),
      responseType: ResponseType.json,
      headers: {'User-Agent': 'AlHuda/1.0 (com.alhuda.islamic.app)'},
    ));

    debugPrint('ALHUDA init: downloads');
    final downloads = AudioDownloadService(dio, storage);
    await downloads.init();

    debugPrint('ALHUDA init: audio service');
    final handler = await AudioService.init<QuranAudioHandler>(
      builder: QuranAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.alhuda.islamic.app.audio',
        androidNotificationChannelName: 'تلاوة القرآن الكريم',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidNotificationIcon: 'drawable/ic_stat_alhuda',
        // Android Auto: list style, voice search.
        androidBrowsableRootExtras: {
          'android.media.browse.SEARCH_SUPPORTED': true,
          'android.media.browse.CONTENT_STYLE_SUPPORTED': true,
          'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1,
          'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 1,
        },
      ),
    );
    final playlistBuilder = PlaylistBuilder(downloads);
    handler.car = CarMedia(handler, playlistBuilder, storage);
    debugPrint('ALHUDA init: audio ready');

    // The Mushaf ships inside the app: start parsing it in the background now so
    // the Quran opens instantly. Old downloaded text cache is no longer needed.
    final quranRepository = QuranRepositoryImpl(BundledQuranDataSource());
    quranRepository.ensureLoaded();
    if (storage.quran.isNotEmpty) await storage.quran.clear();

    return AppDependencies._(
      storage: storage,
      notifications: notifications,
      dio: dio,
      quranRepository: quranRepository,
      bookmarksRepository: BookmarksRepository(storage),
      statsRepository: StatsRepository(storage),
      khatmahRepository: KhatmahRepository(storage),
      downloadService: downloads,
      playlistBuilder: playlistBuilder,
      audioHandler: handler,
      locationService: LocationService(storage),
      prayerRepository: PrayerRepository(),
    );
  }
}
