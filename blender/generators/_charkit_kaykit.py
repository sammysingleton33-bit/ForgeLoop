"""Character kit option C: KayKit (CC0) body parts fitted into the rig envelope (FL-0135, D-057 (9)).

KayKit Adventurers (Kay Lousberg, CC0) pieces are segmented like our rig already (head, body, two arms, two legs, helmet,
cape). Each source mesh is read from a gitignored cache, atlas colours are baked to vertex colours, the mesh is closed and
decimated (colour boundaries protected) and fitted per part into the Kit/Character.luau envelope.
Only used for the style comparison until a style is picked; sources are never committed (D-057 (13)).
"""

import colorsys
from pathlib import Path

from lib import ckit_kaykit as KK
from lib.ckit import M

from . import _charkit_style as K

KK_CHAR_DIR = "addons/kaykit_character_pack_adventures/Characters/gltf"

# fit boxes in the rig frame (studs): the SAME envelopes as the procedural kit
HEAD_BOX = ((-0.8, 3.84, -0.78), (0.8, 5.44, 0.78))
BODY_BOX = ((-0.97, 2.2, -0.6), (0.97, 3.95, 0.6))
ARM_BOX_L = ((-1.95, 2.2, -0.42), (-1.07, 3.95, 0.4))
LEG_BOX_L = ((-0.96, 0.0, -0.62), (-0.04, 2.3, 0.5))
BUDGET = {"head": 300, "helmet": 240, "body": 300, "arm": 100, "leg": 80, "cape": 60, "hat": 180}


def _affine(ref, box):
    (x0, y0, z0), (x1, y1, z1) = ref.bounds()
    (a0, b0, c0), (a1, b1, c1) = box
    sx, sy, sz = (a1 - a0) / (x1 - x0), (b1 - b0) / (y1 - y0), (c1 - c0) / (z1 - z0)
    cx, cy, cz = (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2
    tx, ty, tz = (a0 + a1) / 2, (b0 + b1) / 2, (c0 + c1) / 2
    return lambda p: ((p[0] - cx) * sx + tx, (p[1] - cy) * sy + ty, (p[2] - cz) * sz + tz)


def recolor_hue(m, lo, hi, new_hue, sat_min=0.2):
    """Shift corner colours whose hue is in [lo, hi] (0..1) to `new_hue`, keeping saturation and value."""
    for cols in m.cc:
        for i, c in enumerate(cols):
            h, s, v = colorsys.rgb_to_hsv(*c)
            if s >= sat_min and lo <= h <= hi:
                cols[i] = colorsys.hsv_to_rgb(new_hue, s, v)
    return m


def straighten_arm(m, target_deg=7.0):
    """KayKit arms hang in an A-pose (about 30 degrees out): rotate about the shoulder so they hang like our rig's arms
    (splayed `target_deg` outward at rest). Works on the left arm (x < 0); mirror for the right."""
    import math

    ys = [v[1] for v in m.v]
    y0, y1 = min(ys), max(ys)
    h = y1 - y0

    def centre(lo, hi):
        pts = [v for v in m.v if lo <= v[1] <= hi]
        return sum(p[0] for p in pts) / len(pts)

    top, bot = centre(y1 - 0.1 * h, y1), centre(y0, y0 + 0.15 * h)
    cur = math.degrees(math.atan2(top - bot, 0.75 * h))  # >0: the hand is further out than the shoulder (left arm: x < 0)
    cur = abs(cur)
    return m.rot(cur - target_deg, "z", pivot=(top, y1 - 0.05 * h, 0.0))


def load_character(root, name, tex, parts):
    """parts: {key: (mesh object name, target triangles)} -> {key: M} fitted later by the caller."""
    import bpy  # noqa: F401

    base = Path(root) / KK_CHAR_DIR
    objs = KK.import_glb(base / f"{name}.glb")
    atlas = KK.load_atlas(base / tex)
    out = {}
    for key, (obj_name, tris) in parts.items():
        m = KK.to_M(objs[obj_name], atlas)
        out[key] = KK.decimate(m, tris, protect=0.6) if tris else m
    return out


def build(R, root):
    """Add the KayKit-derived pieces to Registry R (names kk_*). Returns nothing."""
    # ---- Knight (soldier, governor)
    kn = load_character(root, "Knight", "knight_texture.png", {
        "head": ("Knight_Head", BUDGET["head"]), "helmet": ("Knight_Helmet", BUDGET["helmet"]),
        "body": ("Knight_Body", BUDGET["body"]), "cape": ("Knight_Cape", BUDGET["cape"]),
        "arm": ("Knight_ArmLeft", BUDGET["arm"]), "leg": ("Knight_LegLeft", BUDGET["leg"]),
    })
    _register(R, "knight", kn)
    # ---- Rogue (farmer stand-in, hood off): the green tunic becomes a kingdom-coloured tunic (crimson)
    rg = load_character(root, "Rogue", "rogue_texture.png", {
        "head": ("Rogue_Head", BUDGET["head"]), "body": ("Rogue_Body", BUDGET["body"]),
        "arm": ("Rogue_ArmLeft", BUDGET["arm"]), "leg": ("Rogue_LegLeft", BUDGET["leg"]),
    })
    for k in ("body", "arm"):
        recolor_hue(rg[k], 0.18, 0.55, 0.995, 0.18)
    _register(R, "rogue", rg)


def _register(R, who, parts):
    f_head = _affine(parts["head"], HEAD_BOX)
    f_body = _affine(parts["body"], BODY_BOX)
    parts["arm"] = straighten_arm(parts["arm"])
    f_arm = _affine(parts["arm"], ARM_BOX_L)
    f_leg = _affine(parts["leg"], LEG_BOX_L)

    def fitted(m, f):
        out = m.copy()
        return out.map(f)

    R.add(f"kk_{who}_head", fitted(parts["head"], f_head), "Head", "head", "fixed", tags=("kk",))
    if "helmet" in parts:
        R.add(f"kk_{who}_helmet", fitted(parts["helmet"], f_head), "Head", "hat", "fixed", weld="head", tags=("kk",))
    R.add(f"kk_{who}_body", fitted(parts["body"], f_body), "Torso", "torso", "fixed", tags=("kk",))
    if "cape" in parts:
        R.add(f"kk_{who}_cape", fitted(parts["cape"], f_body), "Torso", "cape", "fixed", weld="torso", tags=("kk",))
    arm_l = fitted(parts["arm"], f_arm)
    R.add(f"kk_{who}_arm_l", arm_l, "LeftArm", "arm", "fixed", tags=("kk",))
    R.add(f"kk_{who}_arm_r", arm_l.copy().mirror_x(), "RightArm", "arm", "fixed", tags=("kk",))
    leg_l = fitted(parts["leg"], f_leg)
    R.add(f"kk_{who}_leg_l", leg_l, "LeftLeg", "leg", "fixed", tags=("kk",))
    R.add(f"kk_{who}_leg_r", leg_l.copy().mirror_x(), "RightLeg", "leg", "fixed", tags=("kk",))
