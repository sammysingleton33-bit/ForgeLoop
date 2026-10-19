"""Broad deciduous oak: chunky flared, fluted trunk with exposed roots, recursive tapered
branching (trunk -> limbs -> branches) and a FULL crown made of many overlapping soft leaf
clumps. Each variant is planned as a set of crown "lobes" (sub-crowns): every lobe is one big
smooth core clump wrapped in smaller rim clumps (Fibonacci-spread over its upper surface),
so the canopy reads as one cloud-like mass with a lumpy edge. One chunky limb feeds each
lobe; branches run out to the lowest rim clumps, where the canopy opens and the wood shows.
Summer and autumn leaf schemes. Collision: trunk box only (the canopy never blocks players).

Front faces Blender -Y. Pivot: base centre of the bounding box (lopsided trees keep their
trunk off-centre; use the `harvest` socket to find the trunk).
"""

import math

from lib.geo import TAU, Vector, icosphere

from generators import _vegetation_common as vc

NAME = "tree_oak"
VERSION = 1
CATEGORY = "tree"
BUDGET = "tree"
COLLISION = {"fidelity": "None"}
CHECKS = {"min_branch_depth": 2, "min_leaf_clusters": 8, "max_trunk_taper": 0.75}
DEFAULT_VARIANTS = 8
LINEUP_GAP = 3.0

PLAN = (
    ("round", "summer"),
    ("spreading", "summer"),
    ("tall", "summer"),
    ("lopsided", "summer"),
    ("young", "summer"),
    ("forked", "autumn_orange"),
    ("old", "summer"),
    ("dome", "autumn_yellow"),
)


def variants(n, seed):
    out = []
    for i in range(n):
        style, leaves = PLAN[i % len(PLAN)]
        out.append({"style": style, "leaves": leaves, "seed": seed * 1000 + 31 * i + 5})
    return out


# ------------------------------------------------------------------ planning

def _plan(rng, style):
    """Trunk + crown lobes for a silhouette style. Lobe = (centre, (rx, ry, rz), rim clumps)."""
    j = lambda a, b: rng.uniform(a, b)  # noqa: E731
    V = Vector
    P = {"lean": V((0, 0, 0)), "roots": 5, "flute": 0.3, "gnarl": 0.06, "knot": True, "mushrooms": 0,
         "dead_limb": False, "sprig": False, "rim_k": 0.44, "taper": 0.62}
    if style == "round":  # classic: broad dome, ~29 tall x 29 wide
        P.update(trunk_h=j(8.0, 8.6), r_base=j(2.0, 2.2))
        T = P["trunk_h"]
        P["lobes"] = [
            (V((0.0, 0.4, T + 12.0)), (9.6, 9.0, 7.0), 9),
            (V((-7.6, 1.0, T + 7.6)), (6.6, 6.4, 5.0), 4),
            (V((7.4, -1.0, T + 8.0)), (6.8, 6.4, 5.2), 4),
            (V((0.6, -5.6, T + 6.8)), (5.6, 4.8, 4.2), 2),
        ]
    elif style == "spreading":  # wide umbrella, ~26 tall x 36 wide
        P.update(trunk_h=j(7.0, 7.6), r_base=j(2.1, 2.3), roots=6)
        T = P["trunk_h"]
        lobes = [(V((0, 0, T + 12.0)), (9.0, 8.4, 5.4), 7)]
        ph = rng.uniform(0, TAU)
        for i in range(4):
            a = ph + TAU * i / 4 + j(-0.2, 0.2)
            d = j(10.5, 12.0)
            lobes.append((V((math.cos(a) * d, math.sin(a) * d * 0.85, T + j(7.0, 8.2))),
                          (j(6.6, 7.4), j(6.0, 6.8), j(4.2, 4.8)), 3))
        P["lobes"] = lobes
    elif style == "tall":  # tall oval crown, ~37 tall x 22 wide
        P.update(trunk_h=j(9.6, 10.2), r_base=j(2.1, 2.25))
        T = P["trunk_h"]
        P["lobes"] = [
            (V((0.3, 0.0, T + 16.4)), (7.6, 7.2, 8.6), 9),
            (V((-4.6, 1.0, T + 8.8)), (6.4, 6.0, 5.2), 4),
            (V((4.8, -0.6, T + 7.8)), (6.4, 6.0, 5.0), 4),
        ]
    elif style == "lopsided":  # leaning trunk, crown thrown to one side
        P.update(trunk_h=j(9.0, 9.6), r_base=j(2.0, 2.15), lean=V((3.2, -0.6, 0)))
        T = P["trunk_h"]
        P["lobes"] = [
            (V((5.6, -0.4, T + 9.6)), (9.4, 8.2, 6.8), 9),
            (V((13.2, 0.4, T + 4.8)), (6.4, 6.0, 4.8), 4),
            (V((-1.6, 1.6, T + 6.6)), (5.0, 5.0, 4.2), 3),
        ]
    elif style == "young":  # sapling-sized, ~24.5 tall, one round crown
        P.update(trunk_h=j(9.6, 10.2), r_base=j(1.15, 1.25), roots=4, flute=0.18, knot=False, sprig=False,
                 taper=0.66, lean=V((-0.9, 0.4, 0)))
        T = P["trunk_h"]
        P["lobes"] = [
            (V((0.0, 0.0, T + 8.6)), (6.6, 6.2, 5.8), 9),
            (V((-3.6, 0.8, T + 3.6)), (4.4, 4.2, 3.4), 3),
        ]
    elif style == "forked":  # twin crown on a low fork
        P.update(trunk_h=j(5.4, 6.0), r_base=j(2.0, 2.15), roots=5)
        T = P["trunk_h"]
        P["lobes"] = [
            (V((-6.6, 0.6, T + 17.4)), (7.8, 7.4, 6.6), 8),
            (V((7.0, -0.6, T + 14.4)), (7.4, 7.0, 6.2), 7),
            (V((0.2, 0.0, T + 11.0)), (5.0, 5.0, 4.2), 2),
        ]
    elif style == "old":  # veteran: massive gnarled trunk, huge roots, broad crown, dead limb
        P.update(trunk_h=j(8.4, 9.0), r_base=j(2.6, 2.8), roots=7, flute=0.36, gnarl=0.14, mushrooms=5,
                 dead_limb=True, taper=0.6)
        T = P["trunk_h"]
        P["lobes"] = [
            (V((-0.6, 0.0, T + 13.6)), (10.0, 9.2, 6.8), 9),
            (V((-10.6, 1.0, T + 8.4)), (6.8, 6.4, 5.2), 4),
            (V((9.8, -1.5, T + 9.4)), (7.0, 6.6, 5.4), 4),
        ]
    else:  # dome: low-hanging broad crown that almost reaches the ground
        P.update(trunk_h=j(6.0, 6.6), r_base=j(2.0, 2.15))
        T = P["trunk_h"]
        lobes = [(V((0, 0, T + 11.0)), (10.4, 10.0, 7.0), 9)]
        ph = rng.uniform(0, TAU)
        for i in range(3):
            a = ph + TAU * i / 3 + j(-0.25, 0.25)
            lobes.append((V((math.cos(a) * 9.6, math.sin(a) * 8.8, T + j(3.4, 4.0))),
                          (j(6.6, 7.2), j(6.2, 6.8), j(4.6, 5.0)), 3))
        P["lobes"] = lobes
    return P


def _rim(rng, centre, radii, n, k):
    """Rim clumps spread over a lobe's upper/outer surface (Fibonacci in area). Returns
    [(centre, radius, elevation)] ordered top -> bottom."""
    rx, ry, rz = radii
    rm = (rx + ry + rz) / 3
    lo, hi = math.sin(math.radians(-22)), math.sin(math.radians(84))
    golden = math.pi * (3 - math.sqrt(5))
    ph = rng.uniform(0, TAU)
    out = []
    for i in range(n):
        s = hi - (hi - lo) * (i + 0.5) / n
        el = math.asin(max(-1.0, min(1.0, s + rng.uniform(-0.05, 0.05))))
        az = ph + golden * i + rng.uniform(-0.25, 0.25)
        d = Vector((math.cos(el) * math.cos(az) * rx, math.cos(el) * math.sin(az) * ry, math.sin(el) * rz))
        rr = rm * k * rng.uniform(0.86, 1.12) * (1.1 if el > 0.9 else 1.0)
        out.append((centre + d * 0.8, rr, el))
    return out


# ------------------------------------------------------------------ build

def build(b, p):
    rng = b.rng
    P = _plan(rng, p["style"])
    scheme = vc.SCHEMES[p["leaves"]]
    T, rb = P["trunk_h"], P["r_base"]
    lean = P["lean"]

    # --- trunk: gentle S-curve + optional lean; flared, fluted, smooth loft
    n = 8
    wob = Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), 0))
    spine, radii = [], []
    r_top = rb * P["taper"]
    for i in range(n):
        t = i / (n - 1)
        z = T * (t ** 1.2)
        off = lean * (t ** 1.6) + wob * math.sin(math.pi * t)
        spine.append(Vector((off.x, off.y, z)))
        r = r_top + (rb - r_top) * (1 - t) ** 1.6
        r *= 1.0 + 0.55 * max(0.0, 1.0 - z / (1.5 * rb)) ** 2  # root flare
        radii.append(r)
    spine.append(spine[-1] + Vector((0, 0, r_top * 0.8)))  # rounded top, buried in the limbs
    radii.append(r_top * 0.6)
    zs = [s.z for s in spine]
    flute = lambda i: P["flute"] * max(0.0, 1 - zs[i] / (T * 0.5)) ** 2 + 0.07  # noqa: E731
    trunk = vc.wood_loft(spine, radii, seg=10, color="bark", flute=flute, gnarl=P["gnarl"], seed=rng.uniform(0, 50),
                         twist=0.05, grad=("range", 0.05, 0.85), tag="trunk")
    b.add(vc.clamp_ground(trunk))
    b.stats["trunk_taper"] = round(r_top / rb, 3)

    # --- exposed roots
    nr = P["roots"]
    ph = rng.uniform(0, TAU)
    for i in range(nr):
        a = ph + TAU * i / nr + rng.uniform(-0.22, 0.22)
        b.add(vc.root(rng, (0, 0, 0), a, rb, rb * rng.uniform(1.2, 1.9), "bark", seg=6))

    # --- crown plan
    lobes = P["lobes"]
    rims = [_rim(rng, c, r, k, P["rim_k"]) for c, r, k in lobes]
    cz0 = min(min(c.z - r for c, r, _ in rim) for rim in rims)
    cz1 = max(max(c.z + r * 0.8 for c, r, _ in rim) for rim in rims)
    hg = lambda z: max(0.0, min(1.0, (z - cz0) / max(1e-6, cz1 - cz0)))  # noqa: E731

    top = spine[-2]
    depth = 0
    clusters = 0
    for li, ((lc, lr, _), rim) in enumerate(zip(lobes, rims)):
        rm = sum(lr) / 3
        # depth 1: one chunky limb from the trunk top into the lobe heart
        end = lc - Vector((0, 0, lr[2] * 0.3))
        dirv = (end - top)
        dh = Vector((dirv.x, dirv.y, 0))
        start = top + (dh.normalized() * r_top * 0.35 if dh.length > 1e-6 else Vector()) - Vector((0, 0, r_top))
        dvec = end - start
        ctrl = start + Vector((0, 0, dvec.length * 0.42)) + Vector((dvec.x, dvec.y, 0)) * 0.22
        pts = vc.bezier(start, ctrl, end, 5)
        r0 = r_top * min(0.92, 0.5 + rm / 18.0)
        b.add(vc.limb(pts, r0, r0 * 0.45, seg=8, color="bark"))
        depth = max(depth, 1)
        # depth 2: branches out to the lowest rim clumps (where the crown opens)
        low = sorted(rim, key=lambda c: c[2])[:2 if rm > 5.5 else 1]
        for cc, cr, _ in low:
            ti = rng.choice((2, 3))
            s = pts[ti]
            rs = r0 + (r0 * 0.45 - r0) * ti / (len(pts) - 1)
            e = cc - Vector((0, 0, cr * 0.2))
            d2 = e - s
            bp = vc.bezier(s, s + d2 * 0.5 + Vector((0, 0, d2.length * 0.15)), e, 4)
            b.add(vc.limb(bp, rs * 0.6, max(0.16, rs * 0.2), seg=5, color="bark"))
            depth = max(depth, 2)
        # core: one big smooth clump filling the lobe (mid green, dark underside)
        core = vc.puff(rng, 1.0, scheme, hglob=hg(lc.z), subdiv="g3" if rm > 6.4 else 2, squash=1.0, bottom=0.62, lump=0.16,
                       core=True)
        core.scale(lr[0] * 0.86, lr[1] * 0.86, lr[2] * 0.86)
        b.add(core.move(lc.x, lc.y, lc.z))
        clusters += 1
        # rim clumps: lumpy edge; the upper (most visible) ones get the smoother sphere
        for ri, (cc, cr, el) in enumerate(rim):
            lvl = "g3" if (el > 0.55 and cr > 2.8) else 2
            pf = vc.puff(rng, cr, scheme, hglob=hg(cc.z), subdiv=lvl, squash=rng.uniform(0.86, 0.94),
                         bottom=rng.uniform(0.58, 0.7))
            b.add(pf.move(cc.x, cc.y, cc.z))
            clusters += 1

    # --- accents: knot hole, trunk sprig, dead limb, mushrooms
    if P["knot"]:
        zk = T * rng.uniform(0.38, 0.5)
        i = min(range(len(spine)), key=lambda q: abs(spine[q].z - zk))
        c = spine[i]
        ang = math.radians(-90 + rng.uniform(10, 35))
        d = Vector((math.cos(ang), math.sin(ang), 0))
        rr = radii[i] * 0.95
        rim_ = icosphere(1.0, 1, "bark_light").scale(0.75, 0.3, 0.95)
        hole = icosphere(1.0, 1, "black").scale(0.45, 0.22, 0.6)
        for pc, push in ((rim_, 0.0), (hole, 0.12)):
            pc.rotate(ang + math.pi / 2, "Z")
            pc.move(c.x + d.x * (rr + push), c.y + d.y * (rr + push), zk)
            b.add(pc.paint(smooth=True, grad=("range", 0.2, 0.8)))
    if P["dead_limb"]:
        a = math.radians(rng.uniform(150, 200))
        s = spine[5]
        d = Vector((math.cos(a), math.sin(a), 0.5)).normalized()
        e = s + d * 9.5
        pts = vc.bezier(s, s + d * 4.8 + Vector((0, 0, 0.5)), e, 4)
        b.add(vc.limb(pts, radii[5] * 0.4, 0.18, seg=6, color="bark_light"))
        pts2 = vc.bezier(pts[2], pts[2] + Vector((0, -0.6, 1.6)), pts[2] + Vector((0.4, -1.2, 3.4)), 3)
        b.add(vc.limb(pts2, 0.3, 0.12, seg=5, color="bark_light"))
    for m in range(P["mushrooms"]):
        a = rng.uniform(-2.3, -0.8)
        d = Vector((math.cos(a), math.sin(a), 0))
        rr = rb * rng.uniform(1.3, 1.75)
        cap = rng.uniform(0.38, 0.62)
        for pc in vc.mushroom(rng, cap, cap * rng.uniform(1.0, 1.5)):
            b.add(pc.move(d.x * rr, d.y * rr, 0))
    if P["sprig"]:  # leafy sprig sprouting from the trunk (storybook touch)
        zs_ = T * rng.uniform(0.5, 0.65)
        i = min(range(len(spine)), key=lambda q: abs(spine[q].z - zs_))
        a = math.radians(rng.uniform(-70, -20))
        d = Vector((math.cos(a), math.sin(a), 0))
        s0 = spine[i] + d * radii[i] * 0.8
        s1 = s0 + d * 1.5 + Vector((0, 0, 0.9))
        b.add(vc.limb([s0, (s0 + s1) / 2 + Vector((0, 0, 0.2)), s1], 0.24, 0.12, seg=4, color="bark"))
        sp = vc.puff(rng, 0.85, scheme, hglob=0.2, subdiv=1, squash=0.8, bottom=0.6, lump=0.12)
        b.add(sp.move(s1.x, s1.y, s1.z + 0.35))

    # --- stats, collision, sockets
    b.stats["branch_depth"] = depth
    b.stats["leaf_clusters"] = clusters
    b.stats["lobes"] = len(lobes)
    base = spine[0]
    mid = spine[n // 2]
    w = rb * 1.6
    b.collision_box((base.x + mid.x) / 2, (base.y + mid.y) / 2, T * 0.5, w, w, T, "trunk")
    b.socket("harvest", base.x, base.y - rb * 1.15, 0.0)
    topc = max((c for rim in rims for c, _, _ in rim), key=lambda c: c.z)
    b.socket("canopy_top", topc.x, topc.y, cz1)
