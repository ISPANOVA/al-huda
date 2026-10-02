import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/data/surah_metadata.dart';
import '../../core/theme/app_themes.dart';
import '../../core/utils/arabic_utils.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/state_views.dart';
import '../quran/domain/entities/ayah.dart';
import '../quran/domain/repositories/quran_repository.dart';
import 'virtues_data.dart';

/// قسم الفضائل.
class VirtuesPage extends StatelessWidget {
  const VirtuesPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const VirtuesPage());

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return GlassScaffold(
      title: 'الفضائل',
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: VirtuesData.categories.length,
        itemBuilder: (context, i) {
          final c = VirtuesData.categories[i];
          return GlassContainer(
            blur: 0,
            margin: const EdgeInsets.only(bottom: 12),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _VirtueDetailPage(category: c))),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(colors: [glass.accent, primary]),
                  ),
                  child: Icon(c.icon, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(c.subtitle, style: TextStyle(fontSize: 13, color: glass.onGlassMuted)),
                    ],
                  ),
                ),
                Text(ArabicUtils.toArabicDigits(c.items.length),
                    style: TextStyle(fontWeight: FontWeight.w800, color: glass.accent)),
                const SizedBox(width: 4),
                Icon(Icons.chevron_left_rounded, color: glass.onGlassMuted),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _VirtueDetailPage extends StatelessWidget {
  final VirtueCategory category;

  const _VirtueDetailPage({required this.category});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: category.title,
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: category.items.length,
        itemBuilder: (context, i) => _TextCard(
          text: category.items[i].text,
          source: category.items[i].source,
          quran: category.items[i].isQuran,
        ),
      ),
    );
  }
}

/// A card with a hadith/dua (or a verse in the Mushaf font) and its source.
class _TextCard extends StatelessWidget {
  final String text;
  final String source;
  final bool quran;
  final String? repeat;

  const _TextCard({required this.text, required this.source, this.quran = false, this.repeat});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return GlassContainer(
      blur: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            quran ? '﴿$text﴾' : text,
            textAlign: quran ? TextAlign.center : TextAlign.start,
            style: quran
                ? QuranFont.amiriQuran.style(fontSize: 22, height: 2.0, color: glass.onGlass)
                : TextStyle(fontSize: 17, height: 1.9, color: glass.onGlass, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: glass.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(source, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: glass.accent)),
              ),
              if (repeat != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(repeat!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: glass.onGlass)),
                ),
              ],
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.copy_rounded, size: 20, color: glass.onGlassMuted),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: '$text\n[$source]'));
                  showGlassSnack(context, 'تم النسخ');
                },
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.share_rounded, size: 20, color: glass.onGlassMuted),
                onPressed: () => SharePlus.instance.share(ShareParams(text: '$text\n[$source]\n\n— تطبيق الهدى')),
              ),
            ],
          ),
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
    return GlassScaffold(
      title: 'الرقية الشرعية',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('من القرآن')),
                ButtonSegment(value: 1, label: Text('من السنة')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'تُقرأ بيقين وحضور قلب، مع النفث على موضع الألم أو في الماء، والله هو الشافي.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: glass.onGlassMuted),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _tab == 1
                ? ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: _duas.length,
                    itemBuilder: (context, i) =>
                        _TextCard(text: _duas[i].text, source: _duas[i].source, repeat: _duas[i].repeat),
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
