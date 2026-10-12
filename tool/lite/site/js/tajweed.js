// Tajweed colours for the Mushaf: the same data and colours as the app
// (data/tajweed.txt: per page, per word, runs 'start.end.rule').
import { store } from './app.js';

export const RULES = [
  ['همزة الوصل', 'تُكتب ولا تُنطق عند الوصل'], ['حرف لا يُنطق', 'حروف تُكتب ولا تُقرأ'], ['اللام الشمسية', 'لام تُدغم فيما بعدها'],
  ['مد طبيعي', 'حركتان'], ['مد جائز منفصل', '٢ أو ٤ أو ٥ حركات'], ['مد لازم', '٦ حركات'], ['مد واجب متصل', '٤ أو ٥ حركات'],
  ['قلقلة', 'اضطراب الصوت عند السكون'], ['إخفاء شفوي', 'ميم ساكنة قبل الباء'], ['إخفاء', 'نون ساكنة أو تنوين بغنة'],
  ['إدغام شفوي', 'ميم ساكنة في ميم'], ['إقلاب', 'النون ميمًا قبل الباء'], ['إدغام بغنة', 'في حروف (ينمو)'],
  ['إدغام بلا غنة', 'في اللام والراء'], ['إدغام متجانسين', 'حرفان اتحدا مخرجًا'], ['إدغام متقاربين', 'حرفان تقاربا مخرجًا'],
  ['غنة', 'النون والميم المشددتان'],
];

let pages = null, loading = null;
export const on = () => store.get('tajweed', false);
export const ready = () => !!pages;
export function load() {
  return (loading ??= fetch('data/tajweed.txt').then((r) => r.text()).then((t) => {
    pages = t.split('\n').map((line) => line.split('|').map((w) => (w ? w.split(',').map((r) => r.split('.').map(Number)) : [])));
  }).catch(() => { loading = null; }));
}

/// The word's HTML with its tajweed runs coloured.
export function colour(page, k, html, esc) {
  const runs = pages?.[page - 1]?.[k];
  if (!runs?.length) return html(esc);
  return html((body) => {
    let out = '', at = 0;
    for (const [s, e, r] of runs) {
      if (s < at || e > body.length || s >= e) continue;
      out += esc(body.slice(at, s)) + `<i class="tj${r}">${esc(body.slice(s, e))}</i>`;
      at = e;
    }
    return out + esc(body.slice(at));
  });
}
