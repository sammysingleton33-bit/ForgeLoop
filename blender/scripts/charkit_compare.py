"""Renders for the character-kit style comparison and the before/after sets (FL-0135, D-057).

  ~/forge-bpy/bin/python blender/scripts/charkit_compare.py --option A --view portrait --out DIR [--quick]
  options: old (part-built rigs, games/game-001/art/char_kit/old_rigs.json), A / B (procedural kit styles), C (KayKit-derived)
  views:   portrait (one 480 px image per character, Kit/Portrait framing), gp40 (the three characters 40 studs away,
           Roblox 70 deg FOV), aerial170 (170 studs, 50 deg down, next to a KayKit building if --building is given)
Blender renders are not Studio renders (no Roblox materials, Cycles lighting).
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
from mathutils import Matrix, Vector  # noqa: E402

from generators import _charkit_rig as RIG  # noqa: E402
from generators import _charkit_style as K  # noqa: E402
from lib import ckit_assemble, ckit_scene, ckit_view, kitparts, rig  # noqa: E402

CHARS = [("farmer", "head_01", None, "crimson"), ("soldier", "head_02", None, "crimson"), ("governor", "head_04", None, "crimson")]
OLD = REPO / "games/game-001/art/char_kit/old_rigs.json"


def parse(argv):
    argv = argv[argv.index("--") + 1:] if "--" in argv else argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--option", required=True)
    ap.add_argument("--view", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--samples", type=int, default=0)
    ap.add_argument("--kaykit", default="", help="KayKit Adventurers pack root (read-only cache), option C")
    ap.add_argument("--ground", default="", help="r,g,b 0-255 ground colour for the portrait view (neutral grey avoids the green bounce on skin)")
    ap.add_argument("--building", default="")
    ap.add_argument("--building-scale", type=float, default=25.0)
    return ap.parse_args(argv)


C_NAMES = {
    "farmer": ["kk_rogue_head", "hat_straw", "hat_ribbon", "kk_rogue_body", "kk_rogue_arm_l", "kk_rogue_arm_r", "kk_rogue_leg_l",
               "kk_rogue_leg_r", "tool_hoe", "apron_farm"],
    "soldier": ["kk_knight_head", "kk_knight_helmet", "crest_crimson_C", "kk_knight_body", "kk_knight_arm_l", "kk_knight_arm_r",
                "kk_knight_leg_l", "kk_knight_leg_r", "tool_spear", "tool_pennant"],
    "governor": ["kk_knight_head", "hat_crown", "crown_cap", "kk_knight_body", "kk_knight_cape", "kk_knight_arm_l", "kk_knight_arm_r",
                 "kk_knight_leg_l", "kk_knight_leg_r", "collar_ermine", "tool_staff_ruler"],
}


def new_pieces(option, kaykit=""):
    from generators import _charkit_body as B
    from generators import _charkit_gear as G

    S = K.STYLE_B if option == "B" else K.STYLE_A
    R = K.Registry(S)
    B.build_body(S, R)
    G.build_gear(S, R)
    RIG.set_pieces(R.pieces)
    if option == "C":
        from generators import _charkit_kaykit as KKit

        KKit.build(R, kaykit)
        R.add("crest_crimson_C", R.pieces["crest_crimson"].m.copy().move(0, -0.27, 0), "Head", "crest", "kingdom", weld="head")
    return S, R.pieces


def old_model(job):
    data = json.loads(OLD.read_text())
    return next(m for m in data["jobs"] if m["label"] == job)


def place_option(option, job, face, hair, kingdom, x, z, yaw, state):
    """Create the objects of one character of `option` at (x, z); returns (objs, head_top, half_width)."""
    if option == "old":
        m = old_model(job)
        objs = kitparts.build_model(m, bpy.context.scene.collection, transform=ckit_scene.roblox_matrix(x, 0, z, yaw))
        top, hw = 0.0, 1.5
        for p in m["parts"]:
            if p["name"] in ("Head", "Hair") or (p["name"].startswith("Detail") and abs(p["cframe"][0]) < 1.0):
                cf = p["cframe"]
                sx, sy, sz = p["size"]
                top = max(top, cf[1] + abs(cf[6]) * sx / 2 + abs(cf[7]) * sy / 2 + abs(cf[8]) * sz / 2)
                hw = max(hw, (abs(cf[0]) + abs(cf[3]) * sx / 2 + abs(cf[5]) * sy / 2 + abs(cf[4]) * sz / 2) * 1.15)
        return objs, top, hw
    S, pieces = state
    panels, legs = RIG.CLOTH_PANELS.get(job, RIG.CLOTH_PANELS["folk"]), RIG.CLOTH_LEGS.get(job, RIG.CLOTH_LEGS["folk"])
    ctx = {"skin": 0, "hairColor": 0, "kingdom": kingdom, "kit_tint": RIG.KIT_TINT,
           "cloth": {"leg": legs[0], "default": panels[0], "torso": panels[0], "sleeve": panels[0]}}
    names = C_NAMES[job] if option == "C" else [face if n.startswith("head_") else n for n in RIG.names_for(job, None, kingdom)]
    objs = ckit_assemble.build(pieces, names, ctx, facet=S.facet, location=(x, 0, z), yaw=yaw, tag=f"{job}_")
    top, hw = 0.0, 1.5
    for n in names:
        p = pieces[n]
        if p.joint == "Head":
            (x0, y0, z0), (x1, y1, z1) = p.m.bounds()
            top = max(top, y1)
            hw = max(hw, max(abs(x0), abs(x1)) * 1.15)
    return objs, top, hw


def main(argv):
    a = parse(argv)
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    state = None if a.option == "old" else new_pieces(a.option, a.kaykit)
    quick = a.quick
    if a.view == "portrait":
        for job, face, hair, kingdom in CHARS:
            ckit_view.QUICK = quick
            sc = ckit_view.stage(480, 480, a.samples or (16 if not quick else 6), ground=tuple(float(v) for v in a.ground.split(",")) if a.ground else ckit_view.GRASS, quick=quick)
            objs, top, hw = place_option(a.option, job, face, hair, kingdom, 0, 0, 0, state)
            cam = rig.add_camera(sc, 30)
            dist = ckit_scene.portrait(cam, top, hw)
            path = out / f"{a.option}_portrait_{job}.png"
            rig.render(sc, path)
            print(f"[compare] {path} (portrait dist {dist:.1f})", flush=True)
    elif a.view == "gp40":
        ckit_view.QUICK = quick
        sc = ckit_view.stage(1280, 720, a.samples or (24 if not quick else 6), quick=quick)
        for i, (job, face, hair, kingdom) in enumerate(CHARS):
            place_option(a.option, job, face, hair, kingdom, (1 - i) * 8.0, 0.0, 0.0, state)
        cam = rig.add_camera(sc, 70)
        ckit_scene.gameplay(cam, (0, 2.8, 0), 40.0, 14.0)
        path = out / f"{a.option}_gp40.png"
        rig.render(sc, path)
        print(f"[compare] {path}", flush=True)
    elif a.view == "aerial170":
        ckit_view.QUICK = quick
        sc = ckit_view.stage(1920, 1080, a.samples or (24 if not quick else 6), quick=quick)
        if a.building:
            import_building(a.building, a.building_scale, (0.0, 0.0, 17.0))
        for i, (job, face, hair, kingdom) in enumerate(CHARS):
            place_option(a.option, job, face, hair, kingdom, (1 - i) * 7.0, 0.0, 0.0, state)
        cam = rig.add_camera(sc, 70)
        ckit_scene.aerial(cam, (0, 3.0, 0.0), 170.0, 50.0)
        path = out / f"{a.option}_aerial170.png"
        rig.render(sc, path)
        print(f"[compare] {path}", flush=True)


def import_building(path, scale, at):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    root = Matrix.Diagonal((scale, scale, scale, 1.0))
    for o in new:
        if o.parent is None:
            # glTF import: +Y front is Blender -Y already; place at (-x, z, y) of the Roblox position
            o.matrix_world = Matrix.Translation(ckit_scene.r2b((at[0], at[1], at[2]))) @ root @ o.matrix_world
    return new


if __name__ == "__main__":
    main(sys.argv)
