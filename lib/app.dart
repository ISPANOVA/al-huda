import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/constants/app_constants.dart';
import 'core/di/app_dependencies.dart';
import 'core/services/notification_service.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_themes.dart';
import 'core/theme/theme_transition.dart';
import 'features/athkar/presentation/cubit/athkar_cubit.dart';
import 'features/audio/data/audio_download_service.dart';
import 'features/audio/presentation/cubit/audio_cubit.dart';
import 'features/home/presentation/home_shell.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/wird/wird_tracker.dart';
import 'features/khatmah/presentation/cubit/khatmah_cubit.dart';
import 'features/prayer/presentation/cubit/prayer_cubit.dart';
import 'features/quran/domain/repositories/quran_repository.dart';
import 'features/quran/presentation/cubit/bookmarks_cubit.dart';
import 'features/quran/presentation/cubit/quran_nav_cubit.dart';
import 'features/settings/presentation/cubit/settings_cubit.dart';
import 'features/settings/presentation/cubit/settings_state.dart';
import 'features/stats/data/stats_repository.dart';
import 'features/stats/presentation/stats_page.dart';
import 'features/tasbeeh/presentation/cubit/tasbeeh_cubit.dart';

class AlHudaApp extends StatefulWidget {
  final AppDependencies deps;

  const AlHudaApp({super.key, required this.deps});

  @override
  State<AlHudaApp> createState() => _AlHudaAppState();
}

class _AlHudaAppState extends State<AlHudaApp> {
  late bool _onboarded = widget.deps.storage.settings.get(OnboardingPage.doneKey) == true;

  @override
  Widget build(BuildContext context) {
    final deps = widget.deps;
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<QuranRepository>.value(value: deps.quranRepository),
        RepositoryProvider<StatsRepository>.value(value: deps.statsRepository),
        RepositoryProvider<AudioDownloadService>.value(value: deps.downloadService),
        RepositoryProvider<StorageService>.value(value: deps.storage),
        RepositoryProvider<NotificationService>.value(value: deps.notifications),
        RepositoryProvider<WirdTracker>(create: (_) => WirdTracker(deps.storage)),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => SettingsCubit(deps.storage, deps.notifications)),
          BlocProvider(
            create: (ctx) => AudioCubit(
              deps.audioHandler,
              deps.playlistBuilder,
              deps.statsRepository,
              ctx.read<SettingsCubit>(),
            ),
          ),
          BlocProvider(create: (_) => BookmarksCubit(deps.bookmarksRepository)),
          BlocProvider(create: (_) => KhatmahCubit(deps.khatmahRepository, deps.notifications)),
          BlocProvider(
            lazy: false,
            create: (ctx) => PrayerCubit(
              deps.locationService,
              deps.prayerRepository,
              deps.notifications,
              ctx.read<SettingsCubit>(),
              autoLocate: _onboarded,
            ),
          ),
          BlocProvider(create: (_) => QuranNavCubit()),
          BlocProvider(create: (_) => AthkarCubit(deps.storage, deps.statsRepository)),
          BlocProvider(create: (_) => TasbeehCubit(deps.storage, deps.statsRepository)),
          BlocProvider(create: (_) => StatsCubit(deps.statsRepository)),
        ],
        child: BlocBuilder<SettingsCubit, SettingsState>(
          buildWhen: (p, c) =>
              p.themeType != c.themeType ||
              p.themeMode != c.themeMode ||
              p.customPrimary != c.customPrimary ||
              p.customAccent != c.customAccent ||
              p.customBackground != c.customBackground,
          builder: (context, settings) {
            return MaterialApp(
              title: AppConstants.appName,
              debugShowCheckedModeBanner: false,
              theme: AppThemes.build(settings.themeType, Brightness.light),
              darkTheme: AppThemes.build(settings.themeType, Brightness.dark),
              themeMode: settings.themeMode,
              themeAnimationDuration: Duration.zero,
              locale: const Locale('ar'),
              supportedLocales: const [Locale('ar'), Locale('en')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => Directionality(
                textDirection: TextDirection.rtl,
                child: ThemeTransition(child: child!),
              ),
              home: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                switchInCurve: Curves.easeOutCubic,
                child: _onboarded
                    ? const HomeShell(key: ValueKey('home'))
                    : OnboardingPage(
                        key: const ValueKey('onboarding'),
                        onDone: () => setState(() => _onboarded = true),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}
