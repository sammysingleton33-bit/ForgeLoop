"""FL-0136 phase 3: blind contact sheets for the fresh image-only D-019 reviewers of the resource node markers (A) and of the mesh dressing (B).

  python3 blender/scripts/envnode_sheets.py --group nodes --renders /tmp/nr1 --out games/game-001/art/reviews/img/d057-env-dressing-r1 --key-out /tmp/key_nodes.json
  python3 blender/scripts/envnode_sheets.py --group dressing --renders /tmp/dr1 --out games/game-001/art/reviews/img/d057-env-dressing-r1 --key-out /tmp/key_dressing.json

Reads RENDERS/<scene>__<mode>__<cam>.png (blender/scripts/envnature_scenes.py) and writes one JPEG (< 250 KB) per sheet, like envnature_sheets.py (SET A / SET B,
nothing in the image says which is which, the column order flips on alternate sheets; the key goes to --key-out and stays out of the committed folder until the
review is recorded). The pairs: nodes = A the meshes as PR 247 ships them ("after"), B the same meshes with the resource markers ("marked"); dressing = A the
part-built world as it is today ("before"), B the world with the imported meshes and the mesh-only dressing ("after"). Plot scenes are cropped to the area the
sheet is about, with the same crop for both sets (1:1 pixels at the 170-stud camera: what the player sees).
"""

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import envnature_sheets as base  # noqa: E402

CAM_LABEL = dict(base.CAM_LABEL)

GROUPS = {
    "nodes": {
        "modes": ("after", "marked"),
        "letters": {"A": "the nature meshes as PR 247 ships them (no marker)", "B": "the same meshes with the resource markers (post and glowing orb)"},
        "sheets": {
            "nodes_east": ("scene", "nodes_east_crimson", "A crimson kingdom's quarry, gold ore and berry bushes seen from the yard; four citizens at the keep. The nodes are the stone, the gold ore and the food bushes",
                           ("aerial170", "gameplay82")),
            "nodes_wood": ("scene", "nodes_wood_crimson", "The same kingdom's four wood nodes: oaks and a pine at the forest edge behind the lumber camp, among the valley's other trees",
                           ("aerial170", "gameplay82")),
            "nodes_east_emerald": ("scene", "nodes_east_emerald", "An emerald kingdom's quarry, gold ore and berry bushes (the plot is turned, the layout is the same)", ("aerial170", "gameplay82")),
            "nodes_lineup": ("scene", "nodes_lineup", "Every kind of resource node close up: three stone quarries, two gold ore nodes, two wood nodes (a tree) and a food node (a berry bush), three citizens in front",
                             ("gameplay82", "close45")),
            "settlement": ("scene", "settlement_crimson", "The crimson kingdom's starting settlement, the whole frame (the nodes stand behind the keep and the farm)", ("aerial170", "gameplay82")),
        },
        "order": ["nodes_east", "nodes_wood", "nodes_east_emerald", "nodes_lineup", "settlement"],
        # fractions (x0, y0, x1, y1) of the frame, 16:9, same for both sets
        "crops": {("nodes_east", "aerial170"): (0.30, 0.30, 0.70, 0.70), ("nodes_wood", "aerial170"): (0.30, 0.30, 0.70, 0.70),
                  ("nodes_east_emerald", "aerial170"): (0.30, 0.30, 0.70, 0.70), ("settlement", "aerial170"): (0.28, 0.10, 0.72, 0.54)},
    },
    "dressing": {
        "modes": ("before", "after"),
        "letters": {"A": "the part-built world as it is today", "B": "the world with the imported meshes and the mesh-only dressing (cabbage variants, field fences, rim cliffs)"},
        "sheets": {
            "farm": ("scene", "farm_crimson", "A crimson kingdom's crop fields behind the keep: wheat, a cabbage field and the farm's surroundings", ("aerial170", "gameplay82")),
            "dressing_lineup": ("scene", "dressing_lineup", "Close up: two field fence segments, three cabbage fields and two rock cliffs (the stand-ins of the part-built world against the meshes)",
                                ("gameplay82", "close45")),
        },
        "order": ["farm", "dressing_lineup"],
        "crops": {("farm", "aerial170"): (0.25, 0.22, 0.75, 0.72)},
    },
}


def panel(im, name, cam, crops, subject):
    box = crops.get((name, cam))
    if box:
        w, h = im.size
        return im.crop((int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h)))
    return im


def make_sheet(group, key, renders, panel_w, flip):
    g = GROUPS[group]
    _, scene, title, cams = g["sheets"][key]
    rows = []
    for cam in cams:
        pair = {m: Image.open(renders / f"{scene}__{m}__{cam}.png").convert("RGB") for m in g["modes"]}
        box = None
        if (key, cam) not in g["crops"] and scene.endswith("lineup"):
            box = base.subject_box(list(pair.values()))
        rows.append((cam, {m: (im.crop(box) if box else panel(im, key, cam, g["crops"], None)) for m, im in pair.items()}))
    pw = panel_w
    ph = int(pw * 9 / 16)
    pad, cap_h, title_h = 10, 26, 54
    W = 2 * pw + 3 * pad
    H = title_h + len(rows) * (cap_h + ph + pad) + pad
    sheet = Image.new("RGB", (W, H), (28, 30, 36))
    d = ImageDraw.Draw(sheet)
    d.text((pad, 8), title, fill=(235, 235, 240), font=base.font(15))
    d.text((pad, 30), "SET A and SET B are two versions of the same scene; same cameras, same placements, same citizens and buildings.", fill=(170, 175, 185), font=base.font(12))
    y = title_h
    letter = {g["modes"][0]: "A", g["modes"][1]: "B"}
    order = (g["modes"][1], g["modes"][0]) if flip else g["modes"]
    for cam, ims in rows:
        cropped = (key, cam) in g["crops"]
        cap = CAM_LABEL[cam].split(":")[0] + ": " + CAM_LABEL[cam].split(":", 1)[1].strip()
        if cropped:
            cap += " (cropped to the area of interest, same crop in both sets)"
        d.text((pad, y + 5), cap, fill=(200, 205, 215), font=base.font(13))
        y += cap_h
        for i, m in enumerate(order):
            im = ims[m].resize((pw, ph), Image.LANCZOS)
            x = pad + i * (pw + pad)
            sheet.paste(im, (x, y))
            d.rectangle((x, y, x + 74, y + 24), fill=(0, 0, 0))
            d.text((x + 8, y + 4), f"SET {letter[m]}", fill=(255, 255, 255), font=base.font(15))
        y += ph + pad
    return sheet


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--group", required=True, choices=sorted(GROUPS))
    ap.add_argument("--renders", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--key-out", required=True)
    ap.add_argument("--sheets", default="")
    ap.add_argument("--panel", type=int, default=760)
    a = ap.parse_args(argv)
    g = GROUPS[a.group]
    renders, out = Path(a.renders), Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    names = [s for s in a.sheets.split(",") if s] or g["order"]
    key = {"group": a.group, "letters": g["letters"], "modes": {"A": g["modes"][0], "B": g["modes"][1]}, "column_order": {}}
    for name in names:
        flip = g["order"].index(name) % 2 == 1  # a different column order on alternate sheets
        sheet = make_sheet(a.group, name, renders, a.panel, flip)
        size, q, dims = base.save_small(sheet, out / f"sheet_{name}.jpg")
        key["column_order"][name] = ["B", "A"] if flip else ["A", "B"]
        print(f"[sheets] {name}: {dims[0]}x{dims[1]} q{q} {size // 1024} KB", flush=True)
    Path(a.key_out).write_text(json.dumps(key, indent=1) + "\n")


if __name__ == "__main__":
    main(sys.argv[1:])
