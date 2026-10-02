import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_themes.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../domain/prayer_entities.dart';
import '../cubit/prayer_cubit.dart';

/// Glass card with a live countdown ring to the next prayer.
class NextPrayerCard extends StatelessWidget {
  final VoidCallback? onTap;

  const NextPrayerCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return BlocBuilder<PrayerCubit, PrayerState>(
      builder: (context, state) {
        if (!state.ready) {
          return GlassContainer(
            onTap: onTap,
            child: Row(
              children: [
                Icon(Icons.location_searching_rounded, color: glass.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.error ?? (state.loading ? 'جارٍ تحديد موقعك لحساب المواقيت...' : 'اضغط لتحديد الموقع'),
                  ),
                ),
                if (state.loading)
                  SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: glass.accent)),
              ],
            ),
          );
        }
        final next = state.next!;
        final previousTime = _previousTime(state, next);
        final span = next.time.difference(previousTime).inSeconds;
        final progress = span <= 0 ? 0.0 : 1 - (state.countdown.inSeconds / span);
        return GlassContainer(
          onTap: onTap,
          borderRadius: 30,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              SizedBox(
                width: 108,
                height: 108,
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: progress.clamp(0.0, 1.0),
                    color: glass.accent,
                    track: glass.onGlass.withValues(alpha: 0.12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ArabicUtils.formatDuration(state.countdown),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: glass.onGlass),
                        ),
                        Text('متبقٍ', style: TextStyle(fontSize: 11, color: glass.onGlassMuted)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(next.name.isPrayer ? 'الصلاة القادمة' : 'الشروق القادم',
                        style: TextStyle(color: glass.onGlassMuted)),
                    const SizedBox(height: 2),
                    Text(next.name.nameAr,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                    Text(ArabicUtils.formatTime(next.time),
                        style: TextStyle(fontSize: 18, color: glass.accent, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.place_rounded, size: 14, color: glass.onGlassMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            state.location?.city ?? 'موقعك الحالي',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: glass.onGlassMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  DateTime _previousTime(PrayerState state, NextPrayer next) {
    final today = state.today!;
    final order = PrayerName.values;
    final idx = order.indexOf(next.name);
    final isTomorrow = next.time.day != today.date.day;
    if (isTomorrow) return today[PrayerName.isha];
    if (idx == 0) {
      // Before Fajr: count from yesterday's Isha (approximate as today's Isha - 1 day).
      return today[PrayerName.isha].subtract(const Duration(days: 1));
    }
    return today[order[idx - 1]];
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;

  _RingPainter({required this.progress, required this.color, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 6;
    final bg = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius, bg);
    final fg = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [color.withValues(alpha: 0.4), color],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, 2 * math.pi * progress, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress || old.color != color;
}
