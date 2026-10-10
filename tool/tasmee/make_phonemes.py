"""Builds assets/tasmee/phonemes.txt: the phonetic script of every word of
the Mushaf, as the on-device Quran model hears it.

One line per ayah (6236, in order); one space-separated item per word of
the app's Mushaf (assets/quran/quran.json), so word n of an ayah on the page
is item n of its line. Phonetic script by quran-transcript (MIT),
https://github.com/obadx/quran-transcript

Usage: python3 make_phonemes.py <quran-transcript src dir> <repo root>
"""
import json
import re
import sys

sys.path.insert(0, sys.argv[1])
from quran_transcript import Aya, MoshafAttributes, quran_phonetizer  # noqa: E402
from quran_transcript import alphabet as alph  # noqa: E402

ROOT = sys.argv[2]
# Hafs, murattal, 4-count madd: how most reciters (and the model's data) read.
MOSHAF = MoshafAttributes(
    rewaya="hafs",
    madd_monfasel_len=4,
    madd_mottasel_len=4,
    madd_mottasel_waqf=4,
    madd_aared_len=4,
)
SPACE = alph.uthmani.space
NUM = re.compile(r"[\s ]+[٠-٩]+$")
MARKS = re.compile("[ؐ-ًؚ-ٰٟۖ-ۭـ]")


def skeleton(w: str) -> str:
    w = MARKS.sub("", w)
    w = re.sub("[ٱأإآ]", "ا", w).replace("ى", "ي")
    return re.sub("[^ء-ي]", "", w)


def mushaf_words() -> list[list[str]]:
    data = json.load(open(f"{ROOT}/assets/quran/quran.json", encoding="utf-8"))
    out: list[list[str]] = [[] for _ in range(6237)]
    for page in data["lines"]:
        for line in page:
            if line[0] in ("h", "b"):
                continue
            for i in range(2, len(line) - 1, 2):
                g, text = line[i], line[i + 1]
                if g == 0:
                    continue
                out[g].append(NUM.sub("", text))
    return out


def group(ours: list[str], theirs: list[str], ph: list[str]) -> list[str] | None:
    """Phonemes for each of [ours] when the two texts split words differently."""
    a = [skeleton(w) for w in ours]
    b = [skeleton(w) for w in theirs]
    res: list[str] = []
    i = j = 0
    while i < len(a) and j < len(b):
        if a[i] == b[j]:
            res.append(ph[j]); i += 1; j += 1; continue
        done = False
        for n in (2, 3):  # one of ours is n of theirs
            if j + n <= len(b) and "".join(b[j:j + n]) == a[i]:
                res.append("".join(ph[j:j + n])); i += 1; j += n; done = True; break
            if i + n <= len(a) and "".join(a[i:i + n]) == b[j]:
                # n of ours are one of theirs: the phonemes go to the first.
                res.extend([ph[j]] + [""] * (n - 1)); i += n; j += 1; done = True; break
        if not done:
            # Same word, different spelling: take it as is.
            res.append(ph[j]); i += 1; j += 1
    if i != len(a) or j != len(b):
        return None
    return res


def word_phonemes(uthmani: str, sura: int) -> list[str]:
    """The phonemes of each word, from the phonetizer's character mappings
    (words joined in speech, as in «مِن رَّبِّهِمۡ», share no space)."""
    text = re.sub(r"\s+", " ", uthmani).strip()
    out = quran_phonetizer(text, MOSHAF, sura_idx=sura)
    phon = out.phonemes
    maps = out.mappings
    assert len(maps) == len(text), (len(maps), len(text))
    words: list[str] = []
    taken = 0
    i = 0
    for w in text.split(" "):
        lo, hi = None, None
        for k in range(i, i + len(w)):
            m = maps[k]
            if m is None or m.deleted:
                continue
            a, b = m.pos
            lo = a if lo is None else min(lo, a)
            hi = b if hi is None else max(hi, b)
        i += len(w) + 1
        if lo is None:
            words.append("")
            continue
        lo = max(lo, taken)
        piece = phon[lo:hi].replace(" ", "") if hi > lo else ""
        taken = max(taken, hi)
        words.append(piece)
    # Whatever the mappings didn't give a word (rare) goes to the last word.
    rest = phon[taken:].replace(" ", "")
    if rest and words:
        words[-1] += rest
    return words


def main() -> None:
    ours = mushaf_words()
    lines = []
    bad = 0
    g = 0
    for sura in range(1, 115):
        aya = Aya(sura, 1)
        n = aya.get().num_ayat_in_sura
        for a in range(1, n + 1):
            g += 1
            info = Aya(sura, a).get()
            ph = word_phonemes(info.uthmani, sura)
            theirs = info.uthmani_words
            if len(ph) != len(theirs):
                print(f"{sura}:{a} phoneme words {len(ph)} != words {len(theirs)}")
                ph = (ph + [""] * len(theirs))[: len(theirs)]
            mine = ours[g]
            if len(mine) == len(theirs):
                words = ph
            else:
                words = group(mine, theirs, ph)
                if words is None:
                    bad += 1
                    print(f"{sura}:{a} cannot match {len(mine)} vs {len(theirs)}: {mine} | {theirs}")
                    words = (ph + [""] * len(mine))[: len(mine)]
            lines.append(" ".join(w if w else "-" for w in words))
    assert g == 6236, g
    import os
    os.makedirs(f"{ROOT}/assets/tasmee", exist_ok=True)
    extra = {
        "istiadha": quran_phonetizer(Aya(1, 1).get().istiaatha_uthmani, MOSHAF).phonemes.split(SPACE),
    }
    with open(f"{ROOT}/assets/tasmee/phonemes.txt", "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    with open(f"{ROOT}/assets/tasmee/extra.json", "w", encoding="utf-8") as f:
        json.dump(extra, f, ensure_ascii=False)
    print("ayahs", len(lines), "unmatched", bad)


main()
