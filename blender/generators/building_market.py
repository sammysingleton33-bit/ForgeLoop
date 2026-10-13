"""Village market stall: stone-kerbed plank deck, chunky timber frame (posts, plates, knee
braces, rafters), a thick striped canvas canopy (alternating canvas / kingdom cloth) with a
scalloped valance, a plank counter loaded with goods, ground displays, hanging goods and a
hanging trade sign. Canopy shapes: gable, lean (awning), vault (wagon hoops), pavilion
(pyramid tent with finial pennant) and a double stall.

Front (counter, customers) faces Blender -Y. Sockets: `interact` = where a player stands
to trade (in front of the counter, ground level); `vendor` = behind the counter on the deck.
"""

import math

from lib import kit
from lib.geo import box, cylinder, lathe
from lib.palette import kingdom_color

from generators import _civic_common as cc

NAME = "building_market"
VERSION = 1
CATEGORY = "building"
BUDGET = "building_small"
COLLISION = {"fidelity": "PreciseConvexDecomposition"}
CHECKS = {"min_pieces": 120, "min_stripes": 9, "min_goods": 6, "min_canvas_tabs": 8}
DEFAULT_VARIANTS = 6

DECK = 0.85  # deck top (stone kerb 0.6 + planks)
T = 0.32  # canvas thickness (solid, never a plane)

# (shape, goods, ground goods, width, depth, post top, pitch, sign icon, extras)
_TABLE = [
    dict(shape="gable", goods="produce", W=11.5, D=8.0, Ht=8.6, pitch=38, icon="apple"),
    dict(shape="lean", goods="fish", W=12.5, D=8.2, Ht=7.9, pitch=24, icon="fish"),
    dict(shape="vault", goods="harvest", W=12.0, D=8.6, Ht=8.0, pitch=0, icon="pumpkin"),
    dict(shape="pavilion", goods="bread", W=10.0, D=9.0, Ht=8.2, pitch=44, icon="sheaf"),
    dict(shape="double", goods="pottery", goods2="produce", W=8.4, W2=7.4, D=7.8, Ht=8.2, Ht2=9.4, pitch=36, icon="jug"),
    dict(shape="pavilion", goods="cloth", W=13.5, D=8.2, Ht=8.8, pitch=38, icon="disc"),
]


def variants(n, seed):
    out = []
    for i in range(n):
        p = dict(_TABLE[i % len(_TABLE)])
        p["kingdom"] = cc.KINGDOM_CYCLE[i % 4]
        p["sign_side"] = 1 if i % 2 == 0 else -1
        p["seed"] = seed * 1000 + 300 + i
        out.append(p)
    return out


# ------------------------------------------------------------------ canopies

def _cols(k, n, alt=False):
    a, c = "canvas", kingdom_color(k, "cloth_light" if alt else "cloth")
    return [a if i % 2 == 0 else c for i in range(n)]


def _stripes(span, target=1.25):
    n = max(5, int(round(span / target)))
    return n if n % 2 == 1 else n + 1


def _tabs_along(b, p0, p1, n, cols, drop=1.05):
    """Valance flaps under an eave edge from p0 to p1 (points on the canopy top surface)."""
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    L = math.hypot(dx, dy)
    ang = math.atan2(dy, dx)
    w = L / n
    for i in range(n):
        t = (i + 0.5) / n
        x, y = p0[0] + dx * t, p0[1] + dy * t
        z = p0[2] + (p1[2] - p0[2]) * t
        b.add(cc.tab(w - 0.06, drop, 0.16, cols[i]).rotate(ang, "Z").move(x, y, z - T * 0.55), tag="tab")


def _canopy_gable(b, k, x0, x1, yf, yb, zp, pitch, ov=1.5, gov=0.7, alt=False, pennants=(-1, 1)):
    tp = math.tan(math.radians(pitch))
    ym = (yf + yb) / 2
    half = (yb - yf) / 2
    zr = zp + T + half * tp
    xa = x0 - gov
    span = (x1 - x0) + 2 * gov
    n = _stripes(span)
    w = span / n
    cols = _cols(k, n, alt)
    vp = half / (half + ov)

    def mk(side):
        ye = (yf - ov) if side < 0 else (yb + ov)

        def fn(u, v):
            y = ym + (ye - ym) * v
            sag = 0.2 * math.sin(math.pi * min(1.0, max(0.0, v / vp)))
            sagx = 0.12 * abs(math.sin(math.pi * (u - xa) / (span / 2)))
            return (u, y, zr - tp * abs(y - ym) - sag - sagx * min(1.0, v * 3))
        return fn

    for side in (-1, 1):
        fn = mk(side)
        for i in range(n):
            b.add(cc.sheet(fn, xa + i * w, xa + (i + 1) * w, 3, T, cols[i]).paint(grad=("range", 0.45, 0.95)),
                  tag="canvas")
        e0, e1 = fn(xa, 1.0), fn(xa + span, 1.0)
        _tabs_along(b, e0, e1, n, cols)
    # ridge pole + pennants
    b.add(cylinder(0.3, 0.3, span + 0.7, 7, "timber").rotate(math.pi / 2, "Y").move(xa - 0.35, ym, zr + 0.02))
    for s, xx in ((-1, xa - 0.2), (1, xa + span + 0.2)):
        if s in pennants:
            for pc in cc.pennant(2.0, 0.95, kingdom_color(k, "cloth"), 2.8):
                if s < 0:
                    pc.rotate(math.pi, "Z")
                b.add(pc.move(xx, ym, zr - 0.3))
    # frame under the canvas: tie beams, king posts, rafters at both ends and the middle
    for xx in (x0, x1):
        b.add(box(0.62, yb - yf + 0.8, 0.62, "timber").move(xx, ym, zp - 0.62))
        b.add(box(0.5, 0.5, zr - T - zp, "timber").move(xx, ym, zp - 0.1))
        for ys in (yf, yb):
            b.add(kit.oriented_box((xx, ys, zp), (xx, ym, zr - T - 0.05), 0.5, 0.5, "timber", (1, 0, 0)))
    return zr


def _canopy_lean(b, k, x0, x1, yf, yb, zf, zb, ov=2.4, gov=0.7):
    tp = (zb - zf) / (yb - yf)
    xa = x0 - gov
    span = (x1 - x0) + 2 * gov
    n = _stripes(span)
    w = span / n
    cols = _cols(k, n)
    yback, yfront = yb + 0.6, yf - ov
    vp0 = (yback - yb) / (yback - yfront)
    vp1 = (yback - yf) / (yback - yfront)

    def fn(u, v):
        y = yback + (yfront - yback) * v
        s = (v - vp0) / (vp1 - vp0)
        sag = 0.25 * math.sin(math.pi * min(1.0, max(0.0, s)))
        sagx = 0.12 * abs(math.sin(math.pi * (u - xa) / (span / 2)))
        return (u, y, zf + T + (y - yf) * tp - sag - sagx * min(1.0, max(0.0, s) * 2))

    for i in range(n):
        b.add(cc.sheet(fn, xa + i * w, xa + (i + 1) * w, 4, T, cols[i]).paint(grad=("range", 0.45, 0.95)),
              tag="canvas")
    _tabs_along(b, fn(xa, 1.0), fn(xa + span, 1.0), n, cols, 1.15)
    # side tabs following the slope (short)
    for s in (-1, 1):
        uu = xa if s < 0 else xa + span
        pa, pb = fn(uu, 0.15), fn(uu, 1.0)
        L = math.hypot(pb[1] - pa[1], pb[2] - pa[2])
        m = max(3, int(L / 1.3))
        for j in range(m):
            t = (j + 0.5) / m
            y = pa[1] + (pb[1] - pa[1]) * t
            z = pa[2] + (pb[2] - pa[2]) * t
            b.add(cc.tab(L / m - 0.06, 0.8, 0.16, cols[0] if j % 2 == 0 else cols[1]).rotate(math.pi / 2, "Z")
                  .move(uu, y, z - T * 0.55), tag="tab")
    # awning poles at the front eave with guy ropes
    ye = yfront + 0.35
    ze = fn(xa, 1.0)[2] - T
    for xx in (xa + 0.5, xa + span - 0.5):
        b.add(cylinder(0.2, 0.16, ze, 6, "wood").move(xx, ye, 0))
        b.add(lathe([(0.0, 0.0), (0.28, 0.1), (0.0, 0.45)], 5, "iron").move(xx, ye, ze))
        sgn = -1 if xx < 0 else 1
        b.add(kit.oriented_box((xx, ye, ze - 0.2), (xx + sgn * 1.6, ye - 2.4, 0.0), 0.1, 0.1, "rope", (0, 0, 1)))
        b.add(cylinder(0.14, 0.08, 0.7, 4, "wood_pale").move(xx + sgn * 1.6, ye - 2.4, -0.1))
    # pennants on the high back corners
    for s_, xx in ((-1, x0), (1, x1)):
        for pc in cc.pennant(1.9, 0.9, kingdom_color(k, "cloth"), 2.6):
            if s_ < 0:
                pc.rotate(math.pi, "Z")
            b.add(pc.move(xx, yb, fn(xx, vp0)[2] - 0.3))
    # rafters under the canvas
    for xx in (x0, (x0 + x1) / 2, x1):
        b.add(kit.oriented_box((xx, yb + 0.3, zb - 0.4), (xx, yf - 0.3, zf - 0.4 - 0.3 * tp), 0.45, 0.45,
                               "timber", (1, 0, 0)))
    return fn(xa, 0.0)[2]


def _canopy_vault(b, k, x0, x1, yf, yb, zp, ov=1.0, gov=0.6):
    half = (yb - yf) / 2
    ym = (yf + yb) / 2
    thp = math.radians(38)
    R = half / math.cos(thp)
    Rv = R * 0.95
    zc = zp + T - Rv * math.sin(thp)
    th0 = math.acos(min(0.99, (half + ov) / R)) if half + ov < R else math.radians(12)
    th0 = max(math.radians(10), min(th0, math.radians(22)))
    xa = x0 - gov
    span = (x1 - x0) + 2 * gov
    n = _stripes(span)
    w = span / n
    cols = _cols(k, n)

    def fn(u, v):
        th = th0 + (math.pi - 2 * th0) * v
        sagx = 0.12 * abs(math.sin(math.pi * (u - xa) / (span / 2))) * math.sin(th)
        rr = Rv - sagx
        return (u, ym - R * math.cos(th), zc + rr * math.sin(th))

    def outward(P):
        return (0.0, P.y - ym, P.z - zc)

    for i in range(n):
        b.add(cc.sheet(fn, xa + i * w, xa + (i + 1) * w, 6, T, cols[i], outward=outward)
              .paint(grad=("range", 0.4, 0.95)), tag="canvas")
    _tabs_along(b, fn(xa, 0.0), fn(xa + span, 0.0), n, cols)
    _tabs_along(b, fn(xa, 1.0), fn(xa + span, 1.0), n, cols)
    # timber hoops under the canvas at the post lines and the middle
    for xx in (x0, (x0 + x1) / 2, x1):
        pts = []
        for j in range(9):
            th = th0 + (math.pi - 2 * th0) * j / 8
            pts.append((xx, ym - (R - T - 0.25) * math.cos(th), zc + (Rv - T - 0.25) * math.sin(th)))
        b.add(cc.tube_arc(pts, 0.27, "timber"))
    # ridge batten + pennant at each end
    b.add(cylinder(0.24, 0.24, span + 0.4, 6, "timber").rotate(math.pi / 2, "Y").move(xa - 0.2, ym, zc + Rv + 0.08))
    for s, xx in ((-1, xa - 0.1), (1, xa + span + 0.1)):
        for pc in cc.pennant(1.8, 0.9, kingdom_color(k, "cloth"), 2.4):
            if s < 0:
                pc.rotate(math.pi, "Z")
            b.add(pc.move(xx, ym, zc + Rv - 0.4))
    return zc + Rv


def _canopy_pavilion(b, k, x0, x1, yf, yb, zp, pitch, ov=1.3):
    cx, cy = (x0 + x1) / 2, (yf + yb) / 2
    hx, hy = (x1 - x0) / 2, (yb - yf) / 2
    tp = math.tan(math.radians(pitch))
    za = zp + T + min(hx, hy) * tp + 0.6
    apex = (cx, cy, za)
    ex, ey = hx + ov, hy + ov
    corners = [(cx - ex, cy - ey), (cx + ex, cy - ey), (cx + ex, cy + ey), (cx - ex, cy + ey)]
    # eave height: the plane through the apex and the plate line, extended by the overhang
    stripes = 0
    ze = za - (za - (zp + T)) * min(ex / hx, ey / hy)  # common eave: canvas never dips into the plates
    for f in range(4):
        (ax, ay), (bx, by) = corners[f], corners[(f + 1) % 4]
        L = math.hypot(bx - ax, by - ay)
        n = _stripes(L, 1.35)
        cols = _cols(k, n)

        def fn(u, v, ax=ax, ay=ay, bx=bx, by=by, ze=ze):
            ex_, ey_ = ax + (bx - ax) * u, ay + (by - ay) * u
            sag = 0.22 * math.sin(math.pi * min(1.0, v / 0.85))
            return (apex[0] + (ex_ - apex[0]) * v, apex[1] + (ey_ - apex[1]) * v,
                    apex[2] + (ze - apex[2]) * v - sag)

        for i in range(n):
            b.add(cc.sheet(fn, i / n, (i + 1) / n, 2, T, cols[i], v0=0.035).paint(grad=("range", 0.45, 0.95)),
                  tag="canvas")
            stripes += 1
        _tabs_along(b, fn(0.0, 1.0), fn(1.0, 1.0), n, cols)
    # finial: cap, pole, pennant
    b.add(lathe([(0.0, -0.6), (0.75, -0.4), (0.55, 0.1), (0.0, 0.35)], 7, kingdom_color(k, "trim")).move(*apex))
    for pc in cc.pennant(2.6, 1.2, kingdom_color(k, "cloth"), 3.6):
        b.add(pc.move(apex[0], apex[1], za + 0.1))
    # hip rafters under the canvas
    for (ax, ay) in corners:
        px, py = cx + (ax - cx) * hx / ex, cy + (ay - cy) * hy / ey
        b.add(kit.oriented_box((px, py, zp - 0.45), (cx, cy, za - T - 1.3), 0.42, 0.42, "timber", (0, 0, 1)))
    b.add(box(0.6, 0.6, za - T - 1.1 - zp, "timber").move(cx, cy, zp))
    b.add(box(0.5, yb - yf, 0.5, "timber").move(cx, cy, zp - 0.5))
    return za


# ------------------------------------------------------------------ counter and goods

def _display(b, rng, kind, x, y, z, slot_w, goods_count):
    """One counter display item centred at (x, y) on a surface at z."""
    if kind in ("apple", "pear", "cabbage"):
        sx, sy, sz = slot_w - 0.35, 1.55, 0.75
        th = 0.32
        for pc in cc.produce_crate(rng, kind, sx, sy, sz, rng.choice(("wood_light", "wood_pale")),
                                   n=3 if kind == "cabbage" else 4, s=0.9 if kind == "cabbage" else 1.0):
            b.add(pc.move(0, -sy / 2, 0).rotate(th, "X").move(x, y + sy / 2 - 0.1, z + 0.02))
        goods_count[0] += 1
    elif kind == "pumpkin":
        for j, dx in enumerate((-slot_w * 0.22, slot_w * 0.22)):
            for pc in cc.fruit("pumpkin", rng, 0.85):
                b.add(pc.move(x + dx, y + rng.uniform(-0.2, 0.2), z))
            goods_count[0] += 1
    elif kind == "fish":
        b.add(kit.bbox(slot_w - 0.2, 1.7, 0.4, "foam", 0.12).move(x, y, z).paint(grad=("range", 0.6, 1.0)))
        for j in range(3):
            for pc in cc.fruit("fish", rng, 0.9):
                b.add(pc.rotate(rng.uniform(-0.5, 0.5) + (0.0 if j % 2 else math.pi), "Z")
                      .move(x + (j - 1) * 0.15, y - 0.55 + j * 0.55, z + 0.32))
            goods_count[0] += 1
    elif kind == "loaf":
        b.add(kit.bbox(slot_w - 0.3, 1.6, 0.25, "wood", 0.08).move(x, y, z))
        for j in range(4):
            for pc in cc.fruit("loaf", rng):
                b.add(pc.rotate(math.pi / 2 + rng.uniform(-0.15, 0.15), "Z")
                      .move(x - slot_w * 0.3 + j * slot_w * 0.2, y + rng.uniform(-0.1, 0.1), z + 0.25))
            goods_count[0] += 1
    elif kind == "round_loaf":
        for pc in cc.basket(rng, 0.95, 0.7, None, "straw"):
            b.add(pc.move(x, y, z))
        for j in range(3):
            a = j * 2.1
            for pc in cc.fruit("round_loaf", rng, 0.7):
                b.add(pc.move(x + math.cos(a) * 0.38, y + math.sin(a) * 0.38, z + 0.62))
            goods_count[0] += 1
    elif kind == "bolt":
        for j, (dx, dz) in enumerate(((-0.45, 0.0), (0.45, 0.0), (0.0, 0.72))):
            for pc in cc.fruit("bolt", rng, 0.95):
                b.add(pc.rotate(math.pi / 2, "Z").move(x + dx, y, z + dz))
            goods_count[0] += 1
    elif kind == "jug":
        for j in range(3):
            for pc in cc.fruit("jug", rng, rng.uniform(0.75, 1.05)):
                b.add(pc.move(x - slot_w * 0.3 + j * slot_w * 0.3, y + rng.uniform(-0.3, 0.3), z))
            goods_count[0] += 1
    elif kind == "cheese":
        for j, (dx, dz) in enumerate(((-0.5, 0.0), (0.55, 0.0), (-0.45, 0.55))):
            for pc in cc.fruit("cheese", rng, 0.85):
                b.add(pc.move(x + dx, y, z + dz))
            goods_count[0] += 1


_GOODS = {
    "produce": ["apple", "cabbage", "pear", "apple"],
    "fish": ["fish", "fish", "fish"],
    "harvest": ["cabbage", "pumpkin", "apple", "pumpkin"],
    "bread": ["loaf", "round_loaf", "loaf"],
    "pottery": ["jug", "cheese", "jug"],
    "cloth": ["bolt", "bolt", "bolt", "bolt", "bolt"],
}


def _counter(b, rng, cx, Wc, yfront, goods, goods_count, kc_cloth="canvas"):
    depth, hc = 1.9, 2.55
    z0 = DECK
    b.add(box(Wc - 0.2, depth - 0.3, hc, "wood_dark").move(cx, yfront + depth / 2, z0))
    nb = max(3, int(Wc / 1.05))
    bw = Wc / nb
    for i in range(nb):
        x = cx - Wc / 2 + bw * (i + 0.5)
        b.add(box(bw - 0.1, 0.3, hc - 0.05, rng.choice(("wood", "wood", "wood_light"))).move(x, yfront + 0.15, z0))
    for zz in (0.45, hc - 0.75):
        b.add(box(Wc + 0.1, 0.24, 0.38, "timber").move(cx, yfront - 0.06, z0 + zz))
    b.add(kit.bbox(Wc + 0.5, depth + 0.5, 0.36, "wood_light", 0.1).move(cx, yfront + depth / 2 - 0.1, z0 + hc))
    top = z0 + hc + 0.36
    nt = max(3, int(round(Wc / 1.5)))
    cols = [kc_cloth if i % 2 == 0 else "canvas" for i in range(nt)]
    _tabs_along(b, (cx - Wc / 2, yfront - 0.32, top + T * 0.55 - 0.02), (cx + Wc / 2, yfront - 0.32, top + T * 0.55 - 0.02),
                nt, cols, 0.75)
    kinds = _GOODS[goods]
    nslot = max(2, int(Wc / 2.6))
    sw = Wc / nslot
    for i in range(nslot):
        _display(b, rng, kinds[i % len(kinds)], cx - Wc / 2 + sw * (i + 0.5), yfront + depth / 2 - 0.1, top, sw,
                 goods_count)
    return top


def _ground_goods(b, rng, goods, cx, W, yfront, goods_count):
    """Baskets, barrels, sacks and heaps on the ground in front of / beside the counter."""
    y = yfront - 1.25
    if goods in ("produce", "harvest"):
        for pc in cc.basket(rng, 0.95, 1.0, "apple" if goods == "produce" else "cabbage"):
            b.add(pc.move(cx - W * 0.28, y, 0))
        for pc in cc.basket(rng, 0.85, 0.9, "pear" if goods == "produce" else "apple"):
            b.add(pc.move(cx - W * 0.28 + 2.1, y - 0.3, 0))
        goods_count[0] += 2
        if goods == "harvest":
            for j, (dx, dy) in enumerate(((0, 0), (1.8, 0.2), (0.9, -1.3), (0.95, -0.35))):
                for pc in cc.fruit("pumpkin", rng, 1.15 if j < 2 else 0.95):
                    b.add(pc.move(cx + W * 0.12 + dx, y + 0.2 + dy, 0.0 if j != 3 else 1.05))
                goods_count[0] += 1
            for pc in cc.sack_pile(rng, 2, 1.8, 0.9):
                b.add(pc.move(cx + W / 2 + 1.6, yfront + 2.0, 0))
        else:
            for pc in cc.barrel(0.9, "wood", None):
                b.add(pc.move(cx + W * 0.3, y + 0.1, 0))
            for pc in cc.produce_pile(rng, "apple", 1.6, 1.6, 4, 0.4):
                b.add(pc.move(cx + W * 0.3, y + 0.1, 2.25 - 0.05))
            goods_count[0] += 1
    elif goods == "fish":
        for j, dx in enumerate((-W * 0.3, W * 0.26)):
            for pc in cc.barrel(0.85, "wood", "water"):
                b.add(pc.move(cx + dx, y, 0))
        for pc in cc.basket(rng, 1.0, 0.85, "fish", "hay_dark", 3):
            b.add(pc.move(cx - W * 0.3 + 2.3, y - 0.2, 0))
        goods_count[0] += 3
        # net drying on a rack at the side
        sx = cx + W / 2 + 1.4
        for yy in (yfront + 0.5, yfront + 4.5):
            b.add(cylinder(0.16, 0.14, 4.8, 5, "wood").move(sx, yy, 0))
        b.add(cylinder(0.12, 0.12, 4.4, 5, "wood").rotate(-math.pi / 2, "X").move(sx, yfront + 0.3, 4.6))
        net = cc.sheet(lambda u, v: (sx + 0.05 * math.sin(v * 9), yfront + 0.6 + 3.8 * u, 4.5 - 3.4 * v), 0.0, 1.0,
                       3, 0.12, "rope", outward=lambda P: (1, 0, 0))
        b.add(net)
    elif goods == "bread":
        for pc in cc.sack_pile(rng, 3, 2.6, 0.95, "cloth_white"):
            b.add(pc.move(cx + W * 0.28, y, 0))
        for pc in cc.basket(rng, 1.0, 0.9, "round_loaf", "straw", 3):
            b.add(pc.move(cx - W * 0.3, y, 0))
        goods_count[0] += 4
    elif goods == "pottery":
        for j in range(4):
            for pc in cc.fruit("jug", rng, rng.uniform(1.3, 1.7)):
                b.add(pc.move(cx - W * 0.3 + j * 1.35, y + rng.uniform(-0.3, 0.3), 0))
            goods_count[0] += 1
        for pc in cc.produce_crate(rng, "apple", 2.2, 1.7, 1.0):
            b.add(pc.move(cx + W * 0.3, y, 0))
    elif goods == "cloth":
        for pc in cc.crate(2.0, 1.6, 1.4, "wood_light"):
            b.add(pc.move(cx - W * 0.3, y, 0))
        for j, (dx, dz) in enumerate(((-0.45, 1.4), (0.45, 1.4))):
            for pc in cc.fruit("bolt", rng, 0.95):
                b.add(pc.rotate(math.pi / 2, "Z").move(cx - W * 0.3 + dx, y, dz))
        for pc in cc.basket(rng, 0.9, 0.9, None, "straw"):
            b.add(pc.move(cx + W * 0.3, y, 0))
        for j in range(3):
            for pc in cc.fruit("bolt", rng, 0.7):
                b.add(pc.rotate(math.pi / 2, "Z").rotate(0.4 * j, "Y").move(cx + W * 0.3 - 0.3 + j * 0.3, y, 0.95))
        goods_count[0] += 6


def _hanging(b, rng, goods, x0, x1, y, z):
    """Goods hanging on cords under the front plate."""
    n = min(3, max(2, int((x1 - x0) / 2.6)))
    for i in range(n):
        x = x0 + (x1 - x0) * (i + 0.5) / n + rng.uniform(-0.2, 0.2)
        drop = rng.uniform(0.9, 1.6)
        b.add(box(0.08, 0.08, drop, "rope").move(x, y, z - drop))
        zz = z - drop
        if goods in ("produce", "harvest"):
            for j in range(3):  # onion / garlic string
                b.add(lathe([(0.0, 0.0), (0.3, 0.12), (0.26, 0.38), (0.0, 0.62)], 5,
                            rng.choice(("thatch_light", "straw", "wheat"))).move(x + rng.uniform(-0.12, 0.12), y,
                                                                                  zz - 0.55 * (j + 1)))
        elif goods == "fish":
            for pc in cc.fruit("fish", rng, 0.8):
                b.add(pc.rotate(-math.pi / 2, "Y").move(x, y, zz - 0.2))
        elif goods == "bread":
            ring = cylinder(0.55, 0.55, 0.22, 7, "wood_light").rotate(math.pi / 2, "X").move(x, y + 0.11, zz - 0.55)
            b.add(ring)
        elif goods == "pottery":
            for pc in cc.fruit("jug", rng, 0.6):
                b.add(pc.move(x, y, zz - 1.3))
        elif goods == "cloth":
            col = rng.choice(("tunic_red", "tunic_blue", "tunic_green", "tunic_cream", "flower_purple"))
            b.add(box(1.3, 0.14, 2.2, col).move(x, y, zz - 2.2 + 0.1).paint(grad=("range", 0.4, 0.9)))
            b.add(box(1.3, 0.2, 0.18, "gold").move(x, y, zz - 2.15))


# ------------------------------------------------------------------ build

def _frame(b, x0, x1, yf, yb, zf, zb, posts_x, skip_x=()):
    """Posts (front at yf, back at yb) with plates on top and knee braces."""
    for xx in posts_x:
        if any(abs(xx - s) < 0.05 for s in skip_x):
            continue
        for yy, zt in ((yf, zf), (yb, zb)):
            for pc in cc.post(zt - 0.6 - 0.62, 0.82, "timber", pad=False):
                b.add(pc.move(xx, yy, 0.6))
    for yy, zt in ((yf, zf), (yb, zb)):
        b.add(box(x1 - x0 + 0.9, 0.7, 0.62, "timber").move((x0 + x1) / 2, yy, zt - 0.62))
        for xx in posts_x:
            for s in (-1, 1):
                if (s < 0 and xx <= x0 + 0.5) or (s > 0 and xx >= x1 - 0.5):
                    continue
                b.add(cc.knee_brace((xx + s * 0.35, yy, zt - 2.3), (xx + s * 1.7, yy, zt - 0.6), (0, -1, 0)))


def _deck(b, rng, x0, x1, y0, y1):
    W, D = x1 - x0, y1 - y0
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    for pc in cc.plinth(W, D, 0.6, rng, "stone_dark", cx, cy, depth=0.9, bev=0.0, block=(2.8, 4.6)):
        b.add(pc)
    for pc in kit.plank_floor(W + 0.2, D + 0.2, 0.28, 1.3, "wood", rng, along="x"):
        b.add(pc.move(cx, cy, 0.58))


def build(b, p):
    rng = b.rng
    k = p["kingdom"]
    shape = p["shape"]
    goods_count = [0]
    D = p["D"] + rng.uniform(-0.2, 0.3)
    yf, yb = -D / 2 + 0.45, D / 2 - 0.45

    if shape == "double":
        W1, W2 = p["W"], p["W2"]
        bays = [(-W1, 0.0, -W1 + 0.45, 0.0, p["Ht"], "gable", False, (0.0,)),
                (0.0, W2, 0.0, W2 - 0.45, p["Ht2"], "gable", True, ())]
    else:
        W = p["W"] + rng.uniform(-0.3, 0.3)
        bays = [(-W / 2, W / 2, -W / 2 + 0.45, W / 2 - 0.45, p["Ht"], shape, False, ())]
    xmin, xmax = bays[0][0], bays[-1][1]
    _deck(b, rng, xmin, xmax, -D / 2, D / 2)

    tops = []
    for bi, (x0, x1, px0, px1, Ht, shp, alt, skip) in enumerate(bays):
        zf = Ht
        zb = Ht
        if shp == "lean":
            zb = Ht + (yb - yf) * math.tan(math.radians(p["pitch"]))
        nposts = 3 if (px1 - px0) > 12.0 else 2
        posts_x = [px0 + (px1 - px0) * i / (nposts - 1) for i in range(nposts)]
        _frame(b, px0, px1, yf, yb, zf, zb, posts_x, skip)
        if shp == "gable":
            top = _canopy_gable(b, k, px0, px1, yf, yb, zf, p["pitch"] + (6 if bi == 1 else 0), alt=False,
                                gov=0.7 if bi == 0 or len(bays) == 1 else 0.45,
                                pennants=(-1,) if (shape == "double" and bi == 0) else (-1, 1))
        elif shp == "lean":
            top = _canopy_lean(b, k, px0, px1, yf, yb, zf, zb)
        elif shp == "vault":
            top = _canopy_vault(b, k, px0, px1, yf, yb, zf)
        else:
            top = _canopy_pavilion(b, k, px0, px1, yf, yb, zf, p["pitch"])
        tops.append(top)

        # counter, goods, hanging goods
        Wc = (x1 - x0) - 0.5
        cxb = (x0 + x1) / 2
        ycf = -D / 2 - 0.15
        goods = p["goods"] if bi == 0 else p.get("goods2", p["goods"])
        _counter(b, rng, cxb, Wc, ycf, goods, goods_count, kingdom_color(k, "cloth"))
        if bi == 0:
            _hanging(b, rng, goods, px0 + 0.8, px1 - 0.8, yf - 0.1, zf - 0.62)
        if bi == 0:
            b.socket("interact", cxb, ycf - 1.8, 0.0)
            b.socket("vendor", cxb, ycf + 2.9, DECK)
        else:
            b.socket("interact_2", cxb, ycf - 1.8, 0.0)
            b.socket("vendor_2", cxb, ycf + 2.9, DECK)
        if bi == 0:
            _ground_goods(b, rng, goods, cxb, x1 - x0, ycf, goods_count)
        else:
            for pc in cc.basket(rng, 0.95, 1.0, "apple"):
                b.add(pc.move(cxb + 1.2, ycf - 1.3, 0))
            goods_count[0] += 1

        # back shelf with stock behind the vendor
        b.add(kit.bbox(Wc * 0.8, 1.3, 2.3, "wood", 0.08).move(cxb, yb - 0.3, DECK))
        for j in range(1 if shape == "double" else 2):
            for pc in cc.crate(1.5, 1.1, 1.1, rng.choice(("wood_light", "wood_pale"))):
                b.add(pc.rotate(rng.uniform(-0.1, 0.1), "Z").move(cxb - Wc * 0.22 + j * Wc * 0.44, yb - 0.3,
                                                                    DECK + 2.3))

    # hanging trade sign on the outer front post
    side = p["sign_side"]
    sx = (xmax - 0.45) if side > 0 else (xmin + 0.45)
    zt = bays[-1][4] if side > 0 else bays[0][4]
    icon_col = {"apple": "apple_red", "fish": "stone_cool", "pumpkin": "pumpkin", "sheaf": "wheat",
                "jug": "clay", "disc": kingdom_color(k, "cloth")}[p["icon"]]
    icon = {"fish": "fish", "pumpkin": "apple", "jug": "jug"}.get(p["icon"], p["icon"])
    for pc in cc.hanging_sign(icon, icon_col, side=side, arm=2.9, w=2.3, h=1.7):
        b.add(pc.move(sx + side * 0.4, yf, zt - 1.0))

    # storage behind the stall: crate stack + barrel (+ a sack)
    bx = (xmin + xmax) / 2 + (xmax - xmin) * 0.22 * (-side)
    for pc in cc.crate_stack(rng, 2 if shape == "double" else 3, 1.9, "wood_light"):
        b.add(pc.move(bx, D / 2 + 1.6, 0))
    if shape != "double":
        for pc in cc.barrel(1.0, "wood"):
            b.add(pc.move(bx + side * 3.2, D / 2 + 1.5, 0))

    b.stats["stripes"] = b.count_tag("canvas")
    b.stats["canvas_tabs"] = b.count_tag("tab")
    b.stats["goods"] = goods_count[0]
    b.stats["pieces"] = len(b.pieces)
