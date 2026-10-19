"""Cliff / outcrop chunks for framing terrain edges and riverbanks: jointed rock columns of
different heights with sharp fracture facets (like the boulders and ore rocks), split into
strata by tilted, uneven bedding planes; broken corners, a stepped notch, an overhanging
ledge, a jutting spur, V-shaped vertical cracks between columns, thick turf that drapes over
the lip with a ragged edge, and a talus of fallen boulders at the foot. Warm-grey / warm
stone tones with subtle banding. One variant is curved in plan (river bend).

Sizes: 20-40 wide (X), 15-30 tall, 10-15 deep. Front (cliff face) faces Blender -Y; the top
is a grassy plateau so terrain can meet it. Pivot at base centre (flat base at z=0).
"""

import math

from lib.geo import Matrix, Vector
from generators import _rock_common as rc

NAME = "rock_cliff"
VERSION = 2
CATEGORY = "rock"
BUDGET = "cliff"  # 1500 (class added to budgets.json with the FORGE-02 lead's approval)
COLLISION = {"fidelity": "Default"}
CHECKS = {"min_strata": 2, "min_blocks": 6}
DEFAULT_VARIANTS = 5
HERO_VIEW = {"azimuth": -30, "elevation": 20}
LINEUP_GAP = 6.0

# warm greys like the boulders; bands are close neighbours in tone (no light/dark alternation)
TONES = {
    "grey": [("granite_dark", "granite", "granite"), ("stone_dark", "stone", "stone"),
             ("granite_dark", "granite", "granite_light")],
    "dark": [("granite_dark", "granite_dark", "granite"), ("stone_dark", "stone_dark", "stone"),
             ("granite_dark", "granite", "granite")],
    "warm": [("sandstone_dark", "rock_warm", "rock_warm"), ("sandstone_dark", "rock_warm", "sandstone"),
             ("granite_dark", "rock_warm", "rock_warm")],
}
TALUS = {"grey": rc.STONES["granite"], "dark": rc.STONES["granite"], "warm": rc.STONES["warm"]}
TURF = rc.TURF_COLS

PLANS = [
    {"w": 24, "h": 18, "d": 11, "tone": "grey", "plan": "straight", "spur": True},
    {"w": 34, "h": 26, "d": 13, "tone": "dark", "plan": "straight", "spur": False},
    {"w": 30, "h": 16, "d": 11, "tone": "warm", "plan": "curved", "spur": False},
    {"w": 22, "h": 28, "d": 12, "tone": "grey", "plan": "bluff", "spur": True},
    {"w": 38, "h": 20, "d": 12, "tone": "warm", "plan": "straight", "spur": True},
]


def variants(n, seed):
    out = []
    for i in range(n):
        p = dict(PLANS[i % len(PLANS)])
        p["seed"] = seed * 1000 + 100 + i
        out.append(p)
    return out


def _column(rng, cw, cd, ch, fractures=4):
    """Jointed rock column: near-sharp box points, a faceted bulging front and an uneven top,
    hulled, then broken by fracture planes (corners, front facets) and V-cut front edges so
    neighbouring columns meet in a vertical crack. Centred on x/y, base z=0, front -Y."""
    pts = rc.block_points(rng, cw, cd, ch, 0.3, 0.3, bottom=False)
    for i in range(5):
        pts.append(Vector((rng.uniform(-0.42, 0.42) * cw, -cd / 2 - rng.uniform(0.2, 1.1), rng.uniform(0.1, 0.9) * ch)))
    for i in range(3):
        pts.append(Vector((rng.uniform(-0.4, 0.4) * cw, rng.uniform(-0.3, 0.4) * cd, ch + rng.uniform(0.0, 0.8))))
    bm = rc.hull(pts)
    for sx in (-1, 1):  # vertical cracks: cut the front vertical edges deeply (a V between columns)
        d = Vector((sx, -1.0, rng.uniform(-0.1, 0.1))).normalized()
        rc.cut(bm, d * rc.support(bm, d) * rng.uniform(0.9, 0.95), d)
    for i in range(fractures):  # broken corners and big flat fracture facets
        kind = rng.random()
        if kind < 0.5:
            d = Vector((rng.choice((-1, 1)) * rng.uniform(0.3, 0.8), -rng.uniform(0.2, 0.8), rng.uniform(0.5, 1.0)))
        elif kind < 0.8:
            d = Vector((rng.uniform(-0.4, 0.4), -1.0, rng.uniform(-0.35, 0.35)))
        else:
            d = Vector((rng.choice((-1, 1)), rng.uniform(-0.5, 0.2), rng.uniform(0.0, 0.6)))
        d.normalize()
        rc.cut(bm, d * rc.support(bm, d) * rng.uniform(0.84, 0.94), d)
    return bm


def build(b, p):
    """Budget-aware: rebuild with fewer fracture facets if 1450 tris would be exceeded."""
    for lite in range(3):
        b.pieces, b.stats, b.sockets = [], {}, {}
        _build(b, p, lite)
        if b.tris <= 1450:
            break
    b.stats["lite"] = lite


def _build(b, p, lite):
    rng = b.rng
    W = p["w"] * rng.uniform(0.95, 1.05)
    H = p["h"] * rng.uniform(0.95, 1.03)
    D = p["d"] * rng.uniform(0.95, 1.05)
    tones = TONES[p["tone"]]
    curved = p["plan"] == "curved"
    bluff = p["plan"] == "bluff"
    R_arc = W * 0.9

    def place(bm, bx, by):
        """straight coords -> plan (curved variant bends X onto an arc, ends coming forward)."""
        if not curved:
            rc.move(bm, bx, by, 0)
            return
        th = bx / R_arc
        r = R_arc + by
        rc.transform(bm, Matrix.Rotation(-th, 4, "Z"))
        rc.move(bm, r * math.sin(th), -R_arc + r * math.cos(th), 0)

    def ledge(bm, back, fy):
        rc.transform(bm, Matrix.Translation((0, back, 0)) @ Matrix.Diagonal((1.0, fy, 1.0, 1.0))
                     @ Matrix.Translation((0, -back, 0)))

    # columns of different heights (stepped skyline), widths varying
    m = max(2, round(W / rng.uniform(8.5, 11.0)))
    cuts = sorted(rng.uniform(0.25, 0.75) for _ in range(m - 1))
    edges = [-W / 2] + [-W / 2 + W * (i + c) / m for i, c in enumerate(cuts)] + [W / 2]
    tallest = rng.randrange(m)
    heights = []
    for j in range(m):
        if j == tallest:
            heights.append(H)
        elif bluff:
            heights.append(H * rng.uniform(0.45, 0.7))
        else:
            heights.append(H * rng.uniform(0.62, 0.92) * (0.85 if j in (0, m - 1) else 1.0))
    notch_col = rng.choice([j for j in range(m) if j != tallest])
    overhang_done = False
    base_tone = rng.randrange(len(tones))
    blocks = 0
    strata = 0
    tops = []  # (bm, kind) for turf
    for j in range(m):
        a, c = edges[j] - (0.3 if j else 0.0), edges[j + 1] + (0.3 if j < m - 1 else 0.0)
        cw = c - a
        ch = heights[j]
        cd = D * rng.uniform(0.86, 1.0)
        col = _column(rng, cw, cd, ch, fractures=max(1, 4 - lite))
        yoff = (D - cd) / 2 + rng.uniform(-0.8, 0.8)
        cx = (a + c) / 2
        back = cd / 2
        # strata: 2-4 bands per column, bedding planes tilted and of uneven thickness (+-40 %)
        nb = max(2, min(4, round(ch / rng.uniform(5.5, 7.5))))
        ts = [rng.uniform(0.6, 1.4) for _ in range(nb)]
        zs = [0.0]
        for t in ts[:-1]:
            zs.append(zs[-1] + t * ch / sum(ts))
        planes = [Vector((rng.uniform(-0.1, 0.1), rng.uniform(-0.06, 0.08), 1.0)).normalized() for _ in zs]
        strata = max(strata, nb)
        alt_band = rng.randrange(nb)
        for k in range(nb):
            band = col.copy()
            if k < nb - 1:
                rc.cut(band, (0, 0, zs[k + 1]), planes[k + 1], tag=rc.ROUGH)
            if k > 0:
                rc.cut(band, (0, 0, zs[k]), -planes[k], tag=rc.ROUGH)
            if not band.faces:
                band.free()
                continue
            # ledges: bands recess irregularly; one band overhangs the one below it
            if not overhang_done and 0 < k < nb - 1 and rng.random() < 0.6:
                fy = 1.0 + rng.uniform(1.0, 1.6) / cd
                overhang_done = True
            else:
                fy = max(0.6, 1.0 - (k * rng.uniform(0.4, 0.9) * (1.4 if bluff else 1.0)) / cd)
            ledge(band, back, fy)
            colr = tones[(base_tone + (1 if k == alt_band else 0)) % len(tones)]
            top_band = k == nb - 1
            if top_band and j == notch_col:  # stepped notch: one side of the top band is lower
                sx = rng.choice((-1, 1))
                xcut = sx * cw * rng.uniform(0.0, 0.15)
                _lo, hi_ = rc.bounds(band)
                low = band.copy()
                rc.cut(band, (xcut, 0, 0), (-sx, 0, 0), tag=rc.ROUGH)
                rc.cut(low, (xcut, 0, 0), (sx, 0, 0), tag=rc.ROUGH)
                rc.cut(low, (0, 0, zs[k] + (hi_.z - zs[k]) * rng.uniform(0.35, 0.55)), (0, 0, 1), tag=rc.ROUGH)
                if low.faces:
                    place(low, cx, yoff)
                    tops.append((low.copy(), "low"))
                    b.add(rc.to_piece(low, {rc.ROUGH: colr, rc.GROUND: colr[0]}, grad=("range", 0.15, 0.9)),
                          tag="strata")
                    blocks += 1
                else:
                    low.free()
                if not band.faces:
                    band.free()
                    continue
            place(band, cx, yoff)
            lo_, _h = rc.bounds(band)
            if lo_.z < 0:
                rc.cut(band, (0, 0, 0), (0, 0, -1), tag=rc.GROUND)
            if top_band:
                tops.append((band.copy(), "top"))
            b.add(rc.to_piece(band, {rc.ROUGH: colr, rc.GROUND: colr[0]}, grad=("range", 0.15, 0.9)), tag="strata")
            blocks += 1
        col.free()

    # ---- jutting spur: a lower faceted buttress standing proud of the face
    if p["spur"]:
        sw, sd = rng.uniform(3.5, 5.0), rng.uniform(3.5, 4.5)
        sh = H * rng.uniform(0.4, 0.6)
        sp = _column(rng, sw, sd, sh, fractures=max(1, 3 - lite))
        d = Vector((rng.uniform(-0.3, 0.3), -0.6, 1.0)).normalized()  # sloping, pointed top
        rc.cut(sp, d * rc.support(sp, d) * 0.85, d)
        place(sp, rng.uniform(-0.3, 0.3) * W, -D / 2 - sd * 0.25)
        colr = tones[(base_tone + 1) % len(tones)]
        tops.append((sp.copy(), "spur"))
        b.add(rc.to_piece(sp, {rc.ROUGH: colr, rc.GROUND: colr[0]}, grad=("range", 0.15, 0.9)), tag="spur")
        blocks += 1

    # ---- turf: a thick plateau plate on each top + plates on the front lip that drape over it
    for bm, kind in tops:
        lo_, hi_ = rc.bounds(bm)
        cc = rc.centroid(bm)
        if kind != "spur":
            loc, nrm = rc.ray_surface(bm, (cc.x, cc.y + 0.5, hi_.z + 5), (0, 0, -1))
            if loc is not None and nrm.z > 0.6:
                g = rc.surface_plate(bm, rng, loc, nrm, min(hi_.x - lo_.x, hi_.y - lo_.y) * 0.8, 0.5, depth=1.4)
                if g:
                    b.add(rc.to_piece(g, TURF, grad=("range", 0.35, 1.0)), tag="turf")
        nlip = 1 if (kind == "spur" or lite) else 2
        for q in range(nlip):
            x = lo_.x + (hi_.x - lo_.x) * rng.uniform(0.2, 0.8)
            loc, nrm = rc.ray_surface(bm, (x, lo_.y + (hi_.y - lo_.y) * 0.25, hi_.z + 5), (0, 0, -1))
            if loc is None or nrm.z < 0.5:
                continue
            g = rc.surface_plate(bm, rng, loc, Vector((0, 0, 1)), rng.uniform(1.6, 2.6), 0.4,
                                 depth=rng.uniform(0.9, 2.0))
            if g:
                b.add(rc.to_piece(g, TURF, grad=("range", 0.35, 1.0)), tag="turf")
        bm.free()

    # ---- talus: fallen boulders and pebbles at the foot of the face
    fam = TALUS[p["tone"]]
    for i in range(3):
        u = rng.uniform(-0.38, 0.38) * W
        r = rng.uniform(2.0, 3.4)
        tal = rc.boulder(rng, r, r * 0.85, r * 0.7, n=9, fractures=2, bury=0.35, chamfer_frac=0.0)
        place(tal, u, -D / 2 - r * 0.6)
        b.add(rc.to_piece(tal, {rc.ROUGH: fam, rc.GROUND: fam[0]}, grad=("range", 0.1, 0.9)), tag="talus")
    for i in range(2):
        u = rng.uniform(-0.4, 0.4) * W
        tal = rc.boulder(rng, 0.7, 0.55, 0.45, n=7, fractures=0, bury=0.3, chamfer_frac=0.0)
        place(tal, u, -D / 2 - rng.uniform(2.0, 3.5))
        b.add(rc.to_piece(tal, {rc.ROUGH: fam, rc.GROUND: fam[0]}, grad=("range", 0.1, 0.9)), tag="talus")

    b.stats["strata"] = strata
    b.stats["blocks"] = blocks
    b.stats["pieces"] = len(b.pieces)
