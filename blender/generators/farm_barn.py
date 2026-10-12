"""Big barn: gable end to the front (Blender -Y) with huge double doors (9.2 x 10.6 opening,
open on some variants so the hay-filled interior shows), a hayloft door in the gable with a
hoist beam, pulley and rope, board-and-batten vertical plank walls (natural wood or
kingdom barn paint with white trim) on an irregular stone plinth, a steep kit roof (kingdom
tiles or thatch), small shuttered windows down the long sides, an optional louvred cupola
with a weathervane and an optional lean-to woodshed. Hay bales, tools and a trough by the door.

The walls are separate solid slabs, so the open doorway is a real walkable opening into the
barn (floor at z 0.4). Collision boxes for the walls are emitted for gameplay.
"""

import math

from lib import kit
from lib.geo import Vector, box, cylinder, frustum_box, prism
from lib.palette import kingdom_color

from generators import _farm_common as fc

NAME = "farm_barn"
VERSION = 1
CATEGORY = "farm"
BUDGET = "building_medium"
COLLISION = {"fidelity": "None"}  # wall/floor boxes below keep the doorway walkable
CHECKS = {"min_battens": 40, "min_windows": 2, "min_roof": 2}
DEFAULT_VARIANTS = 4
HERO_VIEW = {"azimuth": 32, "elevation": 16}
LINEUP_GAP = 6.0

PLANS = [
    {"kingdom": "red", "paint": True, "roof": "tile", "doors": "open", "loft": "closed", "cupola": True,
     "lean_to": False},
    {"kingdom": None, "paint": False, "roof": "thatch", "doors": "closed", "loft": "open", "cupola": False,
     "lean_to": True},
    {"kingdom": "blue", "paint": True, "roof": "tile", "doors": "half", "loft": "open", "cupola": False,
     "lean_to": True},
    {"kingdom": "green", "paint": False, "roof": "tile", "doors": "open", "loft": "open", "cupola": True,
     "lean_to": False},
]

DW, DH = 9.2, 10.6  # main door opening
T = 0.6  # wall slab thickness


def asset_id(i, params):
    return f"{CATEGORY}_barn_{i + 1:02d}"


def variants(n, seed):
    out = []
    for i in range(n):
        p = dict(PLANS[i % len(PLANS)])
        p["seed"] = seed * 1000 + 700 + i
        out.append(p)
    return out


# ------------------------------------------------------------------ parts

def battens_x(b, rng, x0, x1, y, z0, ztop_fn, color, sgn, pitch=1.25, skip=None):
    """Vertical cover battens on a wall running along X at y (normal sign sgn on Y)."""
    n = 0
    x = x0 + pitch / 2
    while x < x1 - 0.2:
        if skip and skip[0] < x < skip[1]:
            x += pitch
            continue
        zt = ztop_fn(x)
        if zt - z0 > 0.4:
            bt = box(0.26, 0.16, zt - z0, color).move(x + rng.uniform(-0.04, 0.04), y + sgn * 0.08, z0)
            b.add(bt.paint(tint=rng.uniform(0, 1)), tag="batten")
            n += 1
        x += pitch
    return n


def battens_y(b, rng, y0, y1, x, z0, z1, color, sgn, pitch=1.25, skip=()):
    n = 0
    y = y0 + pitch / 2
    while y < y1 - 0.2:
        if any(a < y < c for a, c in skip):
            y += pitch
            continue
        bt = box(0.16, 0.26, z1 - z0, color).move(x + sgn * 0.08, y + rng.uniform(-0.04, 0.04), z0)
        b.add(bt.paint(tint=rng.uniform(0, 1)), tag="batten")
        n += 1
        y += pitch
    return n


def door_leaf(rng, w, h, color, trim):
    """Barn door leaf in local coords: hinge at x=0, leaf along +X, face toward -Y, base z=0.
    Planked leaf with a trim frame and a Z brace."""
    out = [box(w, 0.35, h, color).move(w / 2, 0, 0).paint(grad=("range", 0.3, 0.85))]
    for k in range(int(w / 1.1)):
        u = 0.55 + k * 1.1
        out.append(box(0.18, 0.1, h - 0.4, kingdom_shade(color)).move(u, -0.2, 0.2))
    t = 0.45
    for fy in (-0.26, 0.26):  # trim frame and Z braces on both faces (open leaves show their backs)
        for (cx, cz, sx, sz) in ((t / 2, 0, t, h), (w - t / 2, 0, t, h), (w / 2, 0, w, t), (w / 2, h - t, w, t),
                                 (w / 2, h / 2 - t / 2, w, t)):
            out.append(box(sx, 0.18, sz, trim).move(cx, fy, cz))
        for (za, zb) in ((t, h / 2 - t / 2), (h / 2 + t / 2, h - t)):
            out.append(kit.oriented_box((t, fy, za), (w - t, fy, zb), 0.42, 0.18, trim, Vector((0, -1, 0))))
    for z in (1.2, h - 1.6):
        out.append(box(1.4, 0.12, 0.3, "iron_dark").move(0.75, -0.4, z))
    return out


def kingdom_shade(color):
    """Batten shade one step darker than the wall boards."""
    return {"wood": "wood_dark", "wood_light": "wood", "red_shutter": "red_roof_dark",
            "blue_shutter": "blue_roof_dark", "green_shutter": "green_roof_dark",
            "yellow_shutter": "yellow_trim_dark"}.get(color, "wood_dark")


def cupola(rng, roof, roof_d):
    out = [kit.bbox(2.8, 2.8, 0.5, "timber", 0.08)]
    out.append(box(2.4, 2.4, 2.4, "wood_dark").move(0, 0, 0.5))
    for k in range(4):  # louvres on each face
        a = k * math.pi / 2
        for j in range(4):
            sl = box(1.8, 0.14, 0.32, "wood_pale").rotate(0.5, "X").move(0, -1.24, 0.95 + j * 0.45)
            out.append(sl.rotate(a, "Z"))
        post = box(0.3, 0.3, 2.4, "timber").move(1.2, -1.2, 0.5)
        out.append(post.rotate(a, "Z"))
    out.append(frustum_box(3.6, 3.6, 0.3, 0.3, 2.2, roof).move(0, 0, 2.9).paint(grad=("range", 0.3, 0.95)))
    out.append(cylinder(0.08, 0.08, 2.6, 4, "iron_dark").move(0, 0, 4.9))
    for a in (0.0, math.pi / 2):
        out.append(box(1.4, 0.07, 0.07, "iron_dark").rotate(a, "Z").move(0, 0, 6.2))
    # rooster weathervane
    rooster = prism([(-0.8, 0.0), (0.5, 0.0), (0.9, 0.5), (0.7, 0.9), (0.85, 1.2), (0.45, 1.25), (0.3, 0.55),
                     (-0.4, 0.6), (-0.95, 1.1), (-0.85, 0.35)], 0.08, "iron_dark")
    out.append(rooster.move(0, 0, 6.8))
    return out


# ------------------------------------------------------------------ build

def build(b, p):
    rng = b.rng
    k = p["kingdom"]
    W = rng.uniform(19.0, 20.5)
    D = rng.uniform(26.0, 29.0)
    Hz = rng.uniform(11.6, 12.4)  # eaves height
    plinth = 1.4
    if p["paint"]:
        wall = kingdom_color(k, "shutter")
        trim = "plaster_white"
    else:
        wall = rng.choice(("wood", "wood_light"))
        trim = "timber"
    bat = kingdom_shade(wall)
    shutter = kingdom_color(k, "shutter") if k else "wood_dark"
    if p["paint"]:
        shutter = "plaster_white"
    yf, yb = -D / 2, D / 2

    # --- floor, plinth
    b.add(kit.bbox(W - 0.2, D - 0.2, 0.4, "wood_dark", 0.08), tag="floor")
    pts_l = [(-DW / 2 - 0.9, yf, 0), (-W / 2, yf, 0), (-W / 2, yb, 0), (W / 2, yb, 0), (W / 2, yf, 0),
             (DW / 2 + 0.9, yf, 0)]
    b.add(kit.stone_course(pts_l, plinth, 1.0, "stone", rng, block=(2.0, 3.2), bev=0.0,
                           colors=("stone", "stone_light", "stone_dark")), tag="plinth")
    # --- walls (separate solid slabs so the doorway is a real opening)
    side_x = W / 2 - T / 2
    for sx in (-1, 1):
        b.add(kit.bbox(T, D, Hz, wall, 0.1).move(sx * side_x, 0, 0).paint(grad=("range", 0.3, 0.85)), tag="wall")
    b.add(kit.bbox(W - 2 * T, T, Hz, wall, 0.1).move(0, yb - T / 2, 0).paint(grad=("range", 0.3, 0.85)), tag="wall")
    pw = (W - DW) / 2 - T
    for sx in (-1, 1):
        b.add(kit.bbox(pw, T, Hz, wall, 0.1).move(sx * (DW / 2 + pw / 2), yf + T / 2, 0)
              .paint(grad=("range", 0.3, 0.85)), tag="wall")
    b.add(kit.bbox(DW + 0.2, T, Hz - DH, wall, 0.06).move(0, yf + T / 2, DH).paint(grad=("range", 0.3, 0.85)),
          tag="wall")
    # interior lining (darker) seen through the doorway
    b.add(box(W - 2 * T - 0.4, 0.2, Hz, "wood").move(0, yb - T - 0.1, 0), tag="lining")
    for sx in (-1, 1):
        b.add(box(0.2, D - 2 * T, Hz, "wood").move(sx * (side_x - T / 2 - 0.1), 0, 0), tag="lining")
    # --- roof + gables
    pitch = rng.uniform(52, 56)
    style = p["roof"]
    color = kingdom_color(k, "roof") if (style == "tile" and k) else ("thatch" if style == "thatch" else "wood_dark")
    ridge_col = kingdom_color(k, "roof_dark") if (style == "tile" and k) else "thatch_dark"
    roof, rise = kit.gable_roof(W, D, pitch, overhang=1.4, gable_overhang=1.3, thickness=0.75, color=color,
                                rows=6, ridge_color=ridge_col, style=style, rng=rng, pins=False)
    for q in roof:
        b.add(q.move(0, 0, Hz), tag="roof")
    for sy, yy in ((-1, yf + T / 2), (1, yb - T / 2)):
        g = kit.gable_end(W, rise, T, wall)
        b.add(g.move(0, yy, Hz).paint(grad=("range", 0.4, 0.9)), tag="wall")
    # --- battens: front (around the door, up the gable), back, sides
    nb = 0
    half = W / 2

    def gable_top(x):
        return Hz + max(0.0, rise * (1 - abs(x) / half)) - 0.25

    # front: full height beside the door, above the door header only
    x = -half + 0.62
    while x < half - 0.3:
        z0 = plinth if abs(x) > DW / 2 + 0.3 else DH + 0.6
        zt = gable_top(x)
        if p["loft"] != "none" and abs(x) < 2.6 and zt > Hz + 1.2:
            zt_lo = Hz + 1.0
            if zt_lo - z0 > 0.4:
                b.add(box(0.26, 0.16, zt_lo - z0, bat).move(x, yf - 0.08, z0), tag="batten")
                nb += 1
            z0 = Hz + 6.4
        if zt - z0 > 0.4:
            b.add(box(0.26, 0.16, zt - z0, bat).move(x + rng.uniform(-0.04, 0.04), yf - 0.08, z0)
                  .paint(tint=rng.uniform(0, 1)), tag="batten")
            nb += 1
        x += 1.25
    nb += battens_x(b, rng, -half, half, yb, plinth, gable_top, bat, 1)
    win_y = (-D * 0.22, D * 0.22)
    for sx in (-1, 1):
        nb += battens_y(b, rng, yf, yb, sx * half, plinth, Hz - 0.2, bat, sx,
                        skip=tuple((wy - 2.0, wy + 2.0) for wy in win_y))
    b.stats["battens"] = nb
    # corner + door trim
    for sx in (-1, 1):
        for yy in (yf, yb):
            sy = -1 if yy < 0 else 1
            b.add(box(0.7, 0.2, Hz - plinth, trim).move(sx * (half - 0.35), yy + sy * 0.1, plinth), tag="trim")
            b.add(box(0.2, 0.7, Hz - plinth, trim).move(sx * (half + 0.1), yy - sy * 0.35, plinth), tag="trim")
        b.add(box(0.6, 0.3, DH + 0.6, trim).move(sx * (DW / 2 + 0.3), yf - 0.15, 0), tag="trim")
    b.add(box(DW + 1.2, 0.3, 0.6, trim).move(0, yf - 0.15, DH), tag="trim")
    b.add(box(W + 0.3, 0.3, 0.45, trim).move(0, yf - 0.15, Hz - 0.45), tag="trim")
    # --- main doors
    lw = DW / 2
    mode = p["doors"]
    angles = {"open": (math.radians(165), math.radians(160)), "closed": (0.0, 0.0),
              "half": (math.radians(150), math.radians(8))}[mode]
    for s, ang in zip((-1, 1), angles):
        leaf = door_leaf(rng, lw - 0.05, DH - 0.2, wall, trim)
        for q in leaf:
            if s > 0:
                q.scale(-1, 1, 1)  # mirror: leaf extends -X from the right jamb
            q.rotate(s * ang, "Z").move(s * DW / 2, yf - 0.25, 0.2)  # mirrored winding: finalize recalcs normals
            b.add(q, tag="door")
    # threshold ramp
    b.add(kit.bbox(DW + 0.6, 2.2, 0.35, "wood_dark", 0.08).move(0, yf - 1.0, 0), tag="floor")
    b.socket("door", 0.0, yf - 3.0, 0.0)
    # interior hay (seen through open doors) + hayloft floor
    if mode != "closed":
        b.add(kit.bbox(W - 2 * T - 0.4, D * 0.45, 0.4, "wood", 0.06).move(0, yb - D * 0.225 - T, Hz - 1.2),
              tag="loft")
        prof = [(0.0, 0.0), (5.0, 0.0), (5.4, 0.8), (4.3, 2.4), (2.2, 3.4), (0.0, 3.7)]
        b.add(fc.hay_mound(rng, prof, 12, "hay", 0.35, 0.7, sx=1.5, sy=0.55,
                           bands=("hay_dark", "hay", "thatch", "hay", "straw")).move(0, yb - 4.2, Hz - 0.8), tag="hay")
        b.add(fc.hay_mound(rng, [(0.0, 0.0), (3.4, 0.0), (3.2, 1.0), (1.8, 2.4), (0.0, 2.8)], 10, "hay", 0.3, 0.8,
                           sx=1.3).move(-3.0, yb - 6.0, 0.4), tag="hay")
        for j, (x, y, z, rot) in enumerate(((4.4, yb - 4.0, 0.4, 0.0), (4.4, yb - 5.7, 0.4, 0.0),
                                            (4.4, yb - 4.8, 1.75, 0.1))):
            b.add([q.rotate(rot + math.pi / 2, "Z").move(x, y, z) for q in fc.square_bale(rng)], tag="hay")
        b.add([q.rotate(-0.25, "X").move(-W / 2 + 2.2, yb - D * 0.45 - T - 0.6, 0.4)
               for q in fc.pitchfork(5.8)], tag="tool")
        # hay spilling out through the doorway + bales stacked just inside: visible from outside
        spill = [(0.0, 0.0), (3.2, 0.0), (3.0, 0.5), (1.8, 1.3), (0.0, 1.6)]
        b.add(fc.hay_mound(rng, spill, 10, "hay", 0.25, 0.9, sx=1.2, sy=0.8,
                           bands=("hay_dark", "hay", "straw", "straw")).move(-1.2, yf + 1.6, 0.35), tag="hay")
        b.add([q.move(-1.2, yf + 1.6, 0.35) for q in fc.straw_tufts(rng, spill, 12, sx=1.2, sy=0.8)], tag="tuft")
        for (x, y, z, rot) in ((2.6, yf + 3.0, 0.4, 0.1), (2.7, yf + 4.7, 0.4, -0.05), (2.5, yf + 3.9, 1.75, 0.2)):
            b.add([q.rotate(rot + math.pi / 2, "Z").move(x, y, z) for q in fc.square_bale(rng)], tag="hay")
    # --- hayloft door + hoist
    lz = Hz + 1.0
    lwid, lh = 4.0, 5.0
    b.add(box(lwid + 1.0, 0.3, 0.5, trim).move(0, yf - 0.2, lz - 0.5), tag="trim")
    b.add(box(lwid + 1.0, 0.3, 0.45, trim).move(0, yf - 0.2, lz + lh), tag="trim")
    for sx in (-1, 1):
        b.add(box(0.5, 0.3, lh, trim).move(sx * (lwid / 2 + 0.25), yf - 0.2, lz), tag="trim")
    if p["loft"] == "open":
        b.add(box(lwid, 0.2, lh, "black").move(0, yf - 0.05, lz), tag="loft_door")
        b.add(fc.hay_mound(rng, [(0.0, 0.0), (1.9, 0.0), (1.6, 0.8), (0.0, 1.3)], 8, "hay", 0.18, 1.0,
                           sx=1.0, sy=0.6).move(0, yf - 0.1, lz), tag="hay")
        for s in (-1, 1):  # leaves swung out ~100 degrees
            lf = box(lwid / 2, 0.25, lh, wall).move(lwid / 4, 0, 0)
            if s > 0:
                lf.scale(-1, 1, 1)
            b.add(lf.rotate(s * math.radians(100), "Z").move(s * lwid / 2, yf - 0.3, lz), tag="loft_door")
    else:
        for s in (-1, 1):
            b.add(box(lwid / 2 - 0.05, 0.25, lh, wall).move(s * lwid / 4, yf - 0.25, lz), tag="loft_door")
        b.add(kit.oriented_box((-lwid / 2 + 0.3, yf - 0.42, lz + 0.3), (lwid / 2 - 0.3, yf - 0.42, lz + lh - 0.3),
                               0.4, 0.15, trim, Vector((0, -1, 0))), tag="loft_door")
    hz = lz + lh + 1.6
    b.add(kit.oriented_box((0, yf + 1.5, hz), (0, yf - 3.6, hz), 0.6, 0.6, "timber", Vector((0, 0, 1))), tag="hoist")
    b.add(cylinder(0.45, 0.45, 0.35, 8, "iron_dark").move(0, 0, -0.175).rotate(math.pi / 2, "Y")
          .move(0, yf - 3.2, hz - 0.55), tag="hoist")
    rope_len = 5.5 if p["loft"] == "open" else 3.0
    b.add(box(0.1, 0.1, rope_len, "rope").move(0, yf - 3.2, hz - 0.7 - rope_len), tag="hoist")
    b.add(box(0.14, 0.5, 0.14, "iron_dark").move(0, yf - 3.2, hz - 0.8 - rope_len), tag="hoist")
    if p["loft"] == "open":
        bale = fc.square_bale(rng, 2.6, 1.4, 1.2)
        b.add([q.rotate(0.3, "Z").move(0, yf - 3.2, hz - 2.25 - rope_len) for q in bale], tag="hay")
    # --- side windows
    windows = 0
    for sx in (-1, 1):
        for wy in win_y:
            for q in kit.window(2.2, 2.8, "timber", shutter, mullion=True):
                b.add(q.rotate(sx * math.pi / 2, "Z").move(sx * half, wy, 5.0), tag="window")
            windows += 1
    b.stats["windows"] = windows
    # --- cupola
    if p["cupola"]:
        rc = kingdom_color(k, "roof") if k else "thatch_dark"
        for q in cupola(rng, rc, rc):
            b.add(q.move(0, rng.uniform(-1, 1), Hz + rise + 0.2), tag="cupola")
    # --- lean-to woodshed on one side
    if p["lean_to"]:
        sx = rng.choice((-1, 1))
        lw2, ld, lh2 = 6.0, D * 0.55, 7.2
        lx = sx * (half + lw2 / 2)
        b.add(kit.bbox(lw2, ld, 0.5, "stone_dark", 0.1).move(lx, D * 0.1, 0), tag="shed")
        for yy in (D * 0.1 - ld / 2 + 0.4, D * 0.1, D * 0.1 + ld / 2 - 0.4):
            b.add(kit.bbox(0.6, 0.6, lh2, "timber", 0.06).move(lx + sx * (lw2 / 2 - 0.4), yy, 0.5), tag="shed")
        a = math.radians(20)
        sl = kit.bbox(lw2 + 1.6, ld + 1.2, 0.5, color if style == "tile" else "wood_dark", 0.1)
        b.add(sl.rotate(sx * a, "Y").move(lx, D * 0.1, lh2 + 0.5 + (lw2 / 2) * math.tan(a) - 0.2), tag="roof")
        for row in range(3):
            for j in range(5 - row):
                lg = cylinder(0.55, 0.55, ld * 0.8, 7, "bark").rotate(math.pi / 2, "X")
                b.add(lg.move(lx - sx * 0.3 - 2.0 + j * 1.05 + row * 0.5, D * 0.1 + ld * 0.4, 0.5 + 0.55 + row * 0.95),
                      tag="logs")
                cut = cylinder(0.42, 0.42, 0.1, 7, "wood_pale").rotate(math.pi / 2, "X")
                b.add(cut.move(lx - sx * 0.3 - 2.0 + j * 1.05 + row * 0.5, D * 0.1 - ld * 0.4 + 0.02,
                               0.5 + 0.55 + row * 0.95), tag="logs")
    # --- props by the door: bales, trough, cart wheel
    bx = DW / 2 + 3.2
    for j, (dx, dy, dz, rot) in enumerate(((0.0, -2.2, 0.0, 0.05), (0.2, -4.0, 0.0, -0.08), (0.1, -3.1, 1.32, 0.2))):
        b.add([q.rotate(rot, "Z").move(bx + dx, yf + dy, dz) for q in fc.square_bale(rng)], tag="prop")
    trough = kit.bbox(3.6, 1.4, 1.1, "wood", 0.1)
    b.add(trough.move(-bx - 0.5, yf - 2.2, 0), tag="prop")
    b.add(box(3.2, 1.0, 0.1, "water").move(-bx - 0.5, yf - 2.2, 0.95), tag="prop")
    for q in fc.wheel(1.6, 0.3, 6, "wood", "iron_dark", 12, hub_len=0.6):
        b.add(q.rotate(-0.25, "X").move(-half - 0.45, yf + 4.0, 1.55), tag="prop")
    b.socket("deposit", bx - 1.4, yf - 3.0, 0.0)
    # lantern on the door post, pitchfork leaning by the bales
    lx = -(DW / 2 + 0.3)
    b.add(box(0.12, 0.9, 0.12, "iron_dark").move(lx, yf - 0.6, DH - 1.2), tag="prop")
    b.add(frustum_box(0.6, 0.6, 0.45, 0.45, 0.8, "window_glow").move(lx, yf - 1.0, DH - 2.0), tag="prop")
    b.add(frustum_box(0.75, 0.75, 0.2, 0.2, 0.35, "iron_dark").move(lx, yf - 1.0, DH - 1.2), tag="prop")
    b.add(box(0.7, 0.7, 0.12, "iron_dark").move(lx, yf - 1.0, DH - 2.1), tag="prop")
    b.add([q.rotate(-0.3, "X").rotate(0.2, "Z").move(bx + 2.2, yf - 1.2, 0) for q in fc.pitchfork(6.0)], tag="prop")
    b.stats["roof"] = b.count_tag("roof")
    # collision boxes for the hollow shell (walls only; the doorway stays open)
    b.collision_box(-side_x, 0, Hz / 2, T, D, Hz, "wall_left")
    b.collision_box(side_x, 0, Hz / 2, T, D, Hz, "wall_right")
    b.collision_box(0, yb - T / 2, Hz / 2, W, T, Hz, "wall_back")
    for sx in (-1, 1):
        b.collision_box(sx * (DW / 2 + pw / 2), yf + T / 2, Hz / 2, pw, T, Hz, f"front_{'l' if sx < 0 else 'r'}")
    b.collision_box(0, yf + T / 2, (Hz + DH) / 2, DW, T, Hz - DH, "front_header")
    b.collision_box(0, 0, 0.2, W, D, 0.4, "floor")
    b.collision_box(bx, yf - 3.1, 1.35, 3.4, 3.6, 2.7, "bales")
    if p["lean_to"]:
        b.collision_box(lx, D * 0.1, 3.0, lw2, ld, 6.0, "lean_to")
