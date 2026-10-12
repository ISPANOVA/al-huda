// الختمة الجماعية: one khatmah shared by a link; everyone takes a juz, reads
// it and marks it done, and all see how far the khatmah has come.
import { $, ar, esc, icon, store, top, toast, sheet, afterSheet } from './app.js';

const API = '/api/khatmah';
const JUZ_PAGES = [1, 22, 42, 62, 82, 102, 121, 142, 162, 182, 201, 222, 242, 262, 282, 302, 322, 342, 362, 382, 402, 422, 442, 462, 482, 502, 522, 542, 562, 582];
const SITE = 'https://al-huda.xyz';

/// This browser's own key (never shown): the parts it took, the khatmahs it made.
function device() {
  let d = store.get('groupDevice', '');
  if (!/^[A-Za-z0-9_-]{16,64}$/.test(d)) {
    const a = crypto.getRandomValues(new Uint8Array(18));
    d = btoa(String.fromCharCode(...a)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    store.set('groupDevice', d);
  }
  return d;
}
const mine = () => store.get('groups', []); // [{id, name}]
function remember(k) {
  const list = mine().filter((g) => g.id !== k.id);
  list.unshift({ id: k.id, name: k.name });
  store.set('groups', list.slice(0, 20));
}
function forget(id) { store.set('groups', mine().filter((g) => g.id !== id)); }

async function api(path, body) {
  const r = await fetch(API + path, body
    ? { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ ...body, d: device() }) }
    : { cache: 'no-store' });
  let j = {};
  try { j = await r.json(); } catch {}
  if (!r.ok && !j.parts) { const e = new Error(j.error || 'net'); e.code = j.error || (r.status === 503 ? 'disabled' : 'net'); throw e; }
  return j;
}
const why = (e) => ({
  disabled: 'الختمة الجماعية لم تُفعَّل على الخادم بعد',
  notfound: 'لم نجد هذه الختمة، تأكد من الرابط',
  net: 'تعذر الاتصال، تحقق من الإنترنت',
}[e.code] || 'حدث خطأ، حاول مرة أخرى');

/// The id in a pasted link or code: «…#/group/abc123», «abc123».
export function idOf(s) {
  const m = String(s).trim().match(/(?:group\/|k=)?([a-z0-9]{6,16})\s*$/i);
  return m ? m[1].toLowerCase() : '';
}
const linkOf = (id) => `${SITE}/#/group/${id}`;

export async function show(view, args) {
  if (args[0]) return group(view, idOf(args[0]));
  const list = mine();
  view.innerHTML = top('الختمة الجماعية', 'اختموا القرآن معًا، كل واحد بجزء', 'emerald', 'flag') + `
    <div class="card solid t-emerald" style="line-height:1.9">أنشئ ختمة وأرسل رابطها لأهلك وأصحابك: يختار كل واحد جزءًا، ويعلّمه عند إتمامه، ويرى الجميع تقدّم الختمة.</div>
    <div class="section">ختمة جديدة</div>
    <div class="card">
      <input class="field" id="gn" maxlength="60" placeholder="اسم الختمة، مثل: ختمة العائلة">
      <input class="field" id="gw" maxlength="30" placeholder="اسمك" value="${esc(store.get('groupName', ''))}" style="margin-top:8px">
      <button class="btn block" id="gc" style="margin-top:10px">${icon('flag')} إنشاء الختمة</button>
    </div>
    <div class="section">الانضمام برابط</div>
    <div class="card row" style="gap:8px"><input class="field grow" id="gj" placeholder="الصق رابط الختمة أو رمزها"><button class="btn" id="gjb">انضمام</button></div>
    ${list.length ? `<div class="section">ختماتي</div><div class="card list">${list.map((g) => `<a href="#/group/${g.id}">${icon('flag', 'gold')}<span class="grow"><b>${esc(g.name)}</b></span>${icon('back', 'muted')}</a>`).join('')}</div>` : ''}`;
  $('#gc', view).onclick = async () => {
    const who = $('#gw', view).value.trim();
    if (!who) { toast('اكتب اسمك أولًا'); $('#gw', view).focus(); return; }
    store.set('groupName', who);
    const b = $('#gc', view);
    b.disabled = true;
    try {
      const k = await api('', { name: $('#gn', view).value.trim() || 'ختمة جماعية', who });
      remember(k);
      location.hash = `#/group/${k.id}`;
      setTimeout(() => invite(k), 400);
    } catch (e) { toast(why(e)); }
    b.disabled = false;
  };
  $('#gjb', view).onclick = () => {
    const id = idOf($('#gj', view).value);
    if (!id) { toast('الرابط غير صحيح'); return; }
    location.hash = `#/group/${id}`;
  };
}

function invite(k) {
  const text = `انضم إلى «${k.name}» واختر جزءًا تقرؤه، نختم القرآن معًا 🤍\n${linkOf(k.id)}`;
  if (navigator.share) navigator.share({ text }).catch(() => {});
  else navigator.clipboard?.writeText(text).then(() => toast('نُسخ رابط الدعوة')).catch(() => toast(linkOf(k.id)));
}

async function group(view, id) {
  view.innerHTML = top('الختمة الجماعية', '', 'emerald', 'flag') + '<div id="gb"><div class="spin"></div></div>';
  const body = $('#gb', view);
  let k;
  try { k = await api(`/${id}?d=${encodeURIComponent(device())}`); }
  catch (e) {
    body.innerHTML = `<div class="card center" style="padding:24px">${esc(why(e))}</div>
      <a class="btn ghost block" href="#/group" style="margin-top:10px">الختمات الجماعية</a>`;
    return;
  }
  remember(k);
  const paint = () => {
    const pct = Math.round((k.done / 30) * 100);
    view.querySelector('.top p')?.remove();
    view.querySelector('.top h1').textContent = k.name;
    const label = (p) => (p.done ? 'تمّ' : !p.readers.length ? 'متاح' : p.readers.length === 1 ? esc(p.readers[0].who || '') : `${ar(p.readers.length)} يقرؤونه`);
    body.innerHTML = `
      <div class="card solid t-emerald">
        <div class="row"><b class="grow" style="font-size:18px">أُتمّ ${ar(k.done)} من ٣٠ جزءًا</b><b style="font-size:22px">${ar(pct)}٪</b></div>
        <div class="bar" style="margin:10px 0"><i style="width:${pct}%"></i></div>
        <small>${[k.ownerName ? `أنشأها ${esc(k.ownerName)}` : '', k.completed ? `أتممتم ${ar(k.completed)} ${k.completed === 1 ? 'ختمة' : 'ختمات'} معًا` : '', `يقرأ معكم ${ar(k.readers || 0)}`].filter(Boolean).join(' • ')}</small>
      </div>
      <button class="btn block" id="inv" style="margin-top:10px">${icon('share')} ادعُ غيرك إلى الختمة</button>
      <div class="section">الأجزاء</div>
      <p class="muted small" style="margin:-4px 0 10px">اختر أي جزء تقرؤه، حتى لو كان غيرك يقرؤه. يُحتسب الجزء عند أول من يتمّه، وعند تمام الثلاثين تبدأ ختمة جديدة بنفس الرابط.</p>
      <div class="juzgrid">${k.parts.map((p) => `<button class="juz${p.done ? ' done' : p.readers.length ? ' taken' : ''}${p.mine ? ' mine' : ''}" data-p="${p.part}">
        <b>${ar(p.part)}</b><small>${label(p)}</small></button>`).join('')}</div>
      ${k.isOwner ? `<button class="btn ghost block" id="rst" style="margin-top:14px">${icon('repeat')} إعادة هذه الختمة من البداية</button>` : ''}
      <button class="chip" id="fg" style="margin:14px auto 0;display:block">إزالة من ختماتي</button>`;
  };
  paint();
  const act = async (path, b) => {
    try { k = await api(`/${id}/${path}`, b); }
    catch (e) { toast(why(e)); return; }
    if (k.justCompleted) toast(`تمّت الختمة رقم ${ar(k.justCompleted)}، تقبّل الله منا ومنكم. بدأت الختمة التالية`);
    paint();
  };
  const myName = async (part) => {
    let who = store.get('groupName', '');
    if (who) return who;
    who = await new Promise((ok) => sheet(`<h3>اسمك</h3><p class="muted small">يظهر على الجزء الذي تقرؤه</p>
      <input class="field" id="nm" maxlength="30"><button class="btn block" id="ok" style="margin-top:10px">سأقرأ الجزء ${ar(part)}</button>`,
    (b, close) => { $('#nm', b).focus(); $('#ok', b).onclick = () => { const v = $('#nm', b).value.trim(); if (v) { close(); ok(v); } }; }).then(() => ok('')));
    if (who) store.set('groupName', who);
    return who;
  };
  body.onclick = async (e) => {
    if (e.target.closest('#inv')) return invite(k);
    if (e.target.closest('#fg')) { forget(id); location.hash = '#/group'; return; }
    if (e.target.closest('#rst')) {
      sheet(`<h3>إعادة الختمة</h3><p>تُفرَّغ أجزاء هذه الختمة ويبدأ الجميع من جديد بنفس الرابط.</p><button class="btn block" id="ok">نعم، ابدأ من جديد</button>`,
        (b, close) => { $('#ok', b).onclick = () => { close(); act('restart', {}); }; });
      return;
    }
    const el = e.target.closest('[data-p]');
    if (!el) return;
    const p = k.parts[+el.dataset.p - 1];
    const who = p.readers.length
      ? `<div class="list" style="margin-bottom:8px">${p.readers.map((r) => `<div>${icon(r.done ? 'check' : 'book', r.done ? 'gold' : 'muted')}<span class="grow">${esc(r.who || '')}</span><small class="muted">${r.done ? 'أتمّه' : 'يقرؤه'}</small></div>`).join('')}</div>`
      : '<p class="muted small">لم يختره أحد بعد.</p>';
    const btn = (k2, ic, t) => `<button data-k="${k2}">${icon(ic, 'gold')}<span class="grow"><b>${t}</b></span></button>`;
    sheet(`<h3>الجزء ${ar(p.part)}</h3>${who}<div class="list">
        ${btn('read', 'book', 'اقرأ الجزء في المصحف')}
        ${p.mine ? btn('done', 'check', p.mineDone ? 'لم أُتمّه بعد' : 'أتممت قراءته')
          : `${btn('claim', 'flag', p.readers.length ? 'سأقرؤه أنا أيضًا' : 'سأقرأ هذا الجزء')}${btn('done', 'check', 'قرأته بالفعل')}`}
        ${p.mine ? `<button data-k="release">${icon('back', 'muted')}<span class="grow"><b>لن أقرأه</b></span></button>` : ''}</div>`,
    (b, close) => {
      b.onclick = async (ev) => {
        const x = ev.target.closest('[data-k]');
        if (!x) return;
        close();
        const what = x.dataset.k;
        // The Mushaf opens once the sheet has gone (closing it steps back in the history).
        if (what === 'read') { afterSheet(() => { location.hash = `#/mushaf/${JUZ_PAGES[p.part - 1]}`; }); return; }
        if (what === 'release') { act('release', { part: p.part }); return; }
        if (what === 'done' && p.mine) { act('done', { part: p.part, done: !p.mineDone }); return; }
        const name = await new Promise((ok) => afterSheet(() => myName(p.part).then(ok)));
        if (!name) return;
        act(what === 'claim' ? 'claim' : 'done', { part: p.part, who: name, done: true });
      };
    });
  };
}
