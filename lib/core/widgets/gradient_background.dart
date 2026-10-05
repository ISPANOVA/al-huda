import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_themes.dart';
import 'adaptive.dart';
import '../theme/tones.dart';
import 'background_patterns.dart';

/// Vibrant multi-stop gradient with soft light orbs behind the glass layers.
class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final size = MediaQuery.sizeOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: glass.backgroundGradient,
            ),
          ),
        ),
        _Orb(color: glass.orbs[0], diameter: size.width * 0.9, top: -size.width * 0.3, right: -size.width * 0.25),
        _Orb(color: glass.orbs[1], diameter: size.width * 0.7, top: size.height * 0.35, left: -size.width * 0.35),
        _Orb(color: glass.orbs[2], diameter: size.width * 0.8, bottom: -size.width * 0.3, right: -size.width * 0.2),
        const _IslamicPatternOverlay(),
        child,
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double diameter;
  final double? top, left, right, bottom;

  const _Orb({required this.color, required this.diameter, this.top, this.left, this.right, this.bottom});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withValues(alpha: 0.45), color.withValues(alpha: 0.0)],
            ),
          ),
        ),
      ),
    );
  }
}

/// The user's chosen ornament (see BackgroundStyle), painted in the accent.
class _IslamicPatternOverlay extends StatelessWidget {
  const _IslamicPatternOverlay();

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: RepaintBoundary(
        child: ValueListenableBuilder(
          valueListenable: BackgroundStyle.current,
          builder: (context, style, _) {
            final painter = PatternPainter(
              pattern: style.pattern,
              color: glass.accent.withValues(alpha: dark ? 0.14 : 0.18),
              strength: style.strength,
            );
            // The browser keeps no raster cache: a full-screen pattern would be
            // re-stroked on every frame. Draw it once into an image there.
            return kIsWeb ? _CachedPattern(painter: painter) : CustomPaint(painter: painter);
          },
        ),
      ),
    );
  }
}

/// Web only: the pattern rendered once per size / style into an image.
class _CachedPattern extends StatefulWidget {
  final PatternPainter painter;

  const _CachedPattern({required this.painter});

  @override
  State<_CachedPattern> createState() => _CachedPatternState();
}

class _CachedPatternState extends State<_CachedPattern> {
  ui.Image? _image;
  String? _key;

  ui.Image? _imageFor(Size size, double dpr) {
    final p = widget.painter;
    final key = '${size.width.round()}x${size.height.round()}@$dpr ${p.pattern} ${p.color.toARGB32()} ${p.strength}';
    if (key == _key) return _image;
    _image?.dispose();
    _image = null;
    _key = key;
    final w = (size.width * dpr).ceil(), h = (size.height * dpr).ceil();
    if (w <= 0 || h <= 0) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(dpr);
    p.paint(canvas, size);
    final picture = recorder.endRecording();
    try {
      _image = picture.toImageSync(w, h);
    } catch (_) {
      _image = null;
    }
    picture.dispose();
    return _image;
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(builder: (context, c) {
      final size = c.biggest;
      if (!size.isFinite) return CustomPaint(painter: widget.painter);
      final image = _imageFor(size, dpr);
      if (image == null) return CustomPaint(painter: widget.painter);
      return RawImage(image: image, width: size.width, height: size.height, fit: BoxFit.fill);
    });
  }
}

/// Standard page scaffold: gradient background, a header in the page's own
/// colour (back button, icon, title and actions) and a glow of that colour
/// behind the top of the page.
class GlassScaffold extends StatelessWidget {
  final String? title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottom;
  final bool showBack;
  final Widget? titleWidget;

  /// The colour of this part of the app (gold by default).
  final Tone tone;

  /// Shown in the tone's squircle beside the title.
  final IconData? icon;
  final String? subtitle;

  const GlassScaffold({
    super.key,
    this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottom,
    this.showBack = true,
    this.titleWidget,
    this.tone = Tone.gold,
    this.icon,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final hasHeader = title != null || titleWidget != null;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // The background lives *outside* the Scaffold and behind a RepaintBoundary,
    // so the keyboard animation (which resizes the Scaffold body every frame)
    // never re-lays-out or repaints it. This removes the typing/search stutter.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Stack(
      children: [
        const Positioned.fill(child: RepaintBoundary(child: GradientBackground(child: SizedBox.expand()))),
        if (hasHeader)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -1.1),
                    radius: 1.1,
                    colors: [tone.mid.withValues(alpha: 0.22), tone.mid.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
        Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: floatingActionButton,
          // On a tablet or computer the page keeps a comfortable reading
          // width, centred on the full-screen background.
          body: SafeArea(
            child: MaxWidth(
              child: Column(
                children: [
                  if (hasHeader)
                    PageHeaderBar(
                      title: title,
                      titleWidget: titleWidget,
                      subtitle: subtitle,
                      icon: icon,
                      tone: tone,
                      showBack: showBack,
                      actions: actions ?? const [],
                    ),
                  Expanded(child: body),
                  ?bottom,
                ],
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }
}

/// The header of an inner page: a round back button, the page's coloured
/// icon, its title in the display face, and the page's actions.
class PageHeaderBar extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final String? subtitle;
  final IconData? icon;
  final Tone tone;
  final bool showBack;
  final List<Widget> actions;

  const PageHeaderBar({
    super.key,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.icon,
    this.tone = Tone.gold,
    this.showBack = true,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final canPop = showBack && (ModalRoute.of(context)?.impliesAppBarDismissal ?? false);
    return SizedBox(
      height: 68,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 8, 6),
        child: Row(
          children: [
            if (canPop) ...[
              _RoundButton(
                icon: Icons.arrow_back_rounded,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 10),
            ],
            if (icon != null) ...[
              ToneIcon(icon!, tone: tone, size: 40),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle.merge(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: glass.onGlass,
                    ),
                    child: titleWidget ?? Text(title ?? ''),
                  ),
                  if (subtitle != null)
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: glass.onGlassMuted, height: 1.3)),
                ],
              ),
            ),
            IconTheme.merge(
              data: IconThemeData(color: glass.onGlass),
              child: Row(mainAxisSize: MainAxisSize.min, children: actions),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: glass.onGlass.withValues(alpha: dark ? 0.07 : 0.06),
        shape: CircleBorder(side: BorderSide(color: glass.onGlass.withValues(alpha: 0.12))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(dimension: 42, child: Icon(icon, size: 22, color: glass.onGlass)),
        ),
      ),
    );
  }
}
