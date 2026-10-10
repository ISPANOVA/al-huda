// المصحف: pages swiped like a paper Mushaf (native scroll snapping), drawn
// only around the page in view, ayah menu, index, tafseer and recitation.
import { $, $$, ar, esc, icon, store, data, meta, surahs, sheet, closeSheet, toast, today } from './app.js';
import { drawPage, hizbLabel, JUZ, BASMALA, ayahText } from './page.js';
import { player, ayahItems } from './player.js';

const PAGES = 604;
let root, pagesEl, page = 1, offPlayer, selected = 0;

export async function show(view, args) {
  const [m, names] = await Promise.all([meta(), surahs()]);
  view.className = 'view full';
  const start = Math.min(PAGES, Math.max(1, +args[0] || store.get('lastPage', 1)));
  view.innerHTML = `<div class="mushaf" id="mushaf">
    <div class="pages" id="pages">${Array.from({ length: PAGES }, (_, i) => `<section class="mpage" data-p="${i + 1}"><div class="inner"></div></section>`).join('')}</div>
    <div class="mbar topb">
      <a class="ibtn" href="#/">${icon('fwd')}</a>
      <button class="chip" id="surahChip"></button>
      <a class="ibtn" href="#/search">${icon('search')}</a>
      <span class="sp"></span>
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
  document.body.classList.add('no-player');
  goTo(start, false);

  let ticking = false;
  pagesEl.addEventListener('scroll', () => {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(() => { ticking = false; onScroll(m, names); });
  }, { passive: true });
  addEventListener('resize', onResize);

  pagesEl.addEventListener('click', (e) => {
    const w = e.target.closest('span[data-a]');
    const a = w ? +w.dataset.a : 0;
    if (a) ayahMenu(a, m, names); else root.classList.toggle('immersive');
  });
  $('#surahChip', root).onclick = () => openIndex(m, names);
  $('#juzChip', root).onclick = () => openIndex(m, names, 1);
  $('#pageChip', root).onclick = () => openIndex(m, names, 1);
  $('#tasmee', root).onclick = () => (location.hash = `#/tasmee/${page}`);
  $('#mark', root).onclick = () => toggleMark(m);
  $('#playPage', root).onclick = () => playFrom(m.page.indexOf(page) + 1, m, names);
  offPlayer = player.on((it) => highlight(it?.ayah ?? 0, m));
  highlight(player.current?.ayah ?? 0, m);
  update(m, names);
}

export function leave() {
  removeEventListener('resize', onResize);
  offPlayer?.();
  document.body.classList.remove('no-player');
}

function pageEl(p) { return pagesEl.children[p - 1]; }

function goTo(p, smooth = true) {
  page = p;
  pageEl(p).scrollIntoView({ behavior: smooth ? 'smooth' : 'instant', inline: 'center', block: 'nearest' });
  drawAround(p);
}

function onScroll(m, names) {
  const w = pagesEl.clientWidth || 1;
  const p = Math.min(PAGES, Math.max(1, Math.round(Math.abs(pagesEl.scrollLeft) / w) + 1));
  if (p === page) return;
  page = p;
  drawAround(p);
  update(m, names);
}

let resizeTimer;
function onResize() {
  clearTimeout(resizeTimer);
  resizeTimer = setTimeout(() => {
    for (const s of $$('.mpage .inner[data-drawn]', pagesEl)) { delete s.dataset.drawn; s.innerHTML = ''; }
    goTo(page, false);
  }, 150);
}

function drawAround(p) {
  for (let q = p - 1; q <= p + 1; q++) {
    if (q < 1 || q > PAGES) continue;
    const inner = pageEl(q).firstElementChild;
    if (+inner.dataset.drawn !== q) drawPage(inner, q).then(() => q === page && highlight(player.current?.ayah ?? 0));
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
  log[d] = [...new Set([...(log[d] || []), page])];
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
    if (p !== page) goTo(p);
  }
}

function toggleMark(m) {
  const marks = store.get('marks', []);
  const i = marks.findIndex((x) => x.page === page);
  if (i >= 0) { marks.splice(i, 1); toast('أُزيلت العلامة'); } else { marks.unshift({ page, at: Date.now(), ayah: m.page.indexOf(page) + 1 }); toast('حُفظ موضع القراءة'); }
  store.set('marks', marks);
  $('#mark', root).innerHTML = icon(i >= 0 ? 'bookmarkO' : 'bookmark');
}

function label(g, m, names) { return `${names[m.surah[g - 1] - 1][1]} • ${ar(m.ayah[g - 1])}`; }

function playFrom(g, m, names) {
  const s = m.surah[g - 1];
  let end = g;
  while (end < m.surah.length && m.surah[end] === s) end++;
  player.play(ayahItems(g, end, null, (x) => `سورة ${label(x, m, names)}`), `سورة ${names[s - 1][1]}`);
}

async function ayahMenu(a, m, names) {
  for (const s of $$('span.sel', pagesEl)) s.classList.remove('sel');
  for (const s of $$(`span[data-a="${a}"]`, pagesEl)) s.classList.add('sel');
  const text = await ayahText(a);
  const name = names[m.surah[a - 1] - 1][1];
  await sheet(`<h3>سورة ${esc(name)} • الآية ${ar(m.ayah[a - 1])}</h3>
    <div class="list">
      <button data-x="play">${icon('play')}<span class="grow">الاستماع من هذه الآية</span></button>
      <button data-x="tafsir">${icon('book')}<span class="grow">التفسير الميسر</span></button>
      <button data-x="tasmee">${icon('mic')}<span class="grow">سمّع من هذه الآية</span></button>
      <button data-x="hifz">${icon('repeat')}<span class="grow">احفظ هذه الآية (تكرار)</span></button>
      <button data-x="copy">${icon('copy')}<span class="grow">نسخ الآية</span></button>
      <button data-x="share">${icon('share')}<span class="grow">مشاركة</span></button>
    </div>`, (body, close) => {
    body.onclick = async (e) => {
      const x = e.target.closest('[data-x]')?.dataset.x;
      if (!x) return;
      const ref = `﴿${text}﴾ [${name}: ${ar(m.ayah[a - 1])}]`;
      if (x === 'play') { close(); playFrom(a, m, names); }
      if (x === 'tafsir') { close(); setTimeout(() => tafsir(a, m, names), 50); }
      if (x === 'tasmee') { close(); location.hash = `#/tasmee/${m.page[a - 1]}/${a}`; }
      if (x === 'hifz') { close(); location.hash = `#/hifz/${a}`; }
      if (x === 'copy') { close(); navigator.clipboard?.writeText(ref).then(() => toast('نُسخت الآية')); }
      if (x === 'share') { close(); if (navigator.share) navigator.share({ text: ref }).catch(() => {}); else navigator.clipboard?.writeText(ref).then(() => toast('نُسخت الآية')); }
    };
  });
  for (const s of $$('span.sel', pagesEl)) s.classList.remove('sel');
}

async function tafsir(a, m, names) {
  const t = await data(`t/${m.page[a - 1]}.json`);
  const text = await ayahText(a);
  await sheet(`<h3>التفسير الميسر</h3>
    <div class="quran center">${esc(text)}</div>
    <p class="muted small center">سورة ${esc(names[m.surah[a - 1] - 1][1])} • الآية ${ar(m.ayah[a - 1])}</p>
    <div class="card" style="line-height:2">${esc(t[a] ?? '')}</div>`);
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
        `<a href="#/mushaf/${surahPage(s[0])}" data-go="${surahPage(s[0])}"><span class="num">${ar(s[0])}</span><span class="grow"><b>سورة ${esc(s[1])}</b><br><small class="muted">${s[3] ? 'مكية' : 'مدنية'} • ${ar(s[2])} آية</small></span><small class="muted">${ar(surahPage(s[0]))}</small></a>`).join('');
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
