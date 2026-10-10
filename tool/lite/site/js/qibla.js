// القبلة: the bearing to the Kaaba from the saved location, and a compass
// from the phone's orientation sensor where the browser gives it.
import { $, ar, icon, top, toast } from './app.js';
import { location, locate } from './prayerlib.js';

const KAABA = [21.422487, 39.826206];
let handler;

export function bearing(lat, lng) {
  const r = Math.PI / 180;
  const [kl, kg] = [KAABA[0] * r, KAABA[1] * r];
  const [a, g] = [lat * r, lng * r];
  const y = Math.sin(kg - g);
  const x = Math.cos(a) * Math.tan(kl) - Math.sin(a) * Math.cos(kg - g);
  return (Math.atan2(y, x) / r + 360) % 360;
}

function distance(lat, lng) {
  const r = Math.PI / 180, R = 6371;
  const dLat = (KAABA[0] - lat) * r, dLng = (KAABA[1] - lng) * r;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat * r) * Math.cos(KAABA[0] * r) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

export async function show(view) {
  const loc = location();
  view.innerHTML = top('القبلة', 'اتجاه الكعبة المشرفة', 'amber', 'compass') + '<div id="body"></div>';
  const body = $('#body', view);
  if (!loc) {
    body.innerHTML = `<div class="card center" style="padding:28px 18px"><b>نحتاج موقعك لتحديد القبلة</b><br><br><button class="btn" id="loc">تحديد موقعي</button></div>`;
    $('#loc', body).onclick = async () => { try { await locate(); show(view); } catch { toast('تعذر تحديد الموقع'); } };
    return;
  }
  const q = bearing(loc.lat, loc.lng);
  body.innerHTML = `
    <div class="compass" id="cmp">
      <div class="dial" id="dial"><span class="n">N</span>
        <div class="needle" style="transform:rotate(${q}deg)"><span class="kaaba">🕋</span></div>
      </div>
    </div>
    <div class="card center">
      <div style="font-size:30px;font-weight:900" class="gold">${ar(Math.round(q))}°</div>
      <p class="muted small" id="st" style="margin:4px 0 0">من الشمال باتجاه عقارب الساعة</p>
      <p class="small" style="margin:6px 0 0">المسافة إلى مكة: ${ar(Math.round(distance(loc.lat, loc.lng)).toLocaleString('en'))} كم</p>
    </div>
    <button class="btn block" id="start" style="margin-top:12px">${icon('compass')} تشغيل البوصلة</button>
    <p class="muted small center">ضع الهاتف أفقيًا وبعيدًا عن المعادن. إن لم تتحرك البوصلة فاستخدم الدرجة الظاهرة مع بوصلة الهاتف.</p>`;
  const dial = $('#dial', body);
  const onHeading = (h) => {
    dial.style.transform = `rotate(${-h}deg)`;
    const diff = Math.abs(((q - h + 540) % 360) - 180);
    $('#st', body).textContent = diff < 4 ? 'أنت في اتجاه القبلة ✓' : `أدر الهاتف ${ar(Math.round(diff))}°`;
    $('#cmp', body).style.borderColor = diff < 4 ? 'var(--emerald-t)' : '';
  };
  const start = async () => {
    try {
      if (typeof DeviceOrientationEvent !== 'undefined' && DeviceOrientationEvent.requestPermission) {
        if ((await DeviceOrientationEvent.requestPermission()) !== 'granted') throw new Error('denied');
      }
    } catch { toast('لم يُسمح باستخدام البوصلة'); return; }
    stop();
    handler = (e) => {
      let h = e.webkitCompassHeading;
      if (h == null && e.absolute && e.alpha != null) h = 360 - e.alpha;
      if (h == null) return;
      onHeading(h);
    };
    addEventListener('deviceorientationabsolute', handler);
    addEventListener('deviceorientation', handler);
    $('#start', body).hidden = true;
  };
  $('#start', body).onclick = start;
  if (typeof DeviceOrientationEvent !== 'undefined' && !DeviceOrientationEvent.requestPermission) start();
}

function stop() {
  if (!handler) return;
  removeEventListener('deviceorientationabsolute', handler);
  removeEventListener('deviceorientation', handler);
  handler = null;
}
export function leave() { stop(); }
