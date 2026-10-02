"""Network diagnostics run on GitHub Actions (the dev sandbox has no internet).
Checks Quran audio CDNs, radio and live streams; writes diag/*.json."""
import json, os, urllib.request, concurrent.futures as cf

os.makedirs('diag', exist_ok=True)
UA = {'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AlHuda/1.0'}

def probe(url, n=2048):
    try:
        req = urllib.request.Request(url, headers={**UA, 'Range': f'bytes=0-{n}'})
        with urllib.request.urlopen(req, timeout=15) as r:
            body = r.read(n)
            return {'ok': r.status in (200, 206), 'status': r.status,
                    'type': r.headers.get('Content-Type'), 'final': r.geturl(), 'head': body[:200].decode('latin1')}
    except Exception as e:
        return {'ok': False, 'err': str(e)[:200]}

def get_json(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())

out = {}
# 1) verse-by-verse editions on cdn.islamic.network
eds = get_json('https://api.alquran.cloud/v1/edition?format=audio&type=versebyverse')['data'] if os.path.exists('tool/diag/FULL') else []
eds = [e for e in eds if e['language'] == 'ar']
bitrates = [192, 128, 64, 48, 40, 32]
jobs = {}
with cf.ThreadPoolExecutor(32) as ex:
    for e in eds:
        for b in bitrates:
            for a in (1, 3000, 6236):
                jobs[(e['identifier'], b, a)] = ex.submit(probe, f'https://cdn.islamic.network/quran/audio/{b}/{e["identifier"]}/{a}.mp3', 64)
res = {}
for e in eds:
    ok = [b for b in bitrates if all(jobs[(e['identifier'], b, a)].result()['ok'] for a in (1, 3000, 6236))]
    res[e['identifier']] = {'name': e['name'], 'en': e['englishName'], 'bitrates': ok}
out['islamic_network'] = res

# 2) mp3quran full-surah reciters + radios
for name, url in [('mp3quran_reciters', 'https://mp3quran.net/api/v3/reciters?language=ar'),
                  ('mp3quran_radios', 'https://mp3quran.net/api/v3/radios?language=ar')]:
    try:
        json.dump(get_json(url), open(f'diag/{name}.json', 'w'), ensure_ascii=False)
    except Exception as e:
        out[name + '_err'] = str(e)

# 3) radio + live candidates
cands = json.load(open('tool/diag/streams.json'))
with cf.ThreadPoolExecutor(16) as ex:
    fut = {u: ex.submit(probe, u) for u in cands}
out['streams'] = {u: f.result() for u, f in fut.items()}

json.dump(out, open('diag/result.json', 'w'), ensure_ascii=False, indent=1)
print(json.dumps({k: v['bitrates'] for k, v in res.items()}, indent=1))
