// الصوتيات: full-surah recitations of famous reciters, Quran radio stations
// and the live broadcast from the Two Holy Mosques.
import { $, $$, ar, esc, icon, store, data, surahs, top, toast } from './app.js';
import { player } from './player.js';
import { PHOTOS } from './reciters.js';

const REGIONS = { eg: 'قراء مصر', gulf: 'قراء الحرمين والخليج', other: 'قراء آخرون' };
const TABS = [['القراء', 'head'], ['الإذاعات', 'radio'], ['البث المباشر', 'tv']];
const TONES = ['emerald', 'sapphire', 'amethyst', 'rose', 'amber', 'teal', 'sky', 'coral'];
let hls, off;

const tone = (key) => TONES[[...key].reduce((a, c) => a + c.charCodeAt(0), 0) % TONES.length];
// The family name (الحصري، المنشاوي…) on the big avatars, an icon on the small.
const family = (name) => name.replace(/\s*[•(].*$/, '').trim().split(/\s+/).slice(-1)[0];
const avatar = (r, size = '') => {
  const k = (r.key || '').replace('_mj', '');
  if (PHOTOS.has(k)) return `<img class="ava photo ${size}" src="img/reciters/${k}.jpg" alt="${esc(r.name)}" width="104" height="104" loading="lazy" decoding="async">`;
  return `<span class="ava ${size} t-${tone(r.key || r.name)}">${size ? `<em>${esc(family(r.name))}</em>` : icon('head')}</span>`;
};
const eq = '<span class="eq"><i></i><i></i><i></i></span>';

export async function show(view, args) {
  const media = await data('media.json');
  if (args[0] === 'r' && args[1]) return reciter(view, media, args[1]);
  if (args[0] === 'live' && args[1] != null) return live(view, media.live[+args[1]]);
  let tab = Math.min(2, +store.get('mediaTab', 0) || 0);
  view.innerHTML = top('الصوتيات', 'تلاوات وإذاعات وبث مباشر', 'amethyst', 'head', false) +
    `<div class="seg" id="tabs" style="--n:3;--i:${tab}"><i></i>${TABS.map(([t, ic], i) => `<button data-t="${i}" class="${i === tab ? 'on' : ''}">${icon(ic)}<span>${t}</span></button>`).join('')}</div>
     <div id="body"></div>`;
  const body = $('#body', view);
  const render = (anim = true) => {
    store.set('mediaTab', tab);
    if (anim) { body.classList.remove('tabin'); void body.offsetWidth; body.classList.add('tabin'); }
    if (tab === 0) {
      const fav = media.featured.map((k) => media.reciters.find((r) => r.key === k)).filter(Boolean);
      body.innerHTML = `
        <div class="section">المختارون</div>
        <div class="hscroll">${fav.map((r) => `<a class="favr" href="#/media/r/${r.key}">${avatar(r, 'lg')}<b>${esc(r.name)}</b><small class="muted">${esc(r.style)}</small></a>`).join('')}</div>
        <div class="search" style="margin-top:18px">${icon('search')}<input class="field" id="q" placeholder="ابحث عن قارئ" type="search"></div>
        <div id="rl"></div>`;
      const list = (q) => {
        const rs = media.reciters.filter((r) => !q || r.name.includes(q));
        $('#rl', body).innerHTML = Object.entries(REGIONS).map(([k, v]) => {
          const items = rs.filter((r) => r.region === k);
          return items.length ? `<div class="section">${v}</div><div class="rgrid">${items.map((r) =>
            `<a class="card rcard" href="#/media/r/${r.key}">${avatar(r)}<span class="grow"><b>${esc(r.name)}</b><small class="muted">${esc(r.style)}</small></span></a>`).join('')}</div>` : '';
        }).join('') || '<p class="muted center">لا يوجد قارئ بهذا الاسم</p>';
      };
      list('');
      $('#q', body).oninput = (e) => list(e.target.value.trim());
    } else if (tab === 1) {
      const now = player.current?.url;
      const playingAny = (r) => r.urls.includes(now) || (player.current?.label === r.name && player.title === 'بث مباشر');
      body.innerHTML = `
        <div class="section">الإذاعات الرسمية</div>
        <div class="grid">${media.official.map((r, i) => `<button class="card solid t-${i ? 'emerald' : 'sapphire'} radio-hero${playingAny(r) ? ' playing' : ''}" data-r="official|${i}">
          <span class="row" style="width:100%">${icon('radio')}<span class="grow"></span>${playingAny(r) ? eq : `<span class="pbtn">${icon('play')}</span>`}</span>
          <b>${esc(r.name)}</b><small>${esc(r.subtitle || '')}</small></button>`).join('')}</div>
        <div class="section">إذاعات القراء</div>
        <div class="rgrid">${media.reciterRadios.map((r, i) => `<button class="card rcard${playingAny(r) ? ' playing' : ''}" data-r="reciterRadios|${i}">${avatar({ key: r.reciter || r.name, name: r.name })}<span class="grow"><b>${esc(r.name)}</b><small class="muted">إذاعة على مدار الساعة</small></span>${playingAny(r) ? eq : icon('play', 'gold')}</button>`).join('')}</div>
        <div class="section">إذاعات متنوعة</div>
        <div class="rgrid">${media.themeRadios.map((r, i) => `<button class="card rcard${playingAny(r) ? ' playing' : ''}" data-r="themeRadios|${i}"><span class="ava t-${TONES[(i + 3) % TONES.length]}">${icon('radio')}</span><span class="grow"><b>${esc(r.name)}</b>${r.subtitle ? `<small class="muted">${esc(r.subtitle)}</small>` : ''}</span>${playingAny(r) ? eq : icon('play', 'gold')}</button>`).join('')}</div>`;
      body.onclick = (e) => {
        const b = e.target.closest('[data-r]');
        if (!b) return;
        const [g, i] = b.dataset.r.split('|');
        const r = media[g][+i];
        player.play([{ url: r.urls[0], alt: r.urls.slice(1), label: r.name }], 'بث مباشر', { isLive: true });
        toast(`جارٍ تشغيل ${r.name}`);
      };
    } else {
      body.innerHTML = media.live.map((l, i) => `<a class="card live-hero t-${i ? 'emerald' : 'amber'}" href="#/media/live/${i}">
        <span class="badge"><span class="live">مباشر</span></span>
        <span class="ticon t-${i ? 'emerald' : 'amber'}">${icon('tv')}</span>
        <b>${esc(l.title)}</b><small class="muted">${esc(l.subtitle)}</small>
        <span class="btn" style="margin-top:12px">${icon('play')} شاهد الآن</span></a>`).join('');
    }
  };
  render();
  off = player.on(() => { if (tab === 1) { const y = scrollY; render(false); scrollTo(0, y); } });
  $('#tabs', view).onclick = (e) => {
    const c = e.target.closest('[data-t]');
    if (!c || +c.dataset.t === tab) return;
    body.onclick = null;
    tab = +c.dataset.t;
    $('#tabs', view).style.setProperty('--i', tab);
    $$('[data-t]', view).forEach((b) => b.classList.toggle('on', b === c));
    render();
  };
}

async function reciter(view, media, key) {
  const r = media.reciters.find((x) => x.key === key);
  if (!r) { location.hash = '#/media'; return; }
  const names = await surahs();
  const url = (n) => `${r.server}${String(n).padStart(3, '0')}.mp3`;
  const items = names.map((s) => ({ url: url(s[0]), label: `سورة ${s[1]}`, surah: s[0] }));
  view.innerHTML = `<div class="top"><button class="back" onclick="history.length>1?history.back():location.hash='#/media'">${icon('fwd')}</button><span class="grow"></span></div>
    <div class="card wash t-${tone(r.key)} center rhead">${avatar(r, 'xl')}<h2>${esc(r.name)}</h2><small class="muted">${esc(r.style)}، ١١٤ سورة</small>
      <div class="row" style="justify-content:center;gap:10px;margin-top:14px">
        <button class="btn" id="all">${icon('play')} تشغيل الكل</button>
        <button class="btn ghost" id="shuf">${icon('repeat')} عشوائي</button>
      </div></div>
    <div class="search" style="margin:14px 0">${icon('search')}<input class="field" id="q" placeholder="ابحث عن سورة" type="search"></div>
    <div class="card list" id="sl"></div>`;
  const list = (q) => {
    const now = player.current?.url;
    $('#sl', view).innerHTML = names.filter((s) => !q || s[1].includes(q) || String(s[0]) === q).map((s) =>
      `<button data-s="${s[0]}" class="${now === url(s[0]) ? 'now' : ''}"><span class="num">${ar(s[0])}</span><span class="grow"><b>سورة ${esc(s[1])}</b><br><small class="muted">${s[3] ? 'مكية' : 'مدنية'}، ${ar(s[2])} آية</small></span>${now === url(s[0]) && player.playing ? eq : icon('play', 'gold')}</button>`).join('');
  };
  list('');
  $('#q', view).oninput = (e) => list(e.target.value.trim());
  $('#all', view).onclick = () => player.play(items, r.name);
  $('#shuf', view).onclick = () => player.play([...items].sort(() => Math.random() - 0.5), r.name);
  $('#sl', view).onclick = (e) => {
    const b = e.target.closest('[data-s]');
    if (b) player.play(items, r.name, { start: +b.dataset.s - 1 });
  };
  off = player.on(() => list($('#q', view)?.value.trim() || ''));
}

async function live(view, l) {
  if (!l) { location.hash = '#/media'; return; }
  player.stop();
  view.innerHTML = top(l.title, l.subtitle, 'amber', 'tv') + `
    <div class="video"><video id="v" controls playsinline autoplay></video><span class="badge"><span class="live">مباشر</span></span></div>
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
  off?.(); off = null;
}
