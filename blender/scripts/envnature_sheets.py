"""FL-0136 phase 2: contact sheets for the fresh image-only D-019 reviewer (blind: SET A / SET B, a different column order per sheet, nothing in the image says which is which).

  python3 blender/scripts/envnature_sheets.py --renders /tmp/env/r1 --out games/game-001/art/reviews/img/d057-env-nature-r1 --key-out /tmp/key.json [--sheets settlement_crimson,crops]

Reads RENDERS/<scene>__<before|after>__<cam>.png (blender/scripts/envnature_scenes.py) and writes one JPEG (< 250 KB) per sheet: a title, then one row per camera
with the two sets side by side. The sets are a fixed letter per source over all sheets (A = the part-built Kit stand-ins, B = the style-B meshes); the key is written to --key-out and
stays out of the committed image folder until the review is recorded. Lineups are cropped to the subject with the same crop for both sets.
"""

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

CAM_LABEL = {"gameplay82": "gameplay camera: 82 studs, 44 degrees down (70 degree vertical field of view)",
             "aerial170": "aerial camera: 170 studs, 50 degrees down",
             "close45": "close view: 45 studs, 30 degrees down"}
SHEETS = {
    "settlement_crimson": ("A crimson kingdom's starting settlement (keep, houses, farm, storehouse, lumber camp, quarry) with the valley's trees, bushes, rocks, flowers, fields and resource nodes around it; "
                           "four citizens in the yard", ("gameplay82", "aerial170")),
    "settlement_emerald": ("An emerald kingdom's starting settlement, same layout rotated by the plot, with its surroundings and four citizens", ("gameplay82", "aerial170")),
    "forest_broadleaf": ("A broadleaf forest stand (oaks, birches, bushes, rocks) in the valley's real placement (the untrimmed density-1.0 plan)", ("gameplay82", "aerial170")),
    "forest_pine": ("A pine and oak forest stand in the valley's real placement (the untrimmed density-1.0 plan)", ("gameplay82", "aerial170")),
    "trees_lineup": ("Every tree variant the world places: 8 oaks, 6 pines, 6 birches (three citizens in front)", ("gameplay82",)),
    "trees_close": ("Four trees up close", ("close45",)),
    "bushes_lineup": ("The 8 bushes and 6 flower tufts the world places (berry bushes: 03, 06; white blossom: 02, 05, 08)", ("gameplay82", "close45")),
    "rocks_lineup": ("The nine boulders (small, medium, large; three variants each)", ("gameplay82", "close45")),
    "nodes_lineup": ("Resource nodes: three stone quarries, two gold ore nodes, wood nodes (trees) and a food node (berry bush)", ("gameplay82", "close45")),
    "crops": ("Crop fields (38 x 28 studs): wheat, wheat, cabbage and a haystack", ("gameplay82", "aerial170")),
    "wheat_stages": ("One wheat field in three growth stages: shoots, green wheat, ripe", ("gameplay82",)),
}
ORDER = ["settlement_crimson", "settlement_emerald", "forest_broadleaf", "forest_pine", "trees_lineup", "trees_close", "bushes_lineup", "rocks_lineup", "nodes_lineup", "crops",
         "wheat_stages"]
LETTER = {"before": "A", "after": "B"}  # fixed over all sheets; the key is withheld until the review is recorded
GROUND = None


def font(size):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/dejavu/DejaVuSans.ttf"):
        if Path(p).exists():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def subject_box(images, margin=0.04):
    """Union bounding box of the pixels that differ from the ground colour in any image, grown to the 16:9 frame (centred), or None for a full frame."""
    x0, y0, x1, y1 = 10 ** 9, 10 ** 9, -1, -1
    for im in images:
        w, h = im.size
        px = im.convert("RGB").resize((w // 4, h // 4)).load()
        ww, hh = w // 4, h // 4
        samples = sorted(px[x, y] for x in range(0, ww, 8) for y in range(int(hh * 0.45), hh, 8))
        ground = samples[len(samples) // 2]
        for y in range(int(hh * 0.30), hh):
            for x in range(ww):
                c = px[x, y]
                if max(abs(c[0] - ground[0]), abs(c[1] - ground[1]), abs(c[2] - ground[2])) > 46 or (c[1] < ground[1] - 50):
                    x0, y0, x1, y1 = min(x0, x * 4), min(y0, y * 4), max(x1, x * 4), max(y1, y * 4)
    if x1 < 0:
        return None
    w, h = images[0].size
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    bw, bh = (x1 - x0) * (1 + 2 * margin) + 40, (y1 - y0) * (1 + 2 * margin) + 40
    if bw / bh < 16 / 9:
        bw = bh * 16 / 9
    else:
        bh = bw * 9 / 16
    bw, bh = min(bw, w), min(bh, h)
    left, top = min(max(0, cx - bw / 2), w - bw), min(max(0, cy - bh / 2), h - bh)
    return (int(left), int(top), int(left + bw), int(top + bh))


def cam_caption(name, cam, renders):
    """The camera caption; a lineup that did not fit the frame at the camera's own distance says so (the scene json records it)."""
    cap = CAM_LABEL[cam]
    try:
        c = json.loads((renders / f"{name}.json").read_text()).get("cams", {}).get(cam)
    except (OSError, ValueError):
        c = None
    if c and c.get("widened"):
        cap = f"{cap.split(':')[0]}: widened to {c['dist']:.0f} studs, {c['pitch']:.0f} degrees down, so the whole row fits the frame"
    return cap


def make_sheet(name, renders, panel_w, flip):
    title, cams = SHEETS[name]
    rows = []
    for cam in cams:
        pair = {m: Image.open(renders / f"{name}__{m}__{cam}.png").convert("RGB") for m in ("before", "after")}
        box = None
        if not name.startswith(("settlement", "forest")):
            box = subject_box(list(pair.values()))
        rows.append((cam, {m: (im.crop(box) if box else im) for m, im in pair.items()}))
    panel_h = int(panel_w * 9 / 16)
    pad, cap_h, title_h = 10, 26, 54
    W = 2 * panel_w + 3 * pad
    H = title_h + len(rows) * (cap_h + panel_h + pad) + pad
    sheet = Image.new("RGB", (W, H), (28, 30, 36))
    d = ImageDraw.Draw(sheet)
    d.text((pad, 8), title, fill=(235, 235, 240), font=font(15))
    d.text((pad, 30), "SET A and SET B are two different ways of drawing the same scene; same cameras, same placements, same citizens and buildings.", fill=(170, 175, 185), font=font(12))
    y = title_h
    order = ("after", "before") if flip else ("before", "after")
    for cam, ims in rows:
        d.text((pad, y + 5), cam_caption(name, cam, renders), fill=(200, 205, 215), font=font(13))
        y += cap_h
        for i, m in enumerate(order):
            im = ims[m].resize((panel_w, panel_h), Image.LANCZOS)
            x = pad + i * (panel_w + pad)
            sheet.paste(im, (x, y))
            d.rectangle((x, y, x + 74, y + 24), fill=(0, 0, 0))
            d.text((x + 8, y + 4), f"SET {LETTER[m]}", fill=(255, 255, 255), font=font(15))
        y += panel_h + pad
    return sheet


def save_small(sheet, path, limit=245 * 1024):
    """JPEG under the 250 KB commit limit: lower the quality first, then the size."""
    scale = 1.0
    while True:
        im = sheet if scale == 1.0 else sheet.resize((int(sheet.width * scale), int(sheet.height * scale)), Image.LANCZOS)
        for q in (84, 78, 72, 66, 60, 54):
            im.save(path, quality=q, optimize=True)
            if Path(path).stat().st_size <= limit:
                return Path(path).stat().st_size, q, im.size
        scale *= 0.9


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--renders", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--key-out", required=True)
    ap.add_argument("--sheets", default="")
    ap.add_argument("--panel", type=int, default=760)
    a = ap.parse_args(argv)
    renders, out = Path(a.renders), Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    names = [s for s in a.sheets.split(",") if s] or ORDER
    key = {"letters": {"A": "part-built Kit stand-ins (before)", "B": "style-B meshes from games/game-001/art/env_kit (after)"}, "column_order": {}}
    for n, name in enumerate(names):
        flip = (ORDER.index(name) % 2 == 1)  # a different column order on alternate sheets
        sheet = make_sheet(name, renders, a.panel, flip)
        size, q, dims = save_small(sheet, out / f"sheet_{name}.jpg")
        key["column_order"][name] = ["B", "A"] if flip else ["A", "B"]
        print(f"[sheets] {name}: {dims[0]}x{dims[1]} q{q} {size // 1024} KB", flush=True)
    Path(a.key_out).write_text(json.dumps(key, indent=1) + "\n")


if __name__ == "__main__":
    main(sys.argv[1:])
