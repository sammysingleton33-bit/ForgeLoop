"""Boulders: faceted, chamfered, noise-displaced rock clusters in three sizes.

Each asset is one main mass plus 1-3 half-buried satellites (and pebbles / grass tufts on
the bigger sizes). Masses are convex hulls of noise-displaced ellipsoid point clouds with
big planar fracture facets and a light chamfer on the sharpest edges, flat-shaded; facets
facing up take the light stone swatch, undersides the dark one (painted light). Optional
smooth moss caps with a soft rim that tucks into the rock.

Sizes (footprint, studs): S 3-5, M 7-10, L 14-20. Ids: rock_boulder_<s|m|l>_<NN>.
Pivot at base centre; everything is cut flat at z=0 (half-buried look).
"""

import math

from generators import _rock_common as rc

NAME = "rock_boulder"
VERSION = 2
CATEGORY = "rock"
BUDGET = "rock"
COLLISION = {"fidelity": "Hull"}
CHECKS = {"min_masses": 2}
DEFAULT_VARIANTS = 9
HERO_VIEW = {"azimuth": -35, "elevation": 24}

SIZES = (("s", 3.0, 5.0), ("m", 7.0, 10.0), ("l", 14.0, 20.0))
SHAPES = ("dome", "tall", "table")
FAMILIES = ("granite", "stone", "warm")
MOSS = {(0, 2), (1, 0), (1, 2), (2, 0), (2, 1)}


def asset_id(i, params):
    return f"{NAME}_{params['size']}_{params['variant']:02d}"


def variants(n, seed):
    out = []
    for i in range(n):
        si, j = (i // 3) % 3, i % 3
        out.append({
            "size": SIZES[si][0],
            "variant": i // 9 * 3 + j + 1,
            "shape": SHAPES[j],
            "stone": FAMILIES[(si + j) % 3],
            "moss": (si, j) in MOSS,
            "seed": seed * 1000 + 300 + i,
        })
    return out


def build(b, p):
    rng = b.rng
    si = [s[0] for s in SIZES].index(p["size"])
    W = rng.uniform(SIZES[si][1], SIZES[si][2])
    cols = rc.STONES[p["stone"]]
    shape = p["shape"]

    # ---- main mass (primary form); small rocks skip the chamfer and use fewer points (cheap)
    ch = 0.0 if si == 0 else 0.08
    cha = 28 if si == 1 else 38  # large rocks: chamfer only the sharpest edges (budget)
    dn = -3 if si == 0 else 0
    if shape == "dome":
        rx, ry, rz = W * 0.36, W * 0.3, W * 0.3
        main = rc.boulder(rng, rx, ry, rz, n=13 + dn, noise=0.18, fractures=5, frac_depth=(0.74, 0.88), bury=0.3,
                          lean=(rng.uniform(-0.15, 0.15), 0.1), chamfer_frac=ch, chamfer_angle=cha)
    elif shape == "tall":
        rx, ry, rz = W * 0.27, W * 0.17, W * 0.42
        main = rc.boulder(rng, rx, ry, rz, n=12 + dn, noise=0.15, fractures=5, flat_top=0.18, top_tilt=0.45,
                          bury=0.2, lean=(rng.uniform(0.12, 0.22), rng.choice((-1, 1)) * rng.uniform(0.12, 0.25)),
                          yaw=rng.uniform(-0.5, 0.5), chamfer_frac=ch, chamfer_angle=cha, frac_z=(-0.1, 0.35),
                          frac_depth=(0.68, 0.82))
    else:  # table
        rx, ry, rz = W * 0.4, W * 0.33, W * 0.22
        main = rc.boulder(rng, rx, ry, rz, n=14 + dn, noise=0.15, fractures=4, flat_top=0.25, bury=0.22,
                          lean=(rng.uniform(-0.1, 0.1), rng.uniform(-0.12, 0.12)), chamfer_frac=ch,
                          chamfer_angle=28)
    lo, hi = rc.bounds(main)
    H = hi.z
    moss_cols = rc.MOSS_COLS
    moss = []
    if p["moss"]:
        # thin moss plates that follow the rock: overlapping irregular patches on the sunny side
        moss = rc.moss_plates(main, rng, n=(2, 3, 3)[si], size=W * rng.uniform(0.13, 0.17), thick=max(0.05, 0.007 * W),
                              min_nz=0.5, z_frac=0.5 if shape != "table" else 0.65, sides=7)
    b.add(rc.to_piece(main, {rc.ROUGH: cols, rc.GROUND: cols[0]}, grad=("grange", 0.1, 1.0)), tag="mass")
    masses = 1
    for mp in moss:
        b.add(rc.to_piece(mp, moss_cols, grad=("range", 0.3, 1.0)), tag="moss")

    # ---- satellites (secondary forms), half-buried, leaning on the main mass
    nsat = {0: rng.choice((1, 2)), 1: 2, 2: 3}[si]
    a0 = -math.pi / 2 + rng.uniform(-1.0, 1.0)  # first (biggest) satellite on the front half
    ex, ey = (hi.x - lo.x) / 2, (hi.y - lo.y) / 2
    cx, cy = (hi.x + lo.x) / 2, (hi.y + lo.y) / 2
    R = max(ex, ey)
    for k in range(nsat):
        a = a0 + math.tau * k / nsat + rng.uniform(-0.4, 0.4)
        r = R * (rng.uniform(0.5, 0.62) if k == 0 else rng.uniform(0.28, 0.4))
        dist = math.hypot(ex * math.cos(a), ey * math.sin(a)) * (0.78 if k == 0 else 0.85) + r * 0.25
        sx, sy = cx + math.cos(a) * dist, cy + math.sin(a) * dist
        sat = rc.boulder(rng, r, r * rng.uniform(0.75, 0.95), r * rng.uniform(0.6, 0.8), n=11 + dn, noise=0.15,
                         fractures=3 if si else 2, frac_depth=(0.72, 0.86), bury=rng.uniform(0.3, 0.42), at=(sx, sy),
                         lean=(rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35)), chamfer_frac=ch,
                         chamfer_angle=28)
        if p["moss"] and si == 2 and k == 0:
            for mc in rc.moss_plates(sat, rng, n=1, size=r * 0.6, thick=0.1, min_nz=0.45, z_frac=0.4):
                b.add(rc.to_piece(mc, moss_cols, grad=("range", 0.3, 1.0)), tag="moss")
        b.add(rc.to_piece(sat, {rc.ROUGH: cols, rc.GROUND: cols[0]}, grad=("grange", 0.05, 0.9)), tag="mass")
        masses += 1

    # ---- accents: pebbles and grass tufts at the foot
    npeb = (1, 3, 3)[si]
    for k in range(npeb):
        a = rng.uniform(0, math.tau)
        dist = max(ex, ey) * rng.uniform(1.0, 1.3)
        r = W * rng.uniform(0.035, 0.06)
        b.add(rc.pebble(rng, cx + math.cos(a) * dist, cy + math.sin(a) * dist, r, cols), tag="pebble")
    ntuft = (1, 3, 3)[si]
    for k in range(ntuft):
        a = rng.uniform(0, math.tau)
        dist = math.hypot(ex * math.cos(a), ey * math.sin(a)) * rng.uniform(0.95, 1.1)
        b.add(rc.grass_tuft(rng, cx + math.cos(a) * dist, cy + math.sin(a) * dist, size=(0.55, 1.0, 1.5)[si],
                            blades=5), tag="grass")

    # ---- normalise: the cluster footprint (largest horizontal extent) hits the size class exactly
    xs = [v.x for pc in b.pieces for v in pc.verts]
    ys = [v.y for pc in b.pieces for v in pc.verts]
    k = W / max(max(xs) - min(xs), max(ys) - min(ys))
    k = min(k, SIZES[si][2] * (1.0 if si == 2 else 1.1) / max(1e-6, H))  # standing stones: cap the height too
    for pc in b.pieces:
        pc.scale(k)
    H *= k

    b.stats["masses"] = masses
    b.stats["height"] = round(H, 2)
    b.stats["pieces"] = len(b.pieces)
