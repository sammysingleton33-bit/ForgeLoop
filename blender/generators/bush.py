"""Bushes and hedges: mounds of overlapping soft leaf clumps (one big smooth core clump,
a ring of lower clumps sitting on the ground, a few crown clumps), dark undersides and light
tops like the oak canopy. Kinds: round, flowering (small coloured flower blobs on the sunny
side), berry (clusters of red/blue berries), and a trimmed low hedge segment 16 studs long.
Small woody stems show at the base. Front faces Blender -Y.
"""

import math

from lib.geo import TAU, Vector, icosphere, lathe, look_rot

from generators import _vegetation_common as vc

NAME = "bush"
VERSION = 2
CATEGORY = "bush"
BUDGET = "bush"
COLLISION = {"fidelity": "Box"}
CHECKS = {"min_leaf_clusters": 5}
DEFAULT_VARIANTS = 8
LINEUP_GAP = 3.0
GAMEPLAY_DISTANCE = 40.0
GAMEPLAY_HEIGHT = 9.0

PLAN = (
    # kind, size, scheme, accent colours
    ("round", 1.0, "bush", None),
    ("round", 1.35, "hedge", None),
    ("flowering", 1.15, "bush", ("blossom_pink", "flower_white")),
    ("flowering", 1.0, "hedge", ("flower_yellow", "flower_white", "flower_purple")),
    ("berry", 1.1, "hedge", ("apple_red",)),
    ("berry", 0.9, "bush", ("flower_blue", "flower_purple")),
    ("hedge", 1.0, "hedge", None),
    ("hedge", 1.25, "bush", ("flower_red", "flower_white")),
)


def variants(n, seed):
    out = []
    for i in range(n):
        kind, size, scheme, acc = PLAN[i % len(PLAN)]
        out.append({"kind": kind, "size": size, "leaves": scheme, "accents": list(acc) if acc else [],
                    "seed": seed * 1000 + 13 * i + 11})
    return out


def asset_id(i, params):
    return f"bush_{params['kind']}_{i + 1:02d}"


def _surface_points(rng, pieces, n, min_nz=0.15, avoid_low=0.25, spacing=0.75):
    """Random outward-facing points on the visible outer surface of a clump group (points
    buried inside a neighbouring clump are rejected)."""
    ell = []
    for pc in pieces:
        lo, hi = pc.bounds()
        ell.append(((lo + hi) / 2, (hi - lo) / 2))
    cands = []
    for pi, pc in enumerate(pieces):
        c = ell[pi][0]
        for v in pc.verts:
            d = v - c
            if d.length < 1e-6:
                continue
            nd = d.normalized()
            if nd.z < min_nz or v.z < avoid_low:
                continue
            hidden = False
            for qj, (cq, hq) in enumerate(ell):
                if qj == pi:
                    continue
                e = Vector(((v.x - cq.x) / max(hq.x, 1e-3), (v.y - cq.y) / max(hq.y, 1e-3),
                            (v.z - cq.z) / max(hq.z, 1e-3)))
                if e.length < 0.92:
                    hidden = True
                    break
            if not hidden:
                cands.append((v, nd))
    rng.shuffle(cands)
    out = []
    for v, nd in cands:
        if all((v - o).length > spacing for o, _ in out):
            out.append((v, nd))
        if len(out) >= n:
            break
    return out


def _mound(b, rng, s, sch, smooth_top=False):
    """Round bush: a smaller smooth core wrapped in clumps spread (Fibonacci) over its upper
    surface; the lowest ring sits on the ground. Returns the clump pieces."""
    R = 3.0 * s  # half-width
    Hh = 4.4 * s  # height target
    pcs = []
    core = vc.puff(rng, 1.0, sch, hglob=0.4, subdiv="g3", squash=1.0, bottom=0.7, lump=0.14, core=True)
    core.scale(R * 0.74, R * 0.68, Hh * 0.42).move(0, 0, Hh * 0.4)
    pcs.append(core)
    n = rng.randint(8, 9)
    lo, hi = math.sin(math.radians(-38)), math.sin(math.radians(80))
    golden = math.pi * (3 - math.sqrt(5))
    ph = rng.uniform(0, TAU)
    for i in range(n):
        sn = hi - (hi - lo) * (i + 0.5) / n
        el = math.asin(sn)
        az = ph + golden * i + rng.uniform(-0.2, 0.2)
        d = Vector((math.cos(el) * math.cos(az) * R * 0.66, math.cos(el) * math.sin(az) * R * 0.6,
                    math.sin(el) * Hh * 0.42))
        r = R * rng.uniform(0.4, 0.5) * (1.08 if el > 0.8 else 1.0)
        c = Vector((0, 0, Hh * 0.42)) + d
        c.z = max(c.z, r * 0.45)
        lvl = "g3" if (smooth_top and el > 0.3) else 2
        pf = vc.puff(rng, r, sch, hglob=max(0.0, min(1.0, c.z / Hh)), subdiv=lvl, squash=0.9, bottom=0.62)
        pcs.append(pf.move(c.x, c.y, c.z))
    return pcs


def _hedge(b, rng, s, sch):
    """Trimmed low hedge segment, 16 long: one lofted rounded-box mass with lumpy, clipped
    surface (dark base, light top), plus a few soft lumps along the top."""
    L, D, Hh = 16.0, 3.2 * s, 3.6 * s
    # rounded-rectangle cross-section (y, z), CCW seen from +X
    sec = []
    cr = min(D, Hh) * 0.32
    for cy, cz, a0 in ((D / 2 - cr, Hh - cr, 0.0), (-D / 2 + cr, Hh - cr, 90.0)):
        for k in range(3):  # 3 points per rounded corner (was 4): same read, fewer hidden faces
            a = math.radians(a0 + 90.0 * k / 2)
            sec.append((cy + math.cos(a) * cr, cz + math.sin(a) * cr))
    sec += [(-D / 2 - 0.05, Hh * 0.3), (-D / 2 + 0.25, 0.0), (D / 2 - 0.25, 0.0), (D / 2 + 0.05, Hh * 0.3)]
    seed = rng.uniform(0, 100)
    xs = [-L / 2 + L * i / 11 for i in range(12)]
    rings = []
    for xi, x in enumerate(xs):
        end = 1.0 - (0.12 if xi in (0, len(xs) - 1) else 0.0)
        ring = []
        for y, z in sec:
            n = vc.mnoise.noise(Vector((x * 0.8, y * 0.8 + seed, z * 0.8)))
            sy = 1.0 + 0.2 * n
            zz = z * (1.0 + 0.1 * n) if z > 0.01 else 0.0
            xx = x * (0.985 if xi in (0, len(xs) - 1) else 1.0)
            ring.append(Vector((xx, y * sy * end, min(Hh + 0.15, zz * (1.0 if end == 1.0 else 0.94)))))
        rings.append(ring)
    from lib.geo import loft_rings
    body = loft_rings(rings, sch[1], smooth=True, grad=("range", 0.0, 1.0), tag="leaf")
    body.face_smooth = [True] * len(body.faces)
    cols = []
    for f in body.faces:
        vs = [body.verts[i] for i in f]
        nz = (vs[1] - vs[0]).cross(vs[2] - vs[0]).normalized().z
        zc = sum(v.z for v in vs) / len(vs)
        cols.append(sch[2] if nz > 0.5 else sch[0] if zc < Hh * 0.2 else sch[1])
    body.face_colors = cols
    pcs = [body]
    for i in range(5):
        x = -L / 2 + 2.0 + (L - 4.0) * i / 4 + rng.uniform(-0.5, 0.5)
        r = rng.uniform(1.3, 1.6) * (Hh / 3.6) ** 0.5
        lump = vc.puff(rng, r, sch, hglob=0.6, subdiv=2, squash=0.6, bottom=0.6, lump=0.2)
        pcs.append(lump.move(x, rng.uniform(-0.4, 0.4), Hh - r * 0.36))
        if i not in (1, 3):
            continue
        side = -1 if i == 1 else 1
        sl = vc.puff(rng, r * 0.8, sch, hglob=0.35, subdiv=2, squash=0.9, bottom=0.8, lump=0.14)
        pcs.append(sl.scale(1.0, 0.6, 1.0).move(x + 0.8, side * D * 0.44, Hh * rng.uniform(0.35, 0.55)))
    return pcs


def build(b, p):
    rng = b.rng
    sch = vc.SCHEMES[p["leaves"]]
    s = p["size"]
    kind = p["kind"]
    pcs = _hedge(b, rng, s, sch) if kind == "hedge" else _mound(b, rng, s, sch, smooth_top=kind == "round")
    for pc in pcs:
        b.add(vc.clamp_ground(pc))
    b.stats["leaf_clusters"] = len(pcs)

    # woody stems at the base, between the ground clumps
    if kind != "hedge":
        for i in range(3):
            a = -math.pi / 2 + rng.uniform(-0.9, 0.9)
            d = Vector((math.cos(a), math.sin(a), 0))
            r0 = 3.0 * s * 0.55
            st = vc.limb([d * r0 * 0.4, d * r0 * 0.75 + Vector((0, 0, 0.45)), d * r0 * 0.95 + Vector((0, 0, 1.3))],
                         0.22, 0.12, seg=4, color="bark_dark")
            b.add(vc.clamp_ground(st))

    # accents
    acc = p["accents"]
    leaves = pcs
    if kind == "flowering" or (kind == "hedge" and acc):
        pts = _surface_points(rng, leaves, 22 if kind == "flowering" else 12, min_nz=0.0, avoid_low=0.8,
                              spacing=1.0)
        for k, (v, nd) in enumerate(pts):
            col = acc[k % len(acc)] if k % 3 else acc[0]
            r = rng.uniform(0.5, 0.64)
            # flat blossom aligned with the leaf surface, half sunk into it
            fl = lathe([(0.0, -0.2), (r, -0.02), (r * 0.62, 0.14), (0.0, 0.17)], 5, col, phase=rng.uniform(0, 1.2))
            parts = [fl.paint(smooth=True, grad=("range", 0.5, 1.0), tag="flower")]
            if k % 2 == 0:
                parts.append(lathe([(0.0, 0.0), (r * 0.34, 0.1), (0.0, 0.24)], 4,
                                   "flower_yellow" if col != "flower_yellow" else "ember").move(0, 0, 0.08))
            nn = (nd + Vector((0, 0, 0.8))).normalized()
            m = look_rot(nn)
            for pc in parts:
                pc.transform(m)
                b.add(pc.move(v.x + nd.x * 0.05, v.y + nd.y * 0.05, v.z + nd.z * 0.05))
        b.stats["flowers"] = len(pts)
    if kind == "berry":
        pts = _surface_points(rng, leaves, 7, min_nz=-0.35, avoid_low=0.9, spacing=1.4)
        nber = 0
        for k, (v, nd) in enumerate(pts):
            col = acc[k % len(acc)]
            for q in range(3):
                off = Vector((math.cos(q * 2.1 + k), math.sin(q * 2.1 + k), 0)) * 0.26
                be = icosphere(1.0, 1, col).scale(0.27)
                b.add(be.move(v.x + nd.x * 0.2 + off.x, v.y + nd.y * 0.2 + off.y, v.z - 0.1 * q).paint(
                    smooth=True, grad=("range", 0.35, 1.0), tag="berry"))
                nber += 1
        b.stats["berries"] = nber
        fr = max(pts, key=lambda t: -t[0].y)[0]
        b.socket("harvest", fr.x, fr.y - 1.2, fr.z * 0.6)

    zt = max(v.z for pc in pcs for v in pc.verts)
    b.socket("top", 0.0, 0.0, zt)
