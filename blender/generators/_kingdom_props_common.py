"""Private helpers for the kingdom-banner / siege / bridge / village-prop family (FORGE-02).

Not a generator (leading underscore: build.py skips it). Everything here returns plain
`Piece`s in local coordinates, like `lib/kit.py`, and builds closed solids only.

Shared language with the cottage kit: chunky proportions, bevelled masses, timber at
kit.TIMBER, iron straps in iron_dark, rope in `rope`, kingdom colour as accents.
"""

import math

from lib import kit
from lib.geo import Piece, Vector, box, cylinder, lathe, recalc_normals, tube
from lib.palette import kingdom_color

KINGDOMS = ("red", "blue", "green", "yellow")


# ------------------------------------------------------------------ generic solids

def sweep_loop(profile, seg, color, phase=0.0, colors=None, rx=1.0, ry=1.0):
    """Revolve a CLOSED 2D cross-section [(r, z), ...] around Z (a torus-like ring: wheel
    rims, tyres, hoops, rope coils, well curbs). `colors[k]` colours the band that starts
    at profile point k. rx/ry squash the ring into an ellipse."""
    n = len(profile)
    verts, faces, fcols = [], [], []
    for i in range(seg):
        a = phase + math.tau * i / seg
        c, s = math.cos(a), math.sin(a)
        for r, z in profile:
            verts.append((r * c * rx, r * s * ry, z))
    for i in range(seg):
        j = (i + 1) % seg
        for k in range(n):
            k2 = (k + 1) % n
            faces.append((i * n + k, j * n + k, j * n + k2, i * n + k2))
            fcols.append(colors[k] if colors else color)
    p = recalc_normals(Piece(verts, faces, color))
    p.face_colors = fcols
    return p


def ring_solid(r_in, r_out, width, seg=12, color="iron_dark", phase=None):
    """Flat ring (rectangular section), axis Z, centred on z=0."""
    w = width / 2
    return sweep_loop([(r_in, -w), (r_out, -w), (r_out, w), (r_in, w)], seg, color,
                      phase=math.pi / seg if phase is None else phase)


def sheet(us, vs, pos_fn, thick, color, colors=None, normal=(0.0, 1.0, 0.0), smooth=True):
    """Solid cloth (thick, closed): a (len(us) x len(vs)) grid of mid-surface points
    pos_fn(u, v) -> (x, y, z), offset +-thick/2 along `normal`. colors(kind, i, j) may
    return a palette name per face (kind: 'front' (-normal side), 'back', 'edge')."""
    nU, nV = len(us), len(vs)
    mids = [Vector(pos_fn(u, v)) for u in us for v in vs]
    if isinstance(normal, str):  # "auto": offset along the local surface normal (curved tarps, tilts)
        hint = Vector((0.0, 0.0, 1.0))
        nrm = []
        for i in range(nU):
            for j in range(nV):
                du = mids[min(nU - 1, i + 1) * nV + j] - mids[max(0, i - 1) * nV + j]
                dv = mids[i * nV + min(nV - 1, j + 1)] - mids[i * nV + max(0, j - 1)]
                c = du.cross(dv)
                nrm.append(c.normalized() if c.length > 1e-9 else hint.copy())
        if sum((c.dot(hint) for c in nrm), 0.0) < 0:
            nrm = [-c for c in nrm]
        verts = [m - c * (thick / 2) for m, c in zip(mids, nrm)] + [m + c * (thick / 2) for m, c in zip(mids, nrm)]
    else:
        n = Vector(normal).normalized() * (thick / 2)
        verts = [m - n for m in mids] + [m + n for m in mids]
    off = nU * nV

    def F(i, j):
        return i * nV + j

    def B(i, j):
        return off + i * nV + j

    faces, cols, sm = [], [], []

    def add(f, kind, i, j):
        faces.append(f)
        c = colors(kind, i, j) if colors else None
        cols.append(c or color)
        sm.append(kind != "edge")

    for i in range(nU - 1):
        for j in range(nV - 1):
            add((F(i, j), F(i + 1, j), F(i + 1, j + 1), F(i, j + 1)), "front", i, j)
            add((B(i, j), B(i, j + 1), B(i + 1, j + 1), B(i + 1, j)), "back", i, j)
    for j in range(nV - 1):  # u = 0 and u = 1 borders
        add((F(0, j + 1), F(0, j), B(0, j), B(0, j + 1)), "edge", 0, j)
        add((F(nU - 1, j), F(nU - 1, j + 1), B(nU - 1, j + 1), B(nU - 1, j)), "edge", nU - 1, j)
    for i in range(nU - 1):  # v = 0 and v = 1 borders
        add((F(i, 0), F(i + 1, 0), B(i + 1, 0), B(i, 0)), "edge", i, 0)
        add((F(i + 1, nV - 1), F(i, nV - 1), B(i, nV - 1), B(i + 1, nV - 1)), "edge", i, nV - 1)
    p = Piece(verts, faces, color, smooth=smooth)
    p.face_colors = cols
    p.face_smooth = sm
    return p


def fan_solid(outline, depth, color, center=(0.0, 0.0), mid=0.5):
    """Raised flat shape in the XZ plane (front face at y = -depth/2, back at +depth/2).
    With `mid` the front is fan-triangulated through a mid ring so the shape can be bent
    onto a waving cloth (6n tris); mid=None gives a plain fan (4n tris). `outline` is CCW
    [(x, z), ...] and must be star-shaped around `center`."""
    cx, cz = center
    n = len(outline)
    for k in range(n):
        ax, az = outline[k][0] - cx, outline[k][1] - cz
        bx, bz = outline[(k + 1) % n][0] - cx, outline[(k + 1) % n][1] - cz
        if ax * bz - az * bx <= 1e-6:
            raise ValueError(f"fan_solid outline not star-shaped at point {k}")
    d = depth / 2
    verts = [(cx, -d, cz)]
    m = mid if mid else 0.5
    verts += [(cx + (x - cx) * m, -d, cz + (z - cz) * m) for x, z in outline]  # 1..n (unused if mid=None)
    verts += [(x, -d, z) for x, z in outline]  # n+1..2n
    verts += [(x, d, z) for x, z in outline]  # 2n+1..3n
    verts.append((cx, d, cz))  # 3n+1
    faces = []
    for k in range(n):
        k2 = (k + 1) % n
        if mid:
            faces.append((0, 1 + k2, 1 + k))
            faces.append((1 + k, 1 + k2, 1 + n + k2, 1 + n + k))
        else:
            faces.append((0, 1 + n + k2, 1 + n + k))
        faces.append((3 * n + 1, 1 + 2 * n + k, 1 + 2 * n + k2))
        faces.append((1 + n + k, 1 + n + k2, 1 + 2 * n + k2, 1 + 2 * n + k))
    if not mid:  # drop the unused mid ring (no loose vertices)
        verts = [verts[0]] + verts[1 + n:]
        faces = [tuple(i if i == 0 else i - n for i in f) for f in faces]
    return recalc_normals(Piece(verts, faces, color))


def strip_solid(zs, half_w, depth, color, xoff=None):
    """Raised z-monotone shape (leaf, blade, pennant) in the XZ plane: at each station z
    the shape spans x = xoff(z) +- half_w(z). Front at y = -depth/2. Has a centre column so
    it can follow a curved surface."""
    d = depth / 2
    verts, faces = [], []
    m = len(zs)
    for z in zs:
        w = max(0.02, half_w(z))
        x0 = xoff(z) if xoff else 0.0
        for x in (x0 - w, x0, x0 + w):
            verts.append((x, -d, z))
        for x in (x0 - w, x0 + w):
            verts.append((x, d, z))
    S = 5
    for i in range(m - 1):
        a, b = i * S, (i + 1) * S
        faces.append((a + 0, a + 1, b + 1, b + 0))  # front left
        faces.append((a + 1, a + 2, b + 2, b + 1))  # front right
        faces.append((a + 4, a + 3, b + 3, b + 4))  # back
        faces.append((a + 3, a + 0, b + 0, b + 3))  # left side
        faces.append((a + 2, a + 4, b + 4, b + 2))  # right side
    for e in (0, (m - 1) * S):  # end caps: 3 triangles (front-left/centre/right are collinear)
        faces += [(e + 0, e + 1, e + 3), (e + 1, e + 4, e + 3), (e + 1, e + 2, e + 4)]
    return recalc_normals(Piece(verts, faces, color))


# ------------------------------------------------------------------ emblems (ART_DIRECTION 3)

def _star(points, r_out, r_in, rot=math.pi / 2):
    out = []
    for i in range(points * 2):
        r = r_out if i % 2 == 0 else r_in
        a = rot + math.pi * i / points
        out.append((math.cos(a) * r, math.sin(a) * r))
    return out


FLAME = [(0.0, -1.0), (0.42, -0.92), (0.66, -0.66), (0.76, -0.3), (0.66, 0.06), (0.8, 0.44), (0.46, 0.18),
         (0.38, 0.52), (0.18, 1.12), (0.04, 0.62), (-0.2, 0.36), (-0.4, 0.76), (-0.62, 0.32), (-0.76, -0.16),
         (-0.68, -0.6), (-0.42, -0.9)]
CROWN = [(-0.95, -0.62), (0.95, -0.62), (0.92, -0.18), (1.04, 0.6), (0.46, 0.02), (0.0, 0.86), (-0.46, 0.02),
         (-1.04, 0.6), (-0.92, -0.18)]


# The ONE Sunspire sun of the kit (banners, shields, signs, tabards): every generator draws it from
# `sun_outlines` (via `emblem("sun")`, `sun_badge`, or its own prisms of the same outlines).
SUN_RAYS, SUN_DISC = "gold_dark", "yellow_shutter"  # deep gold: darker than ivory, gold cloth and sky
SUN_FIELD, SUN_RIM = "yellow_accent", "yellow_trim"  # its backing on gold: ivory roundel, deep-bronze rim
SUN_ROUNDEL = 1.28  # roundel outer radius / sun ray radius (as on the castle crests)


def sun_outlines(s):
    """(rays, disc): CCW (x, z) outlines of the kit-wide sun with ray radius `s`, centred on the
    origin: 8 long pointed rays (valleys at 0.4 s) and a 16-sided disc (0.56 s) that covers the
    valleys, so sun + rays read as one round deep-gold shape, never a cog, flower or star."""
    rays = [(x * s, z * s) for x, z in _star(8, 1.0, 0.4, rot=math.pi / 2)]
    angles = [math.pi / 2 + math.tau * i / 16 for i in range(16)]
    disc = [(math.cos(a) * 0.56 * s, math.sin(a) * 0.56 * s) for a in angles]
    return rays, disc


def roundel(r, depth, seg=12, rim=0.12, field=SUN_FIELD, rim_color=SUN_RIM, mid=False):
    """Round plaque in the XZ plane, centred on the origin, front at y = -depth/2: a `field` face
    inside a `rim_color` band rim * r wide (sides and back in the rim colour too), ONE closed piece.
    It is the backing that keeps the gold sun off gold cloth (D-033: never an emblem on its own
    colour). Front and back are fans around centre vertices, so `bend_onto` can lay it on a gently
    waving cloth (6 * seg tris); mid=True adds a half-radius ring of seg / 2 points for strongly
    waving cloth (7 * seg tris, seg even)."""
    d = depth / 2

    def circle(rr, n, y):
        return [(math.cos(math.pi / 2 + math.tau * i / n) * rr, y, math.sin(math.pi / 2 + math.tau * i / n) * rr)
                for i in range(n)]

    m = seg // 2 if mid else 0
    verts = [(0.0, -d, 0.0)] + circle(r * 0.5, m, -d)  # 0 = front centre, 1..m = half ring
    ia = 1 + m  # inner (field edge) ring, then outer ring front / back, then back centre
    verts += circle(r * (1 - rim), seg, -d)
    verts += circle(r, seg, -d)
    verts += circle(r, seg, d)
    verts.append((0.0, d, 0.0))
    of, ob, bc = ia + seg, ia + 2 * seg, ia + 3 * seg
    faces, cols = [], []

    def add(f, c):
        faces.append(f)
        cols.append(c)

    if mid:
        for j in range(m):
            j2 = (j + 1) % m
            a, a2 = 1 + j, 1 + j2
            b0, b1, b2 = ia + 2 * j, ia + 2 * j + 1, ia + (2 * j + 2) % seg
            add((0, a, a2), field)
            add((a, b0, b1), field)
            add((a, b1, a2), field)
            add((a2, b1, b2), field)
    for k in range(seg):
        k2 = (k + 1) % seg
        if not mid:
            add((0, ia + k, ia + k2), field)
        add((ia + k, of + k, of + k2, ia + k2), rim_color)  # rim band
        add((of + k, ob + k, ob + k2, of + k2), rim_color)  # side
        add((bc, ob + k2, ob + k), rim_color)  # back
    p = recalc_normals(Piece(verts, faces, rim_color))  # (keeps the face order, drops face colours)
    p.face_colors = cols
    return p


def sun_badge(r, depth, seg=12, mid=None, roundel_mid=False, sun_depth=None):
    """The kit-wide sun on its ivory roundel with a bronze rim (outer radius r), for gold fields:
    [roundel, rays, disc] centred on the origin, the roundel `depth` thick around y = 0, the sun
    (`sun_depth` thick, default 1.4 x depth) standing proud of the roundel front with 30 % of its
    depth sunk into it. mid / roundel_mid: see `emblem` / `roundel` (bending onto cloth)."""
    out = [roundel(r, depth, seg, mid=roundel_mid)]
    sd = sun_depth or depth * 1.4
    for q in emblem("sun", 2 * r / SUN_ROUNDEL, None, None, depth=sd, mid=mid):
        out.append(q.move(0, -depth / 2 - sd * 0.2, 0))
    return out


def emblem(kind, size, color, accent, depth=0.22, mid=0.5):
    """Kingdom emblem as raised geometry in the XZ plane, centred on the origin, front at
    -Y, about `size` studs across. kind: crown | star | oak | sun (flame: retired, kept for
    old callers; oak_tilted: the earlier leaf, kept so committed banner geometry stays frozen). mid=None for
    emblems that stay flat (cheaper); keep the mid ring when bending onto cloth."""
    s = size / 2
    out = []
    if kind == "flame":
        pts = [(x * s, z * s) for x, z in FLAME]
        out.append(fan_solid(pts, depth, color, center=(0.0, -0.3 * s), mid=mid))
        core = [(0.0, -0.95), (0.4, -0.78), (0.5, -0.4), (0.36, -0.02), (0.1, 0.42), (-0.1, 0.0), (-0.36, -0.2),
                (-0.46, -0.6)]  # glowing inner tongue
        out.append(fan_solid([(x * s * 0.8, z * s * 0.8) for x, z in core], depth, accent,
                             center=(0.0, -0.5 * s), mid=None).move(0, -depth * 0.55, 0))
    elif kind == "crown":
        pts = [(x * s, z * s) for x, z in CROWN]
        out.append(fan_solid(pts, depth, color, center=(0.0, -0.55 * s), mid=mid))
        out.append(box(1.9 * s, depth, 0.22 * s, accent, base=False).move(0, -depth * 0.6, -0.4 * s))
        for x, z in ((1.04, 0.6), (0.0, 0.86), (-1.04, 0.6)):
            gem = lathe([(0.0, -0.17 * s), (0.17 * s, 0.0), (0.0, 0.17 * s)], 4, accent)
            out.append(gem.rotate(math.pi / 2, "X").move(x * s, -depth * 0.5, z * s + 0.08 * s))
    elif kind == "star":
        out.append(fan_solid([(x * s, z * s) for x, z in _star(5, 1.0, 0.42)], depth, color, mid=mid))
        out.append(fan_solid([(x * s, z * s) for x, z in _star(5, 0.36, 0.16)], depth, accent, mid=None)
                   .move(0, -depth * 0.6, 0))
    elif kind == "sun":
        # Sunspire sun (no purple; fixed colours, `color` / `accent` are ignored): ONE deep-gold
        # silhouette, a big round 16-sided disc with 8 long pointed rays, darker than every field it
        # sits on (ivory roundel, gold cloth, sky), so the whole sun is the figure. The ray valleys hide
        # under the disc and the disc is only 0.3 x depth proud of the rays. (The earlier pale disc,
        # raised 0.85 x depth over a dark bronze ring, nearly matched the ivory roundel: the dark ring
        # was the figure, and parallax / the key light's shadow thinned one side into a "C" crescent.)
        rays, disc = sun_outlines(s)
        out.append(fan_solid(rays, depth, SUN_RAYS, mid=mid))
        out.append(fan_solid(disc, depth, SUN_DISC, mid=None).move(0, -depth * 0.3, 0))
    elif kind == "oak":
        # full oak leaf (reads at 80 studs, never a feather): wide and mirror-symmetric, 4 rounded
        # lobes per side with deep sinuses, a rounded tip lobe, midrib and a visible stem.
        # Concave outline -> prism (the builder triangulates the caps).
        lobes = ((-0.46, 0.56), (-0.1, 0.8), (0.26, 0.8), (0.6, 0.6))  # (z, half-width at lobe tip)
        sinus = (0.3, 0.44, 0.44, 0.34)
        right = [(0.1, -0.84)]
        for (zc, w), sw in zip(lobes, sinus):
            right.append((sw, zc - 0.17))  # sinus below the lobe
            right += [(w * 0.86, zc - 0.09), (w, zc), (w * 0.86, zc + 0.09)]
        right += [(0.26, 0.79), (0.3, 0.9), (0.15, 1.02)]
        outline = right + [(0.0, 1.06)] + [(-x, z) for x, z in reversed(right)]
        from lib.geo import prism
        out.append(prism([(x * s, z * s) for x, z in outline], depth, color, axis="Y"))
        out.append(box(0.1 * s, depth, 1.7 * s, accent, base=False).move(0, -depth * 0.55, 0.08 * s))  # midrib
        out.append(box(0.16 * s, depth, 0.5 * s, accent, base=False).move(0, 0, -1.04 * s))  # stem
    elif kind == "oak_tilted":
        # legacy (prop_banner, frozen geometry): elongated leaf, 4 rounded lobes per side STAGGERED (no mirror
        # symmetry), deep sinuses, a midrib and a visible stem, tilted ~14 deg so it reads as a
        # leaf, not a rosette. Concave outline -> prism (the builder triangulates the caps).
        def env(z):
            return 0.56 * math.sin(math.pi * min(1.0, max(0.0, (z + 0.8) / 1.82))) ** 0.75

        def side(lobes, sgn):
            pts = []
            prev = -0.78
            for zc in lobes:
                zs = (prev + zc) / 2 if prev > -0.78 else zc - 0.16
                pts.append((sgn * 0.4 * env(zs) + sgn * 0.04, zs))  # sinus
                for dz, f in ((-0.08, 0.84), (0.0, 1.0), (0.08, 0.84)):  # rounded lobe
                    pts.append((sgn * (f * env(zc + dz) + 0.05), zc + dz))
                prev = zc
            pts.append((sgn * 0.12, 0.88))
            return pts

        right = [(0.07, -0.8)] + side((-0.42, -0.04, 0.33, 0.66), 1)
        left = [(-0.07, -0.8)] + side((-0.26, 0.13, 0.5, 0.8), -1)
        outline = right + [(0.0, 1.02)] + list(reversed(left))
        from lib.geo import prism
        leaf = [prism([(x * s, z * s) for x, z in outline], depth, color, axis="Y")]
        leaf.append(box(0.09 * s, depth, 1.62 * s, accent, base=False).move(0, -depth * 0.55, 0.06 * s))  # midrib
        stem = box(0.12 * s, depth, 0.46 * s, color, base=False).rotate(-0.25, "Y")
        leaf.append(stem.move(0.05 * s, 0, -0.98 * s))
        for pc in leaf:
            pc.rotate(-0.24, "Y")
        out += leaf
    else:
        raise ValueError(kind)
    return out


def bend_onto(pieces, fn):
    """Add fn(x, z) to every vertex's y (lay emblems onto a waving cloth)."""
    for p in pieces:
        p.bend(lambda v: (v.x, v.y + fn(v.x, v.z), v.z))
    return pieces


# ------------------------------------------------------------------ wood, iron, rope

def wheel(radius, width=0.7, spokes=8, seg=12, wood="wood", tyre="iron_dark", hub="wood_dark", cap="iron",
          lip=False, hub_seg=8):
    """Spoked cart/siege wheel: felloe with an iron tyre band, turned hub, spokes. Axle
    along X, centred on the origin (caller moves it to (x, y, radius))."""
    out = []
    w = width / 2
    t = max(0.14, radius * 0.07)  # iron tyre thickness
    fel = max(0.32, radius * 0.17)  # felloe depth
    r_in = radius - t - fel
    # one ring: wooden felloe inside, iron band outside
    if lip:  # tyre proud of the felloe sides
        prof = [(r_in, -w), (radius - t, -w), (radius - t, -w - 0.04), (radius, -w - 0.04), (radius, w + 0.04),
                (radius - t, w + 0.04), (radius - t, w), (r_in, w)]
        cols = [wood, tyre, tyre, tyre, tyre, tyre, wood, wood]
    else:
        prof = [(r_in, -w), (radius - t, -w), (radius, -w), (radius, w), (radius - t, w), (r_in, w)]
        cols = [wood, tyre, tyre, tyre, wood, wood]
    out.append(sweep_loop(prof, seg, wood, phase=math.pi / seg, colors=cols))
    hr = max(0.32, radius * 0.16)
    out.append(lathe([(0.0, -w - 0.55), (hr * 0.7, -w - 0.5), (hr, -w * 0.6), (hr, w * 0.6), (hr * 0.7, w + 0.5),
                      (0.0, w + 0.55)], hub_seg, hub))
    if cap:
        out.append(cylinder(hr * 0.75, hr * 0.75, 0.16, 8, cap).move(0, 0, w + 0.32))
        out.append(cylinder(hr * 0.75, hr * 0.75, 0.16, 8, cap).move(0, 0, -w - 0.48))
    sw = max(0.18, radius * 0.075)
    for i in range(spokes):
        a = math.tau * i / spokes
        p0 = Vector((math.cos(a) * hr * 0.8, math.sin(a) * hr * 0.8, 0))
        p1 = Vector((math.cos(a) * (r_in + 0.08), math.sin(a) * (r_in + 0.08), 0))
        out.append(kit.oriented_box(p0, p1, sw, sw * 1.2, wood, Vector((0, 0, 1))))
    for p in out:
        p.rotate(math.pi / 2, "Y")
    return out


def rope(points, r=0.12, seg=5, color="rope"):
    return tube(points, [r] * len(points), seg, color)


def lashing(radius, height, color="rope", seg=8, turns=2):
    """Rope wrapped around a post (stacked flattened rings), axis Z, base z=0."""
    out = []
    for i in range(turns):
        h = height / turns
        out.append(lathe([(radius, 0.0), (radius + 0.13, h * 0.2), (radius + 0.13, h * 0.8), (radius, h)], seg,
                         color, phase=0.4 * i).move(0, 0, i * h))
    return out


def barrel(h=2.5, r=1.0, color="wood", hoop="iron_dark", seg=8, lid=True):
    out = [lathe([(0.0, 0.0), (r, 0.0), (r * 1.18, h * 0.4), (r * 1.18, h * 0.6), (r, h), (0.0, h)], seg, color)]
    for zz in (h * 0.2, h * 0.74):
        out.append(cylinder(r * 1.12, r * 1.12, h * 0.07, seg, hoop).move(0, 0, zz))
    if lid:
        out.append(cylinder(r * 0.86, r * 0.86, 0.06, seg, "wood_dark").move(0, 0, h - 0.02))
    return out


def crate(sx, sy, sz, color="wood_light", trim="wood_dark", rng=None, brace=True):
    """Bevelled plank crate with darker edge battens and a diagonal brace on the front."""
    out = [kit.bbox(sx, sy, sz, color, min(0.14, 0.1 * min(sx, sy, sz) + 0.04))]
    b = 0.22
    for zz in (0.04, sz - b - 0.04):  # horizontal battens round the box
        out.append(box(sx + 0.08, sy + 0.08, b, trim).move(0, 0, zz))
    if brace:
        p0 = Vector((-sx / 2 + 0.2, -sy / 2 - 0.05, b + 0.05))
        p1 = Vector((sx / 2 - 0.2, -sy / 2 - 0.05, sz - b - 0.1))
        out.append(kit.oriented_box(p0, p1, 0.24, 0.1, trim))
    return out


def sack(rng, r=0.9, h=1.9, color="canvas", tie="rope", lean=0.0):
    """Soft grain sack: slumped, flattened body (wide bottom), short tied neck with a
    folded tuft on top. Smooth shaded, noise-displaced so no two sacks match."""
    body = lathe([(0.0, 0.0), (r * 0.92, 0.02), (r * 1.1, h * 0.25), (r * 1.02, h * 0.58), (r * 0.72, h * 0.8),
                  (r * 0.36, h * 0.88), (r * 0.44, h * 0.97), (0.0, h * 1.02)], 7, color, smooth=True)
    body.noise_displace(r * 0.14, freq=1.2, seed=rng.uniform(0, 50), center=(0, 0, h * 0.4))
    body.scale(1.0, rng.uniform(0.66, 0.8), 1.0)
    out = [body.paint(grad=("range", 0.25, 0.9))]
    out.append(cylinder(r * 0.4, r * 0.4, h * 0.07, 6, tie).move(0, 0, h * 0.84))
    if lean:
        for p in out:
            p.rotate(lean, "X")
    return out


def stone_ball(rng, r, color="stone", subdiv=2):
    from lib.geo import icosphere
    s = icosphere(r, subdiv, color)
    s.noise_displace(r * 0.12, 1.4, rng.uniform(0, 50))
    return s.move(0, 0, r * 0.92)


def kcol(k, role):
    return kingdom_color(k, role)


def field(k):
    """Banner / flag / shield field colour (ART_DIRECTION 3: emerald flags use the bright
    `green_cloth_light` field, never the dark roof green)."""
    return kcol(k, "cloth_light") if k == "green" else kcol(k, "cloth")


def emblem_colors(k, kind):
    """(main, accent) colours of a kingdom emblem on its field (crown in gold with cream band and
    gems, star / oak in cream or bronze; the sun uses its own fixed colours)."""
    if kind == "crown":
        return kcol(k, "trim"), kcol(k, "emblem")
    return kcol(k, "emblem"), kcol(k, "trim")  # star / oak: ivory emblem, metal accent


def border(k):
    """Border / trim band colour on kingdom cloth: emerald gets an ivory border, gold gets
    deep bronze (never purple), crimson gold, azure silver."""
    return kcol(k, "accent") if k == "green" else kcol(k, "trim")


__all__ = ["KINGDOMS", "sweep_loop", "ring_solid", "sheet", "fan_solid", "strip_solid", "emblem", "bend_onto",
           "SUN_RAYS", "SUN_DISC", "SUN_FIELD", "SUN_RIM", "SUN_ROUNDEL", "sun_outlines", "roundel", "sun_badge",
           "wheel", "rope", "lashing", "barrel", "crate", "sack", "stone_ball", "kcol", "field", "border", "emblem_colors"]
