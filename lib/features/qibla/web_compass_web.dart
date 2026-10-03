import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

JSObject? get _orientationEvent => globalContext['DeviceOrientationEvent'] as JSObject?;

/// iPhone Safari only gives the compass after a tap and the user's consent.
bool get webCompassNeedsPermission => _orientationEvent?.has('requestPermission') ?? false;

/// Must run from a tap (Safari's rule).
Future<bool> requestWebCompassPermission() async {
  final ev = _orientationEvent;
  if (ev == null || !ev.has('requestPermission')) return true;
  try {
    final result = await (ev.callMethod<JSPromise<JSString>>('requestPermission'.toJS)).toDart;
    return result.toDart == 'granted';
  } catch (_) {
    return false;
  }
}

/// Degrees clockwise from north.
Stream<double> webCompassHeadings() {
  late final StreamController<double> controller;
  JSFunction? absolute;
  JSFunction? relative;
  var gotAbsolute = false;

  void emit(double h) {
    if (!controller.isClosed) controller.add((h % 360 + 360) % 360);
  }

  controller = StreamController<double>(
    onListen: () {
      // Android Chrome: alpha against true north.
      absolute = ((web.DeviceOrientationEvent e) {
        final alpha = e.alpha;
        if (alpha == null) return;
        gotAbsolute = true;
        emit(360 - alpha.toDouble());
      }).toJS;
      // iPhone Safari: webkitCompassHeading; others: absolute alpha.
      relative = ((web.DeviceOrientationEvent e) {
        final o = e as JSObject;
        final webkit = o['webkitCompassHeading'];
        if (webkit != null && webkit.isA<JSNumber>()) {
          emit((webkit as JSNumber).toDartDouble);
          return;
        }
        final alpha = e.alpha;
        if (!gotAbsolute && e.absolute && alpha != null) emit(360 - alpha.toDouble());
      }).toJS;
      web.window.addEventListener('deviceorientationabsolute', absolute);
      web.window.addEventListener('deviceorientation', relative);
    },
    onCancel: () {
      if (absolute != null) web.window.removeEventListener('deviceorientationabsolute', absolute);
      if (relative != null) web.window.removeEventListener('deviceorientation', relative);
    },
  );
  return controller.stream;
}
