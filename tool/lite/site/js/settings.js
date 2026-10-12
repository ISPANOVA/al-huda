// الإعدادات وعن التطبيق.
import { $, ar, esc, icon, store, data, top, applyTheme, sheet, toast } from './app.js';
import { CREDITS } from './reciters.js';
import { language, setLanguage } from './i18n.js';

const RATES = [0.75, 1, 1.25, 1.5];

export async function show(view, args, name) {
  if (name === 'about') return about(view, args[0]);
  const reciters = await data('reciters.json');
  const rec = store.get('reciter', { id: 'ar.alafasy', bitrate: 128 });
  const theme = store.get('theme', 'dark');
  const rate = store.get('rate', 1);
  const cur = reciters.find((r) => r.id === rec.id) || reciters[0];
  view.innerHTML = top('الإعدادات', 'القراءة والتلاوة والمظهر', 'slate', 'gear') + `
    <div class="section">المظهر</div>
    <div class="card list">
      <button id="theme">${icon(theme === 'light' ? 'sun' : 'moon', 'gold')}<span class="grow"><b>الوضع ${theme === 'light' ? 'الفاتح' : 'الداكن'}</b><br><small class="muted">اضغط للتبديل</small></span><span class="switch${theme === 'light' ? '' : ' on'}"></span></button>
    </div>
    <div class="section">لغة الواجهة</div>
    <div class="card"><div class="row" style="gap:10px"><button class="chip grow${language() === 'ar' ? ' on' : ''}" data-lang="ar" data-ar style="justify-content:center">العربية</button><button class="chip grow${language() === 'en' ? ' on' : ''}" data-lang="en" style="justify-content:center">English</button></div>
      <small class="muted" style="display:block;margin-top:8px">القرآن والأذكار تبقى بالعربية</small></div>
    <div class="section">التلاوة</div>
    <div class="card list">
      <button id="rec">${icon('head', 'gold')}<span class="grow"><b>قارئ المصحف</b><br><small class="muted">${esc(cur.name)}</small></span>${icon('back', 'muted')}</button>
      <div style="flex-wrap:wrap">${icon('play', 'gold')}<span class="grow"><b>سرعة التلاوة</b></span><span class="chips" style="width:100%">${RATES.map((r) => `<button class="chip${r === rate ? ' on' : ''}" data-rate="${r}">${ar(r)}×</button>`).join('')}</span></div>
    </div>
    <div class="section">بياناتي</div>
    <div class="card list">
      <button id="bk">${icon('download')}<span class="grow"><b>نسخة احتياطية</b><br><small class="muted">احفظ تقدمك في ملف، ويقرأه تطبيق الهدى أيضًا</small></span></button>
      <label style="display:flex;align-items:center;gap:12px;padding:12px 14px;cursor:pointer">${icon('repeat', 'gold')}<span class="grow"><b>استعادة نسخة</b><br><small class="muted">من ملف الموقع أو تطبيق الهدى</small></span><input type="file" accept="application/json,.json" id="rs" hidden></label>
    </div>
    ${window.installPrompt ? `<div class="section">التثبيت</div><div class="card list"><button id="inst">${icon('phone', 'gold')}<span class="grow"><b>ثبّت الهدى على جهازك</b><br><small class="muted">يفتح كتطبيق من الشاشة الرئيسية ويعمل دون إنترنت</small></span></button></div>` : ''}
    <div class="section">التطبيق</div>
    <div class="card list">
      <a href="#/about">${icon('info', 'gold')}<span class="grow"><b>عن الهدى</b></span>${icon('back', 'muted')}</a>
      <a href="#/about/privacy">${icon('eye', 'gold')}<span class="grow"><b>سياسة الخصوصية</b></span>${icon('back', 'muted')}</a>
      <a href="#/about/sources">${icon('book', 'gold')}<span class="grow"><b>المصادر والحقوق</b></span>${icon('back', 'muted')}</a>
      <button id="share">${icon('share', 'gold')}<span class="grow"><b>شارك الهدى</b><br><small class="muted">الدال على الخير كفاعله</small></span></button>
    </div>
    <p class="center muted small" style="margin-top:20px">الهدى، الإصدار 1.0.0</p>`;
  $('#theme', view).onclick = () => { store.set('theme', theme === 'light' ? 'dark' : 'light'); applyTheme(); show(view, args, name); };
  $('#rec', view).onclick = () => sheet(`<h3>قارئ المصحف</h3><div class="list">${reciters.map((r) => `<button data-id="${r.id}">${icon(r.id === rec.id ? 'check' : 'head', r.id === rec.id ? 'gold' : 'muted')}<span class="grow">${esc(r.name)}<br><small class="muted">${esc(r.style || '')}</small></span></button>`).join('')}</div>`,
    (body, close) => { body.onclick = (e) => { const b = e.target.closest('[data-id]'); if (!b) return; const r = reciters.find((x) => x.id === b.dataset.id); store.set('reciter', { id: r.id, bitrate: r.bitrate }); close(); show(view, args, name); }; });
  view.onclick = (e) => {
    const l = e.target.closest('[data-lang]');
    if (l) { if (l.dataset.lang !== language()) setLanguage(l.dataset.lang); return; }
    const b = e.target.closest('[data-rate]');
    if (b) { store.set('rate', +b.dataset.rate); show(view, args, name); }
  };
  $('#bk', view).onclick = () => backup();
  $('#rs', view).onchange = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    try { await restore(JSON.parse(await file.text())); toast('تمت الاستعادة'); setTimeout(() => location.reload(), 800); }
    catch { toast('هذا الملف ليس نسخة من الهدى'); }
  };
  $('#inst', view)?.addEventListener('click', async () => {
    window.installPrompt.prompt();
    await window.installPrompt.userChoice.catch(() => {});
    window.installPrompt = null;
    show(view, args, name);
  });
  $('#share', view).onclick = () => {
    const t = 'الهدى: المصحف والتسميع ومواقيت الصلاة والأذكار، مجاني بلا إعلانات. ' + 'https://al-huda.xyz';
    if (navigator.share) navigator.share({ text: t }).catch(() => {}); else navigator.clipboard?.writeText(t).then(() => toast('نُسخ الرابط'));
  };
}

// ---------------------------------------------------------------- backup ---
// One file for the site and the app: what both keep (prayers, Ramadan, zakat,
// the Forty Hadith read, the last page) in the app's own format, plus the
// site's other settings. The app merges it without clearing anything.
const SHARED = [
  ['plog', 'stats', 'prayer_log'], ['qada', 'stats', 'prayer_qada'], ['fasts', 'stats', 'ramadan_fasts'],
  ['taraweeh', 'stats', 'ramadan_taraweeh'], ['zakat', 'settings', 'zakat'], ['nawawiRead', 'settings', 'nawawi_read'],
  ['lastPage', 'bookmarks', 'last_page'],
];
function backup() {
  const boxes = {};
  for (const [k, box, key] of SHARED) {
    const v = store.get(k, null);
    if (v == null) continue;
    (boxes[box] ??= []).push({ k: key, i: false, v });
  }
  const web = {};
  for (let i = 0; i < localStorage.length; i++) {
    const k = localStorage.key(i);
    if (k?.startsWith('h_') && k !== 'h_resume') web[k.slice(2)] = store.get(k.slice(2));
  }
  const d = new Date();
  const name = `alhuda_backup_${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}.json`;
  const blob = new Blob([JSON.stringify({ app: 'al_huda', version: 1, partial: true, created: d.toISOString(), boxes, web }, null, 1)], { type: 'application/json' });
  const file = new File([blob], name, { type: 'application/json' });
  if (navigator.canShare?.({ files: [file] })) { navigator.share({ files: [file], text: 'نسخة احتياطية من الهدى' }).catch(() => {}); return; }
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob); a.download = name; a.click();
  toast('تم حفظ النسخة');
}
async function restore(d) {
  if (d?.app !== 'al_huda' || typeof d.boxes !== 'object') throw new Error('bad');
  if (d.web) for (const [k, v] of Object.entries(d.web)) store.set(k, v);
  for (const [k, box, key] of SHARED) {
    const e = (d.boxes[box] || []).find((x) => x.k === key);
    if (e) store.set(k, e.v);
  }
}


const block = (ic, t, b) => `<div class="card row" style="align-items:flex-start">${icon(ic, 'gold')}<span class="grow"><b>${t}</b><p class="muted small" style="margin:4px 0 0;line-height:1.8">${b}</p></span></div>`;

function about(view, which) {
  if (which === 'privacy') {
    view.innerHTML = top('سياسة الخصوصية', 'بياناتك تبقى على جهازك', 'sky', 'eye') +
      block('check', 'باختصار', 'الهدى لا يطلب حسابًا ولا يجمع أي بيانات شخصية، ولا يحتوي على إعلانات أو أدوات تتبّع. كل بياناتك تبقى على جهازك.') +
      block('compass', 'الموقع', 'يُستخدم موقعك لحساب مواقيت الصلاة واتجاه القبلة، والحساب نفسه يتم على جهازك. لمعرفة اسم مدينتك فقط تُرسل الإحداثيات التقريبية إلى خدمة BigDataCloud، ولا تُحفظ عندنا ولا تُربط بك.') +
      block('mic', 'الميكروفون (التسميع)', 'يُستخدم الميكروفون فقط أثناء التسميع وأنت تضغط زر التسجيل. في تطبيق أندرويد يتم التعرّف على الهاتف نفسه فلا يخرج صوتك منه. في نسخة الويب يتم التعرّف بخدمة المتصفح نفسه: في متصفح Chrome تقوم بها Google، وفي متصفح Safari تقوم بها Apple. لا نحفظ تسجيلات صوتك ولا نرسلها لأي جهة.') +
      block('download', 'الإنترنت', 'يتصل الموقع بالإنترنت لتحميل التلاوات وتشغيل الإذاعات والبث المباشر من مصادرها، دون إرسال أي معلومات عنك سوى ما يلزم تقنيًا.') +
      block('bookmark', 'بياناتك', 'العلامات والختمة والورد والإحصائيات والإعدادات محفوظة في متصفحك فقط، وتُحذف بمسح بيانات الموقع من المتصفح.');
    return;
  }
  if (which === 'sources') {
    view.innerHTML = top('المصادر والحقوق', 'مصدر كل محتوى', 'gold', 'book') +
      block('book', 'نص المصحف وخطه', 'خط حفص العثماني من مجمع الملك فهد لطباعة المصحف الشريف (KFGQPC)، وترتيب صفحات مصحف المدينة من مشروعي mushaf-layout و quran-data-kfgqpc مفتوحي المصدر.') +
      block('lines', 'التفسير', 'التفسير الميسر (مجمع الملك فهد) عبر alquran.cloud، والسعدي وابن كثير والوسيط والبغوي والقرطبي والطبري من مستودع tafsir_api المفتوح وواجهة Quran.com.') +
      block('lines', 'معاني الكلمات', 'من «التبيان في تفسير غريب القرآن» لابن الهائم و«تذكرة الأريب» لابن الجوزي، عبر الموسوعة القرآنية quranpedia.net.') +
      block('star', 'التجويد والمتشابهات', 'أحكام التجويد من بيانات Quran.com مطابقةً لخط المصحف، والمتشابهات اللفظية محسوبة من نص المصحف نفسه. مساعدة على التعلم، والعبرة بالتلقي من شيخ متقن.') +
      block('book', 'الأربعون النووية والأسماء الحسنى', 'نص الأربعين النووية من مجموعة hadith-api المفتوحة، والأسماء الحسنى في رواية الترمذي مع معانٍ مختصرة.') +
      block('head', 'التلاوات', 'تلاوة الآيات من Islamic Network CDN وEveryAyah، وتلاوات السور كاملة والإذاعات من موقع mp3quran.net، وتلاوة الشيخ علي جابر (تسجيل الاستوديو) من QuranicAudio.') +
      block('head', 'صور القراء', 'من ويكيميديا كومنز برخص حرة: ' + Object.values(CREDITS).map((c) => `<a href="${esc(c.source)}" target="_blank" rel="noopener" class="gold">${esc(c.name)}</a> (${esc(c.license)})`).join('، ') + '. باقي القراء يظهر لهم رسم بدل الصورة.') +
      block('tv', 'البث المباشر', 'قناتا القرآن الكريم والسنة النبوية من هيئة الإذاعة والتلفزيون السعودية عبر روابط البث العامة الرسمية.') +
      block('mic', 'التسميع', 'في نسخة الويب يتعرّف المتصفح على التلاوة، ويقارنها الهدى بالمصحف كلمةً كلمة. التصحيح الآلي قد يخطئ، ولا يغني عن القراءة على شيخ متقن.') +
      block('heart', 'الأذكار والأدعية', 'من كتاب حصن المسلم للشيخ سعيد بن علي بن وهف القحطاني رحمه الله، مع ذكر مصدر كل ذكر.') +
      block('clock', 'المواقيت والتقويم', 'حساب مواقيت الصلاة بمكتبة adhan المفتوحة، والتقويم الهجري بحساب أم القرى (قد يختلف يومًا عن الرؤية المحلية).');
    return;
  }
  view.innerHTML = top('عن الهدى', 'رفيقك اليومي مع القرآن', 'gold', 'info') + `
    <div class="card solid t-gold center" style="padding:24px 18px">
      <div style="font-family:Hafs,serif;font-size:44px">الهُدَىٰ</div>
      <b>صدقة جارية</b>
      <p style="margin:8px 0 0;line-height:1.9">عن روح والدي سمير حجازي، وعن سعد صالح، وعن جميع المسلمين الأحياء منهم والأموات</p>
      <small>اللهم اغفر لهم وارحمهم، واجعل كل حرف يُقرأ هنا في ميزان حسناتهم</small>
    </div>
    ${block('star', 'مجاني بالكامل', 'بلا إعلانات ولا اشتراكات ولا حسابات.')}
    ${block('phone', 'تطبيق أندرويد', 'نسخة أندرويد فيها التسميع يعمل على الهاتف نفسه بدقة عالية ودون إنترنت، مع الأذان والتنبيهات.')}
    <p class="center gold" style="letter-spacing:3px;font-weight:800;margin-top:20px">تطوير SMRH</p>
    <p class="center muted small">الإصدار 1.0.0</p>`;
}
