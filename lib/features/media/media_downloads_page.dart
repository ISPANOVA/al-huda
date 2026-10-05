import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/data/surah_metadata.dart';
import '../../core/theme/app_themes.dart';
import '../../core/theme/tones.dart';
import '../../core/utils/arabic_utils.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/noor_ui.dart';
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
    const tone = Tone.amethyst;
    return GlassScaffold(
      title: 'تنزيلاتي',
      subtitle: 'السور المحفوظة للاستماع دون إنترنت',
      icon: Icons.download_done_rounded,
      tone: tone,
      body: ListenableBuilder(
        listenable: MediaDownloads.instance,
        builder: (context, _) {
          final dl = MediaDownloads.instance;
          final reciters = dl.reciters;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            physics: const BouncingScrollPhysics(),
            children: [
              // ---------------------------------------------------- hero ---
              ToneCard(
                tone: tone,
                solid: true,
                ornament: true,
                radius: 26,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('مكتبتك دون إنترنت',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800)),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(ArabicUtils.toArabicDigits(dl.totalCount),
                                  style: const TextStyle(
                                      fontFamily: AppFonts.display,
                                      fontSize: 40,
                                      fontWeight: FontWeight.w700,
                                      height: 1.3,
                                      color: Colors.white)),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text('سورة محفوظة',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _HeroPill(
                                icon: Icons.record_voice_over_rounded,
                                child: Text('${ArabicUtils.toArabicDigits(reciters.length)} قارئ'),
                              ),
                              _HeroPill(
                                icon: Icons.sd_storage_rounded,
                                child: FutureBuilder<int>(
                                  future: _bytes,
                                  builder: (context, snap) => Text(
                                    snap.hasData ? 'المساحة المستخدمة: ${_size(snap.data!)}' : 'جارٍ الحساب…',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: const Icon(Icons.library_music_rounded, color: Colors.white, size: 32),
                    ),
                  ],
                ),
              ),

              // ------------------------------------------------- reciters ---
              if (reciters.isEmpty) ...[
                const SizedBox(height: 14),
                ToneCard(
                  tone: tone,
                  radius: 26,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                    children: [
                      SizedBox.square(
                        dimension: 132,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [tone.mid.withValues(alpha: 0.38), tone.mid.withValues(alpha: 0)],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox.square(
                              dimension: 108,
                              child: CustomPaint(painter: KhatamPainter(tone.mid.withValues(alpha: 0.45))),
                            ),
                            const ToneIcon(Icons.cloud_download_rounded, tone: tone, size: 62),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('لا توجد تنزيلات بعد',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: AppFonts.display,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: glass.onGlass)),
                      const SizedBox(height: 6),
                      Text('افتح أي قارئ واضغط زر التنزيل بجانب السورة',
                          textAlign: TextAlign.center, style: TextStyle(color: glass.onGlassMuted, height: 1.5)),
                    ],
                  ),
                ),
              ] else ...[
                GlassSectionTitle(
                  'حسب القارئ',
                  tone: tone,
                  trailing: Text('${ArabicUtils.toArabicDigits(reciters.length)} قارئ',
                      style: TextStyle(fontSize: 12.5, color: glass.onGlassMuted)),
                ),
                for (final r in reciters)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ReciterGroup(reciter: r, surahs: dl.surahsFor(r), onDelete: (s) => _delete(r, s)),
                  ),
              ],

              // ---------------------------------------------------- more ---
              const GlassSectionTitle('تنزيلات أخرى', tone: Tone.emerald),
              ToneCard(
                tone: Tone.emerald,
                radius: 22,
                padding: const EdgeInsets.all(14),
                onTap: () => Navigator.of(context).push(DownloadsPage.route()),
                child: Row(
                  children: [
                    const ToneIcon(Icons.menu_book_rounded, tone: Tone.emerald, size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('تنزيلات آيات المصحف',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                          Text('التلاوة آية بآية المستخدمة في المصحف والحفظ',
                              style: TextStyle(fontSize: 12.5, color: glass.onGlassMuted)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_left_rounded, color: glass.onGlassMuted),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Small translucent pill on the solid hero card.
class _HeroPill extends StatelessWidget {
  final IconData icon;
  final Widget child;

  const _HeroPill({required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 12, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: DefaultTextStyle.merge(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              child: child,
            ),
          ),
        ],
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
    const tone = Tone.amethyst;
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = tone.ink(dark);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: noorSurface(context),
        border: Border.all(color: tone.mid.withValues(alpha: dark ? 0.28 : 0.32)),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: tone.wash(dark)),
        child: Material(
          type: MaterialType.transparency,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: true,
              iconColor: ink,
              collapsedIconColor: glass.onGlassMuted,
              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: MonogramAvatar(name: reciter.name, seed: reciter.key.replaceAll('_mj', ''), size: 48, ring: false),
              title: Text(reciter.name, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(reciter.style,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: glass.onGlassMuted, fontSize: 12.5)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: tone.mid.withValues(alpha: dark ? 0.20 : 0.14),
                      ),
                      child: Text('${ArabicUtils.toArabicDigits(surahs.length)} سورة',
                          style: TextStyle(color: ink, fontSize: 11.5, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              children: [
                Divider(height: 1, indent: 16, endIndent: 16, color: glass.onGlass.withValues(alpha: 0.08)),
                BlocBuilder<AudioCubit, AudioState>(
                  buildWhen: (p, c) => p.surah != c.surah || p.playing != c.playing || p.reciterId != c.reciterId,
                  builder: (context, audio) => Column(
                    children: [
                      for (final s in surahs)
                        ListTile(
                          dense: true,
                          leading: audio.hasQueue && audio.reciterId == reciter.id && audio.surah == s
                              ? Equalizer(playing: audio.playing, color: ink, size: 20)
                              : StarNumber(number: s, color: ink, size: 34),
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
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
