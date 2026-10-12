// One audio player for the whole site: ayah-by-ayah recitation (with the
// ayah highlighted in the Mushaf), full surahs, radio stations. A small bar
// above the navigation shows what is playing; tapping it opens the full
// player (seek, previous/next, speed, repetition).
import { $, ar, icon, esc, store, data, meta, surahs, sheet } from './app.js';

const audio = new Audio();
audio.preload = 'auto';
let queue = [];
let index = 0;
let title = '';
let live = false;
let repeatEach = 1, played = 0;
let rangeRepeat = 1, rangePlayed = 0;
const listeners = new Set();
let sleepAt = 0, sleepEnd = false, sleepTick = 0, metaCache = null;

export const CDN = 'https://cdn.islamic.network/quran/audio';

export const player = {
  get playing() { return !audio.paused; },
  get current() { return queue[index]; },
  get title() { return title; },
  on(f) { listeners.add(f); return () => listeners.delete(f); },

  /// items: [{url, label, ayah?}], each repeated [each] times, the whole
  /// [times] times (0: forever).
  play(items, name, { start = 0, each = 1, times = 1, isLive = false } = {}) {
    queue = items;
    index = start;
    title = name;
    live = isLive;
    repeatEach = each; played = 0;
    rangeRepeat = times; rangePlayed = 0;
    load();
  },
  toggle() {
    if (!queue.length) return;
    if (audio.paused) audio.play().catch(() => {}); else audio.pause();
  },
  next() { if (index + 1 < queue.length) { index++; played = 0; load(); } },
  prev() {
    if (audio.currentTime > 3 && !live) { audio.currentTime = 0; return; }
    if (index > 0) { index--; played = 0; load(); }
  },
  stop() { remember(); audio.pause(); queue = []; cancelSleep(); document.body.classList.remove('playing'); render(); emit(); },
  open: () => openPlayer(),

  /// «تابع الاستماع»: the last recitation, from where it stopped.
  get resumePoint() { return store.get('resume', null); },
  resume() {
    const r = store.get('resume', null);
    if (!r?.items?.length) return false;
    this.play(r.items, r.title, { start: Math.min(r.index, r.items.length - 1) });
    if (r.time > 3) audio.addEventListener('loadedmetadata', () => { audio.currentTime = r.time; }, { once: true });
    return true;
  },

  /// The sleep timer: minutes, or 'surah' for the end of the surah, or 0 to cancel.
  sleep(v) {
    cancelSleep();
    if (v === 'surah') { sleepEnd = true; meta().then((m) => { metaCache = m; }); }
    else if (v > 0) {
      sleepAt = Date.now() + v * 60000;
      sleepTick = setInterval(() => {
        const left = sleepAt - Date.now();
        if (left <= 0) { audio.pause(); cancelSleep(); }
        else if (left < 10000) audio.volume = left / 10000;
        paintSleep();
      }, 1000);
    }
    paintSleep();
  },
  get sleepState() { return sleepEnd ? 'surah' : sleepAt ? sleepAt - Date.now() : 0; },
};

function cancelSleep() {
  clearInterval(sleepTick);
  sleepAt = 0; sleepEnd = false; sleepTick = 0;
  audio.volume = 1;
  paintSleep();
}

const surahOf = (it) => it?.surah ?? (it?.ayah && metaCache ? metaCache.surah[it.ayah - 1] : null);

/// Saved after each item and on pause: the queue (from a little before the
/// current item), where, and the title. Radio is not saved.
function remember() {
  if (live || !queue.length) return;
  const from = Math.max(0, index - 2);
  store.set('resume', { items: queue.slice(from, from + 320), index: index - from, title, time: audio.currentTime || 0,
    label: queue[index]?.label || title });
}

function load() {
  const it = queue[index];
  if (!it) return;
  audio.src = it.url;
  audio.playbackRate = live ? 1 : store.get('rate', 1);
  audio.play().catch(() => {});
  render();
  emit();
  if ('mediaSession' in navigator) {
    navigator.mediaSession.metadata = new MediaMetadata({ title: it.label || title, artist: title, album: 'الهدى',
      artwork: [{ src: 'icons/Icon-512.png', sizes: '512x512', type: 'image/png' }] });
    navigator.mediaSession.setActionHandler('nexttrack', () => player.next());
    navigator.mediaSession.setActionHandler('previoustrack', () => player.prev());
  }
}

function emit() { for (const f of listeners) f(queue[index] ?? null, !audio.paused); }

audio.addEventListener('ended', () => {
  if (live) return;
  played++;
  if (played < repeatEach) { audio.currentTime = 0; audio.play(); return; }
  played = 0;
  // «End of the surah»: the next item is another surah (or this one was a whole surah).
  if (sleepEnd) {
    const cur = queue[index], nxt = queue[index + 1];
    if (!nxt || cur?.surah || surahOf(nxt) !== surahOf(cur)) { cancelSleep(); index = Math.min(index + 1, queue.length - 1); remember(); player.stop(); return; }
  }
  if (index + 1 < queue.length) { index++; load(); return; }
  rangePlayed++;
  if (rangeRepeat === 0 || rangePlayed < rangeRepeat) { index = 0; load(); return; }
  player.stop();
});
audio.addEventListener('play', () => { render(); emit(); remember(); });
audio.addEventListener('pause', () => { render(); emit(); remember(); });
audio.addEventListener('timeupdate', progress);
audio.addEventListener('error', () => {
  const it = queue[index];
  // Radios have mirrors: try the next one.
  if (it?.alt?.length) { it.url = it.alt.shift(); load(); }
});

const fmt = (s) => (isFinite(s) ? ar(`${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`) : '');

function progress() {
  const p = audio.duration ? (audio.currentTime / audio.duration) * 100 : 0;
  const bar = $('#player .pline > i');
  if (bar) bar.style.width = `${p}%`;
  const big = $('#fp');
  if (!big) return;
  const r = $('#fpSeek', big);
  if (r && !r.matches(':active')) r.value = String(p);
  $('#fpT0', big).textContent = fmt(audio.currentTime);
  $('#fpT1', big).textContent = fmt(audio.duration);
}

function render() {
  const bar = $('#player');
  const it = queue[index];
  document.body.classList.toggle('playing', !!it);
  if (!it) { bar.hidden = true; paintBig(); return; }
  bar.hidden = false;
  bar.innerHTML = `<button class="pbtn" id="pp" aria-label="${audio.paused ? 'تشغيل' : 'إيقاف مؤقت'}">${icon(audio.paused ? 'play' : 'pause')}</button>
    <button class="grow" id="po" style="text-align:right"><b>${esc(it.label || title)}</b><small>${esc(title)}${live ? '، <span class="live">مباشر</span>' : ''}</small></button>
    ${live ? '' : `<button class="pbtn ghost" id="pn" aria-label="التالي">${icon('next')}</button>`}
    <button class="pbtn ghost" id="px" aria-label="إغلاق">${icon('close')}</button>
    ${live ? '' : '<div class="pline"><i></i></div>'}`;
  bar.querySelector('#pp').onclick = () => player.toggle();
  bar.querySelector('#po').onclick = () => openPlayer();
  bar.querySelector('#pn')?.addEventListener('click', () => player.next());
  bar.querySelector('#px').onclick = () => player.stop();
  progress();
  paintBig();
}

// ------------------------------------------------------- the full player ---
function paintBig() {
  const big = $('#fp');
  if (!big) return;
  const it = queue[index];
  if (!it) { big.innerHTML = '<p class="muted center">لا يوجد تشغيل الآن</p>'; return; }
  $('#fpL', big).textContent = it.label || title;
  $('#fpS', big).textContent = live ? 'بث مباشر' : `${title}${queue.length > 1 ? `، ${ar(index + 1)} من ${ar(queue.length)}` : ''}`;
  $('#fpPP', big).innerHTML = icon(audio.paused ? 'play' : 'pause');
  const rep = [];
  if (repeatEach > 1) rep.push(`تكرار كل آية ${ar(repeatEach)} مرات (الآن ${ar(played + 1)})`);
  if (rangeRepeat !== 1) rep.push(rangeRepeat === 0 ? 'تكرار المقطع بلا توقف' : `تكرار المقطع ${ar(rangeRepeat)} مرات (الآن ${ar(rangePlayed + 1)})`);
  $('#fpR', big).textContent = rep.join('، ');
  progress();
}

function openPlayer() {
  if (!queue[index]) return;
  const rate = store.get('rate', 1);
  sheet(`<div id="fp" class="fp">
      <div class="fp-art ${audio.paused ? '' : 'on'}">${icon(live ? 'radio' : 'head')}</div>
      <h3 id="fpL" style="margin-bottom:2px"></h3>
      <p class="muted small center" id="fpS" style="margin:0"></p>
      ${live ? '' : `<input type="range" id="fpSeek" min="0" max="100" step="0.1" value="0" class="seek">
      <div class="row small muted" style="justify-content:space-between"><span id="fpT0"></span><span id="fpT1"></span></div>`}
      <div class="row" style="justify-content:center;gap:18px;margin:10px 0">
        ${live ? '' : `<button class="pbtn ghost big2" id="fpN" aria-label="التالي">${icon('next')}</button>`}
        <button class="pbtn big" id="fpPP"></button>
        ${live ? '' : `<button class="pbtn ghost big2" id="fpP" aria-label="السابق">${icon('prev')}</button>`}
      </div>
      <p class="gold small center" id="fpR"></p>
      ${live ? '' : `<div class="chips" style="justify-content:center">${[0.75, 1, 1.25, 1.5].map((r) => `<button class="chip${r === rate ? ' on' : ''}" data-rate="${r}">${ar(r)}×</button>`).join('')}</div>`}
      <div class="section" style="margin-top:14px">مؤقت النوم</div>
      <div class="chips" id="fpSl" style="justify-content:center">${[[0, 'بدون'], [10, '١٠ د'], [15, '١٥ د'], [30, '٣٠ د'], [45, '٤٥ د'], [60, '٦٠ د'], ...(live ? [] : [['surah', 'نهاية السورة']])].map(([v, t]) =>
        `<button class="chip" data-sleep="${v}">${t}</button>`).join('')}</div>
      <p class="small center gold" id="fpSlS"></p>
      <button class="btn ghost block" id="fpX" style="margin-top:14px">${icon('stop')} إيقاف التشغيل</button>
    </div>`, (body, close) => {
    paintBig();
    $('#fpPP', body).onclick = () => player.toggle();
    $('#fpN', body)?.addEventListener('click', () => player.next());
    $('#fpP', body)?.addEventListener('click', () => player.prev());
    $('#fpX', body).onclick = () => { player.stop(); close(); };
    const seek = $('#fpSeek', body);
    if (seek) seek.oninput = () => { if (audio.duration) audio.currentTime = (seek.value / 100) * audio.duration; };
    paintSleep();
    body.onclick = (e) => {
      const sl = e.target.closest('[data-sleep]');
      if (sl) { const v = sl.dataset.sleep; player.sleep(v === 'surah' ? 'surah' : +v); return; }
      const b = e.target.closest('[data-rate]');
      if (!b) return;
      store.set('rate', +b.dataset.rate);
      audio.playbackRate = +b.dataset.rate;
      for (const c of body.querySelectorAll('[data-rate]')) c.classList.toggle('on', c === b);
    };
    const art = $('.fp-art', body);
    const off = player.on((_, playing) => art?.classList.toggle('on', playing));
    const mo = new MutationObserver(() => { if (!body.contains(art)) { off(); mo.disconnect(); } });
    mo.observe(body, { childList: true });
  });
}

function paintSleep() {
  const st = $('#fpSlS');
  if (!st) return;
  const s = player.sleepState;
  for (const c of document.querySelectorAll('[data-sleep]')) {
    const v = c.dataset.sleep;
    c.classList.toggle('on', s === 'surah' ? v === 'surah' : (!s && v === '0'));
  }
  st.textContent = s === 'surah' ? 'تتوقف التلاوة عند نهاية السورة' : s > 0 ? `تتوقف بعد ${fmt(s / 1000)}` : '';
}

/// Ayah recitation: global ayah numbers from [from] to [to].
export function ayahItems(from, to, reciter, labelOf) {
  const r = reciter ?? store.get('reciter', { id: 'ar.alafasy', bitrate: 128 });
  const out = [];
  for (let g = from; g <= to; g++) out.push({ url: `${CDN}/${r.bitrate}/${r.id}/${g}.mp3`, ayah: g, label: labelOf?.(g) });
  return out;
}

/// «استماع»: choose from which ayah to which, the repetitions and the
/// reciter, then play. [g]: the global ayah to start from.
export async function listenSheet(g) {
  const [m, names, reciters] = await Promise.all([meta(), surahs(), data('reciters.json')]);
  const opts = store.get('listen', { each: 1, times: 1 });
  const rec = store.get('reciter', { id: 'ar.alafasy', bitrate: 128 });
  let s = m.surah[g - 1];
  let f = m.ayah[g - 1];
  let t = names[s - 1][2];
  sheet(`<h3>الاستماع</h3>
    <label class="small muted">السورة</label>
    <select class="field" id="ls">${names.map((x) => `<option value="${x[0]}"${x[0] === s ? ' selected' : ''}>${ar(x[0])}. ${esc(x[1])}</option>`).join('')}</select>
    <div class="grid" style="margin-top:10px;grid-template-columns:1fr 1fr">
      <div><label class="small muted">من الآية</label><select class="field" id="lf"></select></div>
      <div><label class="small muted">إلى الآية</label><select class="field" id="lt"></select></div>
    </div>
    <div class="row" style="margin-top:14px"><span class="grow">تكرار كل آية</span><button class="chip" data-d="each,-1">−</button><b id="le" class="cnt"></b><button class="chip" data-d="each,1">+</button></div>
    <div class="row" style="margin-top:10px"><span class="grow">تكرار المقطع</span><button class="chip" data-d="times,-1">−</button><b id="lr" class="cnt"></b><button class="chip" data-d="times,1">+</button></div>
    <label class="small muted" style="display:block;margin-top:14px">القارئ</label>
    <select class="field" id="lq">${reciters.map((r) => `<option value="${r.id}"${r.id === rec.id ? ' selected' : ''}>${esc(r.name)}${r.style ? '، ' + esc(r.style) : ''}</option>`).join('')}</select>
    <button class="btn block" id="lgo" style="margin-top:16px">${icon('play')} تشغيل</button>`, (body, close) => {
    const fill = () => {
      const n = names[s - 1][2];
      f = Math.min(f, n); t = Math.min(Math.max(t, f), n);
      const opt = (v, min) => Array.from({ length: n - min + 1 }, (_, i) => i + min).map((a) => `<option${a === v ? ' selected' : ''}>${a}</option>`).join('');
      $('#lf', body).innerHTML = opt(f, 1);
      $('#lt', body).innerHTML = opt(t, f);
      $('#le', body).textContent = ar(opts.each);
      $('#lr', body).textContent = opts.times ? ar(opts.times) : '∞';
    };
    fill();
    $('#ls', body).onchange = (e) => { s = +e.target.value; f = 1; t = names[s - 1][2]; fill(); };
    $('#lf', body).onchange = (e) => { f = +e.target.value; fill(); };
    $('#lt', body).onchange = (e) => { t = +e.target.value; fill(); };
    body.onclick = (e) => {
      const d = e.target.closest('[data-d]');
      if (d) {
        const [k, v] = d.dataset.d.split(',');
        opts[k] = Math.max(k === 'times' ? 0 : 1, Math.min(20, opts[k] + +v));
        fill();
        return;
      }
      if (!e.target.closest('#lgo')) return;
      const r = reciters.find((x) => x.id === $('#lq', body).value) || reciters[0];
      store.set('reciter', { id: r.id, bitrate: r.bitrate });
      store.set('listen', opts);
      const g0 = m.surah.indexOf(s) + f;
      close();
      player.play(ayahItems(g0, g0 + (t - f), { id: r.id, bitrate: r.bitrate }, (x) => `سورة ${names[s - 1][1]}، الآية ${ar(m.ayah[x - 1])}`),
        `${r.name}، سورة ${names[s - 1][1]}`, { each: opts.each, times: opts.times });
    };
  });
}
