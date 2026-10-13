"""Village blacksmith: stone plinth, an enclosed rear block (plaster + timber frame or kingdom
stone, kit windows/door, kit tile roof) or a tall back wall, and an OPEN front workshop under
a kit-tile lean-to roof on chunky posts. Inside: a big stone forge with glowing coals, a hood
and a tall chimney that clears the ridge, bellows, an anvil on a stump, a quench barrel, a
grindstone, a weapon/tool rack with kingdom shields, coal and iron stock, horseshoes, a
kingdom banner and an anvil trade sign.

Layouts: "pent" (gable rear block + lean-to), "loft" (two-storey rear block + lean-to),
"shed" (one big mono-pitch roof from a tall back wall to the front posts).
Front (open side) faces Blender -Y. Sockets: `interact` = in front of the anvil (player
stands here to smith), `forge` = centre of the glowing hearth (VFX/fire attach).
"""

import math

from lib import kit
from lib.geo import arch_poly, box, cylinder, frustum_box, lathe, loft_rings, prism
from lib.palette import kingdom_color

from generators import _civic_common as cc

NAME = "building_smithy"
VERSION = 1
CATEGORY = "building"
BUDGET = "building_medium"
COLLISION = {"fidelity": "PreciseConvexDecomposition"}
CHECKS = {"min_pieces": 150, "min_windows": 2, "min_roof": 4, "has_forge": 1, "has_anvil": 1}
DEFAULT_VARIANTS = 6

_TABLE = [
    dict(layout="pent", forge=-1, walls="timber", W=20.0, D=15.6, h1=12.2),
    dict(layout="shed", forge=1, walls="stone", W=19.0, D=14.5, h1=13.4),
    dict(layout="loft", forge=1, walls="timber", W=18.0, D=15.4, h1=11.8, h2=7.6),
    dict(layout="pent", forge=1, walls="stone", W=21.0, D=15.9, h1=12.4),
    dict(layout="shed", forge=-1, walls="timber", W=18.0, D=14.2, h1=13.0),
    dict(layout="loft", forge=-1, walls="stone", W=19.5, D=15.6, h1=11.9, h2=7.8),
]

PH = 1.0  # plinth / workshop floor height


def variants(n, seed):
    out = []
    for i in range(n):
        p = dict(_TABLE[i % len(_TABLE)])
        p["kingdom"] = cc.KINGDOM_CYCLE[i % 4]
        p["seed"] = seed * 1000 + 500 + i
        out.append(p)
    return out


# ------------------------------------------------------------------ workshop pieces

def _forge(rng, k, chim_top, rack_side):
    """Hearth centred on (0,0) at floor z=0, back face at y=+hd/2 (against the wall).
    Returns pieces and the hearth top z."""
    hw, hd, hh = 5.2, 4.4, 3.0
    stone, light = kingdom_color(k, "stone"), kingdom_color(k, "stone_light")
    out = [kit.bbox(hw, hd, hh, stone, 0.18).paint(grad=("range", 0.15, 0.7))]
    # ash-pit arch on the front with a light voussoir ring
    out.append(prism(arch_poly(1.9, 1.7, 5), 0.3, "fire").move(0, -hd / 2 + 0.1, 0.2).paint(grad=("range", 0.2, 1.0)))
    for i in range(5):
        a = math.pi * (i + 0.5) / 5
        r = 1.25
        v = kit.bbox(0.55, 0.4, 0.62, light, 0.08, base=False).rotate(-(a - math.pi / 2), "Y")
        out.append(v.move(math.cos(a) * r, -hd / 2 - 0.05, 0.2 + 1.7 - 0.95 + math.sin(a) * r))
    # top rim blocks around the coal bed
    for sx, sy, x, y in ((hw + 0.2, 0.6, 0, -hd / 2 + 0.3), (0.6, hd, -hw / 2 + 0.3, 0), (0.6, hd, hw / 2 - 0.3, 0)):
        out.append(kit.bbox(sx, sy, 0.45, light, 0.1).move(x, y, hh - 0.05).paint(tint=rng.uniform(0.2, 0.8)))
    out.append(box(hw - 1.1, hd - 1.0, 0.3, "coal").move(0, 0.1, hh))
    m = lathe([(1.0, 0.0), (0.88, 0.25), (0.5, 0.55), (0.0, 0.7)], 7, "ember").scale(1.75, 1.3, 1.0)
    m.jitter(rng, 0.07)
    out.append(m.paint(smooth=True, grad=("range", 0.4, 1.0)).move(0, -0.1, hh + 0.2))
    for j, (dx, dy, s) in enumerate(((-0.5, -0.3, 1.0), (0.45, 0.0, 0.8), (0.0, 0.35, 1.15), (0.9, -0.5, 0.6))):
        s *= 1.35
        fl = lathe([(0.0, 0.0), (0.34 * s, 0.25 * s), (0.24 * s, 0.8 * s), (0.0, 1.45 * s)], 5,
                   "fire" if j % 2 == 0 else "ember")
        out.append(fl.rotate(rng.uniform(-0.15, 0.15), "X").move(dx, dy, hh + 0.35).paint(grad=("range", 0.5, 1.0)))
    # chimney breast behind the coals, hood over the hearth, tall chimney
    hz0, hz1 = hh + 3.0, hh + 5.4
    out.append(kit.bbox(hw * 0.78, 1.6, hz0 - hh, stone, 0.12).move(0, hd / 2 - 0.8, hh))
    y0, y1 = -hd / 2 - 0.2, hd / 2
    ring0 = [(-hw / 2 - 0.25, y0, hz0), (hw / 2 + 0.25, y0, hz0), (hw / 2 + 0.25, y1, hz0), (-hw / 2 - 0.25, y1, hz0)]
    ring1 = [(-1.55, y1 - 2.9, hz1), (1.55, y1 - 2.9, hz1), (1.55, y1, hz1), (-1.55, y1, hz1)]
    out.append(loft_rings([ring0, ring1], stone).paint(grad=("range", 0.3, 0.75)))
    out.append(kit.bbox(hw + 0.9, hd + 0.6, 0.45, light, 0.1).move(0, -0.1, hz0 - 0.45))  # hood band
    ch = kit.chimney(chim_top - hz1, 3.0, stone, kingdom_color(k, "stone_dark"), pots=2)
    out += [pc.move(0, y1 - 1.5, hz1) for pc in ch]
    # bellows on the inner side, nozzle into the hearth
    for pc in _bellows():
        out.append(pc.rotate(0.0 if rack_side > 0 else math.pi, "Z").move(rack_side * (hw / 2 + 0.25), 0.7, 0.0))
    return out, hh + 0.3


def _bellows():
    """Bellows on a stand, nozzle at the origin pointing -X; wide end at +X."""
    out = []
    poly = [(0.0, 0.0), (0.55, -0.42), (1.5, -0.78), (2.35, -0.72), (2.75, -0.36), (2.75, 0.36), (2.35, 0.72),
            (1.5, 0.78), (0.55, 0.42)]
    z = 1.45
    out.append(prism(poly, 0.16, "wood", axis="Z").move(0.15, 0, z))
    leather = prism([(x * 0.95 + 0.1, y * 0.9) for x, y in poly], 0.62, "leather", axis="Z")
    leather.bend(lambda v: (v.x, v.y * (1.0 + 0.18 * math.sin(math.pi * min(1.0, max(0.0, (v.z - z - 0.16) / 0.62)))),
                            v.z))
    out.append(leather.move(0.15, 0, z + 0.16))
    top = prism(poly, 0.16, "wood", axis="Z").move(0.15, 0, z + 0.78)
    out.append(top.rotate(-0.04, "Y"))
    out.append(cylinder(0.2, 0.12, 1.0, 6, "iron").rotate(-math.pi / 2, "Y").move(0.25, 0, z + 0.45))
    out.append(box(1.3, 0.18, 0.18, "wood_dark").move(3.4, 0, z + 0.95))
    for x in (0.9, 2.3):
        out.append(box(0.3, 1.2, z, "wood_dark").move(x + 0.15, 0, 0))
    return out


def _anvil(rng):
    """Chunky anvil (storybook-exaggerated so it reads from the street) on a tree stump, base
    at z=0, horn towards +X. Work face at z~3.5."""
    out = [cylinder(1.05, 0.92, 1.8, 8, "bark").paint(grad=("range", 0.15, 0.7))]
    out.append(cylinder(0.9, 0.9, 0.1, 8, "wood_pale").move(0, 0, 1.78))
    body = [frustum_box(1.6, 1.1, 0.75, 0.6, 0.45, "iron_dark")]
    body.append(box(0.62, 0.5, 0.42, "iron_dark").move(0, 0, 0.44))
    body.append(kit.bbox(2.1, 0.85, 0.5, "iron", 0.07).move(-0.12, 0, 0.84).paint(grad=("range", 0.5, 1.0)))
    body.append(lathe([(0.32, 0.0), (0.0, 1.2)], 6, "iron").rotate(math.pi / 2, "Y").scale(1, 1, 0.75)
                .move(0.92, 0, 1.11))
    body.append(box(0.4, 0.6, 0.36, "iron_dark").move(-1.35, 0, 0.94))
    # hammer resting on the face
    body.append(box(0.16, 1.5, 0.16, "wood").rotate(0.35, "Z").move(-0.3, -0.55, 1.34))
    body.append(box(0.62, 0.32, 0.3, "iron_dark").rotate(0.35, "Z").move(-0.05, 0.15, 1.3))
    out += [pc.scale(1.3, 1.3, 1.25).move(0, 0, 1.86) for pc in body]
    return out


def _grindstone():
    """Grindstone in an A-frame over a trough; wheel axis along X. Base z=0."""
    out = [kit.bbox(1.5, 2.2, 0.7, "wood", 0.08)]
    out.append(box(1.2, 1.9, 0.08, "water").move(0, 0, 0.66))
    out.append(cylinder(1.2, 1.2, 0.5, 10, "stone_light").rotate(math.pi / 2, "Y").move(-0.25, 0, 2.1)
               .paint(grad=("range", 0.4, 0.95)))
    out.append(cylinder(0.11, 0.11, 2.4, 5, "iron_dark").rotate(math.pi / 2, "Y").move(-1.2, 0, 2.1))
    for x in (-0.8, 0.8):
        for s in (-1, 1):
            out.append(kit.oriented_box((x, s * 1.15, 0.0), (x, 0.0, 2.2), 0.3, 0.3, "wood", (1, 0, 0)))
        out.append(box(0.28, 1.6, 0.25, "wood").move(x, 0, 0.9))
    out.append(box(0.15, 0.15, 0.8, "wood_dark").move(1.25, 0, 1.4))
    out.append(cylinder(0.1, 0.1, 0.5, 5, "wood_dark").rotate(math.pi / 2, "Y").move(1.2, 0, 1.45))
    return out


def _sword(blade=3.0, trim="gold"):
    out = [box(0.34, 0.1, blade, "steel")]
    out.append(box(0.2, 0.08, 0.3, "steel").move(0, 0, -0.25))  # tip
    out.append(box(1.0, 0.22, 0.18, "iron_dark").move(0, 0, blade))
    out.append(box(0.2, 0.2, 0.7, "leather").move(0, 0, blade + 0.18))
    out.append(box(0.32, 0.3, 0.3, trim).move(0, 0, blade + 0.88))
    return out


def _axe():
    out = [box(0.2, 0.2, 3.6, "wood")]
    head = prism([(0.0, -0.35), (0.85, -0.65), (1.0, 0.0), (0.85, 0.65), (0.0, 0.35)], 0.14, "steel")
    out.append(head.move(0.08, 0, 3.0))
    return out


def _shield(k, r=1.15):
    """Round kingdom shield facing -Y, centred at the origin."""
    out = [cylinder(r, r, 0.22, 10, kingdom_color(k, "cloth")).rotate(math.pi / 2, "X").move(0, 0.11, 0)]
    out.append(cylinder(r + 0.12, r + 0.12, 0.14, 10, kingdom_color(k, "trim_dark")).rotate(math.pi / 2, "X")
               .move(0, 0.2, 0))
    out.append(cc.emblem(cc.KINGDOM_EMBLEM[k], r * 1.1, 0.3, kingdom_color(k, "emblem")).move(0, -0.08, 0))
    return out


def _rack(rng, k, w=5.2):
    """Weapon / tool rack against a wall at y=0 (facing -Y), base z=0."""
    out = []
    for x in (-w / 2, w / 2):
        out.append(box(0.42, 0.42, 4.4, "timber").move(x, -0.35, 0))
    for z in (0.75, 3.55):
        out.append(box(w + 0.4, 0.3, 0.3, "timber").move(0, -0.55, z))
    n = 5
    for i in range(n):
        x = -w / 2 + 0.75 + (w - 1.5) * i / (n - 1)
        kind = ("sword", "axe", "sword", "spear", "sword")[i]
        if kind == "sword":
            out += [pc.move(x, -0.75, 0.9) for pc in _sword(2.7, kingdom_color(k, "trim"))]
        elif kind == "axe":
            out += [pc.move(x, -0.75, 0.15) for pc in _axe()]
        else:
            out.append(cylinder(0.12, 0.1, 5.6, 5, "wood").move(x, -0.75, 0.1))
            out.append(lathe([(0.24, 0.0), (0.0, 0.9)], 4, "steel").move(x, -0.75, 5.7))
    for j, dx in enumerate((-w * 0.3, w * 0.3)):
        out += [pc.move(dx, -0.2, 5.6) for pc in _shield(k)]
    return out


def _horseshoe(s=0.5, color="iron_dark"):
    pts = []
    for i in range(7):
        a = math.pi * (1.0 + i / 6.0)
        pts.append((math.cos(a) * s, math.sin(a) * s))
    inner = [(x * 0.55, z * 0.55) for x, z in reversed(pts)]
    poly = [(p[0], -p[1]) for p in pts] + [(p[0], -p[1]) for p in inner]
    return prism(poly, 0.12, color)


# ------------------------------------------------------------------ building shell

def _rear_block(b, rng, k, W, Dr, yc, z0, h1, h2, walls, fs):
    """Enclosed rear block centred at (0, yc). Returns (wall top z, ridge rise, windows)."""
    plaster = rng.choice(("plaster", "plaster", "plaster_white"))
    shutter = kingdom_color(k, "shutter")
    windows = 0
    local = []
    if walls == "stone":
        local.append(kit.bbox(W, Dr, h1, kingdom_color(k, "stone"), 0.2).move(0, 0, z0).paint(grad=("range", 0.2, 0.8)))
        for sx in (-1, 1):
            for sy in (-1, 1):
                for j in range(int(h1 // 1.9)):
                    big = j % 2 == 0
                    q = box(1.9 if big else 1.2, 1.2 if big else 1.9, 1.7, kingdom_color(k, "stone_light"))
                    q.move(sx * (W / 2 - (0.75 if big else 0.4)) + sx * 0.18,
                           sy * (Dr / 2 - (0.4 if big else 0.75)) + sy * 0.18, z0 + 0.12 + j * 1.9)
                    local.append(q)
        local.append(kit.bbox(W + 0.5, Dr + 0.5, 0.5, kingdom_color(k, "stone_dark"), 0.12).move(0, 0, z0 + h1 - 0.5))
        cols = (kingdom_color(k, "stone_light"), kingdom_color(k, "stone_dark"))
        for off in (-W / 2, W / 2):
            local += cc.wall_stones(rng, Dr, h1 - 0.5, "y", off, 4, cols, z0, margin=1.4)
        local += cc.wall_stones(rng, W, h1 - 0.5, "x", Dr / 2, 7, cols, z0)
    else:
        local.append(kit.bbox(W, Dr, h1, plaster, 0.2).move(0, 0, z0).paint(grad=("range", 0.35, 0.85)))
        for off in (-Dr / 2, Dr / 2):
            for f in kit.wall_face_frame(W, h1, "x", off, "timber", posts=5, braces=True, rng=rng,
                                         skip=(1 if fs > 0 else 3,) if off < 0 else (), rail=h1 * 0.5 if off > 0 else None):
                local.append(f.move(0, 0, z0))
        for off in (-W / 2, W / 2):
            sk = (1,) if (off < 0) == (fs > 0) else ()
            for f in kit.wall_face_frame(Dr, h1, "y", off, "timber", posts=3, braces=True, rng=rng, skip=sk):
                local.append(f.move(0, 0, z0))
    # store door in the non-forge side wall, window in the front wall (under the lean-to)
    surround = "stone_light" if walls == "timber" else kingdom_color(k, "stone_light")
    local += [pc.rotate(-fs * math.pi / 2, "Z").move(-fs * W / 2, 0.0, z0)
              for pc in kit.door(kit.DOOR_W, kit.DOOR_H, "wood_dark", surround, step="stone")]
    local += [pc.move(-fs * W / 8, -Dr / 2, z0 + kit.SILL_Z + 0.6)
              for pc in kit.window(kit.WIN_W, kit.WIN_H, "timber", shutter)]
    windows += 1
    for wx in (-W * 0.25, W * 0.25):
        local += [pc.rotate(math.pi, "Z").move(wx, Dr / 2, z0 + kit.SILL_Z)
                  for pc in kit.window(kit.WIN_W, kit.WIN_H, "timber", shutter)]
        windows += 1
    top = z0 + h1
    if h2:
        local.append(kit.bbox(W + 0.6, Dr + 0.6, 0.6, "timber", 0.1).move(0, 0, top))
        top += 0.6
        local.append(kit.bbox(W, Dr, h2, plaster, 0.18).move(0, 0, top).paint(grad=("range", 0.4, 0.85)))
        for off in (-Dr / 2, Dr / 2):
            for f in kit.wall_face_frame(W, h2, "x", off, "timber", posts=5, braces=True, rng=rng):
                local.append(f.move(0, 0, top))
        for off in (-W / 2, W / 2):
            for f in kit.wall_face_frame(Dr, h2, "y", off, "timber", posts=3, braces=False, rng=rng):
                local.append(f.move(0, 0, top))
        for ux in (-fs * W * 0.3, -fs * W * 0.04):
            local += [pc.move(ux, -Dr / 2, top + 2.4) for pc in kit.window(kit.WIN_W, kit.WIN_H * 0.9, "timber", shutter)]
            windows += 1
        top += h2
    roof, rise = kit.gable_roof(Dr, W, 46.0, overhang=1.4, gable_overhang=1.0, thickness=0.75,
                                color=kingdom_color(k, "roof"), rows=4, ridge_color=kingdom_color(k, "roof_dark"),
                                style="tile", rng=rng)
    for pc in roof:
        b.add(pc.rotate(math.pi / 2, "Z").move(0, yc, top), tag="roof")
    for sx in (-1, 1):
        g = kit.gable_end(Dr, rise, 0.8, plaster)
        local.append(g.rotate(math.pi / 2, "Z").move(sx * (W / 2 - 0.4), 0, top).paint(grad=("range", 0.5, 0.85)))
        xg = sx * (W / 2 + 0.1)
        n = (sx, 0, 0)
        local.append(kit.oriented_box((xg, -Dr / 2 + 0.5, top + 0.35), (xg, Dr / 2 - 0.5, top + 0.35), kit.TIMBER, 0.4,
                                      "timber", n))
        local.append(kit.oriented_box((xg, 0, top + 0.6), (xg, 0, top + rise - 0.8), kit.TIMBER, 0.4, "timber", n))
    for pc in local:
        b.add(pc.move(0, yc, 0))
    return top, rise, windows


def _shed_walls(b, rng, k, W, D, yb, z0, zf, zb, walls, fs):
    """Tall back wall + side walls with sloped tops for the mono-pitch shed layout."""
    plaster = rng.choice(("plaster", "plaster_white"))
    shutter = kingdom_color(k, "shutter")
    t = 1.0
    hb = zb - z0
    yfr = -D / 2 + 0.6
    wall_col = kingdom_color(k, "stone") if walls == "stone" else plaster
    b.add(kit.bbox(W, t, hb, wall_col, 0.18).move(0, yb - t / 2, z0).paint(grad=("range", 0.25, 0.85)))
    if walls == "timber":
        for f in kit.wall_face_frame(W, hb, "x", yb - t, "timber", posts=5, braces=True, rng=rng, rail=hb * 0.45):
            b.add(f.move(0, 0, z0))
        for f in kit.wall_face_frame(W, hb, "x", yb, "timber", posts=5, braces=True, rng=rng, rail=hb * 0.45):
            b.add(f.move(0, 0, z0))
    else:
        cols = (kingdom_color(k, "stone_light"), kingdom_color(k, "stone_dark"))
        b.add(cc.wall_stones(rng, W, hb - 0.5, "x", yb, 8, cols, z0))
        for sx in (-1, 1):
            for j in range(int(hb // 1.9)):
                big = j % 2 == 0
                q = box(1.9 if big else 1.2, 1.25, 1.7, kingdom_color(k, "stone_light"))
                b.add(q.move(sx * (W / 2 - (0.75 if big else 0.4)) + sx * 0.18, yb - t / 2, z0 + 0.12 + j * 1.9))
    # side walls: lower stone/plaster box + sloped plaster infill, only over the back half
    ys0 = yb - t
    ys1 = ys0 - (D * 0.5)
    for sx in (-1, 1):
        x = sx * (W / 2 - 0.45)
        zlo = zf + (zb - zf) * (ys1 - yfr) / (yb - yfr) - z0
        b.add(kit.bbox(0.9, ys0 - ys1, zlo, wall_col, 0.15).move(x, (ys0 + ys1) / 2, z0)
              .paint(grad=("range", 0.25, 0.85)))
        if walls == "timber":
            for f in kit.wall_face_frame(ys0 - ys1, zlo, "y", sx * W / 2, "timber", posts=3, braces=True, rng=rng,
                                         skip=(1,) if sx == -fs else ()):
                b.add(f.move(0, (ys0 + ys1) / 2, z0))
        else:
            for yq in (ys1 + 0.55, ys0 - 0.2):
                for j in range(int(zlo // 1.9)):
                    big = j % 2 == 0
                    q = box(1.25, 1.9 if big else 1.2, 1.7, kingdom_color(k, "stone_light"))
                    b.add(q.move(x + sx * 0.2, yq + (0.35 if big else 0.0) * (1 if yq < 0 else -1), z0 + 0.12 + j * 1.9))
        tri = prism([(ys1, zlo + z0), (ys0, zlo + z0), (ys0, zb - 0.05)], 0.8, plaster, axis="X")
        b.add(tri.move(x, 0, 0).paint(grad=("range", 0.45, 0.85)))
        n = (sx, 0, 0)
        b.add(kit.oriented_box((x + sx * 0.45, ys1, z0), (x + sx * 0.45, ys1, zlo + z0 + 0.3), kit.TIMBER, 0.4,
                               "timber", n))
        b.add(kit.oriented_box((x + sx * 0.45, ys1, zlo + z0), (x + sx * 0.45, ys0, zb - 0.1), kit.TIMBER, 0.4,
                               "timber", n))
        b.add(kit.oriented_box((x + sx * 0.45, ys1, zlo + z0), (x + sx * 0.45, ys0, zlo + z0), kit.TIMBER, 0.4,
                               "timber", n))
    # store door in the non-forge side wall, windows high in the back wall
    surround = "stone_light" if walls == "timber" else kingdom_color(k, "stone_light")
    b.add([pc.rotate(-fs * math.pi / 2, "Z").move(-fs * W / 2, (ys0 + ys1) / 2, z0)
           for pc in kit.door(kit.DOOR_W, kit.DOOR_H, "wood_dark", surround, step="stone")])
    windows = 0
    for wx in (-W * 0.28, W * 0.28):
        b.add([pc.rotate(math.pi, "Z").move(wx, yb, z0 + kit.SILL_Z + 3.0)
               for pc in kit.window(kit.WIN_W, kit.WIN_H, "timber", shutter)])
        windows += 1
    return windows


def build(b, p):
    rng = b.rng
    k = p["kingdom"]
    lay = p["layout"]
    fs = p["forge"]
    W = p["W"] + rng.uniform(-0.4, 0.4)
    D = p["D"] + rng.uniform(-0.3, 0.3)
    h1 = p["h1"]
    h2 = p.get("h2", 0.0)
    roof_col = kingdom_color(k, "roof")

    # --- plinth under everything (workshop + forecourt yard), flagstone floor
    YARD = 4.4
    cyp = -YARD / 2
    for pc in cc.plinth(W, D + YARD, PH, rng, "stone_dark", 0.0, cyp, block=(3.4, 5.2)):
        b.add(pc)
    yp = -D / 2 + 0.7  # front post line
    if lay == "shed":
        yr = D / 2 - 1.0  # inner face of the back wall
    else:
        Dr = 7.6
        yr = D / 2 - Dr
    yfront = -D / 2 - YARD
    nx, ny = max(3, int(W / 3.3)), max(3, int((yr - yfront) / 3.3))
    tw, td = (W - 0.6) / nx, (yr - yfront - 0.3) / ny
    for i in range(nx):
        for j in range(ny):
            x = -W / 2 + 0.3 + tw * (i + 0.5)
            y = yfront + 0.3 + td * (j + 0.5)
            b.add(box(tw - 0.16, td - 0.16, 0.14, rng.choice(("cobble", "stone_light", "cobble")))
                  .move(x + rng.uniform(-0.05, 0.05), y, PH - 0.06).paint(tint=rng.uniform(0, 1), grad=0.55))
    floor = PH + 0.08
    b.add(kit.bbox(7.0, 1.5, 0.55, "stone_light", 0.12).move(-fs * W * 0.18, yfront - 0.9, 0))  # front step

    # --- shell
    zf = PH + 8.4  # front post top (tall open front)
    windows = 0
    if lay == "shed":
        zb = PH + h1
        windows += _shed_walls(b, rng, k, W, D, D / 2, PH, zf + 0.7, zb + 0.7, p["walls"], fs)
        ridge = zb + 0.7
        run = (D / 2) - yp
        rise = zb - zf
        pitch = math.degrees(math.atan2(rise, run))
        lean, _ = cc.mono_tile_roof(run, W, pitch, roof_col, rows=5, overhang=1.3, gable_overhang=0.9, thickness=0.7,
                                    rng=rng)
        for pc in lean:
            b.add(pc.move(0, D / 2, zf + 0.7), tag="roof")
        top_z = zb + 0.7 + 0.8
    else:
        wall_top, rrise, w_ = _rear_block(b, rng, k, W, Dr, D / 2 - Dr / 2, PH, h1, h2, p["walls"], fs)
        windows += w_
        ridge = wall_top + rrise
        hi = PH + h1 - 0.45
        run = yr - yp
        pitch = math.degrees(math.atan2(hi - (zf + 0.7), run))
        lean, _ = cc.mono_tile_roof(run, W, pitch, roof_col, rows=4, overhang=1.3, gable_overhang=0.9, thickness=0.65,
                                    rng=rng)
        for pc in lean:
            b.add(pc.move(0, yr, zf + 0.7), tag="roof")
        top_z = ridge + 0.9

    # --- front posts, beam, braces, tie beams back to the wall
    nposts = 4 if W > 18.5 else 3
    xs = [-W / 2 + 0.55 + (W - 1.1) * i / (nposts - 1) for i in range(nposts)]
    for x in xs:
        for pc in cc.post(zf - floor, 0.9, "timber", pad=True):
            b.add(pc.move(x, yp, floor - 0.08))
        b.add(kit.oriented_box((x, yp, zf + 0.35), (x, yr, zf + 0.35), 0.5, 0.5, "timber", (1, 0, 0)))
        for s in (-1, 1):
            if (s < 0 and x == xs[0]) or (s > 0 and x == xs[-1]):
                continue
            b.add(cc.knee_brace((x + s * 0.4, yp, zf - 1.9), (x + s * 1.9, yp, zf + 0.05), (0, -1, 0)))
    b.add(kit.bbox(W + 0.7, 0.8, 0.75, "timber", 0.08).move(0, yp, zf - 0.05))
    for j, x in enumerate((-W * 0.06, W * 0.06)):  # horseshoes nailed to the beam
        b.add(_horseshoe(0.42).move(x + rng.uniform(-0.3, 0.3), yp - 0.47, zf + 0.35))

    # --- forge at the front of the workshop on one side: the glowing fire-box and hood face the
    #     street, the tall chimney rises through the lean-to and clears the ridge
    xf = fs * (W / 2 - 3.9)
    hd = 4.4
    yfh = yp + hd / 2 + 0.35
    chim_top = max(ridge, top_z) + (3.4 if h2 else 4.4)
    fpcs, hearth_top = _forge(rng, k, chim_top - floor, -fs)
    for pc in fpcs:
        b.add(pc.move(xf, yfh, floor))
    b.stats["forge"] = 1
    b.socket("forge", xf, yfh - 0.1, floor + hearth_top)
    # coal heap in the forecourt corner, iron bar stock inside by the rack
    b.add(cc.mound(2.4, 2.0, 1.0, "coal", rng).move(fs * (W / 2 - 1.5), yp - 2.4, floor))
    for j in range(4):
        b.add(box(2.4, 0.22, 0.22, "iron").rotate(rng.uniform(-0.08, 0.08), "Z")
              .move(-fs * (W / 2 - 4.0), yr - 1.6 - j * 0.3, floor + (0.0 if j < 3 else 0.22)))

    # --- anvil out in the forecourt (reads from the street), quench barrel with tongs
    xa = xf - fs * 3.4
    ya = yp - 2.4
    for pc in _anvil(rng):
        b.add(pc.rotate(math.pi if fs > 0 else 0.0, "Z").move(xa, ya, floor))
    b.stats["anvil"] = 1
    b.socket("interact", xa, ya - 2.3, floor)
    bx = xa - fs * 2.7
    for pc in cc.barrel(0.95, "wood", "water_deep"):
        b.add(pc.move(bx, ya + 0.5, floor))
    for s in (-1, 1):
        b.add(kit.oriented_box((bx + s * 0.12, ya + 0.5, floor + 1.4), (bx + s * 0.3 + fs * 0.4, ya + 0.2, floor + 3.6),
                               0.12, 0.12, "iron_dark", (0, -1, 0)))

    # --- grindstone in the forecourt corner (non-forge side), rack on the back wall
    for pc in _grindstone():
        b.add(pc.rotate(0.35 * fs, "Z").move(-fs * (W / 2 - 2.5), yp - 2.3, floor))
    rx = -fs * (W / 2 - 4.0)
    for pc in _rack(rng, k, 5.0):
        b.add(pc.move(rx, yr, floor))

    # --- log pile against the outer forge-side wall
    for pc in cc.log_pile(rng, 3.6, 3, 0.55):
        b.add(pc.rotate(math.pi / 2, "Z").move(fs * (W / 2 + 1.7), (D / 2 - D * 0.25) if lay == "shed" else yr + 3.8,
                                                0.0))

    # --- kingdom banner on the outer non-forge post, anvil sign on the forge-side post
    bxp = xs[0] if fs > 0 else xs[-1]
    for pc in cc.banner(k, 2.0, 4.4):
        b.add(pc.move(bxp, yp - 0.75, zf - 0.3))
    sxp = xs[-1] if fs > 0 else xs[0]
    for pc in cc.hanging_sign("anvil", "iron_dark", side=fs, arm=3.0, w=2.5, h=1.8, board="wood_pale"):
        b.add(pc.move(sxp + fs * 0.45, yp, zf - 0.6))

    b.stats["windows"] = windows
    b.stats["pieces"] = len(b.pieces)
    b.stats["roof"] = b.count_tag("roof")
