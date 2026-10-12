"""Shared vegetation helpers for the tree / bush / plant generators (FORGE-02 nature family).

Not a generator (leading underscore: build.py skips it). Everything here returns plain
`Piece`s; all randomness comes from the caller's `b.rng`.

Look: chunky storybook foliage. Canopies are overlapping lumpy "puffs" (noise-displaced
spheres with flattened bottoms, smooth shaded, full 0..1 palette ramp). Each puff takes one
body swatch from its height in the whole canopy (mid low, light higher, sunlit crown on top)
and a darker swatch on its downward-facing faces (dark undersides without saw-tooth lines).
Wood is lofted along curved spines (flared, fluted trunks; tapered branch tubes).
"""

import math

from mathutils import Vector
from mathutils import noise as mnoise

from lib.geo import TAU, Piece, icosphere, lathe, loft_rings, recalc_normals, subdivide, tube

# dark underside, mid, light, sunlit crown
SCHEMES = {
    "summer": ("oak_dark", "oak_mid", "oak_light", "oak_sun"),
    "deep": ("leaf_dark", "oak_dark", "oak_mid", "oak_light"),
    "autumn_orange": ("autumn_red", "autumn_orange", "autumn_yellow", "ember"),
    "autumn_yellow": ("autumn_orange", "hay_dark", "autumn_yellow", "flower_yellow"),
    "autumn_red": ("red_roof_dark", "autumn_red", "autumn_orange", "autumn_yellow"),
    "birch": ("oak_mid", "leaf_light", "birch_leaf", "birch_leaf_light"),
    "birch_gold": ("autumn_orange", "autumn_yellow", "leaf_yellow", "straw"),
    "bush": ("leaf_dark", "leaf_mid", "leaf_light", "leaf_bright"),
    "hedge": ("leaf_dark", "oak_dark", "oak_mid", "oak_light"),
    "pine": ("pine_dark", "pine_mid", "pine_light", "pine_tip"),
    "pine_blue": ("pine_dark", "pine_blue", "copper_green", "copper_green"),
}


def bezier(p0, p1, p2, n):
    """n points on a quadratic Bezier (inclusive)."""
    p0, p1, p2 = Vector(p0), Vector(p1), Vector(p2)
    out = []
    for i in range(n):
        t = i / (n - 1)
        out.append(p0 * (1 - t) ** 2 + p1 * 2 * (1 - t) * t + p2 * t * t)
    return out


def clamp_ground(piece, z=0.0):
    """Flatten anything below the ground plane onto it (pivot must stay at z=0)."""
    piece.verts = [Vector((v.x, v.y, max(z, v.z))) for v in piece.verts]
    return piece


def sphere(level=2, color="leaf_mid"):
    """Unit sphere mesh by cost: 1 = 20 tris, 2 = 80, 'g3' = 180 (frequency-3 geodesic), 3 = 320."""
    if level == "g3":
        p = subdivide(icosphere(1.0, 1, color), cuts=2)
        p.verts = [v.normalized() for v in p.verts]
        return p
    return icosphere(1.0, level, color)


def puff(rng, r, scheme, hglob=0.5, subdiv=2, squash=0.82, bottom=0.5, lump=0.24, freq=1.1, stretch=0.1,
         under_nz=0.55, sun_nz=2.0, core=False, body=None):
    """One soft lumpy foliage clump centred on the origin: noise-displaced sphere, flattened
    underside, smooth shaded, strong vertical ramp. Colour: a body swatch picked by the clump's
    height in the whole canopy (hglob 0..1: mid low down, light up top), a darker underside
    cap, and a sunlit crown cap on the highest clumps. `core=True`: dark/mid interior clump."""
    p = sphere(subdiv, scheme[1])
    seed = rng.uniform(0, 500)
    off = Vector((seed, -seed * 0.37, seed * 0.61))
    sx = 1 + rng.uniform(-stretch, stretch)
    sy = 1 + rng.uniform(-stretch, stretch)
    out = []
    for v in p.verts:
        d = 1.0 + lump * mnoise.noise(v * freq + off)
        z = v.z * d
        if z < 0:
            z *= bottom
        out.append(Vector((v.x * d * sx * r, v.y * d * sy * r, z * squash * r)))
    p.verts = out
    if core:
        body_c, low, top = scheme[1], scheme[0], scheme[1]
    else:
        body_c = body or (scheme[1] if hglob < 0.4 else scheme[2] if hglob < 0.8 else scheme[3])
        low = scheme[0] if hglob < 0.8 else scheme[1]
        top = body_c
    # colour by face normal, not height: the dark cap sits on the flattened underside (hidden
    # from the usual 20-30 deg camera) instead of drawing a saw-tooth line across the side
    cols = []
    for f in p.faces:
        a, b_, c = out[f[0]], out[f[1]], out[f[2]]
        nz = (b_ - a).cross(c - a).normalized().z
        cols.append(low if nz < -under_nz else top if nz > sun_nz else body_c)
    p.face_colors = cols
    p.smooth = True
    p.grad = ("range", 0.0, 1.0)
    p.tag = "leaf"
    return p


def _frame(t, prev_n=None):
    t = t.normalized()
    if prev_n is None:
        ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
        n = t.cross(ref)
    else:
        n = prev_n - t * prev_n.dot(t)
    if n.length < 1e-8:
        n = t.orthogonal()
    n.normalize()
    return n, t.cross(n)


def wood_loft(spine, radii, seg=8, color="bark", flute=None, gnarl=0.0, seed=0.0, twist=0.0, grad=("range", 0.2, 0.8),
              tag="branch", tip_round=True):
    """Lofted wooden limb along a spine with per-ring radii. `flute(i)` -> fraction pushed in on
    every other ring vertex (bark ridges / root buttresses). Closed, smooth shaded."""
    pts = [Vector(p) for p in spine]
    n = len(pts)
    rings = []
    nrm = None
    for i, c in enumerate(pts):
        if i == 0:
            t = pts[1] - pts[0]
        elif i == n - 1:
            t = pts[-1] - pts[-2]
        else:
            t = (pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()
        nrm, bi = _frame(t, nrm)
        fl = flute(i) if flute else 0.0
        ring = []
        for k in range(seg):
            a = TAU * k / seg + twist * i
            rr = radii[i] * (1.0 - fl * (k % 2))
            if gnarl:
                rr *= 1.0 + gnarl * mnoise.noise(Vector((math.cos(a) * 1.7, math.sin(a) * 1.7, c.z * 0.35 + seed)))
            ring.append(c + (nrm * math.cos(a) + bi * math.sin(a)) * rr)
        rings.append(ring)
    p = loft_rings(rings, color, smooth=True, grad=grad, tag=tag)
    return p


def limb(points, r0, r1, seg=6, color="bark", grad=("range", 0.25, 0.8), tag="branch"):
    """Tapered branch tube (geo.tube) with a pointed-ish end, smooth shaded."""
    n = len(points)
    radii = [r0 + (r1 - r0) * (i / (n - 1)) ** 0.9 for i in range(n)]
    p = tube(points, radii, seg, color)
    return p.paint(smooth=True, grad=grad, tag=tag)


def root(rng, base, ang, r_base, length, color="bark", seg=6, z0=None):
    """Exposed root: arcs out of the trunk base and dives into the ground (clamped flat)."""
    d = Vector((math.cos(ang), math.sin(ang), 0))
    z0 = r_base * 1.5 if z0 is None else z0
    p0 = Vector(base) + d * (r_base * 0.25) + Vector((0, 0, z0))
    p1 = Vector(base) + d * (r_base * 0.95) + Vector((0, 0, r_base * 0.45))
    p2 = Vector(base) + d * (r_base * 0.95 + length * 0.55) + Vector((0, 0, r_base * 0.12))
    p3 = Vector(base) + d * (r_base * 0.95 + length) + Vector((0, 0, -0.05))
    side = Vector((-d.y, d.x, 0)) * rng.uniform(-0.25, 0.25) * length
    pts = [p0, p1, p2 + side * 0.5, p3 + side]
    radii = [r_base * 0.42, r_base * 0.36, r_base * 0.2, r_base * 0.06]
    p = tube(pts, radii, seg, color)
    clamp_ground(p)
    return p.paint(smooth=True, grad=("range", 0.15, 0.7), tag="root")


def mushroom(rng, cap_r=0.55, h=0.8, cap="apple_red", stem="flower_white"):
    st = lathe([(cap_r * 0.35, 0.0), (cap_r * 0.3, h), (0.0, h + 0.01)], 6, stem)
    cp = lathe([(0.0, h - 0.1), (cap_r, h + 0.05), (cap_r * 0.75, h + cap_r * 0.55), (0.0, h + cap_r * 0.75)], 7, cap)
    cp.paint(smooth=True, grad=("range", 0.3, 1.0))
    return [st, cp]


def star_poly(n, r_out, r_in, phase=0.0):
    pts = []
    for i in range(2 * n):
        r = r_out if i % 2 == 0 else r_in
        a = phase + math.pi * i / n
        pts.append((math.cos(a) * r, math.sin(a) * r))
    return pts


def flower_head(rng, r, color, center="flower_yellow", petals=5, thick=0.14, cup=0.12, inner=0.45, dome_k=0.32):
    """Solid star-shaped flower (petals as one thick star plate) with a domed centre."""
    poly = star_poly(petals, r, r * inner, rng.uniform(0, TAU))
    n = len(poly)
    verts = []
    for x, y in poly:
        verts.append(Vector((x, y, cup * math.hypot(x, y) / r)))
    for x, y in poly:
        verts.append(Vector((x, y, thick + cup * math.hypot(x, y) / r)))
    faces = [tuple(reversed(range(n))), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    plate = recalc_normals(Piece(verts, faces, color, grad=("range", 0.4, 1.0)))
    dome = lathe([(r * dome_k, thick * 0.5), (r * dome_k * 0.94, thick + 0.08), (0.0, thick + r * dome_k * 0.8)], 5,
                 center)
    dome.paint(smooth=True, grad=("range", 0.3, 1.0))
    return [plate, dome]


def blade(rng, base, h, w, lean, ang, colors=("grass_dark", "grass", "grass_light"), thick=0.35, curl=1.0):
    """Tapered solid grass blade: flat triangular cross-section (width w, thickness w*thick)
    along a spine that bends outward (lean) and droops at the tip; base on z=0.
    Colour bands by height (dark base -> light tip). 16 tris."""
    d = Vector((math.cos(ang), math.sin(ang), 0))
    side = Vector((-d.y, d.x, 0))
    p0 = Vector(base)
    p1 = p0 + d * (lean * 0.32) + Vector((0, 0, h * 0.42))
    p2 = p0 + d * (lean * 0.68) + Vector((0, 0, h * 0.78))
    tip = p0 + d * (lean * (1.0 + 0.25 * curl)) + Vector((0, 0, h * (1.0 - 0.12 * curl)))
    verts = []
    for c, ww in ((p0, w), (p1, w * 0.82), (p2, w * 0.5)):
        t = w * thick * (ww / w)
        verts += [c - side * ww, c + side * ww, c - d * t]  # flat front, ridge at the back
    verts.append(tip)
    faces = []
    for r in range(2):
        a, b_ = r * 3, (r + 1) * 3
        for k in range(3):
            k2 = (k + 1) % 3
            faces.append((a + k, a + k2, b_ + k2, b_ + k))
    for k in range(3):
        faces.append((6 + k, 6 + (k + 1) % 3, 9))
    faces.append((2, 1, 0))
    p = recalc_normals(Piece(verts, faces, colors[1], grad=("range", 0.1, 1.0), tag="blade"))
    zs = [v.z for v in p.verts]
    z0, z1 = min(zs), max(zs)
    cols = []
    for f in p.faces:
        zc = (sum(zs[i] for i in f) / len(f) - z0) / max(1e-6, z1 - z0)
        cols.append(colors[0] if zc < 0.2 else colors[1] if zc < 0.66 else colors[2])
    p.face_colors = cols
    return p


__all__ = ["mnoise", "SCHEMES", "sphere", "bezier", "clamp_ground", "puff", "wood_loft", "limb", "root", "mushroom",
           "star_poly", "flower_head", "blade"]
