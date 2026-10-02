import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_themes.dart';
import '../../core/utils/arabic_utils.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/state_views.dart';
import 'duas_data.dart';

/// الأدعية — categories grid, then each category's supplications.
class DuasPage extends StatelessWidget {
  const DuasPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const DuasPage());

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return GlassScaffold(
      title: 'الأدعية',
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: kDuaCategories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.45,
        ),
        itemBuilder: (context, i) {
          final c = kDuaCategories[i];
          return GlassContainer(
            padding: const EdgeInsets.all(14),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _DuaListPage(category: c))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: glass.accent.withValues(alpha: 0.15),
                  ),
                  child: Icon(c.icon, color: glass.accent),
                ),
                const Spacer(),
                Text(c.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
                Text('${ArabicUtils.toArabicDigits(c.items.length)} أدعية',
                    style: TextStyle(fontSize: 12, color: glass.onGlassMuted)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DuaListPage extends StatelessWidget {
  final DuaCategory category;

  const _DuaListPage({required this.category});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return GlassScaffold(
      title: category.title,
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: category.items.length,
        itemBuilder: (context, i) {
          final d = category.items[i];
          return GlassContainer(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(16, 16, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (d.note != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(d.note!,
                        style: TextStyle(color: glass.accent, fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                Text(d.text,
                    style: TextStyle(fontSize: 19, height: 2.0, fontWeight: FontWeight.w600, color: glass.onGlass)),
                Row(
                  children: [
                    Expanded(child: Text(d.source, style: TextStyle(fontSize: 12, color: glass.onGlassMuted))),
                    IconButton(
                      tooltip: 'نسخ',
                      icon: Icon(Icons.copy_rounded, size: 20, color: glass.onGlassMuted),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: '${d.text}\n[${d.source}]'));
                        if (context.mounted) showGlassSnack(context, 'تم نسخ الدعاء');
                      },
                    ),
                    IconButton(
                      tooltip: 'مشاركة',
                      icon: Icon(Icons.share_rounded, size: 20, color: glass.onGlassMuted),
                      onPressed: () => SharePlus.instance.share(ShareParams(text: '${d.text}\n[${d.source}]\n\n— تطبيق الهدى')),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
