// الصوتيات: full-surah recitations of famous reciters, Quran radio stations
// and the live broadcast from the Two Holy Mosques.
import { $, $$, ar, esc, icon, store, data, surahs, top, toast } from './app.js';
import { player } from './player.js';

const REGIONS = { eg: 'قراء مصر', gulf: 'قراء الحرمين والخليج', other: 'قراء آخرون' };
const TABS = ['القراء', 'الإذاعات', 'البث المباشر'];
let hls;

export async function show(view, args) {
  const media = await data('media.json');
  if (args[0] === 'r' && args[1]) return reciter(view, media, args[1]);
  if (args[0] === 'live' && args[1] != null) return live(view, media.live[+args[1]]);
  const tab = Math.min(2, +store.get('mediaTab', 0) || 0);
  view.innerHTML = top('الصوتيات', 'تلاوات وإذاعات وبث مباشر', 'amethyst', 'head', false) +
    `<div class="chips" id="tabs" style="margin-bottom:12px">${TABS.map((t, i) => `<button class="chip${i === tab ? ' on' : ''}" data-t="${i}">${t}</button>`).join('')}</div><div id="body"></div>`;
  const body = $('#body', view);
  const render = (t) => {
    store.set('mediaTab', t);
    if (t === 0) {
      const fav = new Set(media.featured);
      body.innerHTML = `<input class="field" id="q" placeholder="ابحث عن قارئ" style="margin-bottom:12px"><div id="rl"></div>`;
      const list = (q) => {
        const rs = media.reciters.filter((r) => !q || r.name.includes(q));
        const group = (title, items) => items.length ? `<div class="section">${title}</div><div class="card list">${items.map((r) =>
          `<a href="#/media/r/${r.key}"><span class="num">${icon('head')}</span><span class="grow"><b>${esc(r.name)}</b><br><small class="muted">${esc(r.style)}</small></span>${icon('fwd', 'muted')}</a>`).join('')}</div>` : '';
        $('#rl', body).innerHTML = (q ? '' : group('المختارون', rs.filter((r) => fav.has(r.key)))) +
          Object.entries(REGIONS).map(([k, v]) => group(v, rs.filter((r) => r.region === k))).join('');
      };
      list('');
      $('#q', body).oninput = (e) => list(e.target.value.trim());
    } else if (t === 1) {
      const section = (title, items) => `<div class="section">${title}</div><div class="card list">${items.map((r, i) =>
        `<button data-r="${title}|${i}"><span class="num">${icon('radio')}</span><span class="grow"><b>${esc(r.name)}</b>${r.subtitle ? `<br><small class="muted">${esc(r.subtitle)}</small>` : ''}</span>${icon('play', 'gold')}</button>`).join('')}</div>`;
      const groups = { 'الإذاعات الرسمية': media.official, 'إذاعات القراء': media.reciterRadios, 'إذاعات متنوعة': media.themeRadios };
      body.innerHTML = Object.entries(groups).map(([k, v]) => section(k, v)).join('');
      body.onclick = (e) => {
        const b = e.target.closest('[data-r]');
        if (!b) return;
        const [g, i] = b.dataset.r.split('|');
        const r = groups[g][+i];
        player.play([{ url: r.urls[0], alt: r.urls.slice(1), label: r.name }], 'بث مباشر', { isLive: true });
        toast(`جارٍ تشغيل ${r.name}`);
      };
    } else {
      body.innerHTML = media.live.map((l, i) => `<a class="card solid t-${i ? 'emerald' : 'amber'} tile" href="#/media/live/${i}" style="margin-bottom:12px">${icon('tv')}<b style="font-size:20px">${esc(l.title)}</b><small>${esc(l.subtitle)}</small></a>`).join('');
    }
  };
  render(tab);
  $('#tabs', view).onclick = (e) => {
    const c = e.target.closest('[data-t]');
    if (!c) return;
    body.onclick = null;
    $$('[data-t]', view).forEach((b) => b.classList.toggle('on', b === c));
    render(+c.dataset.t);
  };
}

async function reciter(view, media, key) {
  const r = media.reciters.find((x) => x.key === key);
  if (!r) { location.hash = '#/media'; return; }
  const names = await surahs();
  const url = (n) => `${r.server}${String(n).padStart(3, '0')}.mp3`;
  const items = names.map((s) => ({ url: url(s[0]), label: `سورة ${s[1]}`, surah: s[0] }));
  view.innerHTML = top(r.name, r.style, 'amethyst', 'head') + `
    <div class="row" style="gap:10px;margin-bottom:12px">
      <button class="btn" id="all">${icon('play')} تشغيل الكل</button>
      <input class="field grow" id="q" placeholder="ابحث عن سورة">
    </div>
    <div class="card list" id="sl"></div>`;
  const list = (q) => {
    $('#sl', view).innerHTML = names.filter((s) => !q || s[1].includes(q) || String(s[0]) === q).map((s) =>
      `<button data-s="${s[0]}"><span class="num">${ar(s[0])}</span><span class="grow"><b>سورة ${esc(s[1])}</b><br><small class="muted">${ar(s[2])} آية</small></span>${icon('play', 'gold')}</button>`).join('');
  };
  list('');
  $('#q', view).oninput = (e) => list(e.target.value.trim());
  $('#all', view).onclick = () => player.play(items, r.name);
  $('#sl', view).onclick = (e) => {
    const b = e.target.closest('[data-s]');
    if (b) player.play(items, r.name, { start: +b.dataset.s - 1 });
  };
}

async function live(view, l) {
  if (!l) { location.hash = '#/media'; return; }
  player.stop();
  view.innerHTML = top(l.title, l.subtitle, 'amber', 'tv') + `
    <video id="v" controls playsinline autoplay style="width:100%;aspect-ratio:16/9;border-radius:18px;background:#000"></video>
    <p class="muted small center" id="st">جارٍ الاتصال بالبث…</p>`;
  const v = $('#v', view);
  const src = l.urls[0];
  v.onplaying = () => { $('#st', view).textContent = 'بث مباشر'; };
  v.onerror = () => { $('#st', view).textContent = 'تعذر تشغيل البث الآن، حاول لاحقًا.'; };
  if (v.canPlayType('application/vnd.apple.mpegurl')) { v.src = src; return; }
  try {
    await new Promise((ok, fail) => {
      if (window.Hls) return ok();
      const s = document.createElement('script');
      s.src = 'https://cdnjs.cloudflare.com/ajax/libs/hls.js/1.5.13/hls.min.js';
      s.onload = ok; s.onerror = fail;
      document.head.appendChild(s);
    });
    if (!v.isConnected) return;
    hls = new window.Hls();
    hls.loadSource(src);
    hls.attachMedia(v);
    hls.on(window.Hls.Events.ERROR, (_, d) => { if (d.fatal) $('#st', view).textContent = 'تعذر تشغيل البث الآن، حاول لاحقًا.'; });
  } catch {
    $('#st', view).textContent = 'المتصفح لا يدعم هذا البث.';
  }
}

export function leave() {
  hls?.destroy(); hls = null;
  const b = $('#body'); if (b) b.onclick = null;
}
