import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import '../../core/widgets/state_views.dart';
import '../audio/presentation/cubit/audio_cubit.dart';
import 'media_widgets.dart';

/// Full-screen-capable HLS player for the live Haram channels.
class LiveStreamPage extends StatefulWidget {
  final String title;
  final List<String> urls;

  const LiveStreamPage({super.key, required this.title, required this.urls});

  static Route<void> route(String title, List<String> urls) =>
      MaterialPageRoute(builder: (_) => LiveStreamPage(title: title, urls: urls));

  @override
  State<LiveStreamPage> createState() => _LiveStreamPageState();
}

class _LiveStreamPageState extends State<LiveStreamPage> {
  VideoPlayerController? _controller;
  bool _failed = false;
  bool _fullscreen = false;

  @override
  void initState() {
    super.initState();
    final audio = context.read<AudioCubit>();
    if (audio.state.playing) audio.togglePlay();
    _start();
  }

  Future<void> _start() async {
    setState(() => _failed = false);
    for (final url in widget.urls) {
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      try {
        await c.initialize().timeout(const Duration(seconds: 15));
        if (!mounted) {
          await c.dispose();
          return;
        }
        await c.play();
        setState(() => _controller = c);
        return;
      } catch (_) {
        await c.dispose();
      }
    }
    if (mounted) setState(() => _failed = true);
  }

  Future<void> _toggleFullscreen() async {
    _fullscreen = !_fullscreen;
    if (_fullscreen) {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    if (_fullscreen) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final Widget video = _failed
        ? MessageView(
            icon: Icons.wifi_off_rounded,
            title: 'تعذر تشغيل البث الآن',
            subtitle: 'تأكد من اتصالك بالإنترنت ثم أعد المحاولة.',
            actionLabel: 'إعادة المحاولة',
            onAction: _start,
          )
        : c == null
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Center(
                child: AspectRatio(
                  aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
                  child: VideoPlayer(c),
                ),
              );
    return PopScope(
      canPop: !_fullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _toggleFullscreen();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _fullscreen
            ? null
            : AppBar(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                title: Text('مباشر من ${widget.title}'),
                actions: const [Padding(padding: EdgeInsetsDirectional.only(end: 14), child: Center(child: LiveBadge()))],
              ),
        body: Stack(
          children: [
            Positioned.fill(child: video),
            if (c != null)
              Positioned(
                left: 12,
                bottom: 12,
                child: SafeArea(
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        icon: Icon(c.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        onPressed: () async {
                          c.value.isPlaying ? await c.pause() : await c.play();
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: Icon(_fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded),
                        onPressed: _toggleFullscreen,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
