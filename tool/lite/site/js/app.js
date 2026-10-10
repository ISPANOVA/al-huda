// الهدى — light web version: a small router and shared helpers. Each screen
// is its own module, loaded only when opened, so the first visit is quick.

export const $ = (s, el = document) => el.querySelector(s);
export const $$ = (s, el = document) => [...el.querySelectorAll(s)];

const AR = '٠١٢٣٤٥٦٧٨٩';
export const ar = (n) => String(n).replace(/[0-9]/g, (d) => AR[d]);
export const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

// ---------------------------------------------------------------- icons ---
const P = {
  back: 'M10 6 4 12l6 6 1.4-1.4L7.8 13H20v-2H7.8l3.6-3.6z',
  fwd: 'M14 6l6 6-6 6-1.4-1.4 3.6-3.6H4v-2h12.2l-3.6-3.6z',
  book: 'M3 5.5C5 4.6 8 4.3 11 5.6v14c-3-1.3-6-1-8-.1zM13 5.6c3-1.3 6-1 8-.1v14c-2-.9-5-1.2-8 .1z',
  mic: 'M12 14a3 3 0 0 0 3-3V5a3 3 0 0 0-6 0v6a3 3 0 0 0 3 3zm5-3a5 5 0 0 1-10 0H5a7 7 0 0 0 6 6.9V21h2v-3.1A7 7 0 0 0 19 11z',
  stop: 'M7 7h10v10H7z',
  play: 'M8 5v14l11-7z',
  pause: 'M7 5h4v14H7zM13 5h4v14h-4z',
  next: 'M6 18l8.5-6L6 6zM16 6h2v12h-2z',
  prev: 'M6 6h2v12H6zm3.5 6 8.5 6V6z',
  close: 'M19 6.4 17.6 5 12 10.6 6.4 5 5 6.4 10.6 12 5 17.6 6.4 19 12 13.4 17.6 19 19 17.6 13.4 12z',
  search: 'M15.5 14h-.8l-.3-.3A6.5 6.5 0 1 0 14 15.5l.3.3v.8l5 5 1.5-1.5zm-6 0a4.5 4.5 0 1 1 0-9 4.5 4.5 0 0 1 0 9z',
  grid: 'M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z',
  bookmark: 'M6 3h12v18l-6-4-6 4z',
  bookmarkO: 'M6 3h12v18l-6-4-6 4zm2 2v12.2l4-2.7 4 2.7V5z',
  clock: 'M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm1 10.6 3.4 2-1 1.7L11 13V6h2z',
  heart: 'M12 21s-7.5-4.6-9.5-9.3C1 8 3.3 4.5 6.9 4.5c2 0 3.6 1.1 5.1 3 1.5-1.9 3.1-3 5.1-3 3.6 0 5.9 3.5 4.4 7.2C19.5 16.4 12 21 12 21z',
  compass: 'M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm2.5 12.5L7 17l2.5-7.5L17 7z',
  beads: 'M12 3a3 3 0 1 1 0 6 3 3 0 0 1 0-6zm-6 6a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5zm12 0a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5zM8 16a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5zm8 0a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5z',
  cal: 'M7 2h2v2h6V2h2v2h3v18H4V4h3zm-1 8v10h12V10z',
  hands: 'M7 3c1 0 2 1 2 2v6l3 3V5a2 2 0 1 1 4 0v9l2-2a2 2 0 0 1 3 3l-5 6H9l-5-6V7a2 2 0 0 1 3-4z',
  star: 'M12 2 14.9 8.6 22 9.3l-5.4 4.7 1.6 7L12 17.3 5.8 21l1.6-7L2 9.3l7.1-.7z',
  radio: 'M4 8h16v12H4zm3-6 10 4-.8 1.8L6.2 4zM9 14a2 2 0 1 0 0 .1zm6-2h3v1h-3zm0 3h3v1h-3z',
  tv: 'M3 6h18v12H3zm6 13h6v2H9z',
  head: 'M12 3a9 9 0 0 0-9 9v6a3 3 0 0 0 3 3h2v-8H5v-1a7 7 0 0 1 14 0v1h-3v8h2a3 3 0 0 0 3-3v-6a9 9 0 0 0-9-9z',
  gear: 'M19.4 13a7.6 7.6 0 0 0 0-2l2.1-1.6-2-3.5-2.5 1a7.4 7.4 0 0 0-1.7-1L15 3h-4l-.4 2.7a7.4 7.4 0 0 0-1.7 1l-2.5-1-2 3.5L6.5 11a7.6 7.6 0 0 0 0 2l-2.1 1.6 2 3.5 2.5-1a7.4 7.4 0 0 0 1.7 1L11 21h4l.4-2.7a7.4 7.4 0 0 0 1.7-1l2.5 1 2-3.5zM13 15.5a3.5 3.5 0 1 1 0-7 3.5 3.5 0 0 1 0 7z',
  info: 'M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm1 15h-2v-6h2zm0-8h-2V7h2z',
  chart: 'M4 20h16v-2H4zm2-4h3V9H6zm5 0h3V4h-3zm5 0h3v-5h-3z',
  flag: 'M5 3h2v18H5zm3 1h11l-2 4 2 4H8z',
  eye: 'M12 5C6 5 2 12 2 12s4 7 10 7 10-7 10-7-4-7-10-7zm0 11a4 4 0 1 1 0-8 4 4 0 0 1 0 8z',
  eyeOff: 'M2 4.3 3.3 3 21 20.7 19.7 22l-3-3A11 11 0 0 1 12 19C6 19 2 12 2 12a18 18 0 0 1 4.3-5.1zM12 5c6 0 10 7 10 7a18 18 0 0 1-3 3.9l-3.1-3.1A4 4 0 0 0 11.2 8.1L9.3 6.2A10 10 0 0 1 12 5z',
  bulb: 'M9 21h6v-2H9zm3-19a7 7 0 0 0-4 12.7V17h8v-2.3A7 7 0 0 0 12 2z',
  lines: 'M4 6h16v2H4zm0 5h16v2H4zm0 5h10v2H4z',
  check: 'M9 16.2 4.8 12l-1.4 1.4L9 19 21 7l-1.4-1.4z',
  share: 'M18 16a3 3 0 0 0-2.4 1.2l-6.7-3.4a3 3 0 0 0 0-1.6l6.7-3.4A3 3 0 1 0 15 7l-6.7 3.4a3 3 0 1 0 0 3.2l6.7 3.4A3 3 0 1 0 18 16z',
  copy: 'M16 1H4v14h2V3h10zm3 4H8v18h11z',
  repeat: 'M7 7h10v3l4-4-4-4v3H5v6h2zm10 10H7v-3l-4 4 4 4v-3h12v-6h-2z',
  tune: 'M3 17v2h6v-2zM3 5v2h10V5zm10 16v-2h8v-2h-8v-2h-2v6zM7 9v2H3v2h4v2h2V9zm14 4v-2H11v2zm-6-4h2V7h4V5h-4V3h-2z',
  moon: 'M12 3a9 9 0 1 0 9 9 7 7 0 0 1-9-9z',
  sun: 'M12 7a5 5 0 1 0 0 10 5 5 0 0 0 0-10zM11 1h2v3h-2zm0 19h2v3h-2zM1 11h3v2H1zm19 0h3v2h-3z',
  download: 'M11 3h2v10l3.5-3.5 1.4 1.4L12 16.8 6.1 10.9l1.4-1.4L11 13zM5 19h14v2H5z',
  phone: 'M7 1h10a2 2 0 0 1 2 2v18a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V3a2 2 0 0 1 2-2zm0 3v15h10V4z',
};
export const icon = (name, cls = '') => `<svg class="${cls}" viewBox="0 0 24 24" aria-hidden="true"><path d="${P[name] || ''}"/></svg>`;

// -------------------------------------------------------------- storage ---
export const store = {
  get(k, d) { try { const v = localStorage.getItem('h_' + k); return v == null ? d : JSON.parse(v); } catch { return d; } },
  set(k, v) { try { localStorage.setItem('h_' + k, JSON.stringify(v)); } catch {} },
};
export const today = () => { const d = new Date(); return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`; };

// --------------------------------------------------------------- data ---
const cache = new Map();
export function data(path) {
  if (!cache.has(path)) {
    cache.set(path, fetch('data/' + path).then((r) => { if (!r.ok) throw new Error(path); return r.json(); })
      .catch((e) => { cache.delete(path); throw e; }));
  }
  return cache.get(path);
}
export const surahs = () => data('surahs.json');
export const meta = () => data('meta.json');

/// The Dart logic (prayer times, hijri dates, Tasmee), loaded on first use.
let coreReady;
export function core() {
  if (!coreReady) {
    coreReady = new Promise((ok, fail) => {
      window.alhudaReady = () => ok(window.alhuda);
      const s = document.createElement('script');
      s.src = 'js/core.js';
      s.onerror = fail;
      document.head.appendChild(s);
    });
  }
  return coreReady;
}

// --------------------------------------------------------------- ui ---
let toastTimer;
export function toast(msg) {
  const t = $('#toast');
  t.textContent = msg;
  t.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => (t.hidden = true), 2600);
}

let sheetClose = null;
export function sheet(html, onOpen) {
  const s = $('#sheet');
  $('.sheet-body', s).innerHTML = html;
  s.hidden = false;
  history.pushState({ sheet: 1 }, '');
  return new Promise((done) => {
    sheetClose = (v) => { s.hidden = true; sheetClose = null; done(v); };
    onOpen?.($('.sheet-body', s), (v) => { closeSheet(v); });
  });
}
export function closeSheet(v) {
  if (!sheetClose) return;
  const f = sheetClose;
  f(v);
  if (history.state?.sheet) history.back();
}
$('#sheet').addEventListener('click', (e) => { if (e.target.id === 'sheet') closeSheet(); });

export function top(title, sub = '', tone = 'gold', ic = 'book', back = true) {
  return `<div class="top">${back ? `<button class="back" onclick="history.length>1?history.back():location.hash='#/'">${icon('fwd')}</button>` : ''}
    <div class="ticon t-${tone}">${icon(ic)}</div><div class="grow"><h1>${esc(title)}</h1>${sub ? `<p>${esc(sub)}</p>` : ''}</div></div>`;
}

// -------------------------------------------------------------- theme ---
export function applyTheme() {
  const t = store.get('theme', 'dark');
  document.documentElement.dataset.theme = t;
  document.querySelector('meta[name=theme-color]').content = t === 'light' ? '#fcfaf5' : '#000000';
  document.documentElement.style.fontSize = '';
}
applyTheme();

// -------------------------------------------------------------- router ---
const routes = {
  '': () => import('./home.js'),
  mushaf: () => import('./mushaf.js'),
  tasmee: () => import('./tasmee.js'),
  search: () => import('./search.js'),
  athkar: () => import('./athkar.js'),
  prayer: () => import('./prayer.js'),
  qibla: () => import('./qibla.js'),
  tasbeeh: () => import('./tasbeeh.js'),
  media: () => import('./media.js'),
  calendar: () => import('./calendar.js'),
  duas: () => import('./content.js'),
  virtues: () => import('./content.js'),
  ruqyah: () => import('./content.js'),
  khatmah: () => import('./khatmah.js'),
  stats: () => import('./khatmah.js'),
  hifz: () => import('./hifz.js'),
  settings: () => import('./settings.js'),
  about: () => import('./settings.js'),
  more: () => import('./more.js'),
};
const TABS = { '': 'home', mushaf: 'mushaf', tasmee: 'mushaf', search: 'mushaf', media: 'media', prayer: 'prayer', qibla: 'prayer',
  calendar: 'prayer', athkar: 'athkar', tasbeeh: 'more', duas: 'athkar', ruqyah: 'athkar', virtues: 'athkar', khatmah: 'more', stats: 'more', hifz: 'media',
  settings: 'more', about: 'more', more: 'more' };
const TONES = { home: 'gold', mushaf: 'emerald', media: 'amethyst', prayer: 'sapphire', athkar: 'rose', more: 'teal' };

let current = null;
let seq = 0;
function highlight(name) {
  const tab = TABS[name] ?? 'home';
  for (const a of $$('#nav a')) a.className = a.dataset.tab === tab ? `on t-${TONES[tab]}` : '';
  $('#nav').classList.toggle('hide', name === 'mushaf' || name === 'tasmee');
}
// The new page fades in as soon as it is written.
const view0 = $('#view');
new MutationObserver(() => {
  if (!view0.classList.contains('enter') || view0.firstElementChild?.classList.contains('spin')) return;
  view0.classList.remove('enter');
  void view0.offsetWidth;
  view0.classList.add('in');
}).observe(view0, { childList: true });
view0.addEventListener('animationend', () => view0.classList.remove('in'));

async function route() {
  if (sheetClose) { const f = sheetClose; f(); }
  const [name, ...args] = location.hash.replace(/^#\/?/, '').split('/');
  const loader = routes[name] ?? routes[''];
  const my = ++seq;
  const view = view0;
  // The tap answers at once: the tab lights up, the old page leaves.
  highlight(name in routes ? name : '');
  try {
    const mod = await loader();
    if (my !== seq) return;
    current?.leave?.();
    current = mod;
    view.className = 'view enter';
    view.onclick = null;
    view.innerHTML = '<div class="spin"></div>';
    window.scrollTo(0, 0);
    await mod.show(view, args.map(decodeURIComponent), name);
    if (!view.className.includes('full')) view.classList.remove('enter');
  } catch (e) {
    console.error(e);
    view.innerHTML = `<div class="card center" style="margin-top:40px">تعذر فتح الصفحة. تأكد من الاتصال ثم أعد المحاولة.<br><br><button class="btn" onclick="location.reload()">إعادة المحاولة</button></div>`;
  }
}
addEventListener('hashchange', route);
addEventListener('popstate', () => { if (sheetClose && !history.state?.sheet) { const f = sheetClose; f(); } });

// After the first page: every other page (and its small data) is fetched in
// the background, so moving between pages never waits for the network.
const idle = (f) => (window.requestIdleCallback ? requestIdleCallback(f, { timeout: 2000 }) : setTimeout(f, 200));
async function warm() {
  for (const load of new Set(Object.values(routes))) { try { await load(); } catch {} }
  for (const f of ['surahs.json', 'meta.json', 'athkar.json', 'duas.json', 'virtues.json', 'media.json', 'reciters.json', 'calendar.json']) {
    try { await data(f); } catch {}
  }
  setTimeout(() => idle(() => core().catch(() => {})), 1500);
}

route().then(() => {
  const s = $('#splash');
  setTimeout(() => { s.classList.add('out'); setTimeout(() => s.remove(), 400); }, 350);
  setTimeout(() => idle(warm), 600);
});

if ('serviceWorker' in navigator && location.protocol === 'https:') {
  addEventListener('load', () => navigator.serviceWorker.register('sw.js').catch(() => {}));
}
