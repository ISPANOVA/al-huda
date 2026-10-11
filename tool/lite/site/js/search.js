// البحث في القرآن: by any words of the ayah, without diacritics.
import { $, ar, esc, icon, data, meta, surahs, top } from './app.js';

const DIAC = /[ؐ-ًؚ-ٰٟۖ-ۭـ]/g;
export const norm = (s) => s.replace(DIAC, '').replace(/[أإآٱٲٳ]/g, 'ا').replace(/ى/g, 'ي').replace(/ئ/g, 'ي')
  .replace(/ؤ/g, 'و').replace(/ة/g, 'ه').replace(/[ۥۦ]/g, '').replace(/\s+/g, ' ').trim();
let keys;

export async function show(view, args) {
  view.innerHTML = top('البحث في القرآن', 'اكتب كلمة أو جزءًا من آية', 'sapphire', 'search') + `
    <input class="field" id="q" type="search" placeholder="مثال: الصبر" autocomplete="off" value="${esc(args[0] || '')}">
    <p class="muted small" id="n" style="margin:10px 4px"></p><div class="card list" id="res" hidden></div>`;
  const [texts, m, names] = await Promise.all([data('search.json'), meta(), surahs()]);
  keys ??= texts.map((t) => norm(t).replace(/ /g, ''));
  const q = $('#q', view), res = $('#res', view), n = $('#n', view);
  let timer;
  const run = () => {
    const k = norm(q.value).replace(/ /g, '');
    history.replaceState(history.state, '', `#/search/${encodeURIComponent(q.value.trim())}`);
    if (k.length < 2) { res.hidden = true; n.textContent = ''; return; }
    const hits = [];
    for (let i = 0; i < keys.length; i++) if (keys[i].includes(k)) hits.push(i);
    n.textContent = hits.length ? `${ar(hits.length)} نتيجة` : 'لا توجد نتائج';
    res.hidden = !hits.length;
    res.innerHTML = hits.slice(0, 200).map((i) => `<a href="#/mushaf/${m.page[i]}"><span class="grow"><span style="line-height:1.9">${esc(texts[i])}</span><br><small class="gold">سورة ${esc(names[m.surah[i] - 1][1])}، ${ar(m.ayah[i])}، صفحة ${ar(m.page[i])}</small></span>${icon('back', 'muted')}</a>`).join('') +
      (hits.length > 200 ? `<p class="muted small center">عُرضت أول ٢٠٠ نتيجة، زِد كلمات البحث.</p>` : '');
  };
  q.oninput = () => { clearTimeout(timer); timer = setTimeout(run, 180); };
  if (q.value) run(); else q.focus();
}
