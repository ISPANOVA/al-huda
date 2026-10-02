import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/data/surah_metadata.dart';
import '../../core/theme/app_themes.dart';
import '../../core/utils/arabic_utils.dart';
import '../../core/widgets/gradient_background.dart';
import '../audio/presentation/cubit/audio_cubit.dart';
import '../audio/presentation/cubit/audio_state.dart';
import '../audio/presentation/pages/downloads_page.dart';
import 'media_catalog.dart';
import 'media_downloads.dart';
import 'media_widgets.dart';
import 'reciter_pages.dart';

/// Offline library: every downloaded surah grouped by reciter.
class MediaDownloadsPage extends StatefulWidget {
  const MediaDownloadsPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const MediaDownloadsPage());

  @override
  State<MediaDownloadsPage> createState() => _MediaDownloadsPageState();
}

class _MediaDownloadsPageState extends State<MediaDownloadsPage> {
  late Future<int> _bytes = MediaDownloads.instance.totalBytes();

  String _size(int b) {
    if (b < 1024 * 1024) return '${ArabicUtils.toArabicDigits((b / 1024).round())} ك.ب';
    final mb = b / (1024 * 1024);
    return mb < 1024
        ? '${ArabicUtils.toArabicDigits(mb.round())} م.ب'
        : '${ArabicUtils.toArabicDigits((mb / 1024).toStringAsFixed(1))} ج.ب';
  }

  Future<void> _delete(MediaReciter r, int s) async {
    await MediaDownloads.instance.delete(r, s);
    setState(() => _bytes = MediaDownloads.instance.totalBytes());
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return GlassScaffold(
      title: 'تنزيلاتي',
      body: ListenableBuilder(
        listenable: MediaDownloads.instance,
        builder: (context, _) {
          final dl = MediaDownloads.instance;
          final reciters = dl.reciters;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            physics: const BouncingScrollPhysics(),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: LinearGradient(
                    colors: [glass.accent.withValues(alpha: 0.22), glass.accent.withValues(alpha: 0.05)],
                  ),
                  border: Border.all(color: glass.accent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.library_music_rounded, color: glass.accent, size: 40),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${ArabicUtils.toArabicDigits(dl.totalCount)} سورة محفوظة',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          FutureBuilder<int>(
                            future: _bytes,
                            builder: (context, snap) => Text(
                              snap.hasData ? 'المساحة المستخدمة: ${_size(snap.data!)}' : 'جارٍ الحساب…',
                              style: TextStyle(color: glass.onGlassMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (reciters.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.cloud_download_outlined, size: 64, color: glass.onGlassMuted),
                      const SizedBox(height: 12),
                      const Text('لا توجد تنزيلات بعد', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('افتح أي قارئ واضغط زر التنزيل بجانب السورة',
                          textAlign: TextAlign.center, style: TextStyle(color: glass.onGlassMuted)),
                    ],
                  ),
                ),
              for (final r in reciters)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ReciterGroup(reciter: r, surahs: dl.surahsFor(r), onDelete: (s) => _delete(r, s)),
                ),
              const SizedBox(height: 6),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: glass.onGlass.withValues(alpha: 0.1)),
                ),
                leading: Icon(Icons.menu_book_rounded, color: glass.accent),
                title: const Text('تنزيلات آيات المصحف', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('التلاوة آية بآية المستخدمة في المصحف والحفظ'),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => Navigator.of(context).push(DownloadsPage.route()),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReciterGroup extends StatelessWidget {
  final MediaReciter reciter;
  final List<int> surahs;
  final ValueChanged<int> onDelete;

  const _ReciterGroup({required this.reciter, required this.surahs, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: glass.onGlass.withValues(alpha: 0.05),
        border: Border.all(color: glass.onGlass.withValues(alpha: 0.08)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: MonogramAvatar(name: reciter.name, seed: reciter.key.replaceAll('_mj', ''), size: 48, ring: false),
          title: Text(reciter.name, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text('${reciter.style} • ${ArabicUtils.toArabicDigits(surahs.length)} سورة',
              style: TextStyle(color: glass.onGlassMuted, fontSize: 12.5)),
          children: [
            BlocBuilder<AudioCubit, AudioState>(
              buildWhen: (p, c) => p.surah != c.surah || p.playing != c.playing || p.reciterId != c.reciterId,
              builder: (context, audio) => Column(
                children: [
                  for (final s in surahs)
                    ListTile(
                      dense: true,
                      leading: audio.hasQueue && audio.reciterId == reciter.id && audio.surah == s
                          ? Equalizer(playing: audio.playing, color: glass.accent, size: 20)
                          : StarNumber(number: s, color: glass.accent, size: 34),
                      title: Text('سورة ${SurahMetadata.surah(s).name}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      onTap: () => playMediaSurah(context, reciter, s),
                      trailing: IconButton(
                        tooltip: 'حذف',
                        icon: Icon(Icons.delete_outline_rounded, color: glass.onGlassMuted),
                        onPressed: () => onDelete(s),
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
