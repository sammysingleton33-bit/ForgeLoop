"""Private helpers shared by the farm generators (farm_field, farm_fence, farm_haystack,
farm_windmill, farm_barn). Not a generator (leading underscore: build.py skips it).

Everything returns Pieces (or lists of Pieces) in local coordinates, base at z=0, so the
callers move them into place. All randomness comes from the caller's `rng` (b.rng).
"""

import math

from lib import kit
from lib.geo import Piece, Vector, box, cylinder, frustum_box, icosphere, lathe, prism
from lib.geo import recalc_normals, tube  # noqa: F401  (re-exported)

HAY = ("hay", "straw", "thatch_light", "hay")
WHEAT = ("wheat", "straw", "thatch_light", "straw", "wheat")


# ------------------------------------------------------------------ tiny organic bits

def spindle(r, h, color, seg=3, mid=0.5):
    """Double cone (bipyramid): wheat ears, leaves, straw tufts. 2*seg tris."""
    return lathe([(0.0, 0.0), (r, h * mid), (0.0, h)], seg, color)


def blade(r, h, color, seg=3):
    """Tapered blade / spike standing on z=0 (seg + seg-2 tris)."""
    return lathe([(r, 0.0), (0.0, h)], seg, color)


def leaf(length, width, color, thick=0.12, seg=4):
    """Flat lens-shaped leaf lying along +X from the origin, width across Y, `thick` in Z."""
    p = lathe([(0.0, 0.0), (width / 2, length * 0.45), (0.0, length)], seg, color, phase=0.0)
    p.rotate(math.pi / 2, "Y")  # lathe axis +Z -> +X
    p.verts = [Vector((v.x, v.y, v.z * thick / width)) for v in p.verts]
    return p


def wattle_band(length, h, t=0.5, colors=("bark_light", "wood_light"), bumps=3):
    """Woven hurdle panel along X (centred, base z=0): rounded withy rods on both faces, rods
    alternating between two colours so the weave reads."""
    if isinstance(colors, str):
        colors = (colors, colors)
    n = bumps * 2
    front = [(-t / 2 - (0.11 if i % 2 else 0.0), h * i / n) for i in range(n + 1)]
    back = [(t / 2 + (0.11 if i % 2 else 0.0), h * i / n) for i in range(n, -1, -1)]
    poly = front + back  # edges 0..n-1 front rods, n = top, n+1..2n back rods, 2n+1 = bottom
    p = prism(poly, length, colors[0], axis="X")  # (y, z) profile, depth along X
    fcols = [colors[0], colors[0]]  # the two caps come first
    for i in range(len(poly)):
        if i < n:
            fcols.append(colors[(i // 2) % 2])
        elif n < i < 2 * n + 1:
            fcols.append(colors[((2 * n - i) // 2) % 2])
        else:
            fcols.append(colors[0])
    p.face_colors = fcols
    return p


def stake(h, r, color="bark", seg=4, point=0.35):
    """Round(ish) stake with a pointed or flat top."""
    if point > 0:
        return lathe([(r, 0.0), (r * 0.92, h - point), (0.0, h)], seg, color)
    return cylinder(r, r * 0.92, h, seg, color)


def fieldstone(rng, L, d, h, color):
    """Rough dry-stone block: tapered, jittered box (12 tris)."""
    s = frustum_box(L, d, L * rng.uniform(0.78, 0.92), d * rng.uniform(0.7, 0.88), h, color)
    s.jitter(rng, min(0.12, h * 0.12))
    return s


def stone_row(rng, p0, p1, h=1.0, d=1.1, block=(1.6, 2.6), colors=("stone", "stone_light", "granite")):
    """Single course of field stones along a straight line (z=0)."""
    out = []
    p0, p1 = Vector(p0), Vector(p1)
    seg = p1 - p0
    L = seg.length
    ang = math.atan2(seg.y, seg.x)
    u = 0.0
    while u < L - 0.3:
        bl = rng.uniform(*block)
        if L - u - bl < block[0] * 0.6:
            bl = L - u
        mid = p0 + seg.normalized() * (u + bl / 2)
        s = fieldstone(rng, bl - 0.12, d * rng.uniform(0.9, 1.1), h * rng.uniform(0.8, 1.15), rng.choice(colors))
        s.rotate(ang + rng.uniform(-0.05, 0.05), "Z").move(mid.x, mid.y, 0)
        out.append(s.paint(tint=rng.uniform(0, 1), grad=("range", 0.25, 0.9)))
        u += bl
    return out


def sack(rng, h=1.7, color="canvas", tie="rope"):
    """Grain sack: lumpy lathe with a tied neck and tuft."""
    r = h * 0.36
    s = lathe([(0.0, 0.0), (r * 0.9, 0.02), (r * 1.05, h * 0.3), (r, h * 0.62), (r * 0.55, h * 0.82),
               (r * 0.3, h * 0.88), (0.0, h * 0.9)], 6, color, smooth=True)
    s.scale(1.0, rng.uniform(0.75, 0.9), 1.0)
    s.jitter(rng, 0.05)
    s.paint(grad=("range", 0.2, 0.9))
    out = [s]
    out.append(cylinder(r * 0.36, r * 0.36, h * 0.07, 5, tie).move(0, 0, h * 0.84))
    out.append(lathe([(r * 0.3, 0.0), (r * 0.45, h * 0.12), (0.0, h * 0.16)], 5, color).move(0, 0, h * 0.9))
    return out


def basket(rng, r=0.9, h=0.9, color="wood_light", fill=None):
    out = [lathe([(r * 0.75, 0.0), (r, h), (r * 0.88, h), (r * 0.66, 0.12)], 7, color, cap_bottom=True)]
    out.append(cylinder(r * 1.03, r * 1.03, 0.14, 7, "wood").move(0, 0, h - 0.14))
    if fill:
        out.append(lathe([(r * 0.92, 0.0), (r * 0.7, 0.3), (0.0, 0.42)], 7, fill, smooth=True).move(0, 0, h - 0.25))
    return out


def pitchfork(length=6.0, tines=3):
    """Pitchfork lying along +Z from the origin (handle bottom at 0)."""
    out = [cylinder(0.11, 0.11, length * 0.8, 5, "wood_light")]
    z = length * 0.8
    out.append(box(0.16, 0.16, 0.3, "iron_dark").move(0, 0, z - 0.1))
    span = 0.9
    out.append(box(span + 0.12, 0.12, 0.14, "iron").move(0, 0, z + 0.15))
    for i in range(tines):
        u = -span / 2 + span * i / max(1, tines - 1)
        out.append(lathe([(0.06, 0.0), (0.0, length * 0.2)], 3, "iron").move(u, 0, z + 0.2))
    return out


def rake(length=5.6, teeth=6):
    out = [cylinder(0.1, 0.1, length, 5, "wood_light")]
    out.append(box(1.6, 0.18, 0.18, "wood").move(0, 0, length - 0.05))
    for i in range(teeth):
        u = -0.7 + 1.4 * i / (teeth - 1)
        out.append(box(0.08, 0.08, 0.32, "wood_dark").move(u, 0, length + 0.12))
    return out


def wheel(r=1.6, w=0.35, spokes=6, color="wood", rim="iron_dark", seg=12, hub_len=0.9):
    """Cart wheel in the XZ plane (axle along Y), centred at the origin: felloe ring with an
    iron tyre face, hub and spokes."""
    ring = _ring_xz(r, r - 0.34, w, seg, color)
    ring.face_colors = [rim if fi % 4 == 0 else color for fi in range(len(ring.faces))]
    out = [ring]
    hub = cylinder(0.42, 0.36, hub_len, 7, "wood_dark")
    hub.move(0, 0, -hub_len / 2).rotate(math.pi / 2, "X")
    out.append(hub)
    ri = r - 0.34
    for i in range(spokes):
        a = math.tau * i / spokes + 0.2
        p0 = Vector((math.cos(a) * 0.35, 0, math.sin(a) * 0.35))
        p1 = Vector((math.cos(a) * (ri + 0.05), 0, math.sin(a) * (ri + 0.05)))
        out.append(kit.oriented_box(p0, p1, 0.2, 0.2, color, Vector((0, 1, 0))))
    return out


def _ring_xz(ro, rin, w, seg, color):
    """Closed annulus (square section) in the XZ plane, axis along Y."""
    verts, faces = [], []
    for k in range(seg):
        a = math.tau * k / seg
        c, s = math.cos(a), math.sin(a)
        for rr, yy in ((ro, -w / 2), (ro, w / 2), (rin, w / 2), (rin, -w / 2)):
            verts.append((c * rr, yy, s * rr))
    for k in range(seg):
        a0, a1 = k * 4, ((k + 1) % seg) * 4
        for j in range(4):
            j1 = (j + 1) % 4
            faces.append((a0 + j, a1 + j, a1 + j1, a0 + j1))
    return recalc_normals(Piece(verts, faces, color))


def scarecrow(rng, cloth="tunic_red", hat="hay_dark", h=6.8):
    """Scarecrow on a pole: crossbar arms, stuffed tunic, sack head with a straw hat and straw tufts."""
    out = []
    out.append(box(0.32, 0.32, h, "wood").jitter(rng, 0.03))
    arm_z = h * 0.68
    out.append(box(4.8, 0.26, 0.26, "wood").move(0, 0, arm_z))
    # tunic (stuffed body)
    body = frustum_box(1.9, 1.0, 1.5, 0.85, 2.3, cloth)
    body.jitter(rng, 0.06)
    out.append(body.move(0, 0, arm_z - 1.85))
    out.append(box(1.98, 1.06, 0.22, "rope").move(0, 0, arm_z - 1.2))  # belt
    # sleeves along the crossbar
    for s in (-1, 1):
        sl = frustum_box(0.65, 0.65, 0.5, 0.5, 1.7, cloth)
        sl.rotate(-s * math.pi / 2, "Y").move(s * 0.65, 0, arm_z + 0.1)
        out.append(sl)
        for k in range(3):  # straw out of the cuffs
            t = blade(0.13, 0.75, "straw").rotate(-s * math.pi / 2 + rng.uniform(-0.5, 0.5), "Y")
            out.append(t.move(s * 2.3, rng.uniform(-0.15, 0.15), arm_z + 0.1 + rng.uniform(-0.12, 0.12)))
    for k in range(5):  # straw under the tunic
        t = blade(0.14, 0.75, "straw").rotate(math.pi + rng.uniform(-0.4, 0.4), "Y")
        out.append(t.move(-0.7 + 0.35 * k, rng.uniform(-0.2, 0.2), arm_z - 1.7))
    # head: lumpy sack + hat
    head = icosphere(0.62, 1, "apron")
    head.scale(1.0, 0.9, 1.1).jitter(rng, 0.05)
    out.append(head.move(0, 0, arm_z + 0.95).paint(smooth=True))
    out.append(cylinder(0.3, 0.3, 0.16, 5, "rope").move(0, 0, arm_z + 0.25))
    out.append(lathe([(1.15, 0.0), (1.1, 0.14), (0.55, 0.18), (0.45, 0.75), (0.0, 0.85)], 7, hat)
               .rotate(rng.uniform(-0.15, 0.15), "Y").move(0, 0, arm_z + 1.4))
    return out


def round_bale(r=1.7, w=2.6, seg=10, color="hay"):
    """Round hay bale lying on its side (axis along X), base z=0. Dished end faces with a dark
    core and lighter rolled ring so the spiral reads; rounded rims."""
    prof = [(0.0, -w / 2 + 0.08), (r * 0.42, -w / 2 + 0.02), (r * 0.8, -w / 2), (r * 0.97, -w / 2 + 0.13),
            (r, -w / 2 + 0.38), (r, w / 2 - 0.38), (r * 0.97, w / 2 - 0.13), (r * 0.8, w / 2),
            (r * 0.42, w / 2 - 0.02), (0.0, w / 2 - 0.08)]
    p = lathe(prof, seg, color, smooth=True)
    bands = ["hay_dark", "straw", color, color, color, color, color, "straw", "hay_dark"]
    p.face_colors = [bands[min(len(bands) - 1, fi // seg)] for fi in range(len(p.faces))]
    p.rotate(math.pi / 2, "Y").move(0, 0, r)
    return p


def twine_ring(r, seg=10, color="hay_dark", t=0.12):
    """Thin band around a round bale (axis X), centred at the origin."""
    c = cylinder(r, r, t, seg, color)
    c.move(0, 0, -t / 2).rotate(math.pi / 2, "Y")
    return c


def hay_mound(rng, prof, seg=12, color="hay", amount=0.3, freq=0.55, sx=1.0, sy=1.0, bands=None):
    """Lumpy smooth hay mass from a lathe profile, noise-displaced, optionally stretched.
    `bands`: optional list of palette names per profile segment (layer colours)."""
    p = lathe(prof, seg, color, smooth=True)
    if bands:
        nb = len(prof) - 1
        p.face_colors = [bands[min(nb - 1, fi // seg) % len(bands)] if fi < nb * seg else color
                         for fi in range(len(p.faces))]
    p.scale(sx, sy, 1.0)
    top = max(z for _, z in prof)
    p.noise_displace(amount, freq, rng.uniform(0, 100), center=(0, 0, top * 0.4))
    p.verts = [Vector((v.x, v.y, max(0.0, v.z))) for v in p.verts]
    return p.paint(grad=("range", 0.15, 1.0))


def layered_profile(radius_fn, h, layers, lip=0.32, tuck=0.12, base=0.0):
    """Lathe profile of a stacked hay rick / stog: a dome R(z) wrapped in overlapping thatch-like
    layers. Returns (profile, band_colours) with dark lip undersides and alternating layer tones."""
    prof = [(0.0, base), (radius_fn(0.0) * 0.92, base)]
    cols = ["hay_dark"]
    zs = [h * (k + 0.12 * ((k * 7919) % 5 - 2) / 2) / (layers + 1) for k in range(1, layers + 1)]
    z_prev = 0.0
    tones = ("hay", "thatch")
    for i, z in enumerate(zs):
        zm = (z_prev + z) / 2
        prof.append((radius_fn(zm) + 0.05, base + zm))
        cols.append(tones[i % 2])
        prof.append((radius_fn(z) - tuck, base + z - 0.04))
        cols.append(tones[i % 2])
        prof.append((radius_fn(z) + lip, base + z))
        cols.append("hay_dark")  # lip underside (the short step face)
        z_prev = z
    zm = (z_prev + h) / 2
    prof.append((max(0.15, radius_fn(zm)), base + zm))
    cols.append(tones[len(zs) % 2])
    prof.append((0.0, base + h))
    cols.append(tones[len(zs) % 2])
    return prof, cols


def straw_tufts(rng, prof, n, sx=1.0, sy=1.0, z0=0.0, colors=("straw", "hay", "thatch_light"), lo=0.15, hi=0.85):
    """Short straw blades poking out of a lathe-profile hay surface (texture accent)."""
    out = []
    zs = [z for _, z in prof]
    zmax = max(zs)
    for k in range(n):
        z = zmax * rng.uniform(lo, hi)
        r = None
        for (ra, za), (rb, zb) in zip(prof, prof[1:]):
            if min(za, zb) <= z <= max(za, zb) and abs(zb - za) > 1e-6:
                r = ra + (rb - ra) * (z - za) / (zb - za)
                break
        if r is None:
            continue
        a = rng.uniform(0, math.tau)
        bl = blade(0.13, rng.uniform(0.75, 1.25), rng.choice(colors))
        bl.rotate(rng.uniform(1.55, 2.1), "Y").rotate(a, "Z")  # hang outwards and down
        out.append(bl.move(math.cos(a) * r * sx * 0.97, math.sin(a) * r * sy * 0.97, z0 + z))
    return out


def square_bale(rng, L=3.0, w=1.6, h=1.4, color="hay", twine="hay_dark"):
    out = [kit.bbox(L, w, h, color, 0.14).jitter(rng, 0.04).paint(grad=("range", 0.25, 0.95))]
    for u in (-L * 0.25, L * 0.25):
        out.append(box(0.12, w + 0.06, h + 0.06, twine).move(u, 0, -0.03))
    return out


EMBLEMS = {"red": "crown", "blue": "star", "green": "oak", "yellow": "sun"}


def kingdom_banner(k, h=5.6, w=2.6, depth=0.14):
    """Hanging kingdom banner in the XZ plane facing -Y, top bar at z=h, swallowtail bottom at z=0:
    cloth in the kingdom colour, dark hem at the top, trim edges and the kingdom emblem
    (crown / star / oak leaf / sun, from the shared kingdom-props helper)."""
    from lib.palette import kingdom_color
    from generators._kingdom_props_common import border, emblem, field

    cloth = field(k)  # emerald flies the bright cloth (ART_DIRECTION 3)
    out = [prism([(-w / 2, 0.0), (0.0, 0.9), (w / 2, 0.0), (w / 2, h), (-w / 2, h)], depth, cloth, axis="Y")
           .paint(grad=("range", 0.35, 0.95))]
    out.append(box(w + 0.1, depth + 0.06, 0.5, kingdom_color(k, "cloth_dark")).move(0, 0, h - 0.5))
    for sx in (-1, 1):
        out.append(box(0.16, depth + 0.04, h - 1.0, border(k)).move(sx * (w / 2 - 0.08), 0, 0.5))
    out.append(cylinder(0.11, 0.11, w + 0.9, 5, "wood_dark").move(0, 0, -(w + 0.9) / 2).rotate(math.pi / 2, "Y")
               .move(0, 0, h + 0.12))
    ey = -depth / 2 - 0.02
    if EMBLEMS[k] == "sun":
        # never an emblem on its own colour: the gold sun sits on an ivory roundel with a bronze rim
        for r, col, dy in ((w * 0.42, kingdom_color(k, "trim"), 0.0), (w * 0.37, kingdom_color(k, "accent"), -0.03)):
            out.append(cylinder(r, r, 0.06, 16, col).rotate(math.pi / 2, "X").move(0, ey + dy, h * 0.58))
        ey -= 0.08
    for q in emblem(EMBLEMS[k], w * 0.62, kingdom_color(k, "emblem"), kingdom_color(k, "trim"), depth=0.12, mid=None):
        out.append(q.move(0, ey, h * 0.58))
    return out


__all__ = ["HAY", "WHEAT", "spindle", "blade", "leaf", "wattle_band", "stake", "fieldstone", "stone_row", "sack",
           "basket", "pitchfork", "rake", "wheel", "scarecrow", "round_bale", "twine_ring", "hay_mound",
           "layered_profile", "straw_tufts", "square_bale", "tube", "EMBLEMS", "kingdom_banner"]
