"""Village cottage: stone plinth, plaster + timber frame (or kingdom-stone ground floor),
optional jettied upper storey, layered thatch or kingdom-tile roof, chimney, shutters in
the kingdom colour, optional lean-to woodshed, door props.

Front (door) faces Blender -Y (Roblox -Z, the Model's front). Door is walkable (4.4 x 7.6).
"""

import math

from lib import kit
from lib.geo import Vector, box, cylinder, lathe
from lib.palette import kingdom_color

NAME = "house_cottage"
VERSION = 2
CATEGORY = "house"
BUDGET = "building_small"
COLLISION = {"fidelity": "PreciseConvexDecomposition"}
CHECKS = {"min_pieces": 60, "min_windows": 3, "min_roof": 2}
DEFAULT_VARIANTS = 6

KINGDOM_CYCLE = ("red", "blue", "green", "yellow")


def variants(n, seed):
    out = []
    for i in range(n):
        out.append({
            "kingdom": KINGDOM_CYCLE[i % 4],
            "storeys": 1 if i % 3 == 0 else 2,
            "roof": "thatch" if i % 2 == 0 else "tile",
            "ground": "stone" if i % 4 in (1, 2) else "plaster",
            "lean_to": i % 3 == 1 or i == 4,
            "chimney": "left" if i % 2 else "right",
            "seed": seed * 1000 + i,
        })
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

    # --- plinth: stone blocks around a solid core
    e = 0.35
    pts = [(-W / 2 - e, -D / 2 - e, 0), (W / 2 + e, -D / 2 - e, 0), (W / 2 + e, D / 2 + e, 0),
           (-W / 2 - e, D / 2 + e, 0), (-W / 2 - e, -D / 2 - e, 0)]
    b.add(kit.stone_course(pts, plinth_h, 1.0, "stone", rng, block=(2.6, 4.2), bev=0.12,
                           colors=("stone", "stone_light", "stone")))
    b.add(box(W, D, plinth_h, "stone_dark"))

    # --- ground floor
    z0 = plinth_h
    dx = rng.choice((-1, 1)) * rng.uniform(W * 0.08, W * 0.2)
    if p["ground"] == "stone":
        b.add(kit.bbox(W, D, h1, kingdom_color(k, "stone"), 0.2).move(0, 0, z0).paint(grad=("range", 0.2, 0.8)))
        for sx in (-1, 1):
            for sy in (-1, 1):
                for j in range(int(h1 // 1.9)):
                    big = j % 2 == 0
                    q = box(1.9 if big else 1.2, 1.2 if big else 1.9, 1.7, kingdom_color(k, "stone_light"))
                    q.move(sx * (W / 2 - (0.75 if big else 0.4)) + sx * 0.18,
                           sy * (D / 2 - (0.4 if big else 0.75)) + sy * 0.18, z0 + 0.12 + j * 1.9)
                    b.add(q)
        # string course under the eaves
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

    # ground floor windows: front, one side, back
    wx = dx + (-1 if dx > 0 else 1) * W * 0.33
    b.add([pc.move(wx, -D / 2, z0 + kit.SILL_Z) for pc in kit.window(kit.WIN_W, kit.WIN_H, "timber", shutter)])
    windows += 1
    side = rng.choice((-1, 1))
    for pc in kit.window(kit.WIN_W, kit.WIN_H, "timber", shutter):
        b.add(pc.rotate(side * math.pi / 2, "Z").move(side * W / 2, rng.uniform(-1.5, 1.5), z0 + kit.SILL_Z))
    windows += 1
    for pc in kit.window(kit.WIN_W, kit.WIN_H, "timber", None):
        b.add(pc.rotate(math.pi, "Z").move(rng.uniform(-W / 4, W / 4), D / 2, z0 + kit.SILL_Z))
    windows += 1

    # flower box under the front window
    b.add(kit.bbox(4.2, 1.0, 0.9, "wood", 0.1).move(wx, -D / 2 - 1.0, z0 + kit.SILL_Z - 1.35))
    b.add(kit.bbox(3.9, 0.8, 0.5, "leaf_mid", 0.15).move(wx, -D / 2 - 1.0, z0 + kit.SILL_Z - 0.5))
    for j in range(6):
        fl = lathe([(0.0, 0.0), (0.42, 0.2), (0.4, 0.55), (0.0, 0.75)], 5,
                   rng.choice(("flower_red", "flower_yellow", "flower_white", "flower_purple", "flower_red")))
        b.add(fl.move(wx - 1.6 + j * 0.64, -D / 2 - 1.0 + rng.uniform(-0.2, 0.2), z0 + kit.SILL_Z - 0.35))

    top = z0 + h1
    Wr, Dr = W, D
    if two:
        b.add(kit.bbox(W + 2 * jetty + 0.4, D + 2 * jetty + 0.4, 0.7, "timber", 0.1).move(0, 0, top))
        for i in range(8):  # joist ends under the jetty
            u = -W / 2 + 0.6 + (W - 1.2) * i / 7
            b.add(box(0.6, jetty + 0.4, 0.6, "timber").move(u, -D / 2 - jetty / 2, top - 0.55))
        top += 0.7
        Wr, Dr = W + 2 * jetty, D + 2 * jetty
        b.add(kit.bbox(Wr, Dr, h2, plaster, 0.18).move(0, 0, top).paint(grad=("range", 0.4, 0.85)))
        for off in (-Dr / 2, Dr / 2):
            fr = kit.wall_face_frame(Wr, h2, "x", off, "timber", posts=5, braces=True, rng=rng)
            b.add([f.move(0, 0, top) for f in fr])
        for off in (-Wr / 2, Wr / 2):
            fr = kit.wall_face_frame(Dr, h2, "y", off, "timber", posts=3, braces=False, rng=rng)
            b.add([f.move(0, 0, top) for f in fr])
        xs = [-Wr / 4.0, Wr / 4.0]
        for ux in xs:
            b.add([pc.move(ux, -Dr / 2, top + 2.6) for pc in kit.window(kit.WIN_W, kit.WIN_H * 0.9, "timber", shutter)])
            windows += 1
        top += h2

    # --- roof (ridge along X so the long side faces the street)
    style = p["roof"]
    pitch = rng.uniform(47, 54) if style == "thatch" else rng.uniform(40, 47)
    color = "thatch" if style == "thatch" else kingdom_color(k, "roof")
    ridge_col = "thatch_dark" if style == "thatch" else kingdom_color(k, "roof_dark")
    roof, rise = kit.gable_roof(Dr, Wr, pitch, overhang=1.5, gable_overhang=1.1, thickness=0.75, color=color,
                                rows=5, ridge_color=ridge_col, style=style, rng=rng)
    for pc in roof:
        b.add(pc.rotate(math.pi / 2, "Z").move(0, 0, top), tag="roof")
    for sx in (-1, 1):
        g = kit.gable_end(Dr, rise, 0.8, plaster)
        b.add(g.rotate(math.pi / 2, "Z").move(sx * (Wr / 2 - 0.4), 0, top).paint(grad=("range", 0.5, 0.85)))
        n = Vector((sx, 0, 0))
        xg = sx * (Wr / 2 + 0.1)
        b.add(kit.oriented_box((xg, -Dr / 2 + 0.5, top + 0.35), (xg, Dr / 2 - 0.5, top + 0.35), kit.TIMBER, 0.4,
                               "timber", n))
        b.add(kit.oriented_box((xg, 0, top + 0.6), (xg, 0, top + rise - 0.8), kit.TIMBER, 0.4, "timber", n))
        for s in (-1, 1):
            b.add(kit.oriented_box((xg, s * Dr * 0.36, top + 0.6), (xg, s * 0.4, top + rise * 0.62), kit.TIMBER * 0.8,
                                   0.4, "timber", n))

    # --- chimney on one gable, rising through the roof
    cx = (-1 if p["chimney"] == "left" else 1) * (Wr / 2 - 2.0)
    ch_h = top + rise + 2.8 - z0
    b.add([pc.move(cx, Dr * 0.2, z0) for pc in kit.chimney(ch_h, 2.4, "stone", "stone_dark")])

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
                lg = cylinder(0.6, 0.6, ld * 0.8, 7, "bark")
                lg.rotate(math.pi / 2, "X").move(lx - sx * 0.2 - 1.8 + j * 1.22 + row * 0.6, ld * 0.4,
                                                 0.6 + 0.6 + row * 1.04)
                b.add(lg)
                lg2 = cylinder(0.45, 0.45, 0.1, 7, "wood_pale")  # cut faces
                lg2.rotate(math.pi / 2, "X").move(lx - sx * 0.2 - 1.8 + j * 1.22 + row * 0.6, -ld * 0.4 + 0.02,
                                                  0.6 + 0.6 + row * 1.04)
                b.add(lg2)
                logs += 1
        b.stats["logs"] = logs

    # --- props by the door
    bx = dx + (3.2 if dx <= 0 else -3.2)
    barrel = lathe([(0.0, 0.0), (1.0, 0.0), (1.18, 1.0), (1.18, 1.5), (1.0, 2.5), (0.0, 2.5)], 8, "wood")
    b.add(barrel.move(bx, -D / 2 - 2.0, 0))
    for zz in (0.5, 1.85):
        b.add(cylinder(1.17, 1.17, 0.18, 8, "iron_dark").move(bx, -D / 2 - 2.0, zz))
    b.add(kit.bbox(2.0, 2.0, 2.0, "wood_light", 0.12).rotate(0.3, "Z").move(bx + (2.4 if bx > dx else -2.4),
                                                                          -D / 2 - 2.4, 0))

    b.stats["windows"] = windows
    b.stats["pieces"] = len(b.pieces)
    b.stats["roof"] = b.count_tag("roof")
