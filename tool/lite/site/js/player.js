// One audio player for the whole site: ayah-by-ayah recitation (with the
// ayah highlighted in the Mushaf), full surahs, radio stations. A small bar
// above the navigation shows what is playing.
import { $, icon, esc, store } from './app.js';

const audio = new Audio();
audio.preload = 'auto';
let queue = [];
let index = 0;
let title = '';
let live = false;
let repeatEach = 1, played = 0;
let rangeRepeat = 1, rangePlayed = 0;
const listeners = new Set();

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
  prev() { if (index > 0) { index--; played = 0; load(); } },
  stop() { audio.pause(); queue = []; render(); emit(); },
};

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
  if (index + 1 < queue.length) { index++; load(); return; }
  rangePlayed++;
  if (rangeRepeat === 0 || rangePlayed < rangeRepeat) { index = 0; load(); return; }
  queue = []; render(); emit();
});
audio.addEventListener('play', () => { render(); emit(); });
audio.addEventListener('pause', () => { render(); emit(); });
audio.addEventListener('error', () => {
  const it = queue[index];
  // Radios have mirrors: try the next one.
  if (it?.alt?.length) { it.url = it.alt.shift(); load(); }
});

function render() {
  const bar = $('#player');
  const it = queue[index];
  if (!it || document.body.classList.contains('no-player')) { bar.hidden = true; return; }
  bar.hidden = false;
  bar.innerHTML = `<button class="pbtn" id="pp">${icon(audio.paused ? 'play' : 'pause')}</button>
    <div class="grow"><b>${esc(it.label || title)}</b><small>${esc(title)}</small></div>
    ${live ? '' : `<button class="pbtn ghost" id="pn">${icon('prev')}</button>`}
    <button class="pbtn ghost" id="px">${icon('close')}</button>`;
  bar.querySelector('#pp').onclick = () => player.toggle();
  bar.querySelector('#pn')?.addEventListener('click', () => player.next());
  bar.querySelector('#px').onclick = () => player.stop();
}

/// Ayah recitation: global ayah numbers from [from] to [to].
export function ayahItems(from, to, reciter, labelOf) {
  const r = reciter ?? store.get('reciter', { id: 'ar.alafasy', bitrate: 128 });
  const out = [];
  for (let g = from; g <= to; g++) out.push({ url: `${CDN}/${r.bitrate}/${r.id}/${g}.mp3`, ayah: g, label: labelOf?.(g) });
  return out;
}
