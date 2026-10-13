"""Private helpers for the large village buildings (building_barracks, building_tavern,
building_workshop): kingdom heraldry (emblems, banners, shields), military yard props,
watch turrets in each kingdom's tower language, timber framing with chosen bays, stairs,
and the tavern/workshop props (barrels, crates, benches, tables, lanterns, planks).

Everything is built from lib/kit.py parts and lib/geo.py primitives so these buildings
share the cottage's timber sizes, bevels, windows, doors and roofs. Facades face -Y.
Not a generator (leading underscore): build.py skips it.
"""

import math

from lib import kit
from lib.geo import Vector, box, cylinder, lathe, merge, prism
from lib.palette import kingdom_color

from generators._kingdom_props_common import emblem as kit_emblem
from generators._kingdom_props_common import sun_badge

KINGDOM_CYCLE = ("red", "blue", "green", "yellow")
# finial / small metal accent per kingdom (ART_DIRECTION section 3)
FINIAL = {"red": "gold", "blue": "steel", "green": "bronze", "yellow": "gold"}


def grounded(piece):
    """Clamp a tilted leg's foot to the ground plane (z >= 0) so the asset's lowest point is the
    ground and the pivot (base centre) sits exactly on it."""
    return piece.bend(lambda v: (v.x, v.y, max(v.z, 0.0)))


# ------------------------------------------------------------------ heraldry

def emblem_poly(k, s=1.0):
    """Kingdom emblem outline (x, z), about s studs tall, centred on the origin: red crown, blue star.
    (No green / yellow: the kit-wide oak leaf and sun are layered, see `emblem`.)"""
    pts = []
    if k == "blue":
        for i in range(10):
            a = math.pi / 2 + math.pi * i / 5
            r = 0.52 if i % 2 == 0 else 0.22
            pts.append((math.cos(a) * r, math.sin(a) * r))
    elif k in ("yellow", "green"):
        raise ValueError(f"emblem_poly({k!r}): the kit-wide sun / oak leaf is layered, draw it with emblem({k!r}, ...)")
    else:  # red crown
        pts = [(-0.5, -0.3), (0.5, -0.3), (0.5, 0.06), (0.58, 0.44), (0.27, 0.14), (0.0, 0.52),
               (-0.27, 0.14), (-0.58, 0.44), (-0.5, 0.06)]
    return [(x * s, z * s) for x, z in pts]


def emblem(k, s=1.0, depth=0.14, color=None, lobe_pts=2):
    """Solid emblem facing -Y (plane XZ), centred on the origin (`depth` thick around y = 0).
    Yellow is the kit-wide Sunspire sun (_kingdom_props_common.sun_badge, `color` ignored): deep-gold
    rays + disc on an ivory roundel with a bronze rim, s studs across, because the banners, flags and
    shields put it on gold cloth (D-033: never an emblem on its own colour). The roundel fills the
    old `depth` envelope, the sun stands proud of it; merged into ONE piece like the other emblems.
    Green is the kit-wide oak leaf (_kingdom_props_common.emblem("oak"): ivory leaf, bronze midrib and
    stem), 0.8 s wide and 1.18 s tall; lobe_pts=2 (flat-topped lobes) keeps the small shields and flags
    cheap, the big banners pass 3 (the full round lobes)."""
    if k == "yellow":
        parts = sun_badge(0.52 * s, depth, sun_depth=depth * 0.9)
        parts[0].paint(grad=("range", 0.55, 0.95))  # merge() keeps the first piece's gradient
        return merge(parts)
    if k == "green":
        parts = kit_emblem("oak", s, color or kingdom_color(k, "emblem"), kingdom_color(k, "trim"), depth=depth,
                           mid=None, lobe_pts=lobe_pts)
        return merge(parts).move(0, 0, 0.0575 * s)  # leaf + stem centred on the origin
    return prism(emblem_poly(k, s), depth, color or kingdom_color(k, "emblem"))


def banner(k, w=2.6, h=8.0, tail="swallow", rod=True, emblem_color=None):
    """Hanging banner on a wall at y=0 facing -Y. Top edge at z=0, hangs down to -h, centred on x=0.
    Trim-coloured border, kingdom cloth, a stripe and the emblem; iron rod on two brackets."""
    out = []
    cloth = kingdom_color(k, "cloth")
    trim = kingdom_color(k, "trim")
    notch = min(w * 0.42, 1.3)

    def shape(ww, hh, dz=0.0):
        if tail == "swallow":
            return [(-ww / 2, dz), (ww / 2, dz), (ww / 2, -hh), (0.0, -hh + notch), (-ww / 2, -hh)]
        return [(-ww / 2, dz), (ww / 2, dz), (ww / 2, -hh + notch), (0.0, -hh), (-ww / 2, -hh + notch)]

    border = prism(shape(w + 0.4, h + 0.3, 0.1), 0.16, trim).move(0, -0.2, 0)
    out.append(border.paint(grad=("range", 0.4, 0.9)))
    out.append(prism(shape(w, h), 0.2, cloth).move(0, -0.36, 0).paint(grad=("range", 0.35, 0.95)))
    out.append(box(w, 0.12, 0.4, trim).move(0, -0.5, -1.0))
    out.append(box(w, 0.12, 0.28, trim).move(0, -0.5, -h * 0.72))
    out.append(emblem(k, w * 0.66, 0.12, emblem_color, lobe_pts=3).move(0, -0.52, -h * 0.42))
    if rod:
        r = cylinder(0.15, 0.15, w + 1.0, 6, "iron_dark").rotate(math.pi / 2, "Y")
        out.append(r.move(-(w + 1.0) / 2, -0.42, 0.12))
        for sx in (-1, 1):
            out.append(lathe([(0.0, 0.0), (0.26, 0.15), (0.26, 0.35), (0.0, 0.6)], 6, FINIAL[k])
                       .rotate(sx * math.pi / 2, "Y").move(sx * (w + 1.0) / 2, -0.42, 0.12))
            out.append(box(0.22, 0.5, 0.22, "iron_dark").move(sx * (w / 2 - 0.2), -0.25, 0.01))
    return out


def heater_shield(k, w=1.8, h=2.3, with_emblem=True):
    """Heater shield facing -Y, back face at y=0, centred on (0, 0) in x/z."""
    pts = []
    top = h * 0.42
    side = h * 0.02
    tip = -h * 0.58
    for i in range(6):
        t = i / 5
        pts.append((w / 2 * math.cos(t * math.pi / 2), side + (tip - side) * math.sin(t * math.pi / 2)))
    right = pts[:-1]
    poly = [(-w / 2, top), (w / 2, top)] + right + [(0.0, tip)] + [(-x, z) for x, z in reversed(right)]
    out = [prism(poly, 0.2, kingdom_color(k, "trim")).move(0, -0.1, 0)]
    inner = [(x * 0.84, z * 0.86 - h * 0.01) for x, z in poly]
    out.append(prism(inner, 0.2, kingdom_color(k, "cloth")).move(0, -0.22, 0))
    if with_emblem:
        out.append(emblem(k, w * 0.52, 0.1).move(0, -0.36, -h * 0.02))
    else:  # cheap heraldry: a pale (vertical stripe) and a chief band in the emblem colour
        out.append(box(w * 0.2, 0.1, h * 0.78, kingdom_color(k, "emblem")).move(0, -0.36, -h * 0.42))
        out.append(box(w * 0.82, 0.1, h * 0.12, kingdom_color(k, "emblem")).move(0, -0.36, h * 0.22))
    return out


# ------------------------------------------------------------------ military props

def spear(length=6.4, tip="steel", pennant=None):
    """Spear standing on z=0 along +Z."""
    out = [cylinder(0.13, 0.12, length - 1.0, 6, "wood_light")]
    out.append(cylinder(0.17, 0.17, 0.3, 6, "iron_dark").move(0, 0, length - 1.05))
    out.append(lathe([(0.0, length - 0.8), (0.24, length - 0.55), (0.0, length + 0.15)], 4, tip, cap_bottom=False))
    if pennant:
        out.append(prism([(0.0, 0.0), (1.3, -0.35), (0.0, -0.7)], 0.08, pennant).move(0.12, 0, length - 1.3))
    return out


def weapon_rack(k, rng, length=5.2, spears=5, shields=2):
    """Freestanding spear rack with shields hung on the front rail. Front faces -Y, base z=0,
    centred, ~1.6 deep. Shields in the kingdom colours."""
    out = []
    nx = Vector((1, 0, 0))
    for sx in (-1, 1):
        x = sx * length / 2
        out.append(grounded(kit.oriented_box((x, -0.7, 0), (x, -0.05, 5.0), 0.38, 0.38, "wood_dark", nx)))
        out.append(grounded(kit.oriented_box((x, 0.6, 0), (x, -0.05, 5.0), 0.38, 0.38, "wood_dark", nx)))
    ny = Vector((0, -1, 0))
    out.append(kit.oriented_box((-length / 2 - 0.35, -0.1, 4.55), (length / 2 + 0.35, -0.1, 4.55), 0.42, 0.42,
                                "wood", ny))
    out.append(kit.oriented_box((-length / 2, -0.5, 1.3), (length / 2, -0.5, 1.3), 0.4, 0.4, "wood", ny))
    out.append(kit.bbox(length + 0.2, 1.2, 0.35, "wood_dark", 0.08).move(0, -0.2, 0))
    for i in range(spears):
        u = -length / 2 + 0.5 + (length - 1.0) * i / max(1, spears - 1)
        pen = kingdom_color(k, "cloth") if i in (0, spears - 1) else None
        lean = rng.uniform(0.04, 0.09)
        for pc in spear(rng.uniform(6.2, 6.9), pennant=pen):
            out.append(pc.rotate(-lean, "X").rotate(rng.uniform(-0.04, 0.04), "Y").move(u, -0.35, 0.35))
    for j in range(shields):
        u = -length / 2 + length * (j + 0.5) / shields
        for pc in heater_shield(k, 1.6, 2.0, with_emblem=False):
            out.append(pc.rotate(rng.uniform(-0.12, 0.12), "Y").move(u, -0.72, 1.7))
    return out


def dummy(rng, k=None):
    """Straw training dummy on a post with crossed feet; ~6.6 tall, base z=0."""
    out = [box(2.8, 0.5, 0.4, "wood_dark"), box(0.5, 2.8, 0.4, "wood_dark")]
    out.append(cylinder(0.3, 0.26, 6.2, 6, "wood").move(0, 0, 0.3))
    body = lathe([(0.0, 0.0), (0.72, 0.1), (1.05, 0.7), (1.12, 1.5), (0.98, 2.2), (0.55, 2.55), (0.0, 2.62)], 8,
                 "straw", smooth=True, grad=("range", 0.2, 0.95))
    out.append(body.jitter(rng, 0.07).move(0, 0, 2.2))
    for z, r in ((2.75, 1.06), (4.15, 1.08)):
        out.append(cylinder(r, r, 0.24, 8, "rope").move(0, 0, z))
    arm = kit.oriented_box((-2.0, 0, 3.9), (2.0, 0, 3.9), 0.34, 0.34, "wood", Vector((0, -1, 0)))
    out.append(arm)
    for sx in (-1, 1):
        wrap = lathe([(0.0, 0.0), (0.42, 0.1), (0.46, 0.7), (0.0, 0.85)], 6, "hay", smooth=True)
        out.append(wrap.rotate(sx * math.pi / 2, "Y").move(sx * 1.35, 0, 3.9))
    head = lathe([(0.0, 0.0), (0.5, 0.1), (0.68, 0.55), (0.6, 1.05), (0.0, 1.3)], 7, "hay", smooth=True,
                 grad=("range", 0.3, 1.0))
    out.append(head.jitter(rng, 0.05).move(0, 0, 4.85))
    if k:
        out.append(cylinder(1.13, 1.1, 0.42, 8, kingdom_color(k, "cloth")).move(0, 0, 3.35))
    helm = lathe([(0.74, 0.0), (0.74, 0.12), (0.66, 0.45), (0.38, 0.72), (0.0, 0.8)], 7, "iron")
    out.append(helm.move(0, 0, 5.85))
    return out


def archery_target(rng, k=None, arrows=3):
    """Straw butt with painted rings on a tripod easel, facing -Y, leaning back. Base z=0."""
    out = []
    R = 1.9
    tgt = [cylinder(R, R, 0.9, 12, "straw", smooth=False, grad=("range", 0.4, 0.95))]
    tgt.append(cylinder(R * 0.78, R * 0.78, 0.98, 12, "cloth_white"))
    tgt.append(cylinder(R * 0.55, R * 0.55, 1.04, 12, kingdom_color(k, "cloth") if k else "flower_red"))
    tgt.append(cylinder(R * 0.3, R * 0.3, 1.1, 10, "cloth_white"))
    tgt.append(cylinder(R * 0.13, R * 0.13, 1.14, 8, "flower_yellow"))
    tilt = math.pi / 2 - 0.22
    cz = 3.6
    for pc in tgt:
        out.append(pc.move(0, 0, -0.45).rotate(tilt, "X").move(0, 0, cz))
    nx = Vector((1, 0, 0))
    for sx in (-1, 1):
        out.append(grounded(kit.oriented_box((sx * 1.5, -0.6, 0), (sx * 0.9, 0.5, 5.6), 0.32, 0.32, "wood", nx)))
    out.append(grounded(kit.oriented_box((0, 2.4, 0), (0, 0.7, 5.0), 0.32, 0.32, "wood", nx)))
    out.append(kit.oriented_box((-1.5, 0.15, 1.6), (1.5, 0.15, 1.6), 0.3, 0.3, "wood_dark", Vector((0, -1, 0))))
    for i in range(arrows):
        a = rng.uniform(0, math.tau)
        rr = rng.uniform(0.2, 1.3)
        x, z = math.cos(a) * rr, math.sin(a) * rr
        sh = cylinder(0.06, 0.06, 2.0, 4, "wood_pale")
        fl = box(0.04, 0.4, 0.3, "cloth_white").move(0, 0, 1.6)
        ar = merge([sh, fl]).rotate(math.pi / 2 - 0.22, "X")  # +Z -> towards -Y (out of the face)
        p = Vector((x, 0, z))
        # point on the tilted face plane
        out.append(ar.move(p.x, -0.55 - z * 0.22, cz + z * 0.97))
    return out


# ------------------------------------------------------------------ turret (kingdom tower language)

def turret(k, rng, r=3.0, h=20.0, stone=None, stone_dark=None):
    """Watch turret, base z=0 centred. Red: round + tall cone spire; blue: square + crisp
    pyramid; green: round + timber hoarding and a low cone; yellow: round + onion dome."""
    stone = stone or kingdom_color(k, "stone")
    stone_dark = stone_dark or kingdom_color(k, "stone_dark")
    roof = kingdom_color(k, "roof")
    out = []
    square = k == "blue"
    if square:
        hs = r * 0.9
        out.append(kit.bbox(hs * 2 + 0.8, hs * 2 + 0.8, 2.2, stone_dark, 0.2))
        out.append(kit.bbox(hs * 2, hs * 2, h, stone, 0.2).paint(grad=("range", 0.2, 0.85)))
        for sx in (-1, 1):  # quoins
            for sy in (-1, 1):
                for j in range(int((h - 2.4) // 2.0)):
                    big = j % 2 == 0
                    q = box(1.6 if big else 1.0, 1.0 if big else 1.6, 1.8, kingdom_color(k, "stone_light"))
                    q.move(sx * (hs - (0.65 if big else 0.35) + 0.16), sy * (hs - (0.35 if big else 0.65) + 0.16),
                           2.4 + j * 2.0)
                    out.append(q)
        out.append(kit.bbox(hs * 2 + 0.7, hs * 2 + 0.7, 0.6, stone_dark, 0.12).move(0, 0, h - 2.6))
        out.append(kit.bbox(hs * 2 + 1.0, hs * 2 + 1.0, 0.7, stone_dark, 0.15).move(0, 0, h - 0.4))
        rad = (hs + 0.5) * math.sqrt(2)
        for pc in kit.cone_roof(rad, hs * 3.6, seg=4, color=roof, overhang=0.9, flare=False, finial=FINIAL[k],
                                rows=2):
            out.append(pc.move(0, 0, h + 0.3))
        slit_r = hs
    else:
        prof = [(r + 0.55, 0.0), (r + 0.45, 1.4), (r + 0.05, 3.2), (r, h)]
        out.append(lathe(prof, 10, stone).paint(grad=("range", 0.2, 0.85)))
        out.append(cylinder(r + 0.3, r + 0.3, 0.6, 10, stone_dark).move(0, 0, h - 2.6))
        slit_r = r
        if k == "green":
            # timber hoarding: overhanging wooden gallery with posts, joists and a low cone
            hr = r + 1.0
            for i in range(8):
                a = math.tau * (i + 0.5) / 8
                out.append(kit.oriented_box((math.cos(a) * (r - 0.2), math.sin(a) * (r - 0.2), h - 0.5),
                                            (math.cos(a) * (hr + 0.3), math.sin(a) * (hr + 0.3), h - 0.5),
                                            0.5, 0.5, "timber", Vector((0, 0, 1))))
            out.append(lathe([(hr, 0.0), (hr, 0.3), (hr + 0.05, 3.2)], 8, "wood", phase=0.0).move(0, 0, h))
            out.append(cylinder(hr + 0.25, hr + 0.25, 0.45, 8, "timber", phase=0.0).move(0, 0, h - 0.1))
            for i in range(8):
                a = math.tau * i / 8
                out.append(kit.oriented_box((math.cos(a) * (hr + 0.02), math.sin(a) * (hr + 0.02), h),
                                            (math.cos(a) * (hr + 0.02), math.sin(a) * (hr + 0.02), h + 3.3),
                                            0.45, 0.4, "timber", Vector((math.cos(a), math.sin(a), 0))))
            for i in (5, 6, 7):  # dark shooting gaps facing front-ish
                a = math.tau * (i + 0.5) / 8
                c = Vector((math.cos(a), math.sin(a), 0)) * (hr * math.cos(math.pi / 8) + 0.06)
                out.append(kit.oriented_box((c.x, c.y, h + 1.3), (c.x, c.y, h + 2.4), 1.2, 0.2, "window_dark",
                                            Vector((math.cos(a), math.sin(a), 0))))
            for pc in kit.cone_roof(hr - 0.6, hr * 1.25, seg=8, color=roof, overhang=0.9, finial=FINIAL[k], rows=2):
                out.append(pc.move(0, 0, h + 3.2))
        elif k == "yellow":
            out.append(cylinder(r + 0.45, r + 0.45, 0.8, 10, kingdom_color(k, "trim")).move(0, 0, h - 0.4))
            out.append(cylinder(r - 0.1, r - 0.1, 1.6, 10, stone).move(0, 0, h + 0.4))  # drum
            dome = lathe([(r + 0.1, 0.0), (r + 0.75, 1.1), (r + 0.95, 2.4), (r + 0.6, 3.9), (r * 0.42, 5.6),
                          (0.5, 7.0), (0.0, 7.7)], 12, roof, smooth=True, grad=("range", 0.15, 1.0))
            out.append(dome.move(0, 0, h + 1.9))
            out.append(lathe([(0.38, 0.0), (0.38, 0.6), (0.66, 1.0), (0.0, 2.2)], 6, "gold", smooth=True)
                       .move(0, 0, h + 9.4))
        else:  # red spire
            out.append(cylinder(r + 0.5, r + 0.45, 0.7, 10, stone_dark).move(0, 0, h - 0.4))
            for pc in kit.cone_roof(r + 0.2, r * 3.4, seg=10, color=roof, overhang=0.7, finial=FINIAL[k], rows=3):
                out.append(pc.move(0, 0, h + 0.3))
    # arrow slits facing front and both sides
    for a in (-math.pi / 2, -math.pi / 2 - 0.9, -math.pi / 2 + 0.9):
        c = Vector((math.cos(a), math.sin(a), 0))
        if square and abs(a + math.pi / 2) > 0.1:
            continue
        d = slit_r - 0.1
        for z in (h * 0.42, h - 5.2):
            p = c * d
            out.append(kit.oriented_box((p.x, p.y, z), (p.x, p.y, z + 2.2), 0.55, 0.5, "window_dark", c))
            out.append(kit.oriented_box((p.x, p.y, z + 2.2), (p.x, p.y, z + 2.6), 0.95, 0.6, stone_dark, c))
    return out


# ------------------------------------------------------------------ walls / structure

def frame_wall(length, height, axis, offset, posts, braces=(), rail=None, color="timber", rail_skip=(), rng=None,
               crooked=0.09):
    """Timber framing with explicit post positions (u, centre-relative) and braces only in the
    listed panels (panel i = between posts i and i+1). Same member sizes as kit.wall_face_frame,
    and the same hand-cut wander (endpoints move up to `crooked`) when an rng is given."""
    out = []
    sgn = 1 if offset >= 0 else -1
    nrm = Vector((0, sgn, 0)) if axis == "x" else Vector((sgn, 0, 0))
    t = kit.TIMBER
    d = kit.TIMBER_OUT * 2

    def P(u, z):
        if rng and crooked:
            u += rng.uniform(-crooked, crooked)
            z += rng.uniform(-crooked, crooked) * 0.6
        return Vector((u, offset, z)) if axis == "x" else Vector((offset, u, z))

    half = length / 2
    for z in (t / 2, height - t / 2):
        out.append(kit.oriented_box(P(-half, z), P(half, z), t, d, color, nrm))
    for u in posts:
        out.append(kit.oriented_box(P(u, 0), P(u, height), t, d, color, nrm))
    if rail:
        for i in range(len(posts) - 1):
            if i in rail_skip:
                continue
            out.append(kit.oriented_box(P(posts[i], rail), P(posts[i + 1], rail), t * 0.8, d * 0.9, color, nrm))
    for i, flip in braces:
        a, b_ = posts[i], posts[i + 1]
        lo, hi = height * 0.06, height * 0.62
        if flip:
            out.append(kit.oriented_box(P(a + t / 2, lo), P(b_ - t / 2, hi), t * 0.8, d * 0.85, color, nrm))
        else:
            out.append(kit.oriented_box(P(b_ - t / 2, lo), P(a + t / 2, hi), t * 0.8, d * 0.85, color, nrm))
    return out


def stairs(width, top_z, steps=3, tread=1.2, color="stone", rng=None):
    """Stone steps against a facade at y=0 (going out to -Y), from the ground up to top_z."""
    out = []
    for i in range(steps):
        hh = top_z * (i + 1) / steps
        dd = tread * (steps - i)
        w = width + 0.6 * (steps - i)
        s = kit.bbox(w, dd, hh, color, 0.12).move(0, -dd / 2 + 0.05, 0)
        out.append(s.paint(tint=rng.uniform(0.2, 0.8) if rng else None))
    return out


def quoins(x, y, sx, sy, z0, h, color, size=(1.9, 1.2, 1.7), pitch=1.9):
    """Alternating corner stones on a building corner at (x, y); sx/sy = outward signs."""
    out = []
    big_l, small_l, hh = size
    for j in range(int(h // pitch)):
        big = j % 2 == 0
        q = box(big_l if big else small_l, small_l if big else big_l, hh, color)
        q.move(x - sx * ((big_l if big else small_l) / 2 - 0.18), y - sy * ((small_l if big else big_l) / 2 - 0.18),
               z0 + 0.12 + j * pitch)
        out.append(q)
    return out


def oculus(r=1.4, frame="stone_light", glass="window_dark"):
    """Round window facing -Y on a wall at y=0, centred on (0, 0)."""
    out = [cylinder(r + 0.45, r + 0.45, 0.5, 10, frame).rotate(math.pi / 2, "X").move(0, 0.1, 0)]
    out.append(cylinder(r, r, 0.62, 10, glass).rotate(math.pi / 2, "X").move(0, 0.12, 0))
    out.append(box(0.22, 0.3, r * 2, "timber", base=False).move(0, -0.45, 0))
    out.append(box(r * 2, 0.3, 0.22, "timber", base=False).move(0, -0.45, 0))
    return out


# ------------------------------------------------------------------ village props

def barrel(r=1.0, h=2.5, color="wood"):
    out = [lathe([(0.0, 0.0), (r, 0.0), (r * 1.18, h * 0.4), (r * 1.18, h * 0.6), (r, h), (0.0, h)], 8, color)]
    for zz in (h * 0.2, h * 0.74):
        out.append(cylinder(r * 1.17, r * 1.17, 0.18, 8, "iron_dark").move(0, 0, zz))
    return out


def barrel_lying(r=1.0, h=2.5, color="wood"):
    """Barrel on its side along X, resting on z=0."""
    return [pc.move(0, 0, -h / 2).rotate(math.pi / 2, "Y").move(0, 0, r * 1.18) for pc in barrel(r, h, color)]


def crate(s=2.0, color="wood_light"):
    out = [kit.bbox(s, s, s, color, 0.12)]
    for sy in (-1, 1):
        out.append(box(s * 0.98, 0.1, 0.3, "wood_dark").move(0, sy * (s / 2 + 0.02), s * 0.75))
    return out


def lantern(glow="window_glow"):
    """Hanging lantern; top (hook) at z=0, body below. ~1.5 tall."""
    out = [box(0.7, 0.7, 0.9, glow).move(0, 0, -1.25)]
    out.append(kit.bbox(1.0, 1.0, 0.18, "iron_dark", 0.05).move(0, 0, -1.4))
    out.append(lathe([(0.62, 0.0), (0.0, 0.42)], 4, "iron_dark", phase=math.pi / 4).move(0, 0, -0.36))
    for sx in (-1, 1):
        for sy in (-1, 1):
            out.append(box(0.12, 0.12, 0.9, "iron_dark").move(sx * 0.38, sy * 0.38, -1.25))
    out.append(cylinder(0.08, 0.08, 0.3, 4, "iron_dark").move(0, 0, -0.06))
    return out


def bracket(length=2.6, drop=1.2, color="iron_dark", normal=Vector((0, -1, 0))):
    """Wrought iron wall bracket projecting along -Y from a wall at y=0; arm top at z=0."""
    n = Vector((1, 0, 0))
    out = [kit.oriented_box((0, 0.0, 0), (0, -length, 0), 0.2, 0.22, color, n)]
    out.append(kit.oriented_box((0, 0.0, -drop), (0, -length * 0.6, -0.05), 0.16, 0.16, color, n))
    out.append(kit.bbox(0.7, 0.2, drop + 0.6, color, 0.04).move(0, -0.05, -drop - 0.3))
    out.append(lathe([(0.0, 0.0), (0.18, 0.1), (0.0, 0.35)], 4, color).rotate(math.pi / 2, "X")
               .move(0, -length - 0.0, 0))
    return out


def bench(length=5.0, color="wood"):
    """Plank bench along X, base z=0, seat at ~1.8."""
    out = [box(length, 1.1, 0.32, color).move(0, 0, 1.6)]
    for sx in (-1, 1):
        out.append(box(0.32, 0.9, 1.6, "wood_dark").move(sx * (length / 2 - 0.6), 0, 0))
    return out


def table(length=5.0, width=2.6, color="wood_light"):
    """Trestle table along X, base z=0, top at ~3.0."""
    out = [kit.bbox(length, width, 0.32, color, 0.08).move(0, 0, 2.7)]
    for sx in (-1, 1):
        x = sx * (length / 2 - 0.7)
        out.append(grounded(kit.oriented_box((x, -width / 2 + 0.3, 0), (x, 0, 2.7), 0.3, 0.3, "wood_dark",
                                             Vector((1, 0, 0)))))
        out.append(grounded(kit.oriented_box((x, width / 2 - 0.3, 0), (x, 0, 2.7), 0.3, 0.3, "wood_dark",
                                             Vector((1, 0, 0)))))
    out.append(box(length - 1.2, 0.25, 0.25, "wood_dark").move(0, 0, 1.0))
    return out


def tankard(color="wood_light"):
    """Small tankard with a foam top and a handle, base z=0."""
    out = [cylinder(0.3, 0.27, 0.62, 6, color)]
    out.append(cylinder(0.31, 0.33, 0.16, 6, "foam").move(0, 0, 0.6))
    out.append(box(0.12, 0.12, 0.42, "iron_dark").move(0.36, 0, 0.12))
    return out


def plank_stack(rng, length=8.0, width=3.0, layers=4, color="wood_pale"):
    """Stacked sawn boards with spacer sticks between layers; along X, base z=0."""
    out = []
    z = 0.0
    nb = max(2, int(width // 0.95))
    bw = width / nb
    for L in range(layers):
        for i in range(nb):
            ll = length * rng.uniform(0.92, 1.0)
            pl = box(ll, bw - 0.08, 0.32, color).move(rng.uniform(-0.25, 0.25), -width / 2 + bw * (i + 0.5), z)
            out.append(pl.paint(tint=rng.uniform(0.1, 0.9)))
        z += 0.32
        if L < layers - 1:
            for sx in (-0.36, 0.36):
                out.append(box(0.3, width + 0.2, 0.22, "wood_dark").move(sx * length, 0, z))
            z += 0.22
    return out


def log(length=8.0, r=0.7, rng=None):
    """Bark log along X centred, resting on z=0, with pale cut ends."""
    lg = cylinder(r, r * 0.92, length, 7, "bark").move(0, 0, -length / 2).rotate(math.pi / 2, "Y")
    if rng:
        lg.jitter(rng, 0.04)
    out = [lg.move(0, 0, r)]
    for sx in (-1, 1):
        c = cylinder(r * 0.8, r * 0.8, 0.12, 7, "wood_pale").move(0, 0, -0.06).rotate(math.pi / 2, "Y")
        out.append(c.move(sx * (length / 2 + 0.01) * (1 if sx > 0 else 1), 0, r))
    return out


def sawhorse(length=3.4, h=2.8, color="wood"):
    """X-legged sawhorse along X, top beam at z=h."""
    out = [kit.bbox(length, 0.45, 0.45, color, 0.06).move(0, 0, h - 0.45)]
    nx = Vector((1, 0, 0))
    for sx in (-1, 1):
        x = sx * (length / 2 - 0.4)
        out.append(grounded(kit.oriented_box((x, -0.9, 0), (x, 0.15, h - 0.2), 0.3, 0.3, "wood_dark", nx)))
        out.append(grounded(kit.oriented_box((x, 0.9, 0), (x, -0.15, h - 0.2), 0.3, 0.3, "wood_dark", nx)))
    return out


def flag(k, w=4.6, h=2.8, pole_h=9.0):
    """Flagpole (base z=0) with a swallow-tailed kingdom flag flying towards +X, facing -Y."""
    out = [cylinder(0.22, 0.16, pole_h, 6, "wood_dark")]
    out.append(lathe([(0.0, 0.0), (0.34, 0.2), (0.34, 0.45), (0.0, 0.8)], 6, FINIAL[k]).move(0, 0, pole_h))
    notch = h * 0.35
    zt = pole_h - 0.3
    poly = [(0.0, 0.0), (w, 0.15), (w - notch, -h / 2 + 0.05), (w, -h + 0.15), (0.0, -h)]
    cl = prism(poly, 0.18, kingdom_color(k, "cloth")).move(0.15, 0, zt).paint(grad=("range", 0.4, 0.95))
    cl.bend(lambda v: (v.x, v.y + 0.25 * math.sin(v.x * 1.3), v.z - 0.05 * v.x))
    out.append(cl)
    out.append(emblem(k, h * 0.62, 0.12).move(w * 0.42, -0.1 + 0.25 * math.sin(w * 0.42 * 1.3) - 0.06,
                                               zt - h / 2 - 0.02 * w))
    return out


def pad(a, b, n=20, rng=None, expo=0.45, color="dirt", thick=0.12):
    """Flat irregular ground patch (superellipse a x b half-sizes), base z=0, centred."""
    pts = []
    for i in range(n):
        t = math.tau * i / n
        c, s_ = math.cos(t), math.sin(t)
        j = 1.0 + (rng.uniform(-0.05, 0.05) if rng else 0.0)
        pts.append((a * j * math.copysign(abs(c) ** expo, c), b * j * math.copysign(abs(s_) ** expo, s_)))
    return prism(pts, thick, color, axis="Z").paint(grad="flat")


def posts_for(length, openings, min_gap=1.0):
    """Post positions (centre-relative) for a framed wall: both ends plus a post either side of
    every opening; openings = [(centre_u, half_width), ...]."""
    t = kit.TIMBER
    half = length / 2
    ps = [-half + t / 2, half - t / 2]
    for c, hw in openings:
        ps += [c - hw - t / 2 - 0.04, c + hw + t / 2 + 0.04]
    out = []
    for u in sorted(ps):
        if -half <= u <= half and (not out or u - out[-1] >= min_gap):
            out.append(u)
    return out


def braces_for(posts, openings, rng, min_w=1.8):
    """Alternating braces in every panel that holds no opening."""
    br = []
    for i in range(len(posts) - 1):
        a, b_ = posts[i], posts[i + 1]
        if b_ - a < min_w or any(a - 0.1 < c < b_ + 0.1 for c, _ in openings):
            continue
        br.append((i, (i + rng.randint(0, 1)) % 2 == 0))
    return br


def tankard_icon(color="gold", foam="foam", depth=0.5, s=1.0):
    """Tankard silhouette for a sign board in the YZ plane (visible from +X and -X), centred."""
    out = [box(depth, 0.95 * s, 1.15 * s, color, base=False).move(0, -0.12 * s, -0.08 * s)]
    out.append(prism([(-0.62 * s, 0.45 * s), (0.4 * s, 0.45 * s), (0.5 * s, 0.62 * s), (0.25 * s, 0.82 * s),
                      (-0.1 * s, 0.7 * s), (-0.45 * s, 0.84 * s), (-0.7 * s, 0.62 * s)], depth + 0.04, foam,
                     axis="X"))
    for z0_, z1_ in ((-0.38, 0.32),):
        out.append(box(depth, 0.18 * s, (z1_ - z0_) * s, color, base=False).move(0, 0.62 * s, (z0_ + z1_) / 2 * s))
    for zz in (-0.38, 0.32):
        out.append(box(depth, 0.32 * s, 0.16 * s, color, base=False).move(0, 0.48 * s, zz * s))
    return out


def hanging_sign(k, arm=3.4, w=3.0, h=2.3, icon="tankard"):
    """Inn sign on a wrought-iron bracket fixed to a wall at y=0 and projecting to -Y (arm at z=0).
    The board hangs from a crossbar at the arm tip, facing the street (-Y) so it reads from the
    front at gameplay distance. Returns (pieces, board_centre)."""
    out = list(bracket(arm, 1.4))
    yc = -arm + 0.35
    out.append(kit.oriented_box((-w / 2 - 0.2, yc, 0.0), (w / 2 + 0.2, yc, 0.0), 0.2, 0.2, "iron_dark",
                                Vector((0, -1, 0))))
    for sx in (-1, 1):
        out.append(lathe([(0.0, 0.0), (0.16, 0.1), (0.0, 0.3)], 4, "iron_dark").rotate(sx * math.pi / 2, "Y")
                   .move(sx * (w / 2 + 0.2), yc, 0.0))
    zc = -0.8 - h / 2
    for dx in (-w * 0.36, w * 0.36):  # chains
        out.append(box(0.1, 0.1, 0.8, "iron_dark").move(dx, yc, -0.8))
    out.append(kit.bbox(w, 0.3, h, kingdom_color(k, "cloth"), 0.08, base=False).move(0, yc, zc))
    out.append(box(w - 0.5, 0.42, h - 0.5, "wood_pale", base=False).move(0, yc, zc))
    for pc in tankard_icon("wood_dark", "foam", 0.56, h * 0.42):
        out.append(pc.rotate(math.pi / 2, "Z").move(0, yc, zc - 0.05))
    return out, (0.0, yc, zc)


def bunting(p0, p1, n, colors, sag=0.6, size=0.7):
    """Rope with small triangular pennants between p0 and p1 (facing -Y), sagging."""
    out = []
    p0, p1 = Vector(p0), Vector(p1)
    pts = []
    for i in range(n + 1):
        t = i / n
        p = p0.lerp(p1, t)
        p.z -= sag * 4 * t * (1 - t)
        pts.append(p)
    for a, b_ in zip(pts, pts[1:]):
        out.append(kit.oriented_box(a, b_, 0.08, 0.08, "rope", Vector((0, -1, 0))))
    for i in range(n):
        m = pts[i].lerp(pts[i + 1], 0.5)
        tri = prism([(-size / 2, 0.0), (size / 2, 0.0), (0.0, -size * 1.2)], 0.06, colors[i % len(colors)])
        out.append(tri.move(m.x, m.y - 0.05, m.z))
    return out


# ------------------------------------------------------------------ workshop props

def tool_wall_tools(rng, length=6.0):
    """Carpenter's tools hung on a wall at y=0 facing -Y, spread along X (centred), z from ~3.6 to 7.6:
    frame saw, hand saws, axe, mallet, hammer, a rope coil and a shelf of planes and pots."""
    out = []
    y = -0.12
    xs = [-length / 2 + length * (i + 0.5) / 6 for i in range(6)]
    # frame saw
    x = xs[0]
    out.append(box(2.6, 0.1, 0.36, "steel").move(x, y - 0.05, 4.2))
    for sx in (-1, 1):
        out.append(box(0.22, 0.22, 2.0, "wood").move(x + sx * 1.2, y - 0.1, 3.9))
    out.append(box(2.4, 0.18, 0.2, "wood").move(x, y - 0.1, 5.2))
    out.append(box(0.08, 0.08, 0.9, "rope").move(x, y - 0.1, 5.2))
    # hand saws
    for j, x in enumerate((xs[1] - 0.5, xs[1] + 0.6)):
        bl = prism([(-0.35, 0.0), (0.35, 0.0), (0.22, 2.0), (-0.1, 2.0)], 0.08, "steel")
        out.append(bl.rotate(math.pi, "Y").move(x, y - 0.06, 6.9 - j * 0.3))
        out.append(box(0.5, 0.2, 0.75, "wood_dark").move(x, y - 0.08, 6.9 - j * 0.3))
    # axe
    x = xs[2]
    out.append(box(0.22, 0.2, 2.6, "wood_light").move(x, y - 0.1, 4.0))
    out.append(prism([(0.0, 0.0), (0.9, -0.3), (0.9, 0.55), (0.0, 0.35)], 0.22, "iron").move(x + 0.1, y - 0.12, 6.2))
    # mallet + hammer
    x = xs[3]
    out.append(box(0.2, 0.2, 1.8, "wood").move(x - 0.4, y - 0.1, 4.4))
    out.append(kit.bbox(0.9, 0.7, 0.6, "wood_light", 0.08).move(x - 0.4, y - 0.36, 6.2))
    out.append(box(0.18, 0.18, 1.4, "wood_dark").move(x + 0.5, y - 0.1, 4.6))
    out.append(box(0.7, 0.3, 0.28, "iron_dark").move(x + 0.5, y - 0.15, 5.95))
    # rope coil
    x = xs[4]
    out.append(cylinder(0.75, 0.75, 0.35, 8, "rope").rotate(math.pi / 2, "X").move(x, y, 5.6))
    out.append(cylinder(0.35, 0.35, 0.4, 6, "wood_dark").rotate(math.pi / 2, "X").move(x, y - 0.02, 5.6))
    # shelf with planes and pots
    x = xs[5]
    out.append(box(2.2, 0.8, 0.22, "wood").move(x, y - 0.4, 5.0))
    out.append(kit.bbox(0.9, 0.5, 0.45, "wood_light", 0.06).move(x - 0.55, y - 0.4, 5.22))
    out.append(lathe([(0.0, 0.0), (0.3, 0.0), (0.36, 0.4), (0.24, 0.7), (0.0, 0.7)], 6, "clay")
               .move(x + 0.5, y - 0.4, 5.22))
    return out


def workbench(rng, length=6.0):
    """Joiner's bench against a wall at y=0 (front towards -Y), base z=0, top at ~3.1."""
    out = [kit.bbox(length, 2.0, 0.4, "wood_light", 0.08).move(0, -1.1, 2.7)]
    for sx in (-1, 1):
        for sy in (-0.35, -1.85):
            out.append(box(0.4, 0.4, 2.7, "wood_dark").move(sx * (length / 2 - 0.5), sy, 0))
    out.append(box(length - 1.2, 0.3, 0.3, "wood_dark").move(0, -1.1, 0.8))
    out.append(box(0.8, 0.6, 0.7, "iron_dark").move(-length / 2 + 0.8, -2.2, 2.6))  # vise
    out.append(kit.bbox(1.0, 0.45, 0.45, "wood", 0.05).move(0.6, -1.2, 3.1))  # plane
    out.append(box(0.18, 0.18, 0.3, "wood_dark").move(0.3, -1.2, 3.55))
    for j in range(3):  # shavings
        out.append(box(0.5, 0.35, 0.12, "wood_pale").rotate(rng.uniform(0, 3), "Z")
                   .move(rng.uniform(-length / 3, length / 3), -1.0 + rng.uniform(-0.5, 0.5), 3.1))
    return out


def log_being_sawn(rng, length=8.0, r=0.75):
    """Log across two sawhorses with a two-man crosscut saw half-way through. Along X, centred."""
    out = []
    for sx in (-1, 1):
        out += [pc.move(sx * length * 0.3, 0, 0) for pc in sawhorse(2.6, 2.8)]
    zl = 2.8
    out += [pc.move(0, 0, zl - 0.05) for pc in log(length, r, rng)]
    cut = length * 0.18
    out.append(box(0.14, r * 2.05, r * 0.95, "wood_dark").move(cut, 0, zl + r))  # kerf
    blade = prism([(-2.6, 0.0), (2.6, 0.0), (2.4, 0.55), (-2.4, 0.55)], 0.08, "steel", axis="X")
    out.append(blade.move(cut, 0, zl + r * 1.1))
    for sy in (-1, 1):
        out.append(kit.bbox(0.3, 0.3, 1.4, "wood", 0.05).move(cut, sy * 2.6, zl + r * 1.1 - 0.2))
    out.append(grounded(lathe([(1.3, 0.0), (0.9, 0.25), (0.35, 0.45), (0.0, 0.5)], 8, "wood_pale", smooth=True)
                        .jitter(rng, 0.06).move(cut, 0.3, 0.06)))
    return out


def log_pile(rng, length=7.0, rows=3, r=0.75):
    """Pyramid of bark logs along Y (cut ends facing -Y), base z=0."""
    out = []
    for row in range(rows):
        for j in range(rows - row):
            x = (-(rows - 1) / 2 + j + row * 0.5) * r * 2.05
            for pc in log(length * rng.uniform(0.92, 1.0), r * rng.uniform(0.9, 1.05)):
                out.append(pc.rotate(math.pi / 2, "Z").move(x, 0, row * r * 1.75))
    return out


def treadwheel(R=3.8, width=2.2, seg=12):
    """Treadwheel in the XZ plane (axle along Y), centred at x=0,y=0, axle at z=R+0.5, on A-frames."""
    out = []
    zc = R + 0.5
    for sy in (-1, 1):
        y = sy * width / 2
        for i in range(seg):
            a0, a1 = math.tau * i / seg, math.tau * (i + 1) / seg
            p0 = (math.cos(a0) * R, y, zc + math.sin(a0) * R)
            p1 = (math.cos(a1) * R, y, zc + math.sin(a1) * R)
            out.append(kit.oriented_box(p0, p1, 0.4, 0.36, "wood", Vector((0, sy, 0))))
        for i in range(4):  # spokes
            a = math.tau * i / 4 + math.pi / 4
            out.append(kit.oriented_box((0, y, zc), (math.cos(a) * R, y, zc + math.sin(a) * R), 0.3, 0.3, "wood_dark",
                                        Vector((0, sy, 0))))
        # A-frame
        for sx in (-1, 1):
            out.append(grounded(kit.oriented_box((sx * 2.0, sy * (width / 2 + 0.6), 0),
                                                 (0, sy * (width / 2 + 0.6), zc + 0.3), 0.45, 0.45, "timber",
                                                 Vector((0, sy, 0)))))
    for i in range(seg):  # treads
        a = math.tau * (i + 0.5) / seg
        r_ = R * math.cos(math.pi / seg) - 0.15
        out.append(box(0.3, width + 0.1, 0.22, "wood_light", base=False).move(math.cos(a) * r_, 0, zc + math.sin(a) * r_))
    out.append(cylinder(0.45, 0.45, width + 1.6, 8, "wood_dark").rotate(math.pi / 2, "X").move(0, width / 2 + 0.8, zc))
    return out


def pennant(k, length=2.6, h=1.2):
    """Small kingdom pennant on a short staff (base z=0), flying towards +X."""
    out = [cylinder(0.12, 0.1, 3.0, 5, "wood_dark")]
    tri = prism([(0.0, 0.0), (length, -h * 0.5), (0.0, -h)], 0.1, kingdom_color(k, "cloth"))
    out.append(tri.move(0.1, 0, 2.9).paint(grad=("range", 0.4, 0.95)))
    out.append(lathe([(0.0, 0.0), (0.2, 0.15), (0.0, 0.4)], 5, FINIAL[k]).move(0, 0, 3.0))
    return out
