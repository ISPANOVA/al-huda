// الأذكار: categories, a counter for every thikr, and today's progress.
import { $, $$, ar, esc, icon, store, data, top, today, toast } from './app.js';
import { player, ayahItems } from './player.js';
import { globalAyah } from './page.js';

const TONES = ['rose', 'amber', 'sapphire', 'emerald', 'amethyst', 'teal', 'sky', 'coral', 'gold', 'slate'];
const key = () => 'ath_' + today();

function progress() {
  const p = store.get(key(), null);
  if (p) return p;
  // Yesterday's counts are dropped: a fresh day.
  try { for (const k of Object.keys(localStorage)) if (k.startsWith('h_ath_')) localStorage.removeItem(k); } catch {}
  return {};
}

export async function show(view, args) {
  const cats = await data('athkar.json');
  const cat = args[0] && cats.find((c) => c.id === args[0]);
  if (cat) return showCategory(view, cat, cats.indexOf(cat));
  const p = progress();
  view.innerHTML = top('الأذكار', 'حصن المسلم في يومه وليلته', 'rose', 'heart', false) +
    `<div class="grid">${cats.map((c, i) => {
      const total = c.items.reduce((a, t) => a + t.count, 0);
      const done = c.items.reduce((a, t) => a + Math.min(p[t.id] || 0, t.count), 0);
      return `<a class="card tile wash t-${TONES[i % TONES.length]}" href="#/athkar/${c.id}">
        <div class="ticon t-${TONES[i % TONES.length]}" style="width:42px;height:42px">${icon('heart')}</div>
        <b>${esc(c.title)}</b><small>${esc(c.subtitle || '')}</small>
        <div class="bar" style="width:100%;margin-top:auto"><i style="width:${(done / total) * 100}%"></i></div></a>`;
    }).join('')}</div>
    <div class="grid" style="margin-top:12px">
      <a class="card tile wash t-sky" href="#/duas">${icon('hands')}<b>الأدعية</b><small>للكرب والسفر والمرض والاستخارة</small></a>
      <a class="card tile wash t-teal" href="#/ruqyah">${icon('book')}<b>الرقية الشرعية</b><small>من القرآن والسنة</small></a>
      <a class="card tile wash t-gold" href="#/virtues">${icon('star')}<b>الفضائل</b><small>فضل الذكر والقرآن</small></a>
      <a class="card tile wash t-emerald" href="#/tasbeeh">${icon('beads')}<b>المسبحة</b><small>عداد ذكي</small></a>
    </div>`;
}

function showCategory(view, cat, i) {
  const tone = TONES[i % TONES.length];
  const p = progress();
  const total = cat.items.reduce((a, t) => a + t.count, 0);
  const doneCount = () => cat.items.reduce((a, t) => a + Math.min(p[t.id] || 0, t.count), 0);
  view.innerHTML = top(cat.title, cat.subtitle || '', tone, 'heart') +
    `<div class="card wash t-${tone} row" style="margin-bottom:12px"><span class="grow"><b id="pt"></b><div class="bar" style="margin-top:6px"><i id="pb"></i></div></span>
      <button class="chip" id="reset">إعادة</button></div>
    <div id="list">${cat.items.map((t) => `
      <div class="card thikr" data-id="${t.id}">
        <div class="txt">${esc(t.text)}</div>
        ${t.virtue ? `<p class="small gold" style="margin:10px 0 0">${esc(t.virtue)}</p>` : ''}
        <p class="small muted" style="margin:6px 0 0">${esc(t.source || '')}</p>
        <div class="count">
          ${t.quran ? `<button class="chip" data-play="${t.quran.join(',')}">${icon('play')} استماع</button>` : '<span></span>'}
          <button class="counter" data-c>${''}</button>
        </div>
      </div>`).join('')}</div>`;
  const paint = () => {
    for (const el of $$('.thikr', view)) {
      const t = cat.items.find((x) => x.id === el.dataset.id);
      const n = Math.min(p[t.id] || 0, t.count);
      el.classList.toggle('done', n >= t.count);
      $('[data-c]', el).innerHTML = n >= t.count ? `${icon('check')} تمّ` : `${ar(t.count - n)}${t.count > 1 ? ` <small style="font-size:12px;opacity:.8">من ${ar(t.count)}</small>` : ''}`;
    }
    const d = doneCount();
    $('#pt', view).textContent = d >= total ? 'أتممت أذكارك، تقبّل الله' : `أنجزت ${ar(d)} من ${ar(total)}`;
    $('#pb', view).style.width = `${(d / total) * 100}%`;
  };
  paint();
  $('#list', view).onclick = async (e) => {
    const pl = e.target.closest('[data-play]');
    if (pl) {
      const [s, f, t] = pl.dataset.play.split(',').map(Number);
      const a = await globalAyah(s, f);
      player.play(ayahItems(a, a + (t - f)), cat.title);
      return;
    }
    const card = e.target.closest('.thikr');
    if (!card) return;
    const t = cat.items.find((x) => x.id === card.dataset.id);
    const n = p[t.id] || 0;
    if (n >= t.count) return;
    p[t.id] = n + 1;
    store.set(key(), p);
    navigator.vibrate?.(n + 1 >= t.count ? [20, 40, 20] : 12);
    paint();
    if (n + 1 >= t.count) {
      const next = card.nextElementSibling;
      if (next) setTimeout(() => next.scrollIntoView({ behavior: 'smooth', block: 'center' }), 250);
      if (doneCount() >= total) toast('أتممت أذكارك، تقبّل الله منك');
    }
  };
  $('#reset', view).onclick = () => { for (const t of cat.items) delete p[t.id]; store.set(key(), p); paint(); };
}
