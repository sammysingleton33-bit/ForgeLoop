"""Environment kit (FL-0136 phase 2, D-057 (19)): style B for nature and crops, shared by the _envkit_* modules.

The same direction as the citizen kit (generators/_charkit_style.py, games/game-001/art/reviews/char-mesh.md): faceted, flat-shaded,
chunky low-poly; ONE vertex-colour material; +-6 % brightness per facet (lib/ckit.corner_colors); no textures. Everything is authored
in ROBLOX axes (x right, y up, front -Z, studs, base on y = 0) and is deterministic: every prop draws from its own
`random.Random(f"envkit:{id}:{seed}")`, never the global generator, so the kit rebuilds bit-identically (check.sh --verify).

Palette: the Kit's own colours (Kit/Parts.luau C, Kit/Props.luau EXTRA and ROCK) so the meshes sit beside the part-built buildings.
"""

import math
import random

from lib.ckit import M, box, cone, cyl, hull, loft, merge, mix, mul, rgb  # noqa: F401  (re-exported for the family modules)

FACET = 0.06  # +-6 % per facet (the citizen kit's value)
AO = 0.22  # down-facing faces darker (lib/ckit.corner_colors)

# ------------------------------------------------------------------ palette (sRGB, mirrors Kit/Parts.luau and Kit/Props.luau)
LEAF_DARK = rgb(46, 107, 47)
LEAF = rgb(63, 138, 54)
LEAF_LIGHT = rgb(99, 168, 60)
OAK_SUN = rgb(166, 207, 74)
BARK = rgb(107, 74, 48)
BARK_DARK = rgb(78, 52, 34)
BARK_LIGHT = rgb(140, 100, 64)
PINE = rgb(31, 82, 54)
PINE_MID = rgb(45, 107, 67)
PINE_LIGHT = rgb(74, 138, 80)
BIRCH = rgb(232, 226, 210)
BIRCH_MARK = rgb(59, 53, 48)
BIRCH_LEAF = rgb(156, 201, 74)
BIRCH_LEAF_LIGHT = rgb(196, 222, 106)
ROCK_BASE = rgb(98, 102, 112)
ROCK_MID = rgb(136, 136, 138)
ROCK_TOP = rgb(184, 180, 168)
ROCK_WARM = rgb(158, 150, 138)
MOSS = rgb(96, 132, 62)
STONE_LIGHT = rgb(184, 178, 168)
IRON_ORE = rgb(160, 86, 58)
GOLD_ORE = rgb(242, 194, 48)
CRYSTAL = rgb(111, 208, 224)
BERRY = rgb(200, 50, 43)
FLOWER = {"red": rgb(217, 52, 58), "yellow": rgb(244, 208, 63), "white": rgb(245, 243, 234), "purple": rgb(142, 92, 194)}
WOOD = rgb(139, 90, 51)
WOOD_LIGHT = rgb(176, 123, 74)
WOOD_DARK = rgb(92, 59, 34)
IRON = rgb(63, 68, 75)
HAY = rgb(216, 184, 90)
HAY_DARK = rgb(184, 150, 62)
SOIL = rgb(96, 70, 44)
SOIL_RIDGE = rgb(112, 82, 52)
SOIL_DARK = rgb(78, 56, 36)
WHEAT = rgb(230, 194, 90)

OAK_RAMP = [rgb(26, 74, 46), rgb(40, 100, 48), rgb(58, 130, 50), rgb(92, 164, 56), rgb(146, 202, 68)]  # blue-green shade up to a sunlit lime
PINE_RAMP = [rgb(22, 62, 46), PINE, PINE_MID, PINE_LIGHT]
BIRCH_RAMP = [mul(BIRCH_LEAF, 0.74), mul(BIRCH_LEAF, 0.9), BIRCH_LEAF, BIRCH_LEAF_LIGHT]
BUSH_RAMP = [mul(LEAF_DARK, 0.95), LEAF, LEAF_LIGHT, mix(LEAF_LIGHT, OAK_SUN, 0.28)]
ROCK_RAMP = [mul(ROCK_BASE, 0.84), ROCK_BASE, ROCK_MID, ROCK_TOP]


def rng_for(prop_id, seed=7):
    """Deterministic generator per prop (string seeds hash with SHA-512 in CPython: stable across runs and machines)."""
    return random.Random(f"envkit:{prop_id}:{seed}")


def ramp(stops, t):
    t = min(1.0, max(0.0, t))
    x = t * (len(stops) - 1)
    i = min(len(stops) - 2, int(x))
    return mix(stops[i], stops[i + 1], x - i)


# ------------------------------------------------------------------ geometry helpers

def face_normal(m, f):
    a, b, c = m.v[f[0]], m.v[f[1]], m.v[f[2]]
    ux, uy, uz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    vx, vy, vz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
    nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    ln = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
    return nx / ln, ny / ln, nz / ln


def centroid(m, f):
    n = len(f)
    return (sum(m.v[i][0] for i in f) / n, sum(m.v[i][1] for i in f) / n, sum(m.v[i][2] for i in f) / n)


def flat(m, tag=""):
    """Every face flat-shaded (style B)."""
    m.s = [False] * len(m.f)
    if tag:
        m.k = [tag] * len(m.f)
    return m


def sphere_points(n, rx, ry, rz, cx=0.0, cy=0.0, cz=0.0, jitter=0.14, rng=None, phase=0.0, squash_bottom=0.0):
    """n points near an ellipsoid (Fibonacci spiral), each pushed in or out by `jitter` (fraction of the radius).

    squash_bottom flattens the lower hemisphere toward the equator (0 = none, 1 = flat), for canopies and rocks that sit on something."""
    rng = rng or random.Random(0)
    pts = []
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(n):
        y = 1 - 2 * (i + 0.5) / n
        r = math.sqrt(max(0.0, 1 - y * y))
        a = phase + i * golden
        s = 1.0 + rng.uniform(-jitter, jitter)
        yy = y * s
        if yy < 0 and squash_bottom:
            yy *= 1.0 - squash_bottom
        pts.append((cx + math.cos(a) * r * rx * s, cy + yy * ry, cz + math.sin(a) * r * rz * s))
    return pts


def blob(rng, n, rx, ry=None, rz=None, cx=0.0, cy=0.0, cz=0.0, jitter=0.14, squash_bottom=0.0, color=LEAF, tag="", yaw=0.0):
    """A faceted lump: the convex hull of `n` jittered ellipsoid points (about 2n - 4 triangles), flat shaded."""
    ry = rx if ry is None else ry
    rz = rx if rz is None else rz
    pts = sphere_points(n, rx, ry, rz, cx, cy, cz, jitter, rng, phase=rng.uniform(0, math.tau), squash_bottom=squash_bottom)
    if yaw:
        c, s = math.cos(yaw), math.sin(yaw)
        pts = [(cx + (p[0] - cx) * c - (p[2] - cz) * s, p[1], cz + (p[0] - cx) * s + (p[2] - cz) * c) for p in pts]
    m = hull(pts, color=color, smooth=False, tag=tag)
    return flat(m, tag)


_PHI = (1 + math.sqrt(5)) / 2
_ICO_V = [(-1, _PHI, 0), (1, _PHI, 0), (-1, -_PHI, 0), (1, -_PHI, 0), (0, -1, _PHI), (0, 1, _PHI), (0, -1, -_PHI), (0, 1, -_PHI), (_PHI, 0, -1), (_PHI, 0, 1), (-_PHI, 0, -1),
          (-_PHI, 0, 1)]
_ICO_F = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9),
          (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]


def ico(rng, rx, ry=None, rz=None, cx=0.0, cy=0.0, cz=0.0, jitter=0.08, subdiv=0, squash_bottom=0.0, color=LEAF, tag="", yaw=None):
    """A regular faceted lump: a jittered icosahedron (20 triangles) or its one-level subdivision (80), flat shaded. Cleaner than `blob` for small props:
    its facets are even-sized, so a bush or a berry reads as a deliberate low-poly gem instead of a crumpled hull."""
    ry = rx if ry is None else ry
    rz = rx if rz is None else rz
    yaw = rng.uniform(0, math.tau) if yaw is None else yaw
    verts = [tuple(c / math.sqrt(sum(q * q for q in v)) for c in v) for v in _ICO_V]
    faces = [tuple(f) for f in _ICO_F]
    if subdiv:
        mid, nv, nf = {}, list(verts), []

        def mp(a, b):
            k = (min(a, b), max(a, b))
            if k not in mid:
                p = tuple((nv[a][i] + nv[b][i]) / 2 for i in range(3))
                ln = math.sqrt(sum(q * q for q in p))
                nv.append(tuple(q / ln for q in p))
                mid[k] = len(nv) - 1
            return mid[k]

        for a, b, c in faces:
            ab, bc, ca = mp(a, b), mp(b, c), mp(c, a)
            nf += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
        verts, faces = nv, nf
    c_, s_ = math.cos(yaw), math.sin(yaw)
    pts = []
    for v in verts:
        k = 1.0 + rng.uniform(-jitter, jitter)
        x, y, z = v[0] * rx * k, v[1] * ry * k, v[2] * rz * k
        if y < 0 and squash_bottom:
            y *= 1.0 - squash_bottom
        pts.append((cx + x * c_ - z * s_, cy + y, cz + x * s_ + z * c_))
    m = M(pts, faces, color=color, smooth=False, tag=tag).fix_winding()
    return flat(m, tag)


def paint_ramp(m, stops, rng, y0, y1, up=0.40, height=0.45, noise=0.10, where=None):
    """Colour every face (or those passing `where(cx, cy, cz, normal)`) from a dark-to-light ramp: higher and up-facing faces are lighter."""
    for i, f in enumerate(m.f):
        c = centroid(m, f)
        n = face_normal(m, f)
        if where is not None and not where(c[0], c[1], c[2], n):
            continue
        h = (c[1] - y0) / max(1e-6, y1 - y0)
        t = height * h + up * (0.5 + 0.5 * n[1]) + rng.uniform(-noise, noise) + (1 - height - up) * 0.5
        m.c[i] = ramp(stops, t)
    return m


def tube(path, radii, seg=6, color=BARK, caps=True, n=2.4, tag=""):
    """A faceted limb along a polyline (lib/ckit.tube), flat shaded."""
    from lib.ckit import tube as _tube

    return flat(_tube(path, radii, seg=seg, caps=caps, n=n, color=color, smooth=False, tag=tag), tag)


def slab(poly_xz, y0, y1, color, scale1=1.0, tag=""):
    """A prism standing on y0 (convex polygon in the x-z plane, CCW seen from +y), tapering by scale1 at y1."""
    # lib/ckit.prism extrudes along +z of an x-y polygon; build ours directly so up is +y
    n = len(poly_xz)
    cxm = sum(p[0] for p in poly_xz) / n
    czm = sum(p[1] for p in poly_xz) / n
    v = [(p[0], y0, p[1]) for p in poly_xz] + [(cxm + (p[0] - cxm) * scale1, y1, czm + (p[1] - czm) * scale1) for p in poly_xz]
    f = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    f.append(tuple(range(n)))
    f.append(tuple(n + i for i in range(n)))
    m = M(v, f, color=color, smooth=False, tag=tag)
    return m.fix_winding()


# ------------------------------------------------------------------ measurements (used by the generators' own sanity checks)

def bounds(m):
    return m.bounds()


def radius_xz(m):
    """Largest horizontal distance of any vertex from the pivot axis."""
    return max(math.hypot(p[0], p[2]) for p in m.v)


def fit_to(m, footprint, height, fp_window=(0.93, 1.07), h_window=(0.9, 1.1)):
    """Bring a prop's footprint (max(x extent, z extent), the figure the Kit's fit rule uses) and height (its top above y = 0) into a window around the stand-in's.

    Only outliers move, and only to the edge of the window (so natural variation inside it is kept): xz about the pivot axis, y about the ground plane.
    Returns (kr, kh), the scale factors applied (1.0 = untouched)."""
    (x0, y0, z0), (x1, y1, z1) = m.bounds()
    fp = max(x1 - x0, z1 - z0)
    h = y1

    def factor(have, want, window):
        if have <= 0 or not want:
            return 1.0
        q = have / want
        return window[1] / q if q > window[1] else window[0] / q if q < window[0] else 1.0

    kr, kh = factor(fp, footprint, fp_window), factor(h, height, h_window)
    if kr != 1.0 or kh != 1.0:
        m.map(lambda p: (p[0] * kr, p[1] * kh, p[2] * kr))
    return round(kr, 3), round(kh, 3)


def assemble(parts, name=""):
    """Merge the parts of one prop into one mesh after the floating-part check: every part must stand on the ground or touch another part's box."""
    flat_parts = []
    for p in parts:
        if p is None:
            continue
        flat_parts += list(p) if isinstance(p, (list, tuple)) else [p]
    bad = weld_check(flat_parts)
    if bad:
        raise AssertionError(f"{name or 'prop'}: floating part(s) {bad} ({[flat_parts[i].k[0] if flat_parts[i].k else '?' for i in bad]})")
    return merge(*flat_parts)


def weld_check(parts, tol=0.15):
    """Floating-part check: every part's bounding box must touch (within `tol`) the box of at least one other part or the ground.

    Returns the indices of parts that float."""
    boxes = []
    for p in parts:
        (x0, y0, z0), (x1, y1, z1) = p.bounds()
        boxes.append((x0 - tol, y0 - tol, z0 - tol, x1 + tol, y1 + tol, z1 + tol))
    out = []
    for i, a in enumerate(boxes):
        if a[1] <= 0.3:  # stands on the ground
            continue
        ok = False
        for j, b in enumerate(boxes):
            if i != j and a[0] <= b[3] and a[3] >= b[0] and a[1] <= b[4] and a[4] >= b[1] and a[2] <= b[5] and a[5] >= b[2]:
                ok = True
                break
        if not ok:
            out.append(i)
    return out
