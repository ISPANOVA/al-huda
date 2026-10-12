"""Finds a freely licensed photo of each reciter on Wikidata / Wikimedia
Commons and saves a small square portrait for the app and the website.

  python3 tool/reciters/fetch_photos.py <out dir>

Only Commons files are used (free licences); the author and licence of each
are written to <out>/credits.json and shown on the app's sources page.
"""
import io
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

from PIL import Image, ImageOps

OUT = sys.argv[1]
UA = {"User-Agent": "AlHudaApp/1.0 (https://github.com/ISPANOVA/al-huda; reciter portraits)"}

# key -> (Arabic name, English name for a second search)
PEOPLE = {
    "basit": ("عبد الباسط عبد الصمد", "Abdul Basit Abdus Samad"),
    "minsh": ("محمد صديق المنشاوي", "Mohamed Siddiq El-Minshawi"),
    "husr": ("محمود خليل الحصري", "Mahmoud Khalil Al-Hussary"),
    "mustafa": ("مصطفى إسماعيل", "Mustafa Ismail"),
    "bna": ("محمود علي البنا", "Mahmoud Ali Al-Banna"),
    "tblawi": ("محمد محمود الطبلاوي", "Mohamed Mahmoud Al-Tablawi"),
    "nuaina": ("أحمد نعينع", "Ahmed Naina"),
    "shahhat": ("عبد الرحمن الشحات", "Abdulrahman Al-Shahat"),
    "afs": ("مشاري راشد العفاسي", "Mishary Rashid Alafasy"),
    "yasser": ("ياسر الدوسري", "Yasser Al-Dosari"),
    "maher": ("ماهر المعيقلي", "Maher Al-Muaiqly"),
    "sds": ("عبد الرحمن السديس", "Abdul Rahman Al-Sudais"),
    "shur": ("سعود الشريم", "Saud Al-Shuraim"),
    "qtm": ("ناصر القطامي", "Nasser Al-Qatami"),
    "ajm": ("أحمد بن علي العجمي", "Ahmed Al-Ajmi"),
    "shatri": ("أبو بكر الشاطري", "Abu Bakr al-Shatri"),
    "hthfi": ("علي الحذيفي", "Ali Al-Hudhaifi"),
    "ayyub": ("محمد أيوب", "Muhammad Ayyub"),
    "bsfr": ("عبد الله بصفر", "Abdullah Basfar"),
    "hani": ("هاني الرفاعي", "Hani ar-Rifai"),
    "jbrl": ("محمد جبريل", "Muhammad Jibreel"),
    "abkr": ("إدريس أبكر", "Idris Abkar"),
    "frs": ("فارس عباد", "Fares Abbad"),
    "gmd": ("سعد الغامدي", "Saad Al-Ghamdi"),
    "jleel": ("خالد الجليل", "Khalid Al-Jalil"),
    "lhdan": ("محمد اللحيدان", "Muhammad Al-Luhaidan"),
    "klb": ("عادل الكلباني", "Adel Al-Kalbani"),
    "jhn": ("عبد الله الجهني", "Abdullah Al-Juhani"),
    "kyat": ("عبد الله خياط", "Abdullah Khayat"),
    "bud": ("صلاح البدير", "Salah Al-Budair"),
    "qasm": ("عبد المحسن القاسم", "Abdul Muhsin Al-Qasim"),
    "akdr": ("إبراهيم الأخضر", "Ibrahim Al-Akhdar"),
    "bader": ("بدر التركي", "Bader Al-Turki"),
    "tnjy": ("خليفة الطنيجي", "Khalifa Al-Tunaiji"),
    "mansor": ("منصور السالمي", "Mansour Al-Salimi"),
    "aloosi": ("عبد الرحمن العوسي", "Abdulrahman Al-Ossi"),
    "nabil": ("نبيل الرفاعي", "Nabil ar-Rifai"),
    "ajbr": ("علي جابر", "Ali Jaber"),
    "mtrod": ("عبد الله المطرود", "Abdullah Al-Matroud"),
    "dosri": ("إبراهيم الدوسري", "Ibrahim Al-Dosari"),
    "mrifai": ("محمود الرفاعي", "Mahmoud ar-Rifai"),
    "alzain": ("الزين محمد أحمد", "Alzain Mohammed Ahmed"),
}
# Photos picked by eye from the wider Commons search (search_more.py): used
# instead of what Wikidata gives, either because Wikidata has none or because
# this one is clearer. Each file's page names the reciter.
FILES = {
    "ajm": "Ahmad bin Ali Al-Ajmi.png",
    "bud": "Salah Ibn Mohammed Al Budair.jpg",
    "mansor": "Mansurahsalme.jpg",
    "alzain": "الزين محمد أحمد.png",
    "mustafa": "Mustafa Ismail (1).jpg",
    "hthfi": "Ali al-Hudhayfi.jpg",
}
WORDS = re.compile(r"قارئ|مقرئ|قرآن|القرآن|إمام|reciter|qari|quran|qur'an|imam", re.I)


def get(url):
    for i in range(4):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30) as r:
                return r.read()
        except Exception as e:  # rate limits: wait and retry
            print("retry", url[:90], e)
            time.sleep(3 * (i + 1))
    raise RuntimeError(url)


def api(base, **params):
    return json.loads(get(base + "?" + urllib.parse.urlencode({**params, "format": "json"})))


def candidates(name, lang):
    r = api("https://www.wikidata.org/w/api.php", action="wbsearchentities", search=name, language=lang, uselang=lang, limit=8, type="item")
    return r.get("search", [])


def image_of(qid):
    r = api("https://www.wikidata.org/w/api.php", action="wbgetentities", ids=qid, props="claims|labels|descriptions|sitelinks", languages="ar|en")
    e = r["entities"][qid]
    claims = e.get("claims", {})
    human = any(c["mainsnak"].get("datavalue", {}).get("value", {}).get("id") == "Q5" for c in claims.get("P31", []))
    p18 = claims.get("P18", [])
    file = p18[0]["mainsnak"]["datavalue"]["value"] if p18 else None
    if human and not file:
        # The freely licensed lead image of its Wikipedia article.
        for wiki, host in (("arwiki", "ar"), ("enwiki", "en")):
            title = e.get("sitelinks", {}).get(wiki, {}).get("title")
            if not title:
                continue
            pi = api(f"https://{host}.wikipedia.org/w/api.php", action="query", titles=title, prop="pageimages", piprop="name", pilicense="free")
            pg = next(iter(pi["query"]["pages"].values()))
            if pg.get("pageimage"):
                file = pg["pageimage"]
                break
    desc = " / ".join(e.get("descriptions", {}).get(l, {}).get("value", "") for l in ("ar", "en"))
    label = e.get("labels", {}).get("ar", e.get("labels", {}).get("en", {})).get("value", "")
    return human, file, desc, label


# Photos the detector gets wrong, checked by eye: "top" = the top-centre
# square; (cx, cy, side) = a square inside it, as fractions of its side.
CROPS = {"ajbr": "top", "hthfi": "top", "mansor": (0.58, 0.57, 0.62)}


def portrait(img, key=""):
    """A square around the face (OpenCV's face detector), else the top centre."""
    w, h = img.size
    fix = CROPS.get(key)
    if fix:
        s = min(w, h)
        img = img.crop(((w - s) // 2, 0, (w - s) // 2 + s, s))
        if fix == "top":
            return img
        cx, cy, side = fix
        a = int(side * s)
        left = int(min(max(cx * s - a / 2, 0), s - a))
        top = int(min(max(cy * s - a / 2, 0), s - a))
        return img.crop((left, top, left + a, top + a))
    try:
        import cv2
        import numpy as np
        gray = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2GRAY)
        det = cv2.CascadeClassifier(cv2.data.haarcascades + "haarcascade_frontalface_default.xml")
        faces, weights = [], []
        for n in (6, 3):  # strict first; looser for small faces in wide shots
            found, _, w8 = det.detectMultiScale3(gray, scaleFactor=1.08, minNeighbors=n, minSize=(max(20, w // 40), max(20, w // 40)),
                                                 outputRejectLevels=True)
            if len(found):
                faces, weights = list(found), [float(x) for x in np.array(w8).ravel()]
                break
    except Exception as e:
        try:
            import cv2 as c2
            print("no face detection", e, getattr(c2, "__file__", None), getattr(c2, "__path__", None), getattr(c2, "__version__", None))
        except Exception as e2:
            print("no face detection", e, e2)
        faces = []
    if len(faces):
        # The most certain face (not the largest: curtains and patterns fool it).
        x, y, fw, fh = faces[max(range(len(faces)), key=lambda i: weights[i])]
        # Head and shoulders: the face in the upper third, the chest to the bottom edge.
        side = int(max(fw, fh) * 3.4)
        side = min(side, w, h)
        cx, cy = x + fw / 2, y + fh / 2 + fh * 0.95
        left = int(min(max(cx - side / 2, 0), w - side))
        top = int(min(max(cy - side / 2, 0), h - side))
        return img.crop((left, top, left + side, top + side))
    s = min(w, h)
    return img.crop(((w - s) // 2, 0, (w - s) // 2 + s, s))


def main():
    os.makedirs(OUT, exist_ok=True)
    credits, report = {}, []
    for key, (ar, en) in PEOPLE.items():
        found = (None, FILES[key], "picked by eye", ar) if key in FILES else None
        seen = set()
        for name, lang in ((ar, "ar"), (en, "en")) if not found else ():
            for c in candidates(name, lang):
                qid = c["id"]
                if qid in seen:
                    continue
                seen.add(qid)
                human, file, desc, label = image_of(qid)
                if human and file and WORDS.search(desc + " " + c.get("description", "")):
                    found = (qid, file, desc, label)
                    break
            if found:
                break
        if not found:
            report.append({"key": key, "name": ar, "found": False})
            print("no photo", key, ar)
            continue
        qid, file, desc, label = found
        info = api("https://commons.wikimedia.org/w/api.php", action="query", titles="File:" + file, prop="imageinfo",
                   iiprop="url|extmetadata", iiurlwidth=1600)
        page = next(iter(info["query"]["pages"].values()))
        if "imageinfo" not in page:  # not on Commons (a local, non-free file)
            report.append({"key": key, "name": ar, "found": False, "why": "not on Commons " + file})
            continue
        ii = page["imageinfo"][0]
        meta = ii.get("extmetadata", {})
        lic = meta.get("LicenseShortName", {}).get("value", "")
        artist = re.sub("<[^>]+>", "", meta.get("Artist", {}).get("value", "")).strip()
        img = Image.open(io.BytesIO(get(ii["thumburl"]))).convert("RGB")
        img = portrait(img, key)
        os.makedirs(os.path.join(OUT, "raw"), exist_ok=True)
        side = min(img.size[0], 768)
        img.resize((side, side), Image.LANCZOS).save(os.path.join(OUT, "raw", f"{key}.png"))
        credits[key] = {"name": ar, "file": file, "license": lic, "author": artist,
                        "source": "https://commons.wikimedia.org/wiki/File:" + urllib.parse.quote(file.replace(" ", "_"))}
        report.append({"key": key, "name": ar, "found": True, "qid": qid, "label": label, "desc": desc, "file": file, "license": lic, "author": artist})
        print("ok", key, qid, label, "|", desc, "|", file, lic)
        time.sleep(0.5)
    json.dump(credits, open(os.path.join(OUT, "credits.json"), "w"), ensure_ascii=False, indent=1)
    json.dump(report, open(os.path.join(OUT, "report.json"), "w"), ensure_ascii=False, indent=1)


main()
