"""Shared castle language for castle_wall / castle_tower / castle_gatehouse / castle_keep.

One stone vocabulary (ashlar courses with mortar gaps, quoins, battered plinths, corbel tables,
merlons, arrow slits), one banner/flag/finial vocabulary and the four kingdom roof languages
(ART_DIRECTION section 3):
  red    tall conical spires + gold finials         blue   square pyramid slate roofs + silver finials
  green  timber hoardings + low cones (bronze)      yellow domes / onion domes + gold finials

Conventions: front (field side) faces Blender -Y. Walls are 32-stud modules along X with the
wall-walk at WALK_Z; towers and gatehouses meet them at WALK_Z. All pieces are closed shells.
Angles: theta = 0 faces -Y (front), +90 deg faces +X; outward direction (sin t, -cos t).
"""

import math

from lib import kit
from lib.geo import Matrix, Piece, Vector, arch_poly, bevel, box, cylinder, lathe, loft, prism, recalc_normals
from lib.palette import kingdom_color

KINGDOMS = ("red", "blue", "green", "yellow")
MODULE = 32.0  # wall module length (X)
WALK_Z = 24.0  # wall-walk level
WALL_T = 8.4  # wall body thickness at walk level
PARAPET_H = 3.2  # breastwork above the walk
MERLON_W, MERLON_H, CRENEL_W = 2.6, 3.0, 1.8
COURSE = 2.7  # stone course height


def kc(k, role):
    return kingdom_color(k, role)


def stone_set(k):
    """(body, light, dark) stone swatches of a kingdom."""
    return kc(k, "stone"), kc(k, "stone_light"), kc(k, "stone_dark")


def pick(rng, cols, weights=(0.5, 0.33, 0.17)):
    x = rng.random()
    acc = 0.0
    for c, w in zip(cols, weights):
        acc += w
        if x <= acc:
            return c
    return cols[-1]


def place(pieces, theta=0.0, x=0.0, y=0.0, z=0.0):
    """Rotate pieces about Z by theta, then move. Returns the list."""
    for p in pieces:
        if theta:
            p.rotate(theta, "Z")
        p.move(x, y, z)
    return pieces


def on_ring(pieces, theta, r, z=0.0):
    """Pieces authored on a facade at y=0 facing -Y -> placed on a circle of radius r at angle theta."""
    for p in pieces:
        p.move(0, -r, z)
        p.rotate(theta, "Z")
    return pieces


def wrap(a):
    return (a + math.pi) % (2 * math.pi) - math.pi


# ------------------------------------------------------------------ closed solids

def revolve_closed(profile, seg, color, phase=None, **kw):
    """Revolve a CLOSED (r, z) loop around Z: annuli, mouldings, rings. All r > 0."""
    phase = math.pi / seg if phase is None else phase
    n = len(profile)
    verts = []
    for r, z in profile:
        for i in range(seg):
            a = phase + 2 * math.pi * i / seg
            verts.append((math.cos(a) * r, math.sin(a) * r, z))
    faces = []
    for k in range(n):
        a, b = k * seg, ((k + 1) % n) * seg
        for i in range(seg):
            j = (i + 1) % seg
            faces.append((a + i, a + j, b + j, b + i))
    return recalc_normals(Piece(verts, faces, color, **kw))


def annulus(r_in, r_out, z0, z1, seg, color, phase=None, **kw):
    return revolve_closed([(r_in, z0), (r_out, z0), (r_out, z1), (r_in, z1)], seg, color, phase, **kw)


def ybox(x0, x1, y0, y1, z0, z1, color, **kw):
    """Axis-aligned box from min/max corners."""
    return box(x1 - x0, y1 - y0, z1 - z0, color, **kw).move((x0 + x1) / 2, (y0 + y1) / 2, z0)


def profile_x(poly_yz, x0, x1, color, **kw):
    """Extrude a (y, z) cross-section along X from x0 to x1 (flat, flush ends: modules tile)."""
    p = prism(poly_yz, x1 - x0, color, axis="X", **kw)
    return p.move((x0 + x1) / 2, 0, 0)


def square_lathe(profile, color, **kw):
    """Lathe with 4 segments: square cross-section with faces on the axes. profile radii are
    half-widths (converted to corner radii)."""
    s = math.sqrt(2.0)
    return lathe([(r * s, z) for r, z in profile], 4, color, phase=math.pi / 4, **kw)


def poly_lathe(profile, seg, color, **kw):
    """Lathe with flats facing the axes: profile radii are apothems (seg 4/8 keep faces on X/Y)."""
    c = 1.0 / math.cos(math.pi / seg)
    return lathe([(r * c, z) for r, z in profile], seg, color, phase=math.pi / seg, **kw)


# ------------------------------------------------------------------ masonry

def stone(L, depth, h, color, base=True):
    """Ashlar block: full front face (y = -depth/2), top and bottom faces slope back to a ridge at
    the rear (a built-in chamfer that reads as a deep mortar joint). 5 faces / 8 tris instead of a
    box's 12; the front outline is identical, so wall silhouettes do not change."""
    x, y0, y1 = L / 2, -depth / 2, depth / 2
    z0, z1 = (0.0, h) if base else (-h / 2, h / 2)
    zm = (z0 + z1) / 2
    v = [(-x, y0, z0), (x, y0, z0), (x, y0, z1), (-x, y0, z1), (-x, y1, zm), (x, y1, zm)]
    f = [(0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)]
    return Piece(v, f, color)


def _shade(t):
    """Gradient window for a block at relative height t (0 bottom .. 1 top): darker near the ground."""
    return ("range", 0.12 + 0.3 * t, 0.58 + 0.38 * t)


def ashlar_plane(k, rng, x0, x1, z0, z1, course=COURSE, blen=(3.4, 6.2), proud=0.22, depth=0.75, gap=0.2,
                 holes=(), end_gap=True, cols=None, weights=(0.5, 0.33, 0.17), shade_t=None, min_len=0.8):
    """Running-bond stone courses on the face plane y=0 facing -Y (blocks stand `proud` towards -Y).
    holes: (xa, xb, za, zb) rectangles kept free (openings get their own surrounds).
    end_gap=False keeps the blocks flush with x0/x1 (module ends)."""
    cols = cols or stone_set(k)
    out = []
    H = z1 - z0
    if H < 0.6:
        return out
    n = max(1, int(round(H / course)))
    ch = H / n
    for i in range(n):
        za = z0 + i * ch
        zb = za + ch
        cuts = [x0]
        u = x0 + (rng.uniform(0.35, 0.6) if i % 2 else rng.uniform(0.75, 1.0)) * blen[1]
        while u < x1 - blen[0] * 0.6:
            cuts.append(u)
            u += rng.uniform(*blen)
        cuts.append(x1)
        for xa, xb in zip(cuts, cuts[1:]):
            segs = [(xa, xb)]
            for ha, hb, hza, hzb in holes:
                if hzb <= za + 0.05 or hza >= zb - 0.05:
                    continue
                new = []
                for sa, sb in segs:
                    if hb <= sa or ha >= sb:
                        new.append((sa, sb))
                        continue
                    if ha - sa > 0.6:
                        new.append((sa, ha))
                    if sb - hb > 0.6:
                        new.append((hb, sb))
                segs = new
            for sa, sb in segs:
                ga = gap / 2 if (sa > x0 + 1e-6 or end_gap) else 0.0
                gb = gap / 2 if (sb < x1 - 1e-6 or end_gap) else 0.0
                L = sb - sa - ga - gb
                if L < min_len * 0.5:
                    continue
                pr = proud + rng.uniform(-0.05, 0.07)
                c = pick(rng, cols, weights)
                t = (za - z0) / max(1e-6, H) if shade_t is None else shade_t
                bl = stone(L, depth, ch - gap, c).move((sa + ga + sb - gb) / 2, depth / 2 - pr, za + gap / 2)
                out.append(bl.paint(grad=_shade(t)))
    return out


def ashlar_ring(k, rng, r0, z0, z1, r1=None, seg_len=4.8, course=COURSE, proud=0.22, depth=0.75, gap=0.2,
                holes=(), cols=None, weights=(0.5, 0.33, 0.17), shade_lo=0.0, shade_hi=1.0, n_min=6, arc=None):
    """Courses of flat blocks round a (possibly battered) cylinder: radius r0 at z0 -> r1 at z1.
    holes: (theta_centre, half_width_rad, za, zb). arc: (theta_centre, half_width) limits the blocks
    to a sector (for D-shaped towers)."""
    cols = cols or stone_set(k)
    r1 = r0 if r1 is None else r1
    out = []
    H = z1 - z0
    n = max(1, int(round(H / course)))
    ch = H / n
    tilt = math.atan2(r0 - r1, H)
    rm = (r0 + r1) / 2
    N = max(n_min, int(round(2 * math.pi * rm / seg_len)))
    step = 2 * math.pi / N
    for i in range(n):
        za = z0 + i * ch
        zm = za + ch / 2
        r = r0 + (r1 - r0) * (zm - z0) / H
        phase = (i % 2) * step / 2 + rng.uniform(-0.12, 0.12) * step
        cuts = [phase + step * j + (rng.uniform(-0.18, 0.18) * step if j else 0.0) for j in range(N)]
        cuts.append(phase + 2 * math.pi)
        for a0, a1 in zip(cuts, cuts[1:]):
            segs = [(a0, a1)]
            hl = list(holes)
            for hc, hw, hza, hzb in hl:
                if hzb <= za + 0.05 or hza >= za + ch - 0.05:
                    continue
                new = []
                for sa, sb in segs:
                    d0 = wrap(sa - hc)
                    d1 = d0 + (sb - sa)
                    if d1 <= -hw or d0 >= hw:
                        new.append((sa, sb))
                        continue
                    if -hw - d0 > 0.08:
                        new.append((sa, sa + (-hw - d0)))
                    if d1 - hw > 0.08:
                        new.append((sb - (d1 - hw), sb))
                segs = new
            if arc is not None:
                ac, aw = arc
                new = []
                for sa, sb in segs:
                    d0 = wrap(sa - ac)
                    d1 = d0 + (sb - sa)
                    lo, hi = max(d0, -aw), min(d1, aw)
                    if hi - lo > 0.06:
                        new.append((ac + lo, ac + hi))
                segs = new
            for sa, sb in segs:
                half = (sb - sa) / 2
                ro = r + proud + rng.uniform(-0.05, 0.06)
                L = 2 * ro * math.sin(half) - gap
                if L < 0.35:
                    continue
                c = pick(rng, cols, weights)
                t = shade_lo + (shade_hi - shade_lo) * (za - z0) / max(1e-6, H)
                bl = stone(L, depth, ch - gap, c, base=False)
                if tilt:
                    bl.rotate(-tilt, "X")
                bl.move(0, -(ro - depth / 2), zm)
                bl.rotate((sa + sb) / 2, "Z")
                out.append(bl.paint(grad=_shade(t)))
    return out


def quoins(k, rng, x, y, z0, z1, sx=1, sy=1, size=(2.6, 1.5), course=COURSE, proud=0.32, color=None):
    """Alternating long/short corner blocks at an outside corner (x, y); sx/sy: corner direction."""
    out = []
    n = max(1, int(round((z1 - z0) / course)))
    ch = (z1 - z0) / n
    col = color or kc(k, "stone_light")
    for j in range(n):
        big = j % 2 == 0
        lx, ly = (size[0], size[1]) if big else (size[1], size[0])
        q = box(lx, ly, ch - 0.2, col)
        q.move(x - sx * (lx / 2 - proud), y - sy * (ly / 2 - proud), z0 + j * ch + 0.1)
        out.append(q.paint(grad=_shade(j / max(1, n - 1)), tint=rng.uniform(0.2, 0.8)))
    return out


def string_course_x(x0, x1, y_face, z, color, proj=0.4, h=0.55, depth=1.0):
    """Moulded band along X on a face at y_face (facing -Y)."""
    return ybox(x0, x1, y_face - proj, y_face - proj + depth, z, z + h, color)


def corbel(color, proj=1.4, w=1.1, h=2.4, steps=2):
    """Stepped corbel on a face at y=0 facing -Y, top at z=0 (hangs below)."""
    out = []
    for s in range(steps):
        p = proj * (s + 1) / steps
        hh = h * (steps - s) / steps
        out.append(box(w * (0.82 + 0.06 * s), p + 0.3, h / steps + 0.02, color).move(0, -p / 2 + 0.15,
                                                                                     -hh))
    return out


def arrow_slit(k, h=3.4, w=0.5, oillet=True, surround=None, dark="window_dark"):
    """Plain vertical arrow slit on a face at y=0 facing -Y, base z=0: dark slot with a small round
    oillet at its foot, light stone frame and a projecting sill. No cross arms (they read as
    religious crosses at gameplay distance). Hole size for the ashlar: (-1.0, 1.0, -0.45, h + 0.45)."""
    s = surround or kc(k, "stone_light")
    out = [box(w, 0.5, h, dark).move(0, -0.14, 0)]
    if oillet:
        r = w * 0.95
        disc = cylinder(r, r, 0.5, 6, dark).rotate(math.pi / 2, "X")
        out.append(disc.move(0, 0.11, r * 0.85))
    out.append(box(w + 1.3, 0.5, h + 0.75, s).move(0, 0.12, -0.3))
    out.append(box(w + 1.7, 0.75, 0.38, s).move(0, -0.2, -0.42))
    return out


def voussoirs(width, spring, thick, depth, color, m=7, gap=0.12, key=1.15):
    """Segmented semicircular arch (separate trapezoid voussoirs, keystone slightly bigger) in the
    XZ plane facing -Y, centred on y=0. ~12 tris per stone."""
    out = []
    r_in = width / 2
    for i in range(m):
        a0 = math.pi * i / m + (gap / 2) / (r_in + thick / 2)
        a1 = math.pi * (i + 1) / m - (gap / 2) / (r_in + thick / 2)
        ro = r_in + thick * (key if i == m // 2 else 1.0)
        poly = [(math.cos(a0) * r_in, spring + math.sin(a0) * r_in), (math.cos(a0) * ro, spring + math.sin(a0) * ro),
                (math.cos(a1) * ro, spring + math.sin(a1) * ro), (math.cos(a1) * r_in, spring + math.sin(a1) * r_in)]
        out.append(prism(poly, depth * (1.08 if i == m // 2 else 1.0), color))
    return out


def arched_door(k, width=kit.DOOR_W, height=kit.DOOR_H, leaf=None, surround=None, step=True, open_=False,
                jw=0.8, m=7):
    """Arched plank door (kit language: battens, iron straps, stone jambs, voussoirs, threshold) at y=0
    facing -Y, base z=0. open_=True gives a dark open doorway. ~150-200 tris."""
    s = surround or kc(k, "stone_light")
    out = []
    spring = height - width / 2
    leafc = "black" if open_ else (leaf or kc(k, "wood"))
    out.append(prism(arch_poly(width + 0.1, height + 0.05, 6), 0.3, leafc).move(0, -0.08, 0))
    if not open_:
        for u in (-width / 3, 0.0, width / 3):
            out.append(box(0.16, 0.12, spring - 0.3, "timber").move(u, -0.28, 0.15))
        for z in (height * 0.2, spring * 0.78):
            out.append(box(width * 0.9, 0.12, 0.28, "iron_dark").move(0, -0.32, z))
        out.append(box(0.3, 0.2, 0.3, "iron").move(width * 0.3, -0.42, height * 0.42))
    out.append(box(jw, 0.7, spring, s).move(-width / 2 - jw / 2, -0.2, 0))
    out.append(box(jw, 0.7, spring, s).move(width / 2 + jw / 2, -0.2, 0))
    out += [v.move(0, -0.2, 0) for v in voussoirs(width, spring, jw, 0.7, s, m)]
    if step:
        out.append(kit.bbox(width + 2.0, 1.8, 0.45, kc(k, "stone_dark"), 0.12).move(0, -0.9, -0.1))
    return out


def opening(width, height, surround, k="red"):
    """Open arched doorway (dark void + jambs + voussoirs)."""
    return arched_door(k, width, height, surround=surround, step=False, open_=True)


def castle_door(k, width=kit.DOOR_W, height=kit.DOOR_H, surround=None, step=True):
    return arched_door(k, width, height, surround=surround, step=step)


def window_v(width=kit.WIN_W, height=kit.WIN_H, frame="timber", shutter=None, arched=False, sill="wood",
             open_angle=0.35):
    """Kit window (frame, sill, open shutters) as a two-light window: one vertical mullion only, no
    cross bars (a cross mullion reads as a religious cross at castle scale)."""
    out = kit.window(width, height, frame, shutter, arched=arched, mullion=False, sill=sill, open_angle=open_angle)
    out.append(box(0.24, 0.28, height, frame).move(0, -0.16, 0))
    return out


def castle_window(k, width=kit.WIN_W, height=kit.WIN_H, shutters=True, arched=True, frame=None):
    return window_v(width, height, frame or "timber", kc(k, "shutter") if shutters else None, arched=arched,
                    sill=kc(k, "stone_light"))


def stone_window(k, width=2.2, height=3.6, arched=True, mullion=False, glass="window_dark"):
    """Stone-framed (no shutters) window for towers/keeps: dark pane, stone jambs, arch head, sill."""
    s = kc(k, "stone_light")
    out = []
    if arched:
        pane = prism(arch_poly(width, height, 5), 0.3, glass).move(0, -0.05, 0)
    else:
        pane = box(width, 0.3, height, glass).move(0, -0.05, 0)
    out.append(pane)
    jw = 0.5
    spring = height - width / 2 if arched else height
    out.append(box(jw, 0.6, spring, s).move(-width / 2 - jw / 2, -0.22, 0))
    out.append(box(jw, 0.6, spring, s).move(width / 2 + jw / 2, -0.22, 0))
    if arched:
        out += [v.move(0, -0.22, 0) for v in voussoirs(width, spring, jw, 0.6, s, 5)]
    else:
        out.append(box(width + 2 * jw, 0.6, jw, s).move(0, -0.22, height))
    if mullion:
        out.append(box(0.24, 0.4, spring, s).move(0, -0.12, 0))
    out.append(box(width + 2 * jw + 0.4, 0.9, 0.36, s).move(0, -0.35, -0.36))
    return out


def arch_ring(width, spring, thick, depth, color, m=7, keystone=True):
    """Semicircular arch ring (voussoir band) in the XZ plane facing -Y, opening `width`,
    springing at z=spring; one closed prism."""
    r_out, r_in = width / 2 + thick, width / 2
    poly = []
    for i in range(m + 1):
        a = math.pi * i / m
        poly.append((math.cos(a) * r_out, spring + math.sin(a) * r_out))
    for i in range(m, -1, -1):
        a = math.pi * i / m
        poly.append((math.cos(a) * r_in, spring + math.sin(a) * r_in))
    poly = list(reversed(poly))
    out = [prism(poly, depth, color)]
    if keystone:
        out.append(box(thick * 0.8, depth + 0.12, thick * 1.15, color).move(0, 0, spring + r_in - 0.1))
    return out


# ------------------------------------------------------------------ emblems, banners, flags, finials

def emblem_poly(k, s=1.0):
    """2D emblem outline (x, z), ~2s across, centred on the origin."""
    pts = []
    if k == "red":  # crown
        pts = [(-1.0, -0.7), (1.0, -0.7), (1.0, 0.05), (1.1, 0.8), (0.52, 0.2), (0.0, 1.0), (-0.52, 0.2),
               (-1.1, 0.8), (-1.0, 0.05)]
    elif k == "blue":  # five-point star
        for i in range(10):
            a = math.pi / 2 + i * math.pi / 5
            r = 1.0 if i % 2 == 0 else 0.42
            pts.append((math.cos(a) * r, math.sin(a) * r))
    elif k == "green":  # oak leaf
        right = [(0.08, -1.1), (0.3, -0.72), (0.55, -0.62), (0.42, -0.36), (0.72, -0.18), (0.52, 0.08),
                 (0.74, 0.34), (0.44, 0.5), (0.52, 0.78), (0.18, 0.86)]
        pts = right + [(0.0, 1.1)] + [(-x, z) for x, z in reversed(right)]
    else:  # sun
        for i in range(16):
            a = math.pi / 2 + i * math.pi / 8
            r = 1.0 if i % 2 == 0 else 0.62
            pts.append((math.cos(a) * r, math.sin(a) * r))
    return [(x * s, z * s) for x, z in pts]


def emblem(k, s=1.0, depth=0.14, color=None):
    """Emblem plaque on a face at y=0 facing -Y, centred at the origin (XZ)."""
    return [prism(emblem_poly(k, s), depth, color or kc(k, "emblem")).move(0, -depth / 2, 0)]


def banner(k, w=3.6, h=8.0, tail="swallow", rod=True):
    """Hanging banner on a face at y=0 facing -Y; top of the rod at z=0, cloth hangs down to -h."""
    out = []
    y = -0.45
    cloth = kc(k, "cloth")
    trim = kc(k, "trim")
    hw = w / 2
    if tail == "swallow":
        poly = [(-hw, -h), (0.0, -h + w * 0.42), (hw, -h), (hw, -0.3), (-hw, -0.3)]
    elif tail == "point":
        poly = [(-hw, -h + w * 0.45), (0.0, -h), (hw, -h + w * 0.45), (hw, -0.3), (-hw, -0.3)]
    else:
        poly = [(-hw, -h), (hw, -h), (hw, -0.3), (-hw, -0.3)]
    out.append(prism(poly, 0.2, cloth).move(0, y, 0).paint(grad=("range", 0.25, 0.85)))
    out.append(box(w + 0.1, 0.3, 0.6, trim).move(0, y - 0.02, -1.0))  # top band
    out.append(box(w * 0.86, 0.26, 0.28, trim).move(0, y - 0.02, -h + w * 0.42 + 0.55))  # lower band
    em = emblem(k, w * 0.3, 0.16)[0]
    out.append(em.move(0, y - 0.1, -h * 0.44))
    if rod:
        out.append(box(w + 1.0, 0.32, 0.32, "iron_dark", base=False).move(0, y, -0.25))
        for sx in (-1, 1):
            out.append(box(0.5, 0.5, 0.5, trim, base=False).move(sx * (w + 1.0) / 2, y, -0.25))
    return out


def flag(k, length=4.4, height=2.6, rng=None, pennant=False, stripe=True, wave=0.35):
    """Waving flag attached at x=0 (pole side), extending +X, top edge at z=0 (hangs down)."""
    st = 6
    ys = [length * i / st for i in range(st + 1)]
    ph = rng.uniform(0, 3) if rng else 0.0

    def deform_fn(scale_z, z0):
        def f(ri, y, x, z):
            t = y / length
            zz = z * (1 - 0.82 * t) if pennant else z
            return (x + wave * math.sin(ph + t * 4.2) * t, y, zz - 0.25 * t * t + z0)
        return f

    prof = [(-0.08, 0.0), (0.08, 0.0), (0.08, -height), (-0.08, -height)]
    out = [loft(prof, ys, kc(k, "cloth"), deform=deform_fn(1.0, 0.0)).paint(grad=("range", 0.4, 0.95))]
    if stripe and not pennant:
        prof2 = [(-0.12, -height * 0.36), (0.12, -height * 0.36), (0.12, -height * 0.64), (-0.12, -height * 0.64)]
        out.append(loft(prof2, ys[1:], kc(k, "emblem"), deform=deform_fn(1.0, 0.0)).paint(grad=0.8))
    for p in out:
        p.rotate(-math.pi / 2, "Z")
    return out


def flagpole(k, h, rng, flag_len=4.6, flag_h=2.7, finial_col=None, pennant=False):
    """Pole standing on z=0 with a finial knob and a flag near the top. Returns (pieces, top_z)."""
    out = [cylinder(0.2, 0.14, h, 6, "wood_dark")]
    out.append(lathe([(0.0, h - 0.05), (0.34, h + 0.1), (0.34, h + 0.45), (0.0, h + 0.7)], 6,
                     finial_col or kc(k, "trim")))
    for p in flag(k, flag_len, flag_h, rng, pennant=pennant):
        out.append(p.move(0.12, 0, h - 0.25))
    return out, h + 0.7


def finial(color, h=3.0, ball=0.55, collar=0.45, seg=6):
    if h < 2.5:  # small turrets: cheaper knob + spike
        return [lathe([(collar, 0.0), (0.16, h * 0.3), (ball, h * 0.45), (ball * 0.8, h * 0.62), (0.0, h)], 5,
                      color)]
    return [lathe([(collar, 0.0), (collar, 0.25), (0.2, 0.45), (0.18, h * 0.32), (ball, h * 0.42),
                   (ball, h * 0.58), (0.12, h * 0.7), (0.0, h)], seg, color)]


def sun_finial(color, h=3.4):
    """Gold spike with a sun disc (Sunspire)."""
    out = finial(color, h * 0.7, 0.45)
    disc = lathe([(0.0, -0.12), (0.9, -0.12), (0.9, 0.12), (0.0, 0.12)], 10, color)
    disc.rotate(math.pi / 2, "X").move(0, 0, h * 0.82)
    out.append(disc)
    out.append(lathe([(0.12, 0.0), (0.12, h * 0.3), (0.0, h * 0.42)], 5, color).move(0, 0, h * 0.82))
    return out


# ------------------------------------------------------------------ kingdom roofs

def finial_color(k):
    return {"red": "gold", "blue": kc("blue", "trim"), "green": kc("green", "trim"), "yellow": "gold"}[k]


def spire(k, r, h, seg=12, overhang=0.8, rows=3, rng=None):
    """Red: tall conical spire with flared skirt, tile rings and a gold finial. Base z=0.
    Returns (pieces, apex_z)."""
    out = kit.cone_roof(r, h, seg, kc(k, "roof"), overhang=overhang, flare=True, finial=None, rows=rows)
    out[0].paint(grad=("range", 0.2, 1.0))
    # dark eave band (shadow line under the skirt)
    out.append(cylinder(r + overhang * 0.6, r + overhang * 0.6, 0.5, seg, kc(k, "roof_dark")).move(0, 0, -0.35))
    big = r > 3.0
    fin = finial(finial_color(k), 3.2 if big else 1.9, 0.6 if big else 0.36)
    for p in fin:
        p.move(0, 0, h - 0.5)
    out += fin
    return out, h + (2.7 if big else 1.4)


def pyramid(k, half, h, overhang=0.9, rows=3, flare=True, fin=True):
    """Blue: crisp square pyramid roof (faces on the axes) with flared eaves, tile steps and hip ridges.
    Returns (pieces, apex_z)."""
    col, dark = kc(k, "roof"), kc(k, "roof_dark")
    r0 = half + overhang
    if flare:
        prof = [(r0 + 0.35, 0.0), (r0 + 0.35, 0.5), (r0 * 0.8, h * 0.16), (r0 * 0.52, h * 0.46),
                (r0 * 0.24, h * 0.76), (0.0, h)]
    else:
        prof = [(r0, 0.0), (r0, 0.45), (0.0, h)]
    out = [square_lathe(prof, col).paint(grad=("range", 0.22, 1.0))]
    for kk in range(1, rows + 1):
        z = h * (kk / (rows + 1)) * 0.8
        rr = None
        for (ra, za), (rb, zb) in zip(prof, prof[1:]):
            if za <= z <= zb:
                rr = ra + (rb - ra) * (z - za) / max(1e-6, zb - za)
                break
        if rr:
            out.append(square_lathe([(rr + 0.22, z - 0.4), (rr + 0.22, z), (rr * 0.9, z + 0.7)], col)
                       .paint(grad=("range", 0.15, 0.6)))
    # hip ridges along the four corners
    s = math.sqrt(2.0)
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        pts = [(prof[1][0] * s, prof[1][1])] + [(r * s, z) for r, z in prof[2:-1]] + [(0.0, h)]
        for (ra, za), (rb, zb) in zip(pts, pts[1:]):
            p0 = Vector((math.cos(a) * ra, math.sin(a) * ra, za + 0.12))
            p1 = Vector((math.cos(a) * rb, math.sin(a) * rb, zb + 0.12))
            nrm = Vector((math.cos(a), math.sin(a), 0.6))
            out.append(kit.oriented_box(p0, p1 + (p1 - p0).normalized() * 0.3, 0.42, 0.42, dark, nrm))
    out.append(square_lathe([(r0 * 0.62, -0.3), (r0 * 0.62, 0.05), (r0 * 0.4, 0.06)], dark).move(0, 0, -0.2))
    if not fin:
        return out, h
    f = finial(finial_color(k), 3.0 if half > 3 else 2.0, 0.5 if half > 3 else 0.32)
    for p in f:
        p.move(0, 0, h - 0.4)
    out += f
    return out, h + (2.6 if half > 3 else 1.6)


def low_cone(k, r, h, seg=10, overhang=1.1, rows=2):
    """Green: low, wide cone with flared skirt and a bronze knob. Returns (pieces, apex_z)."""
    out = kit.cone_roof(r, h, seg, kc(k, "roof"), overhang=overhang, flare=True, finial=None, rows=rows)
    out[0].paint(grad=("range", 0.2, 1.0))
    fin = finial(finial_color(k), 2.2, 0.45)
    for p in fin:
        p.move(0, 0, h - 0.3)
    out += fin
    return out, h + 1.9


def dome(k, r, h=None, onion=True, seg=12, rng=None, fin="sun", ribs=False, collar=True):
    """Yellow: onion dome (or half dome) with a ring collar, ribs and a gold sun finial.
    Returns (pieces, apex_z)."""
    col = kc(k, "roof")
    if onion and r < 2.5:
        h = h or r * 2.0
        prof = [(r * 0.98, 0.0), (r * 1.16, h * 0.24), (r * 0.98, h * 0.48), (r * 0.48, h * 0.7),
                (r * 0.14, h * 0.88), (0.0, h)]
    elif onion:
        h = h or r * 2.0
        prof = [(r * 0.98, 0.0), (r * 1.12, h * 0.16), (r * 1.18, h * 0.3), (r * 1.08, h * 0.45),
                (r * 0.78, h * 0.6), (r * 0.42, h * 0.74), (r * 0.16, h * 0.88), (r * 0.06, h * 0.97), (0.0, h)]
    else:
        h = h or r * 1.0
        prof = [(r, 0.0)] + [(r * math.cos(a), h * math.sin(a)) for a in
                             (math.radians(d) for d in (20, 40, 58, 74, 86))] + [(0.0, h)]
    d = lathe(prof, seg, col, cap_bottom=True).paint(smooth=True, grad=("range", 0.25, 1.0))
    d.face_smooth = None
    out = [d]
    if collar:
        out.append(annulus(r * 0.86, r * 1.04, -0.5, 0.25, seg, "gold_dark"))  # collar
    # ribs (gold) on the lower bulge
    for i in range(seg // 2 if ribs else 0):
        a = 2 * math.pi * i / (seg // 2)
        pts = [(rr * 1.015, z) for rr, z in prof[1:-2]]
        if not onion:
            pts = pts[:4:2] + pts[4:5]
        for (ra, za), (rb, zb) in zip(pts, pts[1:]):
            p0 = Vector((math.cos(a) * ra, math.sin(a) * ra, za))
            p1 = Vector((math.cos(a) * rb, math.sin(a) * rb, zb))
            out.append(kit.oriented_box(p0, p1, 0.22, 0.2, "gold_dark", Vector((math.cos(a), math.sin(a), 0))))
    f = sun_finial("gold", 3.6) if fin == "sun" else finial("gold", 1.8, 0.3, 0.25)
    for p in f:
        p.move(0, 0, h - 0.2)
    out += f
    return out, h + (3.3 if fin == "sun" else 1.6)


def merlon(style, k, w=MERLON_W, h=MERLON_H, t=1.3, color=None, cap=True):
    """One merlon on z=0 centred at the origin, thickness t along Y. Styles:
    square (cap stone), swallow (Ghibelline horns, red), stepped (Moorish, yellow), peaked (blue)."""
    col = color or kc(k, "stone")
    capc = kc(k, "stone_light")
    out = []
    if style == "swallow":
        poly = [(-w / 2, 0.0), (w / 2, 0.0), (w / 2, h + 0.55), (0.0, h - 0.45), (-w / 2, h + 0.55)]
        out.append(prism(poly, t, col))
    elif style == "stepped":
        hw = w / 2
        poly = [(-hw, 0.0), (hw, 0.0), (hw, h * 0.55), (hw * 0.55, h * 0.55), (hw * 0.55, h * 0.86),
                (0.0, h * 1.15), (-hw * 0.55, h * 0.86), (-hw * 0.55, h * 0.55), (-hw, h * 0.55)]
        out.append(prism(poly, t, col))
    elif style == "pyramid":
        out.append(box(w, t, h - 0.3, col))
        out.append(box(w + 0.3, t + 0.3, 0.3, capc).move(0, 0, h - 0.3))
        s2 = math.sqrt(2.0)
        hw2 = (w + 0.1) / 2
        out.append(lathe([(hw2 * s2, 0.0), (hw2 * s2, 0.25), (0.0, 1.9)], 4, kc(k, "roof"), phase=math.pi / 4)
                   .scale(1.0, (t + 0.1) / (w + 0.1), 1.0).move(0, 0, h).paint(grad=("range", 0.3, 1.0)))
    elif style == "peaked":
        out.append(box(w, t, h, col))
        out.append(square_lathe([(w * 0.42, 0.0), (w * 0.42, 0.2), (0.0, 0.95)], capc).move(0, 0, h - 0.05)
                   .scale(1.0, t / w * 1.15, 1.0))
    else:
        out.append(box(w, t, h - 0.35, col))
        if cap:
            out.append(kit.bbox(w + 0.3, t + 0.3, 0.42, capc, 0.08).move(0, 0, h - 0.4))
    return out


def dormer(k, w=2.8, h=3.0, depth=4.0, pitch=52.0):
    """Gabled roof dormer (plaster + timber, kingdom-tile roof, shuttered window) facing -Y.
    Front face at y=0, base at z=0; the body runs back into the roof (+Y)."""
    out = [box(w, depth, h, "plaster").move(0, depth / 2, 0).paint(grad=("range", 0.4, 0.85))]
    for sx in (-1, 1):
        out.append(box(0.45, 0.5, h, "timber").move(sx * (w / 2 - 0.15), -0.05, 0))
    out += window_v(1.3, 1.7, "timber", kc(k, "shutter"), arched=False, open_angle=0.3)
    out[-1].move(0, 0, 0)
    for p in out[3:]:
        p.move(0, 0, 0.55)
    roof, rise = kit.gable_roof(w, depth, pitch, overhang=0.45, gable_overhang=0.35, thickness=0.42,
                                color=kc(k, "roof"), rows=1, ridge_color=kc(k, "roof_dark"), style="tile")
    for p in roof:
        out.append(p.move(0, depth / 2, h))
    out.append(kit.gable_end(w, rise, 0.4, "plaster").move(0, 0.2, h).paint(grad=("range", 0.5, 0.85)))
    return out
