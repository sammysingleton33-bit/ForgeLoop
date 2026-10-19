"""Quarry node (stone resource): a big rock mass with flat, freshly cut faces and stepped
quarried benches on its front (or an asymmetric stepped pit cut into it), running-bond block
seams clipped to each cut face, a split line with wooden wedges, rubble, and one lifting /
access landmark per variant: windlass, ladder + row of blocks, tripod crane, scaffold, sled,
treadwheel crane. Four stone tones (grey, dark granite, pale warm limestone, sandstone). The
rough mass flares out at the bottom so every node sits on a wide, grounded base.

Reads at 60 studs as "stone": grey rough rock + pale stepped faces + timber.
Front (the worked face) faces Blender -Y. Pivot at base centre; base cut flat at z=0.
Sockets: `harvest` (where a worker stands, ground level, in front of the bottom bench),
`hit` (point on the cut face the tool strikes, for VFX). Stats: harvest_radius (studs).
"""

import math

from lib import kit
from lib.geo import Vector, box, cylinder
from generators import _rock_common as rc

NAME = "resource_stone"
VERSION = 3
CATEGORY = "resource"
BUDGET = "resource"
COLLISION = {"fidelity": "Hull"}
CHECKS = {"min_benches": 2, "min_cut_blocks": 1, "has_harvest_radius": 1}
DEFAULT_VARIANTS = 6
HERO_VIEW = {"azimuth": -32, "elevation": 24}

CUTS = {
    "stone": ("stone_light", "stone_pale", "stone_pale"),
    "granite": ("granite", "granite_light", "granite_light"),
    "warm": ("sandstone", "sandstone_light", "path_sand"),
    "pale": ("stone_light", "stone_pale", "stone_pale"),
}
SEAM = {"stone": "stone_dark", "granite": "granite_dark", "warm": "sandstone_dark", "pale": "stone_dark"}
ROUGH = {"pale": ("stone", "cobble", "stone_light")}  # light warm limestone (default: family dark/dark/mid)

PLANS = [
    {"steps": 3, "cut": "front", "stone": "stone", "prop": "windlass", "loose": "roped", "scale": 1.0},
    {"steps": 2, "cut": "corner", "stone": "pale", "prop": "ladder", "loose": "row", "scale": 0.9},
    {"steps": 4, "cut": "front", "stone": "granite", "prop": "tripod", "loose": "hang", "scale": 1.15},
    {"steps": 3, "cut": "corner", "stone": "warm", "prop": "scaffold", "loose": "stack", "scale": 1.05},
    {"steps": 4, "cut": "pit", "stone": "pale", "prop": "sled", "loose": "sled", "scale": 1.1},
    {"steps": 3, "cut": "front", "stone": "warm", "prop": "treadwheel", "loose": "hang", "scale": 1.0},
]


def variants(n, seed):
    out = []
    for i in range(n):
        p = dict(PLANS[i % len(PLANS)])
        p["seed"] = seed * 1000 + 500 + i
        out.append(p)
    return out


def _hull2d(pts):
    """Convex hull (CCW) of 2-D points; [] if degenerate."""
    pts = sorted(set((round(x, 5), round(z, 5)) for x, z in pts))
    if len(pts) < 3:
        return []

    def cross(o, a, c):
        return (a[0] - o[0]) * (c[1] - o[1]) - (a[1] - o[1]) * (c[0] - o[0])
    lower, upper = [], []
    for q in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], q) <= 0:
            lower.pop()
        lower.append(q)
    for q in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], q) <= 0:
            upper.pop()
        upper.append(q)
    return lower[:-1] + upper[:-1]


def _span(poly, t, axis):
    """Interval of the convex polygon along the other axis at coordinate t on `axis` (0=u, 1=z)."""
    vals = []
    o = 1 - axis
    for (a, c) in zip(poly, poly[1:] + poly[:1]):
        if (a[axis] - t) * (c[axis] - t) <= 0 and a[axis] != c[axis]:
            f = (t - a[axis]) / (c[axis] - a[axis])
            vals.append(a[o] + (c[o] - a[o]) * f)
    return (min(vals), max(vals)) if len(vals) >= 2 else None


def _running_bond(b, rng, poly, color, S, side, plane):
    """Seam strips on a cut face given as a convex polygon in (u, z): u is X on front faces (strip
    sits at y=plane) or Y on side faces (strip at x=plane). Returns the number of strips."""
    inset, t, d = 0.3, 0.14, 0.08
    zmin = min(q[1] for q in poly)
    zmax = max(q[1] for q in poly)
    hr = rng.uniform(1.5, 1.9) * S
    lines = []
    z = zmin + hr
    while z < zmax - 0.6:
        lines.append(z)
        z += hr * rng.uniform(0.9, 1.1)
    out = 0

    def strip(u0, u1, z0, z1):
        if side:
            pc = box(d, u1 - u0, z1 - z0, color).move(plane, (u0 + u1) / 2, z0)
        else:
            pc = box(u1 - u0, d, z1 - z0, color).move((u0 + u1) / 2, plane, z0)
        b.add(pc.paint(grad="flat"), tag="seam")

    for zl in lines:  # bed joints
        r = _span(poly, zl, 1)
        if r and r[1] - r[0] > 2 * inset + 0.8:
            strip(r[0] + inset, r[1] - inset, zl - t / 2, zl + t / 2)
            out += 1
    bounds = [zmin] + lines + [zmax]
    bl = rng.uniform(2.5, 3.2) * S
    off0 = rng.uniform(0, bl)
    umin = min(q[0] for q in poly)
    umax = max(q[0] for q in poly)
    for j in range(len(bounds) - 1):  # head joints, staggered half a block per course
        za, zb = bounds[j] + (t / 2 if j > 0 else 0.25), bounds[j + 1] - (t / 2 if j + 1 < len(bounds) - 1 else 0.25)
        if zb - za < 0.5:
            continue
        u = umin + off0 + (bl / 2 if j % 2 else 0.0)
        while u < umax:
            zr = _span(poly, u, 0)
            ur_a, ur_b = _span(poly, za + 0.05, 1) or (1e9, -1e9), _span(poly, zb - 0.05, 1) or (1e9, -1e9)
            inside = max(ur_a[0], ur_b[0]) + inset < u < min(ur_a[1], ur_b[1]) - inset
            if zr and inside:
                z0, z1 = max(za, zr[0] + 0.2), min(zb, zr[1] - 0.2)
                if z1 - z0 > 0.5:
                    strip(u - t / 2, u + t / 2, z0, z1)
                    out += 1
            u += bl
    return out


def _riser_top(bm, x, y, zmax):
    loc, _n = rc.ray_surface(bm, (x, y, zmax + 50.0), (0, 0, -1))
    return min(zmax, loc.z) if loc is not None else zmax


def build(b, p):
    rng = b.rng
    S = p["scale"]
    fam = p["stone"]
    if fam in ROUGH:
        rough = ROUGH[fam]
    else:
        dark, mid, light = rc.STONES[fam]
        rough = (dark, dark, mid)  # weathered rock stays dark so the fresh pale cuts pop
    cutc = CUTS[fam]
    seam_c = SEAM[fam]
    W, D, H = rng.uniform(12.5, 14.5) * S, rng.uniform(11.0, 12.5) * S, rng.uniform(8.5, 9.5) * S

    # ---- the rough mass (pre-cut), sunk a little into the ground
    pts = rc.ellipsoid_points(rng, 16, W / 2, D / 2, H * 0.62, noise=0.14, seed=rng.uniform(0, 99))
    for q in pts:  # flare the lower half outwards: a wide, grounded base instead of a keel
        if q.z < 0:
            f = 1.0 + 0.45 * (-q.z / (H * 0.62))
            q.x *= f
            q.y *= f
    R = rc.hull(pts)
    for _ in range(2):  # natural fracture facets on back / sides
        a = rng.uniform(0.15, 0.85) * math.pi  # +Y half (the back)
        d = Vector((math.cos(a), math.sin(a), rng.uniform(0.0, 0.7))).normalized()
        rc.cut(R, d * rc.support(R, d) * rng.uniform(0.8, 0.9), d, tag=rc.ROUGH)
    d = Vector((rng.uniform(-0.25, 0.25), rng.uniform(0.0, 0.3), 1.0)).normalized()  # weathered top facet
    rc.cut(R, d * rc.support(R, d) * 0.86, d, tag=rc.ROUGH)
    lo, hi = rc.bounds(R)
    rc.move(R, 0, 0, -lo.z - (hi.z - lo.z) * 0.22)
    lo, hi = rc.bounds(R)
    top = hi.z

    # ---- benches: band k between z_k and z_k+1, cut back to y >= y_k; "corner" also steps the +X
    # side back; "pit" cuts a deep stepped notch between two side walls that widen upwards
    n = p["steps"]
    mode = p["cut"]
    pit = mode == "pit"
    zs = [0.0]
    for k in range(1, n):
        zs.append(top * (0.2 + 0.62 * k / n) + rng.uniform(-0.25, 0.25))
    zs.append(None)
    y_front = lo.y * (rng.uniform(0.15, 0.25) if pit else rng.uniform(0.42, 0.5))
    tread = min(2.6, max(1.9, (abs(y_front) + D * 0.16) / n)) * S
    if pit:
        tread = 1.7 * S
    ys = [y_front + k * tread for k in range(n)]
    x_side = hi.x * rng.uniform(0.5, 0.62)
    side_tread = tread * 0.8
    pw = [W * 0.2 + k * 0.9 * S for k in range(n)]  # pit half-width per band (widens upwards)
    # break the symmetric "sofa": walls of different height, skewed wall faces and step edges
    low_side = rng.choice((-1, 1))
    low_z = top * rng.uniform(0.38, 0.5)
    wall_skew = {-1: rng.uniform(-0.15, 0.15), 1: rng.uniform(-0.15, 0.15)}
    step_skew = [rng.uniform(-0.1, 0.1) if pit else 0.0 for _ in range(n)]
    risers = []
    pieces = []
    for k in range(n):
        band = R.copy()
        if zs[k + 1] is not None:
            rc.cut(band, (0, 0, zs[k + 1]), (0, 0, 1), tag=rc.CUT)
        rc.cut(band, (0, 0, zs[k]), (0, 0, -1), tag=rc.GROUND if k == 0 else rc.CUT)
        if pit:
            for sgn in (-1, 1):  # side walls keep the rough front, inner faces are fresh cuts
                wall = band.copy()
                wn = Vector((-sgn, wall_skew[sgn], 0.0)).normalized()
                rc.cut(wall, (sgn * pw[k], 0, 0), wn, tag=rc.CUT)
                if sgn == low_side:  # the low side is broken down to a rough rubble slope
                    rc.cut(wall, (0, 0, low_z), (sgn * 0.7, -0.3, 1.0), tag=rc.ROUGH)
                if wall.faces:
                    rc.chamfer(wall, 0.1 * S, 40)
                    pieces.append(wall)
                else:
                    wall.free()
            for sgn in (-1, 1):
                rc.cut(band, (sgn * pw[k], 0, 0), Vector((sgn, -wall_skew[sgn], 0.0)).normalized(), tag=rc.CUT)
        step_n = Vector((step_skew[k], -1.0, 0.0)).normalized()
        front = rc.cut(band, (0, ys[k], 0), step_n, tag=rc.CUT)
        sidef = []
        if mode == "corner":
            sidef = rc.cut(band, (x_side - k * side_tread, 0, 0), (1, 0, 0), tag=rc.CUT)
        fb = rc.face_bounds(front)
        sb = rc.face_bounds(sidef) if sidef else None
        fpoly = _hull2d([(v.co.x, v.co.z) for f in front if f.is_valid for v in f.verts])
        spoly = _hull2d([(v.co.y, v.co.z) for f in sidef if f.is_valid for v in f.verts]) if sidef else None
        rc.chamfer(band, 0.1 * S, 40)
        risers.append((k, fb, sb, band.copy(), fpoly, spoly))
        pieces.append(band)
    R.free()
    for band in pieces:
        if not band.faces:
            band.free()
            continue
        b.add(rc.to_piece(band, {rc.ROUGH: rough, rc.CUT: cutc, rc.GROUND: rough[0]}, grad=("grange", 0.05, 1.0)),
              tag="bench")
    b.stats["benches"] = n

    # ---- block seams in running bond, clipped to each cut face's real outline: horizontal bed
    # joints span the face; vertical joints run only between two bed joints and are staggered half
    # a block per course, so every junction is a T and no joint leaves the stone. No tally marks.
    seams = 0
    for k, fb, sb, bm, fpoly, spoly in risers:
        for poly, side in ((fpoly, False), (spoly, True)):
            if not poly or len(poly) < 3:
                continue
            seams += _running_bond(b, rng, poly, seam_c, S, side, ys[k] - 0.03 if not side else (sb[1].x + 0.03))
        bm.free()
    b.stats["seams"] = seams

    fb0 = risers[0][1]
    fx0, fx1 = (fb0[0].x, fb0[1].x) if fb0 else (-W / 3, W / 3)
    fxm = (fx0 + fx1) / 2
    prop = p["prop"]
    loose = p["loose"]

    # ---- split line with wooden wedges on the highest tread (not where the windlass stands)
    kt = n - 2
    if prop != "windlass" and risers[kt + 1][1] is not None:
        yw = (ys[kt] + ys[kt + 1]) / 2
        zw = zs[kt + 1]
        fb = risers[kt + 1][1]
        x0, x1 = fb[0].x + 0.8, fb[1].x - 0.8
        b.add(box(x1 - x0, 0.14, 0.08, seam_c).move((x0 + x1) / 2, yw, zw), tag="seam")
        for i in range(max(2, int((x1 - x0) / 1.6))):
            x = x0 + 0.5 + i * 1.6
            if x < x1 - 0.3:
                b.add(rc.wedge(x, yw, zw + 0.08, rng.uniform(-0.15, 0.15)), tag="wedge")

    def block(x, y, z, bw, bd, bh, yaw):
        blk = rc.slab(rng, bw, bd, bh, chamfer_k=0.2, jitter=0.05, taper=1.0, at=(x, y, z), yaw=yaw)
        b.add(rc.to_piece(blk, {rc.ROUGH: cutc}, grad=("range", 0.2, 0.95)), tag="block")

    # ---- loose blocks: a different composition per variant
    blocks = 0
    if loose == "stack":  # two stacked + one beside, front-left
        bx, by = fx0 - 1.0 * S, ys[0] - 1.8 * S
        bw, bd, bh = 2.4 * S, 1.7 * S, 1.5 * S
        block(bx, by, 0, bw, bd, bh, rng.uniform(-0.4, 0.4))
        block(bx + 0.2, by, bh - 0.02, bw * 0.8, bd * 0.9, bh * 0.85, rng.uniform(-0.6, 0.6))
        block(fx1 + 1.2 * S, ys[0] - 1.6 * S, 0, bw * 0.9, bd, bh * 0.9, rng.uniform(-0.5, 0.5))
        blocks += 3
    elif loose == "row":  # a scattered row of shrinking blocks leading away to the right
        for i in range(4):
            sc_ = 1.0 - 0.13 * i
            block(fxm + 1.0 * S + i * 2.5 * S, ys[0] - 2.2 * S - i * 0.5 * S + rng.uniform(-0.3, 0.3), 0,
                  2.2 * S * sc_, 1.5 * S * sc_, 1.3 * S * sc_, rng.uniform(-0.35, 0.35))
            blocks += 1
    for i in range(4 if loose != "row" else 2):
        x = rng.uniform(fx0, fx1)
        b.add(rc.pebble(rng, x, ys[0] - rng.uniform(0.4, 1.8), rng.uniform(0.18, 0.36) * S, cutc, n=7), tag="chip")

    # ---- the landmark rig / tools
    hx = fxm
    if prop == "windlass":
        # hand windlass on the upper tread: A-frame trestles, drum + crank; rope over the edge to a block
        kk = n - 2
        wy = (ys[kk] + ys[kk + 1]) / 2
        wz = zs[kk + 1]
        wx = fxm - (fx1 - fx0) * 0.12
        L = 3.0 * S
        for sx in (-1, 1):
            xx = wx + sx * L / 2
            for sy in (-1, 1):
                b.add(rc.beam((xx, wy + sy * 0.75, wz), (xx, wy, wz + 1.9), 0.26, 0.26, "wood", (1, 0, 0)), tag="timber")
            b.add(rc.beam((xx, wy - 0.85, wz + 0.2), (xx, wy + 0.85, wz + 0.2), 0.24, 0.24, "timber", (1, 0, 0)),
                  tag="timber")
        drum = cylinder(0.42, 0.42, L + 0.4, 8, "wood_light").rotate(math.pi / 2, "Y")
        b.add(drum.move(wx - (L + 0.4) / 2, wy, wz + 1.75), tag="timber")
        b.add(cylinder(0.5, 0.5, 1.0, 8, "rope").rotate(math.pi / 2, "Y").move(wx - 0.5, wy, wz + 1.75), tag="rope")
        cx_ = wx + L / 2 + 0.3
        b.add(rc.beam((cx_, wy, wz + 1.75), (cx_ + 0.15, wy - 0.2, wz + 2.6), 0.2, 0.2, "timber", (1, 0, 0)), tag="timber")
        b.add(rc.beam((cx_ + 0.15, wy - 0.2, wz + 2.6), (cx_ + 0.75, wy - 0.25, wz + 2.6), 0.16, 0.16, "wood_light",
                      (0, 1, 0)), tag="timber")
        # rope from the drum down the face to a roped block standing at the foot
        bxr, byr = wx - 0.4, ys[0] - 1.6 * S
        bh = 1.4 * S
        block(bxr, byr, 0, 2.2 * S, 1.6 * S, bh, 0.1)
        blocks += 1
        top_r = Vector((wx - 0.4, wy - 0.45, wz + 1.75))
        b.add(rc.beam(Vector((bxr, byr, bh + 0.05)), top_r, 0.12, 0.12, "rope", (1, 0, 0)), tag="rope")
        for sx in (-0.5, 0.5):
            b.add(box(0.12, 1.75 * S, 0.12, "rope").move(bxr + sx, byr, bh), tag="rope")
        hx = fxm + (fx1 - fx0) * 0.3
    if prop == "ladder":
        kk = n - 1
        lx = fxm - (fx1 - fx0) * 0.2
        b.add(rc.ladder((lx, ys[kk - 1] - 0.2 - 1.8, zs[kk - 1]), (lx, ys[kk] - 0.25, zs[kk] + 2.2), width=1.7),
              tag="timber")
        b.add(rc.sledgehammer((lx - 2.2, ys[0] - 1.4, 0.0), (lx - 2.6, ys[0] - 0.25, 2.8)), tag="tool")
        hx = fxm - (fx1 - fx0) * 0.05
    if prop == "scaffold":
        # timber scaffold standing in front of the face: deck level with the upper tread, ladder up
        kk = n - 1
        zt = zs[kk]
        y0, y1 = ys[0] - 2.8, ys[kk] - 0.15
        x0, x1 = fxm - 2.6, fxm + 2.6
        for x in (x0 + 0.25, x1 - 0.25):
            for yy in (y0 + 0.25, ys[0] - 0.5):
                b.add(rc.beam((x, yy, 0.0), (x, yy, zt - 0.3), 0.36, 0.36, "wood", (1, 0, 0)), tag="timber")
            b.add(rc.beam((x, y0 + 0.25, 0.4), (x, ys[0] - 0.5, zt - 0.6), 0.24, 0.24, "wood_dark", (1, 0, 0)),
                  tag="timber")
            b.add(rc.beam((x, y0, zt - 0.45), (x, y1, zt - 0.45), 0.34, 0.34, "timber", (1, 0, 0)), tag="timber")
        for pl in kit.plank_floor(x1 - x0 + 0.4, y1 - y0, 0.3, 0.75, "wood_light", rng, along="y"):
            b.add(pl.move(fxm, (y0 + y1) / 2, zt - 0.28), tag="timber")
        b.add(rc.ladder((x1 + 0.4, y0 - 1.6, 0.0), (x1 + 0.4, y0 + 0.2, zt + 1.0), width=1.5), tag="timber")
        b.add(rc.pickaxe((x0 - 1.0, ys[0] - 1.4, 0.0), (x0 - 0.8, ys[0] - 0.25, 3.0), side=(1, 0, 0.2)), tag="tool")
        hx = x0 - 1.6
    if prop == "tripod":
        # timber tripod over the front bench, a block hanging from it (no loose blocks on the ground)
        cx, cy = fxm + (fx1 - fx0) * 0.28, ys[0] - 0.8
        apex = Vector((cx, cy - 0.6, top * 0.95 + 2.5))
        for a in (math.radians(-150), math.radians(-30), math.radians(90)):
            foot = Vector((cx + math.cos(a) * 3.6, cy + math.sin(a) * 2.6, 0.0))
            if a > 0:
                foot.z = zs[1] if (foot.y > ys[0]) else 0.0
            b.add(rc.beam(foot, apex + (apex - foot).normalized() * 0.5, 0.42, 0.42, "wood", (0, 0, 1)), tag="timber")
        b.add(cylinder(0.5, 0.5, 0.4, 8, "wood_dark").rotate(math.pi / 2, "Y").move(apex.x - 0.2, apex.y, apex.z - 0.7),
              tag="timber")
        hb, zb = 1.6, 1.4
        b.add(box(0.14, 0.14, apex.z - 0.9 - (zb + hb)).move(apex.x, apex.y, zb + hb).paint(color="rope"), tag="rope")
        block(apex.x, apex.y, zb, 2.0, 1.6, hb, 0.3)
        for sx in (-0.5, 0.5):  # rope sling over the block
            b.add(box(0.12, 1.7, 0.12, "rope").move(apex.x + sx, apex.y, zb + hb), tag="rope")
        blocks += 1
        hx = fxm - (fx1 - fx0) * 0.15
    if prop == "treadwheel":
        # medieval treadwheel crane beside the face: a big wheel on trestles turning a jib's rope
        side = rng.choice((-1, 1))
        wx, wy = fx0 - 3.2 if side < 0 else fx1 + 3.2, ys[0] - 2.4
        Rw, ax_z, gap = 2.9, 3.5, 1.3
        for sg in (-1, 1):  # two rims of 8 timbers and a cross of spokes each
            yy = wy + sg * gap / 2
            pts = [Vector((wx + math.cos(math.tau * i / 8) * Rw, yy, ax_z + math.sin(math.tau * i / 8) * Rw))
                   for i in range(8)]
            for i in range(8):
                b.add(rc.beam(pts[i], pts[(i + 1) % 8], 0.32, 0.36, "wood", (0, 1, 0)), tag="timber")
            for i in range(2):
                b.add(rc.beam(pts[i], pts[i + 4], 0.24, 0.24, "wood_dark", (0, 1, 0)), tag="timber")
            for dx in (-1.4, 1.4):  # A-frame trestle
                b.add(rc.beam((wx + dx, yy + sg * 0.5, 0.0), (wx, yy + sg * 0.5, ax_z + 0.3), 0.3, 0.3, "timber",
                              (0, 1, 0)), tag="timber")
        for i in (1, 3, 5, 7):  # tread boards between the rims
            a = math.tau * (i + 0.5) / 8
            px, pz = wx + math.cos(a) * (Rw - 0.15), ax_z + math.sin(a) * (Rw - 0.15)
            b.add(rc.beam((px, wy - gap / 2, pz), (px, wy + gap / 2, pz), 0.4, 0.14, "wood_light", (0, 0, 1)),
                  tag="timber")
        b.add(cylinder(0.25, 0.25, gap + 1.6, 6, "iron_dark").rotate(-math.pi / 2, "X")
              .move(wx, wy - gap / 2 - 0.8, ax_z), tag="timber")
        # jib from the trestle top reaching over the face, rope down to a hanging block
        base = Vector((wx, wy + gap / 2 + 0.5, ax_z + 0.3))
        tip = Vector((fxm + side * (fx1 - fx0) * 0.05, ys[0] + 0.4, top + 1.5))
        b.add(rc.beam(base, tip, 0.34, 0.34, "wood", (0, 0, 1)), tag="timber")
        b.add(rc.beam(Vector((wx, wy + gap / 2 + 0.5, 0.0)), base, 0.36, 0.36, "timber", (1, 0, 0)), tag="timber")
        hb, zb = 1.5, 2.0
        b.add(box(0.14, 0.14, tip.z - (zb + hb)).move(tip.x, tip.y - 0.1, zb + hb).paint(color="rope"), tag="rope")
        block(tip.x, tip.y - 0.1, zb, 2.0, 1.5, hb, 0.2)
        blocks += 1
        hx = fxm - side * (fx1 - fx0) * 0.25
    if prop == "sled":
        # wooden sled on log rollers carrying a block out of the pit
        sx, sy = fxm + (fx1 - fx0) * 0.1, ys[0] - 2.6
        for dx in (-1.2, 1.2):
            for pc in rc.log(rng, 3.4, 0.3, seg=6, rings=(True, False)):
                b.add(pc.rotate(math.pi / 2, "Z").move(sx + dx, sy, 0.3), tag="timber")
        for dy in (-0.75, 0.75):
            b.add(kit.bbox(3.6, 0.45, 0.35, "wood", 0.06).move(sx, sy + dy, 0.6), tag="timber")
        block(sx, sy, 0.95, 2.6, 1.8, 1.5, 0.08)
        b.add(box(0.12, 1.9, 0.12, "rope").move(sx - 0.6, sy, 2.45), tag="rope")
        b.add(rc.beam((sx + 1.8, sy, 0.75), (sx + 1.8 + 2.8, sy - 2.2, 0.12), 0.14, 0.14, "rope", (0, 0, 1)), tag="rope")
        blocks += 1
        hx = fxm - (fx1 - fx0) * 0.25
    b.stats["cut_blocks"] = blocks

    # ---- grass at the foot of the rough sides
    for i in range(3):
        a = rng.uniform(0.1, 0.9) * math.pi
        b.add(rc.grass_tuft(rng, math.cos(a) * W * 0.5, math.sin(a) * D * 0.45, size=1.1), tag="grass")

    # ---- gameplay sockets
    b.socket("harvest", hx, ys[0] - 2.6 if not pit else ys[0] - 1.2, 0.0)
    b.socket("hit", hx, ys[0], min(2.6, (zs[1] or 3.0) * 0.6))
    b.stats["harvest_radius"] = round(max(W, D) / 2 + 2.5, 1)
    rc.rest_on_ground(b)
    b.stats["pieces"] = len(b.pieces)
