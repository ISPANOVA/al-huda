import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Large blurred shadows are among the costliest things a browser draws, and
/// it redraws them on every frame (it keeps no raster cache, unlike the
/// phone app). The web build leaves them out; the phone app keeps them.
List<BoxShadow>? liteShadows(List<BoxShadow>? shadows) => kIsWeb ? null : shadows;

/// Endless decorative animations repaint the whole page 60 times a second in
/// a browser; there they stay still.
const bool animateDecorations = !kIsWeb;
