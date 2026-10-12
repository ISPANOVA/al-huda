// الختمة الجماعية: one khatmah shared by a link; everyone takes a juz, reads
// it and marks it done, and all see how far the khatmah has come.
import { $, ar, esc, icon, store, top, toast, sheet } from './app.js';

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
  else navigator.clipboard?.writeText(text).then(() => toast('نُسخ رابط الدعوة'));
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
    body.innerHTML = `
      <div class="card solid t-emerald">
        <div class="row"><b class="grow" style="font-size:18px">${k.complete ? 'تمّت الختمة، تقبّل الله منا ومنكم' : `أُتمّ ${ar(k.done)} من ٣٠ جزءًا`}</b><b style="font-size:22px">${ar(pct)}٪</b></div>
        <div class="bar" style="margin:10px 0"><i style="width:${pct}%"></i></div>
        <small>${k.ownerName ? `أنشأها ${esc(k.ownerName)} • ` : ''}${k.round > 1 ? `الختمة رقم ${ar(k.round)} • ` : ''}محجوز ${ar(k.taken)} جزءًا</small>
      </div>
      <button class="btn block" id="inv" style="margin-top:10px">${icon('share')} ادعُ غيرك إلى الختمة</button>
      <div class="section">الأجزاء <small class="muted">(اضغط جزءًا فارغًا لتحجزه)</small></div>
      <div class="juzgrid">${k.parts.map((p) => `<button class="juz${p.done ? ' done' : p.who ? ' taken' : ''}${p.mine ? ' mine' : ''}" data-p="${p.part}">
        <b>${ar(p.part)}</b><small>${p.done ? 'تمّ' : p.who ? esc(p.who) : 'متاح'}</small></button>`).join('')}</div>
      ${k.isOwner ? `<button class="btn ghost block" id="rst" style="margin-top:14px">${icon('repeat')} ${k.complete ? 'ابدأ ختمة جديدة بنفس الرابط' : 'إعادة الختمة من البداية'}</button>` : ''}
      <button class="chip" id="fg" style="margin:14px auto 0;display:block">إزالة من ختماتي</button>`;
  };
  paint();
  const act = async (path, b) => {
    try { k = await api(`/${id}/${path}`, b); }
    catch (e) { toast(why(e)); return; }
    if (k.error === 'taken') toast('سبقك أحد إلى هذا الجزء');
    paint();
  };
  body.onclick = async (e) => {
    if (e.target.closest('#inv')) return invite(k);
    if (e.target.closest('#fg')) { forget(id); location.hash = '#/group'; return; }
    if (e.target.closest('#rst')) {
      sheet(`<h3>إعادة الختمة</h3><p>تُفرَّغ الأجزاء كلها ويبدأ الجميع من جديد بنفس الرابط.</p><button class="btn block" id="ok">نعم، ابدأ من جديد</button>`,
        (b, close) => { $('#ok', b).onclick = () => { close(); act('restart', {}); }; });
      return;
    }
    const el = e.target.closest('[data-p]');
    if (!el) return;
    const p = k.parts[+el.dataset.p - 1];
    if (p.mine) {
      sheet(`<h3>الجزء ${ar(p.part)}</h3><div class="list">
          <a href="#/mushaf/${JUZ_PAGES[p.part - 1]}" data-k="read">${icon('book', 'gold')}<span class="grow"><b>اقرأ الجزء</b></span></a>
          <button data-k="done">${icon('check', 'gold')}<span class="grow"><b>${p.done ? 'لم أُتمّه بعد' : 'أتممت قراءته'}</b></span></button>
          <button data-k="release">${icon('back', 'muted')}<span class="grow"><b>ترك الجزء لغيري</b></span></button></div>`,
      (b, close) => {
        b.onclick = (ev) => {
          const x = ev.target.closest('[data-k]');
          if (!x) return;
          close();
          if (x.dataset.k === 'done') act('done', { part: p.part, done: !p.done });
          if (x.dataset.k === 'release') act('release', { part: p.part });
        };
      });
      return;
    }
    if (p.who) {
      if (k.isOwner) {
        sheet(`<h3>الجزء ${ar(p.part)}</h3><p>محجوز لـ ${esc(p.who)}${p.done ? '، وقد أتمّه' : ''}.</p><button class="btn ghost block" id="fr">إتاحة الجزء لغيره</button>`,
          (b, close) => { $('#fr', b).onclick = () => { close(); act('release', { part: p.part }); }; });
      } else toast(p.done ? `أتمّه ${p.who}` : `محجوز لـ ${p.who}`);
      return;
    }
    let who = store.get('groupName', '');
    if (!who) {
      who = await new Promise((ok) => sheet(`<h3>اسمك</h3><p class="muted small">يظهر على الجزء الذي تختاره</p>
        <input class="field" id="nm" maxlength="30"><button class="btn block" id="ok" style="margin-top:10px">حجز الجزء ${ar(p.part)}</button>`,
      (b, close) => { $('#nm', b).focus(); $('#ok', b).onclick = () => { const v = $('#nm', b).value.trim(); if (v) { close(); ok(v); } }; }).then(() => ok('')));
      if (!who) return;
      store.set('groupName', who);
    }
    act('claim', { part: p.part, who });
  };
}
