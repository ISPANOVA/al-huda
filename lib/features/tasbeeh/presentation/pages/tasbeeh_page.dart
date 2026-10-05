import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_themes.dart';
import '../../../../core/theme/tones.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/noor_ui.dart';
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    const tone = Tone.teal;
    return GlassScaffold(
      title: 'المسبحة الإلكترونية',
      subtitle: 'عداد ذكي',
      icon: Icons.blur_circular_rounded,
      tone: tone,
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
              const SizedBox(height: 14),
              ToneCard(
                tone: tone,
                ornament: true,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox.square(
                          dimension: 12,
                          child: CustomPaint(painter: KhatamPainter(tone.ink(dark), stroke: 1.4)),
                        ),
                        const SizedBox(width: 8),
                        Text('الذكر الحالي',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tone.ink(dark))),
                        const SizedBox(width: 8),
                        SizedBox.square(
                          dimension: 12,
                          child: CustomPaint(painter: KhatamPainter(tone.ink(dark), stroke: 1.4)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      state.phrase,
                      textAlign: TextAlign.center,
                      style: context
                          .read<SettingsCubit>()
                          .state
                          .quranFont
                          .style(fontSize: 28, height: 1.8, color: glass.onGlass, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: ScaleTransition(
                  scale: _pulse,
                  child: GestureDetector(
                    onTap: _onTap,
                    child: RepaintBoundary(
                      child: SizedBox(
                        width: 272,
                        height: 272,
                        child: CustomPaint(
                          painter: _CounterPainter(
                            progress: progress,
                            light: tone.light,
                            deep: tone.deep,
                            surface: noorSurface(context),
                            track: glass.onGlass.withValues(alpha: dark ? 0.13 : 0.16),
                            beads: state.target == 0 || state.target > 100 ? 33 : state.target,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox.square(
                                dimension: 150,
                                child: CustomPaint(
                                  painter: KhatamPainter(tone.mid.withValues(alpha: dark ? 0.16 : 0.20), stroke: 1.2),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(64),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        ArabicUtils.toArabicDigits(state.count),
                                        style: TextStyle(
                                          fontFamily: AppFonts.display,
                                          fontSize: 66,
                                          fontWeight: FontWeight.w700,
                                          height: 1.15,
                                          color: tone.ink(dark),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        color: tone.mid.withValues(alpha: dark ? 0.18 : 0.14),
                                        border: Border.all(color: tone.mid.withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        state.target == 0 ? 'بلا حد' : 'من ${ArabicUtils.toArabicDigits(state.target)}',
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: tone.ink(dark),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app_rounded, size: 16, color: glass.onGlassMuted),
                  const SizedBox(width: 6),
                  Text('اضغط على الدائرة للتسبيح', style: TextStyle(color: glass.onGlassMuted)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(label: 'الدورات', value: state.rounds, icon: Icons.loop_rounded, tone: tone),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      label: 'إجمالي التسبيح',
                      value: state.lifetime,
                      icon: Icons.all_inclusive_rounded,
                      tone: Tone.emerald,
                    ),
                  ),
                ],
              ),
              const GlassSectionTitle('عدد الدورة', tone: tone),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in _targets)
                    ChoiceChip(
                      label: Text(t == 0 ? 'مفتوح' : ArabicUtils.toArabicDigits(t)),
                      selected: state.target == t,
                      onSelected: (_) => cubit.setTarget(t),
                    ),
                ],
              ),
              const GlassSectionTitle('الإعدادات', tone: tone),
              NoorCard(
                padding: EdgeInsets.zero,
                child: _SettingRow(
                  icon: Icons.skip_next_rounded,
                  tone: Tone.sapphire,
                  title: 'الانتقال للذكر التالي تلقائيًا',
                  subtitle: 'بعد إتمام عدد الدورة ينتقل للذكر الذي يليه',
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
  final IconData icon;
  final Tone tone;

  const _StatTile({required this.label, required this.value, required this.icon, required this.tone});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ToneCard(
      tone: tone,
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ToneIcon(icon, tone: tone, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      ArabicUtils.toArabicDigits(value),
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: tone.ink(dark),
                      ),
                    ),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: glass.onGlassMuted, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A settings row: coloured icon, title, subtitle and a switch.
class _SettingRow extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SettingRow({
    required this.icon,
    required this.tone,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final enabled = onChanged != null;
    return InkWell(
      onTap: enabled ? () => onChanged!(!value) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Opacity(opacity: enabled ? 1 : 0.5, child: ToneIcon(icon, tone: tone, size: 42)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: enabled ? glass.onGlass : glass.onGlassMuted,
                    ),
                  ),
                  if (subtitle != null)
                    Text(subtitle!, style: TextStyle(fontSize: 12, height: 1.4, color: glass.onGlassMuted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// The counter: a ring of beads that light up with the count, and a disc
/// with a teal rim that fills with the round's progress. Painted only when
/// the count changes (no running animation).
class _CounterPainter extends CustomPainter {
  final double progress;
  final Color light;
  final Color deep;
  final Color surface;
  final Color track;
  final int beads;

  _CounterPainter({
    required this.progress,
    required this.light,
    required this.deep,
    required this.surface,
    required this.track,
    required this.beads,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final mid = Color.lerp(light, deep, 0.45)!;
    final p = progress.clamp(0.0, 1.0);

    // Beads around the edge.
    final beadR = outer - 9;
    final lit = (p * beads).floor();
    final small = beads > 60;
    for (var i = 0; i < beads; i++) {
      final a = -math.pi / 2 + 2 * math.pi * i / beads;
      final o = Offset(c.dx + beadR * math.cos(a), c.dy + beadR * math.sin(a));
      final on = i < lit;
      if (on) {
        canvas.drawCircle(o, small ? 5.5 : 8, Paint()..color = light.withValues(alpha: 0.22));
        canvas.drawCircle(
          o,
          small ? 3.5 : 5.5,
          Paint()..color = Color.lerp(light, deep, beads <= 1 ? 0.0 : i / (beads - 1) * 0.7)!,
        );
      } else {
        canvas.drawCircle(o, small ? 3 : 4.5, Paint()..color = track);
      }
    }

    // The disc with a soft teal glow from the top.
    final discR = outer - 30;
    final disc = Rect.fromCircle(center: c, radius: discR);
    canvas.drawCircle(
      c,
      discR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.45),
          radius: 1.0,
          colors: [Color.lerp(surface, mid, 0.30)!, surface],
        ).createShader(disc),
    );

    // Soft halo outside the rim (a wide translucent stroke, no blur).
    if (p > 0) {
      canvas.drawCircle(
        c,
        discR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 20
          ..color = mid.withValues(alpha: 0.08 + 0.10 * p),
      );
    }

    // Rim track and progress arc.
    const rim = 9.0;
    canvas.drawCircle(
      c,
      discR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rim
        ..color = mid.withValues(alpha: 0.18),
    );
    if (p > 0) {
      canvas.drawArc(
        disc,
        -math.pi / 2,
        2 * math.pi * p,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = rim
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            colors: [light, mid, deep, light],
            transform: const GradientRotation(-math.pi / 2),
          ).createShader(disc),
      );
    }

    // Fine inner hairline.
    canvas.drawCircle(
      c,
      discR - rim / 2 - 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = light.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(covariant _CounterPainter old) =>
      old.progress != progress ||
      old.beads != beads ||
      old.light != light ||
      old.surface != surface ||
      old.track != track;
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
