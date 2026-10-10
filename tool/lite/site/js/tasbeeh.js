// المسبحة: a large bead to tap, a target per round and a running total.
import { $, ar, esc, icon, store, top, toast } from './app.js';

const PHRASES = ['سُبْحَانَ اللَّهِ', 'الْحَمْدُ لِلَّهِ', 'اللَّهُ أَكْبَرُ', 'لَا إِلَٰهَ إِلَّا اللَّهُ', 'أَسْتَغْفِرُ اللَّهَ',
  'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ', 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ', 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ'];
const TARGETS = [33, 99, 100, 1000, 0];

export function show(view) {
  const s = store.get('tasbeeh', { phrase: 0, target: 33, count: 0, total: 0, rounds: 0 });
  view.innerHTML = top('المسبحة', 'عداد ذكي', 'teal', 'beads') + `
    <div class="chips" id="ph">${PHRASES.map((p, i) => `<button class="chip${i === s.phrase ? ' on' : ''}" data-p="${i}">${esc(p)}</button>`).join('')}</div>
    <div class="center" style="margin-top:16px;font-size:24px;font-weight:800" id="phrase"></div>
    <button class="bead" id="bead" aria-label="تسبيحة"></button>
    <div class="center muted" id="info"></div>
    <div class="row" style="justify-content:center;gap:10px;margin-top:14px">
      <div class="chips">${TARGETS.map((t) => `<button class="chip${t === s.target ? ' on' : ''}" data-t="${t}">${t ? ar(t) : '∞'}</button>`).join('')}</div>
    </div>
    <div class="row" style="justify-content:center;gap:10px;margin-top:12px">
      <button class="btn ghost" id="undo">${icon('back')} تراجع</button>
      <button class="btn ghost" id="zero">${icon('repeat')} تصفير</button>
    </div>`;
  const save = () => store.set('tasbeeh', s);
  const paint = () => {
    $('#phrase', view).textContent = PHRASES[s.phrase];
    $('#bead', view).textContent = ar(s.count);
    $('#info', view).textContent = `${s.target ? `الهدف ${ar(s.target)} • ` : ''}الجولات ${ar(s.rounds)} • المجموع ${ar(s.total)}`;
  };
  paint();
  $('#bead', view).onclick = () => {
    s.count++; s.total++;
    if (s.target && s.count >= s.target) {
      s.rounds++; s.count = 0;
      navigator.vibrate?.([40, 60, 40]);
      toast(`أتممت ${ar(s.target)}، تقبّل الله`);
    } else navigator.vibrate?.(10);
    save(); paint();
  };
  view.onclick = (e) => {
    const p = e.target.closest('[data-p]');
    if (p) { s.phrase = +p.dataset.p; s.count = 0; for (const c of view.querySelectorAll('[data-p]')) c.classList.toggle('on', c === p); save(); paint(); }
    const t = e.target.closest('[data-t]');
    if (t) { s.target = +t.dataset.t; s.count = 0; for (const c of view.querySelectorAll('[data-t]')) c.classList.toggle('on', c === t); save(); paint(); }
  };
  $('#undo', view).onclick = () => { if (s.count > 0) { s.count--; s.total = Math.max(0, s.total - 1); save(); paint(); } };
  $('#zero', view).onclick = () => { s.count = 0; s.rounds = 0; s.total = 0; save(); paint(); };
}
export function leave() { const v = document.getElementById('view'); if (v) v.onclick = null; }
