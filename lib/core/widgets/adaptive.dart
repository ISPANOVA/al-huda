import 'package:flutter/widgets.dart';

/// Screen classes: a phone keeps its layout; a tablet, an unfolded phone or
/// a computer gets the side navigation and wider, multi-column pages.
class Adaptive {
  Adaptive._();

  /// From this width the app uses the wide layout.
  static const double wide = 840;

  /// From this width the side navigation shows its labels.
  static const double expanded = 1180;

  /// Widest a page of reading content (lists, settings) grows.
  static const double pageMax = 760;

  static bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= wide;

  /// Grid columns for tiles of about [tile] logical pixels across [width].
  static int columns(double width, {double tile = 200, int min = 2, int max = 6}) =>
      (width / tile).floor().clamp(min, max);
}

/// Centres [child] and keeps it at most [maxWidth] wide (full width on phones).
class MaxWidth extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const MaxWidth({super.key, this.maxWidth = Adaptive.pageMax, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
    );
  }
}
