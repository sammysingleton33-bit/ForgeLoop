"""Ore nodes: dark faceted rock clusters with bright ore. Iron (rust veins + nuggets), gold
(yellow veins + nuggets) and crystal (chunky hexagonal prisms), two variants each.

Veins are bands of the rock itself (the rock between two parallel planes, inflated so it
stands proud of the surface) wrapping diagonally round the mass; nuggets are small faceted
lumps half-sunk into the band; loose ore lies at the foot (or in a mine cart). The rock is
kept dark and cool so the ore colour pops at 60 studs; each ore type also has its own
shape cue (iron: chunky lumps + cart, gold: many small glints, crystal: spikes).

Front faces Blender -Y. Pivot at base centre, base cut flat at z=0.
Sockets: `harvest` (worker stands here), `hit` (ore surface the tool strikes).
Stats: harvest_radius (studs).
"""

import math

from lib import kit
from lib.geo import Matrix, Vector, box, cylinder, lathe, look_rot
from generators import _rock_common as rc

NAME = "resource_ore"
VERSION = 3
CATEGORY = "resource"
BUDGET = "resource"
COLLISION = {"fidelity": "Hull"}
CHECKS = {"min_ore_pieces": 5, "has_harvest_radius": 1}
DEFAULT_VARIANTS = 6
HERO_VIEW = {"azimuth": -32, "elevation": 22}

ORE = {
    # iron: dark rust-red ore on a lighter cool-grey rock (clear brightness gap, also in greyscale and
    # for protan/deutan viewers, who would otherwise see khaki close to the gold)
    "iron": {"rock": ("stone_cool_dark", "stone_cool", "stone_cool_light"),
             "ore": ("red_cloth_dark", "red_cloth_dark", "red_roof_dark"),
             "vein": ("red_cloth_dark", "red_cloth_dark", "red_roof_dark")},
    "gold": {"rock": ("slate_dark", "granite_dark", "granite"), "ore": ("gold", "ore_gold", "yellow_glow"),
             "vein": ("gold", "ore_gold", "yellow_glow")},
    "crystal": {"rock": ("slate_dark", "slate", "stone_cool_dark"), "ore": ("crystal", "crystal", "crystal"),
                "vein": ("crystal", "crystal", "crystal")},
}

PLANS = [
    {"ore": "iron", "shape": "mound", "prop": "stuck_pick", "scale": 1.0},
    {"ore": "iron", "shape": "ridge", "prop": "cart", "scale": 1.1},
    {"ore": "gold", "shape": "ridge", "prop": "none", "scale": 0.95},
    {"ore": "gold", "shape": "mound", "prop": "crate", "scale": 1.05},
    {"ore": "crystal", "shape": "mound", "prop": "none", "scale": 1.0},
    {"ore": "crystal", "shape": "ridge", "prop": "none", "scale": 1.1},
]


def variants(n, seed):
    out = []
    for i in range(n):
        p = dict(PLANS[i % len(PLANS)])
        p["seed"] = seed * 1000 + 700 + i
        out.append(p)
    return out


def _ground(bm):
    lo, _hi = rc.bounds(bm)
    if lo.z < 0:
        rc.cut(bm, (0, 0, 0), (0, 0, -1), tag=rc.GROUND)
    return bm


def nugget(rng, pos, normal, r, cols, sink=0.4, tall=1.0):
    bm = rc.hull(rc.ellipsoid_points(rng, 8, r, r * rng.uniform(0.7, 0.95), r * rng.uniform(0.6, 0.8) * tall, noise=0.2,
                                     seed=rng.uniform(0, 50)))
    n = Vector(normal).normalized()
    m = Matrix.Translation(Vector(pos) - n * r * sink) @ look_rot(n) @ Matrix.Rotation(rng.uniform(0, 6.3), 4, "Z")
    rc.transform(bm, m)
    return rc.to_piece(_ground(bm), {rc.ROUGH: cols, rc.GROUND: cols[0]}, grad=("range", 0.25, 1.0))


def chunk(rng, pos, normal, r, cols, sink=0.3, stretch=1.0):
    """Angular ore chunk (iron): a jittered, chamfered block hull pointing along `normal`."""
    pts = rc.block_points(rng, r * 1.6, r * 1.3, r * 1.4 * stretch, chamfer=r * 0.3, jitter=r * 0.18, base=False)
    bm = rc.hull(pts)
    n = Vector(normal).normalized()
    m = Matrix.Translation(Vector(pos) - n * r * sink) @ look_rot(n) @ Matrix.Rotation(rng.uniform(0, 6.3), 4, "Z") \
        @ Matrix.Rotation(rng.uniform(-0.3, 0.3), 4, "X")
    rc.transform(bm, m)
    return rc.to_piece(_ground(bm), {rc.ROUGH: cols, rc.GROUND: cols[0]}, grad=("range", 0.25, 1.0))


def lump(rng, pos, normal, r, cols, sink=0.15):
    """Round gold lump: a 12-point, nearly spherical faceted hull."""
    bm = rc.hull(rc.ellipsoid_points(rng, 12, r, r * rng.uniform(0.85, 1.0), r * rng.uniform(0.8, 0.95), noise=0.12,
                                     seed=rng.uniform(0, 50)))
    n = Vector(normal).normalized()
    rc.transform(bm, Matrix.Translation(Vector(pos) - n * r * sink) @ look_rot(n))
    return rc.to_piece(_ground(bm), {rc.ROUGH: cols, rc.GROUND: cols[0]}, grad=("range", 0.3, 1.0))


def crystal(rng, base, direction, r, h, color="crystal"):
    prof = [(r * 0.75, -0.8), (r, h * 0.08), (r * 0.96, h * 0.7), (r * 0.25, h * 0.97), (0.0, h)]
    pc = lathe(prof, 6, color, phase=rng.uniform(0, 1.0))
    pc.transform(look_rot(Vector(direction)))
    pc.move(*base)
    mz = min(v.z for v in pc.verts)
    if mz < 0:
        pc.move(0, 0, -mz)
    return pc.paint(grad=("range", 0.25, 1.0))


def _surface_points(rng, bm, count, front_bias=0.6, zmin=0.6, plane=None):
    """Points on the rock surface (ray cast from the centre), biased to the front/top; if
    `plane` = (n, d) the directions are kept near that plane (follow a vein band)."""
    c = rc.centroid(bm)
    out = []
    for _ in range(count * 6):
        if len(out) >= count:
            break
        a = rng.uniform(0, math.tau)
        d = Vector((math.cos(a), math.sin(a) - front_bias, rng.uniform(0.0, 1.0)))
        if plane is not None:
            n, _off = plane
            d = d - n * d.dot(n)
        if d.length < 1e-3:
            continue
        loc, nrm = rc.surface_from_centre(bm, d.normalized(), c)
        if loc is None or loc.z < zmin:
            continue
        out.append((loc, nrm))
    return out


def build(b, p):
    rng = b.rng
    S = p["scale"]
    ore = p["ore"]
    cfg = ORE[ore]
    rock, orec, veinc = cfg["rock"], cfg["ore"], cfg["vein"]

    # ---- rock cluster (primary)
    if p["shape"] == "mound":
        rx, ry, rz = 5.0 * S, 4.2 * S, 4.2 * S
        main = rc.boulder(rng, rx, ry, rz, n=15, noise=0.16, fractures=4, frac_depth=(0.75, 0.88), bury=0.3,
                          chamfer_frac=0.07, chamfer_angle=30, lean=(0.1, 0.0), yaw=rng.uniform(-0.4, 0.4))
    else:
        rx, ry, rz = 6.2 * S, 3.6 * S, 4.6 * S
        main = rc.boulder(rng, rx, ry, rz, n=15, noise=0.16, fractures=4, frac_depth=(0.72, 0.86), bury=0.25,
                          chamfer_frac=0.07, chamfer_angle=30, lean=(0.12, rng.uniform(-0.2, 0.2)),
                          yaw=rng.uniform(-0.25, 0.25), flat_top=0.12, top_tilt=0.4)
    lo, hi = rc.bounds(main)
    c = rc.centroid(main)
    H = hi.z
    sats = []
    for k in range(2):
        a = (-0.35 if k == 0 else 0.55) * math.pi + rng.uniform(-0.35, 0.35)
        r = rx * (0.48 if k == 0 else 0.36) * rng.uniform(0.9, 1.1)
        ex, ey = (hi.x - lo.x) / 2, (hi.y - lo.y) / 2
        dist = math.hypot(ex * math.cos(a), ey * math.sin(a)) * 0.8 + r * 0.3
        sat = rc.boulder(rng, r, r * 0.85, r * 0.75, n=11, noise=0.16, fractures=2, bury=0.38,
                         at=(c.x + math.cos(a) * dist, c.y + math.sin(a) * dist), chamfer_frac=0.07,
                         chamfer_angle=30, lean=(rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3)))
        sats.append(sat)

    ore_pieces = 0
    hit = None
    # ---- iron: chunky RAISED flat bands of dark rust-red ore across the front (the rock's own
    # surface inside long irregular polygons, lifted ~0.45 studs) + one big angular chunk jutting
    # out of the top (breaks the outline). gold: a few BIG ROUND lumps sitting high on the rock so
    # they break the silhouette, and smaller ones on the front. (Crystal = spikes, below.)
    if ore == "iron":
        k = 1.0 + 0.45 / max(rx, ry)
        tilt = rng.choice((-1, 1)) * rng.uniform(0.35, 0.6)
        for ci in range(3):
            u = (ci - 1) / 2.0
            ang = -math.pi / 2 + u * 1.9 + rng.uniform(-0.12, 0.12)
            d = Vector((math.cos(ang), math.sin(ang), 0.25 + u * tilt * 2.0 + rng.uniform(-0.1, 0.1)))
            loc, nrm = rc.surface_from_centre(main, d, c)
            if loc is None or loc.z < 0.6:
                continue
            L = Vector((-math.sin(ang), math.cos(ang), tilt)).normalized()
            L = (L - nrm * L.dot(nrm)).normalized()
            A = nrm.cross(L).normalized()
            plate = main.copy()
            rc.transform(plate, Matrix.Translation(c) @ Matrix.Scale(k, 4) @ Matrix.Translation(-c))
            along, across = rng.uniform(2.0, 2.7) * S, rng.uniform(0.6, 0.85) * S
            for dv, dist in ((L, along), (-L, along * rng.uniform(0.8, 1.1)), (A, across), (-A, across * rng.uniform(0.8, 1.2)),
                             ((L + A).normalized(), (along + across) * 0.55), ((-L - A).normalized(), (along + across) * 0.5),
                             ((L - A).normalized(), (along + across) * 0.6), ((A - L).normalized(), (along + across) * 0.55)):
                dv = (dv + nrm * rng.uniform(-0.15, 0.15)).normalized()
                rc.cut(plate, loc + dv * dist, dv, tag=rc.VEIN)
            rc.cut(plate, loc - nrm * 1.2 * S, -nrm, tag=rc.VEIN)
            if plate.faces:
                _ground(plate)
                b.add(rc.to_piece(plate, {rc.ROUGH: veinc, rc.VEIN: veinc[0], rc.GROUND: veinc[0]},
                                  grad=("range", 0.4, 1.0)), tag="ore")
                ore_pieces += 1
                if hit is None or loc.y < hit.y:
                    hit = loc.copy()
            else:
                plate.free()
        loc, nrm = rc.surface_from_centre(main, Vector((rng.uniform(-0.4, 0.4), -0.35, 1.0)), c)
        if loc is not None:  # the big jutting chunk
            b.add(chunk(rng, loc, (nrm + Vector((0, 0, 0.6))).normalized(), 1.25 * S, orec, sink=0.25, stretch=1.5),
                  tag="ore")
            ore_pieces += 1
        sat = sats[0]  # and a chunk breaking out of the big satellite
        sc = rc.centroid(sat)
        loc, nrm = rc.surface_from_centre(sat, Vector((0.2, -0.8, 1.0)), sc)
        if loc is not None:
            b.add(chunk(rng, loc, nrm, 0.75 * S, orec, sink=0.3), tag="ore")
            ore_pieces += 1
    elif ore == "gold":
        tops = []
        for q in range(14):
            a = -math.pi / 2 + rng.uniform(-1.3, 1.3)
            d = Vector((math.cos(a) * 0.6, math.sin(a) * 0.6, rng.uniform(0.6, 1.0)))
            loc, nrm = rc.surface_from_centre(main, d, c)
            if loc is None or any((loc - t).length < 2.0 * S for t, _n in tops):
                continue
            tops.append((loc, nrm))
            if len(tops) >= 3:
                break
        for loc, nrm in tops:  # big round lumps sitting high: they break the outline
            b.add(lump(rng, loc, (nrm + Vector((0, 0, 0.6))).normalized(), rng.uniform(1.2, 1.55) * S, orec, sink=0.08),
                  tag="ore")
            ore_pieces += 1
            if hit is None or loc.y < hit.y:
                hit = loc.copy()
        for loc, nrm in _surface_points(rng, main, 2, front_bias=1.2, zmin=1.0):
            b.add(lump(rng, loc, nrm, rng.uniform(0.6, 0.8) * S, orec, sink=0.25), tag="ore")
            ore_pieces += 1
        sat = sats[0]
        sc = rc.centroid(sat)
        loc, nrm = rc.surface_from_centre(sat, Vector((0.2, -0.6, 1.0)), sc)
        if loc is not None:
            b.add(lump(rng, loc, nrm, 0.75 * S, orec, sink=0.2), tag="ore")
            ore_pieces += 1
    else:
        # ---- crystal clusters sprouting from the rock
        nclusters = 3 if p["shape"] == "mound" else 4
        pts = _surface_points(rng, main, nclusters, front_bias=0.5, zmin=1.2)
        for ci, (loc, nrm) in enumerate(pts):
            big = ci == 0
            nc = rng.randint(4, 5) if big else rng.randint(2, 4)
            for j in range(nc):
                fan = Vector((math.cos(j * 2.4 + ci), math.sin(j * 2.4 + ci), 0)) * (0.0 if j == 0 else 0.75)
                d = (nrm * 0.9 + Vector((0, 0, 0.8)) + fan).normalized()
                h = (rng.uniform(3.8, 5.6) if (big and j == 0) else rng.uniform(1.8, 3.6)) * S
                r = h * rng.uniform(0.13, 0.17)
                base = loc + Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), 0)) * S - nrm * 0.25
                b.add(crystal(rng, base, d, r, h), tag="ore")
                ore_pieces += 1
            if hit is None or loc.y < hit.y:
                hit = loc.copy()
        # crystals pushing out of the ground beside the rock
        for j in range(3):
            a = -math.pi / 2 + rng.uniform(-1.4, 1.4)
            gx, gy = c.x + math.cos(a) * (rx * 1.05), c.y + math.sin(a) * (ry * 1.1)
            d = Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, 1.0)).normalized()
            h = rng.uniform(1.4, 2.4) * S
            b.add(crystal(rng, (gx, gy, 0.0), d, h * 0.2, h), tag="ore")
            ore_pieces += 1

    pick_spot = rc.surface_from_centre(main, Vector((0.35, -0.3, 1.0)), c)
    b.add(rc.to_piece(main, {rc.ROUGH: rock, rc.GROUND: rock[0]}, grad=("grange", 0.05, 0.95)), tag="mass")
    for sat in sats:
        b.add(rc.to_piece(sat, {rc.ROUGH: rock, rc.GROUND: rock[0]}, grad=("grange", 0.05, 0.85)), tag="mass")

    # ---- loose ore heaped at one side (not in front: the front is the worker's spot), gravel, tufts
    front_y = lo.y
    prop = p["prop"]
    hs = rng.choice((-1, 1))
    hxp, hyp = c.x + hs * (rx * 1.05 + 1.0), c.y - ry * 0.35
    if ore == "crystal":
        for j in range(3):
            h = rng.uniform(1.0, 1.6)
            pc = crystal(rng, (hxp + rng.uniform(-0.7, 0.7), hyp + rng.uniform(-0.7, 0.7), 0.0),
                         Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), 1.0)).normalized(), h * 0.22, h)
            b.add(pc, tag="ore")
            ore_pieces += 1
    elif prop not in ("cart", "crate"):
        for j in range(7):  # a spill of ore at the base: chunky (iron) / round (gold)
            ring = 0 if j == 0 else 1
            a = j * math.tau / 6 + rng.uniform(-0.3, 0.3)
            px_, py_ = hxp + math.cos(a) * 0.95 * ring, hyp + math.sin(a) * 0.95 * ring
            rr = rng.uniform(0.55, 0.75) if ring else 0.8
            pos = Vector((px_, py_, 0.75 if ring == 0 else 0.25))
            if ore == "iron":
                b.add(chunk(rng, pos, Vector((0, 0, 1)), rr * 0.8, orec, sink=0.2), tag="ore")
            else:
                b.add(lump(rng, pos, Vector((0, 0, 1)), rr * 0.8, orec, sink=0.2), tag="ore")
            ore_pieces += 1
    for j in range(3):
        a = rng.uniform(0, math.tau)
        b.add(rc.pebble(rng, c.x + math.cos(a) * rx * 1.15, c.y + math.sin(a) * ry * 1.2, rng.uniform(0.25, 0.45),
                        rock, n=7), tag="pebble")
    for j in range(3):
        a = rng.uniform(0, math.tau)
        b.add(rc.grass_tuft(rng, c.x + math.cos(a) * rx * 0.95, c.y + math.sin(a) * ry * 0.95, size=1.0), tag="grass")

    # ---- props
    prop = p["prop"]
    hx = c.x - rx * 0.15
    if prop == "stuck_pick":
        # a pick left bitten into the top of the rock (not leaning in front like the other nodes)
        loc, nrm = pick_spot
        if loc is not None:
            out_dir = (nrm + Vector((0.3, -0.2, 0.6))).normalized()
            b.add(rc.pickaxe(loc + out_dir * 3.3, loc - nrm * 0.1, side=(0, 1, 0)), tag="tool")
    elif prop == "cart":
        # big wooden mine cart heaped with dark ore chunks (reads at 60 studs)
        cx, cy = c.x + rx * 1.05, front_y - 1.2
        body = kit.bbox(4.2, 2.9, 2.0, "wood", 0.12).move(0, 0, 0.9)
        parts = [body]
        for zz in (1.1, 2.55):
            parts.append(box(4.3, 3.0, 0.22, "iron_dark").move(0, 0, zz))
        for sx in (-1, 1):
            for sy in (-1, 1):
                w = cylinder(0.75, 0.75, 0.3, 8, "iron_dark").rotate(math.pi / 2, "X")
                parts.append(w.move(sx * 1.35, sy * 1.6, 0.75))
        for pc in parts:
            pc.rotate(0.35, "Z").move(cx, cy, 0)
            b.add(pc, tag="cart")
        for j in range(5):
            u = Vector((rng.uniform(-1.3, 1.3), rng.uniform(-0.8, 0.8), 0))
            u.rotate(Matrix.Rotation(0.35, 3, "Z"))
            heap = 0.35 if abs(u.x) < 0.7 else 0.0
            b.add(chunk(rng, Vector((cx + u.x, cy + u.y, 2.85 + heap)), Vector((0, 0, 1)), rng.uniform(0.5, 0.65), orec,
                        sink=0.3), tag="ore")
            ore_pieces += 1
        hx = c.x - rx * 0.25
    elif prop == "crate":
        cx, cy = c.x + rx * 1.0, front_y - 1.0
        crate = kit.bbox(2.9, 2.5, 1.8, "wood_light", 0.12).rotate(-0.3, "Z").move(cx, cy, 0)
        b.add(crate, tag="crate")
        for sx in (-1, 1):  # iron bands on the crate
            b.add(box(3.0, 2.6, 0.18, "iron_dark").rotate(-0.3, "Z").move(cx, cy, 0.5 + (sx + 1) * 0.4), tag="crate")
        for j in range(3):
            b.add(lump(rng, Vector((cx + rng.uniform(-0.7, 0.7), cy + rng.uniform(-0.6, 0.6), 2.0)),
                       Vector((0, 0, 1)), rng.uniform(0.55, 0.7), orec, sink=0.35), tag="ore")
            ore_pieces += 1

    b.socket("harvest", hx, front_y - 2.5, 0.0)
    if hit is None:
        hit = Vector((hx, front_y, H * 0.4))
    b.socket("hit", hit.x, hit.y, hit.z)
    b.stats["ore_pieces"] = ore_pieces
    b.stats["harvest_radius"] = round(max(hi.x - lo.x, hi.y - lo.y) / 2 + 2.5, 1)
    rc.rest_on_ground(b)
    b.stats["pieces"] = len(b.pieces)
