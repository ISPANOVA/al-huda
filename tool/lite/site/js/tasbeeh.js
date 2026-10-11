// المسبحة: a large bead to tap, a target per round, a running total, and
// (as in the app) moving on to the next tasbeeh when a round is done.
import { $, $$, ar, esc, icon, store, top, toast } from './app.js';

const PHRASES = ['سُبْحَانَ اللَّهِ', 'الْحَمْدُ لِلَّهِ', 'اللَّهُ أَكْبَرُ', 'لَا إِلَٰهَ إِلَّا اللَّهُ', 'أَسْتَغْفِرُ اللَّهَ',
  'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ', 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ', 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ'];
const TARGETS = [33, 99, 100, 1000, 0];

export function show(view) {
  const s = Object.assign({ phrase: 0, target: 33, count: 0, total: 0, rounds: 0, auto: true }, store.get('tasbeeh', {}));
  view.innerHTML = top('المسبحة', 'عداد ذكي', 'teal', 'beads') + `
    <div class="chips" id="ph">${PHRASES.map((p, i) => `<button class="chip${i === s.phrase ? ' on' : ''}" data-p="${i}">${esc(p)}</button>`).join('')}</div>
    <div class="center tphrase" id="phrase"></div>
    <div class="beadwrap">
      <svg class="ring" viewBox="0 0 100 100" aria-hidden="true"><circle cx="50" cy="50" r="46" class="rbg"/><circle cx="50" cy="50" r="46" class="rfg" id="ring"/></svg>
      <button class="bead" id="bead" aria-label="تسبيحة"><span id="num"></span></button>
    </div>
    <div class="center muted" id="info"></div>
    <div class="chips" style="justify-content:center;margin-top:14px">${TARGETS.map((t) => `<button class="chip${t === s.target ? ' on' : ''}" data-t="${t}">${t ? ar(t) : '∞'}</button>`).join('')}</div>
    <div class="card row" style="margin-top:14px">${icon('repeat', 'gold')}<span class="grow"><b>الانتقال التلقائي</b><br><small class="muted">إذا أتممت العدد ينتقل إلى التسبيح التالي</small></span><button class="switch${s.auto ? ' on' : ''}" id="auto" aria-label="الانتقال التلقائي"></button></div>
    <div class="row" style="justify-content:center;gap:10px;margin-top:12px">
      <button class="btn ghost" id="undo">${icon('back')} تراجع</button>
      <button class="btn ghost" id="zero">${icon('repeat')} تصفير</button>
    </div>`;
  const save = () => store.set('tasbeeh', s);
  const bead = $('#bead', view), num = $('#num', view), ring = $('#ring', view);
  const C = 2 * Math.PI * 46;
  ring.style.strokeDasharray = `${C}`;
  const paint = (pop = false) => {
    $('#phrase', view).textContent = PHRASES[s.phrase];
    num.textContent = ar(s.count);
    ring.style.strokeDashoffset = `${s.target ? C * (1 - s.count / s.target) : C}`;
    $('#info', view).textContent = `${s.target ? `الهدف ${ar(s.target)}، ` : ''}الجولات ${ar(s.rounds)}، المجموع ${ar(s.total)}`;
    if (pop) { num.classList.remove('pop'); void num.offsetWidth; num.classList.add('pop'); }
  };
  const choose = (i) => {
    s.phrase = i; s.count = 0;
    for (const c of $$('[data-p]', view)) c.classList.toggle('on', +c.dataset.p === i);
    $(`[data-p="${i}"]`, view).scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
    const ph = $('#phrase', view);
    ph.classList.remove('swap'); void ph.offsetWidth; ph.classList.add('swap');
    save(); paint();
  };
  paint();
  bead.addEventListener('pointerdown', (e) => {
    // A ripple from where the finger touched.
    const r = bead.getBoundingClientRect();
    const d = document.createElement('i');
    d.className = 'ripple';
    d.style.left = `${e.clientX - r.left}px`; d.style.top = `${e.clientY - r.top}px`;
    bead.appendChild(d);
    setTimeout(() => d.remove(), 600);
  });
  bead.onclick = () => {
    if (s.target && s.count >= s.target) return; // a round just ended
    s.count++; s.total++;
    if (s.target && s.count >= s.target) {
      s.rounds++;
      navigator.vibrate?.([40, 60, 40]);
      bead.classList.remove('done'); void bead.offsetWidth; bead.classList.add('done');
      paint(true);
      save();
      if (s.auto) {
        const next = (s.phrase + 1) % PHRASES.length;
        toast(`أتممت ${ar(s.target)}، التالي: ${PHRASES[next]}`);
        setTimeout(() => choose(next), 450);
      } else {
        toast(`أتممت ${ar(s.target)}، تقبّل الله`);
        setTimeout(() => { s.count = 0; save(); paint(); }, 450);
      }
      return;
    }
    navigator.vibrate?.(10);
    save(); paint(true);
  };
  view.onclick = (e) => {
    const p = e.target.closest('[data-p]');
    if (p) { choose(+p.dataset.p); return; }
    const t = e.target.closest('[data-t]');
    if (t) { s.target = +t.dataset.t; s.count = 0; for (const c of $$('[data-t]', view)) c.classList.toggle('on', c === t); save(); paint(); }
  };
  $('#auto', view).onclick = (e) => { s.auto = !s.auto; e.currentTarget.classList.toggle('on', s.auto); save(); };
  $('#undo', view).onclick = () => { if (s.count > 0) { s.count--; s.total = Math.max(0, s.total - 1); save(); paint(true); } };
  $('#zero', view).onclick = () => { s.count = 0; s.rounds = 0; s.total = 0; save(); paint(true); };
}
