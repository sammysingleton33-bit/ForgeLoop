"""Village storehouse, two types:

* granary  - weatherboarded timber store raised on mushroom-shaped staddle stones (rats can't
             climb them), plank floor on bearers, kit door + vent windows with kingdom shutters,
             thatch or kingdom-tile roof, wooden stairs along the facade to a landing, a ladder,
             a gable hoist beam with pulley, rope and hanging sack, and grain sacks + a deposit
             pallet at the foot of the stairs.
* warehouse - stone or plaster/timber store on the kit plinth with the gable to the street,
             BIG double barn doors (one leaf ajar) in a heavy timber frame, a loft door and a
             hoist beam with a hanging crate, side windows, sacks, crates, a hand cart, a
             deposit pallet; optionally a lean-to cart shed.

Front faces Blender -Y. Sockets: `door` = ground-level entrance (granary: stair foot;
warehouse: in front of the double doors); `door_top` (granary only) = landing at the door;
`deposit` = drop point for carriers (on/at the deposit pallet).
"""

import math

from lib import kit
from lib.geo import box, cylinder, lathe
from lib.palette import kingdom_color

from generators import _civic_common as cc

NAME = "building_storehouse"
VERSION = 1
CATEGORY = "building"
BUDGET = "building_medium"
COLLISION = {"fidelity": "PreciseConvexDecomposition"}
CHECKS = {"min_pieces": 150, "min_windows": 2, "min_roof": 2, "min_sacks": 4}
DEFAULT_VARIANTS = 6

_TABLE = [
    dict(kind="granary", W=14.0, D=10.0, nx=4, ny=3, roof="thatch", stair=-1),
    dict(kind="warehouse", W=16.0, D=21.0, walls="stone", roof="tile", shed=0),
    dict(kind="granary", W=11.0, D=9.0, nx=3, ny=3, roof="tile", stair=1),
    dict(kind="warehouse", W=15.0, D=19.0, walls="timber", roof="thatch", shed=0),
    dict(kind="granary", W=17.0, D=10.0, nx=5, ny=3, roof="tile", stair=1),
    dict(kind="warehouse", W=16.5, D=22.0, walls="stone", roof="tile", shed=1),
]


def variants(n, seed):
    out = []
    for i in range(n):
        p = dict(_TABLE[i % len(_TABLE)])
        p["kingdom"] = cc.KINGDOM_CYCLE[i % 4]
        p["seed"] = seed * 1000 + 700 + i
        out.append(p)
    return out


# ------------------------------------------------------------------ shared props

STADDLE_H = 3.6


def _staddle():
    """Mushroom staddle stone: tapered pillar + overhanging cap (rats can't climb it)."""
    out = [lathe([(0.85, 0.0), (0.66, 0.4), (0.44, 2.85), (0.42, 3.05)], 6, "stone").paint(grad=("range", 0.2, 0.7))]
    out.append(lathe([(0.0, 2.98), (1.2, 3.05), (1.14, 3.38), (0.66, 3.57), (0.0, 3.6)], 7, "stone_light")
               .paint(grad=("range", 0.4, 0.95)))
    return out


def _pallet(rng, n_sacks=3):
    """Deposit pallet: low plank platform with grain sacks. Base z=0, 3.4 x 3.0."""
    out = [kit.bbox(3.4, 3.0, 0.22, "wood_dark", 0.06)]
    for j in range(3):
        out.append(box(3.4, 0.8, 0.16, rng.choice(("wood", "wood_light"))).move(0, -1.0 + j * 1.0, 0.22))
    for i in range(n_sacks):
        for pc in cc.sack(rng, 0.85, "canvas_dark" if i % 2 else "apron"):
            out.append(pc.rotate(rng.uniform(-0.4, 0.4), "Z").move(-1.0 + i * 1.0, rng.uniform(-0.5, 0.5), 0.38))
    return out


def _cart(rng):
    """Two-wheeled hand cart loaded with sacks, along X, base z=0."""
    out = [kit.bbox(4.2, 2.4, 0.3, "wood", 0.06).move(0, 0, 1.55)]
    for s in (-1, 1):
        out.append(box(4.2, 0.2, 0.6, "wood_light").move(0, s * 1.15, 1.85))
    out.append(box(0.2, 2.4, 0.6, "wood_light").move(2.05, 0, 1.85))
    for s in (-1, 1):
        out.append(cylinder(1.25, 1.25, 0.3, 10, "wood_dark").rotate(math.pi / 2, "X").move(0.4, s * 1.35 + (0.3 if s > 0 else 0.0), 1.25))
        out.append(cylinder(0.35, 0.35, 0.5, 6, "iron_dark").rotate(math.pi / 2, "X").move(0.4, s * 1.35 + (0.4 if s > 0 else 0.1), 1.25))
        out.append(kit.oriented_box((-1.9, s * 0.85, 1.7), (-3.9, s * 0.8, 0.0), 0.28, 0.28, "wood", (0, 0, 1)))
    for i in range(2):
        for pc in cc.sack(rng, 0.8, lying=True):
            out.append(pc.rotate(math.pi / 2, "Z").move(-0.9 + i * 1.6, 0.0, 1.85))
    return out


def _barn_leaf(w, h, color, s):
    """Plank barn-door leaf hinged at x=0, extending towards s*X, facing -Y, base z=0."""
    out = []
    n = 3
    for i in range(n):
        out.append(box(w / n - 0.08, 0.3, h, color).move(s * w * (i + 0.5) / n, 0, 0).paint(grad=("range", 0.3, 0.85)))
    for z in (0.55, h - 1.15):
        out.append(box(w - 0.12, 0.2, 0.6, "timber").move(s * w / 2, -0.24, z))
    out.append(kit.oriented_box((s * 0.4, -0.24, 1.15), (s * (w - 0.4), -0.24, h - 1.15), 0.5, 0.2, "timber",
                                (0, -1, 0)))
    for z in (1.0, h - 1.5):
        out.append(box(w * 0.55, 0.12, 0.26, "iron_dark").move(s * w * 0.27, -0.4, z))
    out.append(box(0.24, 0.3, 0.7, "iron").move(s * (w - 0.45), -0.45, h * 0.42))
    return out


def _sign(b, icon, x, y, z, side):
    for pc in cc.hanging_sign(icon, "wheat", side=side, arm=2.8, w=2.4, h=1.7, board="wood"):
        b.add(pc.move(x, y, z))


# ------------------------------------------------------------------ granary

def _granary(b, rng, k, p):
    W = p["W"] + rng.uniform(-0.3, 0.3)
    D = p["D"] + rng.uniform(-0.2, 0.2)
    shutter = kingdom_color(k, "shutter")
    sd = p["stair"]  # stairs descend towards sd * X
    nx, ny = p["nx"], p["ny"]
    SH = STADDLE_H
    xs = [-W / 2 + 1.0 + (W - 2.0) * i / (nx - 1) for i in range(nx)]
    ys = [-D / 2 + 1.0 + (D - 2.0) * j / (ny - 1) for j in range(ny)]
    for x in xs:
        for y in ys:
            for pc in _staddle():
                b.add(pc.move(x + rng.uniform(-0.08, 0.08), y + rng.uniform(-0.08, 0.08), 0))
    b.stats["staddles"] = nx * ny
    for y in ys:
        b.add(box(W + 0.5, 0.8, 0.7, "timber").move(0, y, SH))
    for x in xs:  # joist ends
        b.add(box(0.6, D + 0.9, 0.5, "timber").move(x, 0, SH + 0.45))
    b.add(kit.bbox(W + 1.0, D + 1.0, 0.45, "wood", 0.1).move(0, 0, SH + 0.9))
    FZ = SH + 1.35
    Hw = 9.0
    b.add(box(W, D, Hw, "wood_dark").move(0, 0, FZ))
    # weatherboards with a slight lap (bottom edge kicks out)
    bh = 1.12
    nb = int(Hw / bh)
    for j in range(nb):
        z = FZ + j * bh + 0.05
        col = rng.choice(("wood", "wood", "wood_light"))
        for s in (-1, 1):
            bd = box(W + 0.2, 0.22, bh + 0.04, col).rotate(s * 0.07, "X").move(0, s * (D / 2 + 0.06), z)
            b.add(bd.paint(tint=rng.uniform(0.1, 0.9), grad=("range", 0.35, 0.8)))
            bd = box(0.22, D + 0.2, bh + 0.04, col).rotate(-s * 0.07, "Y").move(s * (W / 2 + 0.06), 0, z)
            b.add(bd.paint(tint=rng.uniform(0.1, 0.9), grad=("range", 0.35, 0.8)))
    # timber frame over the boards: corner posts, mid posts, top plate, braces
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.add(kit.bbox(0.85, 0.85, Hw + 0.2, "timber", 0.08).move(sx * (W / 2 + 0.1), sy * (D / 2 + 0.1), FZ - 0.1))
    dx = -sd * W * 0.12
    for off in (-D / 2 - 0.2, D / 2 + 0.2):
        nposts = max(3, nx)
        px = [-W / 2 + W * i / (nposts - 1) for i in range(nposts)]
        for i, x in enumerate(px[1:-1]):
            if off < 0 and abs(x - dx) < 3.2:
                continue
            b.add(box(0.6, 0.4, Hw, "timber").move(x, off, FZ))
        b.add(box(W + 0.6, 0.45, 0.6, "timber").move(0, off, FZ + Hw - 0.6))
    for s in (-1, 1):
        n = (s, 0, 0)
        x = s * (W / 2 + 0.24)
        b.add(kit.oriented_box((x, -D / 2 + 0.4, FZ + 0.3), (x, -0.4, FZ + Hw * 0.62), kit.TIMBER * 0.8, 0.4, "timber", n))
        b.add(kit.oriented_box((x, D / 2 - 0.4, FZ + 0.3), (x, 0.4, FZ + Hw * 0.62), kit.TIMBER * 0.8, 0.4, "timber", n))
        b.add(box(0.4, D + 0.6, 0.6, "timber").move(x, 0, FZ + Hw - 0.6))
    # door (kingdom colour) with a timber frame, landing, stairs along the facade
    b.add([pc.move(dx, -D / 2 - 0.22, FZ) for pc in kit.door(kit.DOOR_W, kit.DOOR_H, shutter, "timber", arched=False,
                                                            step=None)])
    windows = 0
    for wx in (dx + sd * W * 0.32, dx - sd * W * 0.3):
        if abs(wx) > W / 2 - 1.6:
            continue
        b.add([pc.move(wx, -D / 2 - 0.22, FZ + 4.4) for pc in kit.window(2.0, 2.0, "timber", shutter, mullion=False)])
        windows += 1
    for wx in (-W * 0.25, W * 0.25):
        b.add([pc.rotate(math.pi, "Z").move(wx, D / 2 + 0.22, FZ + 4.4)
               for pc in kit.window(2.0, 2.0, "timber", shutter, mullion=False)])
        windows += 1
    LW, LD = 5.6, 2.6
    ly = -D / 2 - 0.3 - LD / 2
    b.add(kit.bbox(LW, LD, 0.4, "wood", 0.08).move(dx, ly, FZ - 0.4))
    for s in (-1, 1):
        b.add(box(0.5, 0.5, FZ - 0.4, "timber").move(dx + s * (LW / 2 - 0.3), ly - LD / 2 + 0.3, 0))
    nst, run = 5, 0.95
    x0 = dx + sd * LW / 2
    for i in range(1, nst + 1):
        zt = FZ * (nst + 1 - i) / (nst + 1)
        xt = x0 + sd * (i - 0.5) * run
        b.add(box(run + 0.08, LD - 0.2, 0.26, rng.choice(("wood", "wood_light"))).move(xt, ly, zt - 0.26))
    xe = x0 + sd * nst * run
    for yy in (ly - LD / 2 + 0.15, ly + LD / 2 - 0.15):
        b.add(kit.oriented_box((x0, yy, FZ - 0.3), (xe + sd * 0.4, yy, 0.0), 0.3, 0.5, "timber", (0, 1, 0)))
    # hand rail on the outer side of landing + stairs
    yr_ = ly - LD / 2 + 0.1
    for xx, zz in ((dx - sd * (LW / 2 - 0.2), FZ), (x0, FZ), (xe, 0.0)):
        b.add(box(0.3, 0.3, 3.2, "timber").move(xx, yr_, zz))
    b.add(kit.oriented_box((dx - sd * (LW / 2 - 0.2), yr_, FZ + 3.1), (x0, yr_, FZ + 3.1), 0.25, 0.25, "wood", (0, -1, 0)))
    b.add(kit.oriented_box((x0, yr_, FZ + 3.1), (xe, yr_, 3.1), 0.25, 0.25, "wood", (0, -1, 0)))
    foot_x = xe + sd * 1.4
    b.socket("door", foot_x, ly, 0.0)
    b.socket("door_top", dx, ly, FZ)

    # roof (ridge along X) + board gable ends + hoist on one gable
    top = FZ + Hw
    style = p["roof"]
    pitch = 50.0 if style == "thatch" else 46.0
    color = "thatch" if style == "thatch" else kingdom_color(k, "roof")
    ridge_col = "thatch_dark" if style == "thatch" else kingdom_color(k, "roof_dark")
    Dr = D + 0.6
    roof, rise = kit.gable_roof(Dr, W + 0.6, pitch, overhang=1.5, gable_overhang=1.2, thickness=0.75, color=color,
                                rows=5, ridge_color=ridge_col, style=style, rng=rng)
    for pc in roof:
        b.add(pc.rotate(math.pi / 2, "Z").move(0, 0, top), tag="roof")
    for sx in (-1, 1):
        g = kit.gable_end(Dr, rise, 0.8, "wood")
        b.add(g.rotate(math.pi / 2, "Z").move(sx * (W / 2 - 0.2), 0, top).paint(grad=("range", 0.3, 0.75)))
        xg = sx * (W / 2 + 0.25)
        n = (sx, 0, 0)
        for j in range(1, 4):
            yy = Dr / 2 * (1 - j / 4.0)
            for s in (-1, 1):
                b.add(kit.oriented_box((xg, s * yy, top), (xg, s * yy, top + (Dr / 2 - yy) * math.tan(math.radians(pitch)) - 0.4),
                                       0.3, 0.35, "wood_dark", n))
    hsd = -sd  # hoist on the gable away from the stairs
    xg = hsd * (W / 2 + 0.3)
    b.add([pc.rotate(-hsd * math.pi / 2, "Z").move(xg, 0, top + 0.2)
           for pc in kit.door(2.6, 3.2, shutter, "timber", arched=False, step=None)])
    bz = top + 4.0
    b.add(box(4.6, 0.75, 0.75, "timber").move(hsd * (W / 2 + 1.6), 0, bz))
    b.add(kit.oriented_box((hsd * (W / 2 + 0.3), 0, bz - 1.8), (hsd * (W / 2 + 1.9), 0, bz + 0.1), 0.4, 0.4, "timber",
                           (0, 1, 0)))
    for pc in cc.rope_hoist((hsd * (W / 2 + 3.4), 0.5, bz), bz - FZ - 1.0, "sack", rng):
        b.add(pc)
    # ladder against the stair-side gable up to a vent
    lx = sd * (W / 2 + 0.35)
    for pc in cc.ladder((0, -2.6, 0.0), (0, 0.0, FZ + 5.5), 1.7):
        b.add(pc.rotate(sd * math.pi / 2, "Z").move(lx, D * 0.18, 0))
    b.add([pc.rotate(-sd * math.pi / 2, "Z").move(lx - sd * 0.12, D * 0.18, FZ + 5.0)
           for pc in kit.window(1.6, 1.6, "timber", shutter, mullion=False)])
    windows += 1

    # sacks at the stair foot (outside the footprint), deposit pallet under the hoist, crates
    sacks = 0
    for pc in cc.sack_pile(rng, 3, 2.6, 1.0):
        b.add(pc.rotate(sd * math.pi / 2, "Z").move(foot_x + sd * 1.6, ly + 1.2, 0))
    sacks += 3
    for pc in cc.sack_pile(rng, 2, 1.6, 0.85):
        b.add(pc.move(dx + sd * 1.0, ly + 0.3, FZ))
    sacks += 2
    px, py = hsd * (W / 2 + 3.4), -0.4
    for pc in _pallet(rng, 3):
        b.add(pc.rotate(math.pi / 2, "Z").move(px, py, 0))
    sacks += 3
    b.socket("deposit", px + hsd * 2.2, py, 0.0)
    for pc in cc.crate_stack(rng, 3, 1.9, "wood_light"):
        b.add(pc.rotate(math.pi / 2 + 0.2, "Z").move(px + hsd * 0.2, D / 2 + 1.4, 0))
    for pc in cc.basket(rng, 0.9, 0.9, "apple"):
        b.add(pc.move(px + hsd * 0.6, -D / 2 - 1.6, 0))
    _sign(b, "sheaf", sd * (W / 2 + 0.55), -D / 2 - 0.3, FZ + Hw - 1.0, sd)
    b.stats["sacks"] = sacks
    b.stats["windows"] = windows


# ------------------------------------------------------------------ warehouse

def _warehouse(b, rng, k, p):
    W = p["W"] + rng.uniform(-0.3, 0.3)
    D = p["D"] + rng.uniform(-0.3, 0.3)
    shutter = kingdom_color(k, "shutter")
    PH = 1.3
    H = 12.4
    stone = p["walls"] == "stone"
    plaster = rng.choice(("plaster", "plaster", "plaster_white"))
    for pc in cc.plinth(W, D, PH, rng, "stone_dark"):
        b.add(pc)
    z0 = PH
    DW, DH = 8.0, 9.0
    if stone:
        b.add(kit.bbox(W, D, H, kingdom_color(k, "stone"), 0.2).move(0, 0, z0).paint(grad=("range", 0.2, 0.8)))
        for sx in (-1, 1):
            for sy in (-1, 1):
                for j in range(int(H // 1.9)):
                    big = j % 2 == 0
                    q = box(1.9 if big else 1.2, 1.2 if big else 1.9, 1.7, kingdom_color(k, "stone_light"))
                    q.move(sx * (W / 2 - (0.75 if big else 0.4)) + sx * 0.18,
                           sy * (D / 2 - (0.4 if big else 0.75)) + sy * 0.18, z0 + 0.12 + j * 1.9)
                    b.add(q)
        b.add(kit.bbox(W + 0.5, D + 0.5, 0.55, kingdom_color(k, "stone_dark"), 0.12).move(0, 0, z0 + H - 0.55))
        cols = (kingdom_color(k, "stone_light"), kingdom_color(k, "stone_dark"))
        for off in (-W / 2, W / 2):
            b.add(cc.wall_stones(rng, D, H - 0.6, "y", off, 10, cols, z0))
        b.add(cc.wall_stones(rng, W, H - 0.6, "x", D / 2, 5, cols, z0))
        seg = W / 2 - DW / 2 - 1.0  # front wall beside the door frame
        for s_ in (-1, 1):
            b.add([st.move(s_ * (DW / 2 + 1.0 + seg / 2), 0, 0)
                   for st in cc.wall_stones(rng, seg, H - 0.6, "x", -D / 2, 2, cols, z0, margin=0.9)])
    else:
        b.add(kit.bbox(W, D, H, plaster, 0.2).move(0, 0, z0).paint(grad=("range", 0.35, 0.85)))
        b.add([f.move(0, 0, z0) for f in kit.wall_face_frame(W, H, "x", -D / 2, "timber", posts=5, braces=True,
                                                               rng=rng, skip=(1, 2, 3))])
        b.add([f.move(0, 0, z0) for f in kit.wall_face_frame(W, H, "x", D / 2, "timber", posts=5, braces=True,
                                                               rng=rng, rail=H * 0.5)])
        for off in (-W / 2, W / 2):
            b.add([f.move(0, 0, z0) for f in kit.wall_face_frame(D, H, "y", off, "timber", posts=6, braces=True,
                                                                   rng=rng, rail=H * 0.48)])

    # big double barn doors in a heavy timber frame; right leaf ajar
    fy = -D / 2
    b.add(box(DW, 0.3, DH, "window_dark").move(0, fy - 0.05, z0))
    for s in (-1, 1):
        b.add(kit.bbox(0.95, 1.0, DH + 0.95, "timber", 0.08).move(s * (DW / 2 + 0.47), fy - 0.35, z0 - 0.05))
        b.add(cc.knee_brace((s * (DW / 2 + 0.3), fy - 0.75, z0 + DH - 1.9), (s * (DW / 2 - 1.2), fy - 0.75, z0 + DH + 0.1),
                            (0, -1, 0)))
    b.add(kit.bbox(DW + 3.2, 1.1, 1.0, "timber", 0.1).move(0, fy - 0.4, z0 + DH))
    for pc in _barn_leaf(DW / 2 - 0.05, DH - 0.1, shutter, 1):
        b.add(pc.move(-DW / 2, fy - 0.5, z0 + 0.05))
    for pc in _barn_leaf(DW / 2 - 0.05, DH - 0.1, shutter, -1):
        b.add(pc.rotate(math.radians(62), "Z").move(DW / 2, fy - 0.5, z0 + 0.05))
    b.add(kit.bbox(DW + 2.4, 2.4, PH + 0.02, "stone_light", 0.12).move(0, fy - 1.2, 0))  # threshold ramp/step
    b.add(kit.bbox(DW + 1.2, 1.4, PH * 0.5, "stone", 0.1).move(0, fy - 2.9, 0))
    b.socket("door", 0.0, fy - 4.4, 0.0)

    windows = 0
    # side windows (upper half) with kingdom shutters
    for sx in (-1, 1):
        for j in range(3):
            wy = -D / 2 + D * (j + 0.5) / 3
            b.add([pc.rotate(-sx * math.pi / 2, "Z").move(sx * W / 2, wy, z0 + kit.SILL_Z + 3.0)
                   for pc in kit.window(kit.WIN_W, kit.WIN_H, "timber", shutter)])
            windows += 1
    for wx in (-W * 0.25, W * 0.25):
        b.add([pc.rotate(math.pi, "Z").move(wx, D / 2, z0 + kit.SILL_Z + 3.0)
               for pc in kit.window(kit.WIN_W, kit.WIN_H, "timber", shutter)])
        windows += 1

    # roof: ridge along Y, gable to the street
    top = z0 + H
    style = p["roof"]
    pitch = 50.0 if style == "thatch" else 45.0
    color = "thatch" if style == "thatch" else kingdom_color(k, "roof")
    ridge_col = "thatch_dark" if style == "thatch" else kingdom_color(k, "roof_dark")
    roof, rise = kit.gable_roof(W, D, pitch, overhang=1.5, gable_overhang=1.2, thickness=0.8, color=color, rows=6,
                                ridge_color=ridge_col, style=style, rng=rng)
    b.add([pc.move(0, 0, top) for pc in roof], tag="roof")
    for sy in (-1, 1):
        g = kit.gable_end(W, rise, 0.8, plaster)
        b.add(g.move(0, sy * (D / 2 - 0.4), top).paint(grad=("range", 0.5, 0.85)))
        yg = sy * (D / 2 + 0.1)
        n = (0, sy, 0)
        b.add(kit.oriented_box((-W / 2 + 0.5, yg, top + 0.35), (W / 2 - 0.5, yg, top + 0.35), kit.TIMBER, 0.4, "timber", n))
        for s in (-1, 1):
            b.add(kit.oriented_box((s * W * 0.36, yg, top + 0.6), (s * 0.5, yg, top + rise * 0.62), kit.TIMBER * 0.8, 0.4,
                                   "timber", n))
        if sy > 0:
            b.add(kit.oriented_box((0, yg, top + 0.6), (0, yg, top + rise - 0.8), kit.TIMBER, 0.4, "timber", n))
    # loft door in the front gable, hoist beam from the apex with a hanging crate
    b.add([pc.move(0, fy - 0.3, top + 0.55) for pc in kit.door(3.0, 3.8, shutter, "timber", arched=False, step=None)])
    bz = top + rise - 1.6
    b.add(box(0.8, 4.8, 0.8, "timber").move(0, fy - 1.6, bz))
    b.add(kit.oriented_box((0, fy - 0.2, bz - 2.0), (0, fy - 2.0, bz + 0.1), 0.42, 0.42, "timber", (1, 0, 0)))
    for pc in cc.rope_hoist((0, fy - 3.4, bz), bz - (top - 0.5), "crate", rng):
        b.add(pc)

    # side lean-to cart shed
    if p["shed"]:
        s = p["shed"]
        Ls, Ds = D * 0.62, 6.5
        zl = z0 + 7.2
        hi = top - 1.4
        pitch_s = math.degrees(math.atan2(hi - (zl + 0.6), Ds))
        lean, _ = cc.mono_tile_roof(Ds, Ls, pitch_s, kingdom_color(k, "roof"), rows=3, overhang=1.2,
                                    gable_overhang=0.8, thickness=0.6, rng=rng)
        for pc in lean:
            b.add(pc.rotate(-s * math.pi / 2 if s < 0 else s * math.pi / 2, "Z").move(s * W / 2, D * 0.12, zl + 0.6),
                  tag="roof")
        for yy in (D * 0.12 - Ls / 2 + 0.5, D * 0.12 + Ls / 2 - 0.5):
            for pc in cc.post(zl - 0.6, 0.85, "timber", pad=True):
                b.add(pc.move(s * (W / 2 + Ds - 0.3), yy, 0.0))
        b.add(kit.bbox(0.85, Ls, 0.7, "timber", 0.06).move(s * (W / 2 + Ds - 0.3), D * 0.12, zl - 0.1))
        for pc in _cart(rng):
            b.add(pc.rotate(math.pi / 2, "Z").move(s * (W / 2 + Ds * 0.5), D * 0.12 + 1.0, 0))
        for pc in cc.log_pile(rng, 3.4, 3, 0.55):
            b.add(pc.move(s * (W / 2 + 1.5), D * 0.12 - Ls / 2 + 2.6, 0))

    # props: sacks + crates either side of the door, deposit pallet, cart, barrels, sign
    sacks = 0
    side = -1 if p["shed"] <= 0 else 1
    for pc in cc.sack_pile(rng, 5, 3.6, 1.0):
        b.add(pc.move(side * (DW / 2 + 3.4), fy - 1.6, 0))
    sacks += 5
    for pc in cc.crate_stack(rng, 3, 2.0, "wood_light"):
        b.add(pc.move(-side * (DW / 2 + 3.2), fy - 1.5, 0))
    for pc in cc.barrel(1.0, "wood"):
        b.add(pc.move(-side * (DW / 2 + 5.6), fy - 1.2, 0))
    px, py = side * (DW / 2 + 3.2), fy - 4.6
    for pc in _pallet(rng, 3):
        b.add(pc.move(px, py, 0))
    sacks += 3
    b.socket("deposit", px, py - 2.2, 0.0)
    if not p["shed"]:
        for pc in _cart(rng):
            b.add(pc.rotate(0.25 * side, "Z").move(-side * (DW / 2 + 3.6), fy - 5.0, 0))
        sacks += 2
    _sign(b, "sheaf", -side * (DW / 2 + 1.0), fy - 0.5, z0 + DH - 0.4, -side)
    b.stats["sacks"] = sacks
    b.stats["windows"] = windows


def build(b, p):
    k = p["kingdom"]
    if p["kind"] == "granary":
        _granary(b, b.rng, k, p)
    else:
        _warehouse(b, b.rng, k, p)
    b.stats["pieces"] = len(b.pieces)
    b.stats["roof"] = b.count_tag("roof")
