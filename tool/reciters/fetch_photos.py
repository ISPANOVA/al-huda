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
    r = api("https://www.wikidata.org/w/api.php", action="wbgetentities", ids=qid, props="claims|labels|descriptions", languages="ar|en")
    e = r["entities"][qid]
    claims = e.get("claims", {})
    human = any(c["mainsnak"].get("datavalue", {}).get("value", {}).get("id") == "Q5" for c in claims.get("P31", []))
    p18 = claims.get("P18", [])
    file = p18[0]["mainsnak"]["datavalue"]["value"] if p18 else None
    desc = " / ".join(e.get("descriptions", {}).get(l, {}).get("value", "") for l in ("ar", "en"))
    label = e.get("labels", {}).get("ar", e.get("labels", {}).get("en", {})).get("value", "")
    return human, file, desc, label


def main():
    os.makedirs(OUT, exist_ok=True)
    credits, report = {}, []
    for key, (ar, en) in PEOPLE.items():
        found = None
        seen = set()
        for name, lang in ((ar, "ar"), (en, "en")):
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
                   iiprop="url|extmetadata", iiurlwidth=400)
        page = next(iter(info["query"]["pages"].values()))
        ii = page["imageinfo"][0]
        meta = ii.get("extmetadata", {})
        lic = meta.get("LicenseShortName", {}).get("value", "")
        artist = re.sub("<[^>]+>", "", meta.get("Artist", {}).get("value", "")).strip()
        img = Image.open(io.BytesIO(get(ii["thumburl"]))).convert("RGB")
        # A square portrait from the upper part of the photo (the face).
        w, h = img.size
        s = min(w, h)
        top = 0 if h > w else 0
        img = img.crop(((w - s) // 2, top, (w - s) // 2 + s, top + s))
        img = img.resize((256, 256), Image.LANCZOS)
        img.save(os.path.join(OUT, f"{key}.jpg"), "JPEG", quality=82, optimize=True)
        credits[key] = {"name": ar, "file": file, "license": lic, "author": artist,
                        "source": "https://commons.wikimedia.org/wiki/File:" + urllib.parse.quote(file.replace(" ", "_"))}
        report.append({"key": key, "name": ar, "found": True, "qid": qid, "label": label, "desc": desc, "file": file, "license": lic, "author": artist})
        print("ok", key, qid, label, "|", desc, "|", file, lic)
        time.sleep(0.5)
    json.dump(credits, open(os.path.join(OUT, "credits.json"), "w"), ensure_ascii=False, indent=1)
    json.dump(report, open(os.path.join(OUT, "report.json"), "w"), ensure_ascii=False, indent=1)


main()
