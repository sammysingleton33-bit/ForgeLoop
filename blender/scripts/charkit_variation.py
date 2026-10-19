"""Variation evidence for the citizen kit (FL-0135 idle accessory + hair under hats): same looks, old kit files vs new kit files.

  ~/forge-bpy/bin/python -I blender/scripts/charkit_variation.py render --fbx F --rig R --out DIR [--groups idle,farmer,...] [--quick]
  ~/forge-bpy/bin/python -I blender/scripts/charkit_variation.py sheets --before DIR_OLD --after DIR_NEW --out IMG_DIR [--max-kb 250]

`render` writes, per group (a job and a fixed list of looks): head-and-shoulders portraits (the Kit.portrait framing), a row of the looks
at the 40-stud gameplay camera seen from the front and from behind, and the same row at the 170-stud / 50 degree aerial camera with every
citizen turned a different way. `sheets` stacks BEFORE and AFTER of each group into one JPEG per group (<= --max-kb). Blender renders,
not Studio renders.
"""

import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(HERE))
REPO = HERE.parent

BG = (28, 30, 34)
FG = (235, 235, 235)

HAT_LOOKS = [
    {"skin": 2, "hair": 1, "hairColor": 2, "outfit": 1},
    {"skin": 4, "hair": 3, "hairColor": 4, "outfit": 3},
    {"skin": 1, "hair": 4, "hairColor": 5, "outfit": 5},
    {"skin": 5, "hair": 6, "hairColor": 3, "outfit": 2},
]
YAWS = [0, 160, 70, -110, 20, 200, -60, 120, 30, 250]
GROUPS = {"idle": "idle", "farmer": "farmer", "woodcutter": "woodcutter", "miner": "miner", "builder": "builder", "hauler": "hauler",
          "blacksmith": "blacksmith", "merchant": "merchant", "healer": "healer"}


def idle_looks(n=10):
    """Looks of the idle citizen that cover every accessory variant (none, headband, bandana, bindle, rucksack) with different hair."""
    from lib import ckit_resolve

    out, want = [], {}
    for sk in range(1, 7):
        for h in range(1, 7):
            for o in range(1, 7):
                lk = {"skin": sk, "hair": h, "hairColor": 1 + (sk * 3 + h * 5 + o) % 8, "outfit": o}
                key = ckit_resolve.axis_index(ckit_resolve.normalize(lk), "acc", 5)
                if len(want.setdefault(key, [])) < n // 5 and all(w["hair"] != h for w in want[key]):
                    want[key].append(lk)
    for i in range(n // 5):
        for key in range(5):
            if i < len(want.get(key, [])):
                out.append(want[key][i])
    return out


def looks_for(group):
    return idle_looks() if group == "idle" else HAT_LOOKS


def render(a):
    import bpy

    from lib import ckit_rigload, ckit_scene, ckit_view, rig

    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    ckit_view.QUICK = a.quick
    groups = a.groups.split(",") if a.groups else list(GROUPS)
    samples = a.samples or (4 if a.quick else 20)
    manifest = {}
    for g in groups:
        job = GROUPS[g]
        looks = looks_for(g)
        manifest[g] = {"job": job, "looks": looks}
        n = len(looks)
        # --- portraits
        px = 300
        sc = ckit_view.stage(px, px, samples, ground=(150, 148, 140), quick=a.quick)
        cam = rig.add_camera(sc, 70)
        kit = ckit_rigload.Kit(a.fbx, a.rig)
        for i, lk in enumerate(looks):
            names = kit.names_for(job, lk, "crimson")
            objs = kit.spawn(job, lk, "crimson", 0, 0, 0, tag=f"p{i}_", names=names)
            top, half = 0.0, 1.5
            for nme in names:
                p = kit.doc["pieces"][nme]
                if p["joint"] == "Head":
                    top = max(top, p["bbox_center"][1] + p["size"][1] / 2)
                    half = max(half, (abs(p["bbox_center"][0]) + p["size"][0] / 2) * 1.15)
            ckit_scene.portrait(cam, top, half)
            rig.render(sc, out / f"{g}_portrait_{i}.png")
            for o in objs:
                bpy.data.objects.remove(o)
        # --- rows: 40 studs front and back, 170 studs with every citizen turned a different way
        for name, dist, pitch, yaws, size in (("row40_front", 40.0, 14.0, [0] * n, (2400, 900)), ("row40_back", 40.0, 14.0, [180] * n, (2400, 900)),
                                              ("row170", 170.0, 50.0, YAWS[:n], (1280, 720))):
            sc = ckit_view.stage(size[0], size[1], samples, quick=a.quick)
            cam = rig.add_camera(sc, 70)
            kit = ckit_rigload.Kit(a.fbx, a.rig)
            gap = 4.6 if n > 4 else 5.6
            for i, (lk, yaw) in enumerate(zip(looks, yaws)):
                x = ((n - 1) / 2 - i) * gap
                kit.spawn(job, lk, "crimson", x, 0, yaw, tag=f"r{i}_")
            if dist < 100:
                ckit_scene.gameplay(cam, (0, 2.9, 0), dist, pitch, az_deg=0.0, fov=70)
            else:
                ckit_scene.aerial(cam, (0, 3.0, 0), dist, pitch)
            rig.render(sc, out / f"{g}_{name}.png")
        print(f"[variation] {g}: {n} looks -> {out}", flush=True)
    (out / "looks.json").write_text(json.dumps(manifest, indent=1))


def _font(size):
    from PIL import ImageFont

    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def _strip(im, box, width):
    c = im.crop(box)
    return c.resize((width, round(c.height * width / c.width)))


def sheet_for(group, before, after, n):
    from PIL import Image, ImageDraw

    W, half = 1400, 700
    tile = 200
    cols = W // tile
    rows = []
    # portraits: BEFORE and AFTER each as a grid of tiles
    for tag, d in (("BEFORE", before), ("AFTER", after)):
        grid = Image.new("RGB", (W, ((n + cols - 1) // cols) * tile), BG)
        for i in range(n):
            p = Image.open(Path(d) / f"{group}_portrait_{i}.png").convert("RGB").resize((tile, tile), Image.LANCZOS)
            grid.paste(p, ((i % cols) * tile, (i // cols) * tile))
        rows.append((f"{tag}: head and shoulders, the same {n} looks", grid))

    def pair(title_l, title_r, name, box, scale_w):
        ims = []
        for d in (before, after):
            im = Image.open(Path(d) / f"{group}_{name}.png").convert("RGB")
            c = im.crop(box(im))
            ims.append(c.resize((scale_w, round(c.height * scale_w / c.width)), Image.LANCZOS))
        out = Image.new("RGB", (W, max(i.height for i in ims)), BG)
        out.paste(ims[0], (0, 0))
        out.paste(ims[1], (half, 0))
        return out

    nrow = 46 if n > 5 else 24  # studs wide
    px40 = 16.0  # pixels per stud at 40 studs on the 2400 x 900 render (the 56-stud tall frame)
    hw40 = int(nrow * px40 / 2 + 70)
    rows.append(("BEFORE (left) | AFTER (right): 40 studs from the front", pair("", "", "row40_front", lambda im: (im.width // 2 - hw40, im.height // 2 - 130, im.width // 2 + hw40, im.height // 2 + 100), half)))
    rows.append(("BEFORE (left) | AFTER (right): 40 studs from behind", pair("", "", "row40_back", lambda im: (im.width // 2 - hw40, im.height // 2 - 130, im.width // 2 + hw40, im.height // 2 + 100), half)))
    hw170 = int(nrow * 3.0 / 2 + 26)
    rows.append(("BEFORE (left) | AFTER (right): 170 studs, 50 degrees down, every citizen turned a different way (enlarged)", pair("", "", "row170", lambda im: (im.width // 2 - hw170, im.height // 2 - 46, im.width // 2 + hw170, im.height // 2 + 30), half)))
    # the same at actual pixels
    ims = []
    for d in (before, after):
        im = Image.open(Path(d) / f"{group}_row170.png").convert("RGB")
        ims.append(im.crop((im.width // 2 - hw170, im.height // 2 - 46, im.width // 2 + hw170, im.height // 2 + 30)))
    act = Image.new("RGB", (W, ims[0].height), BG)
    act.paste(ims[0], (0, 0))
    act.paste(ims[1], (half, 0))
    rows.append(("BEFORE (left) | AFTER (right): the 170-stud row at actual pixels", act))
    head = 24
    H = sum(im.height + head for _, im in rows) + 8
    sheet = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    y = 0
    for title, im in rows:
        d.text((6, y + 4), title, fill=FG, font=_font(16))
        sheet.paste(im, (0, y + head))
        y += im.height + head
    return sheet


def sheets(a):
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    meta = json.loads((Path(a.after) / "looks.json").read_text())
    for g, info in meta.items():
        im = sheet_for(g, a.before, a.after, len(info["looks"]))
        path = out / f"sheet_variation_{g}.jpg"
        for q in (88, 82, 76, 70, 62, 54):
            im.save(path, quality=q, optimize=True)
            if path.stat().st_size <= a.max_kb * 1024:
                break
        print(f"{path.name} {im.width}x{im.height} {path.stat().st_size // 1024} KB")


def main(argv):
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("render")
    r.add_argument("--fbx", required=True)
    r.add_argument("--rig", required=True)
    r.add_argument("--out", required=True)
    r.add_argument("--groups", default="")
    r.add_argument("--samples", type=int, default=0)
    r.add_argument("--quick", action="store_true")
    s = sub.add_parser("sheets")
    s.add_argument("--before", required=True)
    s.add_argument("--after", required=True)
    s.add_argument("--out", required=True)
    s.add_argument("--max-kb", type=int, default=250)
    a = ap.parse_args(argv[argv.index("--") + 1:] if "--" in argv else argv[1:])
    return render(a) if a.cmd == "render" else sheets(a)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
