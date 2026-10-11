// الرئيسية: next prayer, continue reading, the daily wird, quick actions and
// the ayah of the day.
import { $, ar, esc, icon, store, meta, surahs, today, toast } from './app.js';
import { NAMES, location, nextPrayer, hm, countdown, hijriToday, HMONTHS } from './prayerlib.js';
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
  ['#/tasmee', 'التسميع', 'mic'],
  ['#/athkar', 'الأذكار', 'heart'],
  ['#/qibla', 'القبلة', 'compass'],
  ['#/tasbeeh', 'المسبحة', 'beads'],
  ['#/duas', 'الأدعية', 'hands'],
  ['#/calendar', 'التقويم', 'cal'],
  ['#/hifz', 'الحفظ', 'repeat'],
  ['#/search', 'البحث', 'search'],
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

  view.innerHTML = `
    <header class="masthead">
      <div class="grow"><h1 class="brand">الهُدى</h1><p class="muted small" id="hdate"></p></div>
      <a class="iconbtn" href="#/settings" aria-label="الإعدادات">${icon('gear')}</a>
    </header>

    <div class="home-top">
    <a class="day" href="#/prayer" id="next">
      <svg class="star" viewBox="0 0 100 100" aria-hidden="true"><rect x="21" y="21" width="58" height="58"/><rect x="21" y="21" width="58" height="58" transform="rotate(45 50 50)"/><circle cx="50" cy="50" r="17"/></svg>
      <span class="day-label" id="nlabel">الصلاة القادمة</span>
      <span class="day-name" id="nname">مواقيت الصلاة</span>
      <span class="day-meta"><b id="ncount"></b><span id="ntime">اضغط لتحديد موقعك</span></span>
      <span class="line" id="line"></span>
    </a>

    <a class="resume" href="#/mushaf${last ? '/' + last : ''}">
      <span class="grow">
        <span class="muted small">${last ? 'تابع القراءة' : 'ابدأ القراءة'}</span>
        <span class="resume-surah">سورة ${esc(s[1])}</span>
        <span class="muted small">الصفحة ${ar(last || 1)} من ٦٠٤</span>
      </span>
      <span class="resume-go">${icon('book')}</span>
      <span class="resume-bar"><i style="width:${((last || 0) / 604) * 100}%"></i></span>
    </a>

    <div class="stats">
      <a href="#/khatmah"><b>${goal ? `${ar(Math.min(doneToday, goal))} من ${ar(goal)}` : 'حدّد وردك'}</b><span>الورد اليومي</span></a>
      <a href="#/khatmah"><b>${k ? ar(Math.round((k.pages.length / 604) * 100)) + '٪' : 'لم تبدأ'}</b><span>الختمة</span></a>
      <a href="#/stats"><b>${ar(st)} ${st === 1 ? 'يوم' : st > 2 && st < 11 ? 'أيام' : 'يومًا'}</b><span>المداومة</span></a>
    </div>

    <a class="athkar-now" href="#/athkar/${athkar[0]}">${icon(hour >= 3 && hour < 14 ? 'sun' : 'moon')}<span class="grow">${athkar[1]}</span>${icon('back')}</a>
    </div>

    ${friday ? '<p class="note">يوم الجمعة: سورة الكهف، والإكثار من الصلاة على النبي ﷺ.</p>' : ''}
    <h2 class="h2">الأدوات</h2>
    <nav class="tools">${TOOLS.map(([h, t, ic]) => `<a href="${h}">${icon(ic)}<span>${t}</span></a>`).join('')}</nav>

    <h2 class="h2">آية اليوم</h2>
    <figure class="ayah-day" id="aotd"><p class="muted center">…</p></figure>

    <p class="dedication">صدقة جارية عن روح سمير حجازي، وعن سعد صالح، وعن جميع المسلمين</p>`;

  hijriToday().then((h) => {
    const city = location()?.city;
    $('#hdate').textContent = `${ar(h.d)} ${HMONTHS[h.m - 1]} ${ar(h.y)} هـ${city ? '، ' + city : ''}`;
  }).catch(() => {});
  tickPrayer();
  ayahOfDay(m, names);
}

/// The day's six times on one line: what has passed, the next, and now.
function dayLine(times, next) {
  const t0 = times[0].getTime(), t1 = times[5].getTime();
  const pos = (t) => Math.min(100, Math.max(0, ((t - t0) / (t1 - t0)) * 100));
  const now = Date.now();
  return `<i class="track"></i><i class="done" style="width:${pos(now)}%"></i>` +
    times.map((t, i) => `<i class="dot${t.getTime() <= now ? ' past' : ''}${i === next ? ' next' : ''}" style="right:${pos(t.getTime())}%"><em>${NAMES[i]}</em></i>`).join('');
}

async function tickPrayer() {
  const el = $('#next');
  if (!location()) return;
  let np = await nextPrayer().catch(() => null);
  if (!np || !el.isConnected) return;
  let drawn = -1;
  const paint = async () => {
    if (!el.isConnected) return clearInterval(timer);
    if (np[1] <= new Date()) np = await nextPrayer();
    $('#nname').textContent = NAMES[np[0]];
    $('#nlabel').textContent = np[0] === 1 ? 'الشروق' : 'الصلاة القادمة';
    $('#ntime').textContent = hm(np[1]);
    $('#ncount').textContent = `بعد ${countdown(np[1])}`;
    const sameDay = np[1].toDateString() === new Date().toDateString();
    const key = np[0] * 10 + (sameDay ? 1 : 0) + Math.floor(Date.now() / 60000) * 100;
    if (key !== drawn) { drawn = key; $('#line').innerHTML = dayLine(np[2], sameDay ? np[0] : -1); }
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

export function leave() { clearInterval(timer); }
