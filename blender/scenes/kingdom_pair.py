"""Kingdom colour separation check (FORGE-00 calibration request): the crimson and gold kingdoms side by side,
with wheat and hay next to the gold to prove gold never reads as straw, and an emerald tower among oaks to prove
the kingdom green stands apart from foliage. Rendered at the near gameplay distance and from the aerial
management camera (40-220 studs, G13.6).

Run:  ~/forge-bpy/bin/python blender/scenes/kingdom_pair.py [--quick] [--shots near,aerial]
Outputs: blender/renders/scenes/kingdom_pair_<shot>.png and blender/previews/scene_kingdom_pair_<shot>.jpg
"""

import argparse
import math
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
for p in (HERE, HERE / "scenes"):
    if str(p) not in sys.path:
        sys.path.insert(0, str(p))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import village  # noqa: E402
from lib import contact, rig  # noqa: E402

GRASS = (0.67 * 0.2, 0.66 * 0.62, 0.23 * 0.4)  # linear, close to palette grass 67A93A under the preview rig

# (generator, variant index, kingdom, x, y, rotation deg); front faces -Y (towards the camera)
LAYOUT = [
    # crimson cluster (left)
    ("castle_keep", 0, "red", -70, 40, 0),
    ("castle_tower", 0, "red", -112, 18, 0),
    ("castle_tower", 1, "red", -28, 18, 0),
    ("building_barracks", 0, "red", -70, -30, 0),
    ("prop_banner", 0, "red", -46, -52, 0),
    # gold cluster (right)
    ("castle_keep", 0, "yellow", 70, 40, 0),
    ("castle_tower", 0, "yellow", 28, 18, 0),
    ("castle_tower", 7, "yellow", 112, 18, 0),
    ("building_barracks", 0, "yellow", 70, -30, 0),
    ("prop_banner", 0, "yellow", 46, -52, 0),
    # straw next to the gold: wheat field, haystacks, a thatch cottage
    ("farm_field", 0, None, 128, -46, 0),
    ("farm_haystack", 0, None, 104, -70, 0),
    ("farm_haystack", 2, None, 150, -74, 0),
    ("house_cottage", 0, None, 152, -10, -20),
    # emerald tower among oaks (far right)
    ("castle_tower", 0, "green", 205, 30, 0),
    ("tree_oak", 0, None, 186, 6, 0),
    ("tree_oak", 2, None, 228, 8, 40),
    ("tree_oak", 6, None, 214, 62, 90),
    ("tree_pine", 0, None, 188, 66, 0),
]

SHOTS = {  # camera location, target, vertical fov (deg)
    "near": (Vector((10, -125, 26)), Vector((20, 10, 18)), 70),
    "aerial": (Vector((50, -190, 170)), Vector((50, 0, 0)), 55),
}


class Flat:
    """Flat ground for Library.place (no pads needed)."""

    def pad(self, x, y, r):
        return 0.0

    def height(self, x, y):
        return 0.0


def ground():
    me = bpy.data.meshes.new("ground")
    s = 1200
    me.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
    ob = bpy.data.objects.new("ground", me)
    bpy.context.scene.collection.objects.link(ob)
    m = bpy.data.materials.new("M_terrain")
    try:
        m.use_nodes = True
    except AttributeError:
        pass
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*GRASS, 1)
    bsdf.inputs["Roughness"].default_value = 0.95
    ob.data.materials.append(m)
    return ob


def main(argv):
    argv = argv[argv.index("--") + 1:] if "--" in argv else argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--shots", default="near,aerial")
    args = ap.parse_args(argv)
    t0 = time.time()
    rig.reset_scene()
    sc = bpy.context.scene
    w, h = (960, 540) if args.quick else (1600, 900)
    rig.setup_render(sc, w, h, 16 if args.quick else 48)
    rig.setup_world(sc, sky_top=(0.16, 0.42, 0.88), sky_horizon=(0.70, 0.82, 0.95), fill_strength=0.7)
    rig.add_sun(sc, elevation_deg=40, azimuth_deg=-50, strength=4.6)
    ground()
    lib = village.Library()
    T = Flat()
    placed = 0
    for gen, idx, kingdom, x, y, rot in LAYOUT:
        if lib.place(T, gen, idx, x, y, rot, kingdom=kingdom, pad=False):
            placed += 1
    for m in bpy.data.materials:
        if m.name in ("M_terrain", rig.PREVIEW_MATERIAL):
            village.add_haze(m)
    print(f"placed {placed}/{len(LAYOUT)}; missing {sorted(lib.missing)}; broken {lib.broken}; "
          f"build {time.time() - t0:.0f}s", flush=True)
    cam = rig.add_camera(sc, 40)
    out_dir = HERE / "renders" / "scenes"
    out_dir.mkdir(parents=True, exist_ok=True)
    for name in [s for s in args.shots.split(",") if s]:
        loc, tgt, fov = SHOTS[name]
        cam.location = loc
        cam.data.sensor_fit = "VERTICAL"
        cam.data.angle_y = math.radians(fov)
        rig.aim(cam, tgt)
        path = out_dir / f"kingdom_pair_{name}.png"
        rig.render(sc, path)
        if contact.available():
            from PIL import Image

            res = contact.save_jpeg_under(Image.open(path), HERE / "previews" / f"scene_kingdom_pair_{name}.jpg")
            print(f"preview {res[0].name}: {res[1]} bytes", flush=True)


if __name__ == "__main__":
    main(sys.argv)
