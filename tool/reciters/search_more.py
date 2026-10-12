"""Looks wider on Wikimedia Commons for freely licensed photos of the
reciters (file search by name in Arabic and English), and saves every
candidate with its title and licence for a person to choose from.

  python3 tool/reciters/search_more.py <out dir>
"""
import io
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

from PIL import Image, ImageDraw

OUT = sys.argv[1]
UA = {"User-Agent": "AlHudaApp/1.0 (https://github.com/ISPANOVA/al-huda; reciter portraits)"}
WANT = {
    "basit": ["عبد الباسط عبد الصمد", "Abdul Basit Abdus Samad", "Abdelbasset Abdessamad"],
    "bna": ["محمود علي البنا", "Mahmoud Ali Al-Banna"],
    "tblawi": ["محمد محمود الطبلاوي", "Mohamed Mahmoud Al-Tablawi", "Tablawi"],
    "shahhat": ["عبد الرحمن الشحات", "Abdelrahman El Shahat"],
    "ajm": ["أحمد العجمي", "Ahmed Al Ajmi"],
    "shatri": ["أبو بكر الشاطري", "Abu Bakr al-Shatri"],
    "ayyub": ["محمد أيوب", "Muhammad Ayyub reciter"],
    "bsfr": ["عبد الله بصفر", "Abdullah Basfar"],
    "hani": ["هاني الرفاعي", "Hani ar-Rifai"],
    "abkr": ["إدريس أبكر", "Idris Abkar"],
    "frs": ["فارس عباد", "Fares Abbad"],
    "jleel": ["خالد الجليل", "Khalid al-Jalil"],
    "lhdan": ["محمد اللحيدان", "Muhammad al-Luhaidan"],
    "kyat": ["عبد الله خياط", "Abdullah Khayyat"],
    "bud": ["صلاح البدير", "Salah Al-Budair"],
    "akdr": ["إبراهيم الأخضر", "Ibrahim Al-Akhdar"],
    "tnjy": ["خليفة الطنيجي", "Khalifa Al Tunaiji"],
    "mansor": ["منصور السالمي", "Mansour Al-Salimi"],
    "aloosi": ["عبد الرحمن العوسي", "Abdulrahman Al-Ossi"],
    "nabil": ["نبيل الرفاعي", "Nabil ar-Rifai"],
    "dosri": ["إبراهيم الدوسري", "Ibrahim Al-Dosari"],
    "mrifai": ["محمود الرفاعي", "Mahmoud ar-Rifai"],
    "alzain": ["الزين محمد أحمد", "Al-Zain Mohamed Ahmed"],
    # better photos for these
    "husr": ["محمود خليل الحصري", "Mahmoud Khalil Al-Hussary", "Hussary"],
    "mustafa": ["مصطفى إسماعيل", "Mustafa Ismail reciter"],
    "minsh": ["محمد صديق المنشاوي", "Minshawi"],
    "jbrl": ["محمد جبريل", "Muhammad Jibreel"],
    "hthfi": ["علي الحذيفي", "Ali Al-Hudhaify"],
    "shur": ["سعود الشريم", "Saud Al-Shuraim"],
    "qasm": ["عبد المحسن القاسم", "Abdul Mohsen Al-Qasim"],
    "jhn": ["عبد الله الجهني", "Abdullah Al-Juhany"],
    "afs": ["مشاري العفاسي", "Mishary Alafasy"],
    "bader": ["بدر التركي", "Badr Al-Turki"],
}
FREE = re.compile(r"CC|public domain|PD|GFDL|free|CC0|attribution", re.I)


def get(url):
    for i in range(4):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30) as r:
                return r.read()
        except Exception as e:
            time.sleep(2 * (i + 1))
    raise RuntimeError(url)


def api(**p):
    return json.loads(get("https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode({**p, "format": "json"})))


def main():
    os.makedirs(OUT, exist_ok=True)
    report = {}
    for key, names in WANT.items():
        seen, cands = set(), []
        for n in names:
            r = api(action="query", list="search", srsearch=n, srnamespace=6, srlimit=10)
            for hit in r.get("query", {}).get("search", []):
                t = hit["title"]
                if t in seen or not re.search(r"\.(jpe?g|png|webp)$", t, re.I):
                    continue
                seen.add(t)
                cands.append(t)
            time.sleep(0.3)
        rows = []
        for t in cands[:12]:
            info = api(action="query", titles=t, prop="imageinfo", iiprop="url|extmetadata|size", iiurlwidth=1600)
            pg = next(iter(info["query"]["pages"].values()))
            if "imageinfo" not in pg:
                continue
            ii = pg["imageinfo"][0]
            md = ii.get("extmetadata", {})
            lic = md.get("LicenseShortName", {}).get("value", "")
            if not FREE.search(lic):
                continue
            desc = re.sub("<[^>]+>", "", md.get("ImageDescription", {}).get("value", ""))[:200]
            artist = re.sub("<[^>]+>", "", md.get("Artist", {}).get("value", "")).strip()[:80]
            rows.append({"title": t, "license": lic, "author": artist, "desc": desc, "url": ii.get("thumburl"),
                         "w": ii.get("width"), "h": ii.get("height")})
        # contact sheet
        sheet = Image.new("RGB", (6 * 260, ((len(rows) + 5) // 6 or 1) * 300), "white")
        d = ImageDraw.Draw(sheet)
        for i, row in enumerate(rows):
            try:
                im = Image.open(io.BytesIO(get(row["url"]))).convert("RGB")
                row["file"] = f"{key}_{i}.jpg"
                im.save(os.path.join(OUT, row["file"]), quality=90)
                im.thumbnail((250, 250))
                sheet.paste(im, ((i % 6) * 260 + 5, (i // 6) * 300 + 5))
                d.text(((i % 6) * 260 + 5, (i // 6) * 300 + 262), f"{i} {row['w']}x{row['h']}", fill="black")
            except Exception as e:
                print("img fail", key, i, e)
        sheet.save(os.path.join(OUT, f"_{key}.jpg"), quality=80)
        report[key] = rows
        print(key, len(cands), "found", len(rows), "free")
    json.dump(report, open(os.path.join(OUT, "more.json"), "w"), ensure_ascii=False, indent=1)


main()
