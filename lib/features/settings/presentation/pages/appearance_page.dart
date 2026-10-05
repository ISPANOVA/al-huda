import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_themes.dart';
import '../../../../core/theme/tones.dart';
import '../../../../core/theme/web_lite.dart';
import '../../../../core/widgets/background_patterns.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/noor_ui.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';
import 'settings_page.dart' show showCustomColorsSheet;

/// المظهر: colours (theme + light/dark + custom) and the background ornament.
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const AppearancePage());

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'المظهر',
      subtitle: 'ألوان التطبيق وزخرفة الخلفية',
      icon: Icons.palette_rounded,
      tone: Tone.amethyst,
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, s) {
          final cubit = context.read<SettingsCubit>();
          final glass = GlassTheme.of(context);
          final pattern = BgPattern.values[s.bgPattern.clamp(0, BgPattern.values.length - 1)];
          final palette = AppThemes.palette(s.themeType);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            physics: const BouncingScrollPhysics(),
            children: [
              const _LivePreview(),

              // ------------------------------------------------ theme ---
              GlassSectionTitle('الثيم', tone: Tone.amethyst, trailing: _Pill(palette.nameAr, tone: Tone.amethyst)),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  mainAxisExtent: 124,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                children: [
                  for (final t in AppThemeType.values) _ThemeTile(type: t, selected: s.themeType == t),
                ],
              ),
              if (s.themeType == AppThemeType.custom)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ToneCard(
                    tone: Tone.amethyst,
                    radius: 20,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    onTap: () => showCustomColorsSheet(context),
                    child: Row(
                      children: [
                        const ToneIcon(Icons.palette_rounded, tone: Tone.amethyst, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('تعديل ألواني',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: glass.onGlass)),
                        ),
                        Icon(Icons.chevron_left_rounded, color: glass.onGlassMuted),
                      ],
                    ),
                  ),
                ),

              // ------------------------------------------------- mode ---
              const GlassSectionTitle('الوضع', tone: Tone.sapphire),
              NoorCard(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _ModeTile(
                          label: 'تلقائي',
                          hint: 'حسب الجهاز',
                          icon: Icons.brightness_auto_rounded,
                          tone: Tone.teal,
                          selected: s.themeMode == ThemeMode.system,
                          onTap: () => cubit.setThemeMode(ThemeMode.system),
                        ),
                        const SizedBox(width: 8),
                        _ModeTile(
                          label: 'فاتح',
                          hint: 'نهاري',
                          icon: Icons.light_mode_rounded,
                          tone: Tone.amber,
                          selected: s.themeMode == ThemeMode.light,
                          onTap: () => cubit.setThemeMode(ThemeMode.light),
                        ),
                        const SizedBox(width: 8),
                        _ModeTile(
                          label: 'داكن',
                          hint: 'ليلي',
                          icon: Icons.dark_mode_rounded,
                          tone: Tone.sapphire,
                          selected: s.themeMode == ThemeMode.dark,
                          onTap: () => cubit.setThemeMode(ThemeMode.dark),
                        ),
                      ],
                    ),
                    if (palette.alwaysDark || palette.alwaysLight)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 12, 6, 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 18, color: Tone.sapphire.ink(Theme.of(context).brightness == Brightness.dark)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                s.themeType == AppThemeType.custom
                                    ? 'الوضع الفاتح أو الداكن يتحدد تلقائيًا من لون الخلفية الذي اخترته.'
                                    : 'هذا الثيم داكن دائمًا بطبيعته.',
                                style: TextStyle(fontSize: 12, height: 1.5, color: glass.onGlassMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // ------------------------------------------- ornament ---
              GlassSectionTitle('زخرفة الخلفية', tone: Tone.teal, trailing: _Pill(pattern.labelAr, tone: Tone.teal)),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 150,
                  mainAxisExtent: 142,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                children: [
                  for (final p in BgPattern.values)
                    _PatternTile(
                      pattern: p,
                      selected: p == pattern,
                      onTap: () => cubit.setBackgroundPattern(p),
                    ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child: pattern == BgPattern.none
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: NoorCard(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const ToneIcon(Icons.tune_rounded, tone: Tone.teal, size: 40),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text('وضوح الزخرفة',
                                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: glass.onGlass)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              _StrengthSlider(value: s.patternStrength),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('هادئة', style: TextStyle(fontSize: 12, color: glass.onGlassMuted)),
                                    Text('واضحة', style: TextStyle(fontSize: 12, color: glass.onGlassMuted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),

              // --------------------------------------------- widgets ---
              if (!kIsWeb) ...[
                // home-screen widgets are Android only
                const GlassSectionTitle('ويدجت الشاشة الرئيسية', tone: Tone.sky),
                _WidgetStyleCard(opacity: s.widgetOpacity, textColor: Color(s.widgetTextColor)),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Small rounded label in a tone (the current choice beside a section title).
class _Pill extends StatelessWidget {
  final String text;
  final Tone tone;

  const _Pill(this.text, {required this.tone});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: tone.mid.withValues(alpha: dark ? 0.18 : 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tone.mid.withValues(alpha: 0.35)),
      ),
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tone.ink(dark))),
    );
  }
}

/// One of the three light / dark / automatic choices.
class _ModeTile extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final Tone tone;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTile({
    required this.label,
    required this.hint,
    required this.icon,
    required this.tone,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: selected ? tone.solid : tone.wash(dark),
              border: Border.all(
                color: selected ? Colors.white.withValues(alpha: 0.22) : tone.mid.withValues(alpha: dark ? 0.28 : 0.32),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                selected
                    ? Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: Colors.white, size: 22),
                      )
                    : ToneIcon(icon, tone: tone, size: 40),
                const SizedBox(height: 8),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 14, color: selected ? Colors.white : glass.onGlass)),
                Text(hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        color: selected ? Colors.white.withValues(alpha: 0.8) : glass.onGlassMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Background of the home-screen widgets: transparent, half or solid.
class _WidgetStyleCard extends StatefulWidget {
  final double opacity;
  final Color textColor;

  const _WidgetStyleCard({required this.opacity, required this.textColor});

  @override
  State<_WidgetStyleCard> createState() => _WidgetStyleCardState();
}

class _WidgetStyleCardState extends State<_WidgetStyleCard> {
  late double _v = widget.opacity;

  @override
  void didUpdateWidget(covariant _WidgetStyleCard old) {
    super.didUpdateWidget(old);
    if (old.opacity != widget.opacity) _v = widget.opacity;
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cubit = context.read<SettingsCubit>();
    const tone = Tone.sky;
    Widget chip(String label, double value) {
      final on = (_v - value).abs() < 0.01;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() => _v = value);
            cubit.setWidgetOpacity(value);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: on ? tone.solid : null,
              color: on ? null : glass.onGlass.withValues(alpha: 0.05),
              border: Border.all(
                  color: on ? Colors.white.withValues(alpha: 0.2) : tone.mid.withValues(alpha: dark ? 0.25 : 0.3)),
            ),
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: on ? Colors.white : glass.onGlass)),
          ),
        ),
      );
    }

    return NoorCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ToneIcon(Icons.widgets_rounded, tone: tone, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ويدجت الشاشة الرئيسية',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: glass.onGlass)),
                    Text('خلفية الويدجت ولون كتابته',
                        style: TextStyle(fontSize: 12, height: 1.4, color: glass.onGlassMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _WidgetPreview(opacity: _v, textColor: widget.textColor),
          const SizedBox(height: 14),
          Row(children: [chip('شفافة', 0), chip('نصف شفافة', 0.5), chip('بخلفية', 1)]),
          Slider(
            value: _v,
            onChanged: (v) => setState(() => _v = v),
            onChangeEnd: cubit.setWidgetOpacity,
          ),
          Divider(height: 18, color: glass.onGlass.withValues(alpha: 0.08)),
          Row(
            children: [
              Icon(Icons.format_color_text_rounded, size: 20, color: tone.ink(dark)),
              const SizedBox(width: 8),
              Text('لون الكتابة', style: TextStyle(fontWeight: FontWeight.w800, color: glass.onGlass)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in _textColors)
                GestureDetector(
                  onTap: () => cubit.setWidgetTextColor(c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c,
                      border: Border.all(
                        color: c.toARGB32() == widget.textColor.toARGB32()
                            ? glass.accent
                            : glass.onGlass.withValues(alpha: 0.25),
                        width: c.toARGB32() == widget.textColor.toARGB32() ? 3 : 1,
                      ),
                    ),
                    child: c.toARGB32() == widget.textColor.toARGB32()
                        ? Icon(Icons.check_rounded,
                            size: 20, color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: tone.wash(dark),
              border: Border.all(color: tone.mid.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded, size: 18, color: tone.ink(dark)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'لإضافة ويدجت: اضغط مطولًا على الشاشة الرئيسية ← الأدوات (Widgets) ← الهدى. '
                    'فيه ٥ أشكال لمواقيت الصلاة بالإضافة لآية اليوم والأذكار.',
                    style: TextStyle(fontSize: 12, height: 1.6, color: glass.onGlassMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _textColors = [
  Color(0xFFFFFFFF),
  Color(0xFF121212),
  Color(0xFFE2C275),
  Color(0xFFCFD8DC),
  Color(0xFF8FE3B0),
  Color(0xFF8EC5FF),
  Color(0xFFFFB3C7),
  Color(0xFFFFCC80),
];

/// A look-alike of the "next prayer" widget over a wallpaper.
class _WidgetPreview extends StatelessWidget {
  final double opacity;
  final Color textColor;

  const _WidgetPreview({required this.opacity, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B2A6B), Color(0xFFB4553D), Color(0xFF1E6B73)],
        ),
      ),
      child: Container(
        height: 92,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2A2A2A).withValues(alpha: opacity),
              const Color(0xFF1B1B1B).withValues(alpha: opacity),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12 * opacity)),
        ),
        child: Row(
          children: [
            Text('الظُّهْر',
                style: QuranFont.amiriQuran.style(
                  fontSize: 34,
                  height: 1.4,
                  color: textColor,
                ).copyWith(shadows: const [Shadow(color: Color(0x66000000), blurRadius: 5)])),
            const Spacer(),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('١٢:٣٤',
                    style: TextStyle(
                        color: textColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        shadows: const [Shadow(color: Color(0x66000000), blurRadius: 5)])),
                const SizedBox(height: 2),
                Text('بعد ٣ س ٤٣ د',
                    style: TextStyle(
                        color: textColor.withValues(alpha: 0.66),
                        fontSize: 15,
                        shadows: const [Shadow(color: Color(0x66000000), blurRadius: 5)])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StrengthSlider extends StatefulWidget {
  final double value;

  const _StrengthSlider({required this.value});

  @override
  State<_StrengthSlider> createState() => _StrengthSliderState();
}

class _StrengthSliderState extends State<_StrengthSlider> {
  late double _v = widget.value;

  @override
  void didUpdateWidget(covariant _StrengthSlider old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _v = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    return Slider(
      value: _v.clamp(0.4, 2.0),
      min: 0.4,
      max: 2.0,
      onChanged: (v) {
        setState(() => _v = v);
        cubit.previewPatternStrength(v);
      },
      onChangeEnd: cubit.setPatternStrength,
    );
  }
}

/// A miniature of the app with the current colours and ornament.
class _LivePreview extends StatelessWidget {
  const _LivePreview();

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return Container(
      height: 196,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: glass.accent.withValues(alpha: 0.5), width: 1.4),
      ),
      child: GradientBackground(
        child: Stack(
          children: [
            PositionedDirectional(
              top: -40,
              end: -40,
              child: IgnorePointer(
                child: SizedBox.square(
                  dimension: 150,
                  child: CustomPaint(painter: KhatamPainter(glass.accent.withValues(alpha: 0.22))),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('الهدى',
                          style: TextStyle(
                              fontFamily: AppFonts.display,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: glass.accent)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: glass.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: glass.accent.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility_rounded, size: 14, color: glass.accent),
                            const SizedBox(width: 4),
                            Text('معاينة',
                                style: TextStyle(fontSize: 12, color: glass.accent, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  NoorCard(
                    radius: 20,
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        const ToneIcon(Icons.mosque_rounded, tone: Tone.sapphire, size: 36),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('الصلاة القادمة: العصر',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w800, color: glass.onGlass)),
                        ),
                        Text('٠٣:١٢',
                            style: TextStyle(
                                fontFamily: AppFonts.display, fontWeight: FontWeight.w700, color: glass.accent)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatternTile extends StatelessWidget {
  final BgPattern pattern;
  final bool selected;
  final VoidCallback onTap;

  const _PatternTile({required this.pattern, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      selected: selected,
      label: pattern.labelAr,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: glass.backgroundGradient,
            ),
            border: Border.all(
              color: selected ? glass.accent : glass.onGlass.withValues(alpha: 0.12),
              width: selected ? 2.5 : 1,
            ),
            boxShadow: liteShadows(
                selected ? [BoxShadow(color: glass.accent.withValues(alpha: 0.35), blurRadius: 14)] : null),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: PatternPainter(
                    pattern: pattern,
                    color: glass.accent.withValues(alpha: dark ? 0.5 : 0.6),
                    scale: 0.5,
                  ),
                ),
              ),
              if (pattern == BgPattern.none)
                Center(child: Icon(Icons.crop_square_rounded, color: glass.onGlassMuted, size: 30)),
              PositionedDirectional(
                top: 7,
                end: 7,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: selected ? 1.0 : 0.0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: glass.accent),
                    child: Icon(Icons.check_rounded,
                        size: 16, color: glass.accent.computeLuminance() > 0.5 ? Colors.black : Colors.white),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 16, 6, 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [glass.backgroundGradient.last.withValues(alpha: 0), glass.backgroundGradient.last],
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(pattern.labelAr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: selected ? glass.accent : glass.onGlass)),
                      Text(pattern.hintAr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 9.5, color: glass.onGlassMuted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A theme as a little picture of the app in its colours: its background,
/// a card in its accent, its colour swatches and its name.
class _ThemeTile extends StatelessWidget {
  final AppThemeType type;
  final bool selected;

  const _ThemeTile({required this.type, required this.selected});

  @override
  Widget build(BuildContext context) {
    final p = AppThemes.palette(type);
    final dark = Theme.of(context).brightness == Brightness.dark || p.alwaysDark;
    final colors = dark ? p.darkGradient : p.lightGradient;
    final fg = dark ? Colors.white : const Color(0xFF0E1B17);
    return Semantics(
      button: true,
      selected: selected,
      label: p.nameAr,
      child: GestureDetector(
        onTap: () async {
          await context.read<SettingsCubit>().setThemeType(type);
          if (type == AppThemeType.custom && context.mounted) showCustomColorsSheet(context);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(colors: colors, begin: Alignment.topRight, end: Alignment.bottomLeft),
            border: Border.all(color: selected ? p.accent : fg.withValues(alpha: 0.16), width: selected ? 3 : 1),
            boxShadow: liteShadows(
                selected ? [BoxShadow(color: p.accent.withValues(alpha: 0.5), blurRadius: 16)] : null),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PositionedDirectional(
                bottom: -26,
                end: -26,
                child: IgnorePointer(
                  child: SizedBox.square(
                    dimension: 84,
                    child: CustomPaint(painter: KhatamPainter(p.accent.withValues(alpha: 0.28))),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (final c in [p.primary, p.secondary, p.accent])
                          Container(
                            width: 16,
                            height: 16,
                            margin: const EdgeInsetsDirectional.only(end: 4),
                            decoration: BoxDecoration(
                                shape: BoxShape.circle, color: c, border: Border.all(color: Colors.white54)),
                          ),
                        const Spacer(),
                        AnimatedScale(
                          duration: const Duration(milliseconds: 200),
                          scale: selected ? 1.0 : 0.0,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: p.accent),
                            child: Icon(Icons.check_rounded,
                                size: 16, color: p.accent.computeLuminance() > 0.5 ? Colors.black : Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // a tiny card in the theme's accent: how pages will look.
                    Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: fg.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: p.accent.withValues(alpha: 0.45)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: p.accent),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Container(
                              height: 5,
                              decoration: BoxDecoration(
                                color: fg.withValues(alpha: 0.30),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 18,
                            height: 5,
                            decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(3)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p.nameAr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: fg),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
