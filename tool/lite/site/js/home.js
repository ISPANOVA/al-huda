// الرئيسية: next prayer, continue reading, the daily wird, quick actions and
// the ayah of the day.
import { $, ar, esc, icon, store, meta, surahs, today, toast, core, data } from './app.js';
import { NAMES, location, nextPrayer, timesFor, hm, countdown, hijriToday, HMONTHS } from './prayerlib.js';
import { skyState, drawSky, GREETING } from './sky.js';
import { ayahText } from './page.js';
import { player, ayahItems } from './player.js';

let timer;

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
  ['#/hifz', 'الحفظ', 'repeat', 'amethyst'],
  ['#/search', 'البحث', 'search', 'sapphire'],
  ['#/virtues', 'الفضائل', 'star', 'gold'],
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
  view.innerHTML = `
    <section class="sky" id="sky">
      <canvas id="skyc" aria-hidden="true"></canvas>
      <div class="sky-top">
        <div class="grow"><small id="greet"></small><h1>الهدى</h1><b id="hdate"></b><small>${esc(greg)}</small></div>
        <a class="skybtn" href="#/qibla" aria-label="القبلة">${icon('compass')}</a>
        <a class="skybtn" href="#/settings" aria-label="الإعدادات">${icon('gear')}</a>
      </div>
      <a class="nextp" href="#/prayer" id="next">
        <span class="grow"><small id="nlabel">الصلاة القادمة</small>
          <span class="nrow"><b id="nname">مواقيت الصلاة</b><em id="ntime">اضغط لتحديد موقعك</em></span>
          <small id="ncity"></small></span>
        <span class="nring" id="nring" hidden><svg viewBox="0 0 72 72"><circle cx="36" cy="36" r="32"/><circle cx="36" cy="36" r="32" id="narc"/></svg>
          <span><b id="ncount"></b><small>متبقٍ</small></span></span>
      </a>
    </section>

    <div class="today" id="today"></div>

    ${friday ? '<a class="card banner-fri" href="#/mushaf/293"><b>جمعة مباركة</b><small>اقرأ سورة الكهف، وأكثر من الصلاة على النبي ﷺ</small></a>' : ''}

    <a class="card resume" href="#/mushaf${last ? '/' + last : ''}">
      <span class="ticon t-emerald">${icon('book')}</span>
      <span class="grow">
        <small class="muted">${last ? 'تابع القراءة' : 'ابدأ القراءة'}</small>
        <b class="resume-surah">سورة ${esc(s[1])}</b>
        <small class="muted">الصفحة ${ar(last || 1)} من ٦٠٤</small>
      </span>
      <span class="pbtn">${icon('play')}</span>
      <span class="resume-bar"><i style="width:${((last || 0) / 604) * 100}%"></i></span>
    </a>

    ${!player.current && player.resumePoint ? `<button class="card resume listen" id="lis">
      <span class="ticon t-amethyst">${icon('head')}</span>
      <span class="grow" style="text-align:right"><small class="muted">تابع الاستماع</small>
        <b>${esc(player.resumePoint.label)}</b><small class="muted">${esc(player.resumePoint.title)}</small></span>
      <span class="pbtn">${icon('play')}</span></button>` : ''}

    <div class="goals">
      <a class="card" href="#/khatmah"><span class="ticon t-teal">${icon('book')}</span><b>${goal ? `${ar(Math.min(doneToday, goal))} / ${ar(goal)}` : 'حدّد هدفك'}</b><small>وردي</small></a>
      <a class="card" href="#/khatmah"><span class="ticon t-amethyst">${icon('flag')}</span><b>${k ? ar(Math.round((k.pages.length / 604) * 100)) + '٪' : 'ابدأ'}</b><small>الختمة</small></a>
      <a class="card" href="#/stats"><span class="ticon t-amber">${icon('star')}</span><b>${ar(st)} ${st === 1 ? 'يوم' : st > 2 && st < 11 ? 'أيام' : 'يومًا'}</b><small>المداومة</small></a>
    </div>

    <a class="card athkar-now" href="#/athkar/${athkar[0]}"><span class="ticon t-rose">${icon(hour >= 3 && hour < 14 ? 'sun' : 'moon')}</span><span class="grow"><b>${athkar[1]}</b><small class="muted">حصّن يومك</small></span>${icon('back', 'muted')}</a>

    <div class="section">الوصول السريع</div>
    <div class="tools">${TOOLS.map(([h, t, ic, tone]) => `<a href="${h}"><span class="ticon t-${tone}">${icon(ic)}</span><span>${t}</span></a>`).join('')}</div>

    <div class="section">آية اليوم</div>
    <figure class="card ayah-day" id="aotd"><p class="muted center">…</p></figure>

    <p class="dedication">صدقة جارية عن روح سمير حجازي، وعن سعد صالح، وعن جميع المسلمين</p>`;

  $('#lis')?.addEventListener('click', () => player.resume());
  hijriToday().then((h) => { $('#hdate').textContent = `${ar(h.d)} ${HMONTHS[h.m - 1]} ${ar(h.y)} هـ`; }).catch(() => {});
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
  drawSky(cv, st);
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

/// «غدًا يوم عرفة / الأيام البيض…»: a banner on the evening before a recommended fast.
async function tomorrowFast(view) {
  try {
    const [api, cal] = await Promise.all([core(), data('calendar.json')]);
    const t = new Date();
    t.setDate(t.getDate() + 1);
    const [, hm, hd] = api.hijri(t.getFullYear(), t.getMonth() + 1, t.getDate());
    const o = cal.occasions.find((x) => x[0] === hm && x[1] === hd && x[4]);
    const box = $('#today', view);
    if (!o || !box?.isConnected) return;
    box.insertAdjacentHTML('afterend', `<a class="card banner-fri" href="#/calendar"><b>غدًا ${esc(o[2])}</b><small>${esc(o[3] || '')}، انوِ الصيام من الليل</small></a>`);
  } catch {}
}

export function leave() { clearInterval(timer); removeEventListener('resize', onSkyResize); }
function onSkyResize() { paintSky(); }
