"""Birch: one to three slender white trunks (birch_white) with dark birch_mark dashes as small
solid geometry and a dark rough band at the foot, thin upswept limbs ending in twigs, and an
airy light canopy of smaller, slightly drooping leaf clumps with gaps that show the white
wood. Summer (fresh light green) and autumn gold schemes. Collision: trunk box only.

Front faces Blender -Y. Pivot: base centre of the bounding box.
"""

import math

from mathutils import noise as mnoise

from lib.geo import TAU, Vector, box

from generators import _vegetation_common as vc

NAME = "tree_birch"
VERSION = 1
CATEGORY = "tree"
BUDGET = "tree"
COLLISION = {"fidelity": "None"}
CHECKS = {"min_branch_depth": 2, "min_leaf_clusters": 8, "max_trunk_taper": 0.5, "min_bark_marks": 8}
DEFAULT_VARIANTS = 6
LINEUP_GAP = 3.0

PLAN = (
    # style, trunks, height, scheme
    ("single", 1, 30.0, "birch"),
    ("twin", 2, 32.0, "birch"),
    ("clump", 3, 28.0, "birch"),
    ("tall", 1, 34.5, "birch"),
    ("young", 1, 24.5, "birch"),
    ("twin_gold", 2, 30.0, "birch_gold"),
)


def variants(n, seed):
    out = []
    for i in range(n):
        style, trunks, h, scheme = PLAN[i % len(PLAN)]
        out.append({"style": style, "trunks": trunks, "height": h, "leaves": scheme,
                    "seed": seed * 1000 + 59 * i + 17})
    return out


def _trunk(b, rng, base, lean, H, rb, marks_n):
    """One white trunk along a gently curved spine. Returns (spine, radii)."""
    n = 7
    spine, radii = [], []
    bend = Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 0))
    for i in range(n):
        t = i / (n - 1)
        z = H * t
        off = lean * t ** 1.3 + bend * math.sin(math.pi * t)
        spine.append(Vector(base) + Vector((off.x, off.y, z)))
        r = rb * (1.0 - 0.78 * t)
        r *= 1.0 + 0.35 * max(0.0, 1.0 - z / (2.2 * rb)) ** 2
        radii.append(r)
    tr = vc.wood_loft(spine, radii, seg=8, color="birch_white", flute=lambda i: 0.1 if i == 0 else 0.03,
                      seed=rng.uniform(0, 9), grad=("range", 0.35, 0.95), tag="trunk")
    # dark rough foot: faces low on the trunk, ragged upper edge
    foot = rng.uniform(0.9, 1.4)
    seed = rng.uniform(0, 50)
    cols = []
    for f in tr.faces:
        vs = [tr.verts[k] for k in f]
        zc = sum(v.z for v in vs) / len(vs)
        xc = sum(v.x for v in vs) / len(vs)
        yc = sum(v.y for v in vs) / len(vs)
        edge = foot + 1.6 * mnoise.noise(Vector((xc * 2.3 + seed, yc * 2.3, 0.3)))
        cols.append("birch_mark" if zc < edge else "birch_white")
    tr.face_colors = cols
    b.add(vc.clamp_ground(tr))
    # birch_mark dashes: thin dark plates hugging the bark
    marks = 0
    for m in range(marks_n):
        t = rng.uniform(0.12, 0.8)
        i = min(n - 2, int(t * (n - 1)))
        f = t * (n - 1) - i
        c = spine[i].lerp(spine[i + 1], f)
        r = radii[i] + (radii[i + 1] - radii[i]) * f
        a = rng.uniform(0, TAU)
        wdt = r * rng.uniform(1.0, 1.7)
        mk = box(wdt, 0.22, rng.uniform(0.18, 0.32), "birch_mark", base=False)
        mk.rotate(a + math.pi / 2, "Z")
        d = Vector((math.cos(a), math.sin(a), 0))
        b.add(mk.move(c.x + d.x * (r * 0.92), c.y + d.y * (r * 0.92), c.z).paint(grad=("range", 0.3, 0.7),
                                                                                    tag="mark"))
        marks += 1
    return spine, radii, marks


def build(b, p):
    rng = b.rng
    sch = vc.SCHEMES[p["leaves"]]
    nt = p["trunks"]
    H0 = p["height"]
    style = p["style"]
    young = style == "young"
    rb0 = 0.62 if young else 0.85

    trunks = []
    ph = rng.uniform(0, TAU)
    for k in range(nt):
        if nt == 1:
            base, lean = Vector((0, 0, 0)), Vector((rng.uniform(-1.2, 1.2), rng.uniform(-0.6, 0.6), 0))
            H, rb = H0 - 3.0, rb0
        else:
            a = ph + TAU * k / nt
            d = Vector((math.cos(a), math.sin(a), 0))
            base = d * 0.75
            lean = d * (rng.uniform(3.0, 4.2) if nt == 2 else rng.uniform(2.2, 3.0)) + Vector(
                (rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 0))
            H = (H0 - 3.0) * (1.0 if k == 0 else rng.uniform(0.78, 0.9))
            rb = rb0 * (1.0 if k == 0 else 0.85)
        trunks.append((base, lean, H, rb))

    marks = 0
    clusters = 0
    depth = 0
    tops = []
    lobes_per = {1: 3, 2: 3, 3: 2}[nt]
    rims_per = {1: 7, 2: 5, 3: 5}[nt]
    for ti, (base, lean, H, rb) in enumerate(trunks):
        spine, radii, mk = _trunk(b, rng, base, lean, H, rb, 16 if nt == 1 else 12 if nt == 2 else 9)
        marks += mk
        if ti == 0:
            b.stats["trunk_taper"] = round(radii[-1] / rb, 3)
        top = spine[-1]
        out_dir = Vector((lean.x, lean.y, 0))
        out_dir = out_dir.normalized() if out_dir.length > 1e-6 else Vector((1, 0, 0))
        ang = rng.uniform(0, TAU)
        sc = (0.78 if young else 1.0) * (0.85 if nt == 3 else 1.0)
        for li in range(lobes_per):
            u = li / max(1, lobes_per - 1)
            t = 0.56 + 0.44 * u if lobes_per > 2 else 0.74 + 0.26 * u
            if li == lobes_per - 1:
                t = 1.0
            i = min(len(spine) - 2, int(t * (len(spine) - 1)))
            f = t * (len(spine) - 1) - i
            s = spine[i].lerp(spine[i + 1], f)
            r_here = radii[i] + (radii[i + 1] - radii[i]) * f
            rx = (5.2 - 1.6 * u) * sc * rng.uniform(0.92, 1.08)
            rz = (3.9 - 0.6 * u) * sc
            if li == lobes_per - 1:
                lc = top + Vector((0, 0, rz * 0.35))
            else:
                ang += 2.3 + rng.uniform(-0.4, 0.4)
                d = Vector((math.cos(ang), math.sin(ang), 0))
                if nt > 1:
                    d = (d + out_dir * 1.4).normalized()
                lc = s + d * rx * 0.5 + Vector((0, 0, rz * 0.5))
                # limb from the trunk into the lobe (depth 1)
                e = lc - Vector((0, 0, rz * 0.2))
                mid = s + (e - s) * 0.5 + Vector((0, 0, 0.5))
                b.add(vc.limb([s, mid, e], max(0.16, r_here * 0.55), 0.1, seg=5, color="birch_white",
                              grad=("range", 0.4, 0.9)))
                depth = max(depth, 1)
            hg = max(0.0, min(1.0, (lc.z - H0 * 0.35) / (H0 * 0.6)))
            core = vc.puff(rng, 1.0, sch, hglob=hg, subdiv=2, squash=1.0, bottom=0.6, lump=0.18, core=True)
            b.add(core.scale(rx * 0.7, rx * 0.66, rz * 0.7).move(lc.x, lc.y, lc.z))
            clusters += 1
            lo, hi = math.sin(math.radians(-35)), math.sin(math.radians(80))
            golden = math.pi * (3 - math.sqrt(5))
            ph2 = rng.uniform(0, TAU)
            low_rims = []
            for ri in range(rims_per):
                sn = hi - (hi - lo) * (ri + 0.5) / rims_per
                el = math.asin(sn)
                az = ph2 + golden * ri
                dd = Vector((math.cos(el) * math.cos(az) * rx, math.cos(el) * math.sin(az) * rx * 0.92,
                             math.sin(el) * rz))
                cc = lc + dd * 0.78
                cr = (rx + rz) * 0.5 * rng.uniform(0.46, 0.56)
                pf = vc.puff(rng, cr, sch, hglob=max(0.0, min(1.0, hg + 0.25 * math.sin(el))), subdiv=2,
                             squash=0.92, bottom=0.62, lump=0.3, stretch=0.12)
                b.add(pf.move(cc.x, cc.y, cc.z - (0.5 if el < 0 else 0.0)))
                clusters += 1
                if el < 0:
                    low_rims.append(cc)
            # twigs out to the drooping lower clumps (depth 2)
            if li < lobes_per - 1:
                for cc in low_rims[:2]:
                    s2 = (s + lc) / 2
                    b.add(vc.limb([s2, (s2 + cc) / 2 + Vector((0, 0, 0.3)), cc], 0.13, 0.07, seg=4,
                                  color="bark_dark", grad=("range", 0.3, 0.8)))
                    depth = max(depth, 2)
        tops.append(top)

    b.stats["branch_depth"] = depth
    b.stats["leaf_clusters"] = clusters
    b.stats["bark_marks"] = marks
    b.stats["trunks"] = nt
    xs = [t[0].x for t in trunks]
    ys = [t[0].y for t in trunks]
    w = rb0 * 2.2 + (max(xs) - min(xs))
    dpt = rb0 * 2.2 + (max(ys) - min(ys))
    b.collision_box(sum(xs) / nt, sum(ys) / nt, 4.0, w, dpt, 8.0, "trunk")
    b.socket("harvest", sum(xs) / nt, min(ys) - rb0 * 1.3, 0.0)
    tt = max(tops, key=lambda v: v.z)
    b.socket("canopy_top", tt.x, tt.y, tt.z + 2.6)
