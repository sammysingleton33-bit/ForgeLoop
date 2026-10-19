"""Environment kit: trees (oak, pine, birch), style B (faceted blobs and tiers, vertex colours, 300-900 triangles each).

Archetypes follow the classes the part-built stand-ins (Kit/Props.luau) already use per variant id, so a mesh tree takes the footprint
and height class of the stand-in it replaces (the world's keep-out and plot clearance were tuned on those): oak dome / tall / wide /
lopsided / twin by NN, pine and birch by seed. Each tree is one closed-shell kit of parts (trunk, limbs, canopy lobes) merged into ONE mesh.
"""

import math

from generators import _envkit_style as S
from lib.ckit import M, cone, merge

OAK_ARCH = ["dome", "tall", "wide", "lopsided", "twin", "dome", "tall", "wide"]  # variant NN 1..8 (the stand-in's table)


# ------------------------------------------------------------------ oak

def _oak_lobes(arch, rng, a0):
    """(radial distance, angle, dy from the canopy centre, radius, holds a limb) for the canopy lobes of one archetype."""
    R = rng.uniform
    L = []

    def add(r, a, dy, rad, limb=False):
        L.append((r, a, dy, rad, limb))

    if arch == "tall":  # a tall narrow ovoid: four low lobes, three middle, three crowns
        for k in range(4):
            add(R(3.0, 3.8), a0 + k * math.pi / 2 + R(-0.3, 0.3), R(-4.6, -3.0), R(3.5, 4.2), k in (0, 2))
        for k in range(3):
            add(R(1.8, 2.8), a0 + 0.6 + k * 2.1, R(0.6, 2.8), R(2.8, 3.5))
        for k in range(3):
            add(R(0.4, 1.4), a0 + 1.1 + k * 2.1, R(5.2, 7.2), R(2.3, 3.0))
    elif arch == "wide":  # a wide flat spreading crown: a low core, a ring of six broad lobes, three flat crowns
        add(0, 0, -0.4, R(5.0, 5.6))
        for k in range(6):
            add(R(5.4, 6.6), a0 + k * math.pi / 3 + R(-0.25, 0.25), R(-1.8, 0.6), R(3.8, 4.7), k in (0, 3))
        for k in range(3):
            add(R(1.0, 3.4), a0 + k * 2.1, R(2.6, 3.4), R(2.8, 3.6))
    elif arch == "lopsided":  # heavy on one side; on the other a gap with a bare limb carrying one small lobe
        add(2.6, a0, 0.8, R(4.8, 5.4), True)
        for k in range(3):
            add(R(5.0, 6.4), a0 + (k - 1) * 0.85, R(-2.2, 1.2), R(3.8, 4.8))
        for k in range(4):
            add(R(3.4, 5.0), a0 + (k - 1.5) * 0.75, R(-4.6, -3.4), R(3.0, 3.8))
        add(R(5.2, 6.0), a0 + math.pi + R(-0.2, 0.2), R(-1.6, -0.4), R(2.7, 3.3), True)
        add(R(1.0, 2.4), a0 + 0.4, R(4.4, 5.2), R(2.6, 3.4))
    elif arch == "twin":  # two crowns on a forked trunk: each a core, two shoulders and a crown, joined by two small lobes
        for side in range(2):
            a = a0 + side * math.pi
            up = 1.0 if side == 0 else -0.4
            add(R(4.6, 5.2), a, up + 0.4, R(3.7, 4.2), True)
            add(R(7.0, 7.8), a + R(-0.5, 0.5), up - 1.2, R(3.5, 4.2))
            add(R(6.2, 7.0), a + R(0.8, 1.2), up + 1.4, R(3.3, 4.0))
            add(R(4.2, 5.0), a + R(-0.3, 0.3), up + 4.0, R(3.0, 3.6))
        add(0.6, a0 + 1.4, 3.4, R(2.6, 3.2))
        add(1.2, a0 + 4.0, -2.2, R(2.4, 3.0))
    else:  # dome: a broad core, two hanging skirt lobes, four shoulders, three sunlit crowns
        add(0, 0, 0, R(5.6, 6.2))
        for k in range(2):
            add(R(4.4, 5.4), a0 + k * math.pi + R(-0.5, 0.5), -R(3.2, 4.0), R(3.2, 3.8), True)
        for k in range(4):
            add(R(4.6, 6.2), a0 + 0.8 + k * math.pi / 2 + R(-0.4, 0.4), R(-2.0, 1.4), R(3.5, 4.4))
        for _ in range(3):
            add(R(0.8, 3.4), R(0, math.tau), R(3.6, 4.6), R(2.8, 3.6))
    return L


def oak(variant, rng, height=25.0):
    """tree_oak_NN: trunk with root flare, one or two limbs, 10-13 faceted canopy lobes in four greens (dark under, sunlit above)."""
    arch = OAK_ARCH[(variant - 1) % len(OAK_ARCH)]
    a0 = rng.uniform(0, math.tau)
    lobes = [(r * 1.12, a, dy * 1.1, rad * 1.22, limb) for r, a, dy, rad, limb in _oak_lobes(arch, rng, a0)]
    if arch in ("tall", "lopsided", "twin"):  # a solid core so the crown reads as one mass, not a cluster of separate lobes
        mid = sum(dy for _, _, dy, _, _ in lobes) / len(lobes)
        lobes.append((0.0, 0.0, mid, 4.3 if arch != "tall" else 3.6, False))
    # canopy extent above / below its centre decides where the centre sits so the crown top lands on `height`
    top_ext = max(dy + rad * 0.92 for _, _, dy, rad, _ in lobes)
    low_ext = min(dy - rad * 0.80 for _, _, dy, rad, _ in lobes)
    cy = height - top_ext
    lean = math.radians(rng.uniform(3.5, 7.0))
    la = rng.uniform(0, math.tau)
    ldir = (math.sin(lean) * math.cos(la), math.cos(lean), math.sin(lean) * math.sin(la))
    # trunk: a hexagonal stem rising to just inside the canopy, with a flare at the foot and a lean
    tip_y = cy + low_ext + 3.2
    tip = (ldir[0] * tip_y / ldir[1], tip_y, ldir[2] * tip_y / ldir[1])
    path = [(0.0, -0.35, 0.0), (ldir[0] * 0.9, 0.9, ldir[2] * 0.9), (ldir[0] * 3.0 / ldir[1], 3.0, ldir[2] * 3.0 / ldir[1]),
            (tip[0] * 0.55, tip_y * 0.55, tip[2] * 0.55), tip]
    radii = [2.35, 1.95, 1.55, 1.35, 1.05]
    parts = [S.paint_ramp(S.tube(path, radii, seg=7, color=S.BARK, n=2.5, tag="trunk"), [S.BARK_DARK, S.BARK, S.BARK_LIGHT], rng,
                          0, tip_y, up=0.2, height=0.3, noise=0.12)]
    ccx, ccz = tip[0] + ldir[0] * 1.2, tip[2] + ldir[2] * 1.2
    # canopy lobes
    lobe_pts, limb_targets = [], []
    for r, a, dy, rad, limb in lobes:
        c = (ccx + math.cos(a) * r, cy + dy, ccz + math.sin(a) * r)
        pts = max(16, min(24, int(round(rad * 4.2))))
        b = S.blob(rng, pts, rad * 1.04, rad * 0.98, rad * 1.04, c[0], c[1], c[2], jitter=0.12, squash_bottom=0.18, color=S.LEAF, tag="canopy",
                   yaw=rng.uniform(0, math.tau))
        lobe_pts.append(b)
        if limb:
            limb_targets.append(c)
    ymin = min(b.bounds()[0][1] for b in lobe_pts)
    ymax = max(b.bounds()[1][1] for b in lobe_pts)
    for b in lobe_pts:
        S.paint_ramp(b, S.OAK_RAMP, rng, ymin, ymax, up=0.38, height=0.5, noise=0.09)
    parts += lobe_pts
    # limbs: thick tapered boughs from the stem to the lobes that need one
    forked = arch in ("twin", "lopsided")
    for k, t in enumerate(limb_targets[:2]):
        f = (0.55 + 0.1 * k) if forked else (0.30 + 0.14 * k)
        a = (tip[0] * f, tip_y * f, tip[2] * f)
        b = (a[0] + (t[0] - a[0]) * (0.92 if forked else 0.8), a[1] + (t[1] - a[1]) * (0.92 if forked else 0.8),
             a[2] + (t[2] - a[2]) * (0.92 if forked else 0.8))
        parts.append(S.paint_ramp(S.tube([a, ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2 + 0.4, (a[2] + b[2]) / 2), b], [1.0, 0.8, 0.55], seg=5, color=S.BARK, n=2.5,
                                         tag="limb"), [S.BARK_DARK, S.BARK, S.BARK_LIGHT], rng, 0, tip_y, up=0.2, height=0.3, noise=0.1))
    return S.assemble(parts), {"archetype": arch, "lobes": len(lobes)}


# ------------------------------------------------------------------ pine

def _tier(rng, y0, r0, h, teeth, depth, rot, tip_r, col_lo, col_hi, tag="bough"):
    """One bough tier: a jagged skirt ring (2 x `teeth` points alternating r0 and r0 x (1 - depth)) at y0, a mid ring, an apex at y0 + h,
    a dished underside. Colours: the lower face ring is darker."""
    n = teeth * 2
    v, f, c = [], [], []
    rim = []
    for i in range(n):
        a = rot + math.tau * i / n
        rr = r0 * (1.0 if i % 2 == 0 else 1.0 - depth) * (1.0 + rng.uniform(-0.05, 0.05))
        rim.append(len(v))
        v.append((math.cos(a) * rr, y0 + rng.uniform(-0.12, 0.12), math.sin(a) * rr))
    mid = []
    for i in range(n):
        a = rot + math.tau * (i + 0.5) / n
        rr = r0 * 0.55
        mid.append(len(v))
        v.append((math.cos(a) * rr, y0 + h * 0.55, math.sin(a) * rr))
    apex = len(v)
    v.append((0.0, y0 + h, 0.0))
    under = len(v)
    v.append((0.0, y0 + h * 0.2, 0.0))
    for i in range(n):
        j = (i + 1) % n
        # rim -> mid ring (two triangles per step), mid -> apex, underside fan
        f.append((rim[i], rim[j], mid[i]))
        f.append((rim[j], mid[j], mid[i]))
        f.append((mid[i], mid[j], apex))
        f.append((rim[j], rim[i], under))
    m = M(v, f, color=col_lo, smooth=False, tag=tag)
    m.fix_winding()
    # colour: the lower rim faces are the darkest, the upper cone faces the lightest
    for i, face in enumerate(m.f):
        cy = sum(m.v[k][1] for k in face) / 3
        t = (cy - y0) / h
        nrm = S.face_normal(m, face)
        m.c[i] = S.mix(col_lo, col_hi, min(1.0, max(0.0, 0.15 + 0.55 * t + 0.35 * (0.5 + 0.5 * nrm[1]) + rng.uniform(-0.1, 0.1))))
    return m


PINE_H = [29.6, 32.3, 30.0, 32.6, 30.3, 28.0]  # the stand-in's heights per id (Kit/Props.luau `pine`: 28 to 33)
BIRCH_H = [22.2, 20.8, 22.6, 21.2, 23.0, 21.6]


def pine(variant, rng, height=None):
    """tree_pine_NN: a short bare trunk and 6 to 7 stacked bough tiers with jagged skirts narrowing to a tip (blue-green, lighter on top)."""
    height = (PINE_H[(variant - 1) % 6] if height is None else height)
    tiers = 6 + (variant % 2)  # 6 or 7
    lean = rng.uniform(0.012, 0.035)
    la = rng.uniform(0, math.tau)
    base_r = rng.uniform(7.6, 8.4)

    def axis(y):
        return (math.cos(la) * lean * y, math.sin(la) * lean * y)

    H = height - 4.5  # the tiers rise about 4.5 above their last base: the tip lands on `height`
    trunk_h = rng.uniform(3.4, 4.2)
    trunk_top = H * 0.74
    path = [(0.0, -0.3, 0.0)] + [(axis(y)[0], y, axis(y)[1]) for y in (1.4, trunk_h + 1.0, trunk_top)]
    parts = [S.paint_ramp(S.tube(path, [1.35, 1.1, 0.85, 0.5], seg=6, color=S.BARK, n=2.4, tag="trunk"), [S.BARK_DARK, S.BARK, S.BARK_LIGHT], rng,
                          0, trunk_top, up=0.2, height=0.3, noise=0.1)]
    y = trunk_h - 0.6
    top = H - 2.6  # the last tier's base; the tip sits above it
    span = top - y
    for i in range(tiers):
        t = i / max(1, tiers - 1)
        r0 = base_r * (1.0 - 0.80 * t ** 0.92) + 0.5
        h = (span / tiers) * 1.9 * (1.0 - 0.18 * t) + 1.4
        yy = y + span * (t ** 0.95)
        teeth = 7 if t < 0.5 else 6 if t < 0.8 else 5
        ax = axis(yy)
        tier = _tier(rng, yy, r0, h, teeth, rng.uniform(0.16, 0.26), rng.uniform(0, math.tau), 0.0, S.mix(S.PINE, S.PINE_MID, 0.1 + 0.4 * t),
                     S.mix(S.PINE_MID, S.PINE_LIGHT, 0.2 + 0.6 * t))
        tier.move(ax[0], 0, ax[1])
        parts.append(tier)
    # the tip: a little cone above the last tier
    ax = axis(height - 3.4)
    parts.append(S.flat(S.paint_ramp(cone(1.1, 3.6, seg=5, y0=height - 3.6, color=S.PINE_LIGHT, smooth=False, tag="tip").move(ax[0], 0, ax[1]),
                                    [S.PINE_MID, S.PINE_LIGHT, S.mix(S.PINE_LIGHT, S.OAK_SUN, 0.3)], rng, height - 3.6, height, up=0.2, height=0.6)))
    return S.assemble(parts), {"tiers": tiers}


# ------------------------------------------------------------------ birch

def birch(variant, rng, height=None):
    """tree_birch_NN: a slim white trunk with dark bark marks and a side stub, a crown of four to five yellow-green lobes."""
    height = (BIRCH_H[(variant - 1) % 6] - 2.0) if height is None else height  # the crown rises about 2 above the nominal top
    lean = math.radians(rng.uniform(2.0, 5.0))
    la = rng.uniform(0, math.tau)
    ldir = (math.sin(lean) * math.cos(la), math.cos(lean), math.sin(lean) * math.sin(la))

    def at(y):
        return (ldir[0] * y / ldir[1], y, ldir[2] * y / ldir[1])

    top_y = height - 3.2
    path = [at(-0.3), at(top_y * 0.3), at(top_y * 0.65), at(top_y)]
    parts = [S.paint_ramp(S.tube(path, [1.0, 0.8, 0.6, 0.42], seg=6, color=S.BIRCH, n=2.4, tag="trunk"),
                          [S.mix(S.BIRCH, S.BARK_LIGHT, 0.25), S.BIRCH, S.mix(S.BIRCH, (1, 1, 1), 0.25)], rng, 0, top_y, up=0.1, height=0.2, noise=0.05)]
    # dark bark marks: small slabs hugging the trunk at different heights and sides (the birch giveaway)
    for k in range(6 + variant % 2):
        y = rng.uniform(1.6, top_y * 0.82)
        a = rng.uniform(0, math.tau)
        w = rng.uniform(0.55, 0.9)
        p = at(y)
        rad = 0.72 - 0.3 * (y / top_y)
        mk = S.slab([(-w / 2, -0.2), (w / 2, -0.2), (w / 2, 0.2), (-w / 2, 0.2)], 0.0, rng.uniform(0.35, 0.6), S.BIRCH_MARK, tag="mark")
        mk.rot(math.degrees(-a) + 90, "y").move(p[0] + math.cos(a) * rad, y - 0.25, p[2] + math.sin(a) * rad)
        parts.append(S.flat(mk, "mark"))
    # side stub with its own lobe
    sa = rng.uniform(0, math.tau)
    f0 = top_y * rng.uniform(0.5, 0.62)
    a = at(f0)
    b = (a[0] + math.cos(sa) * 3.2, a[1] + 3.0, a[2] + math.sin(sa) * 3.2)
    parts.append(S.paint_ramp(S.tube([a, ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2), b], [0.42, 0.33, 0.25], seg=5, color=S.BIRCH, n=2.4,
                                     tag="stub"), [S.BIRCH, S.BIRCH], rng, 0, 1, noise=0.03))
    lobes = []
    n_lobes = 4 + (variant % 2)
    a0 = rng.uniform(0, math.tau)
    for i in range(n_lobes):
        f = i / max(1, n_lobes - 1)
        ang = a0 + i * 2.2 + rng.uniform(-0.3, 0.3)
        r = rng.uniform(0.7, 2.2) * (1 - 0.3 * f)
        y = height - 5.4 + f * 4.6 + rng.uniform(-0.3, 0.3)
        rad = rng.uniform(2.5, 3.2) * (1 - 0.15 * f)
        p = at(y)
        pts = 20
        lobes.append(S.blob(rng, pts, rad, rad * 1.08, rad, p[0] + math.cos(ang) * r, y, p[2] + math.sin(ang) * r, jitter=0.12, squash_bottom=0.25,
                            color=S.BIRCH_LEAF, tag="canopy", yaw=rng.uniform(0, math.tau)))
    side = S.blob(rng, 18, rng.uniform(2.1, 2.5), rng.uniform(1.9, 2.2), rng.uniform(2.1, 2.5), b[0] + math.cos(sa) * 0.6, b[1] + 0.8, b[2] + math.sin(sa) * 0.6,
                  jitter=0.12, squash_bottom=0.25, color=S.BIRCH_LEAF, tag="canopy", yaw=rng.uniform(0, math.tau))
    lobes.append(side)
    ymin = min(b_.bounds()[0][1] for b_ in lobes)
    ymax = max(b_.bounds()[1][1] for b_ in lobes)
    for b_ in lobes:
        S.paint_ramp(b_, S.BIRCH_RAMP, rng, ymin, ymax, up=0.38, height=0.5, noise=0.09)
    parts += lobes
    return S.assemble(parts), {"lobes": len(lobes)}
