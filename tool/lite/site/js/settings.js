// الإعدادات وعن التطبيق.
import { $, ar, esc, icon, store, data, top, applyTheme, sheet, toast } from './app.js';
import { CREDITS } from './reciters.js';

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
    <div class="section">التلاوة</div>
    <div class="card list">
      <button id="rec">${icon('head', 'gold')}<span class="grow"><b>قارئ المصحف</b><br><small class="muted">${esc(cur.name)}</small></span>${icon('back', 'muted')}</button>
      <div style="flex-wrap:wrap">${icon('play', 'gold')}<span class="grow"><b>سرعة التلاوة</b></span><span class="chips" style="width:100%">${RATES.map((r) => `<button class="chip${r === rate ? ' on' : ''}" data-rate="${r}">${ar(r)}×</button>`).join('')}</span></div>
    </div>
    <div class="section">التطبيق</div>
    <div class="card list">
      <a href="#/about">${icon('info', 'gold')}<span class="grow"><b>عن الهدى</b></span>${icon('back', 'muted')}</a>
      <a href="#/about/privacy">${icon('eye', 'gold')}<span class="grow"><b>سياسة الخصوصية</b></span>${icon('back', 'muted')}</a>
      <a href="#/about/sources">${icon('book', 'gold')}<span class="grow"><b>المصادر والحقوق</b></span>${icon('back', 'muted')}</a>
      <button id="share">${icon('share', 'gold')}<span class="grow"><b>شارك الهدى</b><br><small class="muted">الدال على الخير كفاعله</small></span></button>
    </div>
    <p class="center muted small" style="margin-top:20px">الهدى • الإصدار 1.0.0</p>`;
  $('#theme', view).onclick = () => { store.set('theme', theme === 'light' ? 'dark' : 'light'); applyTheme(); show(view, args, name); };
  $('#rec', view).onclick = () => sheet(`<h3>قارئ المصحف</h3><div class="list">${reciters.map((r) => `<button data-id="${r.id}">${icon(r.id === rec.id ? 'check' : 'head', r.id === rec.id ? 'gold' : 'muted')}<span class="grow">${esc(r.name)}<br><small class="muted">${esc(r.style || '')}</small></span></button>`).join('')}</div>`,
    (body, close) => { body.onclick = (e) => { const b = e.target.closest('[data-id]'); if (!b) return; const r = reciters.find((x) => x.id === b.dataset.id); store.set('reciter', { id: r.id, bitrate: r.bitrate }); close(); show(view, args, name); }; });
  view.onclick = (e) => {
    const b = e.target.closest('[data-rate]');
    if (b) { store.set('rate', +b.dataset.rate); show(view, args, name); }
  };
  $('#share', view).onclick = () => {
    const t = 'الهدى: المصحف والتسميع ومواقيت الصلاة والأذكار، مجاني بلا إعلانات. ' + location.origin;
    if (navigator.share) navigator.share({ text: t }).catch(() => {}); else navigator.clipboard?.writeText(t).then(() => toast('نُسخ الرابط'));
  };
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
      block('lines', 'التفسير', 'التفسير الميسر (مجمع الملك فهد) عبر alquran.cloud.') +
      block('head', 'التلاوات', 'تلاوة الآيات من Islamic Network CDN، وتلاوات السور كاملة والإذاعات من موقع mp3quran.net.') +
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
