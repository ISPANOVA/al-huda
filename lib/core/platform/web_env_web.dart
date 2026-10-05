import 'package:web/web.dart' as web;

String get _ua => web.window.navigator.userAgent;

/// iPhone / iPad (iPadOS reports itself as a Mac with a touch screen).
bool get isIosBrowser =>
    RegExp('iPhone|iPad|iPod').hasMatch(_ua) ||
    (_ua.contains('Macintosh') && web.window.navigator.maxTouchPoints > 1);

/// A phone or tablet browser (the speech service ends after each pause there).
bool get isMobileBrowser => isIosBrowser || RegExp('Android|Mobile').hasMatch(_ua);

/// Opened from the home-screen icon rather than a browser tab.
bool get isInstalledWebApp => web.window.matchMedia('(display-mode: standalone)').matches;

/// Starts the app again (after restoring a backup).
void reloadPage() => web.window.location.reload();

/// Opens a link in a new tab.
bool openInBrowser(String url) {
  web.window.open(url, '_blank');
  return true;
}
