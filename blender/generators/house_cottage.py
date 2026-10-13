"""Village cottage: stone plinth, plaster + timber frame (or kingdom-stone ground floor),
optional jettied upper storey, layered thatch or kingdom-tile roof, chimney, shutters in
the kingdom colour, and one archetype feature per variant so plans differ:
porch, woodshed, round stair tower, catslide outshut + dormers, front-gabled wing,
exterior chimney breast.

Front (door) faces Blender -Y (Roblox -Z, the Model's front). Door is walkable (4.4 x 7.6).
"""

import math

from generators._kingdom_props_common import (SUN_DISC, SUN_FIELD, SUN_RAYS, SUN_RIM, SUN_ROUNDEL, crown_outlines,
                                              emblem, emblem_colors, field, oak_outlines, sun_outlines)
from lib import kit
from lib.geo import Vector, bevel, box, cylinder, frustum_box, lathe, prism
from lib.palette import kingdom_color

NAME = "house_cottage"
VERSION = 5
CATEGORY = "house"
BUDGET = "building_small"
COLLISION = {"fidelity": "PreciseConvexDecomposition"}
CHECKS = {"min_pieces": 60, "min_windows": 3, "min_roof": 2}
DEFAULT_VARIANTS = 6

KINGDOM_CYCLE = ("red", "blue", "green", "yellow")
# one archetype per slot: (storeys, roof, ground, features)
ARCHETYPES = (
    (1, "thatch", "plaster", ("porch",)),
    (2, "tile", "stone", ("lean_to",)),
    (2, "thatch", "stone", ("tower", "ext_chimney")),
    (1, "tile", "plaster", ("dormers", "catslide")),
    (2, "thatch", "plaster", ("wing",)),
    (2, "tile", "plaster", ("dormers", "ext_chimney", "steep")),
)
FEATURES = ("porch", "lean_to", "tower", "ext_chimney", "dormers", "catslide", "wing", "steep")
PENNANT_EMBLEM = {"red": "crown", "blue": "star", "green": "oak", "yellow": "sun"}  # D-039 (the flame is retired)
PENNANT_W, PENNANT_H, PENNANT_T = 3.6, 3.4, 0.14  # square kingdom banner on the ridge pole (studs)


def variants(n, seed):
    out = []
    for i in range(n):
        storeys, roof, ground, feats = ARCHETYPES[i % len(ARCHETYPES)]
        p = {"kingdom": KINGDOM_CYCLE[i % 4], "storeys": storeys, "roof": roof, "ground": ground,
             "chimney": "left" if i % 2 else "right", "seed": seed * 1000 + i}
        for f in FEATURES:
            p[f] = f in feats
        out.append(p)
    return out


def build(b, p):
    rng = b.rng
    k = p["kingdom"]
    two = p["storeys"] == 2
    W = rng.uniform(16.5, 20.0)  # X
    D = rng.uniform(12.5, 14.5)  # Y (front at -D/2)
    plinth_h = 1.4
    h1 = rng.uniform(10.2, 11.0)
    h2 = rng.uniform(8.8, 9.6) if two else 0.0
    jetty = 0.9 if two else 0.0
    plaster = rng.choice(("plaster", "plaster", "plaster_white"))
    shutter = kingdom_color(k, "shutter")
    windows = 0
    style = p["roof"]
    thatch_tone = rng.choice(("thatch", "thatch", "hay"))

    # --- plinth
    e = 0.35
    pts = [(-W / 2 - e, -D / 2 - e, 0), (W / 2 + e, -D / 2 - e, 0), (W / 2 + e, D / 2 + e, 0),
           (-W / 2 - e, D / 2 + e, 0), (-W / 2 - e, -D / 2 - e, 0)]
    b.add(kit.stone_course(pts, plinth_h, 1.0, "stone", rng, block=(3.2, 5.0), bev=0.12,
                           colors=("stone", "stone_light", "stone")))
    b.add(box(W, D, plinth_h, "stone_dark"))

    # --- ground floor
    z0 = plinth_h
    dx = rng.choice((-1, 1)) * rng.uniform(W * 0.08, W * 0.2)
    ws = -1 if dx > 0 else 1  # side away from the door
    if p["ground"] == "stone":
        b.add(kit.bbox(W, D, h1, kingdom_color(k, "stone"), 0.2).move(0, 0, z0).paint(grad=("range", 0.2, 0.8)))
        for sx in (-1, 1):
            for sy in (-1, 1):
                if p["tower"] and sx == ws and sy < 0:
                    continue  # the stair tower covers this corner
                for j in range(int(h1 // 1.9)):
                    big = j % 2 == 0
                    q = box(1.9 if big else 1.2, 1.2 if big else 1.9, 1.7, kingdom_color(k, "stone_light"))
                    q.move(sx * (W / 2 - (0.75 if big else 0.4)) + sx * 0.18,
                           sy * (D / 2 - (0.4 if big else 0.75)) + sy * 0.18, z0 + 0.12 + j * 1.9)
                    b.add(q)
        b.add(kit.bbox(W + 0.5, D + 0.5, 0.5, kingdom_color(k, "stone_dark"), 0.12).move(0, 0, z0 + h1 - 0.5))
    else:
        b.add(kit.bbox(W, D, h1, plaster, 0.2).move(0, 0, z0).paint(grad=("range", 0.35, 0.85)))
        door_bay = 1 if dx < 0 else 2
        for off in (-D / 2, D / 2):
            fr = kit.wall_face_frame(W, h1, "x", off, "timber", posts=4, braces=True, rng=rng,
                                     skip=(door_bay,) if off < 0 else (), rail=h1 * 0.5 if off > 0 else None)
            b.add([f.move(0, 0, z0) for f in fr])
        for off in (-W / 2, W / 2):
            fr = kit.wall_face_frame(D, h1, "y", off, "timber", posts=3, braces=True, rng=rng)
            b.add([f.move(0, 0, z0) for f in fr])

    surround = "stone_light" if p["ground"] == "plaster" else kingdom_color(k, "stone_light")
    b.add([pc.move(dx, -D / 2, z0) for pc in kit.door(kit.DOOR_W, kit.DOOR_H, "wood_dark", surround)])
    b.socket("door", dx, -D / 2 - 2.0, 0)

    # --- ground floor windows: front (or on the wing gable), one side, back
    wx, wy = dx + ws * W * 0.33, -D / 2
    if p["wing"]:
        Ww, Dw = rng.uniform(9.0, 10.5), rng.uniform(7.0, 8.5)
        xw = ws * (W / 2 - Ww / 2)
        windows += _wing(b, p, k, xw, -D / 2, Ww, Dw, z0, h1, plinth_h, plaster, shutter, thatch_tone, ws)
        wx, wy = xw, -D / 2 - Dw
    if not p["tower"] or abs(wx - ws * (W / 2 - 0.6)) > 4.5:
        b.add([pc.move(wx, wy, z0 + kit.SILL_Z) for pc in kit.window(kit.WIN_W, kit.WIN_H, "timber", shutter)])
    else:
        wx = dx + ws * W * 0.2
        b.add([pc.move(wx, wy, z0 + kit.SILL_Z) for pc in kit.window(kit.WIN_W, kit.WIN_H, "timber", shutter)])
    windows += 1
    side = -ws if p["ext_chimney"] else rng.choice((-1, 1))
    # A stair-tower house moves its chimney breast to this gable (sx = -ws below), which buries this window
    # (only a shutter edge poked out beside the stack). Skip it there: its triangles pay for the oak leaf on
    # the pennant. The rng draws stay identical, so the rest of the house does not change.
    buried = p["ext_chimney"] and p["tower"]
    for pc in kit.window(kit.WIN_W, kit.WIN_H, "timber", shutter):
        y = rng.uniform(-1.5, 1.5)
        if buried:
            if pc.tint is None:
                rng.uniform(0.15, 0.85)  # the tint draw Builder.add would have made
            continue
        b.add(pc.rotate(side * math.pi / 2, "Z").move(side * W / 2, y, z0 + kit.SILL_Z))
    windows += 0 if buried else 1
    if not p["catslide"]:
        for pc in kit.window(kit.WIN_W, kit.WIN_H, "timber", None):
            b.add(pc.rotate(math.pi, "Z").move(rng.uniform(-W / 4, W / 4), D / 2, z0 + kit.SILL_Z))
        windows += 1

    # flower box under the front window (winged houses carry a kingdom banner instead)
    if p["wing"]:
        _kingdom_banner(b, k, wx + 2.2, wy, z0 + kit.SILL_Z + 4.2)
    b.add(kit.bbox(4.2, 1.0, 0.9, "wood", 0.1).move(wx, wy - 1.0, z0 + kit.SILL_Z - 1.35))
    b.add(kit.bbox(3.9, 0.8, 0.5, "leaf_mid", 0.15).move(wx, wy - 1.0, z0 + kit.SILL_Z - 0.5))
    nfl = 0 if p["wing"] else 6
    for j in range(nfl):
        fl = lathe([(0.0, 0.0), (0.42, 0.2), (0.4, 0.55), (0.0, 0.75)], 4,
                   rng.choice(("flower_red", "flower_yellow", "flower_white", "flower_purple", "flower_red")))
        b.add(fl.move(wx - 1.6 + j * 3.2 / max(1, nfl - 1), wy - 1.0 + rng.uniform(-0.2, 0.2), z0 + kit.SILL_Z - 0.35))
    if p["porch"]:
        _porch(b, dx, -D / 2, "wood")

    # --- upper storey (jettied, with a slight storybook lean)
    top = z0 + h1
    Wr, Dr = W, D
    lean_dx = 0.0
    if two:
        lean = rng.uniform(0.008, 0.016) * rng.choice((-1, 1))
        upper = [kit.bbox(W + 2 * jetty + 0.4, D + 2 * jetty + 0.4, 0.7, "timber", 0.1).move(0, 0, top)]
        for i in range(5):
            u = -W / 2 + 0.6 + (W - 1.2) * i / 4
            b.add(box(0.6, jetty + 0.4, 0.6, "timber").move(u, -D / 2 - jetty / 2, top - 0.55))
        t2 = top + 0.7
        Wr, Dr = W + 2 * jetty, D + 2 * jetty
        upper.append(kit.bbox(Wr, Dr, h2, plaster, 0.18).move(0, 0, t2).paint(grad=("range", 0.4, 0.85)))
        for off in (-Dr / 2, Dr / 2):
            upper += [f.move(0, 0, t2) for f in kit.wall_face_frame(Wr, h2, "x", off, "timber", posts=5,
                                                                    braces=True, rng=rng)]
        for off in (-Wr / 2, Wr / 2):
            upper += [f.move(0, 0, t2) for f in kit.wall_face_frame(Dr, h2, "y", off, "timber", posts=3,
                                                                    braces=False, rng=rng)]
        xs = [-Wr / 4.0, Wr / 4.0]
        if p["wing"]:  # keep both upper windows clear of the wing roof
            xs = [-ws * (Wr / 2 - 2.8), -ws * 2.6]
        for ux in xs:
            upper += [pc.move(ux, -Dr / 2, t2 + 2.6) for pc in kit.window(kit.WIN_W, kit.WIN_H * 0.9, "timber", shutter)]
            windows += 1
        for pc in upper:  # lean the whole upper storey a touch sideways
            pc.bend(lambda v, z=top, ln=lean: (v.x + (v.z - z) * ln, v.y, v.z))
            b.add(pc)
        top = t2 + h2
        lean_dx = h2 * lean

    # --- roof (ridge along X so the long side faces the street)
    if style == "thatch":
        pitch = rng.uniform(52, 56) if p["steep"] else rng.uniform(47, 54)
    else:
        pitch = rng.uniform(49, 53) if p["steep"] else rng.uniform(40, 46)
    color = thatch_tone if style == "thatch" else kingdom_color(k, "roof")
    ridge_col = "thatch_dark" if style == "thatch" else kingdom_color(k, "roof_dark")
    extend = (1, 4.0 / math.cos(math.radians(pitch))) if p["catslide"] else None
    roof, rise = kit.gable_roof(Dr, Wr, pitch, overhang=1.5, gable_overhang=1.1, thickness=0.75, color=color,
                                rows=4 if p["dormers"] and two else 5, ridge_color=ridge_col, style=style, rng=rng,
                                extend=extend)
    for pc in roof:
        b.add(pc.rotate(math.pi / 2, "Z").move(lean_dx, 0, top), tag="roof")
    for sx in (-1, 1):
        g = kit.gable_end(Dr, rise, 0.8, plaster)
        b.add(g.rotate(math.pi / 2, "Z").move(sx * (Wr / 2 - 0.4) + lean_dx, 0, top).paint(grad=("range", 0.5, 0.85)))
        n = Vector((sx, 0, 0))
        xg = sx * (Wr / 2 + 0.1) + lean_dx
        b.add(kit.oriented_box((xg, -Dr / 2 + 0.5, top + 0.35), (xg, Dr / 2 - 0.5, top + 0.35), kit.TIMBER, 0.4,
                               "timber", n))
        b.add(kit.oriented_box((xg, 0, top + 0.6), (xg, 0, top + rise - 0.8), kit.TIMBER, 0.4, "timber", n))
        for s in (-1, 1):
            b.add(kit.oriented_box((xg, s * Dr * 0.36, top + 0.6), (xg, s * 0.4, top + rise * 0.62), kit.TIMBER * 0.8,
                                   0.4, "timber", n))
    # kingdom pennant at the ridge end away from the chimney (D-033: every cottage shows its emblem, D-039)
    end = 1 if p["chimney"] == "left" else -1
    if p["ext_chimney"]:  # never on the gable that carries the chimney breast (sx below)
        end = ws if p["tower"] else -ws
    px = end * (Wr / 2 - 0.4) + lean_dx
    if style == "thatch":
        _ridge_pennant(b, k, px, top + rise + 1.4, -end)
    else:  # tile ridge sits lower than the rolled thatch ridge; fixed pole tint: no rng draw, rest unchanged
        _ridge_pennant(b, k, px, top + rise + 0.9, -end, pole_tint=0.5)
    if p["catslide"]:
        _outshut(b, W, D, z0, pitch, top)
    if p["dormers"] and style == "tile":
        for xd in ((-ws * Wr / 5,) if p["ext_chimney"] or not two else (-Wr / 4, Wr / 4)):
            windows += _dormer(b, xd + lean_dx, Dr, top, pitch, plaster, color, ridge_col, shutter)

    # --- chimney: through the roof, or an exterior stone breast on a gable end
    ch_lean = rng.uniform(0.02, 0.045) * rng.choice((-1, 1))
    if p["ext_chimney"]:
        sx = -ws if p["tower"] else ws
        _ext_chimney(b, sx * (W / 2 + 1.5), rng.uniform(-1.5, 1.5), top + rise + 3.5, ch_lean)
    else:
        cx = (-1 if p["chimney"] == "left" else 1) * (Wr / 2 - 2.2)
        ch_h = top + rise + 4.2 - z0
        b.add([pc.move(cx + lean_dx, Dr * 0.2, z0) for pc in kit.chimney(ch_h, 2.4, "stone", "stone_dark",
                                                                         lean=ch_lean, pots=rng.choice((1, 2)))])

    # --- stair tower on the front corner away from the door
    if p["tower"]:
        windows += _stair_tower(b, k, ws * (W / 2 - 0.6), -D / 2 + 0.6, top + 2.5)

    # --- lean-to woodshed with a mono-pitch roof and a log pile
    if p["lean_to"]:
        sx = -1 if p["chimney"] == "right" else 1
        lw, ld, lh = 6.0, D * 0.75, 7.6
        lx = sx * (W / 2 + lw / 2)
        b.add(kit.bbox(lw, ld, 0.6, "stone_dark", 0.12).move(lx, 0, 0))
        for yy in (-ld / 2 + 0.4, ld / 2 - 0.4):
            b.add(kit.bbox(0.7, 0.7, lh - 0.6, "wood", 0.08).move(lx + sx * (lw / 2 - 0.4), yy, 0.6))
        sl = kit.bbox(lw + 1.8, ld + 1.4, 0.55, "wood_light" if style == "thatch" else kingdom_color(k, "roof"), 0.12)
        b.add(sl.rotate(sx * math.radians(17), "Y").move(lx, 0, lh + (lw / 2 - 0.4) * math.tan(math.radians(17)) + 0.3),
              tag="roof")
        logs = 0
        for row in range(3):
            for j in range(4 - row):
                xx = lx - sx * 0.2 - 1.8 + j * 1.22 + row * 0.6
                zz = 0.6 + 0.6 + row * 1.04
                b.add(cylinder(0.6, 0.6, ld * 0.8, 7, "bark").rotate(math.pi / 2, "X").move(xx, ld * 0.4, zz))
                b.add(cylinder(0.45, 0.45, 0.1, 7, "wood_pale").rotate(math.pi / 2, "X").move(xx, -ld * 0.4 + 0.02, zz))
                logs += 1
        b.stats["logs"] = logs

    # --- props by the door
    bx = dx + (3.2 if dx <= 0 else -3.2)
    barrel = lathe([(0.0, 0.0), (1.0, 0.0), (1.18, 1.0), (1.18, 1.5), (1.0, 2.5), (0.0, 2.5)], 8, "wood")
    b.add(barrel.move(bx, -D / 2 - 2.0, 0))
    for zz in (() if p["wing"] else (0.5, 1.85)):
        b.add(cylinder(1.17, 1.17, 0.18, 8, "iron_dark").move(bx, -D / 2 - 2.0, zz))
    if not (p["wing"] or p["tower"]):
        b.add(kit.bbox(2.0, 2.0, 2.0, "wood_light", 0.12).rotate(0.3, "Z").move(bx + (2.4 if bx > dx else -2.4),
                                                                              -D / 2 - 2.4, 0))

    b.stats["windows"] = windows
    b.stats["pieces"] = len(b.pieces)
    b.stats["roof"] = b.count_tag("roof")


def _wing(b, p, k, xw, yfront, Ww, Dw, z0, h1, plinth_h, plaster, shutter, thatch_tone, ws):
    """Front-gabled wing (L-plan) projecting Dw from the main front wall at x=xw. Returns windows added."""
    rng = b.rng
    yc = yfront - Dw / 2
    e = 0.35
    b.add(kit.bbox(Ww + 2 * e, Dw + e, plinth_h, "stone", 0.15).move(xw, yc - e / 2, 0).paint(grad=("range", 0.2, 0.7)))
    b.add(kit.bbox(Ww, Dw + 0.4, h1, plaster, 0.2).move(xw, yc + 0.2, z0).paint(grad=("range", 0.35, 0.85)))
    fr = kit.wall_face_frame(Ww, h1, "x", yfront - Dw, "timber", posts=3, braces=True, rng=rng, skip=(1,))
    b.add([f.move(xw, 0, z0) for f in fr])
    for sx in (-1, 1):
        fr = kit.wall_face_frame(Dw, h1, "y", xw + sx * Ww / 2, "timber", posts=2, braces=False, rng=rng)
        b.add([f.move(0, yc, z0) for f in fr])
    pitch = rng.uniform(46, 52)
    style = p["roof"]
    color = thatch_tone if style == "thatch" else kingdom_color(k, "roof")
    ridge = "thatch_dark" if style == "thatch" else kingdom_color(k, "roof_dark")
    roof, rise = kit.gable_roof(Ww, Dw + 1.2, pitch, overhang=1.2, gable_overhang=0.9, thickness=0.6, color=color,
                                rows=3, ridge_color=ridge, style=style, rng=rng, pins=False)
    for pc in roof:
        b.add(pc.move(xw, yc + 0.6, z0 + h1), tag="roof")
    b.add(kit.gable_end(Ww, rise, 0.8, plaster).move(xw, yfront - Dw + 0.4, z0 + h1).paint(grad=("range", 0.5, 0.85)))
    yg = yfront - Dw - 0.1
    b.add(kit.oriented_box((xw - Ww / 2 + 0.4, yg, z0 + h1 + 0.35), (xw + Ww / 2 - 0.4, yg, z0 + h1 + 0.35),
                           kit.TIMBER, 0.4, "timber", Vector((0, -1, 0))))
    for pc in kit.window(1.6, 2.0, "timber", None, mullion=False):
        b.add(pc.move(xw, yg + 0.1, z0 + h1 + 0.9))
    return 1


def _dormer(b, xd, Dr, top, pitch, plaster, roof_color, ridge_color, shutter):
    """Gabled dormer on the front (-Y) slope of the main roof. Returns windows added."""
    t = math.tan(math.radians(pitch))
    yd = -Dr / 2 + 1.3
    wd, dd, hd = 4.8, 5.5, 4.2
    zb = top + (Dr / 2 - abs(yd)) * t - 0.6
    b.add(kit.bbox(wd, dd, hd, plaster, 0.12).move(xd, yd + dd / 2, zb).paint(grad=("range", 0.45, 0.85)))
    roof, rise = kit.gable_roof(wd, dd, 48, overhang=0.6, gable_overhang=0.5, thickness=0.5, color=roof_color,
                                rows=2, ridge_color=ridge_color, style="tile", trim="timber", sag=0.0)
    for pc in roof:
        b.add(pc.move(xd, yd + dd / 2, zb + hd), tag="roof")
    b.add(kit.gable_end(wd, rise, 0.5, plaster).move(xd, yd + 0.25, zb + hd))
    for pc in kit.window(2.0, 2.3, "timber", shutter, open_angle=0.5):
        b.add(pc.move(xd, yd, zb + 0.9))
    return 1


def _porch(b, dx, yfront, color):
    """Small gabled porch over the door on two posts."""
    pw, pd, ph = 7.0, 4.2, 8.6
    for sx in (-1, 1):
        b.add(kit.bbox(0.7, 0.7, ph, "wood", 0.08).move(dx + sx * (pw / 2 - 0.6), yfront - pd + 0.5, 0))
        b.add(kit.oriented_box((dx + sx * (pw / 2 - 0.6), yfront - pd + 0.5, ph - 1.6),
                               (dx + sx * (pw / 2 - 1.8), yfront - pd + 0.5, ph - 0.1), 0.4, 0.4, "timber"))
    b.add(box(pw, 0.6, 0.6, "timber").move(dx, yfront - pd + 0.5, ph - 0.3))
    roof, rise = kit.gable_roof(pw - 0.6, pd + 0.4, 42, overhang=0.7, gable_overhang=0.4, thickness=0.45,
                                color=color, rows=3, ridge_color="wood_dark", style="tile", trim="timber", sag=0.1)
    for pc in roof:
        b.add(pc.move(dx, yfront - pd / 2 + 0.2, ph + 0.2), tag="roof")


def _outshut(b, W, D, z0, pitch, top):
    """Rear outshut under a catslide roof: a low plaster-and-timber room along the back wall."""
    depth = 4.6
    yb = D / 2 + depth / 2 - 0.2
    hh = max(5.5, (top - z0) - (depth + 1.5) * math.tan(math.radians(pitch)) - 0.4)
    b.add(kit.bbox(W - 0.6, depth + 0.4, 1.4, "stone", 0.12).move(0, yb, 0))
    b.add(kit.bbox(W - 0.6, depth, hh, "plaster", 0.15).move(0, yb, z0).paint(grad=("range", 0.35, 0.8)))
    fr = kit.wall_face_frame(W - 0.6, hh, "x", D / 2 + depth - 0.2, "timber", posts=4, braces=False, rng=b.rng)
    b.add([f.move(0, 0, z0) for f in fr])
    for pc in kit.window(2.2, 2.4, "timber", None):
        b.add(pc.rotate(math.pi, "Z").move(W * 0.2, D / 2 + depth - 0.2, z0 + 2.4))


def _ext_chimney(b, x, y, top_z, lean):
    """Exterior chimney breast against a gable end: wide stepped base, tall leaning stack."""
    sx = 1 if x > 0 else -1
    base_w, base_d, base_h = 5.0, 3.0, 11.0
    b.add(kit.bbox(base_d, base_w, base_h, "stone", 0.2).move(x, y, 0).paint(grad=("range", 0.2, 0.75)))
    b.add(kit.bbox(base_d + 0.5, base_w + 0.5, 0.6, "stone_dark", 0.12).move(x, y, base_h))
    b.add(bevel(frustum_box(base_d - 0.2, base_w - 0.2, 2.8, 3.2, 2.6, "stone"), 0.12).move(x - sx * 0.1, y, base_h + 0.6))
    stack_h = top_z - (base_h + 3.2)
    for pc in kit.chimney(stack_h, 3.0, "stone", "stone_dark", lean=lean * 0.6, pots=2):
        b.add(pc.move(x - sx * 0.1, y, base_h + 3.2))


def _stair_tower(b, k, x, y, height):
    """Round stair turret on a front corner with a conical kingdom roof. Returns windows added."""
    r = 3.0
    b.add(cylinder(r + 0.5, r + 0.3, 1.6, 8, "stone").move(x, y, 0))
    b.add(cylinder(r, r * 0.94, height, 8, "plaster").move(x, y, 1.4).paint(grad=("range", 0.35, 0.85)))
    b.add(cylinder(r + 0.25, r + 0.25, 0.6, 8, "timber").move(x, y, height * 0.55))
    b.add(cylinder(r + 0.35, r + 0.35, 0.6, 8, "timber").move(x, y, height + 0.9))
    for pc in kit.cone_roof(r * 1.05, 6.2, seg=8, color=kingdom_color(k, "roof"), overhang=1.3, rows=1,
                            finial=kingdom_color(k, "trim")):
        b.add(pc.move(x, y, height + 1.4), tag="roof")
    n = 0
    for z, a in ((height * 0.32, -0.5), (height * 0.72, 0.5)):
        for pc in kit.window(1.2, 2.0, "timber", None, mullion=False):
            b.add(pc.move(0, -r + 0.05, 0).rotate(a, "Z").move(x, y, z))
        n += 1
    return n


def _ridge_pennant(b, k, x, z, inward, pole_tint=None):
    """Kingdom pennant on a pole at the ridge end: a square banner of kingdom cloth flying `inward` (+-1)
    along the ridge, facing the street and the back, with the kingdom emblem (D-039) filling it, so the
    cottage reads by kingdom at 80 studs by shape, not colour alone (D-033). The pole takes the only rng draw
    (its tint) unless `pole_tint` is given; everything else has a fixed tint."""
    W, H, T = PENNANT_W, PENNANT_H, PENNANT_T
    b.add(cylinder(0.17, 0.17, 6.5, 3, "timber").move(x, 0, z - 0.6), tint=pole_tint)
    cx, cz = x + inward * (W / 2 + 0.1), z + 5.6 - H / 2
    b.add(box(W, T, H, field(k), base=False).move(cx, 0, cz), tint=0.5)
    for pc in _pennant_emblem(k, W, H, T):
        b.add(pc.move(cx, 0, cz), tint=0.5, grad=("range", 0.55, 0.95))


def _pennant_emblem(k, W, H, T, margin=0.24):
    """The kit-wide emblem of kingdom k (`_kingdom_props_common` outlines) as cheap prisms filling a W x H
    cloth `T` thick, centred on the origin. Every part passes through the cloth and stands proud of both
    faces, so the emblem reads from the front and the back of the pennant."""
    d = T + 0.16  # emblem body: 0.08 proud of each face
    hw, hh = W / 2 - margin, H / 2 - margin
    kind = PENNANT_EMBLEM[k]
    if kind == "crown":  # gold crown, ivory band and gems (flat-sided gems: cheap, ~2 px at 80 studs)
        s = min(hw / 1.04, hh / 0.99)
        pts, (bx, bz, bw, bh), gems = crown_outlines(s)
        dz = -0.12 * s  # centre the crown body (-0.62 s .. 0.86 s; the top gem reaches 1.11 s)
        gold, ivory = emblem_colors(k, "crown")
        out = [prism([(x, z + dz) for x, z in pts], d, gold),
               box(bw, d + 0.08, bh, ivory, base=False).move(bx, 0, bz + dz)]
        for gx, gz, gr in gems:
            gem = lathe([(0.0, -gr), (gr, 0.0), (0.0, gr)], 3, ivory, phase=math.pi / 2)
            out.append(gem.rotate(math.pi / 2, "X").move(gx, 0, gz + dz))
        return out
    if kind == "oak":  # ivory leaf (flat-topped lobes), bronze midrib and stem: light on the bright emerald
        s = min(hw / 0.8, hh / 1.175)
        leaf, (mx, mz, mw, mh), (sx, sz, sw, sh) = oak_outlines(s, lobe_pts=2)
        dz = 0.115 * s  # centre leaf + stem (-1.29 s .. 1.06 s)
        ivory, bronze = emblem_colors(k, "oak")
        return [prism([(x, z + dz) for x, z in leaf], d, ivory),
                box(mw, d + 0.08, mh, bronze, base=False).move(mx, 0, mz + dz),
                box(sw, d, sh, bronze, base=False).move(sx, 0, sz + dz)]
    if kind == "star":  # ivory star with the small silver star at its heart
        s = min(hw / 0.951, hh / 0.905)
        ivory, silver = emblem_colors(k, "star")
        outer, inner = emblem("star", 2 * s, ivory, silver, depth=d, mid=None)
        inner.move(0, d * 0.6, 0).scale(1.0, 1.4, 1.0)  # centred, proud of the star on both faces
        return [pc.move(0, 0, -0.095 * s) for pc in (outer, inner)]  # centre the points (-0.81 s .. s)
    # sun on gold cloth: never gold on gold (D-033), so the kit sun sits on an ivory roundel with a bronze rim
    r = min(hw, hh)
    out = []
    for rr, dd, col in ((r, T + 0.06, SUN_RIM), (r * 0.88, T + 0.12, SUN_FIELD)):
        out.append(cylinder(rr, rr, dd, 12, col).rotate(math.pi / 2, "X").move(0, dd / 2, 0))
    rays, disc = sun_outlines(r / SUN_ROUNDEL)
    out.append(prism(rays, T + 0.2, SUN_RAYS))
    out.append(prism(disc, T + 0.28, SUN_DISC))
    return out


def _kingdom_banner(b, k, x, y, z):
    """Hanging kingdom banner on the front wall (top at z)."""
    b.add(box(3.0, 0.3, 0.3, "timber").move(x, y - 0.35, z))
    b.add(box(2.4, 0.18, 4.2, kingdom_color(k, "cloth")).move(x, y - 0.45, z - 4.2), tint=0.5)
    b.add(box(1.0, 0.2, 1.0, kingdom_color(k, "emblem")).rotate(math.radians(45), "Y").move(x, y - 0.55, z - 2.0))
