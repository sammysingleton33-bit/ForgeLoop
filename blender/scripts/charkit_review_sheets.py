"""Compose the D-019 review / before-after sheets of the character kit from raw renders (FL-0135). PIL only.

  python3 blender/scripts/charkit_review_sheets.py --src RENDER_DIR --out IMG_DIR [--max-kb 250]

RENDER_DIR holds the PNGs of blender/scripts/charkit_scenes.py (+ charkit_compare.py old portraits): portraits, ba_new, old_portrait_*,
crowd40_old/new, crowd170_old/new, jobs, old_jobs, sil_jobs, old_sil_jobs, looks, kingdoms, kingdoms_back, turn_*. Every sheet is a
JPEG <= --max-kb (quality is lowered until it fits). Blender renders, not Studio renders.
"""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

BG = (28, 30, 34)
FG = (235, 235, 235)


def load(src, name):
    return Image.open(Path(src) / f"{name}.png").convert("RGB")


def fit_w(im, w):
    return im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)


def label(canvas, xy, text):
    ImageDraw.Draw(canvas).text(xy, text, fill=FG)


def stack(rows, width, gap=6, head=22):
    """rows: [(title, PIL image)] -> one image, each row scaled to `width`."""
    ims = [(t, fit_w(im, width)) for t, im in rows]
    h = sum(im.height + head + gap for _, im in ims)
    out = Image.new("RGB", (width, h), BG)
    y = 0
    for t, im in ims:
        label(out, (6, y + 5), t)
        out.paste(im, (0, y + head))
        y += im.height + head + gap
    return out


def save(im, path, max_kb):
    for q in (90, 85, 80, 74, 68, 60, 52):
        im.save(path, quality=q, optimize=True)
        if Path(path).stat().st_size <= max_kb * 1024:
            return q
    return None


def aerial_pair(src, name, cx=645, cy=375):
    """Enlarged crop (3.75x, like round 1) + the same region at actual pixels."""
    im = load(src, name)
    big = im.crop((cx - 120, cy - 78, cx + 120, cy + 57)).resize((900, 506), Image.BICUBIC)
    act = im.crop((cx - 180, cy - 101, cx + 180, cy + 102))
    out = Image.new("RGB", (900 + 360 + 8, 506), BG)
    out.paste(big, (0, 0))
    out.paste(act, (908, 0))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--max-kb", type=int, default=250)
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    s = a.src
    sheets = {}

    # 1 portraits of every identity (conversation portrait framing)
    sheets["sheet_portraits"] = load(s, "portraits")

    # 2 before / after portraits of the same three roles (farmer, soldier, ruler)
    new = load(s, "ba_new")
    px = 480
    tiles = [new.crop((i * px, 22, (i + 1) * px, 22 + px)) for i in range(3)]
    old = [load(s, f"old_portrait_{j}").resize((px, px), Image.LANCZOS) for j in ("farmer", "soldier", "governor")]
    ba = Image.new("RGB", (3 * px, 2 * (px + 24)), BG)
    for row, (title, ims) in enumerate((("BEFORE: current part-built rig (farmer, soldier, ruler)", old), ("AFTER: mesh kit (farmer, soldier, ruler)", tiles))):
        label(ba, (6, row * (px + 24) + 5), title)
        for i, im in enumerate(ims):
            ba.paste(im, (i * px, row * (px + 24) + 24))
    sheets["sheet_before_after_portrait"] = ba

    # 3 gameplay distance (about 40 studs), before / after, same roster and camera
    sheets["sheet_gameplay40"] = stack([("BEFORE: current rigs, 40 studs, 30 citizens around a farm", load(s, "crowd40_old")),
                                        ("AFTER: mesh kit, same roster, same camera", load(s, "crowd40_new"))], 1100)

    # 4 aerial distance (170 studs, 50 degrees down), before / after
    sheets["sheet_aerial170"] = stack([("BEFORE: 170 studs, 50 deg down (left: crop enlarged 3.75x, right: actual pixels)", aerial_pair(s, "crowd170_old")),
                                       ("AFTER: same roster, same camera", aerial_pair(s, "crowd170_new"))], 1268)

    # 5 identities side by side + variation
    sheets["sheet_jobs_variation"] = stack([("BEFORE: the eleven identities, current rigs", load(s, "old_jobs")),
                                            ("AFTER: the eleven identities, mesh kit", load(s, "jobs")),
                                            ("AFTER: 36 looks (skin x hair x hair colour x outfit); rows 1-4 idle citizens, row 5 farmers, row 6 builders", load(s, "looks"))], 1200)

    # 6 silhouettes
    rows = [("BEFORE: silhouettes of the eleven identities (current rigs, about 35 studs, seen from the front)", load(s, "old_sil_jobs")),
            ("AFTER: silhouettes, mesh kit, from the front", load(s, "sil_jobs"))]
    if (Path(s) / "sil_jobs_yaw.png").exists():
        rows += [("BEFORE: the same turned 40 degrees", load(s, "old_sil_jobs_yaw")), ("AFTER: the same turned 40 degrees", load(s, "sil_jobs_yaw"))]
    sheets["sheet_silhouettes"] = stack(rows, 1400)

    # 7 kingdoms and rulers from the front and the back, plus capes / packs from four sides
    sheets["sheet_kingdoms_sides"] = stack([("AFTER: soldiers (spear, sword + shield, bow) and rulers in the four kingdom colours, from the front", load(s, "kingdoms")),
                                            ("AFTER: the same from behind", load(s, "kingdoms_back")),
                                            ("AFTER: ruler (cape) from four sides", load(s, "turn_governor")),
                                            ("AFTER: hauler (sack) from four sides", load(s, "turn_hauler"))], 1100)
    for name, im in sheets.items():
        q = save(im, out / f"{name}.jpg", a.max_kb)
        print(f"{name}.jpg {im.width}x{im.height} quality {q} {(out / f'{name}.jpg').stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
