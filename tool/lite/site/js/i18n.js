// The English interface: the same dictionary as the app (data/en.json, from
// assets/i18n/en.json) and the same matching (see lib/core/i18n/i18n.dart).
// Pages are written in Arabic; every text the page shows is translated as it
// appears. The Quran, athkar and duas have no English entry and stay Arabic.

let on = false;
let MAP = {};
let VOCAB = [];
let PATTERNS = [];
const cache = new Map();

export const isEnglish = () => on;
export function language() {
  try { return localStorage.getItem('h_lang') === '"en"' ? 'en' : 'ar'; } catch { return 'ar'; }
}
export function setLanguage(l) {
  try { localStorage.setItem('h_lang', JSON.stringify(l === 'en' ? 'en' : 'ar')); } catch {}
  location.reload();
}

const LETTERS = /[ء-ي]/;
const NUMBER = /[0-9٠-٩]+(?:[:.,/٫][0-9٠-٩]+)*/g;
const SEPARATORS = /( • | · |، |\n| - | — | \| |: )/;
const escape = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

export function setData(map, vocab) {
  cache.clear();
  inner.clear();
  MAP = map;
  VOCAB = Object.entries(vocab).sort((a, b) => b[0].length - a[0].length);
  PATTERNS = Object.entries(map)
    .filter(([k]) => k.includes('{}') && LETTERS.test(k.replaceAll('{}', '')))
    .map(([k, v]) => ({
      re: new RegExp(`^${k.split('{}').map(escape).join('(.+?)')}$`, 's'),
      en: v,
      // Enough words around the gaps to be sure a name may fill one.
      lenient: (k.replaceAll('{}', '').match(/[ء-ي]/g) || []).length >= 4,
      // Its fixed words: a string without all of them cannot match.
      words: k.split('{}').map((x) => x.trim()).filter(Boolean),
    }))
    .sort((a, b) => b.re.source.length - a.re.source.length);
  on = true;
}

export const latin = (s) => String(s).replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x660)).replace(/٫/g, '.').replace(/٬/g, ',');
const fill = (t, parts) => { let i = 0; return t.replace(/\{\}/g, () => (i < parts.length ? parts[i++] : '')); };
const inner = new Map(); // the gaps' translations (null: none)

export function tr(s) {
  if (!on || !s) return s;
  const hit = cache.get(s);
  if (hit !== undefined) return hit;
  if (cache.size > 6000) cache.clear();
  const r = translate(s, 0) ?? s;
  cache.set(s, r);
  return r;
}

function gap(g, depth) {
  if (inner.has(g)) return inner.get(g);
  if (inner.size > 6000) inner.clear();
  const r = translate(g, depth);
  inner.set(g, r);
  return r;
}

function translate(s, depth) {
  if (!LETTERS.test(s)) return latin(s);
  const t = s.trim();
  if (t.length !== s.length) { const r = translate(t, depth); return r == null ? null : s.replace(t, r); }
  if (Object.prototype.hasOwnProperty.call(MAP, t)) return MAP[t];
  const nums = [];
  const key = t.replace(NUMBER, (m) => { nums.push(latin(m)); return '{}'; });
  if (nums.length && Object.prototype.hasOwnProperty.call(MAP, key)) return fill(MAP[key], nums);
  // Patterns: short interface strings only, and one level of gaps inside gaps.
  if (depth < 2 && t.length <= 160) {
    for (const p of PATTERNS) {
      if (!p.words.every((w) => t.includes(w))) continue;
      const m = p.re.exec(t);
      if (!m) continue;
      const parts = [];
      let ok = true;
      for (let i = 1; i < m.length; i++) {
        // A gap never spans « • », «، »…: those pieces are translated one by one.
        if (SEPARATORS.test(m[i])) { ok = false; break; }
        const r = gap(m[i], depth + 1) ?? (p.lenient && m[i].split(' ').length <= 3 ? m[i] : null);
        if (r == null) { ok = false; break; }
        parts.push(r);
      }
      if (ok) return fill(p.en, parts);
    }
  }
  const pieces = depth < 2 && t.length <= 400 ? t.split(SEPARATORS) : [t];
  if (pieces.length > 1) {
    let out = '';
    for (let i = 0; i < pieces.length; i++) {
      const p = pieces[i];
      if (i % 2) { out += p === '، ' ? ', ' : p; continue; }
      const r = p === '' ? '' : gap(p, depth + 1);
      if (r == null) return words(t);
      out += r;
    }
    return out;
  }
  return words(t);
}

function words(t) {
  let v = ` ${t} `;
  for (const [a, e] of VOCAB) {
    if (!v.includes(a)) continue;
    v = v.replace(new RegExp(`(?<=[\\s,،(])${escape(a)}(?=[\\s,،)])`, 'g'), e);
  }
  v = v.replace(/،/g, ',').trim();
  return LETTERS.test(v) ? null : latin(v);
}

// ------------------------------------------------------------- the page ---
// Arabic content (the Mushaf, ayahs, athkar texts) is left as it is.
const SKIP = '.quran, .verse, .mpage, .mline, .thikr .txt, [data-ar], script, style, textarea, canvas';
const ATTRS = ['placeholder', 'aria-label', 'title'];

function node(n) {
  if (n.nodeType === 3) {
    const v = n.nodeValue;
    if (!v || !v.trim()) return;
    if (n.parentElement?.closest(SKIP)) return;
    const r = tr(v);
    if (r !== v) n.nodeValue = r;
    return;
  }
  if (n.nodeType !== 1) return;
  if (n.matches(SKIP)) return;
  for (const a of ATTRS) {
    const v = n.getAttribute(a);
    if (v && LETTERS.test(v)) { const r = tr(v); if (r !== v) n.setAttribute(a, r); }
  }
  if (n.tagName === 'INPUT' && (n.type === 'button' || n.type === 'submit') && LETTERS.test(n.value)) { const r = tr(n.value); if (r !== n.value) n.value = r; }
  for (let c = n.firstChild; c; c = c.nextSibling) node(c);
}

/// Loads the dictionary and translates the page from now on.
export async function startI18n() {
  if (language() !== 'en') return false;
  try {
    const j = await fetch('data/en.json').then((r) => r.json());
    setData(j.map, j.vocab);
  } catch { return false; }
  document.documentElement.lang = 'en';
  document.documentElement.dir = 'ltr';
  document.documentElement.classList.add('en');
  document.title = 'Al-Huda';
  node(document.body);
  new MutationObserver((list) => {
    for (const m of list) {
      if (m.type === 'characterData') node(m.target);
      else if (m.type === 'attributes') node(m.target);
      else for (const n of m.addedNodes) node(n);
    }
  }).observe(document.body, { subtree: true, childList: true, characterData: true, attributes: true, attributeFilter: ATTRS });
  return true;
}
