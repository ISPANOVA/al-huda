import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/di/app_dependencies.dart';
import 'features/onboarding/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Services start first and never wait for the screen: when Android Auto
  // (or a headset button) starts the app there is no Activity, the calls
  // below have nobody to answer them, and the audio service must still
  // come up to answer the car.
  final deps = initializeDateFormatting('ar').then((_) => AppDependencies.init());
  _ui(() => SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]));
  _ui(() async => SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      )));
  _ui(() => SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  runApp(_Bootstrap(deps));
}

/// Screen-only calls: fire and forget, never fatal without a screen.
void _ui(Future<void> Function() call) {
  try {
    call().catchError((Object _) {});
  } catch (_) {}
}

/// Shows the animated splash while services start, then fades into the app.
class _Bootstrap extends StatefulWidget {
  final Future<AppDependencies> deps;

  const _Bootstrap(this.deps);

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  AppDependencies? _deps;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final minSplash = Future<void>.delayed(const Duration(milliseconds: 1700));
    final deps = await widget.deps;
    await minSplash;
    if (mounted) setState(() => _deps = deps);
  }

  @override
  Widget build(BuildContext context) {
    final deps = _deps;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 650),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: deps == null
          ? const Directionality(
              key: ValueKey('splash'),
              textDirection: TextDirection.rtl,
              child: ColoredBox(color: SplashScreen.background, child: SplashScreen()),
            )
          : AlHudaApp(key: const ValueKey('app'), deps: deps),
    );
  }
}
