"""FL-0136 phase 1: render the style comparison (S1 / S2 / S3 / own style-B wheat) of the same subjects at the same cameras.

  ~/forge-bpy/bin/python blender/scripts/envkit_compare.py --s3 /tmp/env_s3.json --out DIR [--subjects keep_L1_crimson,house] [--sources S1,S2,S3] [--quick]

Per (subject, source) it writes DIR/<subject>__<source>__gameplay82.png and __aerial170.png plus DIR/<subject>__<source>.json (triangle count,
mesh pieces, fit report against Kit.footprint, projected bounds of the subject and the citizens for the sheet crops).
The mesh-kit citizens (farmer, soldier, governor, hauler; games/game-001/art/char_kit) stand beside every subject for scale and cohesion.
Cameras: RulerCameraController overview, 70 degrees vertical FOV; gameplay = 82 studs (pitch 44 degrees, the controller's
pitchFor(82)), aerial = 170 studs at 50 degrees (the D-019 aerial view). Blender renders are not Studio renders.
"""

import argparse
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(HERE))
REPO = HERE.parent

import bpy  # noqa: E402
from bpy_extras.object_utils import world_to_camera_view  # noqa: E402

from lib import ckit_rigload, ckit_scene, ckit_view, envkit as E, kitparts, rig  # noqa: E402

FBX = REPO / "games/game-001/art/char_kit/citizen_kit.fbx"
RIGJ = REPO / "games/game-001/art/char_kit/rig.json"

FP = {("keep", 1): (32, 32), ("keep", 3): (46, 46), ("house", 1): (20, 16), ("barracks", 1): (30, 20), ("watchtower", 1): (14, 14)}
CAMS = {"gameplay82": dict(dist=82.0, pitch=44.3), "aerial170": dict(dist=170.0, pitch=50.0)}  # Def.pitchFor(82) = 38 + 27 * 42 / 180

# subject id -> definition. `kind`/`level`/`hue` drive the three loaders; families group the sheets
SUBJECTS = {
    "keep_L1_crimson": dict(family="buildings", kind="keep", level=1, hue="crimson"),
    "keep_L1_emerald": dict(family="buildings", kind="keep", level=1, hue="emerald"),
    "keep_L3_crimson": dict(family="buildings", kind="keep", level=3, hue="crimson"),
    "house_L1_crimson": dict(family="buildings", kind="house", level=1, hue="crimson"),
    "barracks_L1_crimson": dict(family="buildings", kind="barracks", level=1, hue="crimson"),
    "watchtower_L1_crimson": dict(family="buildings", kind="watchtower", level=1, hue="crimson"),
    "watchtower_L1_emerald": dict(family="buildings", kind="watchtower", level=1, hue="emerald"),
    "nature": dict(family="nature"),
    "wheat": dict(family="wheat"),
    "wheat_stages": dict(family="wheat_stages"),
    "town": dict(family="town"),
}
SOURCES = {"buildings": ("S1", "S2", "S3"), "nature": ("S1", "S2", "S3"), "wheat": ("S1", "S3", "B"), "wheat_stages": ("B",),
           "town": ("S1", "S2", "S3")}

S1_ID = {"keep": "castle_keep_{h}_01", "house": "house_cottage_01", "barracks": "building_barracks_01", "watchtower": "castle_tower_{h}_01"}
S2_REL = {"keep": "buildings/{h}/building_castle_{h}", "house": "buildings/{h}/building_home_A_{h}",
          "barracks": "buildings/{h}/building_barracks_{h}", "watchtower": "buildings/{h}/building_tower_A_{h}"}

# the S2 kitbash of a level 3 keep: the castle in the middle, four corner towers, a curtain wall with a gate in front
S2_L3 = {"castle": "buildings/{h}/building_castle_{h}", "tower": "buildings/{h}/building_tower_A_{h}",
         "wall": "buildings/neutral/wall_straight", "gate": "buildings/neutral/wall_straight_gate"}

CITIZENS = [("farmer", dict(skin=2, hair=3, hairColor=4, outfit=1), 0.0), ("soldier", dict(skin=1, hair=1, hairColor=2, outfit=1), 12.0),
            ("governor", dict(skin=3, hair=2, hairColor=1, outfit=1), -10.0), ("hauler", dict(skin=4, hair=5, hairColor=3, outfit=2), 20.0)]

CACHE = {}


def cached(key, fn):
    if key not in CACHE:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        CACHE[key] = fn()
    return CACHE[key]


def s1(aid):
    return cached(("s1", aid), lambda: E.s1_load(aid)).copy()


def s2(rel, flat=True):
    return cached(("s2", rel), lambda: E.kk_load(rel, flat=flat)).copy()


def parse(argv):
    argv = argv[argv.index("--") + 1:] if "--" in argv else argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--s3", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--subjects", default="")
    ap.add_argument("--sources", default="")
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--samples", type=int, default=0)
    ap.add_argument("--size", default="1920x1080")
    ap.add_argument("--cams", default="gameplay82,aerial170", help="town renders only aerial170 unless listed")
    ap.add_argument("--no-render", action="store_true", help="only build the items and write the json reports")
    ap.add_argument("--citizens", default="on")
    return ap.parse_args(argv)


# ------------------------------------------------------------------------------------------------ item builders
# an item is ("M", mesh, x, z, yaw) or ("S3", dump entry, x, z, yaw); the report says what was fitted


def building_items(src, sub, s3):
    kind, level, hue = sub["kind"], sub["level"], sub["hue"]
    fx, fz = FP[(kind, level)]
    h = E.HUE[hue]
    if src == "S1":
        m, rep = E.fit_footprint(s1(S1_ID[kind].format(h=h)), fx, fz)
        return [("M", m, 0, 0, 0)], rep
    if src == "S2":
        if kind == "keep" and level == 3:
            return s2_keep_l3(h, fx, fz)
        m, rep = E.fit_footprint(s2(S2_REL[kind].format(h=h)), fx, fz)
        return [("M", m, 0, 0, 0)], rep
    key = f"{kind}_L{level}_{hue}"
    entry = s3[key]
    return [("S3", entry, 0, 0, 0)], E.s3_report(entry, (fx, fz))


def s2_keep_l3(h, fx, fz):
    """Level 3 from the pack's parts: castle + 4 corner towers + curtain wall segments + a gate; fits 46 x 46 by construction."""
    items, tris = [], 0
    castle, rc = E.fit_footprint(s2(S2_L3["castle"].format(h=h)), 32.0, 32.0)  # the level 1 scale: level 3 is never smaller
    items.append(("M", castle, 0, 0, 0))
    tris += castle.tris
    corner = fx / 2 - 5.0  # tower centres on a 36 x 36 square
    for sx in (-1, 1):
        for sz in (-1, 1):
            t, _ = E.fit_footprint(s2(S2_L3["tower"].format(h=h)), 10.0, 10.0)
            items.append(("M", t, sx * corner, sz * corner, 0))
            tris += t.tris
    # wall: segments of 2.0 pack units along x; scale so that three segments span the gap between two towers (36 - 9 = 27)
    seg_len = (2 * corner - 10.0) / 3.0
    for sz in (-1, 1):
        for i in range(3):
            key = S2_L3["gate"] if (sz == -1 and i == 1) else S2_L3["wall"]
            w, _ = E.fit_footprint(s2(key.format(h=h)), seg_len, 3.6)
            items.append(("M", w, -corner + 5.0 + seg_len * (i + 0.5), sz * corner, 0))
            tris += w.tris
    for sx in (-1, 1):
        for i in range(3):
            w, _ = E.fit_footprint(s2(S2_L3["wall"].format(h=h)), seg_len, 3.6)
            items.append(("M", w, sx * corner, -corner + 5.0 + seg_len * (i + 0.5), 90))
            tris += w.tris
    xs = [it[2] for it in items]
    zs = [it[3] for it in items]
    rep = {"scale": "kitbash", "footprint": [fx, fz], "size": [round(max(xs) - min(xs) + 10.0, 1), 0, round(max(zs) - min(zs) + 10.0, 1)],
           "xz_within": True, "tris": tris, "pieces": len(items), "note": "castle 32x32 (L1 scale) + 4 towers 10x10 + 12 wall segments (one gate)"}
    return items, rep


TREE_S1 = ["tree_oak_01", "tree_oak_02", "tree_oak_03", "tree_pine_01", "tree_pine_02", "tree_birch_01", "tree_birch_02", "tree_oak_04"]
TREE_S3 = ["tree_oak_01", "tree_oak_02", "tree_oak_03", "tree_pine_01", "tree_pine_02", "tree_birch_01", "tree_birch_02", "tree_oak_04"]
STAND = [(-5.0, 4.0, 0), (6.5, 1.0, 40), (-1.0, 12.0, 90), (11.0, 11.5, 15), (-9.5, -4.5, 200), (3.0, -6.0, 130), (-12.0, 11.0, 70), (13.0, -3.5, 300)]


def nature_items(src, s3):
    """A lone oak (left), a stand of trees (centre, 8 trees or 3 pack groves) and a boulder (right)."""
    items, rep = [], {}
    oak_h = E.s3_report(s3["tree_oak_01"])["height"]
    if src == "S1":
        for i, (aid, (x, z, yaw)) in enumerate(zip(TREE_S1, STAND)):
            items.append(("M", E.placed(s1(aid), x + 10.0, z + 2.0, yaw), 0, 0, 0))
        items.append(("M", E.placed(s1("tree_oak_02"), -34.0, -6.0, 20), 0, 0, 0))
        items.append(("M", E.placed(s1("rock_boulder_m_01"), 42.0, -8.0, 30), 0, 0, 0))
        rep = {"oak": "tree_oak_02", "stand": TREE_S1, "boulder": "rock_boulder_m_01"}
    elif src == "S2":
        oak, ro = E.fit_height(s2("decoration/nature/tree_single_B", flat=False), oak_h)
        items.append(("M", E.placed(oak, -34.0, -6.0, 20), 0, 0, 0))
        # a forest look from the pack's groves: scale the single tree's factor over the whole group so they match
        sc = ro["scale"]
        for rel, (x, z, yaw) in (("decoration/nature/trees_A_medium", (0.0, 4.0, 0)), ("decoration/nature/trees_B_medium", (17.0, 2.0, 90)),
                                 ("decoration/nature/trees_A_small", (6.0, -14.0, 40)), ("decoration/nature/tree_single_A", (-14.0, -4.0, 0)),
                                 ("decoration/nature/tree_single_B", (28.0, 14.0, 200)), ("decoration/nature/tree_single_A", (-13.0, 14.0, 70))):
            g = s2(rel, flat=False)
            (x0, y0, z0), (x1, y1, z1) = E.bbox(g)
            g.map(lambda p, s=sc, cx=(x0 + x1) / 2, cz=(z0 + z1) / 2, yb=y0: ((p[0] - cx) * s, (p[1] - yb) * s, (p[2] - cz) * s))
            items.append(("M", E.placed(g, x + 8.0, z + 2.0, yaw), 0, 0, 0))
        rock, rr = E.fit_footprint(s2("decoration/nature/rock_single_E", flat=False), 7.5, 7.5)
        items.append(("M", E.placed(rock, 42.0, -8.0, 30), 0, 0, 0))
        rep = {"oak": ro, "boulder": rr, "scale": sc}
    else:
        for aid, (x, z, yaw) in zip(TREE_S3, STAND):
            items.append(("S3", s3[aid], x + 10.0, z + 2.0, yaw))
        items.append(("S3", s3["tree_oak_02"], -34.0, -6.0, 20))
        items.append(("S3", s3["rock_boulder_m_01"], 42.0, -8.0, 30))
        rep = {"oak": E.s3_report(s3["tree_oak_02"]), "boulder": E.s3_report(s3["rock_boulder_m_01"]), "stand": TREE_S3}
    return items, rep


def wheat_items(src, s3):
    fw, fd = 38.0, 28.0
    if src == "S1":
        m, rep = E.fit_footprint(s1("farm_field_01"), fw, fd)
        return [("M", m, 0, 0, 0)], rep
    if src == "S3":
        entry = s3["farm_field_wheat_01"]
        return [("S3", entry, 0, 0, 0)], E.s3_report(entry, (fw, fd))
    m = E.wheat_b(3, fw, fd)
    return [("M", m, 0, 0, 0)], {"size": [fw, round(E.bbox(m)[1][1], 2), fd], "footprint": [fw, fd], "tris": m.tris, "xz_within": True,
                                  "note": "own style-B wheat, ripe stage 3 (stage 1 shoots and stage 2 half grown exist as well)"}


def wheat_stage_items():
    """Own style-B wheat at the three growth stages side by side (information for the owner; not part of the blind comparison)."""
    items, tris = [], 0
    for stage, x in ((1, 42.0), (2, 0.0), (3, -42.0)):
        m = E.wheat_b(stage, 38.0, 28.0)
        items.append(("M", m, x, 0, 0))
        tris += m.tris
    return items, {"tris": tris, "size": [122, 5, 28], "note": "stages 1, 2, 3 (right to left on screen)"}


def town_items(src, s3):
    """A small settlement per source: keep L1, barracks, house, watchtower, a field, a stand of trees, a lone oak and a boulder."""
    items, tris = [], 0

    def add(its, dx, dz):
        items.extend((k, p, x + dx, z + dz, yw) for k, p, x, z, yw in its)

    add(building_items(src, SUBJECTS["keep_L1_crimson"], s3)[0], 0.0, 14.0)
    add(building_items(src, SUBJECTS["barracks_L1_crimson"], s3)[0], 50.0, 2.0)
    add(building_items(src, SUBJECTS["house_L1_crimson"], s3)[0], -40.0, 4.0)
    add(building_items(src, SUBJECTS["house_L1_crimson"], s3)[0], -62.0, 22.0)
    add(building_items(src, SUBJECTS["watchtower_L1_crimson"], s3)[0], -30.0, -22.0)
    add(wheat_items("B" if src == "S2" else src, s3)[0], 10.0, -46.0)
    add(nature_items(src, s3)[0], -8.0, 62.0)
    return items, {"tris": 0, "size": [0, 0, 0], "note": "settlement; the field is the own style-B wheat for S2"}


# ------------------------------------------------------------------------------------------------ scene

def citizens_for(sub, kit, items_bounds):
    """Four citizens in front of (and beside) the subject; positions follow the subject's front edge."""
    (x0, z0), (x1, z1) = items_bounds
    if sub["family"] == "nature":
        (x0, z0), (x1, z1) = (-2.0, -4.0), (30.0, 8.0)  # in front of the stand, between the oak and the boulder
    elif sub["family"] == "town":
        (x0, z0), (x1, z1) = (-12.0, -10.0), (14.0, 8.0)  # at the foot of the keep
    elif sub["family"] == "wheat_stages":
        (x0, z0), (x1, z1) = (-19.0, -14.0), (19.0, 14.0)
    front = z0 - 5.5
    spec = [(x0 + 3.0, front + 1.0, 8.0), (x0 + 8.5, front - 0.8, -5.0), (x1 - 9.5, front - 0.5, 15.0), (x1 - 3.0, front + 1.2, -12.0)]
    objs = []
    for (job, look, _), (x, z, yaw) in zip(CITIZENS, spec):
        objs += kit.spawn(job, look, "crimson", x, z, yaw, tag=f"{job}_")
    return objs, spec


def item_bounds(items):
    xs, zs = [], []
    for kind, payload, x, z, yaw in items:
        if kind == "M":
            (a0, _, c0), (a1, _, c1) = E.bbox(payload)
            xs += [a0 + x, a1 + x]
            zs += [c0 + z, c1 + z]
        else:
            mn, mx = E.s3_bbox(payload)
            xs += [mn[0] + x, mx[0] + x]
            zs += [mn[2] + z, mx[2] + z]
    return (min(xs), min(zs)), (max(xs), max(zs))


def item_height(items):
    h = 0.0
    for kind, payload, x, z, yaw in items:
        top = E.bbox(payload)[1][1] if kind == "M" else E.s3_bbox(payload)[1][1]
        h = max(h, top)
    return h


def make_scene(items, sub, size, samples, quick, citizens=True):
    w, h = size
    sc = ckit_view.stage(w, h, samples, quick=False)
    sc.cycles.use_denoising = True
    col = sc.collection
    objs = []
    for n, (kind, payload, x, z, yaw) in enumerate(items):
        if kind == "M":
            ob = ckit_view.make(f"item{n}", E.placed(payload, 0, 0, yaw) if yaw else payload.copy(), ao=0.0, location=(x, 0.0, z), collection=col)
            objs.append(ob)
        else:
            objs += kitparts.build_model(payload, col, transform=ckit_scene.roblox_matrix(x, 0, z, yaw))
    cit = []
    if citizens:
        kit = ckit_rigload.Kit(FBX, RIGJ)
        b = item_bounds(items)
        cit, _ = citizens_for(sub, kit, b)
    return sc, objs, cit


def project(sc, cam, objs):
    """2D bounds (0..1, y down) of the objects' bounding boxes in the camera view."""
    from mathutils import Vector

    x0, y0, x1, y1 = 9.0, 9.0, -9.0, -9.0
    for o in objs:
        for c in o.bound_box:
            p = world_to_camera_view(sc, cam, o.matrix_world @ Vector(c))
            x0, x1 = min(x0, p.x), max(x1, p.x)
            y0, y1 = min(y0, 1 - p.y), max(y1, 1 - p.y)
    return [round(v, 4) for v in (x0, y0, x1, y1)]


def render_subject(sid, src, a, s3):
    sub = SUBJECTS[sid]
    fam = sub["family"]
    if fam == "buildings":
        items, rep = building_items(src, sub, s3)
    elif fam == "nature":
        items, rep = nature_items(src, s3)
    elif fam == "wheat":
        items, rep = wheat_items(src, s3)
    elif fam == "wheat_stages":
        items, rep = wheat_stage_items()
    else:
        items, rep = town_items(src, s3)
    tris = sum(p.tris for k, p, *_ in items if k == "M")
    parts = sum(len(p["parts"]) for k, p, *_ in items if k == "S3")
    rep = dict(rep, subject=sid, source=src, tris=tris or rep.get("tris", 0), mesh_pieces=sum(1 for k, *_ in items if k == "M"),
               part_count=parts, height=round(item_height(items), 1))
    w, h = (int(v) for v in a.size.split("x"))
    samples = a.samples or (8 if a.quick else 24)
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    if a.no_render:
        (out / f"{sid}__{src}.json").write_text(json.dumps(rep, indent=1))
        return rep
    sc, objs, cit = make_scene(items, sub, (w, h), samples, a.quick, a.citizens == "on")
    cam = rig.add_camera(sc, 70)
    (x0, z0), (x1, z1) = item_bounds(items)
    tgt_h = {"keep": 26.0, "house": 13.0, "barracks": 14.0, "watchtower": 24.0}.get(sub.get("kind"), {"nature": 10.0, "wheat": 2.0, "wheat_stages": 2.0, "town": 10.0}.get(fam, 12.0))  # the same camera for every source of a subject
    cx, cz = {"buildings": (0.0, 0.0), "nature": (10.0, 0.0), "wheat": (0.0, 0.0), "wheat_stages": (0.0, 0.0), "town": (-8.0, 14.0)}[fam]
    rep["projected"] = {}
    for name in (["aerial170"] if fam == "town" else a.cams.split(",")):
        cfg = CAMS[name]
        ckit_scene.gameplay(cam, (cx, tgt_h, cz - 4.0), cfg["dist"], cfg["pitch"], az_deg=0.0, fov=70.0)
        bpy.context.view_layer.update()
        rep["projected"][name] = {"subject": project(sc, cam, objs), "all": project(sc, cam, objs + cit)}
        path = out / f"{sid}__{src}__{name}.png"
        rig.render(sc, path)
    (out / f"{sid}__{src}.json").write_text(json.dumps(rep, indent=1))
    return rep


def main(argv):
    a = parse(argv)
    s3 = json.loads(Path(a.s3).read_text())["subjects"]
    sids = [s for s in a.subjects.split(",") if s] or list(SUBJECTS)
    want = set(s for s in a.sources.split(",") if s)
    for sid in sids:
        fam = SUBJECTS[sid]["family"]
        for src in SOURCES[fam]:  # noqa: B007
            if want and src not in want:
                continue
            rep = render_subject(sid, src, a, s3)
            print(f"[env] {sid} {src}: tris {rep['tris']} pieces {rep['mesh_pieces']} parts {rep['part_count']} height {rep['height']} "
                  f"fit {rep.get('scale')} size {rep.get('size')}", flush=True)


if __name__ == "__main__":
    main(sys.argv)
