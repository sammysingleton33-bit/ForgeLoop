"""Castle gatehouse: replaces one 32-stud castle_wall module (ground footprint x = +-16, wall-walk
doors at z = 24 on both flanks, pivot on the wall axis). A 14.5-wide arched passage runs through
it along Y (clear 14 x 17.7 at the crown; between the front towers 14.2 wide), with a raised iron
portcullis, two oak gate leaves standing open in the gate hall, an emblem shield over the arch,
banners, and twin front towers + rear turrets crowned in the kingdom's roof language:
  red    round towers, machicolated gate front, swallowtail merlons, conical spires
  blue   square towers, crisp merlons, slate pyramids with silver finials
  green  round towers with timber hoardings + low cones, a timber bretèche over the gate
  yellow sandstone, stepped merlons, striped (ablaq) voussoirs, purple/ivory friezes, onion domes

Front (field side) faces -Y. Collision: the visual mesh is CanCollide=false ("None"); solid
masses are exported as collision boxes so the passage always stays open.
"""

import math

from lib import kit
from lib.geo import box, cylinder, lathe, prism
from generators import _castle_common as cc
from generators._castle_common import kc

NAME = "castle_gatehouse"
VERSION = 1
CATEGORY = "castle"
BUDGET = "castle_gate"
COLLISION = {"fidelity": "None"}
CHECKS = {"min_pieces": 200, "min_merlons": 6, "min_turrets": 4, "min_roof": 4, "min_portcullis_bars": 6}
DEFAULT_VARIANTS = 4
LINEUP_GAP = 6.0
HERO_VIEW = {"azimuth": 28, "elevation": 14}

HALF = 16.0
FL = 15.75  # flank face of the gate block (its ashlar ends flush with x = +-16)
PW = 7.25  # passage half-width
SPRING = 10.5  # arch springing height
CROWN = SPRING + PW  # 17.75
DF = 7.0  # half-depth of the gate block (front face at y = -DF)
TOP = 31.0  # gate block walk level
TX, TR = 11.1, 4.0  # tower centre x and radius (front towers at y = -DF, rear turrets at y = +DF)
HALL = 9.0  # gate hall half-width (between the arches)
HALL_Y = (-3.4, 4.6)  # gate hall y range
ROAD = 13.6  # road half-length (defines the symmetric Y bounds)


def variants(n, seed):
    out = []
    for i in range(n):
        k = cc.KINGDOMS[i % 4]
        out.append({"kingdom": k, "towers": "square" if k == "blue" else "round", "seed": seed * 1000 + 900 + i})
    return out


def asset_id(i, params):
    return f"castle_gatehouse_{params['kingdom']}_{i // 4 + 1:02d}"


def arch_head(y0, y1, color, top=CROWN + 1.6, seg=9):
    """Solid block above the passage between the jambs, its underside the semicircular vault."""
    poly = [(-PW, SPRING)]
    for i in range(1, seg):
        a = math.pi - math.pi * i / seg
        poly.append((math.cos(a) * PW, SPRING + math.sin(a) * PW))
    poly += [(PW, SPRING), (PW, top), (-PW, top)]
    return prism(poly, y1 - y0, color).move(0, (y0 + y1) / 2, 0)


# ------------------------------------------------------------------ parts

def towers(b, k, rng, form, y, z_top, front=True):
    """Pair of flanking towers (round D-towers or square) at y; returns the roof base z."""
    sd, st, sl = kc(k, "stone_dark"), kc(k, "stone"), kc(k, "stone_light")
    out_th = 0.0 if front else math.pi
    for sx in (-1, 1):
        x = sx * TX
        if form == "square":
            h = TR - 0.1
            b.add(cc.ybox(x - h, x + h, y - h, y + h, 0.0, z_top, sd))
            for f, th in ((0, out_th), (1, out_th + math.pi / 2), (3, out_th - math.pi / 2)):
                bl = cc.ashlar_plane(k, rng, -h, h, 0.0, z_top, course=3.4, blen=(3.6, 5.6), end_gap=False,
                                     holes=[(-1.1, 1.1, 12.0, 15.8)] if f == 0 else ())
                b.add([q.move(0, -h, 0).rotate(th, "Z").move(x, y, 0) for q in bl])
            b.add(cc.place([q.move(0, -h - 0.08, 12.4) for q in cc.arrow_slit(k, 3.0)], out_th, x, y))
            b.add(cc.ybox(x - h - 0.5, x + h + 0.5, y - h - 0.5, y + h + 0.5, 5.0, 5.6, sl))
        else:
            b.add(lathe([(TR + 0.55, 0.0), (TR + 0.55, 0.3), (TR, 4.8), (TR, z_top)], 12, sd).move(x, y, 0))
            b.add(cc.place(cc.ashlar_ring(k, rng, TR + 0.35, 0.3, 4.7, r1=TR + 0.02, seg_len=4.6, course=2.2,
                                          arc=(out_th, 0.62 * math.pi), shade_hi=0.2, n_min=8), 0, x, y, 0))
            b.add(cc.place(cc.ashlar_ring(k, rng, TR, 5.3, z_top, seg_len=4.8 if front else 5.2,
                                          course=3.3 if front else 3.6, n_min=8 if front else 6,
                                          arc=(out_th, 0.58 * math.pi), holes=[(out_th + sx * 0.5, 0.3, 11.6, 15.6)]),
                           0, x, y, 0))
            b.add(cc.annulus(TR - 0.3, TR + 0.45, 4.8, 5.4, 12, sl).move(x, y, 0))
            b.add(cc.place(cc.on_ring(cc.arrow_slit(k, 3.0), out_th + sx * 0.5, TR + 0.1, 12.0), 0, x, y, 0))
        b.stats["turrets"] = b.stats.get("turrets", 0) + 1
    return z_top


def tower_crowns(b, k, rng, form, y, z, front=True):
    """Kingdom crowns on the pair of towers at y (round/square), base at z. Front towers get the full
    crown (corbel table, parapet, merlons, roof); rear turrets a string course and the roof."""
    sl, st = kc(k, "stone_light"), kc(k, "stone")
    for sx in (-1, 1):
        x = sx * TX
        if k == "green":
            hoard(b, k, x, y, TR, z, tall=front)
            continue
        if form == "square":
            h = TR - 0.1
            if front and k != "blue":
                for f in range(4):
                    th = f * math.pi / 2
                    b.add(cc.place([q.move(u, -h, z - 0.5) for u in (-2.0, 2.0) for q in cc.corbel(sl, 0.9, 1.0, 1.6)],
                                   th, x, y))
                    b.add(cc.ybox(-h - 0.8, h + 0.8, -h - 0.8, -h + 0.4, z - 0.5, z + 2.6, st).rotate(th, "Z")
                          .move(x, y, 0))
                    ox, oy = rotate_xy(0, -h - 0.2, th)
                    b.add(cc.place(cc.merlon("peaked", k, w=2.2, h=2.4, t=1.1), th, x + ox, y + oy, z + 2.6))
                b.stats["merlons"] = b.stats.get("merlons", 0) + 4
                pcs, apex = cc.pyramid(k, h + 0.9, 15.0, overhang=0.0, rows=2)
                b.add(cc.place(pcs, 0, x, y, z + 2.6), tag="roof")
            else:
                b.add(cc.ybox(x - h - 0.4, x + h + 0.4, y - h - 0.4, y + h + 0.4, z - 0.1, z + 0.5, sl))
                pcs, apex = cc.pyramid(k, h + 0.2, 10.0 if front else 8.0, overhang=0.6, rows=1 if front else 0,
                                       flare=front)
                b.add(cc.place(pcs, 0, x, y, z + 0.5), tag="roof")
            continue
        if not front:
            b.add(cc.annulus(TR - 0.3, TR + 0.45, z - 0.1, z + 0.5, 12, sl).move(x, y, 0))
            if k == "red":
                pcs, apex = cc.spire(k, TR, 11.0, seg=10, overhang=0.5, rows=1)
                b.add(cc.place(pcs, 0, x, y, z + 0.5), tag="roof")
            else:
                pcs, apex = cc.dome(k, TR * 0.9, TR * 1.9, onion=True, seg=8, fin="simple", ribs=False, collar=False)
                b.add(cc.place(pcs, 0, x, y, z + 0.5), tag="roof")
            continue
        Rp = TR + 0.9
        for i in range(8):
            th = 2 * math.pi * (i + 0.5) / 8
            b.add(cc.place(cc.on_ring(cc.corbel(sl, 1.0, 1.0, 1.8), th, TR, z - 0.5), 0, x, y, 0))
        b.add(cc.annulus(TR - 0.2, Rp, z - 0.5, z + 2.6, 12, st).move(x, y, 0).paint(grad=("range", 0.4, 0.85)))
        style = {"red": "swallow", "yellow": "stepped"}[k]
        n = 7
        for i in range(n):
            th = 2 * math.pi * i / n
            b.add(cc.place(cc.on_ring(cc.merlon(style, k, w=2.2, h=2.6, t=1.0), th, Rp - 0.5, z + 2.6), 0, x, y, 0))
        b.stats["merlons"] = b.stats.get("merlons", 0) + n
        if k == "red":
            pcs, apex = cc.spire(k, Rp - 0.4, 16.0, seg=12, overhang=0.45, rows=2)
            b.add(cc.place(pcs, 0, x, y, z + 5.2), tag="roof")
        else:
            b.add(cylinder(TR - 0.8, TR - 0.8, 3.6, 10, kc(k, "stone")).move(x, y, z).paint(grad=("range", 0.5, 0.95)))
            b.add(cc.annulus(TR - 1.3, TR - 0.1, z + 3.6, z + 4.3, 10, kc(k, "accent")).move(x, y, 0))
            pcs, apex = cc.dome(k, TR - 0.75, (TR - 0.75) * 2.3, onion=True, seg=10, fin="sun", ribs=False,
                                collar=False)
            b.add(cc.place(pcs, 0, x, y, z + 4.3), tag="roof")


def rotate_xy(x, y, th):
    c, s = math.cos(th), math.sin(th)
    return x * c - y * s, x * s + y * c


def hoard(b, k, x, y, r, z, tall=True):
    """Green: timber hoarding ring + low cone on a round tower."""
    N = 8
    Rh = r + 1.0
    step = 2 * math.pi / N
    ap = Rh * math.cos(step / 2)
    b.add(lathe([(0.0, z - 0.3), (Rh, z - 0.3), (Rh, z + 0.1), (0.0, z + 0.1)], N, "wood_dark", phase=0.0).move(x, y, 0))
    for i in range(N):
        th = step * i
        if i % 2 == 0:
            b.add(cc.place([kit.oriented_box((0, -(r - 0.2), z - 3.6), (0, -(Rh + 0.3), z - 0.2), 0.45, 0.45, "timber",
                                             normal=(1, 0, 0))], th, x, y))
        thm = th + step / 2
        L = 2 * Rh * math.sin(step / 2) + 0.1
        b.add(cc.place([box(L, 0.35, 4.0, kc(k, "wood")).move(0, -ap, z).paint(grad=("range", 0.3, 0.9))], thm, x, y))
        b.add(cc.place([box(0.45, 0.2, 1.3, "black").move(0, -ap - 0.12, z + 1.4)], thm, x, y))
        b.add(cc.place([box(0.5, 0.5, 4.3, "timber").move(0, -Rh, z - 0.15)], th, x, y))
    pcs, apex = cc.low_cone(k, Rh, Rh * (0.8 if tall else 0.6), seg=N, overhang=0.5, rows=1)
    for q in pcs:
        q.rotate(math.pi / N, "Z")
    b.add(cc.place(pcs, 0, x, y, z + 4.0), tag="roof")
    b.stats["turrets_crowned"] = b.stats.get("turrets_crowned", 0) + 1
    b.stats["merlons"] = b.stats.get("merlons", 0) + N


def portcullis(b, y):
    """Raised iron portcullis: the visible lower part of the grid hangs in the top of the arch,
    pointed iron tips on every bar."""
    z_bot = 13.6
    bars = 0
    for i in range(-3, 4):
        x = i * 1.8
        top = SPRING + math.sqrt(max(0.0, PW * PW - x * x)) + 1.0
        b.add(box(0.36, 0.36, top - z_bot, "iron_dark").move(x, y, z_bot))
        b.add(cc.square_lathe([(0.2, -0.7), (0.2, 0.0), (0.0, 0.01)], "iron").move(x, y, z_bot))
        bars += 1
    for zz in (z_bot + 1.0, z_bot + 2.8):
        half = math.sqrt(max(0.0, PW * PW - (zz - SPRING) ** 2)) + 0.4
        b.add(box(2 * half, 0.3, 0.34, "iron_dark").move(0, y - 0.05, zz))
    b.stats["portcullis_bars"] = bars


def gate_leaf(k):
    """Left oak gate leaf in its closed shape (half of the arched gate), authored with the hinge at
    the origin and the leaf running along +X; battens, iron straps and a ring pull."""
    w = PW - 0.15
    r = PW - 0.15

    def z_top(u):  # arch height over u (circle centred at u = w, z = SPRING)
        return SPRING + math.sqrt(max(0.0, r * r - (u - w) ** 2))

    poly = [(0.0, 0.0), (w, 0.0), (w, SPRING + r)]
    for i in range(1, 6):
        a = math.pi / 2 + math.pi / 2 * i / 6
        poly.append((w + r * math.cos(a), SPRING + r * math.sin(a)))
    poly.append((0.0, SPRING))
    out = [prism(poly, 0.5, kc(k, "wood")).paint(grad=("range", 0.3, 0.85))]
    for u in (w * 0.25, w * 0.5, w * 0.78):
        out.append(box(0.24, 0.16, z_top(u) - 1.2, "timber").move(u, -0.32, 0.4))
    for zz in (2.2, 7.6, 12.6):
        u0 = 0.2 if zz < SPRING else w - math.sqrt(max(0.1, r * r - (zz + 0.5 - SPRING) ** 2)) + 0.2
        out.append(box(w - u0 - 0.1, 0.16, 0.45, "iron_dark").move((u0 + w) / 2, -0.33, zz))
    out.append(box(0.45, 0.3, 0.45, "iron").move(w - 0.8, -0.42, 6.0))
    return out


# ------------------------------------------------------------------ build

def build(b, p):
    rng = b.rng
    k = p["kingdom"]
    form = p["towers"]
    sd, st, sl = kc(k, "stone_dark"), kc(k, "stone"), kc(k, "stone_light")
    b.stats["turrets"] = 0
    front_top, rear_top = {"red": (33.5, 31.0), "blue": (31.0, 31.0), "green": (29.0, 30.0),
                           "yellow": (33.0, 30.5)}[k]

    # --- road through the gate (defines the symmetric Y bounds) + kerb stones
    b.add(cc.ybox(-PW, PW, -ROAD, ROAD, 0.0, 0.18, "road").paint(grad=("range", 0.3, 0.6)))
    for sx in (-1, 1):
        b.add(cc.ybox(sx * PW - 0.5, sx * PW + 0.5, -ROAD, -DF - 4.1, 0.0, 0.5, sl))
        b.add(cc.ybox(sx * PW - 0.5, sx * PW + 0.5, DF + 4.1, ROAD, 0.0, 0.5, sl))

    # --- moss at the tower feet (weathering, same language as walls/towers)
    for i, (x, y) in enumerate(((-TX - 1.6, -DF - 3.9), (TX + 1.2, -DF - 4.0))):
        r = rng.uniform(0.9, 1.2)
        m = lathe([(0.0, 0.0), (r, 0.0), (r * 0.9, 0.4 * r), (r * 0.5, 0.75 * r), (0.0, 0.9 * r)], 5, "moss")
        m.scale(rng.uniform(1.6, 2.2), rng.uniform(0.9, 1.1), rng.uniform(0.7, 0.9))
        b.add(m.rotate(rng.uniform(0, math.pi), "Z").move(x, y, 0.0).paint(grad=("range", 0.15, 0.9), smooth=True))

    # --- solid masses: piers, jambs, arch heads, hall ceiling, upper block
    for sx in (-1, 1):
        b.add(cc.ybox(min(sx * FL, sx * HALL), max(sx * FL, sx * HALL), -DF, DF, 0.0, TOP, sd))
        for y0, y1 in ((-DF, HALL_Y[0]), (HALL_Y[1], DF)):
            b.add(cc.ybox(min(sx * HALL, sx * PW), max(sx * HALL, sx * PW), y0, y1, 0.0, TOP, st)
                  .paint(grad=("range", 0.3, 0.8)))
    for y0, y1 in ((-DF, HALL_Y[0]), (HALL_Y[1], DF)):
        b.add(arch_head(y0, y1, st).paint(grad=("range", 0.4, 0.8)))
    b.add(cc.ybox(-HALL, HALL, HALL_Y[0], HALL_Y[1], CROWN + 0.6, TOP, "stone_dark"))
    b.add(cc.ybox(-PW, PW, -DF, DF, CROWN + 1.5, TOP, sd))
    # hall walls: a few big blocks, portcullis grooves
    for sx in (-1, 1):
        b.add(cc.ybox(sx * PW - 0.25, sx * PW + 0.25, -5.6, -5.0, 0.0, CROWN, "black"))

    # --- ashlar on the visible faces
    for face_y, th in ((-DF, 0.0), (DF, math.pi)):
        bl = cc.ashlar_plane(k, rng, -TX + TR - 0.2, TX - TR + 0.2, 0.0, TOP, course=3.1, blen=(3.6, 6.0),
                             holes=[(-PW - 1.6, PW + 1.6, 0.0, CROWN + 1.9)])
        b.add([q.move(0, -DF, 0).rotate(th, "Z") for q in bl])
    for sx in (-1, 1):  # flanks (x = +-16): the wall-walk doors at z = 24
        th = sx * math.pi / 2
        bl = cc.ashlar_plane(k, rng, -DF, DF, 0.0, TOP, course=3.1, blen=(4.4, 7.4), proud=0.2,
                             holes=[(-3.0, 3.0, cc.WALK_Z - 0.4, cc.WALK_Z + 7.4)])
        b.add([q.move(0, -FL, 0).rotate(th, "Z") for q in bl])
        b.add(cc.place([q.move(0, -FL + 0.3, cc.WALK_Z) for q in cc.opening(4.0, 6.8, sl, k)], th))
    # string course at the springing level
    b.add(cc.ybox(-TX + TR, TX - TR, -DF - 0.45, DF + 0.45, SPRING - 0.6, SPRING, sl))

    # --- arches: voussoirs (yellow: striped ablaq), front and back
    for face_y, th in ((-DF, 0.0), (DF, math.pi)):
        vs = cc.voussoirs(2 * PW, SPRING, 1.5, 0.9, sl, m=11, gap=0.14)
        if k == "yellow":
            for i, v in enumerate(vs):
                v.paint(color=kc(k, "accent") if i % 2 else kc(k, "stone_light"))
        b.add([v.move(0, -DF - 0.3, 0).rotate(th, "Z") for v in vs])
        for sx in (-1, 1):  # jamb blocks
            for j in range(3):
                b.add(cc.ybox(sx * PW - 0.8 if sx > 0 else -PW - 0.8, sx * PW + 0.8 if sx > 0 else -PW + 0.8,
                              -DF - 0.4, -DF + 0.3, j * 3.5, j * 3.5 + 3.3,
                              kc(k, "accent") if (k == "yellow" and j % 2) else sl).rotate(th, "Z"))

    # --- portcullis (raised) and the open gate leaves
    portcullis(b, -5.3)
    for sx in (-1, 1):
        leaf = gate_leaf(k)
        for q in leaf:
            if sx > 0:
                q.scale(-1, 1, 1)
            q.rotate(-sx * math.pi / 2, "Z")
            b.add(q.move(sx * (PW - 0.35), HALL_Y[0] + 0.3, 0.18))

    # --- towers (front pair taller) and rear turrets
    towers(b, k, rng, form, -DF, front_top, True)
    towers(b, k, rng, form, DF, rear_top, False)
    tower_crowns(b, k, rng, form, -DF, front_top, True)
    tower_crowns(b, k, rng, form, DF, rear_top, False)

    # --- gate block crown: walk at TOP, parapets + merlons front/back; kingdom extras over the gate
    b.add(cc.ybox(-HALF, HALF, -DF, DF, TOP - 0.3, TOP + 0.05, "cobble").paint(grad=0.55))
    style = {"red": "swallow", "blue": "peaked", "green": "square", "yellow": "stepped"}[k]
    xs = [-5.4, -1.8, 1.8, 5.4] if k != "yellow" else [-5.6, -2.8, 0.0, 2.8, 5.6]
    xs_front = xs if k != "yellow" else [-6.0, 6.0]
    for face, th in ((0, 0.0), (2, math.pi)):
        if face == 0 and k == "red":
            # machicolated gate front: corbels + projecting parapet with murder-hole slots
            for x in (-6.0, -3.0, 0.0, 3.0, 6.0):
                b.add(cc.place([q.move(x, -DF, TOP - 2.2) for q in cc.corbel(sl, 1.3, 1.1, 2.4)], th))
            for x in (-4.5, -1.5, 1.5, 4.5):
                b.add(cc.ybox(x - 0.5, x + 0.5, -DF - 1.3, -DF - 1.0, TOP - 2.2, TOP - 1.5, "black"))
            y_out = -DF - 1.2
            z0 = TOP - 2.2
        elif face == 0 and k == "green":
            continue  # the timber bretèche is the front parapet
        else:
            y_out = -DF
            z0 = TOP - 0.3
        par = cc.ybox(-TX + TR - 0.3, TX - TR + 0.3, y_out, y_out + 1.3, z0, TOP + 3.0, st).paint(grad=("range", 0.4, 0.85))
        b.add(par.rotate(th, "Z"))
        b.add(cc.ybox(-TX + TR - 0.3, TX - TR + 0.3, y_out - 0.12, y_out + 1.42, TOP + 2.7, TOP + 3.05, sl).rotate(th, "Z"))
        for x in (xs_front if face == 0 else xs):
            m = cc.merlon(style, k, w=2.4 if k != "yellow" else 2.2, h=2.8, t=1.2, cap=style == "square")
            b.add([q.move(x, y_out + 0.65, TOP + 3.05).rotate(th, "Z") for q in m])
            b.stats["merlons"] = b.stats.get("merlons", 0) + 1
    for sx in (-1, 1):  # low flank parapets between the towers
        b.add(cc.ybox(sx * FL - 0.6 if sx > 0 else -FL, sx * FL if sx > 0 else -FL + 0.6,
                      -DF + TR - 0.5, DF - TR + 0.5, TOP - 0.3, TOP + 2.8, st))
    if k == "green":
        breteche(b, k)
    if k == "blue":
        gate_tower(b, k, rng)
    if k == "yellow":
        crest = [(-5.0, TOP - 0.3), (5.0, TOP - 0.3), (5.0, TOP + 3.6), (3.4, TOP + 3.6), (3.4, TOP + 5.4),
                 (1.6, TOP + 5.4), (1.6, TOP + 6.9), (0.0, TOP + 8.0), (-1.6, TOP + 6.9), (-1.6, TOP + 5.4),
                 (-3.4, TOP + 5.4), (-3.4, TOP + 3.6), (-5.0, TOP + 3.6)]
        b.add(prism(crest, 1.4, st, axis="Y").move(0, -DF + 0.5, 0).paint(grad=("range", 0.45, 0.95)))
        b.add(cc.ybox(-5.2, 5.2, -DF - 0.35, -DF + 1.3, TOP + 3.3, TOP + 3.8, kc(k, "trim")))
        b.add(cc.emblem(k, 1.5, 0.25, "gold")[0].move(0, -DF - 0.3, TOP + 1.6))
        b.add(cc.ybox(-TX + TR, TX - TR, -DF - 0.3, -DF + 0.2, TOP - 1.9, TOP - 1.45, kc(k, "accent")))
        b.add(cc.ybox(-TX + TR, TX - TR, -DF - 0.36, -DF + 0.2, TOP - 1.45, TOP - 1.0, kc(k, "trim")))

    # --- emblem shield over the arch, banners on the front towers, the flag on the gate block
    sh_z = CROWN + 6.4
    shield = [(-1.0, 0.6), (1.0, 0.6), (1.0, -0.2), (0.0, -1.3), (-1.0, -0.2)]
    b.add(prism([(x * 2.1, z * 2.1) for x, z in shield], 0.4, kc(k, "cloth")).move(0, -DF - 0.55, sh_z))
    b.add(prism([(x * 2.45, z * 2.45) for x, z in shield], 0.3, kc(k, "trim")).move(0, -DF - 0.35, sh_z))
    b.add(cc.emblem(k, 1.2, 0.2)[0].move(0, -DF - 0.78, sh_z - 0.4))
    for sx in (-1, 1):
        if form == "square":
            pcs = [q.move(sx * TX, -DF - TR - 0.05, front_top - 2.0) for q in cc.banner(k, 3.2, 9.0, tail="point")]
        else:
            pcs = cc.place(cc.on_ring(cc.banner(k, 3.2, 9.0, tail="swallow" if k in ("red", "green") else "point"),
                                      0.0, TR + 0.4, front_top - 2.0), 0, sx * TX, -DF, 0)
        b.add(pcs)
    b.stats["banners"] = 2
    pole, ptop = cc.flagpole(k, 9.0 if k != "blue" else 5.0, rng, 6.0, 3.4)
    fx, fy, fz = (0.0, 2.0, TOP) if k != "blue" else (0.0, -1.6, TOP + 9.55 + 15.0 + 2.6 - 0.6)
    b.add(cc.place(pole, 0, fx, fy, fz))

    # --- sockets and collision boxes
    b.socket("gate_center", 0.0, 0.0, 0.2)
    b.socket("spawn_inside", 0.0, ROAD + 3.0, 0.0)
    b.socket("spawn_outside", 0.0, -ROAD - 3.0, 0.0)
    b.socket("banner", 0.0, -DF - 1.0, sh_z)
    b.socket("flag", fx, fy, fz + ptop)
    b.socket("top", 0.0, 0.0, TOP)
    b.socket("end_left", -HALF, 0.0, cc.WALK_Z)
    b.socket("end_right", HALF, 0.0, cc.WALK_Z)
    for sx, name in ((-1, "left"), (1, "right")):
        b.collision_box(sx * (HALF + PW) / 2, 0.0, TOP / 2, HALF - PW, 2 * DF, TOP, f"mass_{name}")
        b.collision_box(sx * TX, -DF, front_top / 2, 2 * TR, 2 * TR, front_top, f"tower_front_{name}")
        b.collision_box(sx * TX, DF, rear_top / 2, 2 * TR, 2 * TR, rear_top, f"tower_rear_{name}")
    b.collision_box(0.0, 0.0, (CROWN + TOP) / 2, 2 * PW, 2 * DF, TOP - CROWN, "lintel")
    b.collision_box(0.0, -DF + 0.65, TOP + 1.5, 2 * (TX - TR), 1.3, 3.0, "parapet_front")
    b.collision_box(0.0, DF - 0.65, TOP + 1.5, 2 * (TX - TR), 1.3, 3.0, "parapet_back")
    if k == "blue":
        b.collision_box(0.0, -1.6, TOP + 4.5, 11.2, 9.2, 9.6, "gate_tower")
    b.stats["pieces"] = len(b.pieces)
    b.stats["roof"] = b.count_tag("roof")


def gate_tower(b, k, rng):
    """Blue: a crisp square gate tower rising over the passage, steep slate pyramid, dormer, clock-like
    emblem window; it carries the main flag."""
    sd, st, sl = kc(k, "stone_dark"), kc(k, "stone"), kc(k, "stone_light")
    hx, hy = 5.6, 4.6
    cy = -1.6
    z0, z1 = TOP - 0.3, TOP + 9.0
    b.add(cc.ybox(-hx, hx, cy - hy, cy + hy, z0, z1, sd))
    for f in range(4):
        th = f * math.pi / 2
        L = 2 * hx if f in (0, 2) else 2 * hy
        d = hy if f in (0, 2) else hx
        holes = [(-1.6, 1.6, z0 + 2.4, z0 + 7.2)] if f in (0, 2) else []
        bl = cc.ashlar_plane(k, rng, -L / 2, L / 2, z0, z1, course=3.1, blen=(3.0, 5.0), end_gap=False, holes=holes)
        b.add([q.move(0, -d, 0).rotate(th, "Z").move(0, cy, 0) for q in bl])
        if f in (0, 2):
            b.add(cc.place([q.move(0, -d - 0.12, z0 + 2.8) for q in cc.castle_window(k, 2.2, 3.4)], th, 0, cy))
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.add(cc.quoins(k, rng, sx * hx, cy + sy * hy, z0, z1, sx, sy, size=(1.8, 1.0), course=3.1))
    b.add(cc.ybox(-hx - 0.5, hx + 0.5, cy - hy - 0.5, cy + hy + 0.5, z1 - 0.1, z1 + 0.55, sl))
    pcs, apex = cc.pyramid(k, hx + 0.1, 15.0, overhang=0.8, rows=2)
    for q in pcs:
        q.scale(1.0, hy / hx, 1.0)
    b.add(cc.place(pcs, 0, 0, cy, z1 + 0.55), tag="roof")
    b.add(cc.place(cc.dormer(k, 2.4, 2.4, 3.4), 0, 0, cy - hy + 0.4, z1 + 2.6))
    b.stats["gate_tower"] = 1
    return (0, cy, z1 + 0.55 + apex)


def breteche(b, k):
    """Green: timber bretèche (covered fighting box) over the gate, plank walls with loopholes and a
    low gable roof in moss green."""
    tim, wd = "timber", kc(k, "wood")
    x0, x1 = -TX + TR + 0.2, TX - TR - 0.2
    y0, y1 = -DF - 2.2, -DF + 1.0
    z0, z1 = TOP - 1.2, TOP + 4.6
    for x in (-5.5, -2.0, 2.0, 5.5):
        b.add(cc.ybox(x - 0.32, x + 0.32, y0 - 0.4, -DF + 1.2, z0 - 0.7, z0, tim))
        b.add(kit.oriented_box((x, -DF + 0.05, z0 - 4.5), (x, y0 - 0.1, z0 - 0.6), 0.45, 0.45, tim, normal=(1, 0, 0)))
    b.add(cc.ybox(x0, x1, y0, y1, z0, z1, wd).paint(grad=("range", 0.3, 0.9)))
    for x in (x0, -3.6, 0.0, 3.6, x1):
        b.add(cc.ybox(x - 0.3, x + 0.3, y0 - 0.2, y0 + 0.3, z0 - 0.1, z1 + 0.1, tim))
    for x in (-5.4, -1.8, 1.8, 5.4):
        b.add(cc.ybox(x - 0.3, x + 0.3, y0 - 0.1, y0, z0 + 2.2, z0 + 3.8, "black"))
    b.add(cc.ybox(x0, x1, y0 - 0.25, y0, z0 + 0.1, z0 + 0.6, tim))
    roof, rise = kit.gable_roof(y1 - y0, x1 - x0, 34.0, overhang=0.8, gable_overhang=0.5, thickness=0.5,
                                color=kc(k, "roof"), rows=2, ridge_color=kc(k, "roof_dark"), style="tile", sag=0.15)
    for q in roof:
        b.add(q.rotate(math.pi / 2, "Z").move(0, (y0 + y1) / 2, z1), tag="roof")
    for sx in (-1, 1):
        g = kit.gable_end(y1 - y0, rise, 0.4, wd)
        b.add(g.rotate(math.pi / 2, "Z").move(sx * (x1 - 0.2), (y0 + y1) / 2, z1))
    b.stats["merlons"] = b.stats.get("merlons", 0) + 4
