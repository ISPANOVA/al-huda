import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_themes.dart';
import '../../core/theme/tones.dart';
import '../../core/utils/arabic_utils.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/state_views.dart';
import 'duas_data.dart';

const _tones = <Tone>[
  Tone.sapphire,
  Tone.sky,
  Tone.teal,
  Tone.amber,
  Tone.gold,
  Tone.coral,
  Tone.rose,
  Tone.emerald,
  Tone.amethyst,
];

/// Each category of supplications has its own jewel tone (by meaning, and by
/// its place in the list for any new category).
Tone _toneFor(DuaCategory c, int i) => switch (c.id) {
      'distress' => Tone.sapphire,
      'travel' => Tone.sky,
      'sick' => Tone.teal,
      'istikhara' => Tone.amber,
      'home' => Tone.gold,
      'food' => Tone.coral,
      'parents' => Tone.rose,
      'quran' => Tone.emerald,
      'forgive' => Tone.amethyst,
      _ => _tones[i % _tones.length],
    };

/// الأدعية — categories grid, then each category's supplications.
class DuasPage extends StatelessWidget {
  const DuasPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const DuasPage());

  @override
  Widget build(BuildContext context) {
    const cats = kDuaCategories;
    final total = cats.fold<int>(0, (a, c) => a + c.items.length);
    return GlassScaffold(
      title: 'الأدعية',
      subtitle: 'أدعية مأثورة بمصادرها',
      tone: Tone.amethyst,
      icon: Icons.back_hand_rounded,
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _SummaryCard(
                tone: Tone.amethyst,
                title: 'دعاء لكل حال',
                subtitle: 'من الكتاب والسنة الصحيحة',
                stats: [(cats.length, 'الأبواب'), (total, 'الأدعية')],
              ),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: GlassSectionTitle('الأبواب', tone: Tone.amethyst)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisExtent: 142,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final c = cats[i];
                  final tone = _toneFor(c, i);
                  return _CategoryTile(
                    category: c,
                    tone: tone,
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => _DuaListPage(category: c, tone: tone))),
                  );
                },
                childCount: cats.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final DuaCategory category;
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
      ornament: true,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ToneIcon(category.icon, tone: tone, size: 46),
          const Spacer(),
          Text(
            category.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, color: glass.onGlass, height: 1.4),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _TonePill('${ArabicUtils.toArabicDigits(category.items.length)} أدعية', tone: tone),
              const Spacer(),
              Icon(Icons.chevron_left_rounded, size: 20, color: tone.ink(dark)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DuaListPage extends StatelessWidget {
  final DuaCategory category;
  final Tone tone;

  const _DuaListPage({required this.category, required this.tone});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: category.title,
      subtitle: '${ArabicUtils.toArabicDigits(category.items.length)} أدعية',
      tone: tone,
      icon: category.icon,
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: category.items.length,
        itemBuilder: (context, i) => _DuaCard(dua: category.items[i], tone: tone),
      ),
    );
  }
}

/// A reading card for one supplication: tone accent bar, quiet quote mark,
/// the occasion on top, the source as a pill and round copy / share buttons.
class _DuaCard extends StatelessWidget {
  final Dua dua;
  final Tone tone;

  const _DuaCard({required this.dua, required this.tone});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final d = dua;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ToneCard(
        tone: tone,
        radius: 22,
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
            PositionedDirectional(
              top: 2,
              end: 10,
              child: IgnorePointer(
                child: Icon(Icons.format_quote_rounded, size: 48, color: tone.mid.withValues(alpha: dark ? 0.20 : 0.22)),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (d.note != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: 8, end: 40),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsetsDirectional.only(end: 6),
                                child: Icon(Icons.bookmark_rounded, size: 15, color: tone.ink(dark)),
                              ),
                            ),
                            TextSpan(text: d.note),
                          ],
                        ),
                        style: TextStyle(color: tone.ink(dark), fontWeight: FontWeight.w800, fontSize: 13, height: 1.5),
                      ),
                    ),
                  Text(d.text,
                      style: TextStyle(fontSize: 19, height: 2.0, fontWeight: FontWeight.w600, color: glass.onGlass)),
                  const SizedBox(height: 12),
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
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _TonePill(d.source, tone: tone, icon: Icons.verified_rounded),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RoundToneButton(
                        icon: Icons.copy_rounded,
                        tone: tone,
                        tooltip: 'نسخ',
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: '${d.text}\n[${d.source}]'));
                          if (context.mounted) showGlassSnack(context, 'تم نسخ الدعاء');
                        },
                      ),
                      const SizedBox(width: 8),
                      _RoundToneButton(
                        icon: Icons.share_rounded,
                        tone: tone,
                        tooltip: 'مشاركة',
                        onTap: () =>
                            SharePlus.instance.share(ShareParams(text: '${d.text}\n[${d.source}]\n\n— تطبيق الهدى')),
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

/// Small rounded label tinted with a tone.
class _TonePill extends StatelessWidget {
  final String text;
  final Tone tone;
  final IconData? icon;

  const _TonePill(this.text, {required this.tone, this.icon});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = tone.ink(dark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: tone.mid.withValues(alpha: dark ? 0.16 : 0.12),
        border: Border.all(color: tone.mid.withValues(alpha: 0.35)),
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

/// Solid hero card at the top of the page: title, line and big numbers.
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
