import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/di/app_dependencies.dart';
import 'features/onboarding/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Services start here, not from the first frame: when Android Auto (or a
  // headset button) starts the app without a screen there is no frame, and
  // the audio service must still come up to answer the car.
  final deps = initializeDateFormatting('ar').then((_) => AppDependencies.init());
  runApp(_Bootstrap(deps));
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
