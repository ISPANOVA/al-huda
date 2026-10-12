// أسماء الله الحسنى، الأربعون النووية، حاسبة الزكاة، متابعة الصلوات (ورمضان)،
// المتشابهات اللفظية: the same content and keys as the app.
import { $, $$, ar, esc, icon, store, data, meta, surahs, top, toast, sheet, afterSheet } from './app.js';
import { hijriToday } from './prayerlib.js';
import { ayahText } from './page.js';

const share = (t) => {
  if (navigator.share) navigator.share({ text: t }).catch(() => {});
  else navigator.clipboard?.writeText(t).then(() => toast('نُسخ النص'));
};
const LINK = 'https://al-huda.xyz';

export async function show(view, args, name) {
  if (name === 'asma') return asma(view);
  if (name === 'nawawi') return nawawi(view, args);
  if (name === 'zakat') return zakat(view);
  if (name === 'prayerlog') return prayerLog(view);
  if (name === 'similar') return similarPage(view, args);
}

// ------------------------------------------------------------- الأسماء ---
async function asma(view) {
  const names = await data('asma.json');
  view.innerHTML = top('أسماء الله الحسنى', 'تسعة وتسعون اسمًا ومعانيها', 'gold', 'star') + `
    <div class="card solid t-gold center" style="line-height:1.9">قال رسول الله ﷺ: «إن لله تسعة وتسعين اسمًا، مائةً إلا واحدًا، من أحصاها دخل الجنة» متفق عليه</div>
    <div class="search" style="margin:14px 0">${icon('search')}<input class="field" id="q" placeholder="ابحث عن اسم" type="search"></div>
    <div class="names" id="ns"></div>
    <p class="muted small center">الأسماء في رواية الترمذي، وفي تعيين بعضها خلاف بين العلماء، والمعاني مختصرة.</p>`;
  const norm = (s) => s.replace(/[ً-ٰٟ]/g, '').replace(/[أإآٱ]/g, 'ا');
  const list = (q) => {
    $('#ns', view).innerHTML = names.map(([n], i) => (!q || norm(n).includes(norm(q))) ?
      `<button class="card nm" data-i="${i}"><small class="muted">${ar(i + 1)}</small><b>${esc(n)}</b></button>` : '').join('');
  };
  list('');
  $('#q', view).oninput = (e) => list(e.target.value.trim());
  const open = (i) => {
    const [n, m] = names[i];
    sheet(`<div class="center"><small class="gold">${ar(i + 1)}</small><div class="quran" style="font-size:48px;line-height:1.6">${esc(n)}</div>
      <p style="font-size:18px;line-height:1.9">${esc(m)}</p>
      <div class="row" style="justify-content:center;gap:10px">
        ${i < names.length - 1 ? `<button class="chip" data-go="${i + 1}">التالي</button>` : ''}
        <button class="btn" id="sh">${icon('share')} مشاركة</button>
        ${i > 0 ? `<button class="chip" data-go="${i - 1}">السابق</button>` : ''}</div></div>`, (body) => {
      $('#sh', body).onclick = () => share(`${n}: ${m}\n\n— الهدى ${LINK}`);
      body.onclick = (e) => { const g = e.target.closest('[data-go]'); if (g) open(+g.dataset.go); };
    });
  };
  view.onclick = (e) => { const b = e.target.closest('[data-i]'); if (b) open(+b.dataset.i); };
}

// ------------------------------------------------------------- النووية ---
async function nawawi(view, args) {
  const list = await data('nawawi.json');
  const read = store.get('nawawiRead', {});
  if (args[0]) {
    const i = Math.max(0, Math.min(list.length - 1, +args[0] - 1));
    const [n, t, x] = list[i];
    read[n] = true; store.set('nawawiRead', read);
    let fs = store.get('nawawiFs', 20);
    view.innerHTML = top(`الحديث ${ar(n)}`, t, 'emerald', 'book') + `
      <div class="card wash t-emerald"><h2 class="center gold" style="font-family:ReemKufi,Tajawal">${esc(t)}</h2>
        <p id="hx" style="line-height:2.1;text-align:justify;font-size:${fs}px">${esc(x)}</p></div>
      <div class="row" style="gap:8px;margin-top:10px">
        <button class="chip" id="fm">أ−</button><button class="chip" id="fp">أ+</button><span class="grow"></span>
        <button class="btn ghost" id="cp">${icon('copy')} نسخ</button><button class="btn" id="sh">${icon('share')} مشاركة</button></div>
      <div class="row" style="margin-top:14px">
        ${i > 0 ? `<a class="chip" href="#/nawawi/${n - 1}">الحديث ${ar(n - 1)}</a>` : ''}<span class="grow"></span>
        ${i < list.length - 1 ? `<a class="chip" href="#/nawawi/${n + 1}">الحديث ${ar(n + 1)}</a>` : ''}</div>`;
    const ref = `${x}\n\n(الأربعون النووية، الحديث ${n})`;
    $('#cp', view).onclick = () => navigator.clipboard?.writeText(ref).then(() => toast('نُسخ الحديث'));
    $('#sh', view).onclick = () => share(`${ref}\n— الهدى ${LINK}`);
    const size = (d) => { fs = Math.max(15, Math.min(32, fs + d)); store.set('nawawiFs', fs); $('#hx', view).style.fontSize = fs + 'px'; };
    $('#fm', view).onclick = () => size(-2);
    $('#fp', view).onclick = () => size(2);
    return;
  }
  view.innerHTML = top('الأربعون النووية', 'جوامع الكلم من هدي النبي ﷺ', 'emerald', 'book') +
    `<div class="card list">${list.map(([n, t, x]) => `<a href="#/nawawi/${n}"><span class="num${read[n] ? ' done' : ''}">${read[n] ? icon('check') : ar(n)}</span>
      <span class="grow"><b>${esc(t)}</b><br><small class="muted ell">${esc(x.slice(0, 90))}</small></span>${icon('back', 'muted')}</a>`).join('')}</div>`;
}

// --------------------------------------------------------------- الزكاة ---
function zakat(view) {
  const F = [
    ['goldPrice', 'سعر جرام الذهب عيار ٢٤', 'بعملتك المحلية'], ['cash', 'النقود والمدخرات والحسابات البنكية'],
    ['gold24', 'ذهب عيار ٢٤ (جرام)'], ['gold21', 'ذهب عيار ٢١ (جرام)'], ['gold18', 'ذهب عيار ١٨ (جرام)'],
    ['silver', 'فضة (جرام)'], ['silverPrice', 'سعر جرام الفضة'], ['trade', 'قيمة عروض التجارة'],
    ['receivable', 'ديون لك مرجوّة السداد'], ['debts', 'ديون عليك حالّة (تُخصم)'],
  ];
  const saved = store.get('zakat', {});
  view.innerHTML = top('حاسبة الزكاة', 'زكاة المال والذهب والفضة والتجارة', 'amber', 'chart') + `
    <div class="card solid t-amber center" id="zr"></div>
    ${F.map(([k, l, h], i) => `${i === 0 ? '<div class="section">سعر الذهب اليوم</div>' : i === 1 ? '<div class="section">أموالك</div>' : ''}
      <label class="small muted" style="display:block;margin-top:8px">${l}</label>
      <input class="field" inputmode="decimal" data-k="${k}" value="${esc(saved[k] ?? '')}" placeholder="${h || '٠'}">`).join('')}
    <p class="muted small center" style="line-height:1.9;margin-top:14px">تجب الزكاة إذا بلغ المال النصاب وحال عليه الحول (سنة هجرية كاملة)، ومقدارها ربع العشر (٢٫٥٪). ذهب الزينة المستعمل فيه خلاف بين العلماء، والحاسبة للتقدير، فاسأل أهل العلم فيما أشكل عليك.</p>`;
  const num = (v) => +String(v || '').replace(/[٠-٩]/g, (d) => '٠١٢٣٤٥٦٧٨٩'.indexOf(d)).replace(/[٫]/g, '.').replace(/,/g, '') || 0;
  const money = (v) => ar(v >= 100 ? Math.round(v).toLocaleString('en') : v.toFixed(2));
  const calc = () => {
    const v = {};
    for (const el of $$('[data-k]', view)) v[el.dataset.k] = num(el.value);
    const price = v.goldPrice;
    const pure = v.gold24 + (v.gold21 * 21) / 24 + (v.gold18 * 18) / 24;
    const total = v.cash + pure * price + v.silver * v.silverPrice + v.trade + v.receivable - v.debts;
    const nisab = 85 * price;
    const due = price > 0 && total >= nisab;
    $('#zr', view).innerHTML = price <= 0 ? '<b>اكتب سعر جرام الذهب عيار ٢٤ أولًا</b>' :
      `<small>${due ? 'الزكاة الواجبة' : 'لم يبلغ مالك النصاب'}</small><div class="big">${due ? money(total * 0.025) : '—'}</div>
       <small>مجموع المال الزكوي ${money(total)}، والنصاب ${money(nisab)} (قيمة ٨٥ جرامًا من الذهب عيار ٢٤)</small>`;
  };
  calc();
  view.oninput = (e) => {
    const el = e.target.closest('[data-k]');
    if (!el) return;
    const s = store.get('zakat', {});
    s[el.dataset.k] = el.value.trim();
    store.set('zakat', s);
    calc();
  };
}

// ------------------------------------------------------ متابعة الصلوات ---
export const PRAYERS = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
const dkey = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
export const prayedOn = (d) => new Set(store.get('plog', {})[dkey(d)] || []);
export function togglePrayed(d, i) {
  const all = store.get('plog', {});
  const s = new Set(all[dkey(d)] || []);
  s.has(i) ? s.delete(i) : s.add(i);
  all[dkey(d)] = [...s].sort();
  store.set('plog', all);
}
export function ticks(d) {
  const done = prayedOn(d);
  return `<div class="ticks">${PRAYERS.map((p, i) => `<button class="tick${done.has(i) ? ' on' : ''}" data-tick="${i}">${icon(done.has(i) ? 'check' : 'clock')}<small>${p}</small></button>`).join('')}</div>`;
}
function streak() {
  const d = new Date();
  if (prayedOn(d).size < 5) d.setDate(d.getDate() - 1);
  let n = 0;
  while (prayedOn(d).size === 5) { n++; d.setDate(d.getDate() - 1); }
  return n;
}
function pct(days) {
  let done = 0;
  const d = new Date();
  for (let i = 0; i < days; i++) { done += prayedOn(d).size; d.setDate(d.getDate() - 1); }
  return Math.round((done * 100) / (days * 5));
}
const DAYS = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];

async function prayerLog(view) {
  const h = await hijriToday().catch(() => null);
  const paint = () => {
    const now = new Date();
    const qada = store.get('qada', 0);
    const rows = [];
    for (let i = 1; i < 15; i++) {
      const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() - i);
      const done = prayedOn(d);
      rows.push(`<tr><td class="small">${DAYS[d.getDay()]} ${ar(d.getDate())}/${ar(d.getMonth() + 1)}</td>${PRAYERS.map((_, k) =>
        `<td><button class="dot${done.has(k) ? ' on' : ''}" data-day="${dkey(d)}" data-k="${k}">${done.has(k) ? icon('check') : ''}</button></td>`).join('')}</tr>`);
    }
    const ram = h && h.m >= 9 ? ramadan(h.y, h.m === 9 ? h.d : 0) : '';
    view.innerHTML = top('متابعة الصلوات', 'حافظوا على الصلوات', 'sapphire', 'check') + `
      <div class="card center"><b>اليوم، ${DAYS[now.getDay()]}</b>${ticks(now)}</div>
      <div class="grid3">
        <div class="card center"><div class="big gold">${ar(pct(7))}٪</div><small>آخر ٧ أيام</small></div>
        <div class="card center"><div class="big gold">${ar(pct(30))}٪</div><small>آخر ٣٠ يومًا</small></div>
        <div class="card center"><div class="big gold">${ar(streak())}</div><small>أيام كاملة متتالية</small></div></div>
      <div class="section">آخر أسبوعين</div>
      <div class="card" style="overflow-x:auto"><table class="plog"><thead><tr><th></th>${PRAYERS.map((p) => `<th class="small muted">${p}</th>`).join('')}</tr></thead><tbody>${rows.join('')}</tbody></table></div>
      <div class="section">صلوات القضاء</div>
      <div class="card center"><p class="muted small">سجّل عدد الصلوات الفائتة، وانقص منها كلما قضيت صلاة.</p>
        <div class="row" style="justify-content:center;gap:18px"><button class="chip" data-q="1">+</button><b class="big">${ar(qada)}</b><button class="chip" data-q="-1">−</button></div></div>
      ${ram}`;
  };
  paint();
  view.onclick = (e) => {
    const t = e.target.closest('[data-tick]');
    if (t) { togglePrayed(new Date(), +t.dataset.tick); return paint(); }
    const d = e.target.closest('[data-day]');
    if (d) { const [y, m, dd] = d.dataset.day.split('-').map(Number); togglePrayed(new Date(y, m - 1, dd), +d.dataset.k); return paint(); }
    const q = e.target.closest('[data-q]');
    if (q) { store.set('qada', Math.max(0, store.get('qada', 0) + +q.dataset.q)); return paint(); }
    const f = e.target.closest('[data-fast]');
    if (f) { toggleDay('fasts', h.y, +f.dataset.fast); return paint(); }
    const tr = e.target.closest('[data-tar]');
    if (tr) { toggleDay('taraweeh', h.y, +tr.dataset.tar); return paint(); }
  };
}

const days = (k, y) => new Set(store.get(k, {})[y] || []);
function toggleDay(k, y, d) {
  const all = store.get(k, {});
  const s = new Set(all[y] || []);
  s.has(d) ? s.delete(d) : s.add(d);
  all[y] = [...s].sort((a, b) => a - b);
  store.set(k, all);
}

/// Ramadan's thirty days: the fast and the taraweeh of each.
export function ramadan(year, today = 0) {
  const f = days('fasts', year), t = days('taraweeh', year);
  return `<div class="section">رمضان ${ar(year)} هـ</div>
    <div class="card"><p class="center"><b>الصيام ${ar(f.size)} يومًا، التراويح ${ar(t.size)} ليلة</b><br><small class="muted">اضغط على اليوم لتسجيل الصيام، وعلى القمر للتراويح</small></p>
    <div class="ramadan">${Array.from({ length: 30 }, (_, i) => i + 1).map((d) => `<div class="rd${f.has(d) ? ' on' : ''}${d === today ? ' today' : ''}">
      <button data-fast="${d}">${ar(d)}</button><button class="moon${t.has(d) ? ' on' : ''}" data-tar="${d}">${icon('moon')}</button></div>`).join('')}</div></div>`;
}

// ---------------------------------------------------------- المتشابهات ---
const MARKS = /[ؐ-ًؚ-ٰٟۖ-ۭـ]/g;
const normW = (w) => w.replace(MARKS, '').replace(/[ٱأإآ]/g, 'ا').replace(/ى/g, 'ي').replace(/ة/g, 'ه').replace(/ؤ/g, 'و').replace(/ئ/g, 'ي').replace(/[ۥۦ]/g, '');
const wordsOf = (t) => t.replace(/[\s ]+[٠-٩]+$/, '').split(/\s+/).filter(Boolean);
function shared(a, b) {
  const aw = wordsOf(a).map(normW), bw = wordsOf(b).map(normW);
  const pairs = new Set(aw.slice(1).map((w, i) => `${aw[i]} ${w}`));
  const out = bw.map(() => false);
  for (let i = 0; i + 1 < bw.length; i++) if (pairs.has(`${bw[i]} ${bw[i + 1]}`)) out[i] = out[i + 1] = true;
  if (bw.length === 1 && aw.length === 1 && aw[0] === bw[0]) out[0] = true;
  return out;
}

/// The ayahs similar to global ayah [g], the shared words in colour.
export async function similarSheet(g) {
  const [idx, m, names] = await Promise.all([data('mutashabihat.json'), meta(), surahs()]);
  const others = idx[g] || [];
  if (!others.length) { toast('لا توجد آيات متشابهة لفظيًا مع هذه الآية'); return; }
  const text = await ayahText(g);
  const ref = (x) => `سورة ${names[m.surah[x - 1] - 1][1]} ${ar(m.ayah[x - 1])}`;
  const rows = await Promise.all(others.map(async (o) => {
    const t = await ayahText(o);
    const mk = shared(text, t);
    return `<a class="sim" href="#/mushaf/${m.page[o - 1]}" data-close><small class="muted">${ref(o)}</small>
      <div class="quran" style="font-size:22px;line-height:1.9">${wordsOf(t).map((w, i) => mk[i] ? `<span class="hl">${esc(w)}</span>` : esc(w)).join(' ')}</div></a>`;
  }));
  sheet(`<h3>آيات متشابهة</h3><p class="muted small center">${ar(others.length)} آية تشترك في ألفاظها مع ${ref(g)}</p>
    <div class="sim me"><small class="gold">${ref(g)}</small><div class="quran" style="font-size:22px;line-height:1.9">${esc(text)}</div></div>${rows.join('')}`,
  (body, close) => {
    body.onclick = (e) => {
      const l = e.target.closest('[data-close]');
      if (!l) return;
      e.preventDefault();
      close();
      afterSheet(() => { location.hash = l.getAttribute('href'); });
    };
  });
}

async function similarPage(view, args) {
  const [idx, m, names] = await Promise.all([data('mutashabihat.json'), meta(), surahs()]);
  let s = Math.max(1, Math.min(114, +args[0] || 2));
  view.innerHTML = top('المتشابهات اللفظية', 'آيات تتشابه ألفاظها، لتثبيت الحفظ', 'coral', 'repeat') + `
    <select class="field" id="ss">${names.map((x) => `<option value="${x[0]}"${x[0] === s ? ' selected' : ''}>${ar(x[0])}. ${esc(x[1])}</option>`).join('')}</select>
    <div id="sl" style="margin-top:12px"></div>`;
  const paint = async () => {
    const first = m.surah.indexOf(s) + 1;
    const gs = [];
    for (let g = first; g < first + names[s - 1][2]; g++) if (idx[g]?.length) gs.push(g);
    const texts = await Promise.all(gs.map((g) => ayahText(g)));
    $('#sl', view).innerHTML = gs.length ? gs.map((g, i) => `<button class="card sim-row" data-g="${g}"><span class="grow" style="text-align:right">
      <small class="gold">الآية ${ar(m.ayah[g - 1])}</small><div class="quran ell2" style="font-size:20px">${esc(texts[i])}</div></span>
      <span class="num">${ar(idx[g].length)}</span></button>`).join('') : '<p class="muted center">لا توجد متشابهات لفظية في هذه السورة</p>';
  };
  paint();
  $('#ss', view).onchange = (e) => { s = +e.target.value; paint(); };
  view.onclick = (e) => { const b = e.target.closest('[data-g]'); if (b) similarSheet(+b.dataset.g); };
}
