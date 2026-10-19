"""FL-0136 phase 1: blind review sheets of the S1 / S2 / S3 (+ own style-B wheat) renders of blender/scripts/envkit_compare.py.

  python3 blender/scripts/envkit_sheets.py --renders DIR --out IMG_DIR [--key-out env-mesh-key.json] [--max-kb 245]

One sheet per subject family; every row is one camera (82-stud gameplay, 170-stud aerial at 50 degrees); the columns are the sources with
BLIND letters (a fixed letter per source over all sheets, a different column order per sheet), identical crops for the columns of one row.
The letter -> source key goes to --key-out (never into IMG_DIR, which the fresh reviewer sees). Every sheet is a JPEG <= --max-kb.
"""

import argparse
import json
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

BG = (28, 30, 34)
FG = (236, 236, 236)
LETTER = {"S2": "A", "B": "B", "S1": "C", "S3": "D"}  # fixed over the whole review; the reviewer gets letters only
PANEL_W = 430
GAP = 8
CAM_TITLE = {"gameplay82": "82-stud gameplay camera (44 deg down)", "aerial170": "170-stud aerial camera (50 deg down); the panel is enlarged about 1.5x, the framed inset (when it fits beside the subject) is the subject at actual pixels"}

SHEETS = {
    "sheet_keep_L1": dict(title="Keep, level 1 (footprint 32 x 32 studs), two kingdom hues; four mesh-kit citizens stand in front for scale",
                          rows=[("keep_L1_crimson", "gameplay82", "crimson"), ("keep_L1_crimson", "aerial170", "crimson"),
                                ("keep_L1_emerald", "gameplay82", "emerald"), ("keep_L1_emerald", "aerial170", "emerald")]),
    "sheet_keep_L3": dict(title="Keep, level 3 (footprint 46 x 46 studs), crimson",
                          rows=[("keep_L3_crimson", "gameplay82", "crimson"), ("keep_L3_crimson", "aerial170", "crimson")]),
    "sheet_house": dict(title="House (footprint 20 x 16 studs), crimson",
                        rows=[("house_L1_crimson", "gameplay82", "crimson"), ("house_L1_crimson", "aerial170", "crimson")]),
    "sheet_barracks": dict(title="Barracks (footprint 30 x 20 studs), crimson",
                           rows=[("barracks_L1_crimson", "gameplay82", "crimson"), ("barracks_L1_crimson", "aerial170", "crimson")]),
    "sheet_watchtower": dict(title="Watchtower (footprint 14 x 14 studs), two kingdom hues",
                             rows=[("watchtower_L1_crimson", "gameplay82", "crimson"), ("watchtower_L1_crimson", "aerial170", "crimson"),
                                   ("watchtower_L1_emerald", "gameplay82", "emerald"), ("watchtower_L1_emerald", "aerial170", "emerald")]),
    "sheet_nature": dict(title="A lone oak, a stand of trees and a boulder",
                         rows=[("nature", "gameplay82", ""), ("nature", "aerial170", "")]),
    "sheet_wheat": dict(title="Wheat field, ripe (38 x 28 studs)", sources=("S1", "S3", "B"),
                        rows=[("wheat", "gameplay82", ""), ("wheat", "aerial170", "")]),
    "sheet_stages": dict(title="Construction stages 1 to 3 (right to left on screen)", sources=("S2", "S3"),
                         rows=[("stages", "gameplay82", "")]),
    "sheet_town": dict(title="One settlement per set at the 170-stud aerial camera: keep, barracks, two houses, watchtower, field, trees, boulder",
                       rows=[("town", "aerial170", "")]),
}


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def load_rep(renders, subject, src):
    return json.loads((Path(renders) / f"{subject}__{src}.json").read_text())


def crop_box(renders, subject, cam, sources, img_w, img_h, aspect=4 / 3):
    """One crop for every column of a row: the union of the projected boxes (subject and citizens) plus a margin, 4:3."""
    xs0, ys0, xs1, ys1 = [], [], [], []
    for s in sources:
        b = load_rep(renders, subject, s)["projected"][cam]["all"]
        xs0.append(b[0] * img_w)
        ys0.append(b[1] * img_h)
        xs1.append(b[2] * img_w)
        ys1.append(b[3] * img_h)
    x0, y0, x1, y1 = min(xs0), min(ys0), max(xs1), max(ys1)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    w, h = (x1 - x0) * 1.16, (y1 - y0) * 1.16
    w = max(w, h * aspect, 340 if cam == "aerial170" else 420)
    h = w / aspect
    if h > img_h:  # a subject taller than the frame: show the whole frame height rather than a crop that leaves the image
        h = img_h
        w = h * aspect
    cx = min(max(cx, w / 2), img_w - w / 2)
    cy = min(max(cy, h / 2), img_h - h / 2)
    return (round(cx - w / 2), round(cy - h / 2), round(cx + w / 2), round(cy + h / 2))


def tag(im, text, size=20):
    d = ImageDraw.Draw(im)
    f = font(size)
    w = d.textlength(text, font=f)
    d.rectangle((0, 0, w + 14, size + 10), fill=(0, 0, 0))
    d.text((7, 4), text, fill=(255, 255, 255), font=f)


def panel(renders, subject, src, cam, box):
    im = Image.open(Path(renders) / f"{subject}__{src}__{cam}.png").convert("RGB")
    crop = im.crop(box)
    out = crop.resize((PANEL_W, round(PANEL_W * (box[3] - box[1]) / (box[2] - box[0]))), Image.LANCZOS)
    if cam == "aerial170":  # the subject at actual pixels, so the enlargement cannot flatter or hide anything
        b = load_rep(renders, subject, src)["projected"][cam]["subject"]
        sx0, sy0, sx1, sy1 = (int(b[0] * im.width) - 4, int(b[1] * im.height) - 4, int(b[2] * im.width) + 4, int(b[3] * im.height) + 4)
        if (sx1 - sx0) <= 270 and (sy1 - sy0) <= 270:
            ins = im.crop((sx0, sy0, sx1, sy1))
            fr = Image.new("RGB", (ins.width + 4, ins.height + 4), (255, 255, 255))
            fr.paste(ins, (2, 2))
            # the corner of the panel the subject covers least (the subject's box in panel pixels)
            k = out.width / (box[2] - box[0])
            sb = ((b[0] * im.width - box[0]) * k, (b[1] * im.height - box[1]) * k, (b[2] * im.width - box[0]) * k, (b[3] * im.height - box[1]) * k)
            corners = [(out.width - fr.width - 6, 30), (6, 30), (out.width - fr.width - 6, out.height - fr.height - 6), (6, out.height - fr.height - 6)]

            def overlap(c):
                w = min(c[0] + fr.width, sb[2]) - max(c[0], sb[0])
                h = min(c[1] + fr.height, sb[3]) - max(c[1], sb[1])
                return max(0.0, w) * max(0.0, h)

            best = min(corners, key=overlap)
            if overlap(best) <= 0.0:  # shown only where it does not cover the subject
                out.paste(fr, best)
    return out


def build_sheet(name, spec, renders, order_seed):
    sources = list(spec.get("sources", ("S1", "S2", "S3")))
    random.Random(f"{name}-{order_seed}").shuffle(sources)
    rows = []
    for subject, cam, hue in spec["rows"]:
        probe = Image.open(Path(renders) / f"{subject}__{sources[0]}__{cam}.png")
        box = crop_box(renders, subject, cam, sources, probe.width, probe.height)
        panels = [panel(renders, subject, s, cam, box) for s in sources]
        title = CAM_TITLE[cam] + (f"   [{hue}]" if hue else "")
        rows.append((title, panels))
    ph = max(p.height for _, ps in rows for p in ps)
    width = len(sources) * PANEL_W + (len(sources) + 1) * GAP
    head, rowhead = 34, 26
    height = head + sum(rowhead + ph + GAP for _ in rows) + 6
    sheet = Image.new("RGB", (width, height), BG)
    d = ImageDraw.Draw(sheet)
    d.text((GAP, 8), spec["title"], fill=FG, font=font(18))
    y = head
    for title, panels in rows:
        d.text((GAP, y + 4), title, fill=(200, 205, 215), font=font(16))
        y += rowhead
        for i, (p, s) in enumerate(zip(panels, sources)):
            tag(p, f"SET {LETTER[s]}")
            sheet.paste(p, (GAP + i * (PANEL_W + GAP), y))
        y += ph + GAP
    return sheet, {LETTER[s]: s for s in sources}


def save(im, path, max_kb):
    for q in (90, 85, 80, 74, 68, 60, 52):
        im.save(path, quality=q, optimize=True)
        if Path(path).stat().st_size <= max_kb * 1024:
            return q
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--renders", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--key-out", default="")
    ap.add_argument("--max-kb", type=int, default=245)
    ap.add_argument("--seed", default="r1")
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    key = {"letters": LETTER, "sheets": {}}
    for name, spec in SHEETS.items():
        if a.only and name not in a.only.split(","):
            continue
        try:
            im, order = build_sheet(name, spec, a.renders, a.seed)
        except FileNotFoundError as e:
            print(f"skip {name}: {e}")
            continue
        q = save(im, out / f"{name}.jpg", a.max_kb)
        key["sheets"][name] = {"letters_left_to_right": list(order), "sources": order}
        print(f"{name}.jpg {im.width}x{im.height} q{q} {(out / f'{name}.jpg').stat().st_size // 1024} KB; columns {list(order)}")
    if a.key_out:
        Path(a.key_out).write_text(json.dumps(key, indent=1))


if __name__ == "__main__":
    main()
