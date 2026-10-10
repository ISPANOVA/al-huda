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

const QUICK = [
  ['#/tasmee', 'التسميع', 'mic', 'emerald'],
  ['#/qibla', 'القبلة', 'compass', 'amber'],
  ['#/tasbeeh', 'المسبحة', 'beads', 'teal'],
  ['#/duas', 'الأدعية', 'hands', 'rose'],
  ['#/calendar', 'التقويم', 'cal', 'sky'],
  ['#/hifz', 'الحفظ', 'repeat', 'amethyst'],
];

export async function show(view) {
  const [m, names] = await Promise.all([meta(), surahs()]);
  const hour = new Date().getHours();
  const athkar = hour >= 3 && hour < 14 ? ['morning', 'أذكار الصباح', 'sun'] : ['evening', 'أذكار المساء', 'moon'];
  const last = store.get('lastPage', 0);
  const g = last ? m.page.indexOf(last) + 1 : 1;
  const s = names[m.surah[g - 1] - 1];
  const goal = store.get('wirdGoal', 0);
  const doneToday = (store.get('read', {})[today()] || []).length;
  const k = store.get('khatmah', null);
  const st = streak();
  const day = new Date().getDay();

  view.innerHTML = `
    <div class="row" style="padding:6px 0 14px">
      <div class="grow"><h1 style="margin:0;font-family:ReemKufi,Tajawal;color:var(--gold);font-size:30px;line-height:1.2">الهدى</h1>
      <p class="muted small" style="margin:0" id="hdate">رفيقك اليومي مع القرآن</p></div>
      <a class="back" href="#/settings" aria-label="الإعدادات">${icon('gear')}</a>
    </div>
    <a class="card solid t-sapphire hero" href="#/prayer" id="next" style="display:block">
      <small>الصلاة القادمة</small>
      <div class="big" id="nname">…</div>
      <div class="row" style="margin-top:6px"><span class="grow" id="ntime"></span><b id="ncount" style="font-size:20px;font-variant-numeric:tabular-nums"></b></div>
    </a>
    ${day === 5 ? `<div class="card wash t-amber" style="margin-top:12px"><b>جمعة مباركة</b><br><small class="muted">اقرأ سورة الكهف، وأكثر من الصلاة على النبي ﷺ</small></div>` : ''}
    <div class="grid" style="margin-top:12px">
      <a class="card solid t-emerald tile" href="#/mushaf${last ? '/' + last : ''}" style="grid-column:1/-1">
        <small>${last ? 'تابع القراءة' : 'ابدأ القراءة'}</small>
        <b style="font-size:20px">سورة ${esc(s[1])}</b>
        <small>الصفحة ${ar(last || 1)}${last ? ` • <span dir="ltr">${ar(((last / 604) * 100).toFixed(1)).replace('.', '٫')}٪</span> من المصحف` : ''}</small>
        <div class="bar" style="width:100%;margin-top:6px"><i style="width:${((last || 0) / 604) * 100}%"></i></div>
      </a>
      <a class="card solid t-rose tile" href="#/athkar/${athkar[0]}">${icon(athkar[2])}<b>${athkar[1]}</b><small>حصّن يومك</small></a>
      <a class="card solid t-gold tile" href="#/tasmee">${icon('mic')}<b>التسميع</b><small>سمّع حفظك ويصحّح لك</small></a>
    </div>
    <div class="grid3" style="margin-top:12px">
      <a class="card qa" href="#/khatmah"><div class="ticon t-emerald">${icon('book')}</div>${goal ? `${ar(Math.min(doneToday, goal))}/${ar(goal)}` : 'حدّد هدفك'}<small class="muted">وردي</small></a>
      <a class="card qa" href="#/khatmah"><div class="ticon t-amethyst">${icon('flag')}</div>${k ? ar(Math.round((k.pages.length / 604) * 100)) + '٪' : 'ابدأ'}<small class="muted">الختمة</small></a>
      <a class="card qa" href="#/stats"><div class="ticon t-amber">${icon('star')}</div>${ar(st)} ${st === 1 ? 'يوم' : 'أيام'}<small class="muted">المداومة</small></a>
    </div>
    <div class="section">الوصول السريع</div>
    <div class="grid3">${QUICK.map(([h, t, ic, tone]) => `<a class="card qa" href="${h}"><div class="ticon t-${tone}">${icon(ic)}</div>${t}</a>`).join('')}</div>
    <div class="section">آية اليوم</div>
    <div class="card" id="aotd"><p class="muted center">…</p></div>
    <p class="center muted small" style="margin-top:22px">صدقة جارية عن روح سمير حجازي وسعد صالح وجميع المسلمين</p>`;

  hijriToday().then((h) => { $('#hdate').textContent = `${ar(h.d)} ${HMONTHS[h.m - 1]} ${ar(h.y)} هـ`; }).catch(() => {});
  tickPrayer();
  ayahOfDay(m, names);
}

async function tickPrayer() {
  const el = $('#next');
  if (!location()) {
    $('#nname').textContent = 'مواقيت الصلاة';
    $('#ntime').textContent = 'اضغط لتحديد موقعك';
    return;
  }
  let np = await nextPrayer().catch(() => null);
  if (!np || !el.isConnected) return;
  const city = location().city;
  const paint = async () => {
    if (!el.isConnected) return clearInterval(timer);
    if (np[1] <= new Date()) np = await nextPrayer();
    $('#nname').textContent = NAMES[np[0]];
    $('#ntime').textContent = `${hm(np[1])}${city ? ' • ' + city : ''}`;
    $('#ncount').textContent = `باقي ${countdown(np[1])}`;
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
    box.innerHTML = `<div class="verse">${esc(t)}</div>
      <p class="center muted small">سورة ${esc(name)} • الآية ${ar(m.ayah[g - 1])}</p>
      <div class="row" style="justify-content:center;gap:10px">
        <button class="btn ghost" id="al">${icon('play')} استماع</button>
        <button class="btn ghost" id="as">${icon('share')} مشاركة</button>
        <a class="btn ghost" href="#/mushaf/${m.page[g - 1]}">${icon('book')}</a>
      </div>`;
    $('#al', box).onclick = () => player.play(ayahItems(g, g, null, () => `سورة ${name} • ${ar(m.ayah[g - 1])}`), 'آية اليوم');
    $('#as', box).onclick = () => {
      if (navigator.share) navigator.share({ text: ref }).catch(() => {});
      else navigator.clipboard?.writeText(ref).then(() => toast('نُسخت الآية'));
    };
  } catch {
    box.innerHTML = '<p class="muted center">تعذر جلب آية اليوم.</p>';
  }
}

export function leave() { clearInterval(timer); }
