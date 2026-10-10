// الحفظ: choose a range of ayat, repeat each ayah and the whole range, and
// read the ayah being recited.
import { $, ar, esc, icon, store, meta, surahs, data, top } from './app.js';
import { player, ayahItems } from './player.js';
import { ayahText, globalAyah } from './page.js';

let off;

export async function show(view, args) {
  const [m, names, reciters] = await Promise.all([meta(), surahs(), data('reciters.json')]);
  const st = store.get('hifz', { s: 1, f: 1, t: 7, each: 3, times: 1 });
  if (args[0]) {
    const g = +args[0];
    st.s = m.surah[g - 1]; st.f = m.ayah[g - 1]; st.t = st.f;
  }
  const rec = store.get('reciter', { id: 'ar.alafasy', bitrate: 128 });
  view.innerHTML = top('الحفظ', 'نطاق وتكرار', 'amethyst', 'repeat') + `
    <div class="card">
      <label class="small muted">السورة</label>
      <select class="field" id="s">${names.map((s) => `<option value="${s[0]}"${s[0] === st.s ? ' selected' : ''}>${ar(s[0])}. ${esc(s[1])}</option>`).join('')}</select>
      <div class="grid" style="margin-top:10px">
        <div><label class="small muted">من الآية</label><select class="field" id="f"></select></div>
        <div><label class="small muted">إلى الآية</label><select class="field" id="t"></select></div>
      </div>
      <div class="row" style="margin-top:12px"><span class="grow">تكرار كل آية</span><button class="chip" data-d="each,-1">−</button><b id="each" style="min-width:40px;text-align:center"></b><button class="chip" data-d="each,1">+</button></div>
      <div class="row" style="margin-top:10px"><span class="grow">تكرار المقطع</span><button class="chip" data-d="times,-1">−</button><b id="times" style="min-width:40px;text-align:center"></b><button class="chip" data-d="times,1">+</button></div>
      <label class="small muted" style="display:block;margin-top:12px">القارئ</label>
      <select class="field" id="r">${reciters.map((r) => `<option value="${r.id}"${r.id === rec.id ? ' selected' : ''}>${esc(r.name)}${r.style ? ' • ' + esc(r.style) : ''}</option>`).join('')}</select>
      <button class="btn block" id="go" style="margin-top:14px">${icon('play')} ابدأ التكرار</button>
    </div>
    <div class="card" id="now" hidden style="margin-top:12px"><p class="small muted center" id="lbl" style="margin:0"></p><div class="verse" id="txt"></div></div>
    <a class="card row" href="#/tasmee" style="margin-top:12px">${icon('mic', 'gold')}<span class="grow"><b>سمّع ما حفظت</b><br><small class="muted">التسميع يخفي الكلمات ويصحّح لك</small></span>${icon('back', 'muted')}</a>`;
  const fill = () => {
    const n = names[st.s - 1][2];
    st.f = Math.min(st.f, n); st.t = Math.min(Math.max(st.t, st.f), n);
    const opts = (v, min) => Array.from({ length: n - min + 1 }, (_, i) => i + min).map((a) => `<option${a === v ? ' selected' : ''}>${a}</option>`).join('');
    $('#f', view).innerHTML = opts(st.f, 1);
    $('#t', view).innerHTML = opts(st.t, st.f);
    $('#each', view).textContent = ar(st.each);
    $('#times', view).textContent = st.times ? ar(st.times) : '∞';
    store.set('hifz', st);
  };
  fill();
  $('#s', view).onchange = (e) => { st.s = +e.target.value; st.f = 1; st.t = Math.min(7, names[st.s - 1][2]); fill(); };
  $('#f', view).onchange = (e) => { st.f = +e.target.value; fill(); };
  $('#t', view).onchange = (e) => { st.t = +e.target.value; fill(); };
  view.onclick = (e) => {
    const d = e.target.closest('[data-d]');
    if (!d) return;
    const [k, v] = d.dataset.d.split(',');
    st[k] = Math.max(k === 'times' ? 0 : 1, Math.min(20, st[k] + +v));
    fill();
  };
  $('#go', view).onclick = async () => {
    const r = reciters.find((x) => x.id === $('#r', view).value) || reciters[0];
    const g = await globalAyah(st.s, st.f);
    player.play(ayahItems(g, g + st.t - st.f, { id: r.id, bitrate: r.bitrate }, (x) => `سورة ${names[st.s - 1][1]} • ${ar(m.ayah[x - 1])}`),
      `حفظ سورة ${names[st.s - 1][1]}`, { each: st.each, times: st.times });
  };
  const paint = async (it) => {
    const box = $('#now', view);
    if (!box) return;
    if (!it?.ayah) { box.hidden = true; return; }
    box.hidden = false;
    $('#lbl', view).textContent = it.label || '';
    $('#txt', view).textContent = await ayahText(it.ayah);
  };
  off?.();
  off = player.on(paint);
  paint(player.current);
}

export function leave() { off?.(); off = null; }
