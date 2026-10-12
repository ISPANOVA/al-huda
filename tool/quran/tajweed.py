"""Tajweed colours for the bundled Mushaf (run in CI: see probe.yml).

  python3 tool/quran/tajweed.py <out dir>

Quran.com gives every word twice: in the KFGQPC Hafs text the app draws
(text_qpc_hafs) and in Uthmani script with its tajweed rules marked
(text_uthmani_tajweed). The two scripts differ in a few marks, so the rules
are carried over letter by letter (difflib) onto the app's own words.

Writes <out>/tajweed.txt: one line per Mushaf page; on it the page's words in
reading order (as the app lays them out) separated by '|', each word's
coloured runs as 'start.end.rule' separated by ','. Rule numbers index RULES.
Also <out>/tajweed_report.txt (how well the words matched).
"""
import html
import json
import os
import re
import sys
import time
import unicodedata
import urllib.request
from difflib import SequenceMatcher

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
UA = {"User-Agent": "AlHudaApp/1.0 (https://github.com/ISPANOVA/al-huda)"}

RULES = [
    "ham_wasl", "slnt", "laam_shamsiyah", "madda_normal", "madda_permissible", "madda_necessary",
    "madda_obligatory", "qalaqah", "ikhafa_shafawi", "ikhafa", "idgham_shafawi", "iqlab",
    "idgham_ghunnah", "idgham_wo_ghunnah", "idgham_mutajanisayn", "idgham_mutaqaribayn", "ghunnah",
]
ALIAS = {"madda_obligatory_monfasel": "madda_permissible", "madda_obligatory_mottasel": "madda_obligatory"}


def get(url):
    for i in range(5):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
                return json.loads(r.read())
        except Exception as e:  # noqa: BLE001
            print("retry", url, e)
            time.sleep(2 + i * 3)
    raise SystemExit("failed " + url)


# 1. Quran.com words, by verse and position.
qc = {}
for page in range(1, 605):
    d = get(f"https://api.quran.com/api/v4/verses/by_page/{page}?words=true&per_page=50"
            "&word_fields=text_qpc_hafs,text_uthmani_tajweed")
    for v in d["verses"]:
        pos = 0
        for w in v["words"]:
            if w["char_type_name"] != "word":
                continue
            pos += 1
            qc[(v["verse_key"], pos)] = (w.get("text_qpc_hafs") or "", w.get("text_uthmani_tajweed") or "")
    if page % 50 == 0:
        print("page", page, len(qc))
    time.sleep(0.15)

# 2. The app's own words, page by page.
data = json.load(open(os.path.join(ROOT, "assets/quran/quran.json"), encoding="utf-8"))
ayahs = data["a"]
key_of = {i + 1: f"{a[0]}:{a[1]}" for i, a in enumerate(ayahs)}

TAG = re.compile(r"<(/?)(\w+)([^>]*)>")


def parse(markup):
    """Uthmani tajweed markup to [(char, rule or None)]."""
    out, stack, i = [], [], 0
    for m in TAG.finditer(markup):
        for c in html.unescape(markup[i:m.start()]):
            out.append((c, stack[-1] if stack else None))
        i = m.end()
        if m.group(1):
            if stack:
                stack.pop()
        else:
            cls = re.search(r"class=\"?([\w-]+)", m.group(3))
            stack.append(ALIAS.get(cls.group(1), cls.group(1)) if cls and m.group(2) in ("rule", "tajweed") else None)
    for c in html.unescape(markup[i:]):
        out.append((c, stack[-1] if stack else None))
    return out


CANON = {"ْ": "ۡ", "ـ": "", "ۥ": "و", "ۦ": "ي"}


def canon(c):
    return CANON.get(c, c)


stats = {"words": 0, "exact": 0, "aligned": 0, "missing": 0, "rules": 0}
lines_out = []
counter = {}
for page in data["lines"]:
    words_out = []
    for line in page:
        if not line or line[0] not in ("t", "c"):
            continue
        items = line[2:]
        for k in range(0, len(items) - 1, 2):
            g, text = items[k], items[k + 1]
            counter[g] = counter.get(g, 0) + 1
            stats["words"] += 1
            body = re.sub(r"[ \s]+[٠-٩]+$", "", text)
            got = qc.get((key_of[g], counter[g]))
            if not got:
                stats["missing"] += 1
                words_out.append("")
                continue
            qpc, markup = got
            if qpc == body:
                stats["exact"] += 1
            chars = [(canon(c), r) for c, r in parse(markup)]
            chars = [(c, r) for c, r in chars if c]
            a = "".join(c for c, _ in chars)
            b = "".join(canon(c) or "ـ" for c in body)
            rule = [None] * len(body)
            for blk in SequenceMatcher(None, a, b, autojunk=False).get_matching_blocks():
                for j in range(blk.size):
                    rule[blk.b + j] = chars[blk.a + j][1]
            # Marks (harakat) take the colour of their letter.
            for j in range(1, len(body)):
                if rule[j] is None and unicodedata.category(body[j]) == "Mn":
                    rule[j] = rule[j - 1]
            if SequenceMatcher(None, a, b, autojunk=False).ratio() > 0.8:
                stats["aligned"] += 1
            runs, j = [], 0
            while j < len(body):
                r = rule[j]
                if r is None or r not in RULES:
                    j += 1
                    continue
                s = j
                while j < len(body) and rule[j] == r:
                    j += 1
                runs.append(f"{s}.{j}.{RULES.index(r)}")
                stats["rules"] += 1
            words_out.append(",".join(runs))
    lines_out.append("|".join(words_out))

open(os.path.join(OUT, "tajweed.txt"), "w", encoding="utf-8").write("\n".join(lines_out) + "\n")
report = json.dumps(stats, ensure_ascii=False)
open(os.path.join(OUT, "tajweed_report.txt"), "w").write(report + "\n")
print(report)
