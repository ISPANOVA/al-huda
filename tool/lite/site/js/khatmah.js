// الختمة والورد اليومي، وإحصائياتي: built on the pages read in the Mushaf.
import { $, ar, icon, store, top, today, toast } from './app.js';
import { streak } from './home.js';

const PLANS = [7, 10, 15, 20, 30, 60];
const GOALS = [0, 1, 2, 5, 10, 20];
const dayKey = (d) => `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;

export function show(view, args, name) {
  if (name === 'stats') return stats(view);
  const k = store.get('khatmah', null);
  const goal = store.get('wirdGoal', 0);
  const done = (store.get('read', {})[today()] || []).length;
  let plan = '';
  if (k) {
    const pct = k.pages.length / 604;
    const elapsed = Math.floor((Date.now() - k.start) / 864e5) + 1;
    const left = Math.max(1, k.days - elapsed + 1);
    const perDay = Math.ceil((604 - k.pages.length) / left);
    let next = 1;
    const set = new Set(k.pages);
    while (next <= 604 && set.has(next)) next++;
    plan = `<div class="card solid t-emerald">
      <div class="row"><b class="grow" style="font-size:19px">ختمتك في ${ar(k.days)} يومًا</b><b style="font-size:24px">${ar(Math.round(pct * 100))}٪</b></div>
      <div class="bar" style="margin:10px 0"><i style="width:${pct * 100}%"></i></div>
      <small>قرأت ${ar(k.pages.length)} من ٦٠٤ صفحة • اليوم ${ar(Math.min(elapsed, k.days))} من ${ar(k.days)} • المطلوب يوميًا ${ar(perDay)} صفحة</small>
    </div>
    ${next <= 604 ? `<a class="btn block" href="#/mushaf/${next}" style="margin-top:12px">${icon('book')} تابع من الصفحة ${ar(next)}</a>` : `<div class="card center gold" style="margin-top:12px"><b>ختمت القرآن، تقبّل الله منك</b></div>`}
    <button class="btn ghost block" id="end" style="margin-top:10px">إنهاء الختمة</button>`;
  }
  view.innerHTML = top('الختمة والورد', 'خطة قراءة تناسبك', 'emerald', 'flag') + `
    <div class="section">الورد اليومي</div>
    <div class="card">
      <div class="row"><span class="grow"><b>${goal ? `قرأت اليوم ${ar(Math.min(done, goal))} من ${ar(goal)} صفحات` : 'حدّد عدد الصفحات يوميًا'}</b></span>${goal && done >= goal ? `<span class="gold">${icon('check')}</span>` : ''}</div>
      ${goal ? `<div class="bar" style="margin-top:8px"><i style="width:${Math.min(1, done / goal) * 100}%"></i></div>` : ''}
      <div class="chips" style="margin-top:12px">${GOALS.map((g) => `<button class="chip${g === goal ? ' on' : ''}" data-g="${g}">${g ? ar(g) + ' ص' : 'بدون'}</button>`).join('')}</div>
    </div>
    <div class="section">الختمة</div>
    ${plan || `<div class="card"><p style="margin-top:0">اختر مدة الختمة، ونحسب لك ما تقرؤه كل يوم. تُحتسب كل صفحة تفتحها في المصحف.</p>
      <div class="grid3">${PLANS.map((d) => `<button class="card qa" data-p="${d}"><b style="font-size:22px" class="gold">${ar(d)}</b>يومًا<small class="muted">${ar(Math.ceil(604 / d))} ص يوميًا</small></button>`).join('')}</div></div>`}
    <a class="card row" href="#/stats" style="margin-top:12px">${icon('chart', 'gold')}<span class="grow"><b>إحصائياتي</b><br><small class="muted">المداومة والإنجاز</small></span>${icon('fwd', 'muted')}</a>`;
  view.onclick = (e) => {
    const g = e.target.closest('[data-g]');
    if (g) { store.set('wirdGoal', +g.dataset.g); show(view, args, name); return; }
    const p = e.target.closest('[data-p]');
    if (p) { store.set('khatmah', { start: Date.now(), days: +p.dataset.p, pages: [] }); toast('بدأت ختمتك، وفقك الله'); show(view, args, name); return; }
    if (e.target.closest('#end')) { store.set('khatmah', null); show(view, args, name); }
  };
}

function stats(view) {
  const log = store.get('read', {});
  const days = Object.values(log).filter((x) => x.length);
  const total = days.reduce((a, x) => a + x.length, 0);
  const week = [];
  for (let i = 6; i >= 0; i--) {
    const d = new Date(); d.setDate(d.getDate() - i);
    week.push([d, (log[dayKey(d)] || []).length]);
  }
  const max = Math.max(1, ...week.map((w) => w[1]));
  const ath = Object.values(store.get('ath_' + today(), {})).reduce((a, n) => a + n, 0);
  const tas = store.get('tasbeeh', { total: 0 }).total;
  view.innerHTML = top('إحصائياتي', 'المداومة والإنجاز', 'amber', 'chart') + `
    <div class="grid">
      <div class="card solid t-amber tile"><small>المداومة</small><b style="font-size:30px">${ar(streak())}</b><small>أيام متتالية</small></div>
      <div class="card solid t-emerald tile"><small>صفحات اليوم</small><b style="font-size:30px">${ar((log[today()] || []).length)}</b><small>صفحة</small></div>
      <div class="card wash t-sapphire tile"><small>أيام القراءة</small><b style="font-size:26px">${ar(days.length)}</b></div>
      <div class="card wash t-amethyst tile"><small>مجموع الصفحات</small><b style="font-size:26px">${ar(total)}</b></div>
      <div class="card wash t-teal tile"><small>التسبيحات</small><b style="font-size:26px">${ar(tas)}</b></div>
      <div class="card wash t-rose tile"><small>أذكار اليوم</small><b style="font-size:26px">${ar(ath)}</b></div>
    </div>
    <div class="section">آخر ٧ أيام</div>
    <div class="card" style="display:flex;align-items:flex-end;gap:8px;height:180px">${week.map(([d, n]) => `
      <div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:4px;height:100%;justify-content:flex-end">
        <small class="gold">${n ? ar(n) : ''}</small>
        <div style="width:100%;max-width:34px;height:${(n / max) * 100}%;min-height:4px;border-radius:8px;background:linear-gradient(var(--amber-t),var(--amber-d))"></div>
        <small class="muted" style="font-size:11px">${d.toLocaleDateString('ar-EG', { weekday: 'short' })}</small></div>`).join('')}</div>`;
}
