import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/data/surah_metadata.dart';
import '../../core/theme/app_themes.dart';
import '../../core/theme/tones.dart';
import '../../core/utils/arabic_utils.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/noor_ui.dart';
import '../../core/widgets/state_views.dart';
import '../quran/domain/entities/ayah.dart';
import '../quran/domain/repositories/quran_repository.dart';
import 'virtues_data.dart';

/// Each chapter of virtues has its own jewel tone (by its place in the list).
const _tones = <Tone>[
  Tone.emerald,
  Tone.gold,
  Tone.sapphire,
  Tone.amethyst,
  Tone.teal,
  Tone.coral,
  Tone.rose,
  Tone.amber,
  Tone.sky,
];

Tone _toneAt(int i) => _tones[i % _tones.length];

/// قسم الفضائل.
class VirtuesPage extends StatelessWidget {
  const VirtuesPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const VirtuesPage());

  @override
  Widget build(BuildContext context) {
    const cats = VirtuesData.categories;
    final total = cats.fold<int>(0, (a, c) => a + c.items.length);
    return GlassScaffold(
      title: 'الفضائل',
      subtitle: 'من الكتاب والسنة',
      tone: Tone.rose,
      icon: Icons.auto_awesome_rounded,
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        itemCount: cats.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) {
            return _SummaryCard(
              tone: Tone.rose,
              title: 'فضائل الأعمال',
              subtitle: 'آيات وأحاديث صحيحة في فضل الطاعات',
              stats: [(cats.length, 'الأبواب'), (total, 'النصوص')],
            );
          }
          if (i == 1) return const GlassSectionTitle('الأبواب', tone: Tone.rose);
          final index = i - 2;
          final c = cats[index];
          final tone = _toneAt(index);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CategoryTile(
              category: c,
              tone: tone,
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => _VirtueDetailPage(category: c, tone: tone))),
            ),
          );
        },
      ),
    );
  }
}

/// A chapter row: the chapter's coloured icon, title, subtitle and count.
class _CategoryTile extends StatelessWidget {
  final VirtueCategory category;
  final Tone tone;
  final VoidCallback onTap;

  const _CategoryTile({required this.category, required this.tone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ToneCard(
      tone: tone,
      radius: 22,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 10, 14),
      onTap: onTap,
      child: Row(
        children: [
          ToneIcon(category.icon, tone: tone, size: 50),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: glass.onGlass, height: 1.4),
                ),
                const SizedBox(height: 2),
                Text(
                  category.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: glass.onGlassMuted, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _TonePill(ArabicUtils.toArabicDigits(category.items.length), tone: tone),
          const SizedBox(width: 2),
          Icon(Icons.chevron_left_rounded, color: tone.ink(dark)),
        ],
      ),
    );
  }
}

class _VirtueDetailPage extends StatelessWidget {
  final VirtueCategory category;
  final Tone tone;

  const _VirtueDetailPage({required this.category, required this.tone});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: category.title,
      subtitle: category.subtitle,
      tone: tone,
      icon: category.icon,
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        itemCount: category.items.length,
        itemBuilder: (context, i) => _TextCard(
          text: category.items[i].text,
          source: category.items[i].source,
          quran: category.items[i].isQuran,
          tone: tone,
        ),
      ),
    );
  }
}

/// A reading card with a hadith/dua (or a verse in the Mushaf font): a tone
/// accent bar, a quiet quote mark, the source as a pill and round actions.
class _TextCard extends StatelessWidget {
  final String text;
  final String source;
  final bool quran;
  final String? repeat;
  final Tone tone;

  const _TextCard({required this.text, required this.source, required this.tone, this.quran = false, this.repeat});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ToneCard(
        tone: tone,
        radius: 22,
        ornament: quran,
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            PositionedDirectional(
              start: 0,
              top: 18,
              bottom: 18,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadiusDirectional.horizontal(end: Radius.circular(4)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [tone.light, tone.deep],
                  ),
                ),
              ),
            ),
            if (!quran)
              PositionedDirectional(
                top: 2,
                end: 10,
                child: IgnorePointer(
                  child: Icon(Icons.format_quote_rounded,
                      size: 48, color: tone.mid.withValues(alpha: dark ? 0.20 : 0.22)),
                ),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    quran ? '﴿$text﴾' : text,
                    textAlign: quran ? TextAlign.center : TextAlign.start,
                    style: quran
                        ? QuranFont.amiriQuran.style(fontSize: 22, height: 2.0, color: glass.onGlass)
                        : TextStyle(fontSize: 18, height: 1.95, color: glass.onGlass, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.centerStart,
                        end: AlignmentDirectional.centerEnd,
                        colors: [tone.mid.withValues(alpha: 0.5), tone.mid.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _TonePill(source,
                                tone: tone, icon: quran ? Icons.menu_book_rounded : Icons.verified_rounded),
                            if (repeat != null) _TonePill(repeat!, tone: tone, icon: Icons.repeat_rounded, filled: true),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RoundToneButton(
                        icon: Icons.copy_rounded,
                        tone: tone,
                        tooltip: 'نسخ',
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: '$text\n[$source]'));
                          showGlassSnack(context, 'تم النسخ');
                        },
                      ),
                      const SizedBox(width: 8),
                      _RoundToneButton(
                        icon: Icons.share_rounded,
                        tone: tone,
                        tooltip: 'مشاركة',
                        onTap: () => SharePlus.instance.share(ShareParams(text: '$text\n[$source]\n\n— تطبيق الهدى')),
                      ),
                    ],
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

/// Small rounded label in a tone (tinted, or [filled] with white text).
class _TonePill extends StatelessWidget {
  final String text;
  final Tone tone;
  final IconData? icon;
  final bool filled;

  const _TonePill(this.text, {required this.tone, this.icon, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = filled ? Colors.white : tone.ink(dark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: filled ? null : tone.mid.withValues(alpha: dark ? 0.16 : 0.12),
        gradient: filled ? tone.solid : null,
        border: Border.all(color: filled ? Colors.white.withValues(alpha: 0.16) : tone.mid.withValues(alpha: 0.35)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            if (icon != null)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: Icon(icon!, size: 13, color: fg),
                ),
              ),
            TextSpan(text: text),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg, height: 1.4),
      ),
    );
  }
}

/// Small round action button tinted with a tone (copy, share).
class _RoundToneButton extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundToneButton({required this.icon, required this.tone, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: tone.mid.withValues(alpha: dark ? 0.16 : 0.12),
        shape: CircleBorder(side: BorderSide(color: tone.mid.withValues(alpha: 0.4))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(dimension: 38, child: Icon(icon, size: 18, color: tone.ink(dark))),
        ),
      ),
    );
  }
}

/// Solid hero card at the top of a page: title, line and a few big numbers.
class _SummaryCard extends StatelessWidget {
  final Tone tone;
  final String title;
  final String subtitle;
  final List<(int, String)> stats;

  const _SummaryCard({required this.tone, required this.title, required this.subtitle, required this.stats});

  @override
  Widget build(BuildContext context) {
    return ToneCard(
      tone: tone,
      solid: true,
      ornament: true,
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.3),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 13, height: 1.5, color: Colors.white.withValues(alpha: 0.82))),
              ],
            ),
          ),
          for (final s in stats) ...[
            const SizedBox(width: 10),
            Container(
              width: 64,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withValues(alpha: 0.14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      ArabicUtils.toArabicDigits(s.$1),
                      style: const TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.2),
                    ),
                  ),
                  Text(
                    s.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Ruqyah ---

class _RuqyahVerses {
  final String title;
  final int surah;
  final int from;
  final int to;
  final int times;

  const _RuqyahVerses(this.title, this.surah, this.from, this.to, {this.times = 1});
}

class _RuqyahDua {
  final String text;
  final String source;
  final String? repeat;

  const _RuqyahDua(this.text, this.source, [this.repeat]);
}

const _verses = [
  _RuqyahVerses('سورة الفاتحة', 1, 1, 7),
  _RuqyahVerses('أول سورة البقرة', 2, 1, 5),
  _RuqyahVerses('آية الكرسي', 2, 255, 255),
  _RuqyahVerses('خواتيم سورة البقرة', 2, 285, 286),
  _RuqyahVerses('من سورة آل عمران', 3, 18, 19),
  _RuqyahVerses('من سورة الأعراف', 7, 117, 122),
  _RuqyahVerses('من سورة يونس', 10, 79, 82),
  _RuqyahVerses('من سورة طه', 20, 65, 69),
  _RuqyahVerses('خواتيم سورة المؤمنون', 23, 115, 118),
  _RuqyahVerses('أول سورة الصافات', 37, 1, 10),
  _RuqyahVerses('من سورة الرحمن', 55, 33, 36),
  _RuqyahVerses('خواتيم سورة الحشر', 59, 21, 24),
  _RuqyahVerses('سورة الإخلاص', 112, 1, 4, times: 3),
  _RuqyahVerses('سورة الفلق', 113, 1, 5, times: 3),
  _RuqyahVerses('سورة الناس', 114, 1, 6, times: 3),
];

const _duas = [
  _RuqyahDua(
      'اللَّهُمَّ رَبَّ النَّاسِ، أَذْهِبِ الْبَأْسَ، اشْفِ أَنْتَ الشَّافِي، لَا شِفَاءَ إِلَّا شِفَاؤُكَ، شِفَاءً لَا يُغَادِرُ سَقَمًا.',
      'متفق عليه'),
  _RuqyahDua('بِسْمِ اللَّهِ أَرْقِيكَ، مِنْ كُلِّ شَيْءٍ يُؤْذِيكَ، مِنْ شَرِّ كُلِّ نَفْسٍ أَوْ عَيْنِ حَاسِدٍ، اللَّهُ يَشْفِيكَ، بِسْمِ اللَّهِ أَرْقِيكَ.',
      'رواه مسلم'),
  _RuqyahDua('ضع يدك على موضع الألم وقل: بِسْمِ اللَّهِ (ثلاثًا)، ثم: أَعُوذُ بِاللَّهِ وَقُدْرَتِهِ مِنْ شَرِّ مَا أَجِدُ وَأُحَاذِرُ.',
      'رواه مسلم', '٧ مرات'),
  _RuqyahDua('أَسْأَلُ اللَّهَ الْعَظِيمَ، رَبَّ الْعَرْشِ الْعَظِيمِ، أَنْ يَشْفِيَكَ.', 'رواه أبو داود والترمذي', '٧ مرات'),
  _RuqyahDua('أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّةِ، مِنْ كُلِّ شَيْطَانٍ وَهَامَّةٍ، وَمِنْ كُلِّ عَيْنٍ لَامَّةٍ.', 'رواه البخاري'),
  _RuqyahDua('أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ.', 'رواه مسلم', '٣ مرات'),
  _RuqyahDua('بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ.',
      'رواه أبو داود والترمذي', '٣ مرات'),
];

/// قسم الرقية الشرعية: آيات الرقية من المصحف وأدعية الرقية من السنة.
class RuqyahPage extends StatefulWidget {
  const RuqyahPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const RuqyahPage());

  @override
  State<RuqyahPage> createState() => _RuqyahPageState();
}

class _RuqyahPageState extends State<RuqyahPage> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    final repo = context.read<QuranRepository>();
    if (!repo.isReady) repo.ensureLoaded().then((_) => mounted ? setState(() {}) : null);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<QuranRepository>();
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GlassScaffold(
      title: 'الرقية الشرعية',
      subtitle: 'آيات وأدعية الرقية من الكتاب والسنة',
      tone: Tone.sky,
      icon: Icons.healing_rounded,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: _SegmentedPill(
              tone: Tone.sky,
              value: _tab,
              items: const [
                (Icons.menu_book_rounded, 'من القرآن'),
                (Icons.format_quote_rounded, 'من السنة'),
              ],
              onChanged: (v) => setState(() => _tab = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.water_drop_rounded, size: 15, color: Tone.sky.ink(dark)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'تُقرأ بيقين وحضور قلب، مع النفث على موضع الألم أو في الماء، والله هو الشافي.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: glass.onGlassMuted, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _tab == 1
                ? ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: _duas.length,
                    itemBuilder: (context, i) => _TextCard(
                      text: _duas[i].text,
                      source: _duas[i].source,
                      repeat: _duas[i].repeat,
                      tone: Tone.sky,
                    ),
                  )
                : !repo.isReady
                    ? const LoadingView()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: _verses.length,
                        itemBuilder: (context, i) {
                          final v = _verses[i];
                          final ayahs = <Ayah>[
                            for (var n = v.from; n <= v.to; n++)
                              if (repo.ayahByNumber(SurahMetadata.globalAyah(v.surah, n)) case final a?) a,
                          ];
                          final text = ayahs
                              .map((a) => '${a.text}${ArabicUtils.ornateAyahMarker(a.numberInSurah)}')
                              .join(' ');
                          return _TextCard(
                            text: text,
                            source: v.title,
                            quran: true,
                            tone: Tone.emerald,
                            repeat: v.times > 1 ? '${ArabicUtils.toArabicDigits(v.times)} مرات' : null,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

/// A two-way switcher shaped as a pill: the chosen side fills with the tone.
class _SegmentedPill extends StatelessWidget {
  final Tone tone;
  final int value;
  final List<(IconData, String)> items;
  final ValueChanged<int> onChanged;

  const _SegmentedPill({required this.tone, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: noorSurface(context),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: tone.mid.withValues(alpha: dark ? 0.35 : 0.4)),
      ),
      child: Row(
        children: [
          for (final (i, item) in items.indexed)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == value,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    height: 44,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: i == value ? tone.solid : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.$1, size: 18, color: i == value ? Colors.white : tone.ink(dark)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            item.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: i == value ? FontWeight.w900 : FontWeight.w700,
                              color: i == value ? Colors.white : glass.onGlassMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
