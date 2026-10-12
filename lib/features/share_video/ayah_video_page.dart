import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants/app_constants.dart';
import '../../core/data/surah_metadata.dart';
import '../../core/theme/app_themes.dart';
import '../../core/theme/tones.dart';
import '../../core/utils/arabic_utils.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/state_views.dart';
import '../audio/data/audio_download_service.dart';
import '../audio/data/reciter_art.dart';
import '../audio/domain/reciter.dart';
import '../audio/presentation/widgets/mini_player.dart';
import '../quran/domain/repositories/quran_repository.dart';
import '../settings/presentation/cubit/settings_cubit.dart';
import 'ayah_video_service.dart';
import 'video_frames.dart';

/// «فيديو بصوت القارئ»: an ayah or a passage as a story video, the reciter's
/// voice with the words on screen, ready for WhatsApp, Instagram and Facebook.
class AyahVideoPage extends StatefulWidget {
  final int surah;
  final int from;
  final int to;

  const AyahVideoPage({super.key, this.surah = 1, this.from = 1, int? to}) : to = to ?? from;

  static Route<void> route({int surah = 1, int from = 1, int? to}) =>
      MaterialPageRoute(builder: (_) => AyahVideoPage(surah: surah, from: from, to: to ?? (surah == 1 ? 7 : from)));

  @override
  State<AyahVideoPage> createState() => _AyahVideoPageState();
}

class _AyahVideoPageState extends State<AyahVideoPage> {
  static const _tone = Tone.rose;
  static const _maxAyahs = 40;

  late int _surah = widget.surah;
  late int _from = widget.from;
  late int _to = widget.to;
  late String _reciterId = _initialReciter();
  String _bg = 'gold';
  ui.Image? _photo;
  String? _clipPath; // a video from the phone behind the words
  ui.Image? _clipThumb;
  VideoPlayerController? _clipPlayer;
  ui.Image? _logo;
  ui.Image? _reciterPhoto;
  String _previewText = '';

  VideoProgress? _progress;
  String? _video;
  Duration _length = Duration.zero;
  VideoPlayerController? _player;

  String _initialReciter() {
    final raw = context.read<SettingsCubit>().state.reciterId;
    return Reciters.all.any((r) => r.id == raw) ? raw : Reciters.all.first.id;
  }

  Reciter get _reciter => Reciters.byId(_reciterId);
  SurahInfo get _info => SurahMetadata.surah(_surah);

  @override
  void initState() {
    super.initState();
    AyahVideoService.loadAsset('assets/icon/logo_mark.png').then((i) => mounted ? setState(() => _logo = i) : null);
    _loadReciterPhoto();
    _loadPreview();
  }

  @override
  void dispose() {
    _player?.dispose();
    _clipPlayer?.dispose();
    super.dispose();
  }

  Future<void> _loadReciterPhoto() async {
    final key = ReciterArt.keyFor(_reciterId);
    final img = key == null ? null : await AyahVideoService.loadAsset('assets/reciters/$key.jpg');
    if (mounted) setState(() => _reciterPhoto = img);
  }

  Future<void> _loadPreview() async {
    final a = await context.read<QuranRepository>().getAyah(_surah, _from);
    if (mounted) setState(() => _previewText = a?.text ?? '');
  }

  bool get _isClip => _bg == VideoBackground.clip;

  VideoFramePainter get _painter => VideoFramePainter(
      bg: VideoBackground.byId(_bg), photo: _isClip ? _clipThumb : _photo, logo: _logo, reciterPhoto: _reciterPhoto);

  void _resetVideo() {
    _player?.dispose();
    _player = null;
    _video = null;
    // The chosen clip plays (silent) behind the preview again.
    if (_isClip) {
      _clipPlayer?.play();
    } else {
      _clipPlayer?.pause();
    }
  }

  Future<void> _pickSurah() async {
    final s = await showGlassSheet<int>(context, builder: (ctx) {
      return SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.7,
        child: Column(
          children: [
            Text('اختر السورة', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: 114,
                itemBuilder: (ctx, i) {
                  final info = SurahMetadata.surah(i + 1);
                  return ListTile(
                    leading: CircleAvatar(child: Text(ArabicUtils.toArabicDigits(i + 1))),
                    title: Text('سورة ${info.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${info.revelationAr} • ${ArabicUtils.toArabicDigits(info.ayahCount)} آية'),
                    selected: i + 1 == _surah,
                    onTap: () => Navigator.of(ctx).pop(i + 1),
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
    if (s == null || !mounted) return;
    setState(() {
      _surah = s;
      _from = 1;
      _to = SurahMetadata.surah(s).ayahCount.clamp(1, 7);
      _resetVideo();
    });
    _loadPreview();
  }

  Future<void> _pickReciter() async {
    final id = await showReciterPicker(context, _reciterId);
    if (id == null || !mounted) return;
    setState(() {
      _reciterId = id;
      _resetVideo();
    });
    _loadReciterPhoto();
  }

  Future<void> _pickPhoto() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = r?.files.single.path;
    if (path == null) return;
    final img = await AyahVideoService.loadFile(path);
    if (img == null || !mounted) return;
    setState(() {
      _photo = img;
      _bg = VideoBackground.custom;
      _resetVideo();
    });
  }

  Future<void> _pickClip() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.video);
    final path = r?.files.single.path;
    if (path == null || !mounted) return;
    final thumb = await AyahVideoService.clipThumbnail(path);
    if (!mounted) return;
    if (thumb == null) {
      showGlassSnack(context, 'تعذر قراءة هذا الفيديو، جرّب فيديو آخر');
      return;
    }
    VideoPlayerController? player = VideoPlayerController.file(File(path));
    try {
      await player.initialize();
      await player.setVolume(0);
      await player.setLooping(true);
    } catch (_) {
      // The preview then shows its first frame; the video is still made.
      await player.dispose();
      player = null;
    }
    if (!mounted) {
      player?.dispose();
      return;
    }
    _clipPlayer?.dispose();
    setState(() {
      _clipPath = path;
      _clipThumb = thumb;
      _clipPlayer = player;
      _bg = VideoBackground.clip;
      _resetVideo();
    });
  }

  Future<void> _build() async {
    if (_progress != null) return;
    setState(() {
      _resetVideo();
      _progress = const VideoProgress('بدء التجهيز', 0);
    });
    final service = AyahVideoService(
      dio: context.read<Dio>(),
      downloads: context.read<AudioDownloadService>(),
      quran: context.read<QuranRepository>(),
    );
    try {
      final (path, length) = await service.build(
        surah: _surah,
        from: _from,
        to: _to,
        reciter: _reciter,
        painter: _painter,
        clip: _isClip ? _clipPath : null,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      final player = VideoPlayerController.file(File(path));
      await player.initialize();
      await player.setLooping(true);
      if (!mounted) {
        player.dispose();
        return;
      }
      _clipPlayer?.pause();
      setState(() {
        _video = path;
        _length = length;
        _player = player;
      });
      // Watch it first, full screen; save or share from there or from below.
      await _watch();
    } catch (e) {
      if (mounted) {
        showGlassSnack(context, e is DioException ? 'تعذر تحميل التلاوة، تحقق من الاتصال' : 'تعذر إنشاء الفيديو على هذا الجهاز');
      }
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  /// The finished video full screen, before it is saved or shared.
  Future<void> _watch() async {
    final path = _video;
    if (path == null) return;
    await _player?.pause();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _VideoPreviewPage(path: path, onSave: _save, onShare: _share),
    ));
    if (mounted) setState(() {});
  }

  Future<void> _share(String? target) async {
    final path = _video;
    if (path == null) return;
    final text = AyahVideoService.shareText(_info.name, _from, _to, _reciter.nameAr);
    final ok = await AyahVideoService.share(path, target, text);
    if (!ok && mounted) {
      final app = switch (target) { 'whatsapp' => 'واتساب', 'instagram' => 'انستجرام', 'facebook' => 'فيسبوك', _ => '' };
      showGlassSnack(context, 'تطبيق $app غير مثبت، اختر من قائمة المشاركة');
      await AyahVideoService.share(path, null, text);
    }
  }

  Future<void> _save() async {
    final path = _video;
    if (path == null) return;
    final ok = await AyahVideoService.saveToGallery(path);
    if (!mounted) return;
    if (ok) {
      showGlassSnack(context, 'تم الحفظ في المعرض (Movies/الهدى)', icon: Icons.check_circle_rounded);
    } else {
      showGlassSnack(context, 'احفظه من قائمة المشاركة');
      await AyahVideoService.share(path, null, '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final busy = _progress != null;
    final count = _to - _from + 1;
    return GlassScaffold(
      title: 'فيديو بصوت القارئ',
      subtitle: 'شاركه ستوري أو في محادثة',
      icon: Icons.movie_creation_rounded,
      tone: _tone,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ------------------------------------------------ preview / video ---
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.55),
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: _player != null && _player!.value.isInitialized
                      ? GestureDetector(
                          onTap: () => setState(() => _player!.value.isPlaying ? _player!.pause() : _player!.play()),
                          child: Stack(fit: StackFit.expand, children: [
                            VideoPlayer(_player!),
                            if (!_player!.value.isPlaying)
                              const Center(child: Icon(Icons.play_circle_fill_rounded, size: 72, color: Colors.white70)),
                          ]),
                        )
                      : _framePreview(),
                ),
              ),
            ),
          ),
          if (busy) ...[
            const SizedBox(height: 16),
            Text(_progress!.label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: _progress!.value, minHeight: 8, color: _tone.mid),
            ),
          ],
          if (_video != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _tone.deep,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: _watch,
              icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
              label: const Text('شاهد الفيديو بملء الشاشة', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            const GlassSectionTitle('شارك الفيديو', tone: _tone),
            if (_length > const Duration(seconds: 60))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'مدة الفيديو ${ArabicUtils.formatDuration(_length)}: الستوري في واتساب وانستجرام يعرض دقيقة واحدة، فاختر آيات أقل للستوري.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Tone.amber.ink(dark), fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
              children: [
                _ShareTile('واتساب', 'حالة أو محادثة', Icons.chat_rounded, const Color(0xFF25D366), () => _share('whatsapp')),
                _ShareTile('انستجرام', 'ستوري أو ريلز', Icons.camera_alt_rounded, const Color(0xFFE1306C), () => _share('instagram')),
                _ShareTile('فيسبوك', 'ستوري أو منشور', Icons.facebook_rounded, const Color(0xFF1877F2), () => _share('facebook')),
                _ShareTile('تطبيق آخر', 'تيليجرام وغيره', Icons.ios_share_rounded, Tone.slate.deep, () => _share(null)),
                _ShareTile('حفظ', 'في المعرض', Icons.download_rounded, Tone.emerald.deep, _save),
                _ShareTile('فيديو جديد', 'غيّر واعمل تاني', Icons.refresh_rounded, _tone.deep, () => setState(_resetVideo)),
              ],
            ),
          ],

          // ------------------------------------------------------ options ---
          const GlassSectionTitle('الآيات', tone: _tone),
          ToneCard(
            tone: _tone,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled: !busy,
                  leading: const ToneIcon(Icons.menu_book_rounded, tone: _tone, size: 40),
                  title: Text('سورة ${_info.name}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${ArabicUtils.toArabicDigits(_info.ayahCount)} آية'),
                  trailing: const Icon(Icons.expand_more_rounded),
                  onTap: _pickSurah,
                ),
                Row(
                  children: [
                    Expanded(child: _AyahPicker(label: 'من الآية', value: _from, max: _info.ayahCount, enabled: !busy, onChanged: (v) {
                      setState(() {
                        _from = v;
                        if (_to < v) _to = v;
                        if (_to - _from + 1 > _maxAyahs) _to = _from + _maxAyahs - 1;
                        _resetVideo();
                      });
                      _loadPreview();
                    })),
                    const SizedBox(width: 10),
                    Expanded(child: _AyahPicker(label: 'إلى الآية', value: _to, max: _info.ayahCount, min: _from, enabled: !busy, onChanged: (v) {
                      setState(() {
                        _to = v.clamp(_from, _from + _maxAyahs - 1);
                        _resetVideo();
                      });
                    })),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  count == 1 ? 'آية واحدة' : '${ArabicUtils.toArabicDigits(count)} آيات (حتى ${ArabicUtils.toArabicDigits(_maxAyahs)} آية في الفيديو)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: glass.onGlass.withValues(alpha: 0.6), fontSize: 12.5),
                ),
              ],
            ),
          ),
          const GlassSectionTitle('القارئ', tone: _tone),
          ToneCard(
            tone: _tone,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            onTap: busy ? null : _pickReciter,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 24,
                backgroundImage: ReciterArt.keyFor(_reciterId) == null
                    ? null
                    : AssetImage('assets/reciters/${ReciterArt.keyFor(_reciterId)}.jpg'),
                child: ReciterArt.keyFor(_reciterId) == null ? const Icon(Icons.record_voice_over_rounded) : null,
              ),
              title: Text(_reciter.nameAr, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(_reciter.style),
              trailing: const Icon(Icons.expand_more_rounded),
            ),
          ),
          const GlassSectionTitle('الخلفية', tone: _tone),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: VideoBackground.all.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final b = VideoBackground.all[i];
                final selected = b.id == _bg;
                final isPhoto = b.id == VideoBackground.custom;
                final isClip = b.id == VideoBackground.clip;
                return GestureDetector(
                  onTap: busy
                      ? null
                      : () {
                          if (isPhoto) {
                            _pickPhoto();
                          } else if (isClip) {
                            _pickClip();
                          } else {
                            setState(() {
                              _bg = b.id;
                              _resetVideo();
                            });
                          }
                        },
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 62,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: selected ? glass.accent : Colors.transparent, width: 3),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: isPhoto && _photo == null
                              ? Container(color: Colors.black26, child: const Icon(Icons.add_photo_alternate_rounded))
                              : isClip && _clipThumb == null
                                  ? Container(color: Colors.black26, child: const Icon(Icons.video_library_rounded))
                                  : Stack(fit: StackFit.expand, children: [
                                      CustomPaint(
                                          painter: _SwatchPainter(
                                              VideoFramePainter(bg: b, photo: isClip ? _clipThumb : _photo, logo: _logo))),
                                      if (isClip)
                                        const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 26)),
                                    ]),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(b.name, style: TextStyle(fontSize: 11.5, fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _tone.deep,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            icon: busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.movie_filter_rounded),
            label: Text(busy ? 'جارٍ الإنشاء…' : 'إنشاء الفيديو',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            onPressed: busy ? null : _build,
          ),
          const SizedBox(height: 10),
          Text(
            'الفيديو بمقاس الستوري وفيه رابط التطبيق: ${AppConstants.shareUrl.replaceFirst('https://', '')}',
            textAlign: TextAlign.center,
            style: TextStyle(color: glass.onGlass.withValues(alpha: 0.55), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

extension on _AyahVideoPageState {
  /// The first frame as it will look; over a chosen clip, the clip plays under it.
  Widget _framePreview() {
    final content = FrameContent(
      text: _previewText,
      ayahNumber: _from,
      surahName: 'سورة ${_info.name}',
      reciterName: _reciter.nameAr,
      caption: 'الآية ${ArabicUtils.toArabicDigits(_from)}',
    );
    final clip = _clipPlayer;
    if (_isClip && clip != null && clip.value.isInitialized) {
      final p = _painter;
      return Stack(fit: StackFit.expand, children: [
        FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(width: clip.value.size.width, height: clip.value.size.height, child: VideoPlayer(clip)),
        ),
        CustomPaint(
          painter: _PreviewPainter(
              VideoFramePainter(bg: p.bg, photo: p.photo, logo: p.logo, reciterPhoto: p.reciterPhoto, overlayOnly: true), content),
        ),
      ]);
    }
    return CustomPaint(painter: _PreviewPainter(_painter, content));
  }
}

class _PreviewPainter extends CustomPainter {
  final VideoFramePainter painter;
  final FrameContent content;

  _PreviewPainter(this.painter, this.content);

  @override
  void paint(Canvas canvas, Size size) => painter.paintFrame(canvas, size, content);

  @override
  bool shouldRepaint(covariant _PreviewPainter old) => true;
}

class _SwatchPainter extends CustomPainter {
  final VideoFramePainter painter;

  _SwatchPainter(this.painter);

  @override
  void paint(Canvas canvas, Size size) => painter.paintOutro(canvas, size);

  @override
  bool shouldRepaint(covariant _SwatchPainter old) => true;
}

class _AyahPicker extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const _AyahPicker({required this.label, required this.value, required this.max, this.min = 1, required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: glass.onGlass.withValues(alpha: 0.06),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: glass.onGlass.withValues(alpha: 0.7))),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_rounded),
                onPressed: enabled && value < max ? () => onChanged(value + 1) : null,
              ),
              Text(ArabicUtils.toArabicDigits(value), style: const TextStyle(fontFamily: AppFonts.display, fontSize: 22)),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_rounded),
                onPressed: enabled && value > min ? () => onChanged(value - 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ShareTile(this.title, this.subtitle, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return Material(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(radius: 20, backgroundColor: color, child: Icon(icon, color: Colors.white, size: 22)),
              const SizedBox(height: 6),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: glass.onGlass.withValues(alpha: 0.6))),
            ],
          ),
        ),
      ),
    );
  }
}

/// The video full screen: play, pause, scrub, then save or share.
class _VideoPreviewPage extends StatefulWidget {
  final String path;
  final Future<void> Function() onSave;
  final Future<void> Function(String? target) onShare;

  const _VideoPreviewPage({required this.path, required this.onSave, required this.onShare});

  @override
  State<_VideoPreviewPage> createState() => _VideoPreviewPageState();
}

class _VideoPreviewPageState extends State<_VideoPreviewPage> {
  late final VideoPlayerController _c = VideoPlayerController.file(File(widget.path));

  @override
  void initState() {
    super.initState();
    _c.initialize().then((_) {
      if (!mounted) return;
      _c.addListener(_tick);
      _c.play();
      setState(() {});
    });
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_tick);
    _c.dispose();
    super.dispose();
  }

  String _t(Duration d) => ArabicUtils.toArabicDigits(
      '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}');

  @override
  Widget build(BuildContext context) {
    final v = _c.value;
    final done = v.isInitialized && !v.isPlaying && v.position >= v.duration - const Duration(milliseconds: 300);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('معاينة الفيديو', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: !v.isInitialized
                    ? const CircularProgressIndicator()
                    : GestureDetector(
                        onTap: () {
                          if (done) {
                            _c.seekTo(Duration.zero);
                            _c.play();
                          } else {
                            v.isPlaying ? _c.pause() : _c.play();
                          }
                        },
                        child: AspectRatio(
                          aspectRatio: v.aspectRatio,
                          child: Stack(fit: StackFit.expand, children: [
                            ClipRRect(borderRadius: BorderRadius.circular(16), child: VideoPlayer(_c)),
                            if (!v.isPlaying)
                              Center(
                                child: Icon(done ? Icons.replay_circle_filled_rounded : Icons.play_circle_fill_rounded,
                                    size: 84, color: Colors.white.withValues(alpha: 0.85)),
                              ),
                          ]),
                        ),
                      ),
              ),
            ),
            if (v.isInitialized)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Row(
                  children: [
                    Text(_t(v.position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: VideoProgressIndicator(
                          _c,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          colors: const VideoProgressColors(
                              playedColor: Color(0xFFE2C074), bufferedColor: Colors.white24, backgroundColor: Colors.white12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(_t(v.duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  _PreviewAction(Icons.chat_rounded, 'واتساب', const Color(0xFF25D366), () => widget.onShare('whatsapp')),
                  _PreviewAction(Icons.camera_alt_rounded, 'انستجرام', const Color(0xFFE1306C), () => widget.onShare('instagram')),
                  _PreviewAction(Icons.facebook_rounded, 'فيسبوك', const Color(0xFF1877F2), () => widget.onShare('facebook')),
                  _PreviewAction(Icons.ios_share_rounded, 'مشاركة', const Color(0xFF64748B), () => widget.onShare(null)),
                  _PreviewAction(Icons.download_rounded, 'حفظ', const Color(0xFF0E9F6E), widget.onSave),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PreviewAction(this.icon, this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                CircleAvatar(radius: 22, backgroundColor: color, child: Icon(icon, color: Colors.white)),
                const SizedBox(height: 6),
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
}
