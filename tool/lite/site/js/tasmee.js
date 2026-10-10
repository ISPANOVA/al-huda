// التسميع: the page looks like the Mushaf; the browser recognises the
// recitation and the app's own Tasmee engine (compiled from Dart) follows
// it word by word, marking mistakes.
import { $, $$, ar, esc, icon, store, meta, surahs, core, sheet, toast } from './app.js';
import { drawPage, hizbLabel, JUZ } from './page.js';

const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
const IOS = /iP(hone|ad|od)/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);

let api, ps, m, names, view, page = 1, hide, rec, active = false, flash = -1, flashTimer, settleTimer, statusTimer;
let pending = '', heardAny = false, errors = 0, scope = 0, startedAt = 0;

export async function show(v, args) {
  view = v;
  [m, names] = await Promise.all([meta(), surahs()]);
  hide = store.get('tasmeeHide', false);
  page = Math.min(604, Math.max(1, +args[0] || store.get('lastPage', 1)));
  const startAyah = +args[1] || 0;
  view.className = 'view full';
  view.innerHTML = `<div class="mushaf" id="tm">
    <div class="mbar topb">
      <button class="ibtn" id="back">${icon('fwd')}</button>
      <button class="chip" id="scope">القرآن كله ▾</button>
      <span class="sp"></span>
      <button class="ibtn" id="eye" title="إظهار/إخفاء النص">${icon(hide ? 'eyeOff' : 'eye')}</button>
      <button class="chip" id="pg"></button>
    </div>
    <section class="mpage" id="pageBox" style="position:absolute;inset:0"><div class="inner" id="inner" style="bottom:calc(var(--safe-b) + 128px)"></div></section>
    <div class="tctl">
      <div class="status" id="st">جارٍ تجهيز التسميع…</div>
      <div class="row">
        <button class="hbtn" id="hw">${icon('bulb')}كلمة</button>
        <button class="hbtn" id="ha">${icon('lines')}آية</button>
        <button class="mic" id="mic" aria-label="ابدأ التسميع بالميكروفون">${icon('mic')}</button>
        <button class="hbtn" id="sum">${icon('chart')}النتيجة</button>
        <button class="hbtn" id="reset">${icon('repeat')}من جديد</button>
      </div>
    </div>
  </div>`;
  const tm = $('#tm', view);
  $('#back', tm).onclick = () => (history.length > 1 ? history.back() : (location.hash = '#/mushaf'));
  $('#eye', tm).onclick = () => { hide = !hide; store.set('tasmeeHide', hide); $('#eye', tm).innerHTML = icon(hide ? 'eyeOff' : 'eye'); paint(); };
  $('#pg', tm).onclick = pickPage;
  $('#scope', tm).onclick = pickScope;
  $('#mic', tm).onclick = toggle;
  $('#hw', tm).onclick = () => hint(false);
  $('#ha', tm).onclick = () => hint(true);
  $('#sum', tm).onclick = () => summary(false);
  $('#reset', tm).onclick = () => { stop(); init(); draw(); status(readyText()); };
  swipe($('#pageBox', tm));
  addEventListener('resize', onResize);

  await draw();
  try {
    api = await core();
    const text = await (await fetch('data/words.json')).text();
    ps = Array.from(api.tasmeeInit(text));
    if (!view.isConnected) return;
    if (startAyah) startAt(startAyah);
    status(SR ? readyText() : 'المتصفح لا يدعم التعرف على الكلام. افتح الموقع من Chrome أو Safari.');
    paint();
  } catch (e) {
    console.error(e);
    status('تعذر تجهيز التسميع. تأكد من الاتصال ثم أعد المحاولة.');
  }
}

function init() { api?.tasmeeInit(''); scope && api?.tasmeeScope(...surahRange(scope)); flash = -1; }

const readyText = () => 'اضغط الميكروفون واقرأ من حفظك من أي موضع';
function status(t, ms = 0) {
  clearTimeout(statusTimer);
  const el = $('#st', view);
  if (el) el.textContent = t;
  if (ms) statusTimer = setTimeout(() => { if (active) status(listeningText()); }, ms);
}
const listeningText = () => (api?.tasmeeLocated() ? 'أستمع إليك… اقرأ من حفظك' : scope ? `أستمع… اقرأ من أي آية في سورة ${names[scope - 1][1]}` : 'أستمع… اقرأ من أي موضع');

// ------------------------------------------------------------ the page ---
async function draw() {
  const inner = $('#inner', view);
  await drawPage(inner, page);
  const g = m.page.indexOf(page) + 1;
  $('#pg', view).textContent = `${ar(page)} • ${JUZ[m.juz[g - 1] - 1]}`;
  paint();
}

function paint() {
  if (!api || !ps) return;
  const from = ps[page - 1], to = ps[page];
  const states = api.tasmeeStates(from, to);
  const exp = api.tasmeeLocated() ? api.tasmeeExpected() : -1;
  for (const s of $$('#inner span[data-k]', view)) {
    const k = +s.dataset.k;
    if (k < 0) continue;
    const c = states[k] || 'h';
    const lower = c.toLowerCase();
    let cls = '';
    if (lower === 'h') cls = hide ? 'hid' : '';
    else if (lower === 'm') cls = hide ? 'bad hid' : 'bad';
    else if (lower === 'n') cls = 'hint';
    if (c !== lower && lower !== 'm') cls += ' bad';
    if (from + k === exp) cls += ' cur';
    if (from + k === flash) cls += ' flash';
    s.className = cls.trim();
  }
}

let resizeTimer;
function onResize() { clearTimeout(resizeTimer); resizeTimer = setTimeout(draw, 150); }

function goPage(p) {
  p = Math.min(604, Math.max(1, p));
  if (p === page) return;
  page = p;
  draw();
}

function swipe(el) {
  let x0 = 0, y0 = 0;
  el.addEventListener('touchstart', (e) => { x0 = e.touches[0].clientX; y0 = e.touches[0].clientY; }, { passive: true });
  el.addEventListener('touchend', (e) => {
    const dx = e.changedTouches[0].clientX - x0, dy = e.changedTouches[0].clientY - y0;
    if (Math.abs(dx) > 60 && Math.abs(dx) > Math.abs(dy) * 1.5) goPage(page + (dx > 0 ? 1 : -1));
  }, { passive: true });
  el.addEventListener('click', (e) => {
    const w = e.target.closest('span[data-k]');
    if (!w || !api || +w.dataset.k < 0) return;
    // Tap a word: start the recitation from its ayah.
    startAt(+w.dataset.a);
    toast(`ابدأ من سورة ${names[m.surah[+w.dataset.a - 1] - 1][1]} • الآية ${ar(m.ayah[+w.dataset.a - 1])}`);
  });
}

function startAt(g) {
  const p = m.page[g - 1];
  if (p !== page) { page = p; draw(); }
  api.tasmeeStartAt(api.tasmeeWordOf(m.surah[g - 1], m.ayah[g - 1]), ps[p - 1]);
  paint();
}

// --------------------------------------------------------- recognition ---
function toggle() {
  if (!api) return;
  if (active) { stop(); status('متوقف مؤقتًا • اضغط للمتابعة'); return; }
  if (!SR) { help(); return; }
  active = true;
  errors = 0;
  $('#mic', view).classList.add('on');
  $('#mic', view).setAttribute('aria-label', 'إيقاف الاستماع');
  api.tasmeeNewUtterance(true);
  listen();
  status(listeningText());
}

function listen() {
  if (!active) return;
  rec = new SR();
  rec.lang = 'ar-SA';
  rec.interimResults = true;
  rec.continuous = !/Android/.test(navigator.userAgent);
  rec.maxAlternatives = 1;
  startedAt = Date.now();
  rec.onresult = (e) => {
    let text = '', final = true;
    for (let i = 0; i < e.results.length; i++) { text += ' ' + e.results[i][0].transcript; if (!e.results[i].isFinal) final = false; }
    if (text.trim()) heardAny = true;
    clearTimeout(settleTimer);
    if (final && !rec.continuous) { pending = ''; feed(text, true); return; }
    pending = text;
    feed(text, false);
    settleTimer = setTimeout(settle, 1000);
  };
  rec.onerror = (e) => {
    if (e.error === 'not-allowed' || e.error === 'service-not-allowed') { stop(); status('يحتاج التسميع إذن الميكروفون من المتصفح'); help(); return; }
    if (!heardAny && (e.error === 'network' || e.error === 'audio-capture' || e.error === 'language-not-supported') && ++errors >= 3) {
      stop(); status('خدمة التعرف على الكلام لا تعمل في هذا المتصفح'); help(e.error);
    }
  };
  rec.onend = () => {
    settle();
    if (active) setTimeout(() => { if (active) { api.tasmeeNewUtterance(false); listen(); } }, 60);
  };
  try { rec.start(); } catch { setTimeout(listen, 300); }
}

function settle() {
  clearTimeout(settleTimer);
  if (!pending) return;
  const t = pending;
  pending = '';
  feed(t, true);
  // Continuous recognition keeps the words: the next result starts anew.
  if (rec?.continuous && active) { try { rec.stop(); } catch {} }
}

function feed(text, isFinal) {
  const before = api.tasmeeExpected();
  const r = JSON.parse(api.tasmeeFeed(text, isFinal));
  if (r.mistakes > 0) {
    flash = r.flash;
    navigator.vibrate?.([60, 40, 60]);
    beep();
    clearTimeout(flashTimer);
    flashTimer = setTimeout(() => { flash = -1; paint(); }, 900);
  }
  if (r.moved) {
    navigator.vibrate?.(30);
    const w = r.expected;
    const p = ps.findIndex((s, i) => i < 604 && w >= s && w < ps[i + 1]) + 1;
    const g = m.page.indexOf(p) + 1;
    status(`سورة ${names[m.surah[g - 1] - 1][1]} • الصفحة ${ar(p)}`, 3000);
  }
  if (r.located && r.expected < ps[604]) {
    const p = pageOfWord(r.expected);
    if (p !== page) { page = p; draw(); return; }
  }
  paint();
  if (r.done && r.expected !== before) { stop(); summary(true); }
}

function pageOfWord(w) {
  let lo = 0, hi = 603;
  while (lo < hi) { const mid = (lo + hi + 1) >> 1; if (ps[mid] <= w) lo = mid; else hi = mid - 1; }
  return lo + 1;
}

function stop() {
  active = false;
  clearTimeout(settleTimer);
  pending = '';
  try { rec?.abort(); } catch {}
  rec = null;
  const mic = $('#mic', view);
  if (mic) { mic.classList.remove('on'); mic.setAttribute('aria-label', 'ابدأ التسميع بالميكروفون'); }
}

let ctx;
function beep() {
  try {
    ctx ??= new (window.AudioContext || window.webkitAudioContext)();
    const o = ctx.createOscillator(), g = ctx.createGain();
    o.frequency.value = 330; o.type = 'triangle';
    g.gain.setValueAtTime(0.18, ctx.currentTime); g.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.25);
    o.connect(g).connect(ctx.destination); o.start(); o.stop(ctx.currentTime + 0.26);
  } catch {}
}

// --------------------------------------------------------------- hints ---
function hint(ayah) {
  if (!api) return;
  if (!api.tasmeeLocated()) api.tasmeeStartAt(ps[page - 1], ps[page - 1]);
  api.tasmeeHint(ayah);
  const p = pageOfWord(Math.min(api.tasmeeExpected(), ps[604] - 1));
  if (p !== page) { page = p; draw(); } else paint();
}

// --------------------------------------------------------------- scope ---
const surahRange = (s) => [api.tasmeeWordOf(s, 1), api.tasmeeWordOf(s + 1, 1)];

function pickScope() {
  sheet(`<h3>ماذا تسمّع؟</h3><input class="field" id="q" placeholder="ابحث عن سورة" style="margin-bottom:10px">
    <div class="list" id="res"></div>`, (body, close) => {
    const render = (q) => {
      $('#res', body).innerHTML = `<button data-s="0">${icon('book', 'gold')}<span class="grow"><b>القرآن كله</b><br><small class="muted">اقرأ من أي موضع ونتعرّف عليه</small></span></button>` +
        names.filter((s) => !q || s[1].includes(q)).map((s) => `<button data-s="${s[0]}"><span class="num">${ar(s[0])}</span><span class="grow"><b>سورة ${esc(s[1])}</b></span></button>`).join('');
    };
    render('');
    $('#q', body).oninput = (e) => render(e.target.value.trim());
    body.onclick = async (e) => {
      const b = e.target.closest('[data-s]');
      if (!b) return;
      close();
      scope = +b.dataset.s;
      $('#scope', view).textContent = scope ? `سورة ${names[scope - 1][1]} ▾` : 'القرآن كله ▾';
      if (!api) return;
      if (scope) {
        const r = surahRange(scope);
        api.tasmeeScope(r[0], r[1]);
        const g = m.surah.indexOf(scope) + 1;
        page = m.page[g - 1];
        await draw();
      } else api.tasmeeScope(0, ps[604]);
      paint();
      if (active) status(listeningText());
    };
  });
}

function pickPage() {
  sheet(`<h3>الانتقال إلى صفحة</h3><input class="field" id="pn" type="number" inputmode="numeric" min="1" max="604" placeholder="رقم الصفحة (١ - ٦٠٤)">
    <button class="btn block" id="go" style="margin-top:10px">انتقال</button>`, (body, close) => {
    const go = () => { const n = +$('#pn', body).value; if (n >= 1 && n <= 604) { close(); goPage(n); } };
    $('#go', body).onclick = go;
    $('#pn', body).onkeydown = (e) => { if (e.key === 'Enter') go(); };
    $('#pn', body).focus();
  });
}

// ------------------------------------------------------------- summary ---
function summary(finished) {
  if (!api) return;
  const list = JSON.parse(api.tasmeeMistakes());
  sheet(`<h3>${finished ? 'أتممت التسميع، بارك الله فيك' : 'نتيجة التسميع'}</h3>
    <div class="card center ${list.length ? 'wash t-rose' : 'wash t-emerald'}"><div style="font-size:34px;font-weight:900">${ar(list.length)}</div><small class="muted">${list.length === 1 ? 'خطأ' : 'أخطاء'}</small></div>
    <div class="list" style="margin-top:10px">${list.map(([s, a, w, h]) => `<div><span class="grow"><b style="font-family:Hafs,serif;font-size:20px">${esc(w)}</b><br><small class="muted">سورة ${esc(names[s - 1][1])} • الآية ${ar(a)}${h ? ` • سُمع: ${esc(h)}` : ''}</small></span></div>`).join('') || '<p class="muted center">لا أخطاء، ما شاء الله</p>'}</div>
    <p class="muted small center" style="margin-top:12px">التصحيح الآلي قد يخطئ، ولا يغني عن القراءة على شيخ متقن. تطبيق أندرويد يتعرّف على التلاوة بدقة أعلى ودون إنترنت.</p>
    <button class="btn block" id="ok">حسنًا</button>`, (body, close) => { $('#ok', body).onclick = () => close(); });
}

function help(code) {
  sheet(`<h3>الميكروفون لا يعمل للتسميع</h3>
    <p class="muted">${!SR ? `هذا المتصفح لا يدعم التعرف على الكلام. افتح الموقع من ${IOS ? 'Safari' : 'Google Chrome'}.` : `التسميع في المتصفح يعتمد على خدمة التعرف على الكلام في ${IOS ? 'Safari (خدمة الإملاء من Apple)' : 'Chrome (خدمة Google)'}، ويحتاج اتصالًا بالإنترنت.`}</p>
    <div class="list">${(IOS ? [
      'افتح الموقع من Safari نفسه، فهو الأضمن للتسميع على آيفون.',
      'فعّل الإملاء: الإعدادات، ثم عام، ثم لوحة المفاتيح، ثم «تفعيل الإملاء».',
      'اسمح بالميكروفون: الإعدادات، ثم Safari، ثم الميكروفون، ثم «سماح»، وبعدها أعد تحميل الصفحة.',
    ] : [
      'استخدم Google Chrome أو Microsoft Edge (فايرفوكس لا يدعم التسميع).',
      'اسمح بالميكروفون: اضغط رمز القفل بجوار عنوان الصفحة، ثم الميكروفون، ثم «سماح»، وبعدها أعد تحميل الصفحة.',
    ]).concat('تأكد من الاتصال بالإنترنت.').map((t) => `<div>${icon('check', 'gold')}<span class="grow">${t}</span></div>`).join('')}</div>
    ${code ? `<p class="muted small">رمز الخطأ: ${esc(code)}</p>` : ''}
    <button class="btn block" id="ok">حسنًا</button>`, (body, close) => { $('#ok', body).onclick = () => close(); });
}

export function leave() {
  stop();
  removeEventListener('resize', onResize);
  clearTimeout(statusTimer);
}

export { hizbLabel };
