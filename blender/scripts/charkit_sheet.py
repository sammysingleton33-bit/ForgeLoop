"""Compose review sheets from charkit_compare renders (FL-0135). Pillow only (no bpy).

  python blender/scripts/charkit_sheet.py --dir DIR --out OUT_DIR --labels "old=Reference,A=Style 2,B=Style 3,C=Style 1"
        [--tris "A=1124,B=845,C=1290"]

Writes OUT_DIR/sheet_portrait.jpg, sheet_gameplay40.jpg, sheet_aerial170.jpg (each <= 250 KB). Labels are neutral on purpose:
the image-only reviewer must not learn which option is procedural or derived.
"""

import argparse
import io
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def save_under(img, path, limit=245_000):
    img = img.convert("RGB")
    while True:
        for q in (90, 85, 80, 74, 68, 60):
            buf = io.BytesIO()
            img.save(buf, "JPEG", quality=q, optimize=True, progressive=True)
            if buf.tell() <= limit:
                Path(path).write_bytes(buf.getvalue())
                return buf.tell()
        img = img.resize((int(img.width * 0.9), int(img.height * 0.9)), Image.LANCZOS)


def label_bar(w, text, h=26, fill=(28, 30, 34)):
    bar = Image.new("RGB", (w, h), fill)
    ImageDraw.Draw(bar).text((8, 4), text, fill=(235, 235, 235), font=font(16))
    return bar


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--labels", required=True)
    ap.add_argument("--tris", default="")
    ap.add_argument("--chars", default="farmer,soldier,governor")
    ap.add_argument("--tile", type=int, default=330)
    a = ap.parse_args()
    d, out = Path(a.dir), Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    labels = dict(kv.split("=", 1) for kv in a.labels.split(","))
    tris = dict(kv.split("=", 1) for kv in a.tris.split(",")) if a.tris else {}
    chars = a.chars.split(",")
    order = list(labels)

    # portraits: one row per option, one column per character
    t = a.tile
    sheet = Image.new("RGB", (len(chars) * t, len(order) * (t + 26)), (28, 30, 34))
    for r, o in enumerate(order):
        txt = labels[o] + (f"   citizen triangles: {tris[o]}" if o in tris else "")
        sheet.paste(label_bar(sheet.width, txt), (0, r * (t + 26)))
        for c, ch in enumerate(chars):
            im = Image.open(d / f"{o}_portrait_{ch}.png").convert("RGB").resize((t, t), Image.LANCZOS)
            sheet.paste(im, (c * t, r * (t + 26) + 26))
    n = save_under(sheet, out / "sheet_portrait.jpg")
    print("sheet_portrait.jpg", sheet.size, n)

    # gameplay (~40 studs): crop around the three characters, enlarge 2x
    crops = []
    for o in order:
        im = Image.open(d / f"{o}_gp40.png").convert("RGB")
        w, h = im.size
        box = (w // 2 - 250, int(h * 0.30), w // 2 + 250, int(h * 0.30) + 230)
        crops.append(im.crop(box).resize((1000, 460), Image.LANCZOS))
    sheet = Image.new("RGB", (1000, len(order) * (460 + 26)), (28, 30, 34))
    for r, (o, im) in enumerate(zip(order, crops)):
        sheet.paste(label_bar(1000, labels[o] + "   (~40 studs from the camera, Roblox 70 deg FOV, crop enlarged 2x)"), (0, r * 486))
        sheet.paste(im, (0, r * 486 + 26))
    n = save_under(sheet, out / "sheet_gameplay40.jpg")
    print("sheet_gameplay40.jpg", sheet.size, n)

    # aerial (170 studs, 50 deg down): the building and the three citizens, 2x crop; native crop beside it
    tiles = []
    for o in order:
        im = Image.open(d / f"{o}_aerial170.png").convert("RGB")
        w, h = im.size
        cx, cy = w // 2, int(h * 0.50)
        big = im.crop((cx - 120, cy - 78, cx + 120, cy + 57)).resize((900, 506), Image.LANCZOS)
        small = im.crop((cx - 200, cy - 112, cx + 200, cy + 113))
        tiles.append((o, big, small))
    sheet = Image.new("RGB", (900 + 400 + 8, len(order) * (506 + 26)), (28, 30, 34))
    for r, (o, big, small) in enumerate(tiles):
        sheet.paste(label_bar(sheet.width, labels[o] + "   (170 studs, 50 deg down; left: crop enlarged 3.75x, right: actual pixels)"), (0, r * 532))
        sheet.paste(big, (0, r * 532 + 26))
        sheet.paste(small, (908, r * 532 + 26))
    n = save_under(sheet, out / "sheet_aerial170.jpg")
    print("sheet_aerial170.jpg", sheet.size, n)


if __name__ == "__main__":
    main()
