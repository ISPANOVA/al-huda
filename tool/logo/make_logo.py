"""Generates the Al-Huda logo: gold calligraphy "الهُدَى" inside an
eight-pointed Islamic star medallion over a black field with a faint gold
geometric lattice. Outputs app_icon.png (full), app_icon_foreground.png
(transparent, adaptive-icon safe zone) and logo_mark.png (emblem for splash)."""
import math, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

S = 2048
FONT = sys.argv[1] if len(sys.argv) > 1 else 'tool/logo/ArefRuqaa-Bold.ttf'
OUT = sys.argv[2] if len(sys.argv) > 2 else 'assets/icon'

GOLD_LIGHT = (247, 226, 163)
GOLD = (212, 175, 90)
GOLD_DARK = (150, 110, 40)

def gold_fill(size, angle_vertical=True):
    """Metallic vertical gold gradient."""
    w, h = size
    g = Image.new('RGB', (1, 256))
    stops = [(0, GOLD_LIGHT), (0.35, (232, 199, 117)), (0.55, GOLD), (0.75, (240, 214, 140)), (1, GOLD_DARK)]
    for y in range(256):
        t = y / 255
        for i in range(len(stops) - 1):
            a, ca = stops[i]; b, cb = stops[i + 1]
            if a <= t <= b:
                k = (t - a) / (b - a)
                g.putpixel((0, y), tuple(int(ca[j] + (cb[j] - ca[j]) * k) for j in range(3)))
                break
    return g.resize((w, h))

def star_points(cx, cy, r_out, r_in, n=8, rot=-math.pi / 2):
    pts = []
    for i in range(n * 2):
        a = rot + i * math.pi / n
        r = r_out if i % 2 == 0 else r_in
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts

def octagram(cx, cy, r, rot=0):
    """Two overlapping squares (Rub el Hizb outline)."""
    sq = []
    for k in range(2):
        base = rot + k * math.pi / 4
        sq.append([(cx + r * math.cos(base + math.pi / 4 + i * math.pi / 2),
                    cy + r * math.sin(base + math.pi / 4 + i * math.pi / 2)) for i in range(4)])
    return sq

def lattice(mask_draw, step, width, alpha):
    """Faint 8-point star tiling."""
    for gy in range(-1, S // step + 2):
        for gx in range(-1, S // step + 2):
            cx, cy = gx * step + (step / 2 if gy % 2 else 0), gy * step * 0.866
            for sq in octagram(cx, cy, step * 0.32):
                mask_draw.polygon(sq, outline=alpha, width=width)
            mask_draw.ellipse([cx - step * 0.12, cy - step * 0.12, cx + step * 0.12, cy + step * 0.12], outline=alpha, width=width)

def emblem(with_lattice_bg):
    """Returns (RGBA emblem at S×S, transparent background)."""
    cx = cy = S / 2
    line = Image.new('L', (S, S), 0)
    d = ImageDraw.Draw(line)
    # Outer octagram (two squares) with double outline
    R = S * 0.46
    for sq in octagram(cx, cy, R):
        d.polygon(sq, outline=255, width=int(S * 0.012))
    for sq in octagram(cx, cy, R * 0.93):
        d.polygon(sq, outline=200, width=int(S * 0.005))
    # Rings
    for rr, w in [(R * 0.80, 0.010), (R * 0.755, 0.004)]:
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=255, width=int(S * w))
    # Small stars at the 8 tips
    for i in range(8):
        a = -math.pi / 2 + i * math.pi / 4
        px, py = cx + R * 1.0 * math.cos(a), cy + R * 1.0 * math.sin(a)
        d.polygon(star_points(px, py, S * 0.022, S * 0.010), fill=255)
    # Tiny dots ring
    for i in range(48):
        a = i * 2 * math.pi / 48
        rr = R * 0.86
        px, py = cx + rr * math.cos(a), cy + rr * math.sin(a)
        d.ellipse([px - S * 0.004, py - S * 0.004, px + S * 0.004, py + S * 0.004], fill=180)

    # Calligraphy
    txt = Image.new('L', (S, S), 0)
    td = ImageDraw.Draw(txt)
    font = ImageFont.truetype(FONT, int(S * 0.30), layout_engine=ImageFont.Layout.RAQM)
    word = 'الهُدَى'
    bbox = td.textbbox((0, 0), word, font=font, direction='rtl')
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    td.text((cx - tw / 2 - bbox[0], cy - th / 2 - bbox[1] + S * 0.005), word, font=font, fill=255, direction='rtl')
    # Fit inside inner ring
    inner = R * 0.70 * 2
    if tw > inner:
        scale = inner / tw
        t2 = txt.resize((int(S * scale), int(S * scale)), Image.LANCZOS)
        txt = Image.new('L', (S, S), 0)
        txt.paste(t2, (int((S - t2.width) / 2), int((S - t2.height) / 2)))

    mask = ImageChops.lighter(line, txt)
    gold = gold_fill((S, S))
    em = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    em.paste(gold, (0, 0), mask)
    # Soft glow + thin dark edge for depth
    glow = mask.filter(ImageFilter.GaussianBlur(S * 0.012))
    glow_layer = Image.new('RGBA', (S, S), GOLD + (0,))
    glow_layer.putalpha(glow.point(lambda v: int(v * 0.55)))
    shadow = mask.filter(ImageFilter.GaussianBlur(S * 0.004)).point(lambda v: int(v * 0.6))
    shadow_layer = Image.new('RGBA', (S, S), (40, 25, 5, 0))
    shadow_layer.putalpha(shadow)
    out = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    # Dark medallion so the background lattice never crosses the name.
    disk = Image.new('L', (S, S), 0)
    rr = R * 0.79
    ImageDraw.Draw(disk).ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=235)
    disk_layer = Image.new('RGBA', (S, S), (8, 6, 2, 0))
    disk_layer.putalpha(disk)
    if with_lattice_bg:
        out.alpha_composite(disk_layer)
    out.alpha_composite(glow_layer)
    out.alpha_composite(shadow_layer, (int(S * 0.003), int(S * 0.004)))
    out.alpha_composite(em)
    return out

def background():
    bg = Image.new('RGB', (S, S), (0, 0, 0))
    # radial warm glow
    rad = Image.radial_gradient('L').resize((S, S))  # 0 center -> 255 edge
    warm = Image.new('RGB', (S, S), (46, 34, 12))
    bg = Image.composite(bg, warm, rad.point(lambda v: min(255, int(v * 1.15))))
    lat = Image.new('L', (S, S), 0)
    lattice(ImageDraw.Draw(lat), int(S / 7), int(S * 0.0022), 40)
    gold = gold_fill((S, S))
    bg.paste(gold, (0, 0), lat.point(lambda v: int(v * 0.55)))
    return bg

em = emblem(True)
bg = background()

# Full icon (square, used by iOS & legacy Android): emblem at 84%
full = bg.convert('RGBA')
e = em.resize((int(S * 0.84), int(S * 0.84)), Image.LANCZOS)
full.alpha_composite(e, ((S - e.width) // 2, (S - e.height) // 2))
full.convert('RGB').resize((1024, 1024), Image.LANCZOS).save(f'{OUT}/app_icon.png')

# Adaptive foreground: emblem inside the 66% safe zone, transparent
fg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
e2 = em.resize((int(S * 0.62), int(S * 0.62)), Image.LANCZOS)
fg.alpha_composite(e2, ((S - e2.width) // 2, (S - e2.height) // 2))
fg.resize((1024, 1024), Image.LANCZOS).save(f'{OUT}/app_icon_foreground.png')

# Adaptive background with the gold lattice
bg.resize((1024, 1024), Image.LANCZOS).save(f'{OUT}/app_icon_background.png')

# Emblem alone for the splash screen
em.resize((1024, 1024), Image.LANCZOS).save(f'{OUT}/logo_mark.png')
print('ok')
