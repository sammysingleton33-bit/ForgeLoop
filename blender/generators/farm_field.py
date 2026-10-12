"""Crop field: a 32 x 24 stud plot of tilled soil with raised furrow beds running front to back
(along Y), crops planted in rows, and a low border (woven wattle hurdles or field stones) with
a gap at the front for access. Rows are spaced so a 5.5-stud character walks down the furrows.

Crops: ripe wheat (golden swaying stalk masses crowned with seed heads), wheat mid-harvest
(stubble + drying stooks), cabbages, pumpkins on vines, carrots + lettuce, freshly sown sprouts.

Budget trick: each wheat row is ONE flat-shaded lofted stalk mass plus instanced 6-tri ears, and
other crops are 20-60 tri instanced heads, so the plot reads dense inside the 3000-tri crop budget.
Front (entry gap) faces Blender -Y.
"""

import math

from lib import kit
from lib.geo import Vector, box, cylinder, icosphere, lathe, loft_rings, prism
from lib.geo import mnoise

from generators import _farm_common as fc

NAME = "farm_field"
VERSION = 1
CATEGORY = "farm"
BUDGET = "crop"
COLLISION = {"fidelity": "None"}  # crops are walk-through; the border gets collision boxes
CHECKS = {"min_crops": 20, "min_rows": 4}
DEFAULT_VARIANTS = 6
HERO_VIEW = {"azimuth": 32, "elevation": 30}
LINEUP_GAP = 2.0
GAMEPLAY_HEIGHT = 22.0
GAMEPLAY_DISTANCE = 60.0

W, D = 32.0, 24.0  # plot footprint (X, Y)
Y0, Y1 = -D / 2 + 3.6, D / 2 - 2.0  # beds start after a front headland (walkway) and stop before the back border
ZT = 0.82  # top of the furrow beds

PLANS = [
    {"crop": "wheat", "border": "wattle", "rows": 5, "gap": "centre"},
    {"crop": "wheat_harvest", "border": "stones", "rows": 5, "gap": "left"},
    {"crop": "cabbage", "border": "stones", "rows": 6, "gap": "centre", "scarecrow": True},
    {"crop": "pumpkin", "border": "wattle", "rows": 5, "gap": "right"},
    {"crop": "carrot", "border": "wattle", "rows": 6, "gap": "left"},
    {"crop": "sprouts", "border": "stones", "rows": 6, "gap": "centre", "scarecrow": True},
]


def asset_id(i, params):
    return f"{CATEGORY}_field_{i + 1:02d}"


def variants(n, seed):
    out = []
    for i in range(n):
        p = dict(PLANS[i % len(PLANS)])
        p["seed"] = seed * 1000 + 300 + i
        out.append(p)
    return out


# ------------------------------------------------------------------ layout

def row_layout(n):
    pitch = (W - 4.0) / n
    return [(-(n - 1) / 2 + i) * pitch for i in range(n)], pitch


def furrow_bed(rng, x, y0, y1, half=1.45, h=0.55, color="dirt", stations=2):
    """Raised earth bed along Y (rounded trapezoid profile), lumpy when stations > 2."""
    seed = rng.uniform(0, 50)
    ys = [y0 + (y1 - y0) * i / (stations - 1) for i in range(stations)]
    rings = []
    for k, y in enumerate(ys):
        end = k in (0, stations - 1)
        sw = 0.85 if end else 1.0 + 0.1 * mnoise.noise((x, y * 0.6, seed))
        sh = 0.8 if end else 1.0 + 0.2 * mnoise.noise((x * 0.7, y * 0.9, seed + 3))
        dx = 0.0 if end else 0.15 * mnoise.noise((x * 0.3, y * 0.4, seed + 7))
        prof = [(-half, 0.0), (half, 0.0), (half * 0.8 * sw, h * 0.62 * sh), (half * 0.42 * sw, h * sh),
                (-half * 0.42 * sw, h * sh), (-half * 0.8 * sw, h * 0.62 * sh)]
        rings.append([(x + px + dx * (pz / h), y, 0.3 + pz) for px, pz in prof])
    return loft_rings(rings, color, grad=("range", 0.3, 0.95))


def soil(b):
    """Tilled ground inside the border (the border itself forms the plot edge)."""
    b.add(kit.bbox(W - 1.6, D - 1.6, 0.34, "dirt_dark", 0.12).paint(grad=("range", 0.3, 0.7)), tag="soil")


# ------------------------------------------------------------------ wheat

def sway_dx(y, z_frac, phase, amp=0.3):
    return (amp * math.sin(y * 0.42 + phase) + 0.25) * z_frac


def wheat_row(b, x, y0, y1, h, hw, phase, rng, ear_step=1.4):
    """One row of ripe wheat. A low, flared stalk mass (dark straw, shadowed, tufted top line) is
    pierced by five staggered lanes of instanced 'stalk + head' spindles (6 tris each: long thin
    lower cone = stalk, swollen top = seed head) leaning with the wind; the edge lanes droop
    outwards so the row has a soft bristly silhouette instead of a wall. Returns head count."""
    zb = 0.55
    hb = 2.05  # top of the stalk mass
    L = y1 - y0
    nmid = max(3, int(L / 3.0))
    ys = [y0] + [y0 + L * (i + 0.5) / nmid + rng.uniform(-0.3, 0.3) for i in range(nmid)] + [y1]
    seed = rng.uniform(0, 50)
    rings = []
    for k, y in enumerate(ys):
        end = k in (0, len(ys) - 1)
        s = 0.6 if end else 1.0 + rng.uniform(-0.04, 0.08)
        hh = hb * (0.75 if end else 1.0) + (0.15 if k % 2 else -0.1) + 0.12 * mnoise.noise((x * 0.3, y * 0.35, seed))
        zm = zb + 0.55 * (hh - zb)
        prof = [(-0.6 * hw, zb), (0.6 * hw, zb), (0.9 * hw, zm), (0.8 * hw, hh), (-0.8 * hw, hh), (-0.9 * hw, zm)]
        rings.append([(x + px * s + sway_dx(y, (pz - zb) / (h - zb), phase), y, pz) for px, pz in prof])
    b.add(loft_rings(rings, "wheat_dark", grad=("range", 0.0, 0.8)), tag="crop_body")
    heads = 0
    lanes = (-0.9, -0.45, 0.0, 0.45, 0.9)
    for li, lx in enumerate(lanes):
        y = y0 + 0.25 + ear_step * ((li * 0.37) % 1.0)
        while y < y1 - 0.1:
            yy = y + rng.uniform(-0.2, 0.2)
            out = 1 if lx > 0.5 else (-1 if lx < -0.5 else 0)
            e = fc.spindle(rng.uniform(0.27, 0.32), rng.uniform(2.3, 2.7) * h / 3.9, rng.choice(fc.WHEAT), mid=0.72)
            e.rotate(rng.uniform(0, math.tau), "Z")
            lean = 0.22 + 0.18 * math.sin(yy * 0.42 + phase) + out * 0.3 + rng.uniform(-0.15, 0.15)
            e.rotate(lean, "Y").rotate(rng.uniform(-0.2, 0.2), "X")
            ex = x + lx * hw + sway_dx(yy, 0.5, phase) + rng.uniform(-0.1, 0.1)
            b.add(e.move(ex, yy, hb - 0.9 + rng.uniform(-0.1, 0.25)).paint(grad=("range", 0.3, 1.0)), tag="ear")
            heads += 1
            y += ear_step
    return heads


def stook(rng, h=3.5):
    """Harvested sheaves stood together to dry: a ribbed bundle (each rib = one sheaf) with a
    rope band at the waist, splayed butts and a flared crown of heads."""
    seg = 8
    prof = [(0.0, 0.0), (1.15, 0.0), (0.78, h * 0.4), (1.0, h * 0.62), (0.6, h * 0.86), (0.0, h)]
    p = lathe(prof, seg, rng.choice(("wheat", "hay")), phase=0.0)
    out = []
    for v in p.verts:  # ribs: alternate vertices in/out
        a = math.atan2(v.y, v.x)
        k = 1.0 - 0.16 * (0.5 + 0.5 * math.cos(a * seg / 2))
        out.append(Vector((v.x * k, v.y * k, v.z)))
    p.verts = out
    p.jitter(rng, 0.06).rotate(rng.uniform(-0.08, 0.08), "Y")
    band = cylinder(0.84, 0.84, 0.28, seg, "rope").move(0, 0, h * 0.4 - 0.12)
    out = [p.paint(grad=("range", 0.1, 1.0)), band]
    for k in range(5):  # loose heads splaying out of the crown
        a = math.tau * k / 5 + rng.uniform(-0.3, 0.3)
        e = fc.spindle(0.24, 1.3, rng.choice(fc.WHEAT), mid=0.55).rotate(rng.uniform(0.5, 0.9), "Y").rotate(a, "Z")
        out.append(e.move(math.cos(a) * 0.3, math.sin(a) * 0.3, h * 0.72))
    return out


def scythe():
    out = [cylinder(0.1, 0.1, 5.4, 5, "wood_light")]
    out.append(box(0.12, 0.7, 0.12, "wood").move(0, -0.35, 2.6))
    blade = prism([(0.0, 0.0), (2.6, -0.1), (2.2, 0.35), (0.0, 0.3)], 0.08, "steel", axis="Y")
    out.append(blade.move(0, 0, 5.1))
    return out


# ------------------------------------------------------------------ borders

def border(b, kind, gap_x, rng, gap_w=4.4):
    """Low border on the plot edge with an access gap in the front side at gap_x."""
    e = 0.55  # inset of the border centre line from the footprint edge
    xa, xb, ya, yb = -W / 2 + e, W / 2 - e, -D / 2 + e, D / 2 - e
    sides = [((xa, yb), (xb, yb)), ((xa, ya), (xa, yb)), ((xb, ya), (xb, yb)),
             ((xa, ya), (gap_x - gap_w / 2, ya)), ((gap_x + gap_w / 2, ya), (xb, ya))]
    if kind == "wattle":
        h = 1.9
        posts = set()
        for (x0, y0), (x1, y1) in sides:
            L = math.hypot(x1 - x0, y1 - y0)
            band = fc.wattle_band(L - 0.2, h * rng.uniform(0.94, 1.0), 0.42, ("bark_light", "wood_light"), bumps=3)
            if abs(x1 - x0) < 1e-6:
                band.rotate(math.pi / 2, "Z")
            band.jitter(rng, 0.04)
            b.add(band.move((x0 + x1) / 2, (y0 + y1) / 2, 0.05).paint(grad=("range", 0.2, 0.95)), tag="border")
            n = max(1, round(L / 6.4))
            for i in range(n + 1):
                t = i / n
                posts.add((round(x0 + (x1 - x0) * t, 2), round(y0 + (y1 - y0) * t, 2)))
        for (px, py) in sorted(posts):
            st = fc.stake(h + 0.85 + rng.uniform(-0.1, 0.2), 0.3, "bark_dark", seg=3, point=0.5)
            b.add(st.rotate(rng.uniform(-0.05, 0.05), "X").move(px, py, 0), tag="border")
    else:
        for (x0, y0), (x1, y1) in sides:
            b.add(fc.stone_row(rng, (x0, y0), (x1, y1), h=1.05, d=1.1, block=(1.9, 3.0)), tag="border")


# ------------------------------------------------------------------ other crops

def cabbage(rng, s=1.0):
    head = icosphere(0.62 * s, 1, "cabbage")
    head.scale(1.0, 1.0, 0.85).jitter(rng, 0.05 * s)
    head.move(0, 0, 0.55 * s)
    outer = lathe([(0.0, 0.0), (1.05 * s, 0.5 * s), (0.72 * s, 0.62 * s), (0.0, 0.3 * s)], 5, "crop_green")
    outer.rotate(rng.uniform(0, 1), "Z").jitter(rng, 0.08 * s)
    return [outer.paint(grad=("range", 0.15, 0.9)), head.paint(smooth=True, grad=("range", 0.35, 1.0))]


def pumpkin(rng, s=1.0):
    seg = 10
    prof = [(0.0, 0.0), (0.78 * s, 0.1 * s), (1.0 * s, 0.48 * s), (0.62 * s, 0.9 * s), (0.0, 0.84 * s)]
    p = lathe(prof, seg, "pumpkin", phase=0.0, smooth=True)
    out = []
    for v in p.verts:  # ribs: alternate vertices in/out
        a = math.atan2(v.y, v.x)
        k = 1.0 - 0.1 * (0.5 + 0.5 * math.cos(a * seg / 2))
        out.append(Vector((v.x * k, v.y * k, v.z)))
    p.verts = out
    p.scale(1.0, 1.0, rng.uniform(0.82, 0.95)).rotate(rng.uniform(0, 1), "Z")
    stem = cylinder(0.13 * s, 0.08 * s, 0.5 * s, 4, "crop_dark").rotate(rng.uniform(-0.5, 0.5), "X")
    stem.move(0, 0, 0.72 * s)
    return [p.paint(grad=("range", 0.2, 1.0)), stem]


def carrot(rng):
    out = []
    n = 4
    for k in range(n):
        a = math.tau * k / n + rng.uniform(-0.3, 0.3)
        bl = fc.blade(0.15, rng.uniform(1.4, 1.8), rng.choice(("crop_green", "leaf_light", "crop_green")))
        bl.rotate(rng.uniform(0.25, 0.45), "Y").rotate(a, "Z")
        out.append(bl.paint(grad=("range", 0.2, 1.0)))
    out.append(lathe([(0.22, 0.0), (0.26, 0.18), (0.0, 0.32)], 4, "pumpkin").move(0, 0, -0.05))
    return out


def lettuce(rng):
    p = lathe([(0.0, 0.0), (0.75, 0.22), (0.8, 0.58), (0.0, 0.66)], 6, rng.choice(("leaf_bright", "leaf_yellow")),
              smooth=True)
    p.scale(rng.uniform(0.9, 1.1)).jitter(rng, 0.09)
    return [p.paint(grad=("range", 0.15, 1.0))]


def sprout(rng):
    out = []
    a = rng.uniform(0, math.pi)
    for s in (-1, 1):
        lf = fc.leaf(rng.uniform(0.75, 0.9), 0.44, rng.choice(("crop_green", "leaf_bright")), 0.1, seg=3)
        lf.rotate(-0.6, "Y").rotate(a + (0 if s > 0 else math.pi), "Z")
        out.append(lf.move(0, 0, 0.08).paint(grad=("range", 0.4, 1.0)))
    return out


# ------------------------------------------------------------------ build

def build(b, p):
    rng = b.rng
    crop = p["crop"]
    n = p["rows"]
    xs, pitch = row_layout(n)
    gap_x = {"centre": 0.0, "left": -pitch, "right": pitch}[p["gap"]]
    if n % 2 == 1:
        gap_x += pitch / 2
    soil(b)
    border(b, p["border"], gap_x, rng)
    wheat = crop in ("wheat", "wheat_harvest")
    for x in xs:
        if wheat:
            bed = prism([(-1.55, 0.0), (1.55, 0.0), (1.15, 0.5), (-1.15, 0.5)], Y1 - Y0, "dirt", axis="Y")
            b.add(bed.move(x, (Y0 + Y1) / 2, 0.3).paint(grad=("range", 0.3, 0.95)), tag="bed")
        else:
            b.add(furrow_bed(rng, x, Y0, Y1, half=min(1.5, pitch * 0.34), stations=3), tag="bed")
    crops = 0
    phase = rng.uniform(0, math.tau)
    if wheat:
        cut = 2 if crop == "wheat_harvest" else 0
        for i, x in enumerate(xs):
            if i >= cut:
                crops += wheat_row(b, x, Y0 + 0.2, Y1 - 0.2, rng.uniform(3.7, 4.0), 1.45, phase + i * 0.35, rng)
                continue
            # stubble on the cut beds + stooks drying
            st = prism([(-1.15, 0.0), (1.15, 0.0), (0.95, 0.42), (-0.95, 0.42)], Y1 - Y0 - 0.6, "hay_dark", axis="Y")
            b.add(st.jitter(rng, 0.05).move(x, (Y0 + Y1) / 2, ZT - 0.12), tag="stubble")
            for j in range(2):
                yy = Y0 + 3.6 + j * (Y1 - Y0 - 7.0) + (i % 2) * 1.6 - 0.8
                b.add([q.rotate(rng.uniform(0, 6), "Z").move(x + rng.uniform(-0.2, 0.2), yy, ZT - 0.05)
                       for q in stook(rng)], tag="crop")
                crops += 1
        if cut:  # scythe leaning on the standing wheat, a basket of ears in the headland
            b.add([q.rotate(0.22, "Y").rotate(0.3, "Z").move(xs[cut] - 2.2, Y0 + 1.0, ZT - 0.4) for q in scythe()],
                  tag="prop")
            b.add([q.move(xs[cut - 1] + pitch / 2, Y0 - 1.7, 0.3)
                   for q in fc.basket(rng, 0.85, 0.9, "wood_light", fill="wheat")], tag="prop")
    elif crop == "cabbage":
        for x in xs:
            y = Y0 + 1.0
            while y < Y1 - 0.8:
                b.add([c.move(x + rng.uniform(-0.15, 0.15), y, ZT - 0.05)
                       for c in cabbage(rng, rng.uniform(1.12, 1.32))], tag="crop")
                crops += 1
                y += rng.uniform(2.35, 2.55)
    elif crop == "pumpkin":
        for i, x in enumerate(xs):
            m = 7
            pts = [(x + 0.4 * math.sin(k / (m - 1) * 7.5 + i), Y0 + 0.3 + (Y1 - Y0 - 0.6) * k / (m - 1), ZT + 0.08)
                   for k in range(m)]
            b.add(fc.tube(pts, [0.15] * m, 4, "crop_dark"), tag="vine")
            y = Y0 + 0.9
            k = 0
            while y < Y1 - 0.6:
                side = 1 if k % 2 else -1
                lf = fc.leaf(rng.uniform(1.7, 2.1), rng.uniform(1.5, 1.8), rng.choice(("leaf_mid", "crop_green")),
                             0.3, seg=5)
                lf.rotate(-rng.uniform(0.3, 0.55), "Y").rotate(side * rng.uniform(0.9, 2.2), "Z")
                b.add(lf.move(x + rng.uniform(-0.3, 0.3), y, ZT + 0.12).paint(grad=("range", 0.3, 1.0)), tag="leaf")
                y += rng.uniform(1.3, 1.6)
                k += 1
            y = Y0 + 1.6 + rng.uniform(0, 1.0)
            while y < Y1 - 1.0:
                s = rng.uniform(0.95, 1.45)
                b.add([c.move(x + rng.choice((-1, 1)) * rng.uniform(0.3, 0.8), y, ZT - 0.1) for c in pumpkin(rng, s)],
                      tag="crop")
                crops += 1
                y += rng.uniform(3.8, 4.6)
    elif crop == "carrot":
        for i, x in enumerate(xs):
            y = Y0 + 0.7
            while y < Y1 - 0.5:
                if i % 2 == 0:
                    b.add([c.move(x + rng.uniform(-0.12, 0.12), y, ZT - 0.05) for c in carrot(rng)], tag="crop")
                    y += rng.uniform(1.08, 1.2)
                else:
                    b.add([c.move(x + rng.uniform(-0.12, 0.12), y, ZT - 0.08) for c in lettuce(rng)], tag="crop")
                    y += rng.uniform(1.65, 1.85)
                crops += 1
    elif crop == "sprouts":
        for i, x in enumerate(xs):
            y = Y0 + 0.6
            while y < Y1 - 0.4:
                b.add([c.move(x + rng.uniform(-0.1, 0.1), y, ZT) for c in sprout(rng)], tag="crop")
                crops += 1
                y += rng.uniform(0.8, 0.95)
        # seed sack and basket in the headland
        b.add([q.move(gap_x + 3.2, Y0 - 1.7, 0.3) for q in fc.sack(rng, 1.8, "canvas")], tag="prop")
        b.add([q.move(gap_x + 5.0, Y0 - 1.5, 0.3) for q in fc.basket(rng, 0.8, 0.8, "wood_light", fill="dirt")],
              tag="prop")
    if p.get("scarecrow"):
        sx = xs[1] + pitch / 2 if n > 2 else 0.0
        b.add([q.move(sx, (Y0 + Y1) / 2 + 2.0, 0.3) for q in fc.scarecrow(rng, rng.choice(("tunic_red", "tunic_blue")))],
              tag="scarecrow")
    # accents: worn stepping stones through the entry gap, weeds in the border corners (budget allowing)
    for k in range(2):
        st = fc.fieldstone(rng, rng.uniform(1.3, 1.7), rng.uniform(1.0, 1.3), 0.3, rng.choice(("cobble", "stone")))
        b.add(st.rotate(rng.uniform(-0.3, 0.3), "Z").move(gap_x + rng.uniform(-0.5, 0.5), -D / 2 + 0.5 + k * 1.6,
                                                          0.02 if k == 0 else 0.28)
              .paint(tint=rng.uniform(0, 1)), tag="path")
    if b.tris < 2900:
        for (cx, cy) in ((-W / 2 + 1.5, D / 2 - 1.5), (W / 2 - 1.5, D / 2 - 1.5), (-W / 2 + 1.5, -D / 2 + 1.5),
                         (W / 2 - 1.5, -D / 2 + 1.5)):
            for q in range(3):
                bl = fc.blade(0.13, rng.uniform(0.7, 1.1), rng.choice(("grass", "grass_dark", "grass_light")))
                b.add(bl.rotate(rng.uniform(0.15, 0.5), "Y").rotate(rng.uniform(0, 6.3), "Z")
                      .move(cx + rng.uniform(-0.4, 0.4), cy + rng.uniform(-0.4, 0.4), 0.3), tag="weed")
    # collision: the border only (5 thin boxes), leaving the entry gap and the furrows walkable
    bh = 2.4 if p["border"] == "wattle" else 1.2
    e = 0.55
    b.collision_box(0, D / 2 - e, bh / 2, W, 1.0, bh, "border_back")
    for sx in (-1, 1):
        b.collision_box(sx * (W / 2 - e), 0, bh / 2, 1.0, D, bh, f"border_{'left' if sx < 0 else 'right'}")
    gl, gr = gap_x - 2.2, gap_x + 2.2
    b.collision_box((-W / 2 + gl) / 2, -D / 2 + e, bh / 2, gl + W / 2, 1.0, bh, "border_front_l")
    b.collision_box((W / 2 + gr) / 2, -D / 2 + e, bh / 2, W / 2 - gr, 1.0, bh, "border_front_r")
    b.socket("harvest", 0.0, 0.0, 0.9)
    b.socket("entry", gap_x, -D / 2 - 1.0, 0.0)
    b.stats["crops"] = crops
    b.stats["rows"] = n
