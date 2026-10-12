// Pictures to share, in the app's black and gold: a thikr, dua, name of
// Allah or hadith (as tall as the text needs), and a monthly timetable.
import { icon, sheet, toast } from './app.js';

const W = 1080;
const GOLD = '#E2C074';
const LINK = 'al-huda.xyz';

const img = (src) => new Promise((ok) => { const i = new Image(); i.onload = () => ok(i); i.onerror = () => ok(null); i.src = src; });
let logoP = null;
const logo = () => (logoP ||= img('img/logo_mark.png'));
const fonts = () => Promise.all(['700 60px ReemKufi', '800 30px Tajawal', '700 30px Tajawal', '40px Hafs'].map((f) => document.fonts.load(f))).catch(() => {});

function round(c, x, y, w, h, r) { c.beginPath(); c.roundRect ? c.roundRect(x, y, w, h, r) : c.rect(x, y, w, h); }
function text(c, s, x, y, font, color, maxW) {
  c.font = font; c.fillStyle = color; c.textAlign = 'center'; c.textBaseline = 'middle'; c.direction = 'rtl';
  c.fillText(s, x, y, maxW);
}
/// Words in lines no wider than [maxW].
function wrap(c, s, font, maxW) {
  c.font = font; c.direction = 'rtl';
  const out = [];
  for (const para of String(s).split('\n')) {
    let line = '';
    for (const w of para.split(/\s+/).filter(Boolean)) {
      const next = line ? `${line} ${w}` : w;
      if (line && c.measureText(next).width > maxW) { out.push(line); line = w; } else line = next;
    }
    out.push(line);
  }
  return out;
}

function frame(c, h, lg) {
  const g = c.createLinearGradient(0, 0, 0, h);
  g.addColorStop(0, '#050505'); g.addColorStop(0.55, '#15100A'); g.addColorStop(1, '#2A1F0C');
  c.fillStyle = g; c.fillRect(0, 0, W, h);
  const glow = c.createRadialGradient(W / 2, 160, 0, W / 2, 160, 640);
  glow.addColorStop(0, 'rgba(226,192,116,.18)'); glow.addColorStop(1, 'rgba(226,192,116,0)');
  c.fillStyle = glow; c.fillRect(0, 0, W, h);
  c.strokeStyle = 'rgba(226,192,116,.45)'; c.lineWidth = 3;
  round(c, 34, 34, W - 68, h - 68, 44); c.stroke();
  if (lg) {
    c.globalAlpha = 0.045; c.drawImage(lg, W / 2 - 410, h / 2 + 40 - 410, 820, 820); c.globalAlpha = 1;
    c.drawImage(lg, W / 2 - 50, 128 - 50, 100, 100);
  }
}
function footer(c, h) { text(c, `تطبيق الهدى • ${LINK}`, W / 2, h - 92, '800 34px Tajawal', 'rgba(226,192,116,.9)'); }

/// [card] = {title, body, big?, source?, quran?} -> PNG blob.
export async function drawCard(card) {
  await fonts();
  const lg = await logo();
  const cv = document.createElement('canvas');
  const c = cv.getContext('2d');
  const bigH = card.big ? 260 : 0;
  const maxW = W - 220;
  let size = card.big ? 46 : 58, lines, lh, font;
  for (;;) {
    font = card.quran ? `${size + 4}px Hafs` : `700 ${size}px Tajawal`;
    lh = (size + (card.quran ? 4 : 0)) * (card.quran ? 1.9 : 1.75);
    lines = wrap(c, card.body, font, maxW);
    if (lines.length * lh <= 760 - bigH || size <= 34) break;
    size -= 2;
  }
  const bodyH = lines.length * lh;
  const srcH = card.source ? 44 + 90 : 0;
  const top = 330;
  const h = Math.max(1350, top + bigH + bodyH + srcH + 190);
  cv.width = W; cv.height = h;
  frame(c, h, lg);
  text(c, card.title, W / 2, 236, '700 62px ReemKufi', GOLD, W - 160);
  c.strokeStyle = 'rgba(226,192,116,.55)'; c.lineWidth = 2.5;
  c.beginPath(); c.moveTo(W / 2 - 200, 292); c.lineTo(W / 2 - 26, 292); c.moveTo(W / 2 + 26, 292); c.lineTo(W / 2 + 200, 292); c.stroke();
  c.fillStyle = GOLD; c.beginPath(); c.arc(W / 2, 292, 7, 0, 7); c.fill();
  let y = top + ((h - top - 190) - (bigH + bodyH + srcH)) / 2;
  if (card.big) { text(c, card.big, W / 2, y + bigH / 2, '150px Hafs', GOLD, W - 160); y += bigH; }
  for (const l of lines) { text(c, l, W / 2, y + lh / 2, font, '#fff'); y += lh; }
  if (card.source) {
    y += 50;
    c.font = '700 30px Tajawal';
    const sw = Math.min(W - 200, c.measureText(card.source).width + 64);
    round(c, W / 2 - sw / 2, y, sw, 64, 40);
    c.fillStyle = 'rgba(226,192,116,.12)'; c.fill();
    c.strokeStyle = 'rgba(226,192,116,.4)'; c.lineWidth = 2; c.stroke();
    text(c, card.source, W / 2, y + 33, '700 30px Tajawal', GOLD, W - 240);
  }
  footer(c, h);
  return new Promise((ok) => cv.toBlob(ok, 'image/png'));
}

/// A monthly timetable: {title, subtitle, header[], rows[][], highlight} -> PNG blob.
export async function drawTable({ title, subtitle, header, rows, highlight = -1, note = '' }) {
  await fonts();
  const lg = await logo();
  const TOP = 400, HEAD = 66, ROW = 52;
  const h = TOP + HEAD + 8 + rows.length * ROW + 150;
  const cv = document.createElement('canvas');
  cv.width = W; cv.height = h;
  const c = cv.getContext('2d');
  frame(c, h, null);
  if (lg) c.drawImage(lg, W / 2 - 48, 118 - 48, 96, 96);
  text(c, title, W / 2, 236, '700 72px ReemKufi', GOLD, W - 120);
  text(c, subtitle, W / 2, 320, '800 42px Tajawal', '#fff', W - 160);
  const left = 70, right = W - 70, firstW = 210;
  const otherW = (right - left - firstW) / (header.length - 1);
  const cx = (i) => (i === 0 ? right - firstW / 2 : right - firstW - otherW * (i - 0.5));
  round(c, left, TOP, right - left, HEAD, 22); c.fillStyle = GOLD; c.fill();
  header.forEach((t, i) => text(c, t, cx(i), TOP + HEAD / 2, '800 28px Tajawal', '#1A1206', i === 0 ? firstW : otherW));
  rows.forEach((r, j) => {
    const y = TOP + HEAD + 8 + j * ROW;
    const on = j === highlight;
    if (on || j % 2) { round(c, left, y + 2, right - left, ROW - 4, 16); c.fillStyle = on ? 'rgba(226,192,116,.30)' : 'rgba(255,255,255,.04)'; c.fill(); }
    r.forEach((t, i) => text(c, t, cx(i), y + ROW / 2, i === 0 ? '700 26px Tajawal' : '700 29px ReemKufi',
      on ? '#fff' : i === 0 ? 'rgba(255,255,255,.85)' : GOLD, i === 0 ? firstW : otherW));
  });
  if (note) text(c, note, W / 2, h - 118, '26px Tajawal', 'rgba(255,255,255,.6)', W - 160);
  footer(c, h);
  return new Promise((ok) => cv.toBlob(ok, 'image/png'));
}

/// The share sheet, the PNG, or a download where the browser cannot share files.
export async function deliverImage(blob, name, textMsg) {
  const file = new File([blob], name, { type: 'image/png' });
  if (navigator.canShare?.({ files: [file] })) {
    try { await navigator.share({ files: [file], text: textMsg }); return; } catch (e) { if (e.name === 'AbortError') return; }
  }
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob); a.download = name;
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 60000);
  toast('تم تنزيل الصورة');
}

/// «مشاركة»: as a picture, as text, or copied.
export function shareChoice(card, plain) {
  const withLink = `${plain}\n\n— تطبيق الهدى https://${LINK}`;
  sheet(`<h3>مشاركة</h3><div class="list">
      <button data-k="image">${icon('share', 'gold')}<span class="grow"><b>مشاركة كصورة</b><br><small class="muted">بطاقة بتصميم الهدى للحالة أو المحادثة</small></span></button>
      <button data-k="text">${icon('book', 'gold')}<span class="grow"><b>مشاركة كنص</b><br><small class="muted">النص كما هو</small></span></button>
      <button data-k="copy">${icon('copy', 'gold')}<span class="grow"><b>نسخ</b><br><small class="muted">إلى الحافظة</small></span></button></div>`,
  (body, close) => {
    body.onclick = async (e) => {
      const b = e.target.closest('[data-k]');
      if (!b) return;
      close();
      if (b.dataset.k === 'copy') { navigator.clipboard?.writeText(plain).then(() => toast('تم النسخ')); return; }
      if (b.dataset.k === 'text') {
        if (navigator.share) navigator.share({ text: withLink }).catch(() => {});
        else navigator.clipboard?.writeText(withLink).then(() => toast('نُسخ النص'));
        return;
      }
      try {
        const blob = await drawCard(card);
        await deliverImage(blob, `alhuda_${Date.now()}.png`, withLink);
      } catch (err) { console.error(err); toast('تعذر تجهيز الصورة'); }
    };
  });
}

