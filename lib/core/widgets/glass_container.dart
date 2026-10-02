import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_themes.dart';

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
    final radius = BorderRadius.circular(borderRadius);
    final baseOpacity = opacity ?? glass.glassOpacity;
    final tintColor = tint ?? glass.glassTint;

    Widget surface = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tintColor.withValues(alpha: (baseOpacity + 0.10).clamp(0.0, 1.0)),
            tintColor.withValues(alpha: baseOpacity),
            tintColor.withValues(alpha: (baseOpacity * 0.6).clamp(0.0, 1.0)),
          ],
          stops: const [0, 0.55, 1],
        ),
        border: Border.all(color: borderColor ?? glass.glassBorder, width: 1.2),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: glass.glassHighlight, width: 0.6),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [glass.glassHighlight.withValues(alpha: 0.18), Colors.transparent],
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (blur > 0 && realBlur) {
      surface = BackdropFilter(filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: surface);
    }

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(borderRadius: radius, child: surface),
    );
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

  const GlassSectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(color: glass.accent, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
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
        color: glass.onGlass.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(height),
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: v,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height),
              gradient: LinearGradient(colors: [glass.accent, Theme.of(context).colorScheme.primary]),
              boxShadow: [BoxShadow(color: glass.accent.withValues(alpha: 0.5), blurRadius: 8)],
            ),
          ),
        ),
      ),
    );
  }
}
