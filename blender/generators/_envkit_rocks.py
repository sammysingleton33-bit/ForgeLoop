"""Environment kit: boulders (S / M / L), cliff rocks and the resource-node meshes (stone quarry, ore, wood), style B.

A rock is a few faceted lumps (convex hulls of jittered super-ellipsoid points, flat bottoms sunk a little into the ground), stacked and
tipped like the part-built stand-ins (Kit/Props.lua `boulder`: S two lumps, M a dark lump under a lighter one plus a pebble, L a foot,
a mid mass, a leaning lump and moss), coloured cool and dark at the foot, warm and light on top, with per-facet noise, strata and moss
patches so a stand of boulders is never one repeated shape. Resource nodes read by colour first: stone = pale strata + cut blocks, ore =
a dark host rock studded with bright nuggets (iron rust, gold) or crystals, wood = a log pile and a chopped stump with its axe.
"""

import math

from generators import _envkit_style as S
from lib.ckit import M, merge


def lump(rng, rx, ry, rz, x=0.0, z=0.0, bottom=-0.35, n=16, jitter=0.15, tilt=(0.0, 0.0), yaw=None, sharp=2.7, flat_bottom=True, color=S.ROCK_MID):
    """One faceted rock mass standing with its lowest point at y = `bottom`, centred on (x, z)."""
    yaw = rng.uniform(0, math.tau) if yaw is None else yaw
    pts = []
    golden = math.pi * (3 - math.sqrt(5))
    e = 2.0 / sharp
    for i in range(n):
        y = 1 - 2 * (i + 0.5) / n
        r = math.sqrt(max(0.0, 1 - y * y))
        a = i * golden + rng.uniform(-0.12, 0.12)
        ux, uy, uz = math.cos(a) * r, y, math.sin(a) * r
        sx = math.copysign(abs(ux) ** e, ux)
        sy = math.copysign(abs(uy) ** e, uy)
        sz = math.copysign(abs(uz) ** e, uz)
        k = 1.0 + rng.uniform(-jitter, jitter)
        pts.append((sx * rx * k, sy * ry * k, sz * rz * k))
    if flat_bottom:
        pts = [(p[0], max(p[1], -ry * 0.62), p[2]) for p in pts]
    m = S.flat(S.hull(pts, color=color, smooth=False, tag="rock"), "rock")
    if tilt[0]:
        m.rot(math.degrees(tilt[0]), "x")
    if tilt[1]:
        m.rot(math.degrees(tilt[1]), "z")
    m.rot(math.degrees(yaw), "y")
    lo = m.bounds()[0][1]
    return m.move(x, bottom - lo, z)


def paint_rock(m, rng, y0, y1, warm=0.0, moss=0.0, ramp=None, noise=0.10, strata=0.0):
    """Colour a rock mass: height ramp (cool dark foot to warm light top), up-facing faces lighter, per-facet noise, optional strata bands and moss."""
    stops = ramp or S.ROCK_RAMP
    stops = [S.mix(c, S.ROCK_WARM, warm) for c in stops] if warm else stops
    for i, f in enumerate(m.f):
        c = S.centroid(m, f)
        n = S.face_normal(m, f)
        h = (c[1] - y0) / max(1e-6, y1 - y0)
        band = strata * (0.5 - abs((h * 3.0) % 1.0 - 0.5)) if strata else 0.0
        t = 0.45 * h + 0.35 * (0.5 + 0.5 * n[1]) + rng.uniform(-noise, noise) + 0.1 + band
        col = S.ramp(stops, t)
        if moss and n[1] > 0.55 and h > 0.45 and rng.random() < moss:
            col = S.mix(col, S.MOSS, rng.uniform(0.7, 1.0))
        m.c[i] = col
    return m


def _stack(rng, specs, warm=0.0, moss=0.0, strata=0.0):
    """Build lumps from specs [(rx, ry, rz, x, z, bottom, kw)], paint them against one shared height range, merge."""
    lumps = [lump(rng, rx, ry, rz, x, z, bottom, **kw) for rx, ry, rz, x, z, bottom, kw in specs]
    y0 = min(m.bounds()[0][1] for m in lumps)
    y1 = max(m.bounds()[1][1] for m in lumps)
    for m in lumps:
        paint_rock(m, rng, y0, y1, warm=warm, moss=moss, strata=strata)
    return lumps


# ------------------------------------------------------------------ boulders

def boulder(size, variant, rng):
    """rock_boulder_{s,m,l}_NN. The three variants of a size differ in structure (pair / slab / cairn), not only in scale."""
    k = rng.uniform(0.94, 1.08)
    a = rng.uniform(0, math.tau)
    tilt = lambda mag: mag * rng.uniform(0.75, 1.15) * (1 if rng.random() < 0.5 else -1)  # noqa: E731
    warm = [0.0, 0.35, 0.15][(variant - 1) % 3]
    if size == "s":
        shape = ["pair", "slab", "cairn"][(variant - 1) % 3]
        if shape == "pair":
            specs = [(2.5 * k, 1.5, 2.1 * k, -0.4, 0.0, -0.4, dict(n=16, tilt=(tilt(0.22), tilt(0.2)))),
                     (1.8 * k, 1.35, 1.55 * k, 1.6, 0.9, -0.3, dict(n=14, tilt=(tilt(0.3), tilt(0.3)), color=S.ROCK_TOP))]
        elif shape == "slab":
            specs = [(3.2 * k, 1.2, 2.3 * k, 0.0, 0.0, -0.4, dict(n=16, sharp=3.4, tilt=(tilt(0.12), tilt(0.18)))),
                     (1.3 * k, 1.0, 1.1 * k, 2.4, 1.3, -0.3, dict(n=12, tilt=(tilt(0.3), tilt(0.3))))]
        else:
            specs = [(2.0 * k, 1.6, 1.8 * k, -0.7, 0.2, -0.4, dict(n=14)), (1.6 * k, 1.3, 1.4 * k, 1.5, -0.5, -0.35, dict(n=12, tilt=(tilt(0.3), 0.0))),
                     (1.2 * k, 1.0, 1.1 * k, 0.4, 1.6, -0.3, dict(n=12, tilt=(0.0, tilt(0.3))))]
        lumps = _stack(rng, specs, warm=warm, moss=0.25 if variant == 2 else 0.0)
    elif size == "m":
        shape = ["stack", "wedge", "cluster"][(variant - 1) % 3]
        pa = a + rng.uniform(2.2, 4.0)
        if shape == "stack":
            specs = [(3.5 * k, 1.9, 2.9 * k, 0.0, 0.0, -0.4, dict(n=18, tilt=(tilt(0.2), tilt(0.2)))),
                     (2.4 * k, 1.8, 1.9 * k, 0.5, -0.3, 1.1, dict(n=16, tilt=(tilt(0.3), tilt(0.28)), color=S.ROCK_TOP))]
        elif shape == "wedge":
            specs = [(3.3 * k, 2.6, 2.6 * k, 0.0, 0.0, -0.4, dict(n=18, sharp=3.0, tilt=(tilt(0.3), tilt(0.14)))),
                     (1.8 * k, 1.4, 1.5 * k, -1.8, 1.0, 1.0, dict(n=12, tilt=(tilt(0.3), tilt(0.3))))]
        else:
            specs = [(2.6 * k, 2.0, 2.4 * k, -1.0, 0.3, -0.4, dict(n=16)), (2.3 * k, 1.9, 2.0 * k, 1.8, -0.6, -0.4, dict(n=16, tilt=(tilt(0.25), tilt(0.25)))),
                     (1.7 * k, 1.5, 1.5 * k, 0.4, 0.2, 1.2, dict(n=14, tilt=(tilt(0.3), tilt(0.3))))]
        specs.append((0.95, 0.7, 0.9, math.cos(pa) * 4.2, math.sin(pa) * 4.2, -0.25, dict(n=10, tilt=(0.3, 0.3))))
        lumps = _stack(rng, specs, warm=warm, moss=0.35 if variant == 3 else 0.0)
    else:  # l
        shape = ["massif", "spire", "ledge"][(variant - 1) % 3]
        g = 1.0
        if shape == "massif":
            specs = [(6.4 * k, 2.1, 5.2 * k, 0.0, 0.0, -0.45, dict(n=24, sharp=2.9, tilt=(tilt(0.12), tilt(0.1)))),
                     (4.1 * k, 2.6, 3.4 * k, -0.9, 0.7, 1.2, dict(n=22, sharp=2.9, tilt=(tilt(0.28), tilt(0.24)))),
                     (2.9 * k, 1.9, 2.5 * k, math.cos(a + 2.6) * 6.4, math.sin(a + 2.6) * 6.4, -0.4, dict(n=16, tilt=(tilt(0.3), tilt(0.3)), color=S.ROCK_TOP))]
        elif shape == "spire":
            specs = [(5.4 * k, 2.2, 4.6 * k, 0.0, 0.0, -0.45, dict(n=22, sharp=2.9, tilt=(tilt(0.12), tilt(0.1)))),
                     (2.8 * k, 4.2, 2.6 * k, 0.6, 0.2, 0.6, dict(n=20, sharp=3.2, tilt=(tilt(0.12), tilt(0.14)))),
                     (3.0 * k, 1.9, 2.5 * k, math.cos(a + 2.2) * 6.0, math.sin(a + 2.2) * 6.0, -0.4, dict(n=16, tilt=(tilt(0.3), tilt(0.3)))),
                     (2.0 * k, 1.5, 1.8 * k, math.cos(a - 1.0) * 6.8, math.sin(a - 1.0) * 6.8, -0.4, dict(n=14, tilt=(tilt(0.3), tilt(0.3))))]
        else:
            specs = [(6.0 * k, 2.0, 4.6 * k, 0.0, 0.0, -0.45, dict(n=22, sharp=3.2, tilt=(tilt(0.1), tilt(0.1)))),
                     (4.6 * k, 1.9, 3.4 * k, -0.6, 0.4, 1.2, dict(n=20, sharp=3.2, tilt=(tilt(0.14), tilt(0.2)))),
                     (3.2 * k, 1.8, 2.5 * k, 0.2, 0.0, 2.7, dict(n=16, sharp=3.0, tilt=(tilt(0.2), tilt(0.2)), color=S.ROCK_TOP)),
                     (2.8 * k, 1.8, 2.4 * k, math.cos(a + 2.7) * 6.8, math.sin(a + 2.7) * 6.8, -0.4, dict(n=14, tilt=(tilt(0.3), tilt(0.3))))]
        lumps = _stack(rng, specs, warm=warm, moss=0.5, strata=0.18 if shape == "ledge" else 0.0)
    return merge(*lumps), {"shape": shape, "lumps": len(lumps)}


def cliff(variant, rng):
    """rock_cliff_NN (a spare: the world does not place it yet): a tall stack of leaning slabs, taller than the L boulder."""
    k = rng.uniform(0.95, 1.08)
    a = rng.uniform(0, math.tau)
    tilt = lambda mag: mag * rng.uniform(0.75, 1.15) * (1 if rng.random() < 0.5 else -1)  # noqa: E731
    specs = [(5.6 * k, 2.4, 4.6 * k, 0.0, 0.0, -0.45, dict(n=22, sharp=3.1, tilt=(tilt(0.1), tilt(0.1)))),
             (4.0 * k, 3.6, 3.2 * k, -0.8, 0.6, 1.3, dict(n=22, sharp=3.2, tilt=(tilt(0.14), tilt(0.14)))),
             (2.6 * k, 3.2, 2.2 * k, -0.2, 0.2, 4.8, dict(n=18, sharp=3.2, tilt=(tilt(0.16), tilt(0.16)), color=S.ROCK_TOP)),
             (2.8 * k, 2.2, 2.4 * k, math.cos(a + 2.4) * 5.6, math.sin(a + 2.4) * 5.6, -0.4, dict(n=16, tilt=(tilt(0.3), tilt(0.3))))]
    lumps = _stack(rng, specs, warm=0.1 * variant, moss=0.35, strata=0.15)
    return merge(*lumps), {"lumps": len(lumps)}


# ------------------------------------------------------------------ resource nodes

def _block(rng, w, h, d, x, y, z, color, yaw=0.0, chip=0.12, tag="stone"):
    """A chipped block: the hull of a box's eight corners, each nudged a little (flat cut faces, slightly irregular), bottom at y - h/2."""
    pts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                pts.append((sx * w / 2 * (1 + rng.uniform(-chip, chip)), sy * h / 2 * (1 + rng.uniform(-chip * 0.5, chip * 0.5)),
                            sz * d / 2 * (1 + rng.uniform(-chip, chip))))
    m = S.flat(S.hull(pts, color=color, smooth=False, tag=tag), tag)
    m.rot(math.degrees(yaw), "y")
    return m.move(x, y, z)


def quarry(variant, rng):
    """resource_stone_NN: three stepped strata (dark, pale, mid), rubble down one side, two dressed blocks and a pick, as the stand-in's layout."""
    mir = -1.0 if variant == 2 else 1.0
    order = [(S.ROCK_BASE, S.STONE_LIGHT, S.ROCK_MID), (S.STONE_LIGHT, S.ROCK_BASE, S.ROCK_TOP), (S.ROCK_MID, S.STONE_LIGHT, S.ROCK_BASE)][(variant - 1) % 3]
    sizes = [(11.0, 2.7, 9.0), (9.0, 2.5, 7.4), (6.6, 2.3, 5.4)]
    offs = [(0.0, 1.0, 0.0), (-0.6, 3.8, 0.5), (-1.2, 6.1, -0.4)]
    parts = []
    for i in range(3):
        w, h, d = sizes[i]
        x, y, z = offs[i]
        # two sub-blocks per stratum so the quarry face steps and chips instead of reading as three plain slabs
        for sub in range(2):
            off = (sub - 0.5) * w * 0.12
            parts.append(_block(rng, w * (0.62 + 0.1 * sub), h + 0.25 * sub, d * (0.95 - 0.1 * sub), (x + off) * mir, y + 0.1 * sub, z + rng.uniform(-0.3, 0.3),
                                order[i], yaw=rng.uniform(-0.16, 0.16), chip=0.1))
    # rubble down the +x side
    for k in range(5):
        r = rng.uniform(0.7, 1.5)
        parts.append(lump(rng, r * 1.2, r, r * 1.1, (6.2 + rng.uniform(-0.2, 2.4)) * mir, rng.uniform(-2.2, 2.6), -0.3, n=10, tilt=(rng.uniform(-.4, .4), rng.uniform(-.4, .4)),
                          color=S.ROCK_MID))
    # dressed blocks, one on the other
    parts.append(_block(rng, 3.0, 1.7, 2.4, -6.2 * mir, 0.55, -4.6, S.STONE_LIGHT, yaw=rng.uniform(-0.15, 0.15), chip=0.04, tag="cut"))
    parts.append(_block(rng, 2.8, 1.6, 2.2, -6.0 * mir, 2.15, -4.5, S.mul(S.STONE_LIGHT, 0.94), yaw=rng.uniform(0.2, 0.4), chip=0.04, tag="cut"))
    # the pick leaning on the front
    handle = S.flat(S.slab([(-0.15, -0.15), (0.15, -0.15), (0.15, 0.15), (-0.15, 0.15)], 0.0, 3.4, S.WOOD, tag="pick")).rot(28, "z").move(-4.2 * mir, 0.0, -5.1)
    head = S.flat(S.slab([(-0.9, -0.12), (0.9, -0.12), (0.9, 0.12), (-0.9, 0.12)], 0.0, 0.5, S.IRON, tag="pick")).move(-4.2 * mir - 1.5, 2.9, -5.1)
    parts += [handle, head]
    # paint the stone parts by height (a shared ramp), keep tools as built
    stone_parts = [p for p in parts if p.k and p.k[0] in ("stone", "cut", "rock")]
    y0, y1 = 0.0, 7.5
    for p in stone_parts:
        base = p.c[0]
        for i, f in enumerate(p.f):
            c = S.centroid(p, f)
            n = S.face_normal(p, f)
            t = 0.55 + 0.35 * (c[1] / y1) + 0.18 * n[1] + rng.uniform(-0.05, 0.05)
            p.c[i] = S.mul(base, min(1.12, max(0.8, t)))
    return merge(*parts), {"stones": variant}


def ore(variant, rng):
    """resource_ore_NN: a dark host rock (three chunks and a pebble) studded with five bright nuggets: 01-02 iron (rust), 03-04 gold, 05-06 crystal."""
    kind = "iron" if variant <= 2 else "gold" if variant <= 4 else "crystal"
    col = {"iron": S.IRON_ORE, "gold": S.GOLD_ORE, "crystal": S.CRYSTAL}[kind]
    yaw = rng.uniform(0, math.tau)
    k = rng.uniform(0.95, 1.06)
    specs = [(4.1 * k, 1.9, 3.4 * k, 0.3, 0.0, -0.4, dict(n=20, tilt=(0.2, -0.18), yaw=yaw, sharp=3.0)),
             (2.5 * k, 2.2, 2.2 * k, 0.1, -0.2, 1.6, dict(n=18, tilt=(0.35, -0.3), yaw=yaw + 0.7, sharp=2.9)),
             (1.8 * k, 1.5, 1.6 * k, -4.2 * math.cos(yaw), -4.2 * math.sin(yaw), -0.4, dict(n=14, tilt=(0.3, 0.34))),
             (1.0, 0.8, 0.9, math.cos(yaw + 2.4) * 6.0, math.sin(yaw + 2.4) * 6.0, -0.3, dict(n=10, tilt=(0.5, 0.4)))]
    lumps = _stack(rng, specs, warm=-0.0)
    for m in lumps:  # the host is darker than a boulder so the nuggets carry the colour
        for i in range(len(m.f)):
            m.c[i] = S.mul(m.c[i], 0.78)
    parts = list(lumps)
    for i in range(5):
        a = yaw + (i + 1) * 1.25 + rng.uniform(-0.2, 0.2)
        r = 2.6 + (i % 2) * 0.5
        y = 2.6 + (i % 3) * 1.1
        px, pz = math.cos(a) * r, math.sin(a) * r
        if kind == "crystal":
            hgt = rng.uniform(2.6, 4.2)
            seg = 6
            ring = [(math.cos(math.tau * j / seg) * 0.62, 0.0, math.sin(math.tau * j / seg) * 0.62) for j in range(seg)]
            top = [(p[0] * 0.55, hgt * 0.78, p[2] * 0.55) for p in ring]
            v = ring + top + [(0.0, hgt, 0.0)]
            f = [(j, (j + 1) % seg, seg + (j + 1) % seg, seg + j) for j in range(seg)] + [(seg + j, seg + (j + 1) % seg, 2 * seg) for j in range(seg)]
            f.append(tuple(reversed(range(seg))))
            cr = M(v, f, color=col, smooth=False, tag="crystal").fix_winding()
            for fi, face in enumerate(cr.f):
                cy = sum(cr.v[q][1] for q in face) / len(face)
                cr.c[fi] = S.mix(S.mul(col, 0.78), S.mix(col, (1, 1, 1), 0.35), min(1.0, cy / hgt + rng.uniform(-0.1, 0.1)))
            cr.rot(rng.uniform(-30, 30), "x").rot(rng.uniform(-30, 30), "z").move(px, y - 0.6, pz)
            parts.append(S.flat(cr))
        else:
            nug = S.blob(rng, 9, 1.25, 0.95, 1.1, px, y, pz, jitter=0.14, color=col, tag="ore", yaw=rng.uniform(0, math.tau))
            for fi, face in enumerate(nug.f):
                n = S.face_normal(nug, face)
                nug.c[fi] = S.mix(S.mul(col, 0.72), S.mix(col, (1, 1, 1), 0.28 if kind == "gold" else 0.18), min(1.0, 0.5 + 0.5 * n[1] + rng.uniform(-0.15, 0.15)))
            parts.append(nug)
    return merge(*parts), {"kind": kind}


def _log(rng, x, y, z, length, r, yaw_deg, bark=S.BARK):
    """A six-sided log along x (rotated by yaw): bark sides, pale cut ends."""
    seg = 6
    ring = [(math.cos(math.tau * j / seg) * r, math.sin(math.tau * j / seg) * r) for j in range(seg)]
    v = [(-length / 2, p[0], p[1]) for p in ring] + [(length / 2, p[0], p[1]) for p in ring]
    f = [(j, (j + 1) % seg, seg + (j + 1) % seg, seg + j) for j in range(seg)] + [tuple(reversed(range(seg))), tuple(seg + j for j in range(seg))]
    m = M(v, f, color=bark, smooth=False, tag="log").fix_winding()
    for i, face in enumerate(m.f):
        if len(face) == 6:
            m.c[i] = S.WOOD_LIGHT
        else:
            m.c[i] = S.mul(bark, rng.uniform(0.9, 1.1))
    m.rot(yaw_deg, "y").move(x, y, z)
    return S.flat(m)


def wood(variant, rng):
    """resource_wood_NN (a spare: the world's wood nodes are trees): five logs with pale cut ends, a chopped stump with its axe stuck in."""
    rows = [(-1.8, 0.0), (0.0, 0.15), (1.8, -0.2), (-0.9, 1.5), (0.9, 1.5)]
    parts = []
    for i, (x, z) in enumerate(rows):
        y = 0.85 if i < 3 else 2.35
        parts.append(_log(rng, x, y, z, 6.2 + rng.uniform(-0.4, 0.4), 0.88, 90.0 + rng.uniform(-3, 3)))
    stump = S.flat(S.cyl(1.4, 1.2, 1.7, seg=7, y0=0.0, color=S.BARK, smooth=False, tag="stump")).move(5.0, 0.0, 2.6)
    for i, f in enumerate(stump.f):
        if len(f) == 7 and S.face_normal(stump, f)[1] > 0.9:
            stump.c[i] = S.WOOD_LIGHT
    parts.append(stump)
    handle = S.flat(S.slab([(-0.14, -0.14), (0.14, -0.14), (0.14, 0.14), (-0.14, 0.14)], 0.0, 2.6, S.WOOD, tag="axe")).rot(rng.uniform(18, 28), "z").move(5.5, 1.6, 2.6)
    head = S.flat(S.slab([(-0.55, -0.11), (0.55, -0.11), (0.55, 0.11), (-0.55, 0.11)], 0.0, 0.8, S.IRON, tag="axe")).move(4.6, 1.6, 2.6)
    parts += [handle, head]
    return merge(*parts), {}
