import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/announcement_service.dart';
import '../theme/app_themes.dart';
import 'gradient_background.dart';
import 'noor_ui.dart';

/// Shows the owner's message over the app when it opens: a card the user can
/// close, or (a required update) a screen that can't be passed.
class AnnouncementGate extends StatefulWidget {
  final AnnouncementService service;
  final Widget child;

  const AnnouncementGate({super.key, required this.service, required this.child});

  @override
  State<AnnouncementGate> createState() => _AnnouncementGateState();
}

class _AnnouncementGateState extends State<AnnouncementGate> with WidgetsBindingObserver {
  Announcement? _shown;
  Timer? _start;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A required update holds even offline (the last message fetched).
    final cached = widget.service.cached();
    if (cached != null && cached.force) _shown = cached;
    // After the first screen is up, so the start stays fast.
    _start = Timer(const Duration(milliseconds: 1500), _refresh);
  }

  @override
  void dispose() {
    _start?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the store / download: the message may have changed (or the
  /// update was installed and it no longer applies).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && (_shown?.force ?? false)) _refresh();
  }

  Future<void> _refresh() async {
    final a = await widget.service.fetch();
    if (!mounted) return;
    setState(() => _shown = a != null && widget.service.shouldShow(a) ? a : null);
  }

  void _close() {
    final a = _shown;
    if (a == null) return;
    widget.service.markSeen(a);
    setState(() => _shown = null);
  }

  @override
  Widget build(BuildContext context) {
    final a = _shown;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (a != null)
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: a.force
                  ? _ForceScreen(key: ValueKey(a.id), a: a)
                  : _Card(key: ValueKey(a.id), a: a, onClose: _close),
            ),
          ),
      ],
    );
  }
}

Future<void> _follow(BuildContext context, Announcement a) async {
  HapticFeedback.selectionClick();
  final ok = await AnnouncementService.open(a.buttonUrl);
  if (!ok && context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(a.buttonUrl)));
  }
}

/// A required update: covers the app; only the button leads on.
class _ForceScreen extends StatelessWidget {
  final Announcement a;

  const _ForceScreen({super.key, required this.a});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return Material(
      color: Colors.transparent,
      child: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/icon/logo_mark.png', width: 112, height: 112),
                  const SizedBox(height: 22),
                  if (a.title.isNotEmpty)
                    Text(a.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: glass.accent)),
                  if (a.message.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(a.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, height: 1.8, color: glass.onGlass)),
                  ],
                  if (a.buttonUrl.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: () => _follow(context, a),
                        icon: const Icon(Icons.system_update_rounded),
                        label: Text(a.buttonText.isEmpty ? 'تحميل التحديث' : a.buttonText,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A message the user can close.
class _Card extends StatelessWidget {
  final Announcement a;
  final VoidCallback onClose;

  const _Card({super.key, required this.a, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 440, maxHeight: MediaQuery.sizeOf(context).height * 0.8),
              child: Container(
                decoration: BoxDecoration(
                  color: noorSurface(context),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: glass.accent.withValues(alpha: 0.35)),
                ),
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: IconButton(
                        tooltip: 'إغلاق',
                        onPressed: onClose,
                        icon: Icon(Icons.close_rounded, color: glass.onGlassMuted),
                      ),
                    ),
                    Icon(Icons.campaign_rounded, size: 44, color: glass.accent),
                    const SizedBox(height: 10),
                    if (a.title.isNotEmpty)
                      Text(a.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: glass.onGlass)),
                    if (a.message.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Text(a.message,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 15, height: 1.8, color: glass.onGlassMuted)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (a.buttonUrl.isNotEmpty)
                      SizedBox(
                        height: 50,
                        child: FilledButton(
                          onPressed: () {
                            _follow(context, a);
                            onClose();
                          },
                          child: Text(a.buttonText.isEmpty ? 'فتح' : a.buttonText,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: onClose,
                      child: Text(a.buttonUrl.isEmpty ? 'حسنًا' : 'لاحقًا', style: TextStyle(color: glass.onGlassMuted)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
