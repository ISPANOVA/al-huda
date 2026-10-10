// التقويم الهجري: the month grid (Umm al-Qura), with the occasions and the
// recommended fasting days.
import { $, ar, esc, icon, core, data, top } from './app.js';
import { HMONTHS } from './prayerlib.js';

const DAYS = ['أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];
const GM = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];

export async function show(view) {
  const [api, cal] = await Promise.all([core(), data('calendar.json')]);
  const n = new Date();
  const [ty, tm, td] = api.hijri(n.getFullYear(), n.getMonth() + 1, n.getDate());
  let y = ty, m = tm;
  view.innerHTML = top('التقويم الهجري', 'المناسبات وأيام الصيام', 'sky', 'cal') + `
    <div class="card">
      <div class="row"><button class="ibtn" id="nx">${icon('fwd')}</button><div class="grow center"><b id="title" style="font-size:19px"></b><br><small class="muted" id="sub"></small></div><button class="ibtn" id="pv">${icon('back')}</button></div>
      <div id="grid" style="display:grid;grid-template-columns:repeat(7,1fr);gap:4px;margin-top:10px;text-align:center"></div>
    </div>
    <div class="section">مناسبات الشهر</div><div class="card list" id="occ"></div>`;
  const render = () => {
    const days = api.hijriDays(y, m);
    const [gy, gm, gd] = api.gregorian(y, m, 1);
    const first = new Date(gy, gm - 1, gd);
    const [ly, lm, ld] = api.gregorian(y, m, days);
    $('#title', view).textContent = `${cal.months?.[m - 1] ?? HMONTHS[m - 1]} ${ar(y)} هـ`;
    $('#sub', view).textContent = `${GM[gm - 1]}${lm !== gm ? ' – ' + GM[lm - 1] : ''} ${ar(ly)}`;
    const occ = cal.occasions.filter((o) => o[0] === m);
    const marked = new Map(occ.map((o) => [o[1], o]));
    let cells = DAYS.map((d) => `<small class="muted">${d}</small>`).join('');
    for (let i = 0; i < first.getDay(); i++) cells += '<span></span>';
    for (let d = 1; d <= days; d++) {
      const g = new Date(first.getFullYear(), first.getMonth(), first.getDate() + d - 1);
      const isToday = y === ty && m === tm && d === td;
      const o = marked.get(d);
      const white = d >= 13 && d <= 15;
      cells += `<div style="padding:6px 0;border-radius:12px;${isToday ? 'background:var(--gold);color:#1a1205;' : o ? 'background:rgba(94,227,176,.14);' : ''}">
        <b>${ar(d)}</b><br><small style="font-size:10px;opacity:.7">${ar(g.getDate())}</small>${white && !isToday ? '<div style="height:3px;width:14px;margin:2px auto 0;border-radius:2px;background:var(--sky-t)"></div>' : ''}</div>`;
    }
    $('#grid', view).innerHTML = cells;
    // Several days of one occasion (the white days, the ten days): one row.
    const rows = [];
    for (const o of occ) {
      const last = rows[rows.length - 1];
      if (last && last[2] === o[2] && last[5] === o[1] - 1) last[5] = o[1]; else rows.push([...o, o[1]]);
    }
    $('#occ', view).innerHTML = rows.map((o) => `<div><span class="num">${ar(o[1])}</span><span class="grow"><b>${esc(o[2])}</b>${o[5] > o[1] ? ` <small class="gold">(${ar(o[1])} – ${ar(o[5])})</small>` : ''}${o[3] ? `<br><small class="muted">${esc(o[3])}</small>` : ''}</span>${o[4] ? '<small class="chip">صيام</small>' : ''}</div>`).join('')
      || '<p class="muted center">لا مناسبات في هذا الشهر</p>';
  };
  render();
  $('#nx', view).onclick = () => { if (--m < 1) { m = 12; y--; } render(); };
  $('#pv', view).onclick = () => { if (++m > 12) { m = 1; y++; } render(); };
}
