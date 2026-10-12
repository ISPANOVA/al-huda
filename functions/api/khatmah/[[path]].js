// الختمة الجماعية: a khatmah shared by link. Anyone may read any juz (more
// than one person can read the same one); a juz counts as done once someone
// finishes it, and when all 30 are done the next khatmah starts by itself on
// the same link. Cloudflare Pages Function over D1 (binding KHATMAH_DB).
// Each phone/browser sends its own random device key: it marks the parts it
// reads and the khatmahs it made, and is never sent back.
//
//   GET  /api/khatmah/:id?d=KEY          the khatmah
//   POST /api/khatmah                    {name, who, d}         -> new khatmah
//   POST /api/khatmah/:id/claim          {part, who, d}         I'll read this juz
//   POST /api/khatmah/:id/done           {part, d, done}        I finished it (or not yet)
//   POST /api/khatmah/:id/release        {part, d}              I won't read it after all
//   POST /api/khatmah/:id/restart        {d}  (its maker: start the round again)

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
    db.prepare(`CREATE TABLE IF NOT EXISTS readers (
      kid TEXT NOT NULL, round INTEGER NOT NULL, part INTEGER NOT NULL, device TEXT NOT NULL, who TEXT,
      done INTEGER NOT NULL DEFAULT 0, at INTEGER, PRIMARY KEY (kid, round, part, device))`),
    // The first version kept one reader a juz: carried over once, then emptied.
    db.prepare(`CREATE TABLE IF NOT EXISTS parts (
      kid TEXT NOT NULL, part INTEGER NOT NULL, who TEXT, device TEXT, done INTEGER NOT NULL DEFAULT 0, at INTEGER,
      PRIMARY KEY (kid, part))`),
    db.prepare(`INSERT OR IGNORE INTO readers (kid, round, part, device, who, done, at)
      SELECT p.kid, k.round, p.part, p.device, p.who, p.done, p.at FROM parts p JOIN khatmah k ON k.id = p.kid WHERE p.device IS NOT NULL`),
    db.prepare('DELETE FROM parts'),
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

async function state(db, id, device, extra = {}) {
  const k = await db.prepare('SELECT id, name, owner, owner_name, round, created FROM khatmah WHERE id = ?').bind(id).first();
  if (!k) return null;
  const { results } = await db.prepare('SELECT part, who, device, done, at FROM readers WHERE kid = ? AND round = ? ORDER BY at')
    .bind(id, k.round).all();
  const parts = Array.from({ length: PARTS }, (_, i) => ({ part: i + 1, who: null, readers: [], done: false, mine: false, mineDone: false }));
  for (const r of results) {
    const p = parts[r.part - 1];
    if (!p) continue;
    p.readers.push({ who: r.who, done: !!r.done });
    if (r.done) p.done = true;
    if (device && r.device === device) { p.mine = true; p.mineDone = !!r.done; }
  }
  for (const p of parts) {
    // The name shown on the tile: who finished it, else the first reader.
    p.who = (p.readers.find((r) => r.done) || p.readers[0])?.who ?? null;
  }
  const done = parts.filter((p) => p.done).length;
  return {
    id: k.id, name: k.name, ownerName: k.owner_name, round: k.round, completed: k.round - 1, created: k.created,
    isOwner: !!device && k.owner === device, parts, done, taken: parts.filter((p) => p.readers.length).length,
    readers: new Set(results.map((r) => r.device)).size, complete: false, ...extra,
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

  const k = await db.prepare('SELECT owner, round FROM khatmah WHERE id = ?').bind(id).first();
  if (!k) return fail('notfound', 404);
  const part = Number(b.part);
  const okPart = Number.isInteger(part) && part >= 1 && part <= PARTS;

  if (action === 'claim') {
    const who = clean(b.who, 30);
    if (!okPart || !who) return fail('part');
    await db.prepare('INSERT OR IGNORE INTO readers (kid, round, part, device, who, done, at) VALUES (?, ?, ?, ?, ?, 0, ?)')
      .bind(id, k.round, part, d, who, Date.now()).run();
    return json(await state(db, id, d));
  }
  if (action === 'done') {
    if (!okPart) return fail('part');
    const finished = b.done !== false;
    // Finishing a juz you hadn't taken yet takes it too.
    if (finished) {
      await db.prepare('INSERT OR IGNORE INTO readers (kid, round, part, device, who, done, at) VALUES (?, ?, ?, ?, ?, 0, ?)')
        .bind(id, k.round, part, d, clean(b.who, 30) || null, Date.now()).run();
    }
    await db.prepare('UPDATE readers SET done = ?, at = ? WHERE kid = ? AND round = ? AND part = ? AND device = ?')
      .bind(finished ? 1 : 0, Date.now(), id, k.round, part, d).run();
    // All 30 done: this khatmah is complete, the next one starts on the same link.
    const all = await db.prepare('SELECT COUNT(DISTINCT part) AS n FROM readers WHERE kid = ? AND round = ? AND done = 1')
      .bind(id, k.round).first();
    if (finished && all && all.n >= PARTS) {
      await db.prepare('UPDATE khatmah SET round = round + 1 WHERE id = ? AND round = ?').bind(id, k.round).run();
      return json(await state(db, id, d, { justCompleted: k.round }));
    }
    return json(await state(db, id, d));
  }
  if (action === 'release') {
    if (!okPart) return fail('part');
    await db.prepare('DELETE FROM readers WHERE kid = ? AND round = ? AND part = ? AND device = ?').bind(id, k.round, part, d).run();
    return json(await state(db, id, d));
  }
  if (action === 'restart') {
    if (k.owner !== d) return fail('owner', 403);
    await db.prepare('DELETE FROM readers WHERE kid = ? AND round = ?').bind(id, k.round).run();
    return json(await state(db, id, d));
  }
  return fail('action', 404);
}
