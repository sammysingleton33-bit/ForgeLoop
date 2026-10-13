"""Crop field: a 32 x 24 stud plot (24 x 24 pumpkin patch, 16 x 24 kitchen bean garden) of tilled soil with raised furrow beds running front to back
(along Y), crops planted in rows, and a low border (woven wattle hurdles or field stones) with
a gap at the front for access. Rows are spaced so a 5.5-stud character walks down the furrows.

Crops: ripe wheat (swaying stalk masses crowned with seed heads), wheat mid-harvest (stubble
tufts, tied sheaves stood in stooks), cabbages + scarecrow, pumpkins on vines + tool rack, runner
beans on pole teepees + carrots, and leafy seedlings + scarecrow.

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
VERSION = 3
CATEGORY = "farm"
BUDGET = "crop"
COLLISION = {"fidelity": "None"}  # crops are walk-through; the border gets collision boxes
CHECKS = {"min_crops": 12, "min_rows": 3}
DEFAULT_VARIANTS = 6
HERO_VIEW = {"azimuth": 32, "elevation": 30}
LINEUP_GAP = 2.0
GAMEPLAY_HEIGHT = 22.0
GAMEPLAY_DISTANCE = 60.0

D = 24.0  # plot depth (Y); the width W (X) is per variant
Y0, Y1 = -D / 2 + 3.6, D / 2 - 2.0  # beds start after a front headland (walkway) and stop before the back border
ZT = 0.82  # top of the furrow beds

PLANS = [
    {"crop": "wheat", "border": "wattle", "rows": 4, "gap": "centre", "w": 32.0},
    {"crop": "wheat_harvest", "border": "wattle", "rows": 4, "gap": "left", "w": 32.0},
    {"crop": "cabbage", "border": "stones", "rows": 6, "gap": "centre", "scarecrow": True, "w": 32.0},
    {"crop": "pumpkin", "border": "wattle", "rows": 4, "gap": "right", "w": 24.0, "tool_rack": True},
    {"crop": "corn_beans", "border": "wattle", "rows": 3, "gap": "centre", "w": 16.0},
    {"crop": "turnips", "border": "wattle", "rows": 5, "gap": "right", "w": 32.0, "trough": True},
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

def row_layout(n, W):
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


def soil(b, W, color="dirt_dark"):
    """Tilled ground inside the border (the border itself forms the plot edge)."""
    b.add(kit.bbox(W - 1.6, D - 1.6, 0.34, color, 0.12).paint(grad=("range", 0.3, 0.7)), tag="soil")


# ------------------------------------------------------------------ wheat

def sway_dx(y, z_frac, phase, amp=0.3):
    return (amp * math.sin(y * 0.42 + phase) + 0.25) * z_frac


def wheat_row(b, x, y0, y1, h, hw, phase, rng, step=1.1):
    """One row of ripe wheat: a low, dark, shadowed stalk mass (soft loft, tufted top line) out of
    which rise clumps of three thin stalks (4-tri cones), each carrying a smooth ear (6 tris),
    fanned out and leaning with the wind; clumps zig-zag across the row. Ears reach ~4 studs
    (waist height for a 5.5-stud character). Muted straw tones only. Returns the ear count."""
    zb = 0.55
    hb = h  # top of the stalk mass
    L = y1 - y0
    nmid = max(3, int(L / 3.0))
    ys = [y0] + [y0 + L * (i + 0.5) / nmid + rng.uniform(-0.3, 0.3) for i in range(nmid)] + [y1]
    seed = rng.uniform(0, 50)
    rings = []
    for k, y in enumerate(ys):
        end = k in (0, len(ys) - 1)
        s_ = 0.7 if end else 1.0 + rng.uniform(-0.04, 0.06)
        hh = hb * (0.85 if end else 1.0) + (0.15 if k % 2 else -0.1) + 0.12 * mnoise.noise((x * 0.3, y * 0.35, seed))
        zm = zb + 0.6 * (hh - zb)
        prof = [(-0.55 * hw, zb), (0.55 * hw, zb), (0.95 * hw, zm), (0.72 * hw, hh), (-0.72 * hw, hh), (-0.95 * hw, zm)]
        rings.append([(x + px * s_ + sway_dx(y, (pz - zb) / 3.5, phase), y, pz) for px, pz in prof])
    b.add(loft_rings(rings, "hay", smooth=True, grad=("range", 0.0, 0.5)), tag="crop_body")
    ears = 0
    y = y0 + 0.45
    k = 0
    while y < y1 - 0.25:
        cx = x + (0.5 if k % 2 else -0.5) * hw * 0.85 + rng.uniform(-0.12, 0.12) + sway_dx(y, 0.4, phase)
        cy = y + rng.uniform(-0.15, 0.15)
        a0 = rng.uniform(0, math.tau)
        wind = 0.18 + 0.12 * math.sin(y * 0.42 + phase)
        for j in range(3):
            a = a0 + math.tau * j / 3 + rng.uniform(-0.3, 0.3)
            tilt = rng.uniform(0.12, 0.3)
            ln = rng.uniform(1.35, 1.75)
            base_z = hb - 0.4
            dx = math.cos(a) * math.sin(tilt) * ln + wind * ln
            dy = math.sin(a) * math.sin(tilt) * ln
            top = Vector((cx + dx, cy + dy, base_z + math.cos(tilt) * ln))
            d = top - Vector((cx, cy, base_z))
            st = lathe([(0.09, 0.0), (0.0, d.length + 0.3)], 3, "thatch")
            st.transform(d.to_track_quat("Z", "Y").to_matrix().to_4x4())
            b.add(st.move(cx, cy, base_z), tag="stalk")
            ear = fc.spindle(rng.uniform(0.28, 0.33), rng.uniform(1.3, 1.55), rng.choice(fc.WHEAT), seg=3, mid=0.42)
            ear.paint(smooth=True, grad=("range", 0.4, 1.0))
            ear.transform(d.to_track_quat("Z", "Y").to_matrix().to_4x4())
            ear.rotate(wind * 0.6, "Y")
            b.add(ear.move(top.x, top.y, top.z - 0.1), tag="ear")
            ears += 1
        y += step
        k += 1
    return ears


def sheaf(rng, h=3.0):
    """One tied sheaf: dark cut butts, a contrasting band at the waist, a flared head of ears on top."""
    prof = [(0.55, 0.0), (0.4, h * 0.4), (0.66, h * 0.68), (0.48, h * 0.86), (0.0, h)]
    p = lathe(prof, 4, "hay")
    p.face_colors = [("thatch_dark" if fi < 4 else ("straw" if 8 <= fi < 16 else "hay")) for fi in range(len(p.faces))]
    p.jitter(rng, 0.04)
    band = cylinder(0.46, 0.44, 0.34, 4, "cloth_brown").move(0, 0, h * 0.36)
    return [p.paint(grad=("range", 0.2, 1.0)), band]


def stook(rng):
    """Four tied sheaves stood head-to-head to dry (butts splayed, heads touching)."""
    out = []
    for k in range(4):
        a = math.tau * k / 4 + rng.uniform(-0.2, 0.2) + 0.4
        for q in sheaf(rng, rng.uniform(3.4, 3.8)):
            q.rotate(-0.26, "Y").rotate(a, "Z").move(math.cos(a) * 0.78, math.sin(a) * 0.78, 0)
            out.append(q)
    return out


def stubble_row(rng, x, y0, y1, step=1.5):
    """Cut stubble: a low lumpy band of stalk ends with stiff tufts poking out of it."""
    out = [furrow_bed(rng, x, y0, y1, half=1.25, h=0.38, color="thatch_dark", stations=4).move(0, 0, ZT - 0.3)]
    y = y0 + 0.4
    k = 0
    while y < y1 - 0.2:
        t = fc.blade(rng.uniform(0.28, 0.34), rng.uniform(0.55, 0.75), rng.choice(("hay_dark", "thatch_dark", "hay")))
        t.rotate(rng.uniform(-0.25, 0.25), "Y").rotate(rng.uniform(0, 6.3), "Z")
        out.append(t.move(x + (0.6 if k % 2 else -0.6) + rng.uniform(-0.15, 0.15), y, ZT + 0.02)
                   .paint(grad=("range", 0.2, 0.95)))
        y += step
        k += 1
    return out


def scythe():
    out = [cylinder(0.1, 0.1, 5.4, 5, "wood_light")]
    out.append(box(0.12, 0.7, 0.12, "wood").move(0, -0.35, 2.6))
    blade = prism([(0.0, 0.0), (2.6, -0.1), (2.2, 0.35), (0.0, 0.3)], 0.08, "steel", axis="Y")
    out.append(blade.move(0, 0, 5.1))
    return out


# ------------------------------------------------------------------ borders

def border(b, kind, gap_x, rng, W, gap_w=4.4):
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
    seg = 8
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


def turnip(rng):
    """Young turnip: three broad upright leaves over a white bulb with a purple shoulder."""
    out = []
    a0 = rng.uniform(0, math.tau)
    for k in range(3):
        lf = fc.leaf(rng.uniform(1.6, 1.9), rng.uniform(0.95, 1.1), rng.choice(("leaf_mid", "crop_green", "leaf_dark")),
                     0.14, seg=3)
        lf.rotate(-rng.uniform(0.85, 1.1), "Y").rotate(a0 + math.tau * k / 3 + rng.uniform(-0.25, 0.25), "Z")
        out.append(lf.move(0, 0, 0.3).paint(grad=("range", 0.25, 1.0)))
    bulb = lathe([(0.0, 0.0), (0.45, 0.22), (0.32, 0.5), (0.0, 0.58)], 3, "flower_white", smooth=True)
    bulb.face_colors = [("flower_purple" if fi >= 3 else "flower_white") for fi in range(len(bulb.faces))]
    out.append(bulb.move(0, 0, -0.1))
    return out


def corn(rng, h=6.6):
    """Maize plant: thin stalk, four drooping strap leaves, a tan tassel and a husked cob."""
    out = [cylinder(0.22, 0.12, h, 4, "crop_green").paint(grad=("range", 0.2, 0.9))]
    a0 = rng.uniform(0, math.tau)
    for k in range(4):
        L = rng.uniform(2.7, 3.2)
        lf = fc.leaf(L, rng.uniform(0.52, 0.62), rng.choice(("crop_green", "leaf_mid", "leaf_light")), 0.12, seg=3)
        lf.rotate(-0.6, "Y")  # rise out of the stalk...
        lf.bend(lambda v, L=L: (v.x, v.y, v.z - 0.55 * L * (max(0.0, v.x) / L) ** 2))  # ...and droop at the tip
        lf.rotate(a0 + k * math.pi + rng.uniform(-0.5, 0.5) + (k // 2) * 1.4, "Z")
        out.append(lf.move(0, 0, h * (0.28 + 0.16 * k)).paint(grad=("range", 0.3, 1.0)))
    for k in range(3):  # tassel
        t = fc.blade(0.07, rng.uniform(0.9, 1.2), rng.choice(("thatch_light", "hay", "thatch")))
        out.append(t.rotate(rng.uniform(0.25, 0.5), "Y").rotate(a0 + k * 2.1, "Z").move(0, 0, h - 0.15))
    cob = fc.spindle(0.24, 1.1, "crop_dark", seg=4)
    out.append(cob.rotate(0.45, "Y").rotate(a0 + 0.8, "Z").move(0, 0, h * 0.42))
    return out


def bean_pole(rng, h=6.6):
    """Runner bean climbing a single tall pole: spiral vine, heart leaves, red flowers, pods."""
    out = [cylinder(0.11, 0.08, h, 4, "wood_light").rotate(rng.uniform(-0.05, 0.05), "X")]
    pts = []
    a0 = rng.uniform(0, math.tau)
    for i in range(7):
        t = i / 6
        a = a0 + t * 3.5 * math.pi
        pts.append((math.cos(a) * 0.2, math.sin(a) * 0.2, 0.3 + (h - 0.6) * t))
    out.append(fc.tube(pts, [0.07] * len(pts), 3, "crop_dark"))
    for i in range(1, 6):
        px, py, pz = pts[i]
        lf = fc.leaf(rng.uniform(1.0, 1.25), rng.uniform(0.8, 0.95), rng.choice(("leaf_mid", "crop_green", "leaf_dark")),
                     0.1, seg=3)
        lf.rotate(rng.uniform(0.05, 0.4), "Y").rotate(math.atan2(py, px) + rng.uniform(-0.4, 0.4), "Z")
        out.append(lf.move(px, py, pz).paint(grad=("range", 0.3, 1.0)))
    for i, z in enumerate((h * 0.35, h * 0.55, h * 0.75)):
        a = a0 + i * 2.2
        if i % 2 == 0:
            out.append(fc.spindle(0.08, 0.9, "crop_dark", seg=3).move(math.cos(a) * 0.35, math.sin(a) * 0.35, z - 0.9))
        else:
            out.append(fc.spindle(0.2, 0.32, "flower_red", seg=3).move(math.cos(a) * 0.35, math.sin(a) * 0.35, z))
    return out


def trough(rng):
    """Water trough on two blocks with a bucket beside it."""
    out = [kit.bbox(3.8, 1.4, 1.0, "wood", 0.1).move(0, 0, 0.3), box(3.4, 1.0, 0.1, "water").move(0, 0, 1.15)]
    for sx in (-1, 1):
        out.append(box(0.6, 1.6, 0.4, "stone").move(sx * 1.4, 0, 0.0))
    out.append(lathe([(0.0, 0.0), (0.45, 0.0), (0.55, 0.8), (0.0, 0.8)], 6, "wood").move(2.6, 0.2, 0.0))
    out.append(cylinder(0.56, 0.56, 0.1, 6, "iron_dark").move(2.6, 0.2, 0.55))
    return out


def tool_rack(rng):
    """Two posts and a rail with a hoe, a spade and a rake hung on it (a vertical accent)."""
    out = []
    for sx in (-1, 1):
        out.append(box(0.32, 0.32, 3.6, "wood_dark").move(sx * 1.6, 0, 0).jitter(rng, 0.02))
    out.append(box(3.8, 0.28, 0.28, "wood").move(0, 0, 3.0))
    hoe = [cylinder(0.08, 0.08, 2.9, 4, "wood_light").move(0, 0, 0.3), box(0.6, 0.12, 0.4, "iron")]
    spade = [cylinder(0.08, 0.08, 2.3, 4, "wood_light").move(0, 0, 0.7), box(0.55, 0.08, 0.75, "steel"),
             box(0.6, 0.12, 0.12, "wood").move(0, 0, 3.0)]
    for tool, x in ((hoe, -0.9), (spade, 0.2)):  # leaning on the rail, heads down
        for q in tool:
            out.append(q.rotate(0.12, "X").move(x, -0.3, 0.15))
    for q in fc.rake(3.2, 4):
        out.append(q.rotate(math.pi, "Y").move(1.0, -0.25, 3.35))
    return out


# ------------------------------------------------------------------ build

def build(b, p):
    rng = b.rng
    crop = p["crop"]
    n = p["rows"]
    W = p.get("w", 32.0)
    xs, pitch = row_layout(n, W)
    gap_x = {"centre": 0.0, "left": -pitch, "right": pitch}[p["gap"]]
    if n % 2 == 1:
        gap_x += pitch / 2
    wheat = crop in ("wheat", "wheat_harvest")
    soil(b, W, "mud" if wheat else "dirt_dark")  # low-saturation browns under wheat (gold stays the kingdom's)
    border(b, p["border"], gap_x, rng, W)
    for x in xs:
        if wheat:
            bed = prism([(-1.9, 0.0), (1.9, 0.0), (1.5, 0.5), (-1.5, 0.5)], Y1 - Y0, "road_dark", axis="Y")
            b.add(bed.move(x, (Y0 + Y1) / 2, 0.3).paint(grad=("range", 0.3, 0.95)), tag="bed")
        else:
            b.add(furrow_bed(rng, x, Y0, Y1, half=min(1.5, pitch * 0.34), stations=3), tag="bed")
    crops = 0
    phase = rng.uniform(0, math.tau)
    if wheat:
        cut = 2 if crop == "wheat_harvest" else 0
        for i, x in enumerate(xs):
            if i >= cut:
                crops += wheat_row(b, x, Y0 + 0.2, Y1 - 0.2, rng.uniform(2.15, 2.35), 1.55, phase + i * 0.35, rng)
                continue
            # cut beds: stubble band + a row of bound sheaves laid across the bed, one stook drying
            b.add(stubble_row(rng, x, Y0 + 0.3, Y1 - 0.3), tag="stubble")
            stook_y = Y0 + 3.2 + i * 9.0
            y = Y0 + 1.2
            while y < Y1 - 1.0:
                if abs(y - stook_y) > 1.6:
                    for q in sheaf(rng, rng.uniform(2.8, 3.1)):
                        b.add(q.move(0, 0, -1.5).rotate(math.pi / 2, "Y").rotate(rng.uniform(-0.25, 0.25), "Z")
                              .move(x + rng.uniform(-0.2, 0.2), y, ZT + 0.45), tag="crop")
                    crops += 1
                y += rng.uniform(2.6, 2.9)
            b.add([q.move(x + rng.uniform(-0.2, 0.2), stook_y, ZT - 0.05) for q in stook(rng)], tag="crop")
            crops += 1
        if cut:  # scythe leaning on the standing wheat, a basket of ears in the headland
            b.add([q.rotate(0.22, "Y").rotate(0.3, "Z").move(xs[cut] - 2.2, Y0 + 1.0, ZT - 0.4) for q in scythe()],
                  tag="prop")
            b.add([q.move(xs[cut - 1] + pitch / 2, Y0 - 1.7, 0.3)
                   for q in fc.basket(rng, 0.85, 0.9, "wood_light", fill="hay")], tag="prop")
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
                             0.3, seg=4)
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
    elif crop == "corn_beans":
        for i, x in enumerate(xs):
            if i % 2 == 0:  # maize rows, 6-7 studs tall
                y = Y0 + 0.9
                while y < Y1 - 0.6:
                    b.add([q.move(x + rng.uniform(-0.25, 0.25), y, ZT - 0.1) for q in corn(rng, rng.uniform(6.2, 7.0))],
                          tag="crop")
                    crops += 1
                    y += rng.uniform(1.6, 1.8)
            else:  # runner beans climbing single poles
                y = Y0 + 1.3
                while y < Y1 - 0.8:
                    b.add([q.move(x + rng.uniform(-0.15, 0.15), y, ZT - 0.1) for q in bean_pole(rng, rng.uniform(6.3, 6.9))],
                          tag="crop")
                    crops += 1
                    y += rng.uniform(2.3, 2.5)
    elif crop == "turnips":
        for i, x in enumerate(xs):
            y = Y0 + 0.8
            while y < Y1 - 0.6:
                b.add([c.move(x + rng.uniform(-0.12, 0.12), y, ZT) for c in turnip(rng)], tag="crop")
                crops += 1
                y += rng.uniform(1.45, 1.6)
    if p.get("trough"):
        b.add([q.rotate(0.08, "Z").move(-W / 2 + 4.6, Y0 - 1.6, 0.3) for q in trough(rng)], tag="prop")
    if p.get("tool_rack"):
        b.add([q.rotate(0.1, "Z").move(-W / 2 + 3.4, Y0 - 1.9, 0.3) for q in tool_rack(rng)], tag="prop")
    if p.get("scarecrow"):
        sx = xs[1] + pitch / 2 if n > 2 else 0.0
        b.add([q.move(sx, (Y0 + Y1) / 2 + 2.0, 0.3) for q in fc.scarecrow(rng, rng.choice(("tunic_red", "tunic_blue")))],
              tag="scarecrow")
    # accents: worn stepping stones through the entry gap, weeds in the border corners (budget allowing)
    for k in range(2):
        st = fc.fieldstone(rng, rng.uniform(1.3, 1.7), rng.uniform(1.0, 1.3), 0.3, rng.choice(("cobble", "stone")))
        b.add(st.rotate(rng.uniform(-0.3, 0.3), "Z").move(gap_x + rng.uniform(-0.4, 0.4), -D / 2 + 0.5 + k * 1.6,
                                                          0.02 if k == 0 else 0.28)
              .paint(tint=rng.uniform(0, 1)), tag="path")
    if b.tris < 2800 and crop != "wheat":
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
