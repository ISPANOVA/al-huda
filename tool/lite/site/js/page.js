// Draws one page of the Madinah Mushaf with HTML: 15 fixed line slots, each
// line justified edge to edge in the KFGQPC Hafs font, like the app.
import { data, meta, esc } from './app.js';
import { colour as colourWord, ready as tajReady } from './tajweed.js';

const NUM = /([\s ]+[٠-٩]+)$/;
export const BASMALA = 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ';

export const pageData = (p) => data(`p/${p}.json`);

/// Fills [inner] (sized box) with page [p]. [word](i, ayah, text) may return
/// extra classes for the i-th word of the page (the Tasmee's colours).
export async function drawPage(inner, p, { word, tajweed = false } = {}) {
  const [lines, m, names] = await Promise.all([pageData(p), meta(), data('surahs.json')]);
  if (tajweed && !tajReady()) tajweed = false;
  let W = inner.clientWidth;
  let H = inner.clientHeight;
  if (!W || !H) return;
  const screenH = window.innerHeight;
  const opening = p <= 2;
  const slots = lines.length >= 13 ? lines.length : 15;
  let lineH = H / slots;
  // As large as the page box allows: the width, or the 15 lines' height.
  let fs = Math.min(W / m.ref * 100, H / slots / 1.6);
  let top0 = 0;
  if (opening) {
    const widest = Math.max(...lines.map((l) => (typeof l[1] === 'number' ? l[1] : 0)), 1);
    lineH = Math.min(lineH * 1.45, H / (lines.length + 1));
    fs = Math.min(lineH / 1.8, W * 0.86 / widest * 100);
    top0 = (H - lineH * lines.length) / 2;
  }
  let html = '';
  let k = 0;
  lines.forEach((l, li) => {
    const top = top0 + li * lineH;
    const box = `top:${top.toFixed(1)}px;height:${lineH.toFixed(1)}px;font-size:${fs.toFixed(2)}px`;
    if (l[0] === 'h') {
      const name = names[l[1] - 1][1];
      const bh = Math.min(lineH * 0.9, fs * 2.3);
      html += `<div class="banner" style="top:${top.toFixed(1)}px;height:${lineH.toFixed(1)}px;font-size:${(fs * 0.92).toFixed(2)}px"><div style="height:${bh.toFixed(1)}px">سُورَةُ ${esc(name)}</div></div>`;
    } else if (l[0] === 'b') {
      html += `<div class="mline c" style="${box}"><span>${BASMALA}</span></div>`;
    } else {
      const centered = l[0] === 'c' || opening;
      const natural = (l[1] || 0) * fs / 100;
      let style = box;
      if (!centered && natural > W) style += `;transform:scaleX(${(W / natural).toFixed(4)});left:auto;width:${natural.toFixed(1)}px`;
      let words = '';
      for (let i = 2; i + 1 < l.length; i += 2) {
        const a = l[i], t = l[i + 1];
        const m2 = t.match(NUM);
        const body = m2 ? t.slice(0, m2.index) : t;
        const paint = (enc) => (m2 ? `${enc(body)}<b class="n">${m2[1]}</b>` : enc(body));
        const text = tajweed && a !== 0 ? colourWord(p, k, paint, esc) : paint(esc);
        const cls = a !== 0 && word ? word(k, a) : '';
        words += `<span data-a="${a}" data-k="${a !== 0 ? k : -1}"${cls ? ` class="${cls}"` : ''}>${text}</span>`;
        if (a !== 0) k++;
      }
      html += `<div class="mline${centered ? ' c' : ''}" style="${style}">${words}</div>`;
    }
  });
  inner.innerHTML = html;
  inner.dataset.drawn = p;
}

/// Text of one ayah (global number) from the page data: a few KB, instead of
/// the whole Quran text.
export async function ayahText(g) {
  const m = await meta();
  const p = m.page[g - 1];
  const pages = [p];
  if (p < 604 && (g >= m.page.length || m.page[g] > p)) pages.push(p + 1);
  const words = [];
  for (const q of pages) {
    for (const l of await pageData(q)) {
      if (l[0] !== 't' && l[0] !== 'c') continue;
      for (let i = 2; i + 1 < l.length; i += 2) if (l[i] === g) words.push(l[i + 1].replace(NUM, ''));
    }
  }
  return words.join(' ');
}

/// Hizb label of an ayah (hizb quarter number 1..240).
export function hizbLabel(hq) {
  const hizb = Math.floor((hq - 1) / 4) + 1;
  const q = (hq - 1) % 4;
  return `${['', '¼ ', '½ ', '¾ '][q]}الحزب ${hizb}`;
}

export const JUZ = ['الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس', 'السادس', 'السابع', 'الثامن', 'التاسع', 'العاشر',
  'الحادي عشر', 'الثاني عشر', 'الثالث عشر', 'الرابع عشر', 'الخامس عشر', 'السادس عشر', 'السابع عشر', 'الثامن عشر',
  'التاسع عشر', 'العشرون', 'الحادي والعشرون', 'الثاني والعشرون', 'الثالث والعشرون', 'الرابع والعشرون', 'الخامس والعشرون',
  'السادس والعشرون', 'السابع والعشرون', 'الثامن والعشرون', 'التاسع والعشرون', 'الثلاثون'];

/// First ayah (global) of each page, and of each surah.
export async function firstAyahOfPage(p) {
  const m = await meta();
  return m.page.indexOf(p) + 1;
}
export async function pageOf(global) {
  const m = await meta();
  return m.page[global - 1];
}
export async function globalAyah(surah, ayah) {
  const m = await meta();
  for (let i = 0; i < m.surah.length; i++) if (m.surah[i] === surah && m.ayah[i] === ayah) return i + 1;
  return 1;
}
