/// Native build: not a browser.
bool get isIosBrowser => false;

/// Native build: not a browser.
bool get isMobileBrowser => false;

/// Native build: not a browser.
bool get isInstalledWebApp => false;

/// Native build: nothing to reload.
void reloadPage() {}

/// Opens a link in the browser (the phone app uses the system instead).
bool openInBrowser(String url) => false;
