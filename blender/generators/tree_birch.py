"""Birch: white trunks (birch_white) with dark birch_mark dashes as small solid geometry and a
dark rough band at the foot, upswept limbs ending in dark twigs, and a light canopy of large
foliage masses with gaps that show the white wood.

Every variant has its own stem layout (planned explicitly, not a rescaled template):
leaning single stem, twin stems, three-stem clump, an old stem whose snapped top is capped by
foliage while a side leader carries an asymmetric crown, young stem with a chunky low side
branch, and a forked trunk in autumn gold. Crowns are 3-5 large smooth primary masses with a
few satellite clumps (the oak's language at birch scale). Trunks sit next to the oaks: base
radius 0.85-1.3, root flare + small dark roots + dark foot band, taper, bends/kinks.
Collision: trunk box only. Front faces Blender -Y. Pivot: base centre of the bounding box.
"""

import math

from mathutils import noise as mnoise

from lib.geo import TAU, Vector, box, lathe

from generators import _vegetation_common as vc

NAME = "tree_birch"
VERSION = 3
CATEGORY = "tree"
BUDGET = "tree"
COLLISION = {"fidelity": "None"}
CHECKS = {"min_branch_depth": 2, "min_leaf_clusters": 8, "max_trunk_taper": 0.5, "min_bark_marks": 8}
DEFAULT_VARIANTS = 6
LINEUP_GAP = 3.0

PLAN = (
    ("leaning", "birch"),
    ("twin", "birch"),
    ("clump", "birch"),
    ("broken", "birch"),
    ("young_branch", "birch"),
    ("forked", "birch_gold"),
)


def variants(n, seed):
    out = []
    for i in range(n):
        style, scheme = PLAN[i % len(PLAN)]
        out.append({"style": style, "leaves": scheme, "seed": seed * 1000 + 59 * i + 17})
    return out


# ------------------------------------------------------------------ stems

def _spine(base, top, bend, kink=None, n=8):
    """Quadratic-Bezier spine base -> top through base + (top-base)/2 + bend, plus an optional
    kink (offset vector, at fraction t) that bends the stem visibly once."""
    base, top, bend = Vector(base), Vector(top), Vector(bend)
    ctrl = (base + top) / 2 + bend
    pts = vc.bezier(base, ctrl, top, n)
    if kink:
        kv, kt = kink
        for i in range(n):
            t = i / (n - 1)
            w = max(0.0, 1.0 - abs(t - kt) / 0.35)
            pts[i] = pts[i] + Vector(kv) * w
    return pts


def _trunk(b, rng, spine, rb, r_top, marks_n, foot=True, broken=False):
    """White trunk along `spine`; radius tapers rb -> r_top with a root flare at ground level.
    Returns radii and the number of bark marks."""
    n = len(spine)
    radii = []
    for i, c in enumerate(spine):
        t = i / (n - 1)
        r = rb + (r_top - rb) * t ** 0.85
        if foot:
            r *= 1.0 + 0.55 * max(0.0, 1.0 - c.z / (2.2 * rb)) ** 2  # modest root flare
        radii.append(r)
    tr = vc.wood_loft(spine, radii, seg=8, color="birch_white", flute=lambda i: 0.1 if (i == 0 and foot) else 0.03,
                      seed=rng.uniform(0, 9), grad=("range", 0.35, 0.95), tag="trunk")
    footh = rng.uniform(1.3, 1.7)
    seed = rng.uniform(0, 50)
    ztop = spine[-1].z
    cols = []
    for f in tr.faces:
        vs = [tr.verts[k] for k in f]
        zc = sum(v.z for v in vs) / len(vs)
        xc = sum(v.x for v in vs) / len(vs)
        yc = sum(v.y for v in vs) / len(vs)
        edge = footh + 0.7 * mnoise.noise(Vector((xc * 2.3 + seed, yc * 2.3, 0.3)))
        if broken and zc > ztop - 0.05:
            cols.append("wood_pale")  # snapped end shows the pale inner wood
        else:
            cols.append("birch_mark" if (foot and zc < edge) else "birch_white")
    tr.face_colors = cols
    b.add(vc.clamp_ground(tr))
    marks = 0
    for m in range(marks_n):
        t = rng.uniform(0.1, 0.85)
        i = min(n - 2, int(t * (n - 1)))
        f = t * (n - 1) - i
        c = spine[i].lerp(spine[i + 1], f)
        r = radii[i] + (radii[i + 1] - radii[i]) * f
        a = rng.uniform(0, TAU)
        mk = box(r * rng.uniform(1.0, 1.7), 0.24, rng.uniform(0.2, 0.36), "birch_mark", base=False)
        mk.rotate(a + math.pi / 2, "Z")
        d = Vector((math.cos(a), math.sin(a), 0))
        b.add(mk.move(c.x + d.x * (r * 0.92), c.y + d.y * (r * 0.92), c.z).paint(grad=("range", 0.3, 0.7),
                                                                                    tag="mark"))
        marks += 1
    if foot:  # a few low dark roots tie the birch to the oaks' flared bases
        ph = rng.uniform(0, TAU)
        for k in range(3):
            a = ph + TAU * k / 3 + rng.uniform(-0.3, 0.3)
            b.add(vc.root(rng, spine[0], a, rb, rb * rng.uniform(0.8, 1.15), "birch_mark", seg=5, z0=rb * 1.1))
    if broken:  # jagged splinters around the snapped end
        top, rt = spine[-1], radii[-1]
        ph = rng.uniform(0, TAU)
        for k in range(5):
            a = ph + TAU * k / 5
            h = rng.uniform(0.5, 1.6)
            sp = lathe([(rt * 0.42, 0.0), (0.0, h)], 4, "wood_pale" if k % 2 else "birch_white")
            b.add(sp.move(top.x + math.cos(a) * rt * 0.55, top.y + math.sin(a) * rt * 0.55, top.z - 0.15)
                  .paint(grad=("range", 0.4, 1.0), tag="splinter"))
    return radii, marks


def _at(spine, radii, t):
    n = len(spine)
    i = min(n - 2, int(t * (n - 1)))
    f = t * (n - 1) - i
    return spine[i].lerp(spine[i + 1], f), radii[i] + (radii[i + 1] - radii[i]) * f


# ------------------------------------------------------------------ crown lobes

def _mass(b, rng, sch, H0, anchor, r_here, lc, rx, rz, sats, limb=True):
    """One large primary foliage mass (smooth 180-tri geodesic, oval) with 2-3 satellite clumps on
    its upper/outer surface, a limb from the stem into it and dark twigs under its rim.
    Returns (clusters, depth)."""
    depth = 0
    if limb:
        e = lc - Vector((0, 0, rz * 0.25))
        mid = anchor + (e - anchor) * 0.5 + Vector((0, 0, 0.5))
        b.add(vc.limb([anchor, mid, e], max(0.2, r_here * 0.62), 0.14, seg=5, color="birch_white",
                      grad=("range", 0.4, 0.9)))
        depth = 1
    hg = max(0.0, min(1.0, (lc.z - H0 * 0.3) / (H0 * 0.65)))
    m = vc.puff(rng, 1.0, sch, hglob=hg, subdiv="g3", squash=1.0, bottom=0.6, lump=0.2, stretch=0.08)
    b.add(m.scale(rx * 0.9, rx * 0.84, rz * 1.0).move(lc.x, lc.y, lc.z))
    clusters = 1
    ph = rng.uniform(0, TAU)
    outs = []
    for k in range(sats):
        el = math.radians(rng.uniform(15, 55) if k else rng.uniform(55, 75))
        az = ph + TAU * k / max(1, sats) + rng.uniform(-0.4, 0.4)
        d = Vector((math.cos(el) * math.cos(az), math.cos(el) * math.sin(az), math.sin(el)))
        cc = lc + Vector((d.x * rx * 0.72, d.y * rx * 0.68, d.z * rz * 0.72))
        cr = (rx + rz) * 0.5 * rng.uniform(0.48, 0.58)
        pf = vc.puff(rng, cr, sch, hglob=min(1.0, hg + 0.2), subdiv=2, squash=0.96, bottom=0.7, lump=0.24)
        b.add(pf.move(cc.x, cc.y, cc.z))
        clusters += 1
        outs.append(Vector((d.x, d.y, 0)))
    # dark twigs poking out under the rim (depth 2)
    base = (anchor + lc) / 2 if limb else lc - Vector((0, 0, rz * 0.45))
    for k in range(2):
        a = ph + math.pi * (k + 0.5)
        tgt = lc + Vector((math.cos(a) * rx * 0.78, math.sin(a) * rx * 0.74, -rz * 0.6))
        b.add(vc.limb([base, (base + tgt) / 2 + Vector((0, 0, 0.3)), tgt], 0.15, 0.07, seg=4, color="bark_dark",
                      grad=("range", 0.3, 0.8)))
        depth = 2
    return clusters, depth


def _side(rng, ang_center, spread=1.2):
    a = ang_center + rng.uniform(-spread, spread)
    return Vector((math.cos(a), math.sin(a), 0))


# ------------------------------------------------------------------ build

def build(b, p):
    rng = b.rng
    sch = vc.SCHEMES[p["leaves"]]
    style = p["style"]
    V = Vector
    j = rng.uniform
    # stems: (spine, rb, r_top, marks, foot, broken); masses: (stem, t, dir, offset_k, rx, rz, satellites, limb)
    stems, lobes = [], []
    lean_a = j(0, TAU)
    ld = V((math.cos(lean_a), math.sin(lean_a), 0))
    if style == "leaning":  # one stem curving out towards the light, crown thrown to that side
        H0 = 30.0
        ld = V((rng.choice((-1, 1)), j(-0.25, 0.25), 0)).normalized()  # lean across the view
        top = ld * j(6.0, 7.0) + V((0, 0, 26.5))
        stems.append((_spine((0, 0, 0), top, -ld * 2.6), j(1.1, 1.2), 0.3, 14, True, False))
        lobes += [(0, 0.45, -ld, 0.5, 4.4, 3.4, 2, True), (0, 0.66, ld, 0.6, 5.6, 4.2, 3, True),
                  (0, 0.84, -ld, 0.45, 4.6, 3.5, 2, True), (0, 1.0, ld, 0.0, 5.4, 4.2, 3, False)]
    elif style == "twin":  # two stems from one root, splaying apart
        H0 = 32.0
        for k, (s, h, rb) in enumerate(((1, 29.0, 1.05), (-1, 25.0, 0.9))):
            d = ld * s
            top = d * j(3.4, 4.2) + V((0, 0, h))
            stems.append((_spine(d * 0.8, top, d * 0.6 + V((j(-0.6, 0.6), j(-0.6, 0.6), 0))), rb, 0.28,
                          10, True, False))
            side = d
            if k == 0:
                lobes += [(k, 0.64, side, 0.6, 5.4, 4.0, 2, True), (k, 1.0, side, 0.0, 5.2, 4.0, 3, False)]
            else:
                lobes += [(k, 0.66, -side.cross(V((0, 0, 1))), 0.5, 5.0, 3.8, 2, True),
                          (k, 1.0, side, 0.0, 4.6, 3.6, 3, False)]
    elif style == "clump":  # three stems, crowns merging into one airy mass
        H0 = 28.0
        for k in range(3):
            a = lean_a + TAU * k / 3
            d = V((math.cos(a), math.sin(a), 0))
            h = (25.0, 21.5, 19.0)[k]
            top = d * j(2.4, 3.2) + V((0, 0, h))
            stems.append((_spine(d * 0.85, top, d * 0.5), (0.95, 0.85, 0.78)[k], 0.3, 8, True, False))
            if k == 0:
                lobes.append((k, 0.58, d, 0.5, 4.4, 3.4, 2, True))
            lobes.append((k, 1.0, d, 0.0, (4.4, 4.2, 4.0)[k], (3.4, 3.3, 3.2)[k], 3 if k == 0 else 2, False))
        lobes.append((0, 0.36, -ld, 0.6, 3.4, 2.7, 2, True))  # low mass on the main stem
    elif style == "broken":  # old stem snapped long ago (stub capped by foliage); a side leader took over
        H0 = 34.0
        brk = V((j(-0.4, 0.4), j(-0.4, 0.4), 15.5))
        main = _spine((0, 0, 0), brk, V((j(-0.8, 0.8), j(-0.8, 0.8), 0)), kink=(ld * 0.9, 0.55))
        ld = V((rng.choice((-1, 1)), j(-0.3, 0.3), 0)).normalized()
        stems.append((main, 1.3, 0.66, 12, True, False))
        fork, _ = _at(main, [1.0] * len(main), 0.55)
        ltop = fork + ld * 7.0 + V((0, 0, 22.5))
        stems.append((_spine(fork, ltop, -ld * 1.6 + V((0, 0, -1.0))), 0.7, 0.22, 6, False, False))
        lobes += [(0, 1.0, -ld, 0.25, 4.8, 3.6, 2, False),  # caps the old snapped stub
                  (1, 0.7, ld, 0.6, 5.2, 4.0, 2, True), (1, 1.0, ld, 0.0, 5.4, 4.2, 3, False)]
    elif style == "young_branch":  # young stem with one long low side branch carrying its own lobe
        H0 = 25.0
        ld = V((rng.choice((-1, 1)), j(-0.3, 0.3), 0)).normalized()
        top = V((j(-0.6, 0.6), j(-0.6, 0.6), 22.0))
        stems.append((_spine((0, 0, 0), top, V((0, 0, 0)), kink=(-ld * 0.7, 0.45)), 0.85, 0.24, 10, True, False))
        stems.append(None)  # placeholder index 1 = the low branch (built below)
        lobes += [(0, 0.7, -ld, 0.5, 4.6, 3.5, 2, True), (0, 1.0, ld, 0.0, 4.8, 3.8, 3, False)]
    else:  # forked: short thick trunk splitting into two leaders in a V (autumn gold)
        H0 = 30.0
        forkp = V((j(-0.3, 0.3), j(-0.3, 0.3), j(10.0, 11.0)))
        stems.append((_spine((0, 0, 0), forkp, V((0, 0, 0))), 1.25, 0.85, 8, True, False))
        sx = V((1, 0, 0)) if abs(ld.x) > 0.3 else V((0.8, -0.6, 0)).normalized()
        for k, (s, h) in enumerate(((1, 27.0), (-1, 23.5))):
            top = forkp + sx * s * j(4.5, 5.5) + V((0, j(-0.8, 0.8), h - forkp.z))
            stems.append((_spine(forkp - V((0, 0, 0.6)), top, -sx * s * 1.2), 0.72, 0.22, 6, False, False))
            lobes += [(k + 1, 0.62, sx * s, 0.6, (4.8, 4.2)[k], (3.6, 3.2)[k], 2, True),
                      (k + 1, 1.0, sx * s, 0.0, (5.0, 4.8)[k], (3.8, 3.7)[k], 3, False)]

    marks = clusters = depth = 0
    built = []
    for si, st in enumerate(stems):
        if st is None:
            built.append(None)
            continue
        spine, rb, rt, mk, foot, broken = st
        radii, m = _trunk(b, rng, spine, rb, rb * rt, mk, foot, broken)
        marks += m
        built.append((spine, radii))
    if style == "young_branch":  # the low side branch: nearly horizontal arm at ~7 studs
        spine, radii = built[0]
        s, r_here = _at(spine, radii, 0.3)
        e = s + ld * 4.6 + V((0, 0, 1.8))  # shorter, chunkier arm: the low mass sits close to the trunk
        arm = vc.bezier(s, s + ld * 2.4 + V((0, 0, -0.2)), e, 6)
        b.add(vc.limb(arm, r_here * 0.8, 0.36, seg=6, color="birch_white", grad=("range", 0.4, 0.9)))
        built[1] = (arm, [r_here * 0.8 * (1 - 0.55 * i / 5) for i in range(6)])
        lobes.append((1, 1.0, ld, 0.0, 4.0, 3.1, 2, False))
        depth = max(depth, 1)
    tops = []
    for si, t, d, k, rx, rz, rims, limb in lobes:
        k *= 0.72  # masses hug the stem and overlap into one crown
        rz *= 1.18  # birch masses are rounder / taller than the oak's
        spine, radii = built[si]
        anchor, r_here = _at(spine, radii, t)
        d = V((d.x, d.y, 0))
        d = d.normalized() if d.length > 1e-6 else V((1, 0, 0))
        d = (d + V((j(-0.25, 0.25), j(-0.25, 0.25), 0))).normalized()
        lc = anchor + d * rx * k + V((0, 0, rz * (0.5 if limb else 0.35)))
        c, dp = _mass(b, rng, sch, H0, anchor, r_here, lc, rx, rz, rims, limb=limb)
        clusters += c
        depth = max(depth, dp)
        tops.append(lc + V((0, 0, rz * 0.8)))

    # taper of the wood from the thickest foot to the thinnest stem top that carries the crown
    wood = [x for x in built if x]
    b.stats["trunk_taper"] = round(min(r[-1] for _, r in wood) / max(r[0] for _, r in wood), 3)
    b.stats["branch_depth"] = depth
    b.stats["leaf_clusters"] = clusters
    b.stats["bark_marks"] = marks
    b.stats["trunks"] = sum(1 for st in stems if st and st[4])
    feet = [st[0][0] for st in stems if st and st[4]]
    xs = [f.x for f in feet]
    ys = [f.y for f in feet]
    rb0 = max(st[1] for st in stems if st and st[4])
    b.collision_box(sum(xs) / len(xs), sum(ys) / len(ys), 4.0, rb0 * 2.2 + (max(xs) - min(xs)),
                    rb0 * 2.2 + (max(ys) - min(ys)), 8.0, "trunk")
    b.socket("harvest", sum(xs) / len(xs), min(ys) - rb0 * 1.3, 0.0)
    tt = max(tops, key=lambda v: v.z)
    b.socket("canopy_top", tt.x, tt.y, tt.z)
