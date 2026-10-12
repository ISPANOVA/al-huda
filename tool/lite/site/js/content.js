// الأدعية، الفضائل، الرقية الشرعية: categories of texts with their sources.
import { $, $$, ar, esc, icon, data, top, toast } from './app.js';
import { player, ayahItems } from './player.js';
import { globalAyah, ayahText } from './page.js';
import { shareChoice } from './cards.js';

const RUQYAH_VERSES = [
  ['سورة الفاتحة', 1, 1, 7], ['أول سورة البقرة', 2, 1, 5], ['آية الكرسي', 2, 255, 255], ['خواتيم سورة البقرة', 2, 285, 286],
  ['من سورة آل عمران', 3, 18, 19], ['من سورة الأعراف', 7, 117, 122], ['من سورة يونس', 10, 79, 82], ['من سورة طه', 20, 65, 69],
  ['خواتيم سورة المؤمنون', 23, 115, 118], ['أول سورة الصافات', 37, 1, 10], ['من سورة الرحمن', 55, 33, 36], ['خواتيم سورة الحشر', 59, 21, 24],
  ['سورة الإخلاص', 112, 1, 4, 3], ['سورة الفلق', 113, 1, 5, 3], ['سورة الناس', 114, 1, 6, 3],
];
const RUQYAH_DUAS = [
  ['اللَّهُمَّ رَبَّ النَّاسِ، أَذْهِبِ الْبَأْسَ، اشْفِ أَنْتَ الشَّافِي، لَا شِفَاءَ إِلَّا شِفَاؤُكَ، شِفَاءً لَا يُغَادِرُ سَقَمًا.', 'متفق عليه'],
  ['بِسْمِ اللَّهِ أَرْقِيكَ، مِنْ كُلِّ شَيْءٍ يُؤْذِيكَ، مِنْ شَرِّ كُلِّ نَفْسٍ أَوْ عَيْنِ حَاسِدٍ، اللَّهُ يَشْفِيكَ، بِسْمِ اللَّهِ أَرْقِيكَ.', 'رواه مسلم'],
  ['ضع يدك على موضع الألم وقل: بِسْمِ اللَّهِ (ثلاثًا)، ثم: أَعُوذُ بِاللَّهِ وَقُدْرَتِهِ مِنْ شَرِّ مَا أَجِدُ وَأُحَاذِرُ.', 'رواه مسلم', '٧ مرات'],
  ['أَسْأَلُ اللَّهَ الْعَظِيمَ، رَبَّ الْعَرْشِ الْعَظِيمِ، أَنْ يَشْفِيَكَ.', 'رواه أبو داود والترمذي', '٧ مرات'],
  ['أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّةِ، مِنْ كُلِّ شَيْطَانٍ وَهَامَّةٍ، وَمِنْ كُلِّ عَيْنٍ لَامَّةٍ.', 'رواه البخاري'],
  ['أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ.', 'رواه مسلم', '٣ مرات'],
  ['بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ.', 'رواه أبو داود والترمذي', '٣ مرات'],
];

function item(text, source, extra = '', quran = false) {
  return `<div class="card" data-share data-src="${esc(source || '')}"${quran ? ' data-q' : ''}>
    <div class="${quran ? 'quran' : 'thikr'}" style="${quran ? '' : 'font-size:18px;line-height:2'}">${esc(text)}</div>
    <div class="row" style="margin-top:8px"><small class="grow muted">${esc(source || '')}${extra}</small>
    <button class="ibtn" data-sh aria-label="مشاركة">${icon('share')}</button></div></div>`;
}

export async function show(view, args, name) {
  if (name === 'ruqyah') return ruqyah(view, args);
  const virtues = name === 'virtues';
  const cats = await data(virtues ? 'virtues.json' : 'duas.json');
  const tone = virtues ? 'gold' : 'rose';
  const title = virtues ? 'الفضائل' : 'الأدعية';
  const sub = virtues ? 'فضل الذكر والقرآن والصلاة على النبي ﷺ' : 'أدعية من القرآن والسنة';
  let c = Math.min(cats.length - 1, +args[0] || 0);
  view.innerHTML = top(title, sub, tone, virtues ? 'star' : 'hands') +
    `<div class="chips" id="cats" style="margin-bottom:12px">${cats.map((x, i) => `<button class="chip${i === c ? ' on' : ''}" data-c="${i}">${esc(x.title)}</button>`).join('')}</div><div id="items"></div>`;
  const render = () => {
    const cat = cats[c];
    $('#items', view).innerHTML = (cat.subtitle ? `<p class="muted small center">${esc(cat.subtitle)}</p>` : '') +
      cat.items.map((d) => item(d.text, d.source, d.note ? `، ${esc(d.note)}` : '', !!d.quran)).join('');
  };
  render();
  view.onclick = (e) => {
    const b = e.target.closest('[data-c]');
    if (b) { c = +b.dataset.c; $$('[data-c]', view).forEach((x) => x.classList.toggle('on', x === b)); render(); scrollTo(0, 0); return; }
    const s = e.target.closest('[data-sh]');
    if (s) shareCard(s.closest('[data-share]'), virtues ? (s.closest('[data-share]').hasAttribute('data-q') ? 'من كتاب الله' : 'من السنة') : 'دعاء');
  };
}

/// A card of the list ([el]) shared as a picture or text.
function shareCard(el, title) {
  const body = el.querySelector('.quran,.thikr').textContent;
  const source = el.dataset.src || '';
  shareChoice({ title, body, source, quran: !!el.querySelector('.quran') }, source ? `${body}\n[${source}]` : body);
}

async function ruqyah(view, args) {
  let tab = +args[0] || 0;
  view.innerHTML = top('الرقية الشرعية', 'آيات وأدعية الرقية من الكتاب والسنة', 'sky', 'book') + `
    <div class="chips" style="justify-content:center;margin-bottom:8px"><button class="chip${tab ? '' : ' on'}" data-t="0">من القرآن</button><button class="chip${tab ? ' on' : ''}" data-t="1">من السنة</button></div>
    <p class="muted small center">تُقرأ بيقين وحضور قلب، مع النفث على موضع الألم أو في الماء، والله هو الشافي.</p><div id="items"></div>`;
  const render = async () => {
    const box = $('#items', view);
    if (tab === 1) { box.innerHTML = RUQYAH_DUAS.map(([t, s, r]) => item(t, s, r ? `، ${r}` : '')).join(''); return; }
    box.innerHTML = RUQYAH_VERSES.map(([t, s, f, to, n], i) => `<div class="card" data-share data-v="${i}">
      <div class="row"><b class="grow gold">${t}</b>${n ? `<small class="chip">${ar(n)} مرات</small>` : ''}<button class="ibtn" data-play="${i}">${icon('play')}</button><button class="ibtn" data-sh>${icon('share')}</button></div>
      <div class="quran" data-txt>…</div></div>`).join('');
    for (const [i, [, s, f, to]] of RUQYAH_VERSES.entries()) {
      const g = await globalAyah(s, f);
      const parts = [];
      for (let a = g; a <= g + (to - f); a++) parts.push(await ayahText(a) + ` ${ar(a - g + f)}`);
      const el = box.querySelector(`[data-v="${i}"] [data-txt]`);
      if (!el) return;
      el.textContent = parts.join(' ');
    }
  };
  render();
  view.onclick = async (e) => {
    const t = e.target.closest('[data-t]');
    if (t) { tab = +t.dataset.t; $$('[data-t]', view).forEach((x) => x.classList.toggle('on', x === t)); render(); return; }
    const p = e.target.closest('[data-play]');
    if (p) {
      const [title, s, f, to, n] = RUQYAH_VERSES[+p.dataset.play];
      const g = await globalAyah(s, f);
      player.play(ayahItems(g, g + (to - f), null, () => title), 'الرقية الشرعية', { times: n || 1 });
      return;
    }
    const s = e.target.closest('[data-sh]');
    if (s) { const el = s.closest('[data-share]'); shareCard(el, el.querySelector('b.gold')?.textContent || 'الرقية الشرعية'); }
  };
}

export function leave() { const v = document.getElementById('view'); if (v) v.onclick = null; }
