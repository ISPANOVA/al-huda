import 'package:flutter/material.dart';

import '../theme/app_themes.dart';
import 'glass_container.dart';

class LoadingView extends StatelessWidget {
  final String? message;

  const LoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: glass.accent),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: TextStyle(color: glass.onGlassMuted)),
          ],
        ],
      ),
    );
  }
}

class MessageView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: glass.accent),
              const SizedBox(height: 12),
              Text(title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(color: glass.onGlassMuted)),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

void showGlassSnack(BuildContext context, String message, {IconData? icon}) {
  final glass = GlassTheme.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      duration: const Duration(milliseconds: 2400),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: sheetSurface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: glass.accent.withValues(alpha: 0.35)),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 18, offset: Offset(0, 6))],
        ),
        child: Row(
          children: [
            Icon(icon ?? Icons.check_circle_rounded, color: glass.accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message,
                  style: TextStyle(color: glass.onGlass, fontWeight: FontWeight.w700, fontSize: 14, height: 1.4)),
            ),
          ],
        ),
      ),
    ));
}

/// Solid surface colour for sheets and dialogs, derived from the current theme.
Color sheetSurface(BuildContext context) {
  final glass = GlassTheme.of(context);
  final dark = Theme.of(context).brightness == Brightness.dark;
  final base = glass.backgroundGradient[glass.backgroundGradient.length > 1 ? 1 : 0];
  return dark ? Color.lerp(base, Colors.black, 0.35)! : Color.lerp(base, Colors.white, 0.82)!;
}

/// Bottom sheet in the app's theme colours (solid, rounded, with a handle).
Future<T?> showGlassSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) {
      final glass = GlassTheme.of(ctx);
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Container(
          decoration: BoxDecoration(
            color: sheetSurface(ctx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: glass.accent.withValues(alpha: 0.35), width: 1.2),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: glass.onGlass.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Flexible(child: builder(ctx)),
              ],
            ),
          ),
        ),
      );
    },
  );
}
