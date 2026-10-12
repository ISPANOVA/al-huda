// Prayer times for the saved location (the app's own calculation, from Dart).
import { core, store, ar } from './app.js';

export const NAMES = ['الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
export const METHODS = {
  egyptian: 'الهيئة المصرية العامة للمساحة', umm_al_qura: 'أم القرى (مكة)', muslim_world_league: 'رابطة العالم الإسلامي',
  karachi: 'جامعة العلوم الإسلامية (كراتشي)', dubai: 'دبي', kuwait: 'الكويت', qatar: 'قطر', singapore: 'سنغافورة',
  turkey: 'تركيا', tehran: 'طهران', north_america: 'أمريكا الشمالية', moon_sighting_committee: 'لجنة رؤية الهلال',
};

export const location = () => store.get('loc', null);

/// Asks the browser for the location; the city name from BigDataCloud.
export function locate() {
  return new Promise((ok, fail) => {
    if (!navigator.geolocation) return fail(new Error('geo'));
    navigator.geolocation.getCurrentPosition(async (p) => {
      const loc = { lat: p.coords.latitude, lng: p.coords.longitude, city: '' };
      try {
        const r = await fetch(`https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${loc.lat}&longitude=${loc.lng}&localityLanguage=ar`);
        const j = await r.json();
        loc.city = j.city || j.locality || j.principalSubdivision || '';
      } catch {}
      store.set('loc', loc);
      ok(loc);
    }, fail, { enableHighAccuracy: false, timeout: 15000, maximumAge: 3600e3 });
  });
}

export async function timesFor(date, loc = location()) {
  if (!loc) return null;
  const api = await core();
  const ms = api.prayerTimes(loc.lat, loc.lng, date.getFullYear(), date.getMonth() + 1, date.getDate(),
    store.get('method', 'egyptian'), store.get('madhab', 'shafi'));
  const adj = store.get('adj', [0, 0, 0, 0, 0, 0]);
  return Array.from(ms, (t, i) => new Date(t + adj[i] * 60000));
}

/// Next prayer (or sunrise) after now: [index, time].
export async function nextPrayer() {
  const now = new Date();
  const t = await timesFor(now);
  if (!t) return null;
  for (let i = 0; i < 6; i++) if (t[i] > now) return [i, t[i], t];
  const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
  const t2 = await timesFor(tomorrow);
  return [0, t2[0], t];
}

export const hm = (d) => ar(d.toLocaleTimeString('ar-EG-u-nu-latn', { hour: 'numeric', minute: '2-digit' }));

export function countdown(to) {
  let s = Math.max(0, Math.round((to - new Date()) / 1000));
  const h = Math.floor(s / 3600); s -= h * 3600;
  const m = Math.floor(s / 60); s -= m * 60;
  return ar(`${h > 0 ? h + ':' : ''}${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`);
}

export async function hijriToday() {
  const api = await core();
  const d = new Date();
  const [y, m, dd] = api.hijri(d.getFullYear(), d.getMonth() + 1, d.getDate());
  return { y, m, d: dd };
}
export const HMONTHS = ['محرّم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة', 'رجب', 'شعبان', 'رمضان', 'شوّال', 'ذو القعدة', 'ذو الحجة'];

/// This Ramadan (or the next): its hijri year and its days (Gregorian dates).
export async function ramadanDays() {
  const api = await core();
  const now = new Date();
  const base = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const at = (i) => new Date(base.getFullYear(), base.getMonth(), base.getDate() + i);
  const h = (d) => api.hijri(d.getFullYear(), d.getMonth() + 1, d.getDate());
  let start = -1;
  const [, m0, d0] = h(base);
  if (m0 === 9) start = 1 - d0;
  else for (let i = 1; i < 400; i++) { const [, m, d] = h(at(i)); if (m === 9 && d === 1) { start = i; break; } }
  if (start === -1 && m0 !== 9) return null;
  const days = [];
  for (let i = start; days.length < 30; i++) { const [, m] = h(at(i)); if (m !== 9) break; days.push(at(i)); }
  return { year: h(days[0])[0], days };
}
