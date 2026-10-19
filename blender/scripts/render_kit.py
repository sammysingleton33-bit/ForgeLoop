"""Render Kit (part-built Roblox architecture) contact sheets from a Lune dump (FL-0054 preview path).

  FORGE_KIT_DUMP=/tmp/kit.json lune run roblox/tests/harness/run.luau \
      --project games/game-001/default.project.json --specs games/game-001/tests/world KitDump
  ~/forge-bpy/bin/python blender/scripts/render_kit.py --json /tmp/kit.json [--groups building_house,stages] [--quick]

Writes blender/previews/kit_<group>.jpg (<= 250 KB) and raw renders to blender/renders/kit/.
The look is an approximation of Studio (no Roblox material textures, Cycles lighting); the Studio
screenshot from the user decides the final look (D-026 calibration).
"""

import argparse
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(HERE))

import bpy  # noqa: E402

from lib import contact, kitparts, rig  # noqa: E402


def parse(argv):
    argv = argv[argv.index("--") + 1:] if "--" in argv else argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", required=True)
    ap.add_argument("--groups", default="")
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--cols", type=int, default=3)
    return ap.parse_args(argv)


def bounds(objs):
    return rig.world_bounds(objs)


def render_group(name, models, args, out_dir):
    rig.reset_scene()
    kitparts.reset_cache()
    px = 300 if args.quick else 420
    samples = 12 if args.quick else 28
    sc = rig.standard_stage(px, px, samples, ground_rgb=(0.40, 0.47, 0.33))
    col = sc.collection
    built = []
    for m in models:
        objs = kitparts.build_model(m, col)
        built.append(objs)
    cam = rig.add_camera(sc, 30)
    tiles = []
    for i, (m, objs) in enumerate(zip(models, built)):
        for j, others in enumerate(built):
            for o in others:
                o.hide_render = j != i
        mn, mx = bounds(objs)
        h = mx.z - mn.z
        proxy = rig.add_character_proxy(sc, mx.x + 2.0 + 0.04 * h, mn.y + (mx.y - mn.y) * 0.65 + 0.8, 0, 0.4)
        rig.frame(sc, cam, objs + [proxy], 35, 22)
        sc.render.resolution_x = sc.render.resolution_y = px
        path = out_dir / f"{name}_{i:02d}.png"
        rig.render(sc, path)
        bpy.data.objects.remove(proxy)
        nparts = len(m["parts"])
        tiles.append((path, m.get("label", m["name"]), f"{nparts} parts  {mx.x - mn.x:.0f}x{mx.y - mn.y:.0f}x{h:.0f} studs"))
    # gameplay strip: everything in a row, Roblox default FOV
    for objs in built:
        for o in objs:
            o.hide_render = False
    widths = []
    for objs in built:
        mn, mx = bounds(objs)
        widths.append((mn, mx))
    gap = 6.0
    total = sum(mx.x - mn.x for mn, mx in widths) + gap * (len(built) - 1)
    x = -total / 2
    for objs, (mn, mx) in zip(built, widths):
        dx = x - mn.x
        dy = -(mn.y + mx.y) / 2
        for o in objs:
            o.location.x += dx
            o.location.y += dy
        x += (mx.x - mn.x) + gap
    depth = max(mx.y - mn.y for mn, mx in widths)
    rig.add_character_proxy(sc, 0, -depth / 2 - 5, 0, 0)
    half_h = math.tan(math.radians(rig.ROBLOX_FOV_DEG) / 2) * 16 / 9
    dist = min(90.0, max(40.0, (total / 2 + 6) / half_h + depth / 2))
    tallest = max(mx.z for mn, mx in widths)
    rig.gameplay_camera(sc, cam, (0, 0, min(tallest * 0.4, 25)), dist, 14, 0)
    sc.render.resolution_x, sc.render.resolution_y = (640, 360) if args.quick else (1280, 720)
    strip = out_dir / f"{name}_gameplay.png"
    rig.render(sc, strip)
    if not contact.available():
        return None
    res = contact.sheet(f"Kit (part-built) - {name} - {len(models)} models - FORGE-02", tiles,
                        (strip, f"gameplay view ~{dist:.0f} studs, Roblox 70 deg FOV"), cols=args.cols,
                        tile_px=300 if args.quick else 360, out=HERE / "previews" / f"kit_{name}.jpg",
                        subtitle="Roblox primitive parts rebuilt in Blender (approximation of Studio; no material textures)")
    return res


def main(argv):
    args = parse(argv)
    data = json.loads(Path(args.json).read_text())
    groups = data["groups"]
    wanted = [g for g in args.groups.split(",") if g] or sorted(groups)
    out_dir = HERE / "renders" / "kit"
    out_dir.mkdir(parents=True, exist_ok=True)
    for g in wanted:
        if g not in groups:
            print(f"skip unknown group {g}")
            continue
        res = render_group(g, groups[g], args, out_dir)
        print(f"[kit] {g}: {len(groups[g])} models -> {res[0] if res else 'renders only'}"
              + (f" ({res[1]} bytes)" if res else ""), flush=True)


if __name__ == "__main__":
    main(sys.argv)
