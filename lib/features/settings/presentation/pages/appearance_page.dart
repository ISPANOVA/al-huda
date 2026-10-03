import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_themes.dart';
import '../../../../core/widgets/background_patterns.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/gradient_background.dart';
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
              const GlassSectionTitle('ألوان التطبيق'),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.7,
                children: [
                  for (final t in AppThemeType.values) _ThemeTile(type: t, selected: s.themeType == t),
                ],
              ),
              const SizedBox(height: 12),
              GlassContainer(
                padding: const EdgeInsets.all(8),
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('تلقائي'), icon: Icon(Icons.brightness_auto_rounded)),
                    ButtonSegment(value: ThemeMode.light, label: Text('فاتح'), icon: Icon(Icons.light_mode_rounded)),
                    ButtonSegment(value: ThemeMode.dark, label: Text('داكن'), icon: Icon(Icons.dark_mode_rounded)),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (v) => cubit.setThemeMode(v.first),
                ),
              ),
              if (s.themeType == AppThemeType.custom)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.palette_rounded),
                    label: const Text('تعديل ألواني'),
                    onPressed: () => showCustomColorsSheet(context),
                  ),
                ),
              if (palette.alwaysDark || palette.alwaysLight)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    s.themeType == AppThemeType.custom
                        ? 'الوضع الفاتح أو الداكن يتحدد تلقائيًا من لون الخلفية الذي اخترته.'
                        : 'هذا الثيم داكن دائمًا بطبيعته.',
                    style: TextStyle(fontSize: 12, color: glass.onGlassMuted),
                    textAlign: TextAlign.center,
                  ),
                ),
              const GlassSectionTitle('زخرفة الخلفية'),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.74,
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
                        padding: const EdgeInsets.only(top: 14),
                        child: GlassContainer(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.tune_rounded, color: glass.accent),
                                  const SizedBox(width: 8),
                                  const Text('وضوح الزخرفة', style: TextStyle(fontWeight: FontWeight.w800)),
                                ],
                              ),
                              _StrengthSlider(value: s.patternStrength),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('هادئة', style: TextStyle(fontSize: 12, color: glass.onGlassMuted)),
                                  Text('واضحة', style: TextStyle(fontSize: 12, color: glass.onGlassMuted)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 22),
              _WidgetStyleCard(opacity: s.widgetOpacity, textColor: Color(s.widgetTextColor)),
            ],
          );
        },
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
    final cubit = context.read<SettingsCubit>();
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
            padding: const EdgeInsets.symmetric(vertical: 9),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: on ? glass.accent.withValues(alpha: 0.18) : glass.onGlass.withValues(alpha: 0.05),
              border: Border.all(color: on ? glass.accent : glass.onGlass.withValues(alpha: 0.12)),
            ),
            child: Text(label,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: on ? glass.accent : glass.onGlass)),
          ),
        ),
      );
    }

    return GlassContainer(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.widgets_rounded, color: glass.accent),
              const SizedBox(width: 8),
              const Text('ويدجت الشاشة الرئيسية', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          _WidgetPreview(opacity: _v, textColor: widget.textColor),
          const SizedBox(height: 12),
          Row(children: [chip('شفافة', 0), chip('نصف شفافة', 0.5), chip('بخلفية', 1)]),
          Slider(
            value: _v,
            onChanged: (v) => setState(() => _v = v),
            onChangeEnd: cubit.setWidgetOpacity,
          ),
          Text('لون الكتابة', style: TextStyle(fontWeight: FontWeight.w800, color: glass.onGlass)),
          const SizedBox(height: 10),
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
          const SizedBox(height: 12),
          Text(
            'لإضافة ويدجت: اضغط مطولًا على الشاشة الرئيسية ← الأدوات (Widgets) ← الهدى. '
            'فيه ٥ أشكال لمواقيت الصلاة بالإضافة لآية اليوم والأذكار.',
            style: TextStyle(fontSize: 12, height: 1.6, color: glass.onGlassMuted),
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
      height: 190,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: glass.accent.withValues(alpha: 0.45)),
      ),
      child: GradientBackground(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('الهدى', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: glass.accent)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: glass.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('معاينة', style: TextStyle(fontSize: 12, color: glass.accent, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const Spacer(),
              GlassContainer(
                blur: 0,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.mosque_rounded, color: glass.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('الصلاة القادمة: العصر', style: TextStyle(fontWeight: FontWeight.w800, color: glass.onGlass)),
                    ),
                    Text('٠٣:١٢', style: TextStyle(color: glass.onGlassMuted)),
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

class _PatternTile extends StatelessWidget {
  final BgPattern pattern;
  final bool selected;
  final VoidCallback onTap;

  const _PatternTile({required this.pattern, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
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
          boxShadow: selected ? [BoxShadow(color: glass.accent.withValues(alpha: 0.35), blurRadius: 14)] : null,
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
            if (selected)
              PositionedDirectional(
                top: 6,
                end: 6,
                child: Icon(Icons.check_circle_rounded, color: glass.accent, size: 22),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
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
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final AppThemeType type;
  final bool selected;

  const _ThemeTile({required this.type, required this.selected});

  @override
  Widget build(BuildContext context) {
    final p = AppThemes.palette(type);
    final dark = Theme.of(context).brightness == Brightness.dark || p.alwaysDark;
    final colors = dark ? p.darkGradient : p.lightGradient;
    return GestureDetector(
      onTap: () async {
        await context.read<SettingsCubit>().setThemeType(type);
        if (type == AppThemeType.custom && context.mounted) showCustomColorsSheet(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(colors: colors, begin: Alignment.topRight, end: Alignment.bottomLeft),
          border: Border.all(color: selected ? p.accent : Colors.white24, width: selected ? 3 : 1),
          boxShadow: selected ? [BoxShadow(color: p.accent.withValues(alpha: 0.5), blurRadius: 16)] : null,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                for (final c in [p.primary, p.secondary, p.accent])
                  Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsetsDirectional.only(end: 4),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: c, border: Border.all(color: Colors.white54)),
                  ),
                const Spacer(),
                if (selected) Icon(Icons.check_circle_rounded, color: p.accent),
              ],
            ),
            Text(
              type == AppThemeType.custom ? '🎨 ${p.nameAr}' : p.nameAr,
              style: TextStyle(fontWeight: FontWeight.w900, color: dark ? Colors.white : const Color(0xFF0E1B17)),
            ),
          ],
        ),
      ),
    );
  }
}
