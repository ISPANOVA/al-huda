// الرئيسية: next prayer, continue reading, the daily wird, quick actions and
// the ayah of the day.
import { $, ar, esc, icon, store, meta, surahs, today, toast, core, data } from './app.js';
import { NAMES, location, nextPrayer, timesFor, hm, countdown, hijriToday, HMONTHS, ramadanDays } from './prayerlib.js';
import { skyState, drawSky, GREETING } from './sky.js';
import { ayahText } from './page.js';
import { player, ayahItems } from './player.js';

let timer, rTimer;

/// The first page of each juz (the Madani Mushaf), for the Ramadan wird.
const JUZ_PAGES = [1, 22, 42, 62, 82, 102, 121, 142, 162, 182, 201, 222, 242, 262, 282, 302, 322, 342, 362, 382, 402, 422, 442, 462, 482, 502, 522, 542, 562, 582];
const JUZ = ['الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس', 'السادس', 'السابع', 'الثامن', 'التاسع', 'العاشر', 'الحادي عشر', 'الثاني عشر', 'الثالث عشر', 'الرابع عشر', 'الخامس عشر', 'السادس عشر', 'السابع عشر', 'الثامن عشر', 'التاسع عشر', 'العشرون', 'الحادي والعشرون', 'الثاني والعشرون', 'الثالث والعشرون', 'الرابع والعشرون', 'الخامس والعشرون', 'السادس والعشرون', 'السابع والعشرون', 'الثامن والعشرون', 'التاسع والعشرون', 'الثلاثون'];

export function streak() {
  const log = store.get('read', {});
  let n = 0;
  const d = new Date();
  // Today not read yet does not break the streak.
  if (!(log[today()] || []).length) d.setDate(d.getDate() - 1);
  for (;;) {
    const k = `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
    if (!(log[k] || []).length) break;
    n++;
    d.setDate(d.getDate() - 1);
  }
  return n;
}

const TOOLS = [
  ['#/tasmee', 'التسميع', 'mic', 'emerald'],
  ['#/qibla', 'القبلة', 'compass', 'amber'],
  ['#/tasbeeh', 'المسبحة', 'beads', 'teal'],
  ['#/duas', 'الأدعية', 'hands', 'rose'],
  ['#/calendar', 'التقويم', 'cal', 'sky'],
  ['#/prayerlog', 'صلواتي', 'check', 'sapphire'],
  ['#/video', 'فيديو آية', 'tv', 'coral'],
  ['#/hifz', 'الحفظ', 'repeat', 'amethyst'],
];

export async function show(view) {
  const [m, names] = await Promise.all([meta(), surahs()]);
  const hour = new Date().getHours();
  const athkar = hour >= 3 && hour < 14 ? ['morning', 'أذكار الصباح'] : ['evening', 'أذكار المساء'];
  const last = store.get('lastPage', 0);
  const g = last ? m.page.indexOf(last) + 1 : 1;
  const s = names[m.surah[g - 1] - 1];
  const goal = store.get('wirdGoal', 0);
  const doneToday = (store.get('read', {})[today()] || []).length;
  const k = store.get('khatmah', null);
  const st = streak();
  const friday = new Date().getDay() === 5;

  const greg = new Date().toLocaleDateString('ar-EG', { weekday: 'long', day: 'numeric', month: 'long' });
  const rp = !player.current ? player.resumePoint : null;
  const pct = last ? Math.max(1, Math.round((last / 604) * 100)) : 0;
  view.innerHTML = `<div class="home">
    <div class="hcol hmain">
      <section class="sky" id="sky">
        <div class="skyart">
          <canvas id="skyc" aria-hidden="true"></canvas>
          <div class="sky-top">
            <div class="grow"><small id="greet"></small><h1>الهدى</h1></div>
            <a class="skybtn" href="#/qibla" aria-label="القبلة">${icon('compass')}</a>
            <a class="skybtn" href="#/settings" aria-label="الإعدادات">${icon('gear')}</a>
          </div>
          <div class="sky-date"><b id="hdate"></b><small>${esc(greg)}</small></div>
        </div>
        <a class="nextp" href="#/prayer" id="next">
          <span class="grow"><small id="nlabel">الصلاة القادمة</small>
            <span class="nrow"><b id="nname">مواقيت الصلاة</b><em id="ntime">اضغط لتحديد موقعك</em></span>
            <small id="ncity"></small></span>
          <span class="nring" id="nring" hidden><svg viewBox="0 0 72 72"><circle cx="36" cy="36" r="32"/><circle cx="36" cy="36" r="32" id="narc"/></svg>
            <span><b id="ncount"></b><small>متبقٍ</small></span></span>
          ${icon('back', 'muted')}
        </a>
      </section>
      <div class="today" id="today"></div>
      <div id="banners">${friday ? '<a class="card banner-fri" href="#/mushaf/293"><b>جمعة مباركة</b><small>اقرأ سورة الكهف، وأكثر من الصلاة على النبي ﷺ</small></a>' : ''}</div>
      <div class="hsec hayah"><div class="section">آية اليوم</div>
        <figure class="card ayah-day" id="aotd"><p class="muted center">…</p></figure></div>
    </div>

    <div class="hcol hside">
      <div class="cont${rp ? ' two' : ''}">
        <a class="card ccard" href="#/mushaf${last ? '/' + last : ''}">
          <span class="ticon t-emerald">${icon('book')}</span>
          <span class="grow"><small class="muted">${last ? 'تابع القراءة' : 'ابدأ القراءة'}</small>
            <b class="ctitle">سورة ${esc(s[1])}</b>
            <small class="muted">الصفحة ${ar(last || 1)}${last ? `، ${ar(pct)}٪ من المصحف` : ''}</small></span>
          <span class="pbtn">${icon('play')}</span>
          <span class="cbar"><i style="width:${pct}%"></i></span>
        </a>
        ${rp ? `<button class="card ccard" id="lis">
          <span class="ticon t-amethyst">${icon('head')}</span>
          <span class="grow"><small class="muted">تابع الاستماع</small>
            <b class="ctitle sm">${esc(rp.label)}</b><small class="muted ell">${esc(rp.title)}</small></span>
          <span class="pbtn">${icon('play')}</span></button>` : ''}
      </div>

      <div class="goals">
        <a class="card" href="#/khatmah"><span class="ticon t-teal">${icon('book')}</span><span><b>${goal ? `${ar(Math.min(doneToday, goal))} / ${ar(goal)}` : 'حدّد هدفك'}</b><small>الورد اليومي</small></span></a>
        <a class="card" href="#/khatmah"><span class="ticon t-amethyst">${icon('flag')}</span><span><b>${k ? ar(Math.round((k.pages.length / 604) * 100)) + '٪' : 'ابدأ ختمة'}</b><small>الختمة</small></span></a>
        <a class="card" href="#/stats"><span class="ticon t-amber">${icon('star')}</span><span><b>${st ? `${ar(st)} ${st === 1 ? 'يوم' : st > 2 && st < 11 ? 'أيام' : 'يومًا'}` : 'ابدأ اليوم'}</b><small>المداومة</small></span></a>
      </div>

      <a class="card athkar-now" href="#/athkar/${athkar[0]}"><span class="ticon t-rose">${icon(hour >= 3 && hour < 14 ? 'sun' : 'moon')}</span><span class="grow"><b>${athkar[1]}</b><small class="muted">حصّن يومك بذكر الله</small></span>${icon('back', 'muted')}</a>

      <div class="hsec"><div class="section">الوصول السريع</div>
        <div class="card tools">${TOOLS.map(([h, t, ic, tone]) => `<a href="${h}"><span class="ticon t-${tone}">${icon(ic)}</span><span>${t}</span></a>`).join('')}</div></div>
    </div>
  </div>
  <p class="dedication">صدقة جارية عن روح سمير حجازي، وعن سعد صالح، وعن جميع المسلمين</p>`;

  $('#lis')?.addEventListener('click', () => player.resume());
  hijriToday().then((h) => {
    $('#hdate').textContent = `${ar(h.d)} ${HMONTHS[h.m - 1]} ${ar(h.y)} هـ`;
    if (h.m === 9) ramadanCard(view, h.d);
    else if (h.m === 8 && h.d >= 19) ramadanSoon(view);
  }).catch(() => {});
  paintSky();
  addEventListener('resize', onSkyResize);
  tickPrayer();
  // Below the fold: after the first paint, so it never delays the top.
  if (window.requestIdleCallback) requestIdleCallback(() => ayahOfDay(m, names), { timeout: 1200 });
  else setTimeout(() => ayahOfDay(m, names), 300);
  if (hour >= 12) setTimeout(() => tomorrowFast(view), 1800);
}

let skyTimes = null;
async function paintSky() {
  const cv = $('#skyc');
  if (!cv) return;
  if (location() && !skyTimes) skyTimes = await timesFor(new Date()).catch(() => null);
  const st = skyState(new Date(), skyTimes);
  $('#greet').textContent = GREETING[st.phase];
  // The sun's path stays below the title on phones.
  drawSky(cv, st, { orbitTop: 0.5, horizonAt: 0.9 });
}

/// Today's six times in a row, the next one lit.
function todayRow(times, next) {
  const now = new Date();
  return times.map((t, i) => `<a href="#/prayer" class="${i === next ? 'next' : t < now ? 'past' : ''}"><small>${NAMES[i]}</small><b>${hm(t).replace(/\s?[صم]$/, '')}</b></a>`).join('');
}

async function tickPrayer() {
  const el = $('#next');
  if (!location()) return;
  let np = await nextPrayer().catch(() => null);
  if (!np || !el.isConnected) return;
  $('#nring').hidden = false;
  $('#ncity').textContent = location().city || '';
  let drawn = '';
  const paint = async () => {
    if (!el.isConnected) return clearInterval(timer);
    if (document.hidden) return; // no work while the tab is in the background
    const now = new Date();
    if (np[1] <= now) { np = await nextPrayer(); skyTimes = null; }
    $('#nname').textContent = NAMES[np[0]];
    $('#nlabel').textContent = np[0] === 1 ? 'الشروق' : 'الصلاة القادمة';
    $('#ntime').textContent = hm(np[1]);
    $('#ncount').textContent = countdown(np[1]);
    // The ring fills from the last time to the next one.
    const times = np[2];
    let prev = null;
    for (const t of times) if (t <= now && (!prev || t > prev)) prev = t;
    if (!prev) prev = new Date(times[5].getTime() - 864e5);
    const f = Math.min(1, Math.max(0, (now - prev) / (np[1] - prev)));
    $('#narc').style.strokeDashoffset = String(201 * (1 - f));
    const sameDay = np[1].toDateString() === now.toDateString();
    const key = `${np[0]}${sameDay}${now.getMinutes()}`;
    if (key !== drawn) { drawn = key; $('#today').innerHTML = todayRow(times, sameDay ? np[0] : -1); paintSky(); }
  };
  paint();
  clearInterval(timer);
  timer = setInterval(paint, 1000);
}

async function ayahOfDay(m, names) {
  const box = $('#aotd');
  const d = new Date();
  const seed = d.getFullYear() * 400 + d.getMonth() * 32 + d.getDate();
  const g = ((seed * 2654435761) >>> 0) % m.surah.length + 1;
  try {
    const t = await ayahText(g);
    const name = names[m.surah[g - 1] - 1][1];
    const ref = `﴿${t}﴾ [${name}: ${ar(m.ayah[g - 1])}]`;
    box.innerHTML = `<blockquote class="verse">${esc(t)}</blockquote>
      <figcaption>سورة ${esc(name)}، الآية ${ar(m.ayah[g - 1])}</figcaption>
      <div class="ayah-actions">
        <button id="al">${icon('play')} استماع</button>
        <button id="as">${icon('share')} مشاركة</button>
        <a href="#/mushaf/${m.page[g - 1]}">${icon('book')} في المصحف</a>
      </div>`;
    $('#al', box).onclick = () => player.play(ayahItems(g, g, null, () => `سورة ${name}، الآية ${ar(m.ayah[g - 1])}`), 'آية اليوم');
    $('#as', box).onclick = () => {
      if (navigator.share) navigator.share({ text: ref }).catch(() => {});
      else navigator.clipboard?.writeText(ref).then(() => toast('نُسخت الآية'));
    };
  } catch {
    box.innerHTML = '<p class="muted center">تعذر جلب آية اليوم.</p>';
  }
}

/// رمضان: the day, the countdown to iftar or imsak, the juz of the day and the imsakiya.
async function ramadanCard(view, day) {
  const box = $('#banners', view);
  if (!box) return;
  const d = Math.max(1, Math.min(30, day));
  box.insertAdjacentHTML('afterbegin', `<div class="card ramadan">
    <div class="row"><span class="rmoon">${icon('moon')}</span><span class="grow"><b>رمضان كريم • اليوم ${ar(d)}</b><small id="rline">حدّد موقعك لعدّاد الإفطار والسحور</small></span></div>
    <div class="rchips" id="rchips"></div>
    <div class="ractions"><a href="#/mushaf/${JUZ_PAGES[d - 1]}">${icon('book')} ورد اليوم: الجزء ${JUZ[d - 1]}</a><a href="#/prayer/month">${icon('cal')} الإمساكية</a></div></div>`);
  if (!location()) return;
  const now0 = new Date();
  const [t, t2] = await Promise.all([timesFor(now0), timesFor(new Date(now0.getFullYear(), now0.getMonth(), now0.getDate() + 1))]);
  const tick = () => {
    const line = $('#rline', view);
    if (!line) return clearInterval(rTimer);
    const now = new Date();
    const fajr = t[0], maghrib = t[4];
    const nextFajr = now < fajr ? fajr : t2[0];
    const imsak = new Date(nextFajr - 600000);
    const left = (to) => { const m = Math.max(0, Math.round((to - new Date()) / 60000)); const hh = Math.floor(m / 60); return hh ? `${ar(hh)} س ${ar(m % 60)} د` : `${ar(m)} د`; };
    line.textContent = now > fajr && now < maghrib ? `باقٍ على الإفطار ${left(maghrib)}`
      : now < imsak ? `باقٍ على الإمساك ${left(imsak)}` : `حان الإمساك • الفجر ${hm(nextFajr)}`;
    $('#rchips', view).innerHTML = `<span>الإمساك ${hm(imsak)}</span><span>الإفطار ${hm(maghrib)}</span>`;
  };
  tick();
  clearInterval(rTimer);
  rTimer = setInterval(tick, 20000);
}

/// The last days of Sha'ban: Ramadan is near.
async function ramadanSoon(view) {
  const r = await ramadanDays().catch(() => null);
  const box = $('#banners', view);
  if (!r || !box) return;
  const n = Math.round((r.days[0] - new Date(new Date().toDateString())) / 864e5);
  if (n < 1 || n > 10) return;
  box.insertAdjacentHTML('afterbegin', `<a class="card banner-fri" href="#/prayer/month"><b>اقترب رمضان</b><small>${n === 1 ? 'رمضان غدًا بإذن الله' : `باقٍ ${ar(n)} ${n <= 10 ? 'أيام' : 'يومًا'}`} • الإمساكية جاهزة لمدينتك</small></a>`);
}

/// «غدًا يوم عرفة / الأيام البيض…»: a banner on the evening before a recommended fast.
async function tomorrowFast(view) {
  try {
    const [api, cal] = await Promise.all([core(), data('calendar.json')]);
    const t = new Date();
    t.setDate(t.getDate() + 1);
    const [, hm, hd] = api.hijri(t.getFullYear(), t.getMonth() + 1, t.getDate());
    const o = cal.occasions.find((x) => x[0] === hm && x[1] === hd && x[4]);
    const box = $('#banners', view);
    if (!o || !box?.isConnected) return;
    box.insertAdjacentHTML('beforeend', `<a class="card banner-fri" href="#/calendar"><b>غدًا ${esc(o[2])}</b><small>${esc(o[3] || '')}، انوِ الصيام من الليل</small></a>`);
  } catch {}
}

export function leave() { clearInterval(timer); clearInterval(rTimer); removeEventListener('resize', onSkyResize); }
function onSkyResize() { paintSky(); }
