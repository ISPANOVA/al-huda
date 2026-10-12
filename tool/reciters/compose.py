"""Portraits for the app and the website: the reciter cut out of his photo
(rembg) and placed on the app's own background, the الهدى mark faint behind.

  python3 tool/reciters/compose.py <dir with raw/*.png> <logo_mark.png>

Writes <dir>/<key>.jpg (512 px) next to the raw photos.
"""
import glob
import os
import sys

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter
from rembg import new_session, remove

D, LOGO = sys.argv[1], sys.argv[2]
S = 512


def background():
    bg = Image.new("RGB", (S, S), (0, 0, 0))
    # A warm glow behind the head, like the app's gold on black.
    glow = Image.new("L", (S, S), 0)
    ImageDraw.Draw(glow).ellipse((S * 0.08, S * 0.02, S * 0.92, S * 0.86), fill=255)
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.16))
    bg.paste(Image.new("RGB", (S, S), (58, 42, 14)), (0, 0), glow)
    # The app's mark, large and faint.
    logo = Image.open(LOGO).convert("RGBA").resize((int(S * 1.05), int(S * 1.05)), Image.LANCZOS)
    alpha = logo.getchannel("A").point(lambda a: int(a * 0.22))
    logo.putalpha(alpha)
    bg = bg.convert("RGBA")
    off = (S - logo.size[0]) // 2
    bg.alpha_composite(logo, (off, off - int(S * 0.04)))
    return bg


# Photos whose cut-out is not clean (checked by eye): the photo itself fades
# into the background instead, from an oval around the face.
BLEND = {"afs", "bader", "husr", "jbrl", "maher", "minsh", "mustafa", "shur"}


def blended(base, img):
    img = img.resize((S, S), Image.LANCZOS).convert("RGBA")
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse((S * 0.08, S * 0.02, S * 0.92, S * 1.12), fill=255)
    img.putalpha(mask.filter(ImageFilter.GaussianBlur(S * 0.07)))
    out = base.copy()
    out.alpha_composite(img)
    return out


def main():
    session = new_session("u2net_human_seg")
    base = background()
    for f in sorted(glob.glob(os.path.join(D, "raw", "*.png"))):
        key = os.path.splitext(os.path.basename(f))[0]
        img = Image.open(f).convert("RGB")
        img = ImageEnhance.Contrast(img).enhance(1.04)
        if key in BLEND:
            out = blended(base, img).convert("RGB").filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))
            out.save(os.path.join(D, f"{key}.jpg"), "JPEG", quality=86, optimize=True, progressive=True)
            print("blended", key)
            continue
        cut = remove(img, session=session, post_process_mask=True).resize((S, S), Image.LANCZOS)
        # Soften the cut edge a little so it sits in the scene.
        a = cut.getchannel("A").filter(ImageFilter.GaussianBlur(0.8))
        cut.putalpha(a)
        out = base.copy()
        # A faint dark shadow under the figure.
        shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        shadow.putalpha(a.point(lambda v: int(v * 0.5)).filter(ImageFilter.GaussianBlur(10)))
        out.alpha_composite(shadow, (0, 6))
        out.alpha_composite(cut)
        out = out.convert("RGB").filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))
        out.save(os.path.join(D, f"{key}.jpg"), "JPEG", quality=86, optimize=True, progressive=True)
        print("composed", key)


main()
