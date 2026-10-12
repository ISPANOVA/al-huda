// المزيد: every tool in one place.
import { icon, top } from './app.js';

const GROUPS = [
  ['أدوات يومية', [
    ['#/tasbeeh', 'المسبحة', 'عداد ذكي', 'beads', 'teal'],
    ['#/qibla', 'القبلة', 'بوصلة دقيقة', 'compass', 'amber'],
    ['#/khatmah', 'الختمة', 'ورد وخطة', 'flag', 'emerald'],
    ['#/group', 'الختمة الجماعية', 'اختموا معًا برابط', 'flag', 'teal'],
    ['#/hifz', 'الحفظ', 'نطاق وتكرار', 'repeat', 'amethyst'],
  ]],
  ['القرآن والذكر', [
    ['#/tasmee', 'التسميع', 'سمّع حفظك', 'mic', 'gold'],
    ['#/search', 'البحث في القرآن', 'بكلمة من الآية', 'search', 'sapphire'],
    ['#/virtues', 'الفضائل', 'فضل الذكر والقرآن', 'star', 'gold'],
    ['#/ruqyah', 'الرقية الشرعية', 'من القرآن والسنة', 'book', 'sky'],
    ['#/duas', 'الأدعية', 'للكرب والسفر والمرض', 'hands', 'rose'],
    ['#/asma', 'أسماء الله الحسنى', 'تسعة وتسعون اسمًا ومعانيها', 'star', 'gold'],
    ['#/nawawi', 'الأربعون النووية', 'جوامع الكلم من هدي النبي ﷺ', 'book', 'emerald'],
    ['#/similar', 'المتشابهات اللفظية', 'لتثبيت الحفظ', 'repeat', 'coral'],
    ['#/video', 'فيديو بصوت القارئ', 'آية أو سورة ستوري', 'tv', 'rose'],
  ]],
  ['العبادات', [
    ['#/prayerlog', 'متابعة الصلوات', 'صلواتك والقضاء ورمضان', 'check', 'sapphire'],
    ['#/zakat', 'حاسبة الزكاة', 'المال والذهب والفضة', 'chart', 'amber'],
  ]],
  ['المواقيت', [
    ['#/calendar', 'التقويم الهجري', 'المناسبات والصيام', 'cal', 'sky'],
    ['#/prayer/month', 'الإمساكية', 'مواقيت الشهر', 'moon', 'sapphire'],
  ]],
  ['حسابي', [
    ['#/stats', 'إحصائياتي', 'المداومة والإنجاز', 'chart', 'amber'],
    ['#/settings', 'الإعدادات', 'المظهر والتلاوة', 'gear', 'slate'],
    ['#/about', 'عن الهدى', 'صدقة جارية', 'info', 'gold'],
  ]],
];

export function show(view) {
  view.innerHTML = top('المزيد', 'كل أدواتك في مكان واحد', 'teal', 'grid', false) +
    GROUPS.map(([t, items]) => `<div class="section">${t}</div><div class="grid">${items.map(([h, n, s, ic, tone]) =>
      `<a class="card tile wash t-${tone}" href="${h}"><div class="ticon t-${tone}" style="width:44px;height:44px">${icon(ic)}</div><b>${n}</b><small>${s}</small></a>`).join('')}</div>`).join('') +
    `<a class="card solid t-gold center" href="#/about" style="display:block;margin-top:20px">
      <b>صدقة جارية</b><p style="margin:6px 0;line-height:1.8">عن روح والدي سمير حجازي، وعن سعد صالح، وعن جميع المسلمين الأحياء منهم والأموات</p>
      <small>تطوير SMRH، الإصدار 1.0.0</small></a>`;
}
