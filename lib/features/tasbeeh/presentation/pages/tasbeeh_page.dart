import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_themes.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../cubit/tasbeeh_cubit.dart';

/// Glassy electronic Subha.
class TasbeehPage extends StatefulWidget {
  const TasbeehPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const TasbeehPage());

  @override
  State<TasbeehPage> createState() => _TasbeehPageState();
}

class _TasbeehPageState extends State<TasbeehPage> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 180), lowerBound: 0.94, upperBound: 1)
        ..value = 1;

  static const _targets = [33, 99, 100, 1000, 0];

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _onTap() {
    final haptics = context.read<SettingsCubit>().state.hapticFeedback;
    final roundDone = context.read<TasbeehCubit>().tap();
    _pulse.reverse(from: 1).then((_) => _pulse.forward());
    final count = context.read<TasbeehCubit>().state.count;
    if (haptics) {
      if (roundDone) {
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 140), HapticFeedback.heavyImpact);
      } else if (count > 0 && count % 33 == 0) {
        HapticFeedback.mediumImpact();
        Future.delayed(const Duration(milliseconds: 110), HapticFeedback.mediumImpact);
      } else {
        HapticFeedback.lightImpact();
      }
    }
    if (roundDone) {
      _celebrate();
      final st = context.read<TasbeehCubit>().state;
      showGlassSnack(
        context,
        st.autoNext && st.phrases.length > 1
            ? 'أتممت الدورة • الذكر التالي: ${st.phrase}'
            : 'أتممت دورة كاملة، بارك الله فيك',
      );
    }
  }

  /// A short burst of golden stars over the counter.
  void _celebrate() {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    final accent = GlassTheme.of(context).accent;
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _StarBurst(color: accent, onDone: () => entry.remove()));
    overlay.insert(entry);
  }

  Future<void> _addPhrase() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة ذكر'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'اكتب الذكر')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('إضافة')),
        ],
      ),
    );
    controller.dispose();
    if (result != null && mounted) context.read<TasbeehCubit>().addPhrase(result);
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return GlassScaffold(
      title: 'المسبحة الإلكترونية',
      actions: [
        IconButton(tooltip: 'إضافة ذكر', icon: const Icon(Icons.add_rounded), onPressed: _addPhrase),
        IconButton(
          tooltip: 'تصفير',
          icon: const Icon(Icons.restart_alt_rounded),
          onPressed: () => context.read<TasbeehCubit>().reset(),
        ),
      ],
      body: BlocBuilder<TasbeehCubit, TasbeehState>(
        builder: (context, state) {
          final cubit = context.read<TasbeehCubit>();
          final progress = state.target == 0 ? 0.0 : state.count / state.target;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: state.phrases.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => GestureDetector(
                    onLongPress: state.phrases.length > 1
                        ? () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('حذف هذا الذكر؟'),
                                content: Text(state.phrases[i]),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
                                ],
                              ),
                            );
                            if (ok == true) cubit.removePhrase(i);
                          }
                        : null,
                    child: ChoiceChip(
                      label: Text(state.phrases[i]),
                      selected: state.selected == i,
                      onSelected: (_) => cubit.selectPhrase(i),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              GlassContainer(
                padding: const EdgeInsets.all(18),
                child: Text(
                  state.phrase,
                  textAlign: TextAlign.center,
                  style: context
                      .read<SettingsCubit>()
                      .state
                      .quranFont
                      .style(fontSize: 28, height: 1.8, color: glass.onGlass, weight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: ScaleTransition(
                  scale: _pulse,
                  child: GestureDetector(
                    onTap: _onTap,
                    child: SizedBox(
                      width: 260,
                      height: 260,
                      child: CustomPaint(
                        painter: _BeadsRingPainter(
                          progress: progress,
                          accent: glass.accent,
                          track: glass.onGlass.withValues(alpha: 0.15),
                          beads: state.target == 0 || state.target > 100 ? 33 : state.target,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: GlassContainer(
                            borderRadius: 200,
                            blur: 24,
                            padding: EdgeInsets.zero,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    ArabicUtils.toArabicDigits(state.count),
                                    style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: glass.onGlass),
                                  ),
                                  Text(
                                    state.target == 0 ? 'بلا حد' : 'من ${ArabicUtils.toArabicDigits(state.target)}',
                                    style: TextStyle(color: glass.onGlassMuted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(child: Text('اضغط على الدائرة للتسبيح', style: TextStyle(color: glass.onGlassMuted))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _StatTile(label: 'الدورات', value: state.rounds)),
                  const SizedBox(width: 10),
                  Expanded(child: _StatTile(label: 'إجمالي التسبيح', value: state.lifetime)),
                ],
              ),
              const GlassSectionTitle('عدد الدورة'),
              Wrap(
                spacing: 8,
                children: [
                  for (final t in _targets)
                    ChoiceChip(
                      label: Text(t == 0 ? 'مفتوح' : ArabicUtils.toArabicDigits(t)),
                      selected: state.target == t,
                      onSelected: (_) => cubit.setTarget(t),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('الانتقال للذكر التالي تلقائيًا'),
                  subtitle: const Text('بعد إتمام عدد الدورة ينتقل للذكر الذي يليه'),
                  value: state.autoNext,
                  onChanged: state.target == 0 ? null : cubit.setAutoNext,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return GlassContainer(
      child: Column(
        children: [
          Text(ArabicUtils.toArabicDigits(value), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: glass.accent)),
          Text(label, style: TextStyle(color: glass.onGlassMuted)),
        ],
      ),
    );
  }
}

/// Ring of beads that light up with progress.
class _BeadsRingPainter extends CustomPainter {
  final double progress;
  final Color accent;
  final Color track;
  final int beads;

  _BeadsRingPainter({required this.progress, required this.accent, required this.track, required this.beads});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 10;
    final lit = (progress * beads).floor();
    for (var i = 0; i < beads; i++) {
      final a = -math.pi / 2 + 2 * math.pi * i / beads;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      final on = i < lit;
      if (on) canvas.drawCircle(p, 8, Paint()..color = accent.withValues(alpha: 0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawCircle(p, beads > 60 ? 3.5 : 5.5, Paint()..color = on ? accent : track);
    }
  }

  @override
  bool shouldRepaint(covariant _BeadsRingPainter old) =>
      old.progress != progress || old.beads != beads || old.accent != accent;
}


class _StarBurst extends StatefulWidget {
  final Color color;
  final VoidCallback onDone;

  const _StarBurst({required this.color, required this.onDone});

  @override
  State<_StarBurst> createState() => _StarBurstState();
}

class _StarBurstState extends State<_StarBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))
    ..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: MediaQuery.sizeOf(context),
          painter: _BurstPainter(_c.value, widget.color),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  final double t;
  final Color color;

  _BurstPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.45);
    final ease = Curves.easeOutCubic.transform(t);
    final fade = (1 - t).clamp(0.0, 1.0);
    final rnd = math.Random(5);
    for (var i = 0; i < 28; i++) {
      final a = i * 2 * math.pi / 28 + rnd.nextDouble() * 0.3;
      final dist = (90 + rnd.nextDouble() * 120) * ease;
      final p = c + Offset(math.cos(a) * dist, math.sin(a) * dist);
      final r = (3 + rnd.nextDouble() * 5) * (1 - t * 0.5);
      final path = Path();
      for (var k = 0; k < 8; k++) {
        final ang = -math.pi / 2 + k * math.pi / 4;
        final rr = k.isEven ? r : r * 0.4;
        final pt = p + Offset(math.cos(ang) * rr, math.sin(ang) * rr);
        k == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path..close(), Paint()..color = color.withValues(alpha: fade));
    }
    canvas.drawCircle(
      c,
      140 * ease,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * fade
        ..color = color.withValues(alpha: 0.5 * fade),
    );
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.t != t;
}
