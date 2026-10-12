// فيديو بصوت القارئ: an ayah or a passage as a story video (1080x1920), the
// reciter's voice with the words on screen, encoded in the browser
// (WebCodecs + mp4-muxer) and shared to WhatsApp, Instagram, Facebook…
// Also the ayah as a picture (the same frame), for the ayah menu.
import { $, $$, ar, esc, icon, store, data, meta, surahs, top, toast } from './app.js';
import { ayahText } from './page.js';
import { PHOTOS } from './reciters.js';
import { CDN } from './player.js';

const W = 1080, H = 1920;
const LINK = location.host || 'al-huda-brf.pages.dev';
export const BGS = [
  ['gold', 'ذهبي', ['#050505', '#15100A', '#2A1F0C'], '#E2C074', '#fff'],
  ['night', 'ليل', ['#03050F', '#0A1230', '#1D2347'], '#F1D7A0', '#fff'],
  ['emerald', 'زمردي', ['#02140F', '#07301F', '#0E4A33'], '#E2C074', '#fff'],
  ['dawn', 'فجر', ['#141634', '#55376A', '#E08B6E'], '#FFE3B0', '#fff'],
  ['amethyst', 'بنفسجي', ['#0B0716', '#1F1238', '#3A1E63'], '#E6C9FF', '#fff'],
  ['sea', 'فيروزي', ['#021619', '#06363A', '#0D5257'], '#DCC59B', '#fff'],
  ['ivory', 'عاجي', ['#FBF6EA', '#F2E8D2', '#E6D5B3'], '#8A5A1E', '#2B1E12'],
];
const AYAH_KEYS = {
  'ar.alafasy': 'afs', 'ar.abdulbasitmurattal': 'basit', 'ar.husary': 'husr', 'ar.husarymujawwad': 'husr', 'ar.minshawi': 'minsh',
  'ar.abdurrahmaansudais': 'sds', 'ar.saoodshuraym': 'shur', 'ar.mahermuaiqly': 'maher', 'ar.ahmedajamy': 'ajm', 'ar.shaatree': 'shatri',
  'ar.hudhaify': 'hthfi', 'ar.muhammadayyoub': 'ayyub', 'ar.abdullahbasfar': 'bsfr', 'ar.hanirifai': 'hani', 'ar.muhammadjibreel': 'jbrl',
};
// The browser may only read recitations served with CORS: EveryAyah has the
// same reciters (cdn.islamic.network has no CORS headers).
const EVERYAYAH = {
  'ar.alafasy': 'Alafasy_128kbps', 'ar.abdulbasitmurattal': 'Abdul_Basit_Murattal_192kbps', 'ar.husary': 'Husary_128kbps',
  'ar.husarymujawwad': 'Husary_128kbps_Mujawwad', 'ar.minshawi': 'Minshawy_Murattal_128kbps', 'ar.abdurrahmaansudais': 'Abdurrahmaan_As-Sudais_192kbps',
  'ar.saoodshuraym': 'Saood_ash-Shuraym_128kbps', 'ar.mahermuaiqly': 'MaherAlMuaiqly128kbps', 'ar.ahmedajamy': 'Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net',
  'ar.shaatree': 'Abu_Bakr_Ash-Shaatree_128kbps', 'ar.hudhaify': 'Hudhaify_128kbps', 'ar.muhammadayyoub': 'Muhammad_Ayyoub_128kbps',
  'ar.abdullahbasfar': 'Abdullah_Basfar_192kbps', 'ar.hanirifai': 'Hani_Rifai_192kbps', 'ar.muhammadjibreel': 'Muhammad_Jibreel_128kbps',
};
const pad = (n) => String(n).padStart(3, '0');
function audioUrl(r, g, m) {
  const f = EVERYAYAH[r.id];
  return f ? `https://everyayah.com/data/${f}/${pad(m.surah[g - 1])}${pad(m.ayah[g - 1])}.mp3` : `${CDN}/${r.bitrate}/${r.id}/${g}.mp3`;
}
const photoKey = (id) => { const k = AYAH_KEYS[id]; return k && PHOTOS.has(k) ? k : null; };

const img = (src) => new Promise((ok) => { const i = new Image(); i.onload = () => ok(i); i.onerror = () => ok(null); i.src = src; });

// ------------------------------------------------------------- drawing ---
function star(c, x, y, r1, r2) {
  c.beginPath();
  for (let i = 0; i < 16; i++) {
    const a = -Math.PI / 2 + (i * Math.PI) / 8, r = i % 2 ? r2 : r1;
    c.lineTo(x + r * Math.cos(a), y + r * Math.sin(a));
  }
  c.closePath();
}

function background(c, bg, photo, logo) {
  const [id, , cols, accent] = bg;
  if (id === 'photo' && photo) {
    const s = Math.max(W / photo.width, H / photo.height);
    const w = W / s, h = H / s;
    c.drawImage(photo, (photo.width - w) / 2, (photo.height - h) / 2, w, h, 0, 0, W, H);
    const g = c.createLinearGradient(0, 0, 0, H);
    g.addColorStop(0, 'rgba(0,0,0,.55)'); g.addColorStop(0.5, 'rgba(0,0,0,.35)'); g.addColorStop(1, 'rgba(0,0,0,.65)');
    c.fillStyle = g; c.fillRect(0, 0, W, H);
    return;
  }
  const g = c.createLinearGradient(0, 0, 0, H);
  g.addColorStop(0, cols[0]); g.addColorStop(0.55, cols[1]); g.addColorStop(1, cols[2]);
  c.fillStyle = g; c.fillRect(0, 0, W, H);
  if (id === 'night' || id === 'dawn') {
    let seed = 7;
    const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
    for (let i = 0; i < 160; i++) {
      c.fillStyle = `rgba(255,255,255,${(0.25 + rnd() * 0.6) * (id === 'night' ? 1 : 0.35)})`;
      c.beginPath(); c.arc(rnd() * W, rnd() * H * 0.72, 1.2 + rnd() * 2.6, 0, 7); c.fill();
    }
    if (id === 'night') {
      c.fillStyle = '#F5EBC8'; c.beginPath(); c.arc(880, 190, 50, 0, 7); c.fill();
      c.globalCompositeOperation = 'destination-out'; c.beginPath(); c.arc(902, 175, 42, 0, 7); c.fill();
      c.globalCompositeOperation = 'source-over';
      const gg = c.createLinearGradient(0, 0, 0, H); gg.addColorStop(0, cols[0]); gg.addColorStop(0.55, cols[1]);
      c.fillStyle = gg; c.globalCompositeOperation = 'destination-over'; c.fillRect(0, 0, W, H); c.globalCompositeOperation = 'source-over';
    } else {
      const sg = c.createRadialGradient(W / 2, 1640, 0, W / 2, 1640, 480);
      sg.addColorStop(0, 'rgba(255,227,163,.55)'); sg.addColorStop(1, 'rgba(255,227,163,0)');
      c.fillStyle = sg; c.fillRect(0, 1100, W, 820);
      c.fillStyle = '#FFF1C4'; c.beginPath(); c.arc(W / 2, 1640, 120, 0, 7); c.fill();
    }
    skyline(c, id === 'night' ? '#02030A' : '#1A1230');
    return;
  }
  if (id !== 'ivory') {
    const rg = c.createRadialGradient(W / 2, 900, 0, W / 2, 900, 900);
    rg.addColorStop(0, hexA(accent, 0.16)); rg.addColorStop(1, hexA(accent, 0));
    c.fillStyle = rg; c.fillRect(0, 0, W, H);
  }
  c.strokeStyle = hexA(accent, id === 'ivory' ? 0.1 : 0.07); c.lineWidth = 2;
  for (let y = 0, row = 0; y <= H + 180; y += 180, row++) {
    for (let x = row % 2 ? 90 : 0; x <= W + 180; x += 180) { star(c, x, y, 62, 44); c.stroke(); }
  }
  if (logo && id !== 'ivory') { c.globalAlpha = 0.07; c.drawImage(tint(logo, accent), W / 2 - 490, 960 - 490, 980, 980); c.globalAlpha = 1; }
  frame(c, accent);
}

function frame(c, accent) {
  c.strokeStyle = hexA(accent, 0.55); c.lineWidth = 3;
  round(c, 44, 44, W - 88, H - 88, 48); c.stroke();
  c.strokeStyle = hexA(accent, 0.3); c.lineWidth = 1.5;
  round(c, 58, 58, W - 116, H - 116, 36); c.stroke();
  c.fillStyle = hexA(accent, 0.8);
  for (const [x, y] of [[44, 44], [W - 44, 44], [44, H - 44], [W - 44, H - 44]]) { star(c, x, y, 22, 13); c.fill(); }
}

function skyline(c, color) {
  const hz = 1820, x = 250;
  c.fillStyle = color; c.strokeStyle = color;
  c.fillRect(0, hz, W, H - hz);
  c.fillRect(x, hz - 50, 380, 50);
  c.beginPath(); c.arc(x + 190, hz - 50, 95, Math.PI, 0); c.fill();
  c.beginPath(); c.arc(x + 190, hz - 158, 10, 0, 7); c.fill();
  for (const dx of [60, 320]) { c.beginPath(); c.arc(x + dx, hz - 50, 40, Math.PI, 0); c.fill(); }
  for (const mx of [x - 30, x + 410]) {
    round(c, mx - 14, hz - 230, 28, 230, 14); c.fill();
    c.fillRect(mx - 24, hz - 170, 48, 12);
    c.beginPath(); c.arc(mx, hz - 248, 9, 0, 7); c.fill();
  }
  c.lineCap = 'round'; c.lineWidth = 14;
  c.beginPath(); c.moveTo(900, hz); c.lineTo(888, hz - 150); c.stroke();
  c.lineWidth = 9;
  for (let i = 0; i < 6; i++) {
    const a = -Math.PI / 2 + (i - 2.5) * 0.55;
    c.beginPath(); c.moveTo(888, hz - 150); c.lineTo(888 + 75 * Math.cos(a), hz - 150 + 50 * Math.sin(a) + 28); c.stroke();
  }
}

function round(c, x, y, w, h, r) { c.beginPath(); c.roundRect ? c.roundRect(x, y, w, h, r) : c.rect(x, y, w, h); }
function hexA(hex, a) {
  const n = parseInt(hex.slice(1), 16);
  return `rgba(${n >> 16},${(n >> 8) & 255},${n & 255},${a})`;
}
const tinted = new Map();
function tint(image, color) {
  const k = color;
  if (tinted.has(k)) return tinted.get(k);
  const cv = document.createElement('canvas');
  cv.width = image.width; cv.height = image.height;
  const x = cv.getContext('2d');
  x.drawImage(image, 0, 0); x.globalCompositeOperation = 'source-in'; x.fillStyle = color; x.fillRect(0, 0, cv.width, cv.height);
  tinted.set(k, cv);
  return cv;
}

function text(c, s, x, y, font, color, shadow = 0) {
  c.font = font; c.fillStyle = color; c.textAlign = 'center'; c.textBaseline = 'middle'; c.direction = 'rtl';
  if (shadow) { c.shadowColor = 'rgba(0,0,0,.45)'; c.shadowBlur = shadow; }
  c.fillText(s, x, y);
  c.shadowBlur = 0;
}

/// The ayah's words in lines that fit [maxW] at [size].
function lines(c, words, size, maxW) {
  c.font = `${size}px Hafs`;
  const out = [];
  let cur = '';
  for (const w of words) {
    const next = cur ? `${cur} ${w}` : w;
    if (cur && c.measureText(next).width > maxW) { out.push(cur); cur = w; } else cur = next;
  }
  if (cur) out.push(cur);
  return out;
}

const BOX = { x: 96, y: 560, w: 888, h: 800 };
function fit(c, words, size) { const ls = lines(c, words, size, BOX.w); return ls.length * size * 1.85 <= BOX.h ? ls : null; }

/// Splits a long ayah into pages that each fit at a readable size.
export function split(c, txt, num) {
  const words = (txt + (num ? ` ${num}` : '')).split(/\s+/).filter(Boolean);
  if (fit(c, words, 46)) return [txt];
  const pages = [];
  let cur = [];
  for (const w of txt.split(/\s+/).filter(Boolean)) {
    if (cur.length && !fit(c, [...cur, w], 52)) { pages.push(cur.join(' ')); cur = [w]; } else cur.push(w);
  }
  if (cur.length) pages.push(cur.join(' '));
  return pages;
}

/// One frame: [f] = {text, num, surah, reciter, caption}.
export function drawFrame(c, f, bg, assets) {
  const [id, , , accent, ink] = bg;
  c.save();
  c.scale(c.canvas.width / W, c.canvas.height / H);
  background(c, bg, assets.photo, assets.logo);
  if (assets.logo) c.drawImage(tint(assets.logo, accent), W / 2 - 46, 250 - 46, 92, 92);
  text(c, f.surah, W / 2, 380, '700 72px ReemKufi', accent, id === 'ivory' ? 0 : 12);
  c.strokeStyle = hexA(accent, 0.6); c.lineWidth = 2.5;
  c.beginPath(); c.moveTo(W / 2 - 220, 456); c.lineTo(W / 2 - 34, 456); c.moveTo(W / 2 + 34, 456); c.lineTo(W / 2 + 220, 456); c.stroke();
  c.fillStyle = accent; star(c, W / 2, 456, 16, 10); c.fill();
  // The ayah, as large as fits; its number in the accent colour.
  const marker = f.num ? ` ${ar(f.num)}` : '';
  const words = (f.text + marker).split(/\s+/).filter(Boolean);
  let size = 96, ls;
  while (size > 30 && !(ls = fit(c, words, size))) size -= 2;
  ls = ls || lines(c, words, size, BOX.w);
  const lh = size * 1.85, top0 = BOX.y + BOX.h / 2 - (ls.length * lh) / 2;
  c.font = `${size}px Hafs`; c.textAlign = 'center'; c.textBaseline = 'middle'; c.direction = 'rtl';
  ls.forEach((l, i) => {
    const y = top0 + lh * i + lh / 2;
    if (id !== 'ivory') { c.fillStyle = 'rgba(0,0,0,.45)'; c.fillText(l, W / 2, y + 3); }
    c.fillStyle = ink;
    if (i === ls.length - 1 && marker && l.endsWith(marker.trim())) {
      // Draw the line, then the number over it in the accent colour.
      const body = l.slice(0, l.length - marker.trim().length);
      const wB = c.measureText(body).width, wM = c.measureText(marker.trim()).width;
      const total = wB + wM;
      c.textAlign = 'right';
      c.fillText(body, W / 2 + total / 2, y);
      c.fillStyle = accent; c.fillText(marker.trim(), W / 2 + total / 2 - wB, y);
      c.textAlign = 'center';
    } else c.fillText(l, W / 2, y);
  });
  if (f.caption) text(c, f.caption, W / 2, BOX.y + BOX.h + 54, '700 42px ReemKufi', accent);
  // The reciter, with his photo.
  c.font = '800 38px Tajawal';
  const label = `بصوت القارئ ${f.reciter}`;
  const tw = c.measureText(label).width, ps = assets.reciter ? 96 : 0, gap = ps ? 22 : 0, total = tw + ps + gap;
  round(c, W / 2 - total / 2 - 32, 1520 - Math.max(ps, 44) / 2 - 18, total + 64, Math.max(ps, 44) + 36, 80);
  c.fillStyle = id === 'ivory' ? 'rgba(255,255,255,.35)' : 'rgba(0,0,0,.35)'; c.fill();
  c.strokeStyle = hexA(accent, 0.5); c.lineWidth = 2; c.stroke();
  const right = W / 2 + total / 2;
  if (assets.reciter) {
    c.save(); c.beginPath(); c.arc(right - ps / 2, 1520, ps / 2, 0, 7); c.clip();
    c.drawImage(assets.reciter, right - ps, 1520 - ps / 2, ps, ps); c.restore();
    c.strokeStyle = accent; c.lineWidth = 3; c.beginPath(); c.arc(right - ps / 2, 1520, ps / 2, 0, 7); c.stroke();
  }
  c.fillStyle = ink; c.textAlign = 'right'; c.textBaseline = 'middle'; c.direction = 'rtl';
  c.fillText(label, right - ps - gap, 1520);
  pill(c, `تطبيق الهدى • ${LINK}`, 1720, 32, bg);
  c.restore();
}

function pill(c, s, y, size, bg) {
  c.font = `800 ${size}px Tajawal`;
  const w = c.measureText(s).width + 70;
  round(c, W / 2 - w / 2, y - size / 2 - 15, w, size + 30, 60);
  c.fillStyle = bg[3]; c.fill();
  text(c, s, W / 2, y, `800 ${size}px Tajawal`, bg[0] === 'ivory' ? '#fff' : '#1A1206');
}

export function drawOutro(c, bg, assets) {
  const [, , , accent, ink] = bg;
  c.save();
  c.scale(c.canvas.width / W, c.canvas.height / H);
  background(c, bg, assets.photo, assets.logo);
  if (assets.logo) c.drawImage(assets.logo, W / 2 - 150, 700 - 150, 300, 300);
  text(c, 'تطبيق الهدى', W / 2, 940, '700 96px ReemKufi', accent);
  text(c, 'القرآن الكريم • التلاوات • المواقيت • الأذكار', W / 2, 1060, '700 38px Tajawal', ink);
  text(c, 'مجاني بالكامل وبلا إعلانات', W / 2, 1130, '34px Tajawal', ink);
  pill(c, `افتح التطبيق: ${LINK}`, 1300, 40, bg);
  text(c, 'صدقة جارية', W / 2, 1460, '700 36px ReemKufi', accent);
  c.restore();
}

async function assetsFor(reciterId, photo) {
  await Promise.all([document.fonts.load('60px Hafs'), document.fonts.load('700 60px ReemKufi'), document.fonts.load('800 30px Tajawal')]).catch(() => {});
  const k = photoKey(reciterId);
  const [logo, reciter] = await Promise.all([img('img/logo_mark.png'), k ? img(`img/reciters/${k}.jpg`) : null]);
  return { logo, reciter, photo };
}

// ------------------------------------------------------- the ayah image ---
/// The ayah as a story picture: shared (or downloaded) as PNG.
export async function shareAyahImage(g) {
  const [m, names] = await Promise.all([meta(), surahs()]);
  const rec = store.get('reciter', { id: 'ar.alafasy' });
  const reciters = await data('reciters.json');
  const r = reciters.find((x) => x.id === rec.id) || reciters[0];
  const bg = BGS.find((b) => b[0] === store.get('videoBg', 'gold')) || BGS[0];
  const cv = document.createElement('canvas');
  cv.width = W; cv.height = H;
  const assets = await assetsFor(r.id, null);
  const t = await ayahText(g);
  drawFrame(cv.getContext('2d'), { text: t, num: m.ayah[g - 1], surah: `سورة ${names[m.surah[g - 1] - 1][1]}`, reciter: r.name,
    caption: `الآية ${ar(m.ayah[g - 1])}` }, bg, assets);
  const blob = await new Promise((ok) => cv.toBlob(ok, 'image/png'));
  const name = `alhuda_${m.surah[g - 1]}_${m.ayah[g - 1]}.png`;
  await deliver(blob, name, `﴿${t}﴾ [${names[m.surah[g - 1] - 1][1]}: ${ar(m.ayah[g - 1])}]\nمن تطبيق الهدى: ${location.origin}`);
}

async function deliver(blob, name, textMsg) {
  const file = new File([blob], name, { type: blob.type });
  if (navigator.canShare?.({ files: [file] })) {
    try { await navigator.share({ files: [file], text: textMsg }); return; } catch (e) { if (e.name === 'AbortError') return; }
  }
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob); a.download = name;
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 60000);
  toast('تم التنزيل');
}

// ---------------------------------------------------------- the video ---
let built = null; // {blob, name, text}

export async function show(view, args) {
  const [m, names, reciters] = await Promise.all([meta(), surahs(), data('reciters.json')]);
  let s = Math.max(1, Math.min(114, +args[0] || 1));
  let f = Math.max(1, +args[1] || 1);
  let t = +args[2] || (s === 1 ? 7 : f);
  let rec = store.get('reciter', { id: 'ar.alafasy' }).id;
  if (!reciters.some((x) => x.id === rec)) rec = reciters[0].id;
  let bgId = store.get('videoBg', 'gold');
  let photo = null;
  built = null;
  const MAX = 40;
  view.innerHTML = top('فيديو بصوت القارئ', 'شاركه ستوري أو في محادثة', 'rose', 'tv') + `
    <div class="vprev"><canvas id="pv" width="360" height="640"></canvas><video id="vv" playsinline controls loop hidden></video></div>
    <div id="prog" hidden><p class="center small" id="pl"></p><div class="pbar"><i id="pb"></i></div></div>
    <div id="out" hidden>
      <button class="btn block" id="fs" style="margin-top:4px">${icon('expand')} شاهد الفيديو بملء الشاشة</button>
      <div class="section">شارك الفيديو</div>
      <button class="btn block" id="sh">${icon('share')} مشاركة (واتساب، انستجرام، فيسبوك…)</button>
      <button class="btn ghost block" id="dl" style="margin-top:8px">${icon('download')} تنزيل الفيديو</button>
      <p class="muted small center" id="len"></p>
    </div>
    <div class="section">الآيات</div>
    <select class="field" id="vs">${names.map((x) => `<option value="${x[0]}"${x[0] === s ? ' selected' : ''}>${ar(x[0])}. ${esc(x[1])}</option>`).join('')}</select>
    <div class="grid" style="margin-top:10px;grid-template-columns:1fr 1fr">
      <div><label class="small muted">من الآية</label><select class="field" id="vf"></select></div>
      <div><label class="small muted">إلى الآية</label><select class="field" id="vt"></select></div></div>
    <p class="muted small center">حتى ${ar(MAX)} آية في الفيديو</p>
    <div class="section">القارئ</div>
    <select class="field" id="vq">${reciters.map((r) => `<option value="${r.id}"${r.id === rec ? ' selected' : ''}>${esc(r.name)}${r.style ? '، ' + esc(r.style) : ''}</option>`).join('')}</select>
    <div class="section">الخلفية</div>
    <div class="chips" id="vb">${BGS.map(([id, n]) => `<button class="chip${id === bgId ? ' on' : ''}" data-bg="${id}">${n}</button>`).join('')}
      <label class="chip">${icon('download')} صورة من جهازك<input type="file" accept="image/*" id="vph" hidden></label></div>
    <button class="btn block" id="go" style="margin-top:18px">${icon('play')} إنشاء الفيديو</button>
    <p class="muted small center">الفيديو بمقاس الستوري وفيه رابط التطبيق. يُنشأ على جهازك ولا يُرفع لأي مكان.</p>`;

  const pv = $('#pv', view);
  const fill = () => {
    const n = names[s - 1][2];
    f = Math.min(f, n); t = Math.min(Math.max(t, f), Math.min(n, f + MAX - 1));
    const opt = (v, a, b) => { let o = ''; for (let i = a; i <= b; i++) o += `<option${i === v ? ' selected' : ''}>${i}</option>`; return o; };
    $('#vf', view).innerHTML = opt(f, 1, n);
    $('#vt', view).innerHTML = opt(t, f, Math.min(n, f + MAX - 1));
  };
  const bgOf = () => (bgId === 'photo' ? ['photo', 'صورة', ['#000', '#000', '#000'], '#E2C074', '#fff'] : BGS.find((b) => b[0] === bgId) || BGS[0]);
  const preview = async () => {
    const r = reciters.find((x) => x.id === rec) || reciters[0];
    const assets = await assetsFor(r.id, photo);
    const g = m.surah.indexOf(s) + f;
    const txt = await ayahText(g);
    if (!pv.isConnected) return;
    drawFrame(pv.getContext('2d'), { text: txt, num: f, surah: `سورة ${names[s - 1][1]}`, reciter: r.name, caption: `الآية ${ar(f)}` }, bgOf(), assets);
  };
  const reset = () => { built = null; $('#out', view).hidden = true; $('#vv', view).hidden = true; pv.hidden = false; preview(); };
  fill(); preview();
  $('#vs', view).onchange = (e) => { s = +e.target.value; f = 1; t = Math.min(7, names[s - 1][2]); fill(); reset(); };
  $('#vf', view).onchange = (e) => { f = +e.target.value; fill(); reset(); };
  $('#vt', view).onchange = (e) => { t = +e.target.value; fill(); reset(); };
  $('#vq', view).onchange = (e) => { rec = e.target.value; reset(); };
  $('#vb', view).onclick = (e) => {
    const b = e.target.closest('[data-bg]');
    if (!b) return;
    bgId = b.dataset.bg; store.set('videoBg', bgId);
    $$('[data-bg]', view).forEach((x) => x.classList.toggle('on', x === b));
    reset();
  };
  $('#vph', view).onchange = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    photo = await img(URL.createObjectURL(file));
    if (photo) { bgId = 'photo'; $$('[data-bg]', view).forEach((x) => x.classList.remove('on')); reset(); }
  };
  $('#go', view).onclick = async () => {
    const btn = $('#go', view);
    btn.disabled = true;
    $('#prog', view).hidden = false;
    const prog = (label, v) => { $('#pl', view).textContent = label; $('#pb', view).style.width = `${Math.round(v * 100)}%`; };
    try {
      const r = reciters.find((x) => x.id === rec) || reciters[0];
      const res = await render({ s, f, t, r, m, names, bg: bgOf(), photo, prog });
      built = res;
      const v = $('#vv', view);
      v.src = URL.createObjectURL(res.blob);
      v.hidden = false; pv.hidden = true;
      v.play().catch(() => {});
      $('#out', view).hidden = false;
      $('#len', view).textContent = res.seconds > 60
        ? `مدة الفيديو ${ar(Math.round(res.seconds))} ثانية: الستوري في واتساب وانستجرام يعرض دقيقة واحدة، فاختر آيات أقل للستوري.`
        : `مدة الفيديو ${ar(Math.round(res.seconds))} ثانية`;
      // The video first: watch it before saving or sharing.
      $('.vprev', view).scrollIntoView({ behavior: 'smooth', block: 'start' });
    } catch (e) {
      console.error(e);
      toast(e?.message === 'net' ? 'تعذر تحميل التلاوة، تحقق من الاتصال' : 'المتصفح لا يدعم إنشاء الفيديو، جرّب Chrome أو تطبيق الهدى');
    } finally {
      btn.disabled = false;
      $('#prog', view).hidden = true;
    }
  };
  $('#fs', view).onclick = () => {
    const v = $('#vv', view);
    v.currentTime = 0;
    v.play().catch(() => {});
    if (v.requestFullscreen) v.requestFullscreen().catch(() => {});
    else v.webkitEnterFullscreen?.();
  };
  $('#sh', view).onclick = () => built && deliver(built.blob, built.name, built.text);
  $('#dl', view).onclick = () => {
    if (!built) return;
    const a = document.createElement('a');
    a.href = URL.createObjectURL(built.blob); a.download = built.name; a.click();
  };
}

/// Builds the MP4 in the browser. Returns {blob, name, text, seconds}.
async function render({ s, f, t, r, m, names, bg, photo, prog }) {
  const first = m.surah.indexOf(s) + 1;
  const g0 = first + f - 1, g1 = first + t - 1;
  const basmala = f === 1 && s !== 1 && s !== 9;
  const globals = [...(basmala ? [1] : []), ...Array.from({ length: g1 - g0 + 1 }, (_, i) => g0 + i)];

  // 1. The recitation, decoded and joined at 48 kHz stereo.
  const RATE = 48000;
  const ac = new (window.AudioContext || window.webkitAudioContext)({ sampleRate: RATE });
  const parts = [];
  for (let i = 0; i < globals.length; i++) {
    prog(`تحميل التلاوة ${ar(i + 1)} من ${ar(globals.length)}`, (0.25 * i) / globals.length);
    let buf;
    try {
      const res = await fetch(audioUrl(r, globals[i], m));
      if (!res.ok) throw new Error('net');
      buf = await res.arrayBuffer();
    } catch { throw new Error('net'); }
    parts.push(await ac.decodeAudioData(buf));
  }
  ac.close();
  const gap = Math.round(RATE * 0.25), tail = Math.round(RATE * 2.6);
  const lens = parts.map((p) => Math.round(p.duration * RATE) + gap);
  const total = lens.reduce((a, b) => a + b, 0) + tail;
  const L = new Float32Array(total), R = new Float32Array(total);
  let at = 0;
  parts.forEach((p, i) => {
    // decodeAudioData already resampled to the context's 48 kHz.
    const a = p.getChannelData(0), b = p.numberOfChannels > 1 ? p.getChannelData(1) : a;
    L.set(a.subarray(0, Math.min(a.length, total - at)), at);
    R.set(b.subarray(0, Math.min(b.length, total - at)), at);
    at += lens[i];
  });

  // 2. The frames.
  const assets = await assetsFor(r.id, photo);
  const size = (await pickSize()) || [720, 1280, null];
  const cv = document.createElement('canvas');
  cv.width = size[0]; cv.height = size[1];
  const ctx = cv.getContext('2d');
  const shots = []; // {bitmap, start, end} in seconds
  let tsec = 0;
  const surahName = `سورة ${names[s - 1][1]}`;
  for (let i = 0; i < globals.length; i++) {
    prog('تجهيز الصور', 0.25 + (0.1 * i) / globals.length);
    const g = globals[i];
    const isBas = basmala && i === 0;
    const txt = isBas ? 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ' : await ayahText(g);
    const pages = isBas ? [txt] : split(ctx, txt, m.ayah[g - 1]);
    const dur = lens[i] / RATE;
    const sum = pages.reduce((a, p) => a + p.length, 0);
    let st = tsec;
    for (let k = 0; k < pages.length; k++) {
      drawFrame(ctx, { text: pages[k], num: !isBas && k === pages.length - 1 ? m.ayah[g - 1] : null, surah: surahName, reciter: r.name,
        caption: isBas ? 'البسملة' : `الآية ${ar(m.ayah[g - 1])}` }, bg, assets);
      const end = k === pages.length - 1 ? tsec + dur : st + (dur * pages[k].length) / sum;
      shots.push({ bmp: await createImageBitmap(cv), start: st, end });
      st = end;
    }
    tsec += dur;
  }
  drawOutro(ctx, bg, assets);
  shots.push({ bmp: await createImageBitmap(cv), start: tsec, end: total / RATE });

  // 3. Encode and mux: WebCodecs (fast, MP4 with AAC); else the browser
  //    records the video as it plays (takes as long as the video).
  const range = f === t ? `الآية ${ar(f)}` : `الآيات ${ar(f)}–${ar(t)}`;
  const text = `سورة ${names[s - 1][1]} • ${range} • بصوت ${r.name}\nمن تطبيق الهدى: ${location.origin}`;
  let Muxer, ArrayBufferTarget;
  try { ({ Muxer, ArrayBufferTarget } = await import('https://cdn.jsdelivr.net/npm/mp4-muxer@5.1.3/+esm')); } catch {}
  const audioOk = 'AudioEncoder' in window && (await AudioEncoder.isConfigSupported({ codec: 'mp4a.40.2', sampleRate: RATE, numberOfChannels: 2, bitrate: 128000 }).catch(() => ({}))).supported;
  if (!size[2] || !Muxer || !audioOk) {
    const blob = await recordRealtime(cv, ctx, shots, L, R, RATE, total, prog);
    for (const sh of shots) sh.bmp.close?.();
    const ext = blob.type.includes('mp4') ? 'mp4' : 'webm';
    return { blob, name: `alhuda_${s}_${f}_${t}.${ext}`, seconds: total / RATE, text };
  }
  const FPS = 24;
  const target = new ArrayBufferTarget();
  const audioCfg = { codec: 'mp4a.40.2', sampleRate: RATE, numberOfChannels: 2, bitrate: 128000 }, audioCodec = 'aac';
  const muxer = new Muxer({ target, fastStart: 'in-memory',
    video: { codec: 'avc', width: size[0], height: size[1], frameRate: FPS },
    audio: { codec: audioCodec, sampleRate: RATE, numberOfChannels: 2 } });
  let fail = null;
  const venc = new VideoEncoder({ output: (ch, md) => muxer.addVideoChunk(ch, md), error: (e) => { fail = e; } });
  venc.configure({ codec: size[2], width: size[0], height: size[1], bitrate: size[0] >= 1080 ? 3_500_000 : 2_200_000, framerate: FPS });
  const aenc = new AudioEncoder({ output: (ch, md) => muxer.addAudioChunk(ch, md), error: (e) => { fail = e; } });
  aenc.configure(audioCfg);
  const CH = 1024 * 8;
  for (let i = 0; i < total; i += CH) {
    const n = Math.min(CH, total - i);
    const planar = new Float32Array(n * 2);
    planar.set(L.subarray(i, i + n), 0); planar.set(R.subarray(i, i + n), n);
    const ad = new AudioData({ format: 'f32-planar', sampleRate: RATE, numberOfFrames: n, numberOfChannels: 2, timestamp: Math.round((i / RATE) * 1e6), data: planar });
    aenc.encode(ad); ad.close();
  }
  const frames = Math.ceil((total / RATE) * FPS);
  let si = 0;
  const fade = 0.35;
  for (let k = 0; k < frames; k++) {
    if (fail) throw fail;
    const sec = k / FPS;
    while (si < shots.length - 1 && sec >= shots[si].end) si++;
    const into = sec - shots[si].start;
    ctx.globalAlpha = 1;
    ctx.drawImage(shots[si].bmp, 0, 0);
    if (si > 0 && into < fade) { ctx.globalAlpha = 1 - into / fade; ctx.drawImage(shots[si - 1].bmp, 0, 0); ctx.globalAlpha = 1; }
    const vf = new VideoFrame(cv, { timestamp: Math.round(sec * 1e6), duration: Math.round(1e6 / FPS) });
    venc.encode(vf, { keyFrame: k % FPS === 0 });
    vf.close();
    if (venc.encodeQueueSize > 8) await new Promise((ok) => setTimeout(ok, 5));
    if (k % 12 === 0) { prog('إنشاء الفيديو', 0.35 + (0.65 * k) / frames); await new Promise((ok) => setTimeout(ok, 0)); }
  }
  await venc.flush(); await aenc.flush();
  if (fail) throw fail;
  muxer.finalize();
  for (const sh of shots) sh.bmp.close?.();
  const blob = new Blob([target.buffer], { type: 'video/mp4' });
  return { blob, name: `alhuda_${s}_${f}_${t}.mp4`, seconds: total / RATE, text };
}

/// The slower way: the canvas and the sound are played and recorded live.
async function recordRealtime(cv, ctx, shots, L, R, RATE, total, prog) {
  if (!('MediaRecorder' in window) || !cv.captureStream) throw new Error('codecs');
  const type = ['video/mp4;codecs=avc1,mp4a.40.2', 'video/mp4', 'video/webm;codecs=vp9,opus', 'video/webm'].find((x) => MediaRecorder.isTypeSupported(x));
  if (!type) throw new Error('codecs');
  const ac = new AudioContext({ sampleRate: RATE });
  const buf = ac.createBuffer(2, total, RATE);
  buf.copyToChannel(L, 0); buf.copyToChannel(R, 1);
  const src = ac.createBufferSource();
  src.buffer = buf;
  const dest = ac.createMediaStreamDestination();
  src.connect(dest);
  const stream = new MediaStream([...cv.captureStream(30).getVideoTracks(), ...dest.stream.getAudioTracks()]);
  const rec = new MediaRecorder(stream, { mimeType: type, videoBitsPerSecond: 3_000_000 });
  const chunks = [];
  rec.ondataavailable = (e) => e.data.size && chunks.push(e.data);
  const done = new Promise((ok) => { rec.onstop = ok; });
  const dur = total / RATE;
  rec.start(500);
  const t0 = ac.currentTime + 0.05;
  src.start(t0);
  await new Promise((ok) => {
    let si = 0;
    const tick = () => {
      const sec = ac.currentTime - t0;
      if (sec >= dur) return ok();
      while (si < shots.length - 1 && sec >= shots[si].end) si++;
      const into = sec - shots[si].start;
      ctx.globalAlpha = 1;
      ctx.drawImage(shots[si].bmp, 0, 0);
      if (si > 0 && into < 0.35) { ctx.globalAlpha = 1 - into / 0.35; ctx.drawImage(shots[si - 1].bmp, 0, 0); ctx.globalAlpha = 1; }
      prog('تسجيل الفيديو', 0.35 + 0.65 * Math.max(0, sec) / dur);
      requestAnimationFrame(tick);
    };
    tick();
  });
  rec.stop();
  await done;
  ac.close();
  return new Blob(chunks, { type: type.split(';')[0] });
}

/// The largest story size this browser can encode.
async function pickSize() {
  if (!('VideoEncoder' in window)) return null;
  for (const [w, h, codec] of [[1080, 1920, 'avc1.640028'], [1080, 1920, 'avc1.4d0028'], [720, 1280, 'avc1.42001f']]) {
    try {
      const r = await VideoEncoder.isConfigSupported({ codec, width: w, height: h, bitrate: 3e6, framerate: 24 });
      if (r.supported) return [w, h, codec];
    } catch {}
  }
  return null;
}

export function leave() { built = null; }
