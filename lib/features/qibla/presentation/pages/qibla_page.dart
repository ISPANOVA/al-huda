import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../../core/theme/app_themes.dart';
import '../../../../core/theme/tones.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/noor_ui.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../prayer/data/prayer_repository.dart';
import '../../web_compass.dart';
import '../../../prayer/presentation/cubit/prayer_cubit.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';

/// Sensor-driven Qibla compass with a 3D tilt effect.
class QiblaPage extends StatefulWidget {
  const QiblaPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const QiblaPage());

  @override
  State<QiblaPage> createState() => _QiblaPageState();
}

class _QiblaPageState extends State<QiblaPage> {
  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  double? _heading; // smoothed, degrees from north
  double _accuracy = 0;
  bool _noSensor = false;
  double _tiltX = 0, _tiltY = 0; // radians, smoothed
  bool _wasAligned = false;

  // Browser build: deviceorientation events (Safari asks first, on a tap).
  StreamSubscription<double>? _webSub;
  bool _webNeedsTap = false;
  Timer? _webProbe;

  void _startWebCompass() {
    _webSub?.cancel();
    _webSub = webCompassHeadings().listen((raw) {
      _webProbe?.cancel();
      if (!mounted) return;
      setState(() {
        _noSensor = false;
        _heading = _heading == null ? raw : _smoothAngle(_heading!, raw, 0.18);
      });
    });
    // No reading at all (a computer): say so instead of a frozen dial.
    _webProbe?.cancel();
    _webProbe = Timer(const Duration(seconds: 3), () {
      if (mounted && _heading == null) setState(() => _noSensor = true);
    });
  }

  Future<void> _enableWebCompass() async {
    final ok = await requestWebCompassPermission();
    if (!mounted) return;
    setState(() => _webNeedsTap = !ok);
    if (ok) _startWebCompass();
  }

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _webNeedsTap = webCompassNeedsPermission;
      if (!_webNeedsTap) _startWebCompass();
      return;
    }
    _initNativeCompass();
  }

  void _initNativeCompass() {
    final events = FlutterCompass.events;
    if (events == null) {
      _noSensor = true;
    } else {
      _compassSub = events.listen((e) {
        final h = e.heading;
        if (h == null) {
          if (mounted) setState(() => _noSensor = true);
          return;
        }
        final raw = (h + 360) % 360;
        setState(() {
          _heading = _heading == null ? raw : _smoothAngle(_heading!, raw, 0.18);
          _accuracy = e.accuracy ?? 0;
        });
      });
    }
    _accelSub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen((e) {
      // Map gravity vector to a gentle tilt (max ~20°).
      final tx = (e.y / 9.81).clamp(-1.0, 1.0) * 0.35;
      final ty = (-e.x / 9.81).clamp(-1.0, 1.0) * 0.35;
      if (!mounted) return;
      setState(() {
        _tiltX = _tiltX + (tx - _tiltX) * 0.15;
        _tiltY = _tiltY + (ty - _tiltY) * 0.15;
      });
    }, onError: (_) {});
  }

  /// Exponential smoothing that respects the 0/360 wrap-around.
  double _smoothAngle(double current, double target, double factor) {
    final diff = (target - current + 540) % 360 - 180;
    return (current + diff * factor + 360) % 360;
  }

  @override
  void dispose() {
    _webSub?.cancel();
    _webProbe?.cancel();
    _compassSub?.cancel();
    _accelSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final location = context.select((PrayerCubit c) => c.state.location);
    final haptics = context.select((SettingsCubit c) => c.state.hapticFeedback);

    Widget body;
    if (location == null) {
      body = MessageView(
        icon: Icons.location_off_rounded,
        title: 'نحتاج موقعك لتحديد القبلة',
        actionLabel: 'تحديد الموقع',
        onAction: () => context.read<PrayerCubit>().refreshLocation(),
      );
    } else {
      final qibla = PrayerRepository.qiblaDirection(location.latitude, location.longitude);
      final distance = PrayerRepository.distanceToKaaba(location.latitude, location.longitude);
      final heading = _heading ?? 0;
      final relative = (qibla - heading + 360) % 360;
      final offset = relative > 180 ? relative - 360 : relative;
      final aligned = _heading != null && offset.abs() <= 3;
      if (aligned && !_wasAligned && haptics) HapticFeedback.heavyImpact();
      _wasAligned = aligned;

      final dark = Theme.of(context).brightness == Brightness.dark;
      final statusTone = aligned ? Tone.emerald : Tone.amber;
      final surface = noorSurface(context);
      final onStatus = aligned ? Colors.white : glass.onGlass;
      final onStatusMuted = aligned ? Colors.white.withValues(alpha: 0.8) : glass.onGlassMuted;

      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              _Info(
                icon: Icons.explore_rounded,
                tone: Tone.amber,
                label: 'اتجاه القبلة',
                value: '${ArabicUtils.toArabicDigits(qibla.toStringAsFixed(1))}°',
              ),
              const SizedBox(width: 10),
              _Info(
                icon: Icons.navigation_rounded,
                tone: Tone.sapphire,
                label: 'اتجاه الجهاز',
                value: '${ArabicUtils.toArabicDigits(heading.toStringAsFixed(0))}°',
              ),
              const SizedBox(width: 10),
              _Info(
                icon: Icons.place_rounded,
                tone: Tone.emerald,
                label: 'المسافة إلى الكعبة',
                value: '${ArabicUtils.toArabicDigits(distance.round())} كم',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateX(_tiltX)
                ..rotateY(_tiltY),
              child: SizedBox(
                width: 300,
                height: 300,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (aligned ? glass.accent : Colors.black).withValues(alpha: aligned ? 0.7 : 0.25),
                            blurRadius: aligned ? 60 : 30,
                            spreadRadius: aligned ? 6 : 0,
                          ),
                        ],
                      ),
                    ),
                    // The face of the compass: dark disc, a fine amber ring
                    // (gold when facing the Qibla) and a quiet star inside.
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color.alphaBlend(statusTone.mid.withValues(alpha: dark ? 0.16 : 0.12), surface),
                            Color.alphaBlend(statusTone.mid.withValues(alpha: 0.03), surface),
                          ],
                        ),
                        border: Border.all(
                          color: aligned ? glass.accent : Tone.amber.mid.withValues(alpha: dark ? 0.45 : 0.5),
                          width: aligned ? 2.5 : 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(70),
                        child: CustomPaint(
                          painter: KhatamPainter(Tone.amber.mid.withValues(alpha: dark ? 0.16 : 0.2)),
                        ),
                      ),
                    ),
                    // Dial rotates so that "N" always points to true north.
                    Transform.rotate(
                      angle: -heading * math.pi / 180,
                      child: CustomPaint(
                        size: const Size(280, 280),
                        painter: _DialPainter(color: glass.onGlass, accent: glass.accent, qibla: qibla),
                      ),
                    ),
                    // Needle pointing to the Qibla relative to the phone.
                    Transform.rotate(
                      angle: relative * math.pi / 180,
                      child: _Needle(color: aligned ? glass.accent : Theme.of(context).colorScheme.primary),
                    ),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: glass.accent, border: Border.all(color: Colors.white, width: 3)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          ToneCard(
            tone: statusTone,
            solid: aligned,
            ornament: true,
            radius: 24,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              children: [
                if (aligned)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
                  )
                else
                  ToneIcon(
                    _webNeedsTap || _noSensor ? Icons.explore_off_rounded : Icons.explore_rounded,
                    tone: Tone.amber,
                    size: 48,
                  ),
                const SizedBox(height: 10),
                Text(
                  _webNeedsTap
                      ? 'اضغط «تفعيل البوصلة» ليتحرك المؤشر مع اتجاه هاتفك'
                      : _noSensor
                      ? 'جهازك لا يحتوي على مستشعر بوصلة. استخدم الزاوية أعلاه مع بوصلة خارجية.'
                      : aligned
                          ? '🕋 أنت متجه نحو القبلة'
                          : offset > 0
                              ? 'استدر يمينًا ${ArabicUtils.toArabicDigits(offset.abs().round())}°'
                              : 'استدر يسارًا ${ArabicUtils.toArabicDigits(offset.abs().round())}°',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: _webNeedsTap || _noSensor ? 17 : 22,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                    color: onStatus,
                  ),
                ),
                if (!_noSensor && _accuracy > 30) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: aligned ? Colors.white.withValues(alpha: 0.14) : Tone.coral.mid.withValues(alpha: 0.12),
                      border: Border.all(
                          color: aligned ? Colors.white.withValues(alpha: 0.2) : Tone.coral.mid.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 18, color: aligned ? Colors.white : Tone.coral.ink(dark)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('دقة البوصلة منخفضة: حرّك الهاتف على شكل رقم 8 للمعايرة، وابتعد عن المعادن.',
                              style: TextStyle(fontSize: 12.5, height: 1.5, color: onStatus)),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_webNeedsTap) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _enableWebCompass,
                    icon: const Icon(Icons.explore_rounded),
                    label: const Text('تفعيل البوصلة'),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.screen_rotation_alt_rounded, size: 16, color: onStatusMuted),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text('ضع الهاتف أفقيًا للحصول على أدق نتيجة',
                          textAlign: TextAlign.center, style: TextStyle(color: onStatusMuted, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    return GlassScaffold(
      title: 'اتجاه القبلة',
      subtitle: location?.city ?? 'نحو الكعبة المشرفة',
      icon: Icons.explore_rounded,
      tone: Tone.amber,
      body: body,
    );
  }
}

/// A small stat card: coloured icon, big number and its label.
class _Info extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final String label;
  final String value;

  const _Info({required this.icon, required this.tone, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: ToneCard(
        tone: tone,
        radius: 20,
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Column(
          children: [
            ToneIcon(icon, tone: tone, size: 34),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  maxLines: 1,
                  style: TextStyle(
                      fontFamily: AppFonts.display, fontSize: 20, fontWeight: FontWeight.w700, color: tone.ink(dark))),
            ),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: glass.onGlassMuted)),
          ],
        ),
      ),
    );
  }
}

class _Needle extends StatelessWidget {
  final Color color;

  const _Needle({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 250,
      child: Column(
        children: [
          const Text('🕋', style: TextStyle(fontSize: 28)),
          Expanded(
            child: CustomPaint(size: const Size(24, 100), painter: _NeedlePainter(color)),
          ),
          const SizedBox(height: 110),
        ],
      ),
    );
  }
}

class _NeedlePainter extends CustomPainter {
  final Color color;

  _NeedlePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height * 0.82)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawShadow(path, Colors.black, 4, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(colors: [color, color.withValues(alpha: 0.6)], begin: Alignment.topCenter, end: Alignment.bottomCenter)
            .createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _NeedlePainter old) => old.color != color;
}

class _DialPainter extends CustomPainter {
  final Color color;
  final Color accent;
  final double qibla;

  _DialPainter({required this.color, required this.accent, required this.qibla});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final tick = Paint()..color = color.withValues(alpha: 0.5);

    for (var deg = 0; deg < 360; deg += 5) {
      final major = deg % 30 == 0;
      final a = deg * math.pi / 180 - math.pi / 2;
      final outer = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      final inner = Offset(c.dx + (r - (major ? 16 : 8)) * math.cos(a), c.dy + (r - (major ? 16 : 8)) * math.sin(a));
      canvas.drawLine(inner, outer, tick..strokeWidth = major ? 2.4 : 1);
    }

    const labels = {0: 'ش', 90: 'ق', 180: 'ج', 270: 'غ'};
    labels.forEach((deg, text) {
      final a = deg * math.pi / 180 - math.pi / 2;
      final pos = Offset(c.dx + (r - 34) * math.cos(a), c.dy + (r - 34) * math.sin(a));
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(color: deg == 0 ? Colors.redAccent : color, fontSize: 20, fontWeight: FontWeight.w900),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    });

    // Qibla marker on the rim.
    final qa = qibla * math.pi / 180 - math.pi / 2;
    canvas.drawCircle(
      Offset(c.dx + (r - 6) * math.cos(qa), c.dy + (r - 6) * math.sin(qa)),
      7,
      Paint()..color = accent,
    );
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) => old.qibla != qibla || old.color != color;
}
