// المصحف: pages swiped like a paper Mushaf (native scroll snapping), drawn
// only around the page in view, ayah menu, index, tafseer and recitation.
import { $, $$, ar, esc, icon, store, data, meta, surahs, sheet, closeSheet, toast, today } from './app.js';
import { drawPage, hizbLabel, JUZ, BASMALA, ayahText } from './page.js';
import { player, listenSheet } from './player.js';
import * as taj from './tajweed.js';

const PAGES = 604;
let root, pagesEl, page = 1, offPlayer, selected = 0, spread = false;

/// Two pages side by side whenever the screen is sideways: a computer, a
/// tablet or a phone turned to landscape.
function layoutMode() {
  spread = innerWidth >= 600 && innerWidth > innerHeight * 1.15;
  root.classList.toggle('spread', spread);
}
const first = (p) => (spread ? p - ((p - 1) % 2) : p);

export async function show(view, args) {
  const [m, names] = await Promise.all([meta(), surahs()]);
  view.className = 'view full';
  const start = Math.min(PAGES, Math.max(1, +args[0] || store.get('lastPage', 1)));
  view.innerHTML = `<div class="mushaf" id="mushaf">
    <div class="pages" id="pages">${Array.from({ length: PAGES }, (_, i) => `<section class="mpage" data-p="${i + 1}"><div class="inner"></div></section>`).join('')}</div>
    <div class="spine" aria-hidden="true"></div>
    <div class="mbar topb">
      <a class="ibtn" href="#/">${icon('fwd')}</a>
      <button class="chip" id="surahChip"></button>
      <a class="ibtn" href="#/search">${icon('search')}</a>
      <span class="sp"></span>
      <button class="ibtn${taj.on() ? ' on' : ''}" id="tj" title="مصحف التجويد">${icon('palette')}</button>
      <button class="ibtn" id="full" title="ملء الشاشة">${icon('expand')}</button>
      <button class="ibtn" id="tasmee" title="التسميع">${icon('mic')}</button>
      <button class="chip" id="juzChip"></button>
      <button class="ibtn" id="mark">${icon('bookmarkO')}</button>
    </div>
    <div class="mbar botb">
      <button class="chip" id="pageChip"></button>
      <span class="sp"></span>
      <button class="pbtn" id="playPage">${icon('play')}</button>
    </div>
  </div>`;
  root = $('#mushaf', view);
  pagesEl = $('#pages', view);
  document.body.classList.add('in-mushaf');
  layoutMode();
  goTo(start, false);

  let ticking = false;
  pagesEl.addEventListener('scroll', () => {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(() => { ticking = false; onScroll(m, names); });
  }, { passive: true });
  addEventListener('resize', onResize);

  // A tap shows or hides the bars; holding an ayah opens its menu.
  let hold, held = false, x0 = 0, y0 = 0;
  pagesEl.addEventListener('pointerdown', (e) => {
    held = false;
    x0 = e.clientX; y0 = e.clientY;
    const w = e.target.closest('span[data-a]');
    const a = w ? +w.dataset.a : 0;
    clearTimeout(hold);
    if (!a) return;
    hold = setTimeout(() => { held = true; navigator.vibrate?.(15); ayahMenu(a, m, names); }, 480);
  });
  const cancel = () => clearTimeout(hold);
  pagesEl.addEventListener('pointermove', (e) => { if (Math.abs(e.clientX - x0) + Math.abs(e.clientY - y0) > 12) cancel(); });
  pagesEl.addEventListener('pointerup', cancel);
  pagesEl.addEventListener('pointercancel', cancel);
  pagesEl.addEventListener('scroll', cancel, { passive: true });
  pagesEl.addEventListener('contextmenu', (e) => e.preventDefault());
  pagesEl.addEventListener('click', () => {
    if (held) { held = false; return; }
    focus(!root.classList.contains('immersive'));
  });
  document.addEventListener('fullscreenchange', onFullscreen);
  $('#surahChip', root).onclick = () => openIndex(m, names);
  $('#juzChip', root).onclick = () => openIndex(m, names, 1);
  $('#pageChip', root).onclick = () => openIndex(m, names, 1);
  $('#tasmee', root).onclick = () => (location.hash = `#/tasmee/${page}`);
  $('#full', root).onclick = fullscreen;
  $('#tj', root).onclick = () => tajweedSheet();
  if (taj.on()) taj.load().then(relayout);
  $('#mark', root).onclick = () => toggleMark(m);
  $('#playPage', root).onclick = () => listenSheet(m.page.indexOf(page) + 1);
  offPlayer = player.on((it) => highlight(it?.ayah ?? 0, m));
  highlight(player.current?.ayah ?? 0, m);
  update(m, names);
}

// Focus: the page alone, as large as the screen allows (full screen where
// the browser lets a site do it: Android; on iPhone only the bars hide).
let ownFullscreen = false;
function focus(on) {
  // A tap on the page: the bars hide or show (the page never moves).
  root.classList.toggle('immersive', on);
  document.body.classList.toggle('focus', on);
}
/// The full-screen button: the browser's own bars hide too (Android, computers).
async function fullscreen() {
  try {
    if (document.fullscreenElement) { ownFullscreen = false; await document.exitFullscreen(); return; }
    await document.documentElement.requestFullscreen({ navigationUI: 'hide' });
    ownFullscreen = true;
    if (innerHeight > innerWidth) screen.orientation?.lock?.('portrait').catch(() => {});
    focus(true);
  } catch {
    toast('المتصفح لا يسمح بملء الشاشة. على آيفون: أضف الموقع إلى الشاشة الرئيسية');
  }
}
function onFullscreen() {
  const on = !!document.fullscreenElement;
  $('#full', root).innerHTML = icon(on ? 'shrink' : 'expand');
  // Leaving full screen (the back gesture) shows the bars again.
  if (!on && ownFullscreen) { ownFullscreen = false; focus(false); }
}

export function leave() {
  removeEventListener('resize', onResize);
  document.removeEventListener('fullscreenchange', onFullscreen);
  document.body.classList.remove('focus');
  if (document.fullscreenElement) { screen.orientation?.unlock?.(); document.exitFullscreen().catch(() => {}); }
  offPlayer?.();
  document.body.classList.remove('in-mushaf');
}

function pageEl(p) { return pagesEl.children[p - 1]; }

function goTo(p, smooth = true) {
  page = first(p);
  pageEl(page).scrollIntoView({ behavior: smooth ? 'smooth' : 'instant', inline: spread ? 'start' : 'center', block: 'nearest' });
  drawAround(page);
}

function onScroll(m, names) {
  const w = (pagesEl.clientWidth || 1) / (spread ? 2 : 1);
  const p = first(Math.min(PAGES, Math.max(1, Math.round(Math.abs(pagesEl.scrollLeft) / w) + 1)));
  if (p === page) return;
  page = p;
  drawAround(p);
  update(m, names);
}

let resizeTimer;
function onResize() {
  clearTimeout(resizeTimer);
  resizeTimer = setTimeout(relayout, 150);
}
function relayout() {
  for (const s of $$('.mpage .inner[data-drawn]', pagesEl)) { delete s.dataset.drawn; s.innerHTML = ''; s.style.height = ''; s.style.width = ''; }
  layoutMode();
  goTo(page, false);
}

/// «مصحف التجويد»: on or off, and the colour key.
function tajweedSheet() {
  sheet(`<h3>مصحف التجويد</h3>
    <button class="btn block${taj.on() ? ' ghost' : ''}" id="tjOn">${taj.on() ? 'إيقاف ألوان التجويد' : 'تشغيل ألوان التجويد'}</button>
    <div class="list" style="margin-top:12px">${taj.RULES.map(([n, d], i) => `<div><i class="tjdot tj${i}"></i><span class="grow"><b class="tj${i}">${n}</b><br><small class="muted">${d}</small></span></div>`).join('')}</div>
    <p class="muted small center">الألوان تقريبية مساعدة على التعلم، والعبرة بالتلقي من شيخ متقن.</p>`, (body, close) => {
    $('#tjOn', body).onclick = async () => {
      store.set('tajweed', !taj.on());
      $('#tj', root).classList.toggle('on', taj.on());
      close();
      if (taj.on()) { toast('جارٍ تحميل ألوان التجويد…'); await taj.load(); }
      relayout();
    };
  });
}

function drawAround(p) {
  for (let q = p - (spread ? 2 : 1); q <= p + (spread ? 3 : 1); q++) {
    if (q < 1 || q > PAGES) continue;
    const inner = pageEl(q).firstElementChild;
    if (+inner.dataset.drawn !== q) drawPage(inner, q, { tajweed: taj.on() }).then(() => q === page && highlight(player.current?.ayah ?? 0));
  }
  // Pages far away are emptied (memory stays small).
  for (const s of $$('.inner[data-drawn]', pagesEl)) {
    const q = +s.dataset.drawn;
    if (Math.abs(q - p) > 3) { s.innerHTML = ''; delete s.dataset.drawn; }
  }
}

function update(m, names) {
  store.set('lastPage', page);
  // Pages read today (the wird and the statistics).
  const log = store.get('read', {});
  const d = today();
  log[d] = [...new Set([...(log[d] || []), page, ...(spread && page < PAGES ? [page + 1] : [])])];
  const keys = Object.keys(log);
  if (keys.length > 120) delete log[keys[0]];
  store.set('read', log);
  const k = store.get('khatmah', null);
  if (k && !k.pages.includes(page)) { k.pages.push(page); store.set('khatmah', k); }
  const g = m.page.indexOf(page) + 1;
  $('#surahChip', root).innerHTML = `${esc(names[m.surah[g - 1] - 1][1])} ▾`;
  $('#juzChip', root).textContent = `الجزء ${JUZ[m.juz[g - 1] - 1]}`;
  $('#pageChip', root).textContent = `${ar(page)}   ${ar(hizbLabel(m.hq[g - 1]))}`;
  const marks = store.get('marks', []);
  $('#mark', root).innerHTML = icon(marks.some((x) => x.page === page) ? 'bookmark' : 'bookmarkO');
}

function highlight(a, m) {
  for (const s of $$('span.hl', pagesEl)) s.classList.remove('hl');
  if (!a) return;
  for (const s of $$(`span[data-a="${a}"]`, pagesEl)) s.classList.add('hl');
  if (m) {
    const p = m.page[a - 1];
    if (first(p) !== page) goTo(p);
  }
}

function toggleMark(m) {
  const marks = store.get('marks', []);
  const i = marks.findIndex((x) => x.page === page);
  if (i >= 0) { marks.splice(i, 1); toast('أُزيلت العلامة'); } else { marks.unshift({ page, at: Date.now(), ayah: m.page.indexOf(page) + 1 }); toast('حُفظ موضع القراءة'); }
  store.set('marks', marks);
  $('#mark', root).innerHTML = icon(i >= 0 ? 'bookmarkO' : 'bookmark');
}

function label(g, m, names) { return `${names[m.surah[g - 1] - 1][1]}، ${ar(m.ayah[g - 1])}`; }


async function ayahMenu(a, m, names) {
  for (const s of $$('span.sel', pagesEl)) s.classList.remove('sel');
  for (const s of $$(`span[data-a="${a}"]`, pagesEl)) s.classList.add('sel');
  const [text, sim] = await Promise.all([ayahText(a), data('mutashabihat.json').catch(() => ({}))]);
  const name = names[m.surah[a - 1] - 1][1];
  await sheet(`<h3>سورة ${esc(name)}، الآية ${ar(m.ayah[a - 1])}</h3>
    <div class="list">
      <button data-x="play">${icon('play')}<span class="grow">الاستماع من هذه الآية<br><small class="muted">حدّد النطاق والتكرار والقارئ</small></span></button>
      <button data-x="tafsir">${icon('book')}<span class="grow">التفسير<br><small class="muted">الميسر والسعدي وابن كثير وغيرها</small></span></button>
      ${sim[a]?.length ? `<button data-x="similar">${icon('repeat')}<span class="grow">آيات متشابهة<br><small class="muted">${ar(sim[a].length)} آية تشبهها في الألفاظ</small></span></button>` : ''}
      <button data-x="video">${icon('tv')}<span class="grow">فيديو بصوت القارئ<br><small class="muted">ستوري لواتساب وانستجرام وفيسبوك</small></span></button>
      <button data-x="image">${icon('image')}<span class="grow">مشاركة كصورة</span></button>
      <button data-x="tasmee">${icon('mic')}<span class="grow">سمّع من هذه الآية</span></button>
      <button data-x="hifz">${icon('repeat')}<span class="grow">احفظ هذه الآية (تكرار)</span></button>
      <button data-x="copy">${icon('copy')}<span class="grow">نسخ الآية</span></button>
      <button data-x="share">${icon('share')}<span class="grow">مشاركة</span></button>
    </div>`, (body, close) => {
    body.onclick = async (e) => {
      const x = e.target.closest('[data-x]')?.dataset.x;
      if (!x) return;
      const ref = `﴿${text}﴾ [${name}: ${ar(m.ayah[a - 1])}]`;
      if (x === 'play') { close(); setTimeout(() => listenSheet(a), 50); }
      if (x === 'tafsir') { close(); setTimeout(() => tafsir(a, m, names), 50); }
      if (x === 'similar') { close(); import('./tools.js').then((t) => setTimeout(() => t.similarSheet(a), 50)); }
      if (x === 'video') { close(); location.hash = `#/video/${m.surah[a - 1]}/${m.ayah[a - 1]}/${m.ayah[a - 1]}`; }
      if (x === 'image') { close(); toast('جارٍ تجهيز الصورة…'); import('./video.js').then((v) => v.shareAyahImage(a)).catch(() => toast('تعذر إنشاء الصورة')); }
      if (x === 'tasmee') { close(); location.hash = `#/tasmee/${m.page[a - 1]}/${a}`; }
      if (x === 'hifz') { close(); location.hash = `#/hifz/${a}`; }
      if (x === 'copy') { close(); navigator.clipboard?.writeText(ref).then(() => toast('نُسخت الآية')); }
      if (x === 'share') { close(); if (navigator.share) navigator.share({ text: ref }).catch(() => {}); else navigator.clipboard?.writeText(ref).then(() => toast('نُسخت الآية')); }
    };
  });
  for (const s of $$('span.sel', pagesEl)) s.classList.remove('sel');
}

// The tafsir books: Al-Muyassar comes with the site; the others are fetched
// (spa5k/tafsir_api, then Quran.com) and kept for the next time.
const BOOKS = [['muyassar', 'الميسر'], ['saadi', 'السعدي', 'ar-tafsir-as-saadi', 91], ['ibnkathir', 'ابن كثير', 'ar-tafsir-ibn-kathir', 14],
  ['wasit', 'الوسيط', null, 93], ['baghawi', 'البغوي', 'ar-tafsir-al-baghawi', 94], ['qurtubi', 'القرطبي', 'ar-tafseer-al-qurtubi', 90],
  ['tabari', 'الطبري', 'ar-tafsir-al-tabari', 15]];
const clean = (h) => h.replace(/<\s*(br|\/p|\/h\d|\/div)[^>]*>/gi, '\n').replace(/<[^>]+>/g, '').replace(/&nbsp;/g, ' ').replace(/&quot;/g, '"').replace(/&amp;/g, '&').replace(/\n{3,}/g, '\n\n').trim();
async function tafsirText(book, a, m) {
  const [id, , slug, qc] = book;
  if (id === 'muyassar') return (await data(`t/${m.page[a - 1]}.json`))[a] ?? '';
  const key = `tafsir:${id}:${a}`;
  try { const c = sessionStorage.getItem(key) || localStorage.getItem('h_' + key); if (c) return c; } catch {}
  const s = m.surah[a - 1], v = m.ayah[a - 1];
  let t = '';
  if (slug) {
    try { const r = await fetch(`https://cdn.jsdelivr.net/gh/spa5k/tafsir_api@main/tafsir/${slug}/${s}/${v}.json`); if (r.ok) t = ((await r.json()).text || '').trim(); } catch {}
  }
  if (!t && qc) {
    const r = await fetch(`https://api.quran.com/api/v4/tafsirs/${qc}/by_ayah/${s}:${v}`);
    if (r.ok) t = clean((await r.json()).tafsir?.text || '');
  }
  if (t) { try { sessionStorage.setItem(key, t); } catch {} }
  return t;
}
async function tafsir(a, m, names) {
  const text = await ayahText(a);
  let book = BOOKS.find((b) => b[0] === store.get('tafsirBook', 'muyassar')) || BOOKS[0];
  await sheet(`<h3>التفسير</h3>
    <div class="chips" id="tb">${BOOKS.map((b) => `<button class="chip${b === book ? ' on' : ''}" data-b="${b[0]}">${b[1]}</button>`).join('')}</div>
    <div class="quran center" style="margin-top:10px">${esc(text)}</div>
    <p class="muted small center">سورة ${esc(names[m.surah[a - 1] - 1][1])}، الآية ${ar(m.ayah[a - 1])}</p>
    <div class="card" style="line-height:2;white-space:pre-line" id="tt"></div>
    <div id="gh"></div>`, (body) => {
    data('gharib.json').then((gh) => {
      const w = gh.ayahs[`${m.surah[a - 1]}:${m.ayah[a - 1]}`];
      if (!w) return;
      $('#gh', body).innerHTML = `<div class="section">معاني الكلمات</div><div class="card" style="line-height:1.9">${w.slice(1).map(([k, v]) =>
        `<p style="margin:6px 0"><b class="gold quran" style="font-size:20px">${esc(k)}:</b> ${esc(v)}</p>`).join('')}
        <small class="muted">${esc(gh.source[w[0]])}، عبر ${esc(gh.source.via)}</small></div>`;
    }).catch(() => {});
    const load = async () => {
      const box = $('#tt', body);
      box.innerHTML = '<div class="spin" style="margin:20px auto;opacity:1"></div>';
      try {
        const t = await tafsirText(book, a, m);
        box.textContent = t || 'التفسير غير متوفر لهذه الآية.';
      } catch { box.textContent = `تعذر تحميل تفسير ${book[1]}. تحقق من الاتصال بالإنترنت.`; }
    };
    load();
    $('#tb', body).onclick = (e) => {
      const c = e.target.closest('[data-b]');
      if (!c) return;
      book = BOOKS.find((b) => b[0] === c.dataset.b);
      store.set('tafsirBook', book[0]);
      $$('[data-b]', body).forEach((x) => x.classList.toggle('on', x === c));
      load();
    };
  });
}

async function openIndex(m, names, tab = 0) {
  const juzStarts = [];
  for (let i = 0, last = 0; i < m.juz.length; i++) if (m.juz[i] > last) { last = m.juz[i]; juzStarts.push([last, m.page[i]]); }
  const surahPage = (s) => m.page[m.surah.indexOf(s)];
  const marks = store.get('marks', []);
  const tabs = ['السور', 'الأجزاء', 'العلامات'];
  const render = (t, q = '') => {
    if (t === 0) {
      return names.filter((s) => !q || s[1].includes(q) || String(s[0]) === q).map((s) =>
        `<a href="#/mushaf/${surahPage(s[0])}" data-go="${surahPage(s[0])}"><span class="num">${ar(s[0])}</span><span class="grow"><b>سورة ${esc(s[1])}</b><br><small class="muted">${s[3] ? 'مكية' : 'مدنية'}، ${ar(s[2])} آية</small></span><small class="muted">${ar(surahPage(s[0]))}</small></a>`).join('');
    }
    if (t === 1) {
      return juzStarts.map(([j, p]) => `<a href="#/mushaf/${p}" data-go="${p}"><span class="num">${ar(j)}</span><span class="grow"><b>الجزء ${JUZ[j - 1]}</b></span><small class="muted">صفحة ${ar(p)}</small></a>`).join('');
    }
    return marks.length ? marks.map((x) => `<a href="#/mushaf/${x.page}" data-go="${x.page}">${icon('bookmark')}<span class="grow"><b>صفحة ${ar(x.page)}</b><br><small class="muted">سورة ${esc(names[m.surah[x.ayah - 1] - 1][1])}</small></span></a>`).join('')
      : '<p class="muted center">لا توجد علامات بعد. اضغط رمز العلامة أعلى الصفحة لحفظ موضعك.</p>';
  };
  await sheet(`<div class="chips" style="justify-content:center">${tabs.map((x, i) => `<button class="chip${i === tab ? ' on' : ''}" data-t="${i}">${x}</button>`).join('')}</div>
    <input class="field" id="q" placeholder="ابحث باسم السورة أو رقمها" style="margin:12px 0">
    <div class="list" id="res">${render(tab)}</div>`, (body, close) => {
    let t = tab;
    const res = $('#res', body), q = $('#q', body);
    q.hidden = t !== 0;
    body.onclick = (e) => {
      const c = e.target.closest('[data-t]');
      if (c) { t = +c.dataset.t; $$('[data-t]', body).forEach((b) => b.classList.toggle('on', +b.dataset.t === t)); q.hidden = t !== 0; res.innerHTML = render(t, q.value.trim()); return; }
      const g = e.target.closest('[data-go]');
      if (g) { e.preventDefault(); close(); goTo(+g.dataset.go, false); }
    };
    q.oninput = () => { res.innerHTML = render(0, q.value.trim()); };
  });
}

export { BASMALA };
