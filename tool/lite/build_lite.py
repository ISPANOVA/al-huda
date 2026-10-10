"""Builds the light web version (no Flutter) into an output folder.

  python3 tool/lite/build_lite.py <out dir>

Static files come from tool/lite/site; the Quran data is cut from
assets/quran/quran.json into small files loaded only when needed (one page,
one page's tafseer), so the site stays light on phones. The app's other
content (athkar, duas, …) is exported by tool/lite/export_test.dart, and its
logic (prayer times, hijri dates, Tasmee) compiled from Dart by core.dart.
"""
import json
import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = sys.argv[1]


def dump(path, data):
    path = os.path.join(OUT, path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))


def main():
    if os.path.exists(OUT):
        shutil.rmtree(OUT)
    shutil.copytree(os.path.join(ROOT, "tool/lite/site"), OUT)
    for name in ["icons", "favicon.png", "og.jpg", "privacy.html"]:
        src = os.path.join(ROOT, "tool/web", name)
        dst = os.path.join(OUT, name)
        if os.path.isdir(src):
            shutil.copytree(src, dst)
        elif os.path.exists(src):
            shutil.copy(src, dst)

    q = json.load(open(os.path.join(ROOT, "assets/quran/quran.json"), encoding="utf-8"))
    rows = q["a"]
    # Per-ayah facts, as plain arrays (index = global ayah - 1).
    meta = {
        "ref": q.get("ref50") or q.get("ref") or 1540,
        "surah": [r[0] for r in rows],
        "ayah": [r[1] for r in rows],
        "juz": [r[4] for r in rows],
        "page": [r[5] for r in rows],
        "hq": [r[6] for r in rows],
        "sajda": [i + 1 for i, r in enumerate(rows) if r[7] == 1],
    }
    dump("data/meta.json", meta)
    # Plain (imlaei) text of each ayah, for the search.
    dump("data/search.json", [r[8] if len(r) > 8 else "" for r in rows])

    number = re.compile(r"[\s ]+[٠-٩]+$")
    words = []
    page_start = []
    for p, lines in enumerate(q["lines"], start=1):
        dump(f"data/p/{p}.json", lines)
        tafseer = {}
        page_start.append(len(words))
        for line in lines:
            if line[0] in ("h", "b"):
                continue
            for i in range(2, len(line) - 1, 2):
                g, text = line[i], line[i + 1]
                if g == 0:
                    continue
                tafseer[g] = rows[g - 1][3]
                m = number.search(text)
                words.append([rows[g - 1][0], rows[g - 1][1], text[: m.start()] if m else text, 1 if m else 0])
        dump(f"data/t/{p}.json", tafseer)
    page_start.append(len(words))
    # The Tasmee's words (all of the Mushaf, in page order).
    dump("data/words.json", {"words": words, "pageStart": page_start})

    fonts = os.path.join(OUT, "fonts")
    os.makedirs(fonts, exist_ok=True)
    for f in ["UthmanicHafs18.ttf", "Tajawal-Regular.ttf", "Tajawal-Bold.ttf", "Tajawal-ExtraBold.ttf", "ReemKufi-Bold.ttf"]:
        src = os.path.join(ROOT, "assets/fonts", f)
        try:
            from fontTools.ttLib import TTFont

            font = TTFont(src)
            font.flavor = "woff2"
            font.save(os.path.join(fonts, f.replace(".ttf", ".woff2")))
        except Exception as e:  # fontTools missing: plain TTF
            print("woff2 skipped", f, e)
            shutil.copy(src, os.path.join(fonts, f.replace(".ttf", ".woff2")))
    # A new cache for the service worker on every build.
    sw = os.path.join(OUT, "sw.js")
    version = (os.environ.get("GITHUB_SHA") or str(int(os.path.getmtime(sw))))[:12]
    with open(sw, encoding="utf-8") as f:
        text = f.read().replace("__BUILD__", version)
    with open(sw, "w", encoding="utf-8") as f:
        f.write(text)
    print("pages", len(q["lines"]), "words", len(words))


main()
