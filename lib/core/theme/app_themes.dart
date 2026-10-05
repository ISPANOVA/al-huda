import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'page_transitions.dart';

/// Bundled typefaces.
class AppFonts {
  AppFonts._();

  /// Interface text.
  static const ui = 'Tajawal';

  /// Titles and large numbers (Kufi).
  static const display = 'ReemKufi';
}

enum AppThemeType { noirGold, emerald, andalusian, royalGold, obsidian, custom }

/// Colour DNA of one glass theme.
class GlassPalette {
  final String nameAr;
  final Color primary;
  final Color secondary;
  final Color accent;
  final List<Color> lightGradient;
  final List<Color> darkGradient;
  final List<Color> orbs;
  final bool alwaysDark;
  final bool alwaysLight;

  /// Accent used in light mode when the dark-mode accent is too pale on white.
  final Color? lightAccent;

  const GlassPalette({
    required this.nameAr,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.lightGradient,
    required this.darkGradient,
    required this.orbs,
    this.alwaysDark = false,
    this.alwaysLight = false,
    this.lightAccent,
  });
}

/// Theme extension carrying the frosted-glass tokens used by glass widgets.
@immutable
class GlassTheme extends ThemeExtension<GlassTheme> {
  final List<Color> backgroundGradient;
  final List<Color> orbs;
  final Color glassTint;
  final Color glassBorder;
  final Color glassHighlight;
  final Color accent;
  final Color onGlass;
  final Color onGlassMuted;
  final Color highlightAyah;
  final double glassOpacity;

  const GlassTheme({
    required this.backgroundGradient,
    required this.orbs,
    required this.glassTint,
    required this.glassBorder,
    required this.glassHighlight,
    required this.accent,
    required this.onGlass,
    required this.onGlassMuted,
    required this.highlightAyah,
    required this.glassOpacity,
  });

  static GlassTheme of(BuildContext context) => Theme.of(context).extension<GlassTheme>()!;

  @override
  GlassTheme copyWith({
    List<Color>? backgroundGradient,
    List<Color>? orbs,
    Color? glassTint,
    Color? glassBorder,
    Color? glassHighlight,
    Color? accent,
    Color? onGlass,
    Color? onGlassMuted,
    Color? highlightAyah,
    double? glassOpacity,
  }) {
    return GlassTheme(
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      orbs: orbs ?? this.orbs,
      glassTint: glassTint ?? this.glassTint,
      glassBorder: glassBorder ?? this.glassBorder,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      accent: accent ?? this.accent,
      onGlass: onGlass ?? this.onGlass,
      onGlassMuted: onGlassMuted ?? this.onGlassMuted,
      highlightAyah: highlightAyah ?? this.highlightAyah,
      glassOpacity: glassOpacity ?? this.glassOpacity,
    );
  }

  @override
  GlassTheme lerp(ThemeExtension<GlassTheme>? other, double t) {
    if (other is! GlassTheme) return this;
    List<Color> lerpList(List<Color> a, List<Color> b) =>
        List.generate(a.length, (i) => Color.lerp(a[i], b[i < b.length ? i : b.length - 1], t)!);
    return GlassTheme(
      backgroundGradient: lerpList(backgroundGradient, other.backgroundGradient),
      orbs: lerpList(orbs, other.orbs),
      glassTint: Color.lerp(glassTint, other.glassTint, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassHighlight: Color.lerp(glassHighlight, other.glassHighlight, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onGlass: Color.lerp(onGlass, other.onGlass, t)!,
      onGlassMuted: Color.lerp(onGlassMuted, other.onGlassMuted, t)!,
      highlightAyah: Color.lerp(highlightAyah, other.highlightAyah, t)!,
      glassOpacity: glassOpacity + (other.glassOpacity - glassOpacity) * t,
    );
  }
}

class AppThemes {
  AppThemes._();

  static const Map<AppThemeType, GlassPalette> palettes = {
    AppThemeType.noirGold: GlassPalette(
      nameAr: 'أسود وذهبي',
      primary: Color(0xFFC9A44C),
      secondary: Color(0xFFE2C275),
      accent: Color(0xFFE2C275),
      lightAccent: Color(0xFFA8812F),
      lightGradient: [Color(0xFFFFFFFF), Color(0xFFFCFAF5), Color(0xFFF4EDDF)],
      darkGradient: [Color(0xFF000000), Color(0xFF080807), Color(0xFF121110)],
      orbs: [Color(0xFF4A3D1F), Color(0xFF2A2418), Color(0xFF5C4B26)],
    ),
    AppThemeType.emerald: GlassPalette(
      nameAr: 'زمردي ملكي',
      primary: Color(0xFF1E7A5A),
      secondary: Color(0xFF2E9C78),
      accent: Color(0xFFD8B46A),
      lightGradient: [Color(0xFFF4F1E6), Color(0xFFE2E9DB), Color(0xFFC5D7C2)],
      darkGradient: [Color(0xFF050F0B), Color(0xFF0A1C15), Color(0xFF113024)],
      orbs: [Color(0xFF1E7A5A), Color(0xFFD8B46A), Color(0xFF0F4D39)],
    ),
    AppThemeType.andalusian: GlassPalette(
      nameAr: 'عاجي كلاسيكي',
      primary: Color(0xFF7A5C3E),
      secondary: Color(0xFF9C7B57),
      accent: Color(0xFFA8865A),
      lightGradient: [Color(0xFFFBF7EF), Color(0xFFF2EADB), Color(0xFFE4D6BE)],
      darkGradient: [Color(0xFF111110), Color(0xFF191816), Color(0xFF23211E)],
      orbs: [Color(0xFF8C7458), Color(0xFFCDB894), Color(0xFF5E4A36)],
    ),
    AppThemeType.royalGold: GlassPalette(
      nameAr: 'فيروزي أندلسي',
      primary: Color(0xFF12807A),
      secondary: Color(0xFF2A9D96),
      accent: Color(0xFFD9C29A),
      lightGradient: [Color(0xFFF1F8F7), Color(0xFFD8ECE9), Color(0xFFB7DCD7)],
      darkGradient: [Color(0xFF041315), Color(0xFF072226), Color(0xFF0C3238)],
      orbs: [Color(0xFF0E6E69), Color(0xFF7FB8B2), Color(0xFF0A4E52)],
    ),
    AppThemeType.obsidian: GlassPalette(
      nameAr: 'كحلي ليلي',
      primary: Color(0xFF3B6EA8),
      secondary: Color(0xFF5B8CC4),
      accent: Color(0xFFD9B26B),
      lightGradient: [Color(0xFF060A12), Color(0xFF0B1424), Color(0xFF132138)],
      darkGradient: [Color(0xFF04070D), Color(0xFF09111F), Color(0xFF101C31)],
      orbs: [Color(0xFF1E3A5F), Color(0xFFD9B26B), Color(0xFF274B78)],
      alwaysDark: true,
    ),
  };

  /// The user's own three colours (primary, accent, background).
  static GlassPalette custom = customFrom(const Color(0xFFC9A44C), const Color(0xFFE2C275), const Color(0xFF000000));

  static GlassPalette customFrom(Color primary, Color accent, Color background) {
    final dark = background.computeLuminance() < 0.35;
    final grad = dark
        ? [Color.lerp(background, Colors.black, 0.35)!, background, Color.lerp(background, primary, 0.14)!]
        : [Color.lerp(background, Colors.white, 0.5)!, background, Color.lerp(background, primary, 0.10)!];
    return GlassPalette(
      nameAr: 'ألواني',
      primary: primary,
      secondary: Color.lerp(primary, accent, 0.4)!,
      accent: accent,
      lightAccent: accent.computeLuminance() > 0.55 ? Color.lerp(accent, Colors.black, 0.35) : null,
      lightGradient: grad,
      darkGradient: grad,
      orbs: [Color.lerp(primary, background, 0.55)!, Color.lerp(accent, background, 0.6)!, Color.lerp(primary, background, 0.7)!],
      alwaysDark: dark,
      alwaysLight: !dark,
    );
  }

  static GlassPalette palette(AppThemeType type) => type == AppThemeType.custom ? custom : palettes[type]!;

  static ThemeData build(AppThemeType type, Brightness requested) {
    final p = palette(type);
    final brightness = p.alwaysDark ? Brightness.dark : (p.alwaysLight ? Brightness.light : requested);
    final isDark = brightness == Brightness.dark;
    final accent = isDark ? p.accent : (p.lightAccent ?? p.accent);

    final scheme = ColorScheme.fromSeed(
      seedColor: p.primary,
      brightness: brightness,
      primary: isDark ? Color.lerp(p.primary, Colors.white, 0.25)! : p.primary,
      secondary: p.secondary,
      tertiary: accent,
    );

    final onGlass = isDark ? Colors.white : const Color(0xFF0E1B17);
    final glass = GlassTheme(
      backgroundGradient: isDark ? p.darkGradient : p.lightGradient,
      // Black & gold at night: a quiet aurora of gold, violet and emerald.
      orbs: isDark && type == AppThemeType.noirGold
          ? const [Color(0xFF4A3D1F), Color(0xFF2B1B52), Color(0xFF0E3F35)]
          : p.orbs,
      glassTint: Colors.white,
      glassBorder: Colors.white.withValues(alpha: isDark ? 0.18 : 0.55),
      glassHighlight: Colors.white.withValues(alpha: isDark ? 0.10 : 0.35),
      accent: accent,
      onGlass: onGlass,
      onGlassMuted: onGlass.withValues(alpha: 0.68),
      highlightAyah: accent.withValues(alpha: isDark ? 0.28 : 0.38),
      glassOpacity: isDark ? 0.08 : 0.28,
    );

    final base = ThemeData(
      useMaterial3: true,
      fontFamily: AppFonts.ui,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: glass.backgroundGradient.first,
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeSlidePageTransitionsBuilder(),
        TargetPlatform.iOS: FadeSlidePageTransitionsBuilder(),
      }),
    );

    final textTheme = base.textTheme.apply(
      fontFamily: AppFonts.ui,
      bodyColor: onGlass,
      displayColor: onGlass,
    );

    return base.copyWith(
      textTheme: textTheme,
      extensions: [glass],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: onGlass,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      iconTheme: IconThemeData(color: onGlass),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        thumbColor: accent,
        inactiveTrackColor: onGlass.withValues(alpha: 0.2),
        overlayColor: accent.withValues(alpha: 0.2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accent : null),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? accent.withValues(alpha: 0.45) : null),
      ),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.transparent, elevation: 0),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark
            ? Color.lerp(glass.backgroundGradient[1], Colors.black, 0.35)
            : Color.lerp(glass.backgroundGradient[1], Colors.white, 0.82),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: accent.withValues(alpha: 0.35)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color.lerp(p.primary, Colors.black, isDark ? 0.45 : 0.2),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
        actionTextColor: accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: accent.withValues(alpha: 0.5)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: isDark ? 0.06 : 0.35),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        hintStyle: TextStyle(color: onGlass.withValues(alpha: 0.5)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withValues(alpha: isDark ? 0.06 : 0.3),
        selectedColor: accent.withValues(alpha: 0.5),
        labelStyle: TextStyle(color: onGlass),
        side: BorderSide(color: glass.glassBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

/// Quranic font choices (served & cached by google_fonts).
enum QuranFont { amiriQuran, scheherazade, notoNaskh }

extension QuranFontX on QuranFont {
  String get labelAr => switch (this) {
        QuranFont.amiriQuran => 'خط مصحف المدينة (عثماني)',
        QuranFont.scheherazade => 'شهرزاد',
        QuranFont.notoNaskh => 'نسخ',
      };

  TextStyle style({required double fontSize, required double height, Color? color, FontWeight? weight}) {
    return switch (this) {
      QuranFont.amiriQuran =>
        TextStyle(
            fontFamily: 'UthmanicHafs', fontSize: fontSize, height: height, color: color, fontWeight: weight ?? FontWeight.w700),
      QuranFont.scheherazade =>
        GoogleFonts.scheherazadeNew(fontSize: fontSize, height: height, color: color, fontWeight: weight),
      QuranFont.notoNaskh =>
        GoogleFonts.notoNaskhArabic(fontSize: fontSize, height: height, color: color, fontWeight: weight),
    };
  }
}
