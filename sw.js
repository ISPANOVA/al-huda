// Offline support: the shell and what was opened stay cached, so the Mushaf
// and the athkar open without the internet after the first visit.
const VERSION = '4d169ebabd70';
const CACHE = 'alhuda-' + VERSION;
const JS = ['app', 'home', 'player', 'prayerlib', 'page', 'mushaf', 'tasmee', 'search', 'athkar', 'prayer', 'qibla', 'tasbeeh',
  'media', 'calendar', 'content', 'khatmah', 'hifz', 'settings', 'more', 'core', 'reciters', 'sky', 'tools', 'video', 'tajweed', 'cards', 'group', 'i18n'].map((n) => `js/${n}.js`);
const DATA = ['meta', 'surahs', 'athkar', 'duas', 'virtues', 'media', 'reciters', 'calendar', 'asma', 'nawawi', 'mutashabihat', 'en'].map((n) => `data/${n}.json`);
const FONTS = ['Tajawal-Regular', 'Tajawal-Bold', 'Tajawal-ExtraBold', 'ReemKufi-Bold', 'UthmanicHafs18', 'HafsSplash'].map((n) => `fonts/${n}.woff2`);
const SHELL = ['./', 'index.html', 'css/app.css', 'manifest.json', ...JS, ...DATA, ...FONTS];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).catch(() => {}).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((k) => k.startsWith('alhuda-') && k !== CACHE).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== location.origin) return; // audio, radios, APIs: straight to the network
  if (url.pathname.startsWith('/full/')) return; // the Flutter version has its own
  // Pages: the network first (new versions), the cache when offline.
  if (req.mode === 'navigate') {
    e.respondWith(fetch(req).then((r) => { const copy = r.clone(); caches.open(CACHE).then((c) => c.put('index.html', copy)); return r; })
      .catch(() => caches.match('index.html')));
    return;
  }
  // Fonts, page data and pictures never change: the cache first.
  if (/\/(fonts|data|img|icons)\//.test(url.pathname)) {
    e.respondWith(caches.match(req).then((hit) => hit || fetch(req).then((r) => {
      if (r.ok && !url.pathname.endsWith('words.json')) { const copy = r.clone(); caches.open(CACHE).then((c) => c.put(req, copy)); }
      return r;
    })));
    return;
  }
  // Code and styles: always the newest from the network, the cache offline.
  e.respondWith(fetch(req).then((r) => {
    if (r.ok) { const copy = r.clone(); caches.open(CACHE).then((c) => c.put(req, copy)); }
    return r;
  }).catch(() => caches.match(req)));
});
