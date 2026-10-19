"""Cohesion vignette: a red-kingdom (Emberhold) village with farms, forest, river, bridge and
castle, built from the generators exactly as they are exported (same params as the manifest).

Run:  ~/forge-bpy/bin/python blender/scenes/village.py [--quick] [--shots establish,street,castle]
Desktop: blender -b -P blender/scenes/village.py -- --quick
Outputs: blender/renders/scenes/village_<shot>.png and blender/previews/scene_village_<shot>.jpg

The ground is a stand-in for Roblox Terrain (grass/ground/water materials), not an exported asset.
Generators that do not exist yet are skipped and listed.
"""

import argparse
import importlib
import math
import random
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
from mathutils import noise as mnoise  # noqa: E402

from lib import asset, contact, rig  # noqa: E402

KINGDOM = "red"
WATER_Z = -1.6
SEED = 7  # must match build.py default so placed assets equal manifest assets


def smoothstep(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def dist_to_polyline(p, pts):
    best = 1e9
    for a, b in zip(pts, pts[1:]):
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / max(1e-9, ab.length_squared)))
        best = min(best, (p - (a + ab * t)).length)
    return best


# ------------------------------------------------------------------ layout (studs; camera looks north +Y)
RIVER = [Vector(v) for v in ((-420, 150), (-250, 95), (-110, 70), (0, 66), (120, 80), (260, 120), (430, 140))]
ROAD_MAIN = [Vector(v) for v in ((-10, -330), (-6, -150), (0, -40), (4, 30), (2, 66), (0, 110), (-6, 170), (0, 228))]
ROAD_FARM = [Vector(v) for v in ((-4, -40), (-70, -48), (-150, -30), (-230, -10))]
ROAD_FOREST = [Vector(v) for v in ((4, -10), (80, -4), (150, 20), (215, 40))]
SQUARE = (Vector((0, -40)), 26.0)  # village square: centre, radius
CASTLE = Vector((0, 275))


class Terrain:
    def __init__(self, seed=3):
        self.seed = seed
        self.pads = []  # (centre Vector2, radius, height)

    def base(self, x, y):
        p = Vector((x, y))
        h = 7.0 * mnoise.noise((x / 160.0, y / 160.0, self.seed)) + 2.5 * mnoise.noise((x / 55.0, y / 55.0, self.seed + 9))
        h += 30.0 * math.exp(-((p - CASTLE).length_squared) / (2 * 85.0 ** 2))  # castle hill
        h += 14.0 * math.exp(-((x - 260) ** 2 + (y - 230) ** 2) / (2 * 90.0 ** 2))  # forest ridge
        h *= 0.35 + 0.65 * smoothstep(0, 140, (p - SQUARE[0]).length)  # village plain is flatter
        h = max(h, WATER_Z + 1.6 + 1.2 * mnoise.noise((x / 70.0, y / 70.0, self.seed + 4)))  # no stray lakes
        d = dist_to_polyline(p, RIVER)
        carve = 1.0 - smoothstep(13.0, 34.0, d)
        h = h * (1 - carve) + (WATER_Z - 3.2) * carve
        r = min(dist_to_polyline(p, ROAD_MAIN), dist_to_polyline(p, ROAD_FARM), dist_to_polyline(p, ROAD_FOREST))
        h -= 0.25 * (1 - smoothstep(5.0, 8.0, r))
        return h

    def height(self, x, y):
        h = self.base(x, y)
        p = Vector((x, y))
        for c, rad, hz in self.pads:
            w = 1.0 - smoothstep(rad, rad + 14.0, (p - c).length)
            h = h * (1 - w) + hz * w
        return h

    def pad(self, x, y, radius):
        hz = self.height(x, y)
        self.pads.append((Vector((x, y)), radius, hz))
        return hz

    def colour(self, x, y, h, slope):
        p = Vector((x, y))
        n1 = mnoise.noise((x / 40.0, y / 40.0, 5.0))
        n2 = mnoise.noise((x / 9.0, y / 9.0, 11.0))
        grass_a, grass_b, grass_c = (0.30, 0.58, 0.20), (0.42, 0.66, 0.24), (0.55, 0.72, 0.30)
        t = 0.5 + 0.5 * n1
        c = [grass_a[i] * (1 - t) + grass_b[i] * t for i in range(3)]
        if n2 > 0.35:
            c = [c[i] * 0.7 + grass_c[i] * 0.3 for i in range(3)]
        r = min(dist_to_polyline(p, ROAD_MAIN), dist_to_polyline(p, ROAD_FARM), dist_to_polyline(p, ROAD_FOREST))
        sq = (p - SQUARE[0]).length - SQUARE[1]
        road = max(1.0 - smoothstep(5.5, 7.5, r), 1.0 - smoothstep(0.0, 3.0, sq))
        dirt = (0.70, 0.56, 0.38) if n2 < 0.2 else (0.64, 0.50, 0.33)
        c = [c[i] * (1 - road) + dirt[i] * road for i in range(3)]
        d = dist_to_polyline(p, RIVER)
        bank = (1.0 - smoothstep(18.0, 30.0, d)) * (1 - road)
        mud = (0.55, 0.47, 0.34)
        c = [c[i] * (1 - bank) + mud[i] * bank for i in range(3)]
        rock = smoothstep(0.55, 0.85, slope)
        stone = (0.52, 0.50, 0.47)
        c = [c[i] * (1 - rock) + stone[i] * rock for i in range(3)]
        return c

    def build_mesh(self, x0=-700, x1=700, y0=-420, y1=760, step=3.0):
        nx = int((x1 - x0) / step) + 1
        ny = int((y1 - y0) / step) + 1
        hs = [[self.height(x0 + i * step, y0 + j * step) for i in range(nx)] for j in range(ny)]
        verts, faces, cols = [], [], []
        for j in range(ny):
            for i in range(nx):
                verts.append((x0 + i * step, y0 + j * step, hs[j][i]))
        for j in range(ny - 1):
            for i in range(nx - 1):
                a = j * nx + i
                faces.append((a, a + 1, a + nx + 1, a + nx))
        me = bpy.data.meshes.new("terrain")
        me.from_pydata(verts, [], faces)
        attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        for j in range(ny):
            for i in range(nx):
                h = hs[j][i]
                gx = hs[j][min(nx - 1, i + 1)] - hs[j][max(0, i - 1)]
                gy = hs[min(ny - 1, j + 1)][i] - hs[max(0, j - 1)][i]
                slope = min(1.0, math.hypot(gx, gy) / (2 * step) / 1.2)
                c = self.colour(x0 + i * step, y0 + j * step, h, slope)
                attr.data[j * nx + i].color = (*c, 1.0)
        for poly in me.polygons:
            poly.use_smooth = True
        ob = bpy.data.objects.new("terrain", me)
        bpy.context.scene.collection.objects.link(ob)
        m = bpy.data.materials.new("M_terrain")
        try:
            m.use_nodes = True
        except AttributeError:
            pass
        nt = m.node_tree
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        ca = nt.nodes.new("ShaderNodeVertexColor")
        ca.layer_name = "Col"
        nt.links.new(ca.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.95
        ob.data.materials.append(m)
        return ob


def add_far_hills(seed=21):
    """Ring of soft hills beyond the play area so the horizon never shows the world edge."""
    verts, faces, cols = [], [], []
    seg, rings = 160, 6
    for j in range(rings):
        r = 760 + j * 260
        for i in range(seg):
            a = math.tau * i / seg
            x, y = math.cos(a) * r, math.sin(a) * r + 150
            hh = (40 + 90 * (0.5 + 0.5 * mnoise.noise((math.cos(a) * 3, math.sin(a) * 3, seed + j * 0.3)))) * min(1, j / 2)
            verts.append((x, y, hh - 6))
            t = j / (rings - 1)
            cols.append((0.34 * (1 - t) + 0.62 * t, 0.56 * (1 - t) + 0.74 * t, 0.30 * (1 - t) + 0.88 * t))
    for j in range(rings - 1):
        for i in range(seg):
            a, b = j * seg + i, j * seg + (i + 1) % seg
            faces.append((a, b, b + seg, a + seg))
    me = bpy.data.meshes.new("far_hills")
    me.from_pydata(verts, [], faces)
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for i, c in enumerate(cols):
        attr.data[i].color = (*c, 1.0)
    for poly in me.polygons:
        poly.use_smooth = True
    ob = bpy.data.objects.new("far_hills", me)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(bpy.data.materials["M_terrain"])
    return ob


def add_haze(mat, colour=(0.66, 0.78, 0.93), start=320.0, end=2000.0, amount=0.38):
    """Fake aerial perspective: mix the surface towards the sky colour with camera distance."""
    nt = mat.node_tree
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL" and n.is_active_output)
    link = out.inputs["Surface"].links[0]
    src = link.from_socket
    cam = nt.nodes.new("ShaderNodeCameraData")
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = start
    mr.inputs["From Max"].default_value = end
    mr.inputs["To Max"].default_value = amount
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*colour, 1)
    em.inputs["Strength"].default_value = 1.0
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(cam.outputs["View Distance"], mr.inputs["Value"])
    nt.links.new(mr.outputs["Result"], mix.inputs["Fac"])
    nt.links.new(src, mix.inputs[1])
    nt.links.new(em.outputs["Emission"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])


def add_water(z=WATER_Z):
    me = bpy.data.meshes.new("water")
    s = 760
    me.from_pydata([(-s, -s + 160, z), (s, -s + 160, z), (s, s + 160, z), (-s, s + 160, z)], [], [(0, 1, 2, 3)])
    ob = bpy.data.objects.new("water", me)
    bpy.context.scene.collection.objects.link(ob)
    m = bpy.data.materials.new("M_water")
    try:
        m.use_nodes = True
    except AttributeError:
        pass
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0.10, 0.36, 0.62, 1)
    bsdf.inputs["Roughness"].default_value = 0.12
    ob.data.materials.append(m)
    return ob


# ------------------------------------------------------------------ assets

class Library:
    """Builds each (generator, variant) once; placements are linked duplicates."""

    def __init__(self):
        self.cache = {}
        self.missing = set()
        self.broken = {}
        self.count = 0

    def get(self, gen_name, index, kingdom=None):
        key = (gen_name, index, kingdom)
        if key in self.cache:
            return self.cache[key]
        try:
            gen = importlib.import_module(f"generators.{gen_name}")
        except Exception:
            self.missing.add(gen_name)
            self.cache[key] = None
            return None
        n = max(index + 1, getattr(gen, "DEFAULT_VARIANTS", 6))
        plist = gen.variants(n, SEED)
        if kingdom:
            # choose the first variant of this kingdom at or after `index` (keeps manifest params)
            cands = [i for i in range(len(plist)) if plist[i].get("kingdom") == kingdom]
            later = [i for i in cands if i >= index]
            if later or cands:
                index = (later or cands)[0]
        index = min(index, len(plist) - 1)
        p = plist[index]
        aid = gen.asset_id(index, p) if hasattr(gen, "asset_id") else f"{gen.NAME}_{index + 1:02d}"
        b = asset.Builder(aid, int(p.get("seed", SEED * 1000 + index)))
        try:
            gen.build(b, p)
            ob = b.finalize(f"src_{aid}")
        except Exception as exc:  # a generator mid-development must not kill the scene
            self.broken[gen_name] = f"{type(exc).__name__}: {exc}"
            self.cache[key] = None
            return None
        rig.use_preview_material(ob)
        ob.hide_render = True
        ob.hide_viewport = True
        mn, mx = rig.world_bounds([ob])
        self.cache[key] = (ob, max(mx.x - mn.x, mx.y - mn.y) / 2)
        return self.cache[key]

    def place(self, terrain, gen_name, index, x, y, rot_deg=0.0, kingdom=None, pad=True, scale=1.0, sink=0.0):
        got = self.get(gen_name, index, kingdom)
        if not got:
            return None
        src, radius = got
        z = terrain.pad(x, y, radius * 0.9 * scale) if pad else terrain.height(x, y)
        ob = bpy.data.objects.new(f"{src.name}_{self.count}", src.data)
        self.count += 1
        bpy.context.scene.collection.objects.link(ob)
        ob.location = (x, y, z - sink)
        ob.rotation_euler = (0, 0, math.radians(rot_deg))
        ob.scale = (scale, scale, scale)
        return ob


def face(x, y, tx, ty):
    """Rotation (deg) so an asset whose front is -Y faces the point (tx, ty)."""
    return math.degrees(math.atan2(-(tx - x), (ty - y))) + 180.0


def populate(lib, T, rng):
    placed = []

    def P(*a, **k):
        o = lib.place(T, *a, **k)
        if o:
            placed.append(o)
        return o

    sq, sr = SQUARE
    # --- castle on the hill: keep, gatehouse on the road, walls + towers in an arc facing the village
    cz = CASTLE
    P("castle_keep", 0, cz.x, cz.y + 30, 0, KINGDOM)
    gate_y = cz.y - 48
    P("castle_gatehouse", 0, cz.x, gate_y, 0, KINGDOM)
    for side in (-1, 1):
        for k in range(1, 3):
            P("castle_wall", k % 2, cz.x + side * (16 + 32 * (k - 1) + 16), gate_y, 0, KINGDOM)
        P("castle_tower", side > 0, cz.x + side * 80, gate_y, 0, KINGDOM)
        for k in range(2):
            wx = cz.x + side * 80
            P("castle_wall", k, wx, gate_y + 16 + 32 * k + 16, 90, KINGDOM)
        P("castle_tower", 0, cz.x + side * 80, gate_y + 80, 0, KINGDOM)
    P("building_barracks", 0, cz.x + 62, gate_y - 44, face(cz.x + 62, gate_y - 44, 0, gate_y - 60), KINGDOM)
    P("siege_catapult", 0, cz.x + 34, gate_y - 70, 200, KINGDOM)
    for k, (bx, by) in enumerate(((-12, gate_y - 22), (12, gate_y - 22), (-8, 160), (8, 160))):
        P("prop_banner", k % 2, bx, by, 0, KINGDOM)

    # --- bridge over the river on the main road
    P("bridge_stone", 0, 2, 70, 0, pad=False, sink=0.0)

    # --- village square with well, market stalls, tavern, smithy, houses along the roads
    P("prop_well", 0, sq.x + 3, sq.y + 2, 20)
    for k, (ox, oy, rr) in enumerate(((-16, 12, 160), (15, 14, 200), (-18, -12, 110), (17, -14, 250))):
        P("building_market", k, sq.x + ox, sq.y + oy, rr, KINGDOM if k % 2 == 0 else None)
    P("building_tavern", 0, sq.x + 44, sq.y + 6, face(sq.x + 44, sq.y + 6, sq.x, sq.y), KINGDOM)
    P("building_smithy", 0, sq.x - 46, sq.y + 30, face(sq.x - 46, sq.y + 30, sq.x, sq.y + 20), KINGDOM)
    P("building_storehouse", 0, sq.x - 48, sq.y - 20, face(sq.x - 48, sq.y - 20, sq.x, sq.y), KINGDOM)
    P("building_workshop", 0, 70, 2, face(70, 2, 80, -30), KINGDOM)
    houses = [(-30, -84), (32, -88), (-34, -128), (30, -132), (-36, -176), (34, -180), (38, -40), (-44, 16),
              (44, 34), (-88, -60), (-120, -14), (110, -36), (150, 0), (-30, 30)]
    for k, (hx, hy) in enumerate(houses):
        tx, ty = (hx * 0.2, hy) if abs(hx) < 60 else (hx, hy + 40)
        kingdom = KINGDOM if k % 3 != 2 else None
        P("house_cottage", k % 6, hx, hy, face(hx, hy, tx, ty) + rng.uniform(-6, 6), kingdom)

    # --- farms west of the village
    fields = [(-150, -90, 0), (-150, -125, 2), (-196, -90, 1), (-196, -125, 0), (-240, -60, 3), (-110, -128, 4)]
    for k, (fx, fy, var) in enumerate(fields):
        P("farm_field", var, fx, fy, 0 if k % 2 == 0 else 90)
    for k in range(6):
        P("farm_fence", k % 3, -128 + 16 * k, -64, 0)
    P("farm_windmill", 0, -232, -10, 30, KINGDOM)
    P("farm_barn", 0, -180, -28, face(-180, -28, -150, -30), KINGDOM)
    for k, (hx, hy) in enumerate(((-205, -40), (-212, -48), (-160, -44))):
        P("farm_haystack", k, hx, hy, rng.uniform(0, 360))

    # --- forest east + edges, resource nodes at the forest edge, rocks on the hill
    def scatter(gen, n, cx, cy, rx, ry, spacing, variants, avoid=()):
        pts = []
        tries = 0
        while len(pts) < n and tries < n * 40:
            tries += 1
            x, y = cx + rng.uniform(-rx, rx), cy + rng.uniform(-ry, ry)
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 > 1:
                continue
            p = Vector((x, y))
            if any((p - q).length < spacing for q in pts):
                continue
            if dist_to_polyline(p, RIVER) < 30 or min(dist_to_polyline(p, ROAD_MAIN), dist_to_polyline(p, ROAD_FOREST),
                                                       dist_to_polyline(p, ROAD_FARM)) < 12:
                continue
            if any((p - Vector(a[:2])).length < a[2] for a in avoid):
                continue
            pts.append(p)
            P(gen, rng.choice(variants), x, y, rng.uniform(0, 360), pad=False, sink=0.4,
              scale=rng.uniform(0.85, 1.15))
        return pts

    avoid = [(sq.x, sq.y, 70), (CASTLE.x, CASTLE.y, 120), (70, 2, 26), (-180, -80, 90)]
    scatter("tree_oak", 26, 190, 10, 110, 70, 22, range(8), avoid)
    scatter("tree_pine", 30, 270, 200, 140, 110, 20, range(6), avoid)
    scatter("tree_birch", 10, 120, 60, 60, 40, 18, range(6), avoid)
    scatter("tree_oak", 14, -120, 180, 140, 70, 24, range(8), avoid)
    scatter("tree_pine", 16, -260, 200, 120, 90, 22, range(6), avoid)
    scatter("tree_oak", 10, -300, -120, 80, 120, 24, range(8), avoid)
    scatter("bush", 40, 0, 0, 300, 220, 14, range(8), avoid + [(0, -120, 40)])
    scatter("plant_flowers", 24, 0, -60, 120, 120, 10, range(6), [(sq.x, sq.y, 30)])
    P("resource_wood", 0, 132, -24, 30)
    P("resource_wood", 1, 168, 52, 300)
    P("resource_stone", 0, -70, 205, 10)
    P("resource_stone", 1, 90, 215, 160)
    P("resource_ore", 0, 120, 240, 40)
    P("resource_ore", 3, -110, 230, 220)
    for k, (rx, ry) in enumerate(((-60, 230), (70, 200), (40, 250), (-90, 180), (150, 170), (-150, 60), (160, 100))):
        P("rock_boulder", k % 9, rx, ry, rng.uniform(0, 360), pad=False, sink=0.6)
    P("rock_cliff", 0, -60, 112, 10, pad=False, sink=2.0)
    P("rock_cliff", 1, 70, 120, 190, pad=False, sink=2.0)

    # --- people and life on the roads
    for k, (cx_, cy_) in enumerate(((2, -60), (-6, -34), (8, -30), (-12, -50), (14, -48), (-2, -110), (4, -150))):
        P("char_citizen", k % 6, cx_, cy_, rng.uniform(0, 360), KINGDOM if k % 2 else None, pad=False)
    for k in range(6):
        P("char_soldier", 0 if k % 3 else 1, -3 + (k % 2) * 6, 120 + k * 7, 180, KINGDOM, pad=False)
    P("prop_cart", 0, 10, -8, 170)
    P("prop_goods", 0, sq.x + 22, sq.y - 2, 0)
    P("prop_goods", 1, sq.x - 22, sq.y + 2, 90)
    return placed


SHOTS = {
    # name: (camera location, target, vertical FOV deg)
    "establish": ((-150, -330, 135), (10, 95, 6), 42),
    "street": ((-6, -112, 15), (4, -20, 7), 70),  # Roblox-like third-person in the village street
    "castle": ((70, 60, 40), (0, 230, 30), 55),
}


def main(argv):
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--shots", default="establish,street,castle")
    ap.add_argument("--samples", type=int)
    args = ap.parse_args(argv)

    t0 = time.time()
    rig.reset_scene()
    sc = bpy.context.scene
    w, h = (960, 540) if args.quick else (1920, 1080)
    rig.setup_render(sc, w, h, args.samples or (16 if args.quick else 64))
    rig.setup_world(sc, sky_top=(0.16, 0.42, 0.88), sky_horizon=(0.70, 0.82, 0.95), fill_strength=0.7)
    rig.add_sun(sc, elevation_deg=38, azimuth_deg=-55, strength=4.8)
    rng = random.Random(42)
    T = Terrain()
    lib = Library()
    placed = populate(lib, T, rng)  # pads registered while placing; terrain mesh built after
    T.build_mesh(step=3.0 if not args.quick else 4.0)
    add_far_hills()
    add_water()
    for m in bpy.data.materials:
        if m.name in ("M_terrain", "M_water", rig.PREVIEW_MATERIAL):
            add_haze(m)
    cam = rig.add_camera(sc, 40)
    print(f"placed {len(placed)} objects from {len(lib.cache)} sources; missing generators: "
          f"{sorted(lib.missing)}; broken: {lib.broken}; build {time.time() - t0:.0f}s", flush=True)
    out_dir = HERE / "renders" / "scenes"
    out_dir.mkdir(parents=True, exist_ok=True)
    for name in args.shots.split(","):
        loc, tgt, fov = SHOTS[name]
        cam.location = loc
        cam.data.angle_y = math.radians(fov)
        rig.aim(cam, tgt)
        path = out_dir / f"village_{name}.png"
        t1 = time.time()
        rig.render(sc, path)
        print(f"shot {name}: {path} ({time.time() - t1:.0f}s)", flush=True)
        if contact.available():
            from PIL import Image

            res = contact.save_jpeg_under(Image.open(path), HERE / "previews" / f"scene_village_{name}.jpg")
            print(f"preview {res[0].name}: {res[1]} bytes, q{res[2]}, {res[3]}", flush=True)


if __name__ == "__main__":
    main(sys.argv)
