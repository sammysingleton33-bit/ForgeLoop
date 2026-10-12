"""Shared medieval architecture parts. Every building generator uses these, which is what
keeps the castle, village and farm sets cohesive (same roof language, same timber sizes,
same window and door treatment, same bevels). See blender/ART_DIRECTION.md.

All functions return lists of Pieces (or one Piece) in local coordinates; callers move
them into place. Sizes are in studs at human scale (5.5-stud Roblox character).
Facades face -Y unless stated.
"""

import math

from .geo import Matrix, Piece, Vector, arch_poly, bevel, box, lathe, loft_rings, merge, prism, recalc_normals
from .geo import mnoise

# Human scale (Roblox R15 character ~5.5 studs): walkable doors, 11-stud storeys.
CHAR_H = 5.5
DOOR_W, DOOR_H = 4.4, 7.6
WIN_W, WIN_H, SILL_Z = 2.6, 3.4, 3.4
STOREY = 11.0
TIMBER = 0.62  # timber member width
TIMBER_OUT = 0.2  # how far timber stands proud of plaster
BEVEL = 0.18  # default chamfer for hard surfaces


def bbox(sx, sy, sz, color, bev=BEVEL, base=True, segments=1, **kw):
    """Bevelled box: the default building block for anything bigger than ~1 stud."""
    p = box(sx, sy, sz, color, base=base, **kw)
    return bevel(p, min(bev, 0.45 * min(sx, sy, sz)), segments=segments) if bev > 0 else p


def oriented_box(p0, p1, width, depth, color, normal=Vector((0, -1, 0)), bev=0.0, **kw):
    """Box running from p0 to p1 (a beam/brace), cross-section width x depth; `normal`
    is the wall normal (depth axis)."""
    p0, p1 = Vector(p0), Vector(p1)
    axis = p1 - p0
    length = axis.length
    z = axis.normalized()
    n = Vector(normal).normalized()
    x = n.cross(z)
    if x.length < 1e-6:
        x = z.orthogonal()
    x.normalize()
    y = z.cross(x)
    m = Matrix((x, y, z)).transposed().to_4x4()
    b = box(width, depth, length, color, base=True, **kw)
    if bev > 0:
        b = bevel(b, bev)
    b.transform(m)
    b.move(*p0)
    return b


# ------------------------------------------------------------------ walls

def wall_face_frame(length, height, axis, offset, color="timber", posts=3, braces=True, rng=None, skip=(),
                    rail=None):
    """Timber framing on one wall face (sole plate, top plate, posts, optional mid rail and
    diagonal braces). axis 'x': wall runs along X at y=offset (normal sign(offset) on Y);
    axis 'y': wall runs along Y at x=offset. `skip`: post indices left out (door bays)."""
    out = []
    sgn = 1 if offset >= 0 else -1
    nrm = Vector((0, sgn, 0)) if axis == "x" else Vector((sgn, 0, 0))
    t = TIMBER
    d = TIMBER_OUT * 2

    def P(u, z):
        return Vector((u, offset, z)) if axis == "x" else Vector((offset, u, z))

    half = length / 2
    for z in (t / 2, height - t / 2):
        out.append(oriented_box(P(-half, z), P(half, z), t, d, color, nrm))
    xs = [-half + t / 2 + (length - t) * i / (posts - 1) for i in range(posts)] if posts > 1 else [0.0]
    for i, u in enumerate(xs):
        if i in skip:
            continue
        out.append(oriented_box(P(u, 0), P(u, height), t, d, color, nrm))
    if rail:
        for i in range(len(xs) - 1):
            if i in skip or (i + 1) in skip:
                continue
            out.append(oriented_box(P(xs[i], rail), P(xs[i + 1], rail), t * 0.8, d * 0.9, color, nrm))
    if braces and len(xs) >= 2:
        for i in range(len(xs) - 1):
            if i in skip or (i + 1) in skip:
                continue
            a, b = xs[i], xs[i + 1]
            flip = (i % 2 == 0) == (rng.random() < 0.5 if rng else True)
            lo, hi = height * 0.06, height * 0.62
            if flip:
                out.append(oriented_box(P(a + t / 2, lo), P(b - t / 2, hi), t * 0.8, d * 0.85, color, nrm))
            else:
                out.append(oriented_box(P(b - t / 2, lo), P(a + t / 2, hi), t * 0.8, d * 0.85, color, nrm))
    return out


def window(width=WIN_W, height=WIN_H, frame="timber", shutter=None, glass="window_dark", sill="wood",
           arched=False, open_angle=0.35, mullion=True):
    """Window on a wall surface at y=0 facing -Y; centred on x=0, bottom of opening at z=0."""
    out = []
    t = 0.42
    if arched:
        pane = prism(arch_poly(width, height, 5), 0.16, glass)
        pane.move(0, -0.08, 0)
        out.append(pane)
    else:
        out.append(box(width, 0.16, height, glass).move(0, -0.08, 0))
    out.append(box(width + 2 * t, 0.4, t, frame).move(0, -0.2, height))  # head
    out.append(box(t, 0.4, height, frame).move(-width / 2 - t / 2, -0.2, 0))  # jambs
    out.append(box(t, 0.4, height, frame).move(width / 2 + t / 2, -0.2, 0))
    if mullion:
        out.append(box(0.22, 0.28, height, frame).move(0, -0.16, 0))
        out.append(box(width, 0.28, 0.22, frame).move(0, -0.16, height * 0.55))
    out.append(bbox(width + 2 * t + 0.5, 0.8, 0.36, sill, 0.1).move(0, -0.4, -0.36))
    if shutter:
        ws = width / 2 + 0.15
        for side in (-1, 1):
            sh = box(ws, 0.2, height + 0.15, shutter)
            bat1 = box(ws - 0.3, 0.12, 0.3, "timber").move(0, -0.14, height * 0.18)
            bat2 = box(ws - 0.3, 0.12, 0.3, "timber").move(0, -0.14, height * 0.72)
            s = merge([sh, bat1, bat2])
            s.move(side * ws / 2, 0, -0.08)
            s.rotate(-side * open_angle, "Z")
            s.move(side * (width / 2 + t), -0.42, 0)
            out.append(s)
    return out


def door(width=DOOR_W, height=DOOR_H, color="wood_dark", surround="stone_light", arched=True, step="stone"):
    """Arched plank door on a wall at y=0 facing -Y, centred on x=0, base z=0."""
    out = []
    if arched:
        leaf = prism(arch_poly(width, height, 6), 0.3, color)
    else:
        leaf = box(width, 0.3, height, color)
    leaf.move(0, -0.15, 0)
    out.append(leaf)
    spring = height - width / 2 if arched else height
    for u in (-width / 3, 0.0, width / 3):  # raised plank battens
        out.append(box(0.16, 0.12, spring - 0.3, "timber").move(u, -0.34, 0.15))
    for z in (height * 0.2, spring * 0.78):  # iron straps
        out.append(box(width * 0.9, 0.12, 0.28, "iron_dark").move(0, -0.38, z))
    out.append(box(0.3, 0.2, 0.3, "iron").move(width * 0.3, -0.5, height * 0.42))  # handle
    if surround:
        jw = 0.8
        out.append(bbox(jw, 0.7, spring, surround, 0.12).move(-width / 2 - jw / 2, -0.2, 0))
        out.append(bbox(jw, 0.7, spring, surround, 0.12).move(width / 2 + jw / 2, -0.2, 0))
        if arched:
            n = 7
            r = width / 2 + jw / 2
            for i in range(n):
                a = math.pi * (i + 0.5) / n
                seg = math.pi * r / n
                vs = bbox(jw * (1.15 if i == n // 2 else 1.0), 0.7, seg * 0.92, surround, 0.1, base=False)
                vs.rotate(-(a - math.pi / 2), "Y")
                vs.move(math.cos(a) * r, -0.2, spring + math.sin(a) * r)
                out.append(vs)
        else:
            out.append(bbox(width + 2 * jw, 0.7, jw, surround, 0.12).move(0, -0.2, height))
    if step:
        out.append(bbox(width + 2.0, 1.8, 0.45, step, 0.12).move(0, -0.9, -0.1))
    return out


# ------------------------------------------------------------------ roofs

def _slab(ridge, a, side, s0, s1, y0, y1, t, extra=0.0, color="thatch", lift=0.0):
    """One straight roof slab between slope distances s0..s1 (from the ridge), y0..y1 along
    the ridge, thickness t. side=+1 slopes down towards +X. `extra` tilts the slab about its
    upper edge (radians, positive = flatter, so the lower edge kicks out: shingle steps)."""
    ca, sa = math.cos(a), math.sin(a)
    d = Vector((side * ca, 0, -sa))
    n = Vector((side * sa, 0, ca))
    if extra:
        rot = Matrix.Rotation(-side * extra, 3, "Y")
        d2, n2 = rot @ d, rot @ n
    else:
        d2, n2 = d, n
    top = Vector(ridge) + d * s0 + n * lift
    pts = []
    for yy in (y0, y1):
        for s, nn in ((0, 0), (s1 - s0, 0), (s1 - s0, t), (0, t)):
            p = top + d2 * s + n2 * nn
            pts.append(Vector((p.x, yy, p.z)))
    f = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    return recalc_normals(Piece(pts, f, color))


def gable_roof(span, length, pitch_deg=45.0, overhang=1.2, gable_overhang=1.0, thickness=0.8,
               color="thatch", rows=5, ridge_color=None, style="tile", rng=None, trim="timber"):
    """Roof over walls of width `span` (X) and length `length` (Y), eaves at z=0, ridge along Y.

    style 'tile': stepped shingle rows + ridge cap + barge boards.
    style 'thatch': three thick rounded layers, wavy eaves and a rolled ridge.
    Returns (pieces, ridge_height)."""
    a = math.radians(pitch_deg)
    half = span / 2
    rise = half * math.tan(a)
    ridge = Vector((0, 0, rise))
    L = (half + overhang) / math.cos(a)
    y0, y1 = -length / 2 - gable_overhang, length / 2 + gable_overhang
    out = []
    if style == "thatch":
        out += thatch_roof(span, length, pitch_deg, overhang, gable_overhang, thickness * 1.6, color,
                           ridge_color or "thatch_dark", rng)
    else:
        n = max(1, rows)
        seg = L / n
        for side in (-1, 1):
            for k in range(n):
                s0 = -0.3 + k * seg
                s1 = (k + 1) * seg + (0.3 if k < n - 1 else 0.0)
                sl = _slab(ridge, a, side, s0, s1, y0, y1, thickness, extra=math.radians(4.0) if n > 1 else 0.0,
                           color=color, lift=0.02 * k)
                sl.grad = ("range", 0.3 + 0.25 * (n - 1 - k) / max(1, n - 1), 0.9)
                out.append(bevel(sl, 0.1))
        cap = bbox(thickness * 1.6, (y1 - y0) + 0.4, thickness * 1.6, ridge_color or color, 0.15, base=False)
        cap.rotate(math.radians(45), "Y")
        cap.move(0, 0, rise + thickness * 0.45)
        out.append(cap)
        if trim:
            ez = -overhang * math.tan(a)
            for yy in (y0 + 0.2, y1 - 0.2):
                for side in (-1, 1):
                    out.append(oriented_box((side * (half + overhang * 0.95), yy, ez - 0.2), (0, yy, rise - 0.1),
                                            0.55, 0.4, trim, Vector((0, 1, 0))))
    return out, rise


def thatch_roof(span, length, pitch_deg=50.0, overhang=1.4, gable_overhang=1.1, t=1.3, color="thatch",
                ridge_color="thatch_dark", rng=None, steps=3):
    """Puffy layered thatch: one lofted profile with stepped bulges, rounded eave lips,
    a rolled ridge, a slight sag along the ridge and wavy eaves. Rests on walls of width
    `span`; eaves at z=0. Smooth-shaded (soft straw look)."""
    a = math.radians(pitch_deg)
    half = span / 2
    rise = half * math.tan(a)
    L = (half + overhang) / math.cos(a)
    ca, sa = math.cos(a), math.sin(a)
    seed = rng.uniform(0, 100) if rng else 0.0

    def P(side, u, off):
        # point at slope distance u from the ridge (underside line), pushed `off` along the normal
        return (side * (u * ca + off * sa), rise - u * sa + off * ca)

    b = t * 0.32  # bulge of each layer's lower edge
    outer = []  # right side, ridge -> eave
    for k in range(steps):
        u0, u1 = L * k / steps, L * (k + 1) / steps
        if k == 0:
            outer.append((u0 + 0.0, t * 1.05))
        else:
            outer.append((u0 + 0.12, t * 0.92))
        outer.append((u0 + (u1 - u0) * 0.55, t + b * 0.35))
        outer.append((u1 - 0.18, t + b))
    lip = [(L + t * 0.18, t * 0.55), (L + t * 0.05, t * 0.08)]
    under = [(L - 0.2, -0.05), (L * 0.5, 0.0)]
    right = [P(1, u, o) for u, o in outer] + [P(1, u, o) for u, o in lip] + [P(1, u, o) for u, o in under]
    left = [(-x, z) for x, z in right]
    top = [(0.0, rise + t * 1.12)]
    bottom = [(0.0, rise + 0.02)]
    # polygon: ridge top -> right outer -> right lip -> right underside -> ridge bottom -> left (reversed)
    poly = top + right + bottom + list(reversed(left))

    ys = [-length / 2 - gable_overhang, -length / 2 - gable_overhang + 0.45]
    nmid = max(2, int(length // 6))
    ys += [-length / 2 + length * i / nmid for i in range(nmid + 1)]
    ys += [length / 2 + gable_overhang - 0.45, length / 2 + gable_overhang]
    ys = sorted(set(round(y, 4) for y in ys))
    y0, y1 = ys[0], ys[-1]
    rings = []
    for ri, y in enumerate(ys):
        end = ri in (0, len(ys) - 1)
        t_y = (y - y0) / (y1 - y0)
        sag = -0.22 * math.sin(math.pi * t_y)
        ring = []
        for x, z in poly:
            reach = abs(x) / (half + overhang)
            wave = 0.18 * mnoise.noise((y * 0.35, seed, 0.0)) * reach
            zz = z + sag * (1 - reach) + wave
            xx = x
            if end:  # pull the outer surface in at the gable ends: rounded edge
                zz -= 0.35 * t * (1 - 0.5 * reach) if z > rise - x * 0 - abs(x) * math.tan(a) + 0.1 else 0.0
                xx = x * 0.985
            ring.append((xx, y, zz))
        rings.append(ring)
    roof = loft_rings(rings, color, smooth=True, grad=("range", 0.15, 0.95))
    out = [roof]
    roll = lathe([(0.0, y0 - 0.3), (t * 0.5, y0 - 0.1), (t * 0.62, y0 + 0.6), (t * 0.62, y1 - 0.6),
                  (t * 0.5, y1 + 0.1), (0.0, y1 + 0.3)], 8, ridge_color)
    roll.transform(Matrix.Rotation(-math.pi / 2, 4, "X"))
    roll = recalc_normals(roll)
    roll.bend(lambda v: (v.x, v.y, v.z - 0.22 * math.sin(math.pi * (v.y - y0) / (y1 - y0))))
    roll.move(0, 0, rise + t * 1.0)
    out.append(roll.paint(smooth=True, grad=("range", 0.3, 0.85)))
    return out


def gable_end(span, rise, thickness, color="plaster"):
    """Triangular wall filling the gable (plane XZ, centred, depth along Y = thickness)."""
    return prism([(-span / 2, 0.0), (span / 2, 0.0), (0.0, rise)], thickness, color)


def cone_roof(radius, height, seg=10, color="slate", overhang=0.9, flare=True, finial=None, rows=3):
    """Conical tower roof with a flared skirt, stepped tile rings and an optional finial."""
    out = []
    r0 = radius + overhang
    if flare:
        prof = [(r0 + 0.4, 0.0), (r0 + 0.4, 0.45), (r0 * 0.8, height * 0.2), (r0 * 0.52, height * 0.48),
                (r0 * 0.24, height * 0.78), (0.0, height)]
    else:
        prof = [(r0, 0.0), (r0, 0.4), (0.0, height)]
    out.append(lathe(prof, seg, color, cap_bottom=True).paint(grad=("range", 0.25, 0.95)))
    for k in range(1, rows + 1):
        z = height * (k / (rows + 1)) * 0.78
        rr = None
        for (ra, za), (rb, zb) in zip(prof, prof[1:]):
            if za <= z <= zb:
                rr = ra + (rb - ra) * (z - za) / max(1e-6, zb - za)
                break
        if rr:
            out.append(lathe([(rr + 0.25, z - 0.4), (rr + 0.25, z), (rr * 0.9, z + 0.7)], seg, color,
                             cap_bottom=True).paint(grad=("range", 0.2, 0.7)))
    if finial:
        out.append(lathe([(0.25, height - 0.4), (0.25, height + 1.4), (0.5, height + 1.55), (0.5, height + 2.0),
                          (0.0, height + 2.7)], 6, finial))
    return out


def crenellations(length, thickness, height=3.0, merlon=2.6, gap=1.8, color="stone", along="x", rng=None,
                  bev=0.15):
    """Row of merlons centred on the origin, base z=0."""
    out = []
    n = max(1, int((length + gap) // (merlon + gap)))
    total = n * merlon + (n - 1) * gap
    start = -total / 2 + merlon / 2
    for i in range(n):
        u = start + i * (merlon + gap)
        h = height * (1.0 + (rng.uniform(-0.04, 0.04) if rng else 0.0))
        m = bbox(merlon, thickness, h, color, bev) if along == "x" else bbox(thickness, merlon, h, color, bev)
        m.move(u if along == "x" else 0, 0 if along == "x" else u, 0)
        out.append(m.paint(tint=rng.uniform(0.2, 0.8) if rng else None))
    return out


def chimney(height, w=2.2, color="stone", cap="stone_dark"):
    out = [bbox(w, w, height, color, 0.15).paint(grad=("range", 0.25, 0.8))]
    out.append(bbox(w + 0.6, w + 0.6, 0.45, cap, 0.1).move(0, 0, height))
    out.append(box(w * 0.55, w * 0.55, 0.3, "black").move(0, 0, height + 0.3))
    return out


def stone_course(points, height, depth, color="stone", rng=None, block=(2.2, 3.4), bev=0.0, colors=None):
    """Irregular block course along a polyline (plinths, wall bases, wells, quoins)."""
    out = []
    for p0, p1 in zip(points, points[1:]):
        p0, p1 = Vector(p0), Vector(p1)
        seg = p1 - p0
        L = seg.length
        u = 0.0
        while u < L - 0.05:
            bl = rng.uniform(*block) if rng else sum(block) / 2
            if L - u - bl < block[0] * 0.6:
                bl = L - u
            mid = p0 + seg.normalized() * (u + bl / 2)
            hh = height * (rng.uniform(0.9, 1.08) if rng else 1)
            c = rng.choice(colors) if (colors and rng) else color
            b = bbox(bl - 0.1, depth * (rng.uniform(0.95, 1.1) if rng else 1), hh, c, bev)
            b.rotate(math.atan2(seg.y, seg.x), "Z")
            b.move(mid.x, mid.y, mid.z)
            out.append(b.paint(tint=rng.uniform(0, 1) if rng else 0.5))
            u += bl
    return out


def plank_floor(sx, sy, thickness=0.4, plank=1.4, color="wood", rng=None, along="x"):
    """Plank deck (bridges, stalls, docks): separate boards with tiny gaps and tint variation."""
    out = []
    n = max(1, int((sy if along == "x" else sx) // plank))
    w = (sy if along == "x" else sx) / n
    for i in range(n):
        off = -((sy if along == "x" else sx) / 2) + w * (i + 0.5)
        L = (sx if along == "x" else sy) * (rng.uniform(0.97, 1.0) if rng else 1)
        b = box(L, w - 0.12, thickness, color) if along == "x" else box(w - 0.12, L, thickness, color)
        b.move(0 if along == "x" else off, off if along == "x" else 0,
               (rng.uniform(-0.04, 0.04) if rng else 0))
        out.append(b.paint(tint=rng.uniform(0, 1) if rng else 0.5))
    return out


__all__ = ["CHAR_H", "DOOR_W", "DOOR_H", "WIN_W", "WIN_H", "SILL_Z", "STOREY", "TIMBER", "TIMBER_OUT", "BEVEL",
           "bbox", "oriented_box", "wall_face_frame", "window", "door", "gable_roof", "thatch_roof", "gable_end", "cone_roof",
           "crenellations", "chimney", "stone_course", "plank_floor"]
