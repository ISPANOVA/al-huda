import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Reads `navigator.geolocation` directly.
///
/// geolocator's web plugin first asks the Permissions API (which Safari
/// answers inconsistently) and converts the timestamp to an int (Safari's is
/// fractional); only the coordinates are needed here, so neither is used.
/// Throws the browser's error code: 1 denied, 2 unavailable, 3 timeout.
Future<({double lat, double lng})> browserPosition() {
  final done = Completer<({double lat, double lng})>();
  void attempt(bool precise) {
    web.window.navigator.geolocation.getCurrentPosition(
      (web.GeolocationPosition p) {
        if (!done.isCompleted) done.complete((lat: p.coords.latitude, lng: p.coords.longitude));
      }.toJS,
      (web.GeolocationPositionError e) {
        if (done.isCompleted) return;
        // A slow or failed fix: one more try with the other accuracy.
        if (e.code != 1 && !precise) {
          attempt(true);
        } else {
          done.completeError(e.code);
        }
      }.toJS,
      web.PositionOptions(enableHighAccuracy: precise, timeout: 15000, maximumAge: 600000),
    );
  }

  try {
    attempt(false);
  } catch (_) {
    if (!done.isCompleted) done.completeError(2);
  }
  return done.future.timeout(const Duration(seconds: 35), onTimeout: () => throw 3);
}
