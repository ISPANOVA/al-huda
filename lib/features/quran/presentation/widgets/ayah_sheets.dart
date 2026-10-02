import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/data/surah_metadata.dart';
import '../../../../core/theme/app_themes.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../khatmah/presentation/cubit/khatmah_cubit.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/cubit/settings_state.dart';
import '../../domain/entities/ayah.dart';
import '../cubit/bookmarks_cubit.dart';
import '../pages/ayah_image_page.dart';
import 'listen_sheet.dart';

String _reference(Ayah a) =>
    'سورة ${SurahMetadata.surah(a.surah).name} • الآية ${ArabicUtils.toArabicDigits(a.numberInSurah)}';

/// Ayah sheet: the verse, its Tafseer Al-Muyassar, and quick actions.
Future<void> showAyahActions(BuildContext context, Ayah ayah) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => _AyahSheet(ayah: ayah, hostContext: context),
  );
}

/// Kept for callers that only want the Tafseer — it is part of the ayah sheet now.
Future<void> showTafseerSheet(BuildContext context, Ayah ayah) => showAyahActions(context, ayah);

class _AyahSheet extends StatelessWidget {
  final Ayah ayah;
  final BuildContext hostContext;

  const _AyahSheet({required this.ayah, required this.hostContext});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scroll) {
        return Container(
          decoration: BoxDecoration(
            color: sheetSurface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: glass.accent.withValues(alpha: 0.35), width: 1.2),
          ),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 5,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(color: glass.onGlass.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(4)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(_reference(ayah),
                          style: TextStyle(fontWeight: FontWeight.w800, color: glass.onGlass, fontSize: 13)),
                    ),
                    const Spacer(),
                    Text('صفحة ${ArabicUtils.toArabicDigits(ayah.page)}',
                        style: TextStyle(color: glass.onGlassMuted, fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                  children: [
                    Text(
                      '${ayah.text} ${ArabicUtils.ornateAyahMarker(ayah.numberInSurah)}',
                      textAlign: TextAlign.center,
                      style: QuranFont.amiriQuran.style(fontSize: 24, height: 2.0, color: glass.onGlass),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: glass.onGlass.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: glass.accent.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_stories_rounded, size: 18, color: glass.accent),
                              const SizedBox(width: 8),
                              Text('التفسير الميسر',
                                  style: TextStyle(fontWeight: FontWeight.w800, color: glass.accent)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            ayah.tafseer.isEmpty ? 'التفسير غير متوفر لهذه الآية.' : ayah.tafseer,
                            style: TextStyle(fontSize: 16, height: 1.85, color: glass.onGlass),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _ActionBar(ayah: ayah, hostContext: hostContext),
            ],
          ),
        );
      },
    );
  }
}

class _ActionBar extends StatelessWidget {
  final Ayah ayah;
  final BuildContext hostContext;

  const _ActionBar({required this.ayah, required this.hostContext});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final bookmarks = context.watch<BookmarksCubit>().state;
    final isBookmarked = bookmarks.isBookmarked(ayah.surah, ayah.numberInSurah);
    final isFavorite = bookmarks.isFavorite(ayah.surah, ayah.numberInSurah);
    final hasKhatmah = context.select<KhatmahCubit, bool>((c) => c.state.plan != null);
    void close() => Navigator.of(context).pop();

    final actions = <_ActionData>[
      _ActionData(Icons.play_arrow_rounded, 'استماع', false, () {
        close();
        showListenOptions(hostContext, ayah);
      }),
      _ActionData(isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_add_outlined, 'علامة', isBookmarked,
          () => context.read<BookmarksCubit>().toggleBookmark(ayah.surah, ayah.numberInSurah, text: ayah.text)),
      _ActionData(isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, 'مفضلة', isFavorite,
          () => context.read<BookmarksCubit>().toggleFavorite(ayah.surah, ayah.numberInSurah, text: ayah.text)),
      _ActionData(Icons.copy_rounded, 'نسخ', false, () async {
        await Clipboard.setData(ClipboardData(text: '${ayah.text} [${_reference(ayah)}]'));
        if (!context.mounted) return;
        close();
        showGlassSnack(hostContext, 'تم نسخ الآية');
      }),
      _ActionData(Icons.image_outlined, 'صورة', false, () {
        close();
        Navigator.of(hostContext).push(AyahImagePage.route(ayah));
      }),
      _ActionData(Icons.share_rounded, 'مشاركة', false, () {
        close();
        SharePlus.instance.share(ShareParams(
          text: '﴿${ayah.text}﴾\n[${_reference(ayah)}]\n\nالتفسير الميسر: ${ayah.tafseer}\n\n— تطبيق الهدى',
        ));
      }),
      if (hasKhatmah)
        _ActionData(Icons.flag_rounded, 'الختمة', false, () {
          context.read<KhatmahCubit>().setProgress(ayah.number);
          close();
          showGlassSnack(hostContext, 'تم تحديث تقدم الختمة حتى هذه الآية');
        }),
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(8, 10, 8, 10 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: glass.onGlass.withValues(alpha: 0.08))),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        spacing: 4,
        runSpacing: 8,
        children: [for (final a in actions) SizedBox(width: 62, child: _ActionButton(data: a))],
      ),
    );
  }
}

class _ActionData {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ActionData(this.icon, this.label, this.active, this.onTap);
}

class _ActionButton extends StatelessWidget {
  final _ActionData data;

  const _ActionButton({required this.data});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: data.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: data.active ? primary : primary.withValues(alpha: 0.14),
              ),
              child: Icon(data.icon, size: 22, color: data.active ? Colors.white : glass.onGlass),
            ),
            const SizedBox(height: 4),
            Text(data.label, style: TextStyle(fontSize: 11.5, color: glass.onGlassMuted, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Reading preferences for the Mushaf.
Future<void> showReaderSettingsSheet(BuildContext context) {
  return showGlassSheet<void>(context, builder: (ctx) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (ctx, s) {
        final cubit = ctx.read<SettingsCubit>();
        final glass = GlassTheme.of(ctx);
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('إعدادات القراءة', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تقليب الصفحات تلقائيًا مع التلاوة'),
                value: s.autoFollowAudio,
                onChanged: cubit.setAutoFollowAudio,
              ),
              const SizedBox(height: 4),
              Text(
                'اضغط مطولًا على أي آية لعرض تفسيرها وخيارات الاستماع والمشاركة، واضغط ضغطة عادية في أي مكان لإخفاء الأدوات أو إظهارها.',
                style: TextStyle(fontSize: 12.5, color: glass.onGlassMuted),
              ),
            ],
          ),
        );
      },
    );
  });
}
