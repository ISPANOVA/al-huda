import 'package:flutter/material.dart';

import '../theme/app_themes.dart';
import '../theme/tones.dart';
import 'noor_ui.dart';

/// Frosted glass surface: backdrop blur + translucent gradient fill +
/// double border (outer hairline & inner highlight).
///
/// Pass `blur: 0` for "lite glass" inside long lists: it keeps the look
/// but skips the expensive BackdropFilter.
class GlassContainer extends StatelessWidget {
  /// Real backdrop blur is expensive (it re-blurs every frame while content
  /// behind it moves). Off by default for 60–120 fps; toggled from settings.
  static bool realBlur = false;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final double? opacity;
  final Color? tint;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double? width;
  final double? height;
  final Color? borderColor;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 24,
    this.blur = 18,
    this.opacity,
    this.tint,
    this.onTap,
    this.onLongPress,
    this.width,
    this.height,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);
    final base = noorSurface(context);
    // Calm, opaque surface (the "Noor" look). A tint, when given, is laid
    // softly over it for selected / highlighted states.
    final fill = tint == null ? base : Color.alphaBlend(tint!.withValues(alpha: ((opacity ?? 0.3) * 0.6).clamp(0.0, 1.0)), base);

    final surface = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: fill,
        border: Border.all(
          color: borderColor ?? glass.accent.withValues(alpha: dark ? 0.16 : 0.22),
          width: 1,
        ),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [Colors.white.withValues(alpha: dark ? 0.035 : 0.0), Colors.transparent],
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: radius,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );

    return Padding(padding: margin ?? EdgeInsets.zero, child: surface);
  }
}

/// Circular glass button.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final String? tooltip;
  final Color? color;
  final bool highlighted;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 48,
    this.tooltip,
    this.color,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final button = GlassContainer(
      width: size,
      height: size,
      borderRadius: size / 2,
      padding: EdgeInsets.zero,
      blur: 10,
      tint: highlighted ? glass.accent : null,
      opacity: highlighted ? 0.55 : null,
      onTap: onPressed,
      child: Center(child: Icon(icon, size: size * 0.48, color: color ?? glass.onGlass)),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Section title used across pages.
class GlassSectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  /// Colour of the little star before the title (the page's tone).
  final Tone? tone;

  const GlassSectionTitle(this.title, {super.key, this.trailing, this.tone});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 22, 4, 10),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 14,
            child: CustomPaint(painter: KhatamPainter(tone?.ink(dark) ?? glass.accent, stroke: 1.6)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: TextStyle(fontFamily: AppFonts.display, fontSize: 19, fontWeight: FontWeight.w700, color: glass.onGlass)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Thin rounded progress bar with accent gradient.
class GlassProgressBar extends StatelessWidget {
  final double value;
  final double height;

  const GlassProgressBar({super.key, required this.value, this.height = 10});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: glass.onGlass.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(height),
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: v,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height),
              gradient: LinearGradient(colors: [glass.accent.withValues(alpha: 0.75), glass.accent]),
            ),
          ),
        ),
      ),
    );
  }
}
