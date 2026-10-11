"""Artwork for Android Auto, drawn once and kept as Android drawables.

  python3 tool/car/make_car_art.py

Writes into tool/android_res/drawable-nodpi (copied into the app by
configure_platforms.dart):

* car_s_<n>.webp — a tile for each of the 114 surahs: the surah's name in
  gold over the app's dark background, its number in a star above;
* car_r_<key>.webp — every reciter of the catalog: his photo from
  assets/reciters, small (256 px), or, without a photo, his name in gold on
  the same background, so the reciters grid never shows a blank icon.

Run it again whenever the reciter photos change.
"""
import glob
import os
import re

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "tool/android_res/drawable-nodpi")
FONT = os.path.join(ROOT, "assets/fonts/ReemKufi-Bold.ttf")
DIGITS = os.path.join(ROOT, "assets/fonts/Tajawal-ExtraBold.ttf")
LOGO = os.path.join(ROOT, "assets/icon/logo_mark.png")
S = 256
GOLD = (226, 192, 116)
GOLD_HI = (246, 222, 160)
AR = str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩")


def surahs():
    src = open(os.path.join(ROOT, "lib/core/data/surah_metadata.dart"), encoding="utf-8").read()
    return [(int(n), name, mk == "true") for n, name, mk in re.findall(r"SurahInfo\((\d+), '([^']+)', '(?:[^'\\]|\\.)*', \d+, (true|false)\)", src)]


def background(meccan):
    bg = Image.new("RGB", (S, S), (6, 6, 8))
    glow = Image.new("L", (S, S), 0)
    ImageDraw.Draw(glow).ellipse((-S * 0.1, S * 0.05, S * 1.1, S * 1.15), fill=255)
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.18))
    # Meccan surahs a warmer gold, Medinan a deeper green-gold: a quiet hint.
    tone = (60, 42, 12) if meccan else (22, 46, 34)
    bg.paste(Image.new("RGB", (S, S), tone), (0, 0), glow)
    logo = Image.open(LOGO).convert("RGBA").resize((int(S * 1.1), int(S * 1.1)), Image.LANCZOS)
    logo.putalpha(logo.getchannel("A").point(lambda a: int(a * 0.10)))
    bg = bg.convert("RGBA")
    off = (S - logo.size[0]) // 2
    bg.alpha_composite(logo, (off, off + int(S * 0.08)))
    return bg


def star(d, cx, cy, r, fill, outline, width):
    """The eight-pointed star of the ayah markers."""
    import math
    pts = []
    for i in range(16):
        a = math.pi / 8 * i - math.pi / 2
        rr = r if i % 2 == 0 else r * 0.80
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts, fill=fill, outline=outline, width=width)


def fit(text, font_path, max_w, start):
    size = start
    while size > 20:
        f = ImageFont.truetype(font_path, size, layout_engine=ImageFont.Layout.RAQM)
        box = f.getbbox(text, direction="rtl", language="ar")
        if box[2] - box[0] <= max_w:
            return f, box
        size -= 2
    return f, box


def surah_tile(n, name, meccan):
    im = background(meccan)
    d = ImageDraw.Draw(im)
    # A thin gold frame, like the app's cards.
    d.rounded_rectangle((8, 8, S - 9, S - 9), radius=34, outline=GOLD + (110,), width=3)
    star(d, S / 2, S * 0.30, S * 0.17, (14, 12, 8, 255), GOLD + (255,), 4)
    nf = ImageFont.truetype(DIGITS, 44 if n < 100 else 36)
    num = str(n).translate(AR)
    b = nf.getbbox(num, direction="rtl", language="ar")
    d.text((S / 2 - (b[0] + b[2]) / 2, S * 0.30 - (b[1] + b[3]) / 2), num, font=nf, fill=GOLD_HI, direction="rtl", language="ar")
    f, b = fit(name, FONT, S * 0.84, 64)
    x = S / 2 - (b[0] + b[2]) / 2
    y = S * 0.70 - (b[1] + b[3]) / 2
    # A soft shadow keeps the name crisp on any car screen.
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(sh).text((x, y + 3), name, font=f, fill=(0, 0, 0, 200), direction="rtl", language="ar")
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(3)))
    d = ImageDraw.Draw(im)
    d.text((x, y), name, font=f, fill=GOLD_HI, direction="rtl", language="ar")
    return im.convert("RGB")


def reciters():
    src = open(os.path.join(ROOT, "lib/features/media/media_catalog.dart"), encoding="utf-8").read()
    out = {}
    for key, name in re.findall(r"MediaReciter\('([a-z0-9_]+)', '([^']+)'", src):
        out.setdefault(key.replace("_mj", ""), name)
    return out


def name_tile(name):
    im = background(True)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((8, 8, S - 9, S - 9), radius=34, outline=GOLD + (110,), width=3)
    star(d, S / 2, S * 0.22, S * 0.09, (14, 12, 8, 255), GOLD + (255,), 3)
    words = name.split()
    # Two balanced lines: «عبد الباسط» over «عبد الصمد».
    cut = min(range(1, len(words)), key=lambda i: abs(len(" ".join(words[:i])) - len(" ".join(words[i:])))) if len(words) > 1 else 1
    lines = [" ".join(words[:cut]), " ".join(words[cut:])] if len(words) > 1 else [name]
    size = 52
    while True:
        f = ImageFont.truetype(FONT, size, layout_engine=ImageFont.Layout.RAQM)
        boxes = [f.getbbox(t, direction="rtl", language="ar") for t in lines]
        if max(b[2] - b[0] for b in boxes) <= S * 0.82 or size <= 22:
            break
        size -= 2
    lh = size * 1.25
    top = S * 0.60 - lh * len(lines) / 2
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    for i, (t, b) in enumerate(zip(lines, boxes)):
        x = S / 2 - (b[0] + b[2]) / 2
        y = top + i * lh + lh / 2 - (b[1] + b[3]) / 2
        sd.text((x, y + 3), t, font=f, fill=(0, 0, 0, 200), direction="rtl", language="ar")
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(3)))
    d = ImageDraw.Draw(im)
    for i, (t, b) in enumerate(zip(lines, boxes)):
        x = S / 2 - (b[0] + b[2]) / 2
        y = top + i * lh + lh / 2 - (b[1] + b[3]) / 2
        d.text((x, y), t, font=f, fill=GOLD_HI, direction="rtl", language="ar")
    return im.convert("RGB")


def main():
    os.makedirs(OUT, exist_ok=True)
    for old in glob.glob(os.path.join(OUT, "car_s_*")) + glob.glob(os.path.join(OUT, "car_r_*")):
        os.remove(old)
    for n, name, meccan in surahs():
        tile = surah_tile(n, name, meccan)
        # WebP (Android 7+, the app's minimum): a tenth of a PNG's size.
        tile.save(os.path.join(OUT, f"car_s_{n}.webp"), "WEBP", quality=85, method=6)
    for key, name in reciters().items():
        p = os.path.join(ROOT, f"assets/reciters/{key}.jpg")
        im = Image.open(p).convert("RGB").resize((S, S), Image.LANCZOS) if os.path.exists(p) else name_tile(name)
        im.save(os.path.join(OUT, f"car_r_{key}.webp"), "WEBP", quality=84, method=6)
    print("surahs:", len(surahs()), "reciters:", len(glob.glob(os.path.join(OUT, "car_r_*.webp"))))


if __name__ == "__main__":
    main()
