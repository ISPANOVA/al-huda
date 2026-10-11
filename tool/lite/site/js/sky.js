// The living sky of the app's home page: the sun crossing the day, the moon
// at night, stars, and a mosque on the horizon (a port of SkyPainter).

const COLORS = {
  night: ['#03050F', '#0A1230', '#1D2347'],
  dawn: ['#141634', '#55376A', '#E08B6E'],
  morning: ['#15426B', '#4F8DB6', '#F1D7A0'],
  afternoon: ['#1F4A6B', '#7FA6BE', '#F4C27A'],
  sunset: ['#1E1638', '#7E3048', '#F09A4A'],
};
export const GREETING = { night: 'ليلة مباركة', dawn: 'فجر مبارك', morning: 'صباح الخير', afternoon: 'طاب يومك', sunset: 'مساء الخير' };

/// Where the sun or the moon is, from today's times [fajr, sunrise, dhuhr, asr, maghrib, isha].
export function skyState(now, t) {
  const day = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const h = (x) => new Date(day.getTime() + x * 3600e3);
  const [fajr, sunrise, dhuhr, , maghrib, isha] = t || [h(4.5), h(6), h(12), h(15.5), h(18), h(19.5)];
  const frac = (a, b) => Math.min(1, Math.max(0, (now - a) / Math.max(1, b - a)));
  if (now > sunrise && now < maghrib) {
    const phase = now < dhuhr ? 'morning' : (maghrib - now < 40 * 60e3 ? 'sunset' : 'afternoon');
    return { phase, t: frac(sunrise, maghrib), sun: true };
  }
  if (now > fajr && now <= sunrise) return { phase: 'dawn', t: 0.02, sun: true };
  if (now >= maghrib && now < isha) return { phase: 'sunset', t: 0.04, sun: false };
  const DAY = 864e5;
  const start = now < fajr ? new Date(isha - DAY) : isha;
  const end = now < fajr ? fajr : new Date(+fajr + DAY);
  return { phase: 'night', t: frac(start, end), sun: false };
}

export function drawSky(canvas, { phase, t, sun }, { orbitTop = 0.2, horizonAt = 0.68 } = {}) {
  const dpr = Math.min(2, devicePixelRatio || 1);
  const W = canvas.clientWidth, H = canvas.clientHeight;
  if (!W || !H) return;
  canvas.width = W * dpr; canvas.height = H * dpr;
  const c = canvas.getContext('2d');
  c.setTransform(dpr, 0, 0, dpr, 0, 0);
  const cols = COLORS[phase];
  const g = c.createLinearGradient(0, 0, 0, H);
  g.addColorStop(0, cols[0]); g.addColorStop(0.55, cols[1]); g.addColorStop(1, cols[2]);
  c.fillStyle = g; c.fillRect(0, 0, W, H);

  if (phase === 'night' || phase === 'dawn' || phase === 'sunset') {
    let seed = 3;
    const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
    const k = phase === 'night' ? 1 : 0.45;
    for (let i = 0; i < 70; i++) {
      const x = rnd() * W, y = rnd() * H * 0.7, r = 0.5 + rnd() * 1.3;
      c.fillStyle = `rgba(255,255,255,${(0.25 + rnd() * 0.6) * k})`;
      c.beginPath(); c.arc(x, y, r, 0, 7); c.fill();
    }
  }

  // The orbit, from the east (right) to the west (left).
  const horizon = H * horizonAt, cx = W / 2, rx = W * 0.42, ry = horizon - H * orbitTop;
  const at = (f) => [cx + rx * Math.cos(Math.PI * f), horizon - ry * Math.sin(Math.PI * f)];
  c.strokeStyle = 'rgba(255,255,255,.28)'; c.lineWidth = 1.2;
  for (let f = 0; f < 1; f += 0.02) { const a = at(f), b = at(f + 0.008); c.beginPath(); c.moveTo(...a); c.lineTo(...b); c.stroke(); }

  const [bx, by] = at(t);
  if (sun) {
    const rg = c.createRadialGradient(bx, by, 0, bx, by, 46);
    rg.addColorStop(0, 'rgba(255,232,163,.75)'); rg.addColorStop(1, 'rgba(255,232,163,0)');
    c.fillStyle = rg; c.beginPath(); c.arc(bx, by, 46, 0, 7); c.fill();
    c.fillStyle = '#FFF1C4'; c.beginPath(); c.arc(bx, by, 15, 0, 7); c.fill();
  } else {
    const rg = c.createRadialGradient(bx, by, 0, bx, by, 38);
    rg.addColorStop(0, 'rgba(255,255,255,.28)'); rg.addColorStop(1, 'rgba(255,255,255,0)');
    c.fillStyle = rg; c.beginPath(); c.arc(bx, by, 38, 0, 7); c.fill();
    // A crescent: the full disc minus a shifted one.
    c.save();
    c.beginPath(); c.arc(bx, by, 13, 0, 7); c.clip();
    c.fillStyle = '#F5EBC8'; c.fillRect(bx - 14, by - 14, 28, 28);
    c.globalCompositeOperation = 'destination-out';
    c.beginPath(); c.arc(bx + 6, by - 4, 11, 0, 7); c.fill();
    c.restore();
  }

  skyline(c, W, H, horizon, shade(cols[0]));
}

function shade(hex) {
  const n = parseInt(hex.slice(1), 16);
  const f = (v) => Math.round(v * 0.45);
  return `rgb(${f(n >> 16)},${f((n >> 8) & 255)},${f(n & 255)})`;
}

function skyline(c, w, h, horizon, color) {
  c.fillStyle = color; c.strokeStyle = color;
  c.fillRect(0, horizon, w, h - horizon);
  c.beginPath(); c.moveTo(0, horizon);
  c.quadraticCurveTo(w * 0.15, horizon - 10, w * 0.3, horizon - 2);
  c.quadraticCurveTo(w * 0.5, horizon + 6, w * 0.7, horizon - 4);
  c.quadraticCurveTo(w * 0.85, horizon - 12, w, horizon - 3);
  c.lineTo(w, horizon + 2); c.lineTo(0, horizon + 2); c.closePath(); c.fill();
  const minaret = (x, hh, bw) => {
    const top = horizon - hh;
    c.beginPath();
    if (c.roundRect) c.roundRect(x - bw / 2, top, bw, hh, [bw / 2, bw / 2, 0, 0]); else c.rect(x - bw / 2, top, bw, hh);
    c.fill();
    c.fillRect(x - bw, top + hh * 0.3, bw * 2, hh * 0.04);
    c.beginPath(); c.arc(x, top - bw * 0.9, bw * 0.32, 0, 7); c.fill();
  };
  const dome = (x, r) => {
    c.beginPath(); c.arc(x, horizon, r, Math.PI, 0); c.fill();
    c.beginPath(); c.arc(x, horizon - r * 1.2, r * 0.12, 0, 7); c.fill();
  };
  // The mosque keeps a phone's size on wide screens.
  const m = Math.min(w, 460);
  const base = w * 0.2;
  c.fillRect(base, horizon - 22, m * 0.3, 22);
  dome(base + m * 0.15, m * 0.085); dome(base + m * 0.05, m * 0.035); dome(base + m * 0.25, m * 0.035);
  minaret(base - 6, 78, 9); minaret(base + m * 0.3 + 6, 64, 8);
  const px = w * 0.86;
  c.lineCap = 'round'; c.lineWidth = 4;
  c.beginPath(); c.moveTo(px, horizon); c.lineTo(px - 6, horizon - 46); c.stroke();
  c.lineWidth = 3;
  for (let i = 0; i < 6; i++) {
    const a = -Math.PI / 2 + (i - 2.5) * 0.55;
    c.beginPath(); c.moveTo(px - 6, horizon - 46); c.lineTo(px - 6 + 26 * Math.cos(a), horizon - 46 + 18 * Math.sin(a) + 10); c.stroke();
  }
}
