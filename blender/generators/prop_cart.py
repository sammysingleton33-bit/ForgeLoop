"""Village carts and wagons on spoked, iron-tyred wheels, with loads.

  handcart  2 wheels, long pull handles + rest legs, sacks, a crate and a basket
  haycart   2 large wheels, ladder sides, a heaped hay load with a pitchfork, horse shafts
  wagon     4-wheel supply wagon: crates, barrel and sacks, draw pole with a yoke bar
  logcart   2 big wheels, bolster stakes, a stack of cut logs bound with rope
  covered   4-wheel covered wagon: canvas tilt over hoops with a kingdom stripe

Side boards are painted in the kingdom shutter colour (same rule as village doors and
shutters). Front (pulling end) faces -Y. Bed floors sit ~2.3-2.9 above the ground.
Sockets: `interact` = where a character grabs the handles / where a draught animal is
hitched (ground level); `load` = centre of the bed floor (cargo attach point).
"""

import math

from lib import kit
from lib.geo import Vector, box, cone, cylinder, icosphere, lathe, look_rot, tube

from generators._kingdom_props_common import KINGDOMS, barrel, crate, kcol, rope, sack, sheet, wheel

NAME = "prop_cart"
VERSION = 1
CATEGORY = "prop"
BUDGET = "prop"
COLLISION = {"fidelity": "Hull"}
CHECKS = {"min_wheels": 2, "min_spokes": 12, "min_load": 1}
DEFAULT_VARIANTS = 5
HERO_VIEW = {"azimuth": 38, "elevation": 22}
TYPES = ("handcart", "haycart", "wagon", "logcart", "covered")


def variants(n, seed):
    return [{"kingdom": KINGDOMS[i % 4], "type": TYPES[i % 5], "seed": seed * 1000 + i} for i in range(n)]


def asset_id(i, p):
    return f"{CATEGORY}_cart_{p['type']}_{i // 5 + 1:02d}"


def add_wheels(b, xs, y, r, spokes=6, seg=10, width=0.55, hub_seg=8):
    for x in xs:
        b.add([pc.move(x, y, r) for pc in wheel(r, width, spokes, seg, wood="wood", hub="wood_dark", cap=None,
                                                hub_seg=hub_seg)])
        b.stats["wheels"] = b.stats.get("wheels", 0) + 1
        b.stats["spokes"] = b.stats.get("spokes", 0) + spokes


def bed(b, k, Lb, Wb, zf, side_h, rng, ladder=False, front=True, back=True, mid_stakes=True):
    """Plank floor on two runners, painted side boards, corner stakes. Returns floor top z."""
    paint = kcol(k, "shutter")
    b.add(kit.bbox(Wb, Lb, 0.35, "wood", 0.08).move(0, 0, zf), grad=("range", 0.3, 0.8))
    for sx in (-1, 1):
        b.add(box(0.45, Lb - 0.2, 0.5, "wood_dark").move(sx * (Wb / 2 - 0.55), 0, zf - 0.5))
    top = zf + 0.35
    if ladder:  # rails with spindles (hay cart)
        for sx in (-1, 1):
            x = sx * (Wb / 2 - 0.1)
            b.add(box(0.3, Lb + 0.4, 0.3, paint).move(x, 0, top + side_h - 0.3))
            b.add(box(0.28, Lb, 0.5, paint).move(x, 0, top))
            n = 6
            for i in range(n):
                y = -Lb / 2 + 0.3 + (Lb - 0.6) * i / (n - 1)
                b.add(box(0.2, 0.2, side_h, "wood_dark").move(x, y, top))
    else:
        for sx in (-1, 1):
            b.add(box(0.25, Lb, side_h, paint).move(sx * (Wb / 2 - 0.12), 0, top), grad=("range", 0.35, 0.85))
            b.add(box(0.32, Lb + 0.1, 0.22, "wood_dark").move(sx * (Wb / 2 - 0.12), 0, top + side_h - 0.22))
        ends = [s for s, on in ((-1, front), (1, back)) if on]
        for sy in ends:
            b.add(box(Wb - 0.5, 0.25, side_h * 0.85, "wood").move(0, sy * (Lb / 2 - 0.12), top))
        for sx in (-1, 1):
            for sy in ((-1, 0, 1) if mid_stakes else (-1, 1)):
                b.add(box(0.32, 0.32, side_h + 0.35, "timber").move(sx * (Wb / 2 + 0.02), sy * (Lb / 2 - 0.2), top - 0.1))
    return top


def shafts(b, Wb, y0, length, z0, z1, spread=2.6, color="wood", legs=True):
    """Two pull handles / horse shafts from the bed front (y0) forward to -Y."""
    for sx in (-1, 1):
        p0 = Vector((sx * (Wb / 2 - 0.4), y0 + 0.8, z0))
        p1 = Vector((sx * spread / 2, y0 - length, z1))
        b.add(kit.oriented_box(p0, p1, 0.3, 0.3, color, Vector((0, 0, 1))))
        if legs:  # rest leg so the cart stands level
            lz = z0 - 0.2
            b.add(kit.oriented_box((sx * (Wb / 2 - 0.4), y0 - 0.2, lz), (sx * (Wb / 2 - 0.3), y0 - 0.5, 0.0),
                                   0.26, 0.26, "wood_dark", Vector((1, 0, 0))))
    b.add(box(spread + 0.2, 0.26, 0.26, "wood_dark").move(0, y0 - length * 0.55, z0 + (z1 - z0) * 0.55 - 0.13))


def hay_mound(b, Wb, Lb, top, h, rng):
    """Heaped hay load: one rounded lumpy heap bulging over the rails, bristling with straw
    tufts (fibrous silhouette), held down by two ropes."""
    ax, ay, az = Wb * 0.64, Lb * 0.56, h
    core = icosphere(1.0, 2, "hay")
    core.scale(ax, ay, az)
    core.noise_displace(0.3, 0.7, rng.uniform(0, 50))
    core.bend(lambda v: (v.x, v.y, max(v.z, -0.35)))
    z0 = top + 0.3
    b.add(core.move(0, 0, z0).paint(smooth=True, grad=("range", 0.05, 0.95)), tag="load")
    for i in range(18):  # straw tufts combed down the heap: a fringe at the bulge, a few on top
        th = math.tau * (i + rng.uniform(-0.3, 0.3)) / 13
        ph = rng.uniform(1.15, 1.45) if i < 13 else rng.uniform(0.35, 0.9)
        d = Vector((math.sin(ph) * math.cos(th), math.sin(ph) * math.sin(th), math.cos(ph)))
        p0 = Vector((d.x * ax * 0.98, d.y * ay * 0.98, z0 + d.z * az * 0.98))
        nrm = Vector((d.x / ax, d.y / ay, d.z / az)).normalized()
        down = (Vector((0, 0, -1)) - nrm * nrm.z).normalized()  # down-slope tangent
        out = (down * 0.72 + nrm * 0.45).normalized()
        t = cone(0.34, rng.uniform(0.8, 1.05), 3, rng.choice(("straw", "thatch_light", "straw", "hay_dark")))
        t.scale(1.0, 0.5, 1.0)
        b.add(t.transform(look_rot(out)).move(*p0), grad=("range", 0.4, 1.0))
    for y in (-ay * 0.45, ay * 0.45):  # ropes over the heap
        pts = []
        for j in range(7):
            a = math.pi * j / 6
            pts.append((-math.cos(a) * ax * 1.0, y, z0 + math.sin(a) * az * 1.0 - 0.05 * (1 - math.sin(a))))
        b.add(rope(pts, r=0.1, seg=4))


def build_handcart(b, k, rng):
    Lb, Wb, r = 4.8, 3.4, 1.95
    zf = r + 0.6
    top = bed(b, k, Lb, Wb, zf, 0.95, rng, front=True, back=False)
    b.add(box(Wb + 1.6, 0.4, 0.4, "wood_dark").move(0, 0.4, r - 0.2))  # axle tree
    b.add(box(Wb - 0.6, 0.5, zf - r - 0.2, "wood_dark").move(0, 0.4, r + 0.15))  # bolster
    add_wheels(b, (-(Wb / 2 + 0.55), Wb / 2 + 0.55), 0.4, r)
    shafts(b, Wb, -Lb / 2, 3.6, zf + 0.1, 3.0, spread=2.4)
    # load: sacks, a crate, a basket of apples
    for i, (x, y, lean) in enumerate(((-0.75, 0.9, 0.15), (0.65, 1.1, -0.1), (0.0, -0.4, 0.25))):
        for pc in sack(rng, 0.62, 1.5, rng.choice(("canvas", "canvas_dark", "cloth_brown")), lean=lean):
            b.add(pc.move(x, y, top), tag="load")
    for pc in crate(1.3, 1.3, 1.2, rng=rng):
        b.add(pc.rotate(0.2, "Z").move(-0.8, -1.3, top))
    bk = lathe([(0.0, 0.0), (0.55, 0.0), (0.72, 0.62), (0.62, 0.62), (0.0, 0.4)], 7, "wood_pale")
    b.add(bk.move(0.85, -1.2, top))
    for j in range(4):
        a = math.tau * j / 4
        b.add(icosphere(0.24, 1, "apple_red").move(0.85 + math.cos(a) * 0.3, -1.2 + math.sin(a) * 0.3, top + 0.62))
    b.socket("interact", 0, -Lb / 2 - 3.8, 0)
    b.socket("load", 0, 0, top)


def build_haycart(b, k, rng):
    Lb, Wb, r = 6.6, 4.2, 2.45
    zf = r + 0.15
    top = bed(b, k, Lb, Wb, zf, 1.5, rng, ladder=True)
    b.add(box(Wb + 1.8, 0.45, 0.45, "wood_dark").move(0, 0.3, r - 0.22))
    add_wheels(b, (-(Wb / 2 + 0.6), Wb / 2 + 0.6), 0.3, r, spokes=8)
    b.add(box(Wb - 0.6, 0.5, 0.4, "wood_dark").move(0, 0.3, r))  # bolster
    shafts(b, Wb, -Lb / 2, 5.0, zf + 0.1, 1.4, spread=2.8)
    hay_mound(b, Wb, Lb, top, 2.4, rng)
    # pitchfork stuck in the hay
    p0 = Vector((0.9, 1.6, top + 0.6))
    d = Vector((0.25, 0.35, 1.0)).normalized()
    b.add(kit.oriented_box(p0, p0 + d * 4.4, 0.16, 0.16, "wood_light", Vector((1, 0, 0))))
    for t in (-0.22, 0.0, 0.22):
        b.add(kit.oriented_box(p0 + Vector((t, 0, 0)), p0 + Vector((t, 0, 0)) - d * 0.9, 0.08, 0.08, "iron",
                               Vector((0, 1, 0))))
    b.socket("interact", 0, -Lb / 2 - 5.2, 0)
    b.socket("load", 0, 0, top)


def build_wagon(b, k, rng, covered=False):
    Lb, Wb = (8.6, 4.4) if not covered else (9.2, 4.6)
    rf, rr = 1.9, 2.25
    zf = rr + 0.4
    top = bed(b, k, Lb, Wb, zf, 1.0, rng, mid_stakes=False)
    yf, yr = -Lb / 2 + 1.7, Lb / 2 - 1.9
    for y, r in ((yf, rf), (yr, rr)):
        b.add(box(Wb + 1.6, 0.45, 0.45, "wood_dark").move(0, y, r - 0.22))
        b.add(box(Wb - 0.6, 0.5, zf - r - 0.25, "wood_dark").move(0, y, r + 0.2))  # bolster
        add_wheels(b, (-(Wb / 2 + 0.55), Wb / 2 + 0.55), y, r, hub_seg=6)
    # draw pole with a yoke bar, resting on the ground
    p0 = Vector((0, yf, rf + 0.1))
    p1 = Vector((0, -Lb / 2 - 4.6, 0.35))
    b.add(kit.oriented_box(p0, p1, 0.32, 0.32, "wood", Vector((0, 0, 1))))
    b.add(kit.oriented_box((-1.6, p1.y + 0.5, 0.55), (1.6, p1.y + 0.5, 0.55), 0.3, 0.3, "wood_dark",
                           Vector((0, 0, 1))))
    # driver's bench at the front
    b.add(kit.bbox(Wb - 0.4, 1.1, 0.3, "wood_light", 0.06).move(0, -Lb / 2 + 0.75, top + 1.2))
    for sx in (-1, 1):
        b.add(box(0.25, 0.25, 1.2, "timber").move(sx * (Wb / 2 - 0.5), -Lb / 2 + 0.75, top))
    if not covered:
        for pc in crate(1.7, 1.6, 1.5, rng=rng):
            b.add(pc.rotate(0.06, "Z").move(-0.95, 1.9, top), tag="load")
        for pc in crate(1.4, 1.4, 1.3, color="wood", rng=rng, brace=False):
            b.add(pc.rotate(-0.2, "Z").move(-0.95, 1.9, top + 1.5))
        for pc in barrel(2.0, 0.72):
            b.add(pc.move(1.1, 2.1, top), tag="load")
        for pc in sack(rng, 0.72, 1.5, "canvas", lean=0.3):
            b.add(pc.rotate(0.4, "Z").move(0.9, -0.3, top), tag="load")
        # rope lashing over the load
        b.add(rope([(-Wb / 2, 1.9, top + 0.9), (-0.9, 1.9, top + 2.95), (0.9, 1.9, top + 2.1), (Wb / 2, 1.9, top + 0.9)],
                   r=0.09, seg=4))
    else:
        # canvas tilt over three hoops, kingdom stripe along the middle
        hs = [(-Lb / 2 + 1.4), 0.4, (Lb / 2 - 0.4)]
        R = Wb / 2 + 0.15
        zb = top + 0.9

        def arch(u):
            a = math.pi * u
            return -math.cos(a) * R, zb + math.sin(a) * R * 1.05

        for y in hs:
            pts = [(arch(u)[0] * 0.97, y, arch(u)[1] - 0.15) for u in (0.0, 0.2, 0.5, 0.8, 1.0)]
            b.add(tube(pts, [0.12] * 5, 4, "wood_dark"))
        y0, y1 = hs[0] - 0.5, hs[-1] + 0.4
        us = [0.0, 0.14, 0.3, 0.42, 0.58, 0.7, 0.86, 1.0]
        vs = [0.0, 0.35, 0.65, 1.0]

        def pos(u, v):
            x, z = arch(u)
            y = y0 + (y1 - y0) * v
            sag = 0.18 * math.sin(math.pi * ((v * 2) % 1.0)) if 0 < u < 1 else 0.0
            return (x, y, z - sag)

        def cols(kind, i, j):
            if kind == "edge":
                return "canvas_dark"
            return kcol(k, "cloth") if i in (3, 4) else ("canvas" if i % 2 else "canvas_dark")

        b.add(sheet(us, vs, pos, 0.22, "canvas", cols, normal="auto"), grad=("range", 0.35, 0.95), tag="load")
        # cords tying the tilt down at the sides
        for sx in (-1, 1):
            for y in (hs[0], hs[-1]):
                b.add(box(0.12, 0.12, 0.9, "rope").move(sx * (R - 0.05), y, top + 0.05))
        # a sack and a small crate peeking out of the back
        for pc in sack(rng, 0.6, 1.3, "cloth_brown", lean=0.35):
            b.add(pc.move(0.8, Lb / 2 - 1.0, top))
        for pc in crate(1.1, 1.1, 1.0, color="wood_pale", rng=rng, brace=False):
            b.add(pc.rotate(0.2, "Z").move(-0.8, Lb / 2 - 1.1, top))
        # kingdom pennant on the front hoop
        fx, fz = R * 0.97, zb + 0.2
        b.add(cylinder(0.08, 0.07, 2.6, 5, "timber").move(fx, hs[0], fz))

        def ppos(u, v):
            return (fx + 0.1 + u * 1.9, hs[0] + 0.12 * math.sin(u * 4) * u, fz + 2.5 - v * 0.9 * (1 - 0.75 * u))

        b.add(sheet([0.0, 0.5, 1.0], [0.0, 1.0], ppos, 0.14, kcol(k, "cloth")), grad=("range", 0.3, 0.9))
    b.socket("interact", 0, -Lb / 2 - 4.6, 0)
    b.socket("load", 0, 0.8, top)


def build_logcart(b, k, rng):
    Lb, Wb, r = 7.4, 3.6, 2.6
    zf = r - 0.1
    # open frame: two runners + bolsters with stakes instead of a box bed
    for sx in (-1, 1):
        b.add(kit.bbox(0.55, Lb, 0.55, "wood", 0.08).move(sx * (Wb / 2 - 0.4), 0, zf))
    b.add(box(Wb + 2.0, 0.5, 0.5, "wood_dark").move(0, 0.0, r - 0.25))
    add_wheels(b, (-(Wb / 2 + 0.75), Wb / 2 + 0.75), 0.0, r, spokes=8, seg=12)
    top = zf + 0.55
    for y in (-Lb / 2 + 0.8, Lb / 2 - 0.8):
        b.add(kit.bbox(Wb + 0.8, 0.7, 0.55, kcol(k, "shutter"), 0.08).move(0, y, top))
        for sx in (-1, 1):
            b.add(box(0.3, 0.3, 2.6, "wood_dark").move(sx * (Wb / 2 + 0.2), y, top))
    shafts(b, Wb, -Lb / 2, 4.6, zf + 0.2, 1.3, spread=2.6, legs=False)
    # log stack 3-2-1 (pyramid), cut ends showing
    ll = Lb + rng.uniform(0.6, 1.2)
    rl = 0.58
    n = 0
    for row, cnt in enumerate((3, 2, 1)):
        for j in range(cnt):
            x = (j - (cnt - 1) / 2) * (2 * rl + 0.05)
            z = top + 0.55 + rl + row * (rl * 1.75)
            lg = cylinder(rl, rl * rng.uniform(0.92, 1.0), ll, 7, rng.choice(("bark", "bark_dark", "bark")))
            lg.rotate(math.pi / 2, "X").move(x, ll / 2 + rng.uniform(-0.3, 0.3), z)
            b.add(lg, tag="load")
            cy = lg.bounds()[0].y
            b.add(cylinder(rl * 0.82, rl * 0.82, 0.08, 7, "wood_pale").rotate(math.pi / 2, "X")
                  .move(x, cy + 0.02, z))
            n += 1
    for y in (-Lb * 0.25, Lb * 0.25):  # rope bindings over the stack
        b.add(rope([(-Wb / 2 - 0.1, y, top + 0.6), (-1.4, y, top + 2.9), (0.0, y, top + 4.0), (1.4, y, top + 2.9),
                    (Wb / 2 + 0.1, y, top + 0.6)], r=0.1, seg=4))
    b.stats["logs"] = n
    b.socket("interact", 0, -Lb / 2 - 4.8, 0)
    b.socket("load", 0, 0, top)


def build(b, p):
    rng = b.rng
    k = p["kingdom"]
    t = p["type"]
    if t == "handcart":
        build_handcart(b, k, rng)
    elif t == "haycart":
        build_haycart(b, k, rng)
    elif t == "wagon":
        build_wagon(b, k, rng)
    elif t == "covered":
        build_wagon(b, k, rng, covered=True)
    else:
        build_logcart(b, k, rng)
    b.stats["load"] = max(1, b.count_tag("load"))
    b.stats["pieces"] = len(b.pieces)
