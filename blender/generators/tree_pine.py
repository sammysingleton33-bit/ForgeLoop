"""Conifer (pine / spruce): straight tapered trunk with a small root flare and dead branch
stubs low down, then layered TIERS of drooping branch clusters. Every tier is a ring of
separate radial branch-pads (lofted, lumpy, drooping at the tip) around a dark inner core:
dark next to the trunk, lighter towards the tips, darker undersides. Tiers shrink towards a
pointed leader; slight asymmetry per tier. Snowy-tip and blue-green variants.
Collision: trunk box only (the foliage never blocks players).

Front faces Blender -Y. Pivot: base centre of the bounding box.
"""

import math

from mathutils import noise as mnoise

from lib.geo import TAU, Vector, lathe, loft_rings

from generators import _vegetation_common as vc

NAME = "tree_pine"
VERSION = 1
CATEGORY = "tree"
BUDGET = "tree"
COLLISION = {"fidelity": "None"}
CHECKS = {"min_branch_depth": 1, "min_tiers": 4, "min_leaf_clusters": 20, "max_trunk_taper": 0.5}
DEFAULT_VARIANTS = 6
LINEUP_GAP = 3.0

PLAN = (
    # style, scheme, snow
    ("classic", "pine", False),
    ("broad", "pine", False),
    ("spruce", "pine", False),
    ("snowy", "pine", True),
    ("blue", "pine_blue", False),
    ("young", "pine", False),
)


def variants(n, seed):
    out = []
    for i in range(n):
        style, scheme, snow = PLAN[i % len(PLAN)]
        out.append({"style": style, "leaves": scheme, "snow": snow, "seed": seed * 1000 + 47 * i + 3})
    return out


def _spec(rng, style):
    j = rng.uniform
    if style == "classic":
        return dict(H=j(38, 41), z0=j(7.5, 8.5), R0=j(9.2, 10.0), Rtop=2.4, tiers=7, rb=j(1.25, 1.35), pads=(8, 4),
                    droop=1.0, thick=1.0)
    if style == "broad":
        return dict(H=j(31, 33), z0=j(4.5, 5.5), R0=j(11.0, 12.0), Rtop=2.8, tiers=6, rb=j(1.35, 1.45), pads=(9, 5),
                    droop=1.15, thick=1.1)
    if style == "spruce":
        return dict(H=j(45, 47.5), z0=j(6.5, 7.5), R0=j(8.0, 8.6), Rtop=2.0, tiers=8, rb=j(1.2, 1.3), pads=(6, 4),
                    droop=1.25, thick=0.9)
    if style == "snowy":
        return dict(H=j(36, 38), z0=j(6.0, 7.0), R0=j(9.6, 10.4), Rtop=2.4, tiers=7, rb=j(1.25, 1.35), pads=(8, 4),
                    droop=1.1, thick=1.0)
    if style == "blue":
        return dict(H=j(40, 42), z0=j(8.5, 9.5), R0=j(8.8, 9.4), Rtop=2.2, tiers=7, rb=j(1.25, 1.35), pads=(7, 4),
                    droop=0.9, thick=1.0)
    return dict(H=j(28, 29.5), z0=j(3.0, 3.8), R0=j(7.0, 7.6), Rtop=2.2, tiers=6, rb=j(0.8, 0.9), pads=(7, 4),
                droop=0.9, thick=0.95)


def _pad(rng, L, w, h, rise, droop, cols, snow, seg=6):
    """One drooping branch-cluster: lofted lumpy pad from the trunk (x=0) out to x=L, with a
    bumpy outline (needle tufts along the branch) and a rounded, drooping tip.
    cols = (inner, mid, tip, tip_top, under)."""
    ts = (0.0, 0.22, 0.44, 0.66, 0.88, 1.0)
    wf = (0.3, 0.94, 0.74, 1.0, 0.74, 0.28)
    hf = (0.55, 1.0, 0.8, 0.92, 0.66, 0.26)
    seed = rng.uniform(0, 300)
    rings = []
    for t, a_w, a_h in zip(ts, wf, hf):
        x = 0.3 + t * (L - 0.3)
        zc = rise * t - droop * t * t
        ww, hh = w * a_w, h * a_h
        ring = []
        for k in range(seg):
            a = TAU * k / seg + math.pi / seg
            cy, cz = math.cos(a), math.sin(a)
            if cz < 0:
                cz *= 0.55  # flatter underside
            lump = 1.0 + 0.16 * mnoise.noise(Vector((x * 0.6 + seed, cy * 1.3, cz * 1.3)))
            ring.append(Vector((x, cy * ww * lump, zc + cz * hh * lump)))
        rings.append(ring)
    p = loft_rings(rings, cols[1], smooth=True, grad=("range", 0.25, 1.0), tag="leaf")
    p.face_smooth = [True] * len(p.faces)
    inner, mid, tip, tip_top, under = cols
    fc = []
    for f in p.faces:
        vs = [p.verts[i] for i in f]
        cx = sum(v.x for v in vs) / len(vs) / L
        nz = (vs[1] - vs[0]).cross(vs[2] - vs[0]).normalized().z
        if nz < -0.5:
            c = under
        elif snow and nz > 0.62 and cx > 0.3:
            c = "foam"
        elif cx < 0.42:
            c = inner
        elif cx < 0.78:
            c = mid
        else:
            c = tip
        fc.append(c)
    p.face_colors = fc
    return p


def build(b, p):
    rng = b.rng
    S = _spec(rng, p["style"])
    sch = vc.SCHEMES[p["leaves"]]
    H, z0, R0, Rtop, nt, rb = S["H"], S["z0"], S["R0"], S["Rtop"], S["tiers"], S["rb"]
    snow = p["snow"]

    # --- trunk: straight tapered loft with a small flare, slight top drift
    drift = Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), 0))
    n = 7
    spine, radii = [], []
    for i in range(n):
        t = i / (n - 1)
        z = (H - 2.0) * t
        spine.append(Vector((0, 0, z)) + drift * t * t)
        r = rb * (1.0 - 0.86 * t)
        r *= 1.0 + 0.45 * max(0.0, 1.0 - z / (1.8 * rb)) ** 2
        radii.append(r)
    trunk = vc.wood_loft(spine, radii, seg=8, color="bark", flute=lambda i: 0.12 if i == 0 else 0.05,
                         seed=rng.uniform(0, 9), twist=0.04, grad=("range", 0.1, 0.85), tag="trunk")
    b.add(vc.clamp_ground(trunk))
    b.stats["trunk_taper"] = round(radii[-1] / rb, 3)
    a = rng.uniform(0, TAU)
    for i in range(4):
        if i:
            a += TAU / 4 + rng.uniform(-0.3, 0.3)
        b.add(vc.root(rng, (0, 0, 0), a, rb, rb * rng.uniform(0.9, 1.3), "bark", seg=5, z0=rb * 1.2))
    # dead branch stubs on the bare lower trunk
    depth = 0
    for i in range(2 if z0 > 4.5 else 0):
        zz = z0 * rng.uniform(0.45, 0.85)
        a = rng.uniform(-2.4, -0.4) if i == 0 else rng.uniform(0.5, 2.6)
        d = Vector((math.cos(a), math.sin(a), 0.15))
        s = Vector((0, 0, zz)) + drift * (zz / H) ** 2
        rr = rb * (1 - 0.86 * zz / (H - 2)) * 0.6
        b.add(vc.limb([s, s + d * 1.3, s + d * 2.4 + Vector((0, 0, -0.2))], 0.3, 0.12, seg=4, color="bark_dark"))

    # --- tiers of radial branch-pads
    pads = 0
    ztop = H - 4.6
    ph = rng.uniform(0, TAU)
    zlist = [z0 + (ztop - z0) * (ti / nt) ** 0.82 for ti in range(nt + 1)]
    for ti in range(nt):
        u = ti / max(1, nt - 1)  # 0 bottom .. 1 top
        spacing = zlist[ti + 1] - zlist[ti]
        zt = zlist[ti] + rng.uniform(-0.15, 0.15)
        R = R0 + (Rtop - R0) * u ** 0.92
        R *= rng.uniform(0.94, 1.06)
        k = int(round(S["pads"][0] + (S["pads"][1] - S["pads"][0]) * u)) + (1 if ti == 0 else 0)
        th = (1.9 + 1.3 * (1 - u)) * S["thick"]
        cols = (sch[0], sch[1] if u < 0.5 else sch[2], sch[2], sch[3], sch[0])
        if u < 0.25:
            cols = (sch[0], sch[0], sch[1], sch[2], sch[0])
        # dark inner core cone
        core = lathe([(R * 0.5, -th * 0.55), (R * 0.32, th * 0.4), (0.0, th * 1.2 + spacing * 0.5)], 7, sch[0])
        b.add(core.move(*(Vector((0, 0, zt)) + drift * (zt / H) ** 2)).paint(smooth=True, grad=("range", 0.0, 0.7),
                                                                             tag="leaf"))
        ph += rng.uniform(0.5, 1.1)
        bias = rng.uniform(0, TAU)
        for pi in range(k):
            a = ph + TAU * pi / k + rng.uniform(-0.18, 0.18)
            L = R * rng.uniform(0.86, 1.08) * (1.0 + 0.08 * math.cos(a - bias))
            w = max(1.0, L * rng.uniform(0.3, 0.36) * (1.15 if u > 0.7 else 1.0))
            pad = _pad(rng, L, w, th * 0.62, rise=th * 0.3, droop=th * 1.05 * S["droop"], cols=cols, snow=snow)
            pad.rotate(a, "Z")
            c = Vector((0, 0, zt + rng.uniform(-0.25, 0.25))) + drift * (zt / H) ** 2
            b.add(pad.move(c.x, c.y, c.z))
            pads += 1
        if ti in (1, 2):  # a few pine cones hanging under the tier
            for ci in range(2):
                a = ph + TAU * (ci * 2 + 1) / k
                rr = R * rng.uniform(0.5, 0.65)
                cz = zt - th * 0.45 - 0.2 * rr
                cone_ = lathe([(0.0, 0.0), (0.32, 0.25), (0.42, 0.7), (0.28, 1.1), (0.0, 1.3)], 5, "bark_light")
                cone_.paint(grad=("range", 0.2, 0.9), tag="cone")
                b.add(cone_.move(math.cos(a) * rr, math.sin(a) * rr, cz - 1.3))
        if ti == 0:  # bare branches visible under the lowest tier
            for pi in range(0, k, 2):
                a = ph + TAU * pi / k
                d = Vector((math.cos(a), math.sin(a), 0))
                s = Vector((0, 0, zt - th * 0.35))
                e = s + d * R * 0.62 + Vector((0, 0, -0.2))
                b.add(vc.limb([s, (s + e) / 2 + Vector((0, 0, 0.15)), e], 0.32, 0.12, seg=4, color="bark_dark"))
                depth = 1
    # --- leader: a few upturned pads around a short pointed tip
    c = Vector((0, 0, ztop)) + drift
    tcols = (sch[1], sch[2], sch[2], sch[3], sch[1])
    for pi in range(3):
        a = ph + 1.0 + TAU * pi / 3
        pad = _pad(rng, Rtop * 0.95, Rtop * 0.6, 0.8, rise=0.9, droop=0.7, cols=tcols, snow=snow)
        pad.rotate(-0.3, "Y").rotate(a, "Z")
        b.add(pad.move(c.x, c.y, c.z - 0.9))
        pads += 1
    lead = lathe([(0.0, 0.0), (Rtop * 0.5, 0.5), (Rtop * 0.36, 2.0), (Rtop * 0.14, 3.6), (0.0, 4.8)], 7, sch[2])
    lead.paint(smooth=True, grad=("range", 0.2, 1.0), tag="leaf")
    if snow:
        lead.face_colors = ["foam" if i >= 7 * 2 else sch[2] for i in range(len(lead.faces))]
    b.add(lead.move(c.x, c.y, c.z))
    depth = max(depth, 1)

    b.stats["branch_depth"] = depth
    b.stats["tiers"] = nt
    b.stats["leaf_clusters"] = pads
    b.collision_box(0, 0, H * 0.4, rb * 1.6, rb * 1.6, H * 0.8, "trunk")
    b.socket("harvest", 0.0, -rb * 1.2, 0.0)
    b.socket("canopy_top", c.x, c.y, c.z + 4.4)
