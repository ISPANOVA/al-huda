// مواقيت الصلاة: today's times for the saved location, the next prayer, the
// calculation settings and a monthly timetable (إمساكية).
import { $, ar, esc, icon, store, top, toast, sheet } from './app.js';
import { NAMES, METHODS, location, locate, timesFor, nextPrayer, hm, countdown, hijriToday, HMONTHS } from './prayerlib.js';
import { ticks, togglePrayed, prayedOn } from './tools.js';

let timer;

export async function show(view, args) {
  if (args[0] === 'month') return month(view);
  const loc = location();
  view.innerHTML = top('مواقيت الصلاة', loc?.city || 'حسب موقعك', 'sapphire', 'clock', false) + '<div id="body"></div>';
  const body = $('#body', view);
  if (!loc) {
    body.innerHTML = `<div class="card center" style="padding:28px 18px">
      <div class="ticon t-sapphire" style="margin:0 auto 12px">${icon('compass')}</div>
      <b>نحتاج موقعك لحساب المواقيت</b><p class="muted small">يُستخدم الموقع على جهازك فقط لحساب المواقيت واتجاه القبلة.</p>
      <button class="btn" id="loc">تحديد موقعي</button></div>`;
    $('#loc', body).onclick = () => askLocation(view);
    return;
  }
  const now = new Date();
  const [t, h] = await Promise.all([timesFor(now), hijriToday().catch(() => null)]);
  let np = await nextPrayer();
  body.innerHTML = `
    <div class="card solid t-sapphire hero center">
      <small>${h ? `${ar(h.d)} ${HMONTHS[h.m - 1]} ${ar(h.y)} هـ` : ''}</small>
      <div style="margin-top:4px">الصلاة القادمة: <b id="nn"></b></div>
      <div class="big" id="nc" style="font-variant-numeric:tabular-nums;margin:6px 0"></div>
      <small id="nt"></small>
    </div>
    <div class="ptimes" style="margin-top:14px">${NAMES.map((n, i) => `<div data-i="${i}"><span>${n}</span><span class="t">${hm(t[i])}</span></div>`).join('')}</div>
    <a class="card" href="#/prayerlog" id="plc" style="display:block;margin-top:12px"><div class="row"><b class="grow">صلواتي اليوم</b><span class="gold" id="plN">${ar(prayedOn(now).size)} / ٥</span>${icon('back', 'muted')}</div>${ticks(now)}</a>
    <div class="grid3" style="margin-top:6px">
      <a class="card qa" href="#/qibla"><div class="ticon t-amber">${icon('compass')}</div>القبلة</a>
      <a class="card qa" href="#/prayer/month"><div class="ticon t-sky">${icon('cal')}</div>الإمساكية</a>
      <a class="card qa" href="#/calendar"><div class="ticon t-emerald">${icon('moon')}</div>التقويم</a>
    </div>
    <div class="card list" style="margin-top:12px">
      <button id="m">${icon('tune')}<span class="grow"><b>طريقة الحساب</b><br><small class="muted">${esc(METHODS[store.get('method', 'egyptian')])}</small></span></button>
      <button id="md">${icon('clock')}<span class="grow"><b>حساب العصر</b><br><small class="muted">${store.get('madhab', 'shafi') === 'hanafi' ? 'الحنفي' : 'الجمهور (الشافعي والمالكي والحنبلي)'}</small></span></button>
      <button id="adj">${icon('tune')}<span class="grow"><b>تعديل يدوي بالدقائق</b><br><small class="muted">لمطابقة مسجدك</small></span></button>
      <button id="loc">${icon('compass')}<span class="grow"><b>تحديث الموقع</b><br><small class="muted">${esc(loc.city || `${loc.lat.toFixed(2)}، ${loc.lng.toFixed(2)}`)}</small></span></button>
    </div>`;
  const paint = async () => {
    if (!body.isConnected) return clearInterval(timer);
    if (np[1] <= new Date()) { np = await nextPrayer(); }
    $('#nn', body).textContent = NAMES[np[0]];
    $('#nc', body).textContent = countdown(np[1]);
    $('#nt', body).textContent = `عند ${hm(np[1])}`;
    for (const el of body.querySelectorAll('.ptimes > div')) el.classList.toggle('next', +el.dataset.i === np[0] && np[1].toDateString() === new Date().toDateString());
  };
  paint();
  clearInterval(timer);
  timer = setInterval(paint, 1000);

  $('#plc', body).onclick = (e) => {
    const t = e.target.closest('[data-tick]');
    if (!t) return;
    e.preventDefault();
    togglePrayed(new Date(), +t.dataset.tick);
    const card = $('#plc', body);
    card.querySelector('.ticks').outerHTML = ticks(new Date());
    $('#plN', body).textContent = `${ar(prayedOn(new Date()).size)} / ٥`;
  };
  $('#m', body).onclick = () => pick('طريقة الحساب', Object.entries(METHODS), store.get('method', 'egyptian'), (v) => { store.set('method', v); show(view, []); });
  $('#md', body).onclick = () => pick('حساب العصر', [['shafi', 'الجمهور (الشافعي والمالكي والحنبلي)'], ['hanafi', 'الحنفي']], store.get('madhab', 'shafi'), (v) => { store.set('madhab', v); show(view, []); });
  $('#adj', body).onclick = () => adjust(view);
  $('#loc', body).onclick = () => askLocation(view);
}

async function askLocation(view) {
  toast('جارٍ تحديد الموقع…');
  try { await locate(); show(view, []); } catch { toast('تعذر تحديد الموقع. اسمح للمتصفح بالوصول إلى الموقع.'); }
}

function pick(title, items, value, done) {
  sheet(`<h3>${title}</h3><div class="list">${items.map(([k, v]) => `<button data-k="${k}">${icon(k === value ? 'check' : 'clock', k === value ? 'gold' : 'muted')}<span class="grow">${esc(v)}</span></button>`).join('')}</div>`,
    (body, close) => { body.onclick = (e) => { const b = e.target.closest('[data-k]'); if (b) { close(); done(b.dataset.k); } }; });
}

function adjust(view) {
  const adj = store.get('adj', [0, 0, 0, 0, 0, 0]);
  sheet(`<h3>تعديل المواقيت</h3><div class="list">${NAMES.map((n, i) => `<div><span class="grow"><b>${n}</b></span>
      <button class="chip" data-d="${i},-1">−</button><b style="min-width:48px;text-align:center" id="a${i}">${ar(adj[i])}</b><button class="chip" data-d="${i},1">+</button></div>`).join('')}</div>
      <button class="btn block" id="ok" style="margin-top:12px">تم</button>`, (body, close) => {
    body.onclick = (e) => {
      const b = e.target.closest('[data-d]');
      if (b) { const [i, d] = b.dataset.d.split(',').map(Number); adj[i] = Math.max(-30, Math.min(30, adj[i] + d)); $('#a' + i, body).textContent = ar(adj[i]); store.set('adj', adj); }
      if (e.target.closest('#ok')) close();
    };
  }).then(() => show(view, []));
}

async function month(view) {
  view.innerHTML = top('الإمساكية', 'مواقيت الشهر لمدينتك', 'sky', 'cal') + '<div id="body"></div>';
  const body = $('#body', view);
  if (!location()) { body.innerHTML = '<div class="card center">حدّد موقعك أولًا من صفحة المواقيت.</div>'; return; }
  const now = new Date();
  const rows = [];
  for (let d = 0; d < 30; d++) {
    const day = new Date(now.getFullYear(), now.getMonth(), now.getDate() + d);
    const t = await timesFor(day);
    rows.push(`<tr${d === 0 ? ' style="color:var(--gold)"' : ''}><td>${ar(day.getDate())}/${ar(day.getMonth() + 1)}</td>${[0, 1, 2, 3, 4, 5].map((i) => `<td>${hm(t[i]).replace(/\s?[صم]$/, '')}</td>`).join('')}</tr>`);
  }
  body.innerHTML = `<div class="card" style="padding:8px;overflow-x:auto"><table style="width:100%;border-collapse:collapse;text-align:center;font-size:13px;font-variant-numeric:tabular-nums">
    <thead><tr class="gold"><th>اليوم</th>${NAMES.map((n) => `<th>${n}</th>`).join('')}</tr></thead>
    <tbody>${rows.join('')}</tbody></table></div>
    <p class="muted small center">الإمساك قبل الفجر بنحو عشر دقائق، والإفطار عند المغرب.</p>`;
  for (const td of body.querySelectorAll('td,th')) td.style.padding = '8px 2px';
}

export function leave() { clearInterval(timer); }
