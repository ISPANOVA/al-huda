// الختمة الجماعية: a khatmah shared by link, its 30 parts claimed and finished
// by the people who open it. Cloudflare Pages Function over D1 (binding
// KHATMAH_DB). Each phone/browser sends its own random device key: it marks
// the parts it took and the khatmahs it made, and is never sent back.
//
//   GET  /api/khatmah/:id?d=KEY          the khatmah
//   POST /api/khatmah                    {name, who, d}         -> new khatmah
//   POST /api/khatmah/:id/claim          {part, who, d}
//   POST /api/khatmah/:id/done           {part, d, done}
//   POST /api/khatmah/:id/release        {part, d}
//   POST /api/khatmah/:id/restart        {d}  (its maker: a new round)

const PARTS = 30;
const HEADERS = {
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store',
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
  'access-control-allow-headers': 'content-type',
};
const json = (body, status = 200) => new Response(JSON.stringify(body), { status, headers: HEADERS });
const fail = (error, status = 400) => json({ error }, status);

let ready = null;
function schema(db) {
  ready ||= db.batch([
    db.prepare(`CREATE TABLE IF NOT EXISTS khatmah (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, owner TEXT NOT NULL, owner_name TEXT,
      round INTEGER NOT NULL DEFAULT 1, created INTEGER NOT NULL)`),
    db.prepare(`CREATE TABLE IF NOT EXISTS parts (
      kid TEXT NOT NULL, part INTEGER NOT NULL, who TEXT, device TEXT, done INTEGER NOT NULL DEFAULT 0, at INTEGER,
      PRIMARY KEY (kid, part))`),
  ]).catch((e) => { ready = null; throw e; });
  return ready;
}

const clean = (s, max) => String(s ?? '').replace(/[\u0000-\u001f<>]/g, '').trim().slice(0, max);
const validDevice = (d) => typeof d === 'string' && /^[A-Za-z0-9_-]{16,64}$/.test(d);
const ALPHABET = 'abcdefghjkmnpqrstuvwxyz23456789';
function newId() {
  const bytes = crypto.getRandomValues(new Uint8Array(9));
  return Array.from(bytes, (b) => ALPHABET[b % ALPHABET.length]).join('');
}

async function state(db, id, device) {
  const k = await db.prepare('SELECT id, name, owner, owner_name, round, created FROM khatmah WHERE id = ?').bind(id).first();
  if (!k) return null;
  const { results } = await db.prepare('SELECT part, who, device, done, at FROM parts WHERE kid = ? ORDER BY part').bind(id).all();
  const parts = Array.from({ length: PARTS }, (_, i) => ({ part: i + 1, who: null, done: false, mine: false }));
  for (const r of results) {
    const p = parts[r.part - 1];
    if (!p) continue;
    p.who = r.who; p.done = !!r.done; p.mine = !!device && r.device === device;
  }
  const done = parts.filter((p) => p.done).length;
  return {
    id: k.id, name: k.name, ownerName: k.owner_name, round: k.round, created: k.created,
    isOwner: !!device && k.owner === device, parts, done, taken: parts.filter((p) => p.who).length, complete: done === PARTS,
  };
}

async function body(request) {
  try { return await request.json(); } catch { return {}; }
}

export async function onRequest({ request, env, params }) {
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: HEADERS });
  const db = env.KHATMAH_DB;
  if (!db) return fail('disabled', 503);
  try {
    await schema(db);
  } catch {
    return fail('storage', 503);
  }
  const path = params.path || [];
  const id = clean(path[0], 16).toLowerCase();
  const action = path[1] || '';

  if (request.method === 'GET') {
    if (!id) return fail('missing');
    const s = await state(db, id, new URL(request.url).searchParams.get('d'));
    return s ? json(s) : fail('notfound', 404);
  }
  if (request.method !== 'POST') return fail('method', 405);
  const b = await body(request);
  const d = b.d;
  if (!validDevice(d)) return fail('device');

  if (!id) {
    // A new khatmah.
    const name = clean(b.name, 60) || 'ختمة جماعية';
    const who = clean(b.who, 30);
    let kid = newId();
    for (let i = 0; i < 3; i++) {
      const r = await db.prepare('INSERT OR IGNORE INTO khatmah (id, name, owner, owner_name, round, created) VALUES (?, ?, ?, ?, 1, ?)')
        .bind(kid, name, d, who || null, Date.now()).run();
      if (r.meta.changes === 1) return json(await state(db, kid, d), 201);
      kid = newId();
    }
    return fail('busy', 503);
  }

  const exists = await db.prepare('SELECT owner FROM khatmah WHERE id = ?').bind(id).first();
  if (!exists) return fail('notfound', 404);
  const part = Number(b.part);
  const okPart = Number.isInteger(part) && part >= 1 && part <= PARTS;

  if (action === 'claim') {
    const who = clean(b.who, 30);
    if (!okPart || !who) return fail('part');
    await db.prepare('INSERT OR IGNORE INTO parts (kid, part) VALUES (?, ?)').bind(id, part).run();
    const r = await db.prepare('UPDATE parts SET who = ?, device = ?, done = 0, at = ? WHERE kid = ? AND part = ? AND device IS NULL')
      .bind(who, d, Date.now(), id, part).run();
    if (r.meta.changes !== 1) return json({ ...(await state(db, id, d)), error: 'taken' }, 409);
    return json(await state(db, id, d));
  }
  if (action === 'done') {
    if (!okPart) return fail('part');
    const r = await db.prepare('UPDATE parts SET done = ?, at = ? WHERE kid = ? AND part = ? AND device = ?')
      .bind(b.done === false ? 0 : 1, Date.now(), id, part, d).run();
    if (r.meta.changes !== 1) return json({ ...(await state(db, id, d)), error: 'notyours' }, 403);
    return json(await state(db, id, d));
  }
  if (action === 'release') {
    if (!okPart) return fail('part');
    // The one who took it, or the khatmah's maker.
    const r = exists.owner === d
      ? await db.prepare('UPDATE parts SET who = NULL, device = NULL, done = 0, at = NULL WHERE kid = ? AND part = ?').bind(id, part).run()
      : await db.prepare('UPDATE parts SET who = NULL, device = NULL, done = 0, at = NULL WHERE kid = ? AND part = ? AND device = ?').bind(id, part, d).run();
    if (r.meta.changes !== 1) return json({ ...(await state(db, id, d)), error: 'notyours' }, 403);
    return json(await state(db, id, d));
  }
  if (action === 'restart') {
    if (exists.owner !== d) return fail('owner', 403);
    await db.batch([
      db.prepare('DELETE FROM parts WHERE kid = ?').bind(id),
      db.prepare('UPDATE khatmah SET round = round + 1 WHERE id = ?').bind(id),
    ]);
    return json(await state(db, id, d));
  }
  return fail('action', 404);
}
