"""Finds the verbally similar ayahs (المتشابهات اللفظية) in the bundled Mushaf.

  python3 tool/quran/mutashabihat.py

Two ayahs are similar when they share a run of at least four words (after
removing diacritics and unifying letter forms), or when two short ayahs are
nearly the same. Writes assets/quran/mutashabihat.json:
{"<global ayah>": [<global ayah>, ...]} (both directions), at most 12 each.
"""
import json
import os
import re
from collections import defaultdict
from difflib import SequenceMatcher

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
data = json.load(open(os.path.join(ROOT, "assets/quran/quran.json"), encoding="utf-8"))

MARKS = re.compile("[ؐ-ًؚ-ٰٟۖ-ۭ࣓-ࣿـ]")


def norm(t):
    t = re.sub(r"[ \s]+[٠-٩]+$", "", t)
    t = MARKS.sub("", t)
    for a, b in (("ٱ", "ا"), ("أ", "ا"), ("إ", "ا"), ("آ", "ا"), ("ى", "ي"), ("ة", "ه"), ("ؤ", "و"), ("ئ", "ي"), ("ۥ", ""), ("ۦ", "")):
        t = t.replace(a, b)
    return [w for w in re.split(r"\s+", t) if w]


ayahs = data["a"]
words = [norm(a[2]) for a in ayahs]
# Drop the basmala that opens ayah 1 of Al-Fatiha only (it is an ayah there).
N = 4
grams = defaultdict(set)
for i, w in enumerate(words):
    for k in range(len(w) - N + 1):
        grams[" ".join(w[k:k + N])].add(i)

pairs = defaultdict(dict)
for g, ids in grams.items():
    if len(ids) > 40:  # a phrase in 40+ ayahs is a formula, not a confusable pair
        continue
    ids = sorted(ids)
    for a in ids:
        for b in ids:
            if a != b:
                pairs[a][b] = pairs[a].get(b, 0) + 1

# Short ayahs (under four words) that are nearly identical.
short = [i for i, w in enumerate(words) if 1 <= len(w) < N]
by_first = defaultdict(list)
for i in short:
    by_first[words[i][0]].append(i)
for ids in by_first.values():
    for a in ids:
        for b in ids:
            if a < b and SequenceMatcher(None, words[a], words[b]).ratio() >= 0.66 and words[a] != words[b] or (a < b and words[a] == words[b]):
                pairs[a][b] = pairs[a].get(b, 0) + 1
                pairs[b][a] = pairs[b].get(a, 0) + 1

out = {}
for a, others in pairs.items():
    best = sorted(others, key=lambda b: (-others[b], b))[:12]
    out[str(a + 1)] = sorted(b + 1 for b in best)
json.dump(out, open(os.path.join(ROOT, "assets/quran/mutashabihat.json"), "w"), separators=(",", ":"))
print(len(out), "ayahs with similar ayahs;", sum(len(v) for v in out.values()), "links")
