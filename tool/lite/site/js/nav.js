// The bottom bar on phones: the lens sits on the current tab; hold and slide
// a finger along the bar and it follows, letting go opens the tab under it.
// Scrolling a page down folds the bar into a circle at the bottom left (the
// current tab's icon); scrolling up, reaching the top or tapping it opens it.
//
// One pointer handler owns the whole bar (with pointer capture), so a touch
// that starts on it always ends by opening a tab: it never sticks halfway.
import { $, $$ } from './app.js';

const phone = matchMedia('(max-width: 999.98px)');
let nav, lens, links, dot;
let drag = null; // {id, x0, moved, i}

const TONES = { home: 'gold', mushaf: 'emerald', media: 'amethyst', prayer: 'sapphire', athkar: 'rose', more: 'teal' };

function at(clientX) {
  // The link whose box holds x (or the nearest one).
  let best = 0, d = Infinity;
  links.forEach((a, i) => {
    const r = a.getBoundingClientRect();
    const c = r.left + r.width / 2;
    if (Math.abs(clientX - c) < d) { d = Math.abs(clientX - c); best = i; }
  });
  return best;
}

const tone = (a) => `t-${TONES[a.dataset.tab] || 'gold'}`;

function place(i, x) {
  const a = links[i];
  if (!a) return;
  lens.style.width = `${a.offsetWidth}px`;
  lens.style.setProperty('--x', `${x ?? a.offsetLeft}px`);
  lens.className = `lens ${tone(a)}`;
  links.forEach((l, j) => l.classList.toggle('near', j === i));
}

const currentIndex = () => Math.max(0, links.findIndex((a) => a.classList.contains('on')));

/// Called after the router marks the current tab.
export function syncNav() {
  if (!nav) return;
  if (!drag) place(currentIndex());
  const a = links[currentIndex()];
  dot.innerHTML = a.querySelector('svg').outerHTML;
  dot.className = `navdot ${tone(a)}`;
  fold(false);
}

let folded = false;
function fold(v) {
  if (v === folded) return;
  folded = v;
  nav.classList.toggle('fold', v);
}

function down(e) {
  if (!phone.matches || folded || e.button > 0 || drag) return;
  if (!e.target.closest('.navin')) return;
  drag = { id: e.pointerId, x0: e.clientX, moved: false, i: at(e.clientX) };
  try { nav.setPointerCapture(e.pointerId); } catch {}
  nav.classList.add('drag');
}
function move(e) {
  if (!drag || e.pointerId !== drag.id) return;
  if (!drag.moved && Math.abs(e.clientX - drag.x0) < 6) return;
  drag.moved = true;
  const box = nav.querySelector('.navin').getBoundingClientRect();
  const w = links[0].offsetWidth;
  const x = Math.min(Math.max(e.clientX - box.left - w / 2, 6), box.width - 6 - w);
  const i = at(e.clientX);
  if (i !== drag.i) { drag.i = i; navigator.vibrate?.(4); }
  place(i, x);
}
function up(e) {
  if (!drag || e.pointerId !== drag.id) return;
  const i = e.type === 'pointercancel' ? drag.i : at(e.clientX);
  drag = null;
  nav.classList.remove('drag');
  try { nav.releasePointerCapture(e.pointerId); } catch {}
  place(i);
  const a = links[i];
  // The link's own click is skipped (see below): the hash is set here.
  suppress = Date.now();
  if (a && !a.classList.contains('on')) location.hash = a.getAttribute('href');
  else if (a) syncNav();
}
let suppress = 0;

let lastY = 0, run = 0;
function onScroll() {
  const y = window.scrollY;
  const d = y - lastY;
  lastY = y;
  if (!phone.matches || nav.classList.contains('hide')) return;
  if (y < 40) { run = 0; fold(false); return; }
  if (Math.sign(d) !== Math.sign(run)) run = 0;
  run += d;
  if (run > 36) fold(true);
  else if (run < -36) fold(false);
}

export function initNav() {
  nav = $('#nav');
  lens = $('.lens', nav);
  dot = $('.navdot', nav);
  links = $$('.navin a', nav);
  // A held link is not dragged and gets no menu (either would cancel the touch).
  for (const a of links) a.draggable = false;
  nav.addEventListener('dragstart', (e) => e.preventDefault());
  nav.addEventListener('contextmenu', (e) => { if (phone.matches) e.preventDefault(); });
  nav.addEventListener('pointerdown', down);
  nav.addEventListener('pointermove', move);
  nav.addEventListener('pointerup', up);
  nav.addEventListener('pointercancel', up);
  nav.addEventListener('lostpointercapture', (e) => { if (drag && e.pointerId === drag.id) up({ pointerId: e.pointerId, type: 'pointercancel' }); });
  // Taps are handled on pointerup; the click that follows is dropped. Keyboard
  // and screen-reader activation (no pointer) still go through the link.
  nav.addEventListener('click', (e) => {
    if (e.target.closest('.navin a') && Date.now() - suppress < 800) e.preventDefault();
  });
  dot.addEventListener('click', () => { run = 0; fold(false); });
  addEventListener('scroll', onScroll, { passive: true });
  addEventListener('resize', () => { if (!drag) place(currentIndex()); });
  phone.addEventListener?.('change', () => { fold(false); syncNav(); });
}
