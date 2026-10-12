import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_themes.dart';
import '../../core/theme/tones.dart';
import '../../core/utils/arabic_utils.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/noor_ui.dart';
import '../../core/widgets/state_views.dart';
import 'asma_data.dart';
import 'nawawi_data.dart';

// ------------------------------------------------------- أسماء الله الحسنى ---

class AsmaPage extends StatefulWidget {
  const AsmaPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const AsmaPage());

  @override
  State<AsmaPage> createState() => _AsmaPageState();
}

class _AsmaPageState extends State<AsmaPage> {
  static const _tone = Tone.gold;
  String _q = '';

  void _open(int i) {
    showGlassSheet<void>(context, builder: (ctx) {
      final (name, meaning) = kAsmaUlHusna[i];
      final dark = Theme.of(ctx).brightness == Brightness.dark;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ArabicUtils.toArabicDigits(i + 1), style: TextStyle(color: _tone.ink(dark), fontFamily: AppFonts.display)),
            const SizedBox(height: 6),
            Text(name, style: TextStyle(fontFamily: 'UthmanicHafs', fontSize: 52, height: 1.6, color: _tone.ink(dark))),
            const SizedBox(height: 10),
            Text(meaning, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, height: 1.8, fontWeight: FontWeight.w600)),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (i > 0)
                  IconButton.filledTonal(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _open(i - 1);
                    },
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: () => SharePlus.instance.share(ShareParams(text: '$name: $meaning\n\n— تطبيق الهدى ${AppConstants.shareUrl}')),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('مشاركة'),
                ),
                const SizedBox(width: 12),
                if (i < kAsmaUlHusna.length - 1)
                  IconButton.filledTonal(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _open(i + 1);
                    },
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      for (var i = 0; i < kAsmaUlHusna.length; i++)
        if (_q.isEmpty || ArabicUtils.normalize(kAsmaUlHusna[i].$1).contains(ArabicUtils.normalize(_q))) i,
    ];
    return GlassScaffold(
      title: 'أسماء الله الحسنى',
      subtitle: 'تسعة وتسعون اسمًا ومعانيها',
      icon: Icons.auto_awesome_rounded,
      tone: _tone,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          ToneCard(
            tone: _tone,
            ornament: true,
            padding: const EdgeInsets.all(16),
            child: Text(
              'قال رسول الله ﷺ: «إن لله تسعة وتسعين اسمًا، مائةً إلا واحدًا، من أحصاها دخل الجنة» متفق عليه',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.8, fontWeight: FontWeight.w700, color: _tone.ink(dark)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: 'ابحث عن اسم',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: glass.onGlass.withValues(alpha: 0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            ),
            onChanged: (v) => setState(() => _q = v.trim()),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, box) {
            final cols = box.maxWidth >= 640 ? 5 : 3;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
              children: [
                for (final i in items)
                  ToneCard(
                    tone: _tone,
                    padding: const EdgeInsets.all(6),
                    onTap: () => _open(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(ArabicUtils.toArabicDigits(i + 1), style: TextStyle(fontSize: 11, color: glass.onGlassMuted)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(kAsmaUlHusna[i].$1,
                              style: TextStyle(fontFamily: 'UthmanicHafs', fontSize: 28, height: 1.5, color: _tone.ink(dark))),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }),
          const SizedBox(height: 14),
          Text('الأسماء في رواية الترمذي، وفي تعيين بعضها خلاف بين العلماء، والمعاني مختصرة.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: glass.onGlassMuted)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------- الأربعون النووية ---

class NawawiPage extends StatelessWidget {
  const NawawiPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const NawawiPage());

  static const tone = Tone.emerald;

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final read = StorageService.asMap(context.read<StorageService>().settings.get('nawawi_read'));
    return GlassScaffold(
      title: 'الأربعون النووية',
      subtitle: 'جوامع الكلم من هدي النبي ﷺ',
      icon: Icons.menu_book_rounded,
      tone: tone,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          NoorCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < kNawawi.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 64, color: glass.onGlass.withValues(alpha: 0.08)),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: tone.mid.withValues(alpha: read[kNawawi[i].$1.toString()] == true ? 0.9 : 0.2),
                      child: read[kNawawi[i].$1.toString()] == true
                          ? const Icon(Icons.check_rounded, color: Colors.white)
                          : Text(ArabicUtils.toArabicDigits(kNawawi[i].$1), style: TextStyle(color: glass.onGlass)),
                    ),
                    title: Text(kNawawi[i].$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(kNawawi[i].$3, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: glass.onGlassMuted)),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _HadithPage(index: i))),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HadithPage extends StatefulWidget {
  final int index;

  const _HadithPage({required this.index});

  @override
  State<_HadithPage> createState() => _HadithPageState();
}

class _HadithPageState extends State<_HadithPage> {
  late int _i = widget.index;
  double _size = 21;

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  void _markRead() {
    final s = context.read<StorageService>().settings;
    final read = StorageService.asMap(s.get('nawawi_read'));
    read[kNawawi[_i].$1.toString()] = true;
    s.put('nawawi_read', read);
  }

  void _go(int i) {
    setState(() => _i = i);
    _markRead();
  }

  @override
  Widget build(BuildContext context) {
    final (n, title, text) = kNawawi[_i];
    final glass = GlassTheme.of(context);
    const tone = NawawiPage.tone;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GlassScaffold(
      title: 'الحديث ${ArabicUtils.toArabicDigits(n)}',
      subtitle: title,
      icon: Icons.menu_book_rounded,
      tone: tone,
      actions: [
        IconButton(
          tooltip: 'تصغير الخط',
          icon: const Icon(Icons.text_decrease_rounded),
          onPressed: () => setState(() => _size = (_size - 2).clamp(15, 34)),
        ),
        IconButton(
          tooltip: 'تكبير الخط',
          icon: const Icon(Icons.text_increase_rounded),
          onPressed: () => setState(() => _size = (_size + 2).clamp(15, 34)),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          ToneCard(
            tone: tone,
            ornament: true,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: AppFonts.display, fontSize: 22, color: tone.ink(dark))),
                const SizedBox(height: 14),
                SelectableText(text, textAlign: TextAlign.justify, style: TextStyle(fontSize: _size, height: 2.0)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: '$text\n\n(الأربعون النووية، الحديث $n)'));
                    if (context.mounted) showGlassSnack(context, 'تم نسخ الحديث');
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('نسخ'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: tone.deep),
                  onPressed: () => SharePlus.instance.share(
                      ShareParams(text: '$text\n\n(الأربعون النووية، الحديث $n)\n— تطبيق الهدى ${AppConstants.shareUrl}')),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('مشاركة'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (_i > 0)
                TextButton.icon(
                  onPressed: () => _go(_i - 1),
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: Text('الحديث ${ArabicUtils.toArabicDigits(kNawawi[_i - 1].$1)}'),
                ),
              const Spacer(),
              if (_i < kNawawi.length - 1)
                TextButton.icon(
                  onPressed: () => _go(_i + 1),
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: Text('الحديث ${ArabicUtils.toArabicDigits(kNawawi[_i + 1].$1)}'),
                ),
            ],
          ),
          Text('النص من مجموعة الأربعين النووية للإمام النووي رحمه الله.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: glass.onGlassMuted)),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- حاسبة الزكاة ---

class ZakatPage extends StatefulWidget {
  const ZakatPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const ZakatPage());

  @override
  State<ZakatPage> createState() => _ZakatPageState();
}

class _ZakatPageState extends State<ZakatPage> {
  static const _tone = Tone.amber;
  static const _nisabGrams = 85.0; // of pure (24k) gold

  late final StorageService _storage = context.read<StorageService>();
  late final Map<String, TextEditingController> _c = {
    for (final k in ['goldPrice', 'cash', 'gold24', 'gold21', 'gold18', 'silver', 'silverPrice', 'trade', 'receivable', 'debts'])
      k: TextEditingController(text: _saved(k)),
  };

  String _saved(String k) {
    final v = StorageService.asMap(_storage.settings.get('zakat'))[k];
    return v == null ? '' : '$v';
  }

  double _v(String k) => double.tryParse(ArabicUtils.toLatinDigits(_c[k]!.text.trim()).replaceAll(',', '')) ?? 0;

  void _save() {
    _storage.settings.put('zakat', {
      for (final e in _c.entries)
        if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
    });
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _money(double v) => ArabicUtils.toArabicDigits(v.toStringAsFixed(v >= 100 ? 0 : 2));

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final price = _v('goldPrice');
    final pureGold = _v('gold24') + _v('gold21') * 21 / 24 + _v('gold18') * 18 / 24;
    final total = _v('cash') + pureGold * price + _v('silver') * _v('silverPrice') + _v('trade') + _v('receivable') - _v('debts');
    final nisab = _nisabGrams * price;
    final due = price > 0 && total >= nisab;
    final zakat = due ? total * 0.025 : 0.0;

    Widget field(String k, String label, {String? hint}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: _c[k],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              filled: true,
              fillColor: glass.onGlass.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            onChanged: (_) {
              _save();
              setState(() {});
            },
          ),
        );

    return GlassScaffold(
      title: 'حاسبة الزكاة',
      subtitle: 'زكاة المال والذهب والفضة والتجارة',
      icon: Icons.calculate_rounded,
      tone: _tone,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          ToneCard(
            tone: _tone,
            ornament: true,
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Text(price <= 0 ? 'اكتب سعر جرام الذهب عيار ٢٤ أولًا' : (due ? 'الزكاة الواجبة' : 'لم يبلغ مالك النصاب'),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(due ? _money(zakat) : '—',
                    style: TextStyle(fontFamily: AppFonts.display, fontSize: 44, color: _tone.ink(dark))),
                if (price > 0)
                  Text(
                    'مجموع المال الزكوي ${_money(total)} • النصاب ${_money(nisab)} (قيمة ٨٥ جرامًا من الذهب عيار ٢٤)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: glass.onGlassMuted, height: 1.6),
                  ),
              ],
            ),
          ),
          const GlassSectionTitle('سعر الذهب اليوم', tone: _tone),
          field('goldPrice', 'سعر جرام الذهب عيار ٢٤', hint: 'بعملتك المحلية'),
          const GlassSectionTitle('أموالك', tone: _tone),
          field('cash', 'النقود والمدخرات والحسابات البنكية'),
          field('gold24', 'ذهب عيار ٢٤ (جرام)'),
          field('gold21', 'ذهب عيار ٢١ (جرام)'),
          field('gold18', 'ذهب عيار ١٨ (جرام)'),
          field('silver', 'فضة (جرام)'),
          field('silverPrice', 'سعر جرام الفضة'),
          field('trade', 'قيمة عروض التجارة (البضاعة المعدّة للبيع)'),
          field('receivable', 'ديون لك مرجوّة السداد'),
          const GlassSectionTitle('يُخصم', tone: _tone),
          field('debts', 'ديون عليك حالّة (مستحقة الآن)'),
          const SizedBox(height: 6),
          Text(
            'تجب الزكاة إذا بلغ المال النصاب وحال عليه الحول (سنة هجرية كاملة)، ومقدارها ربع العشر (٢٫٥٪). '
            'ذهب الزينة المستعمل فيه خلاف بين العلماء، والحاسبة للتقدير، فاسأل أهل العلم فيما أشكل عليك.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.8, color: glass.onGlassMuted),
          ),
        ],
      ),
    );
  }
}
