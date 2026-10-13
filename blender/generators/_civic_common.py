"""Private helpers for the village civic family (building_market, building_smithy,
building_storehouse). Not a generator (leading underscore: build.py skips it).

Everything returns lists of Pieces in local coordinates (front faces -Y), sized at human
scale like lib/kit.py, so the props match the cottage's barrels and crates exactly.
"""

import math

from lib import kit
from lib.geo import Matrix, Vector, box, cylinder, icosphere, lathe, loft_rings, prism, tube

KINGDOM_CYCLE = ("red", "blue", "green", "yellow")


# ------------------------------------------------------------------ structure

def rect_pts(W, D, e=0.35, cx=0.0, cy=0.0):
    x0, x1, y0, y1 = cx - W / 2 - e, cx + W / 2 + e, cy - D / 2 - e, cy + D / 2 + e
    return [(x0, y0, 0), (x1, y0, 0), (x1, y1, 0), (x0, y1, 0), (x0, y0, 0)]


def plinth(W, D, h, rng, core="stone_dark", cx=0.0, cy=0.0, depth=1.0, bev=0.12, block=(2.6, 4.2)):
    """Irregular stone block course around a solid core (same recipe as house_cottage)."""
    out = kit.stone_course(rect_pts(W, D, 0.35, cx, cy), h, depth, "stone", rng, block=block, bev=bev,
                           colors=("stone", "stone_light", "stone"))
    out.append(box(W, D, h, core).move(cx, cy, 0))
    return out


def wall_stones(rng, length, height, axis, offset, n, colors, z0=0.0, margin=1.6):
    """Scattered proud stones on a plain wall face (breaks up big flat stone walls).
    axis 'x': wall along X at y=offset (normal sign(offset)); 'y': along Y at x=offset."""
    out = []
    sgn = 1 if offset >= 0 else -1
    for _ in range(n):
        u = rng.uniform(-length / 2 + margin, length / 2 - margin)
        z = z0 + rng.uniform(0.6, height - 1.2)
        w, h = rng.uniform(1.0, 1.9), rng.uniform(0.6, 0.95)
        if axis == "x":
            st = box(w, 0.3, h, rng.choice(colors)).move(u, offset + sgn * 0.08, z)
        else:
            st = box(0.3, w, h, rng.choice(colors)).move(offset + sgn * 0.08, u, z)
        out.append(st.paint(tint=rng.uniform(0, 1)))
    return out


def post(h, w=0.8, color="timber", pad=True):
    """Chunky timber post on a stone pad."""
    out = [kit.bbox(w, w, h, color, 0.1).paint(grad=("range", 0.25, 0.8))]
    if pad:
        out.append(kit.bbox(w + 0.7, w + 0.7, 0.6, "stone_light", 0.12))
    return out


def knee_brace(p_post, p_beam, normal):
    return kit.oriented_box(p_post, p_beam, kit.TIMBER * 0.8, kit.TIMBER * 0.8, "timber", Vector(normal))


def mono_tile_roof(run, length, pitch, color, rows=4, overhang=1.3, gable_overhang=1.0, thickness=0.7, rng=None):
    """One slope of the kit's stepped tile roof (lean-tos). High edge along X at y=0, z=rise;
    slope descends towards -Y and reaches z=0 at y=-run (eave continues by `overhang`).
    Returns (pieces, rise)."""
    pieces, rise = kit.gable_roof(2 * run, length, pitch, overhang=overhang, gable_overhang=gable_overhang,
                                  thickness=thickness, color=color, rows=rows, style="tile", rng=rng, trim="timber")
    trims = pieces[2 * rows + 1:]
    out = pieces[:rows] + [trims[0], trims[2]]
    for p in out:
        p.rotate(math.pi / 2, "Z")
    return out, rise


# ------------------------------------------------------------------ canvas

def sheet(fn, u0, u1, nv, t, color, v0=0.0, v1=1.0, outward=None):
    """Thick canvas strip: top surface fn(u, v) for u in [u0, u1], v in [v0, v1] (nv segments),
    pushed down along its normal by `t`. Closed solid. `outward(P)` optionally gives the
    direction the top surface should face (default: up)."""
    e = 1e-3
    rings = []
    for j in range(nv + 1):
        v = v0 + (v1 - v0) * j / nv
        tops, bots = [], []
        for u in (u0, u1):
            P = Vector(fn(u, v))
            du = Vector(fn(u + e, v)) - Vector(fn(u - e, v))
            dv = Vector(fn(u, v + e)) - Vector(fn(u, v - e))
            n = du.cross(dv).normalized()
            ref = Vector(outward(P)) if outward else Vector((0, 0, 1))
            if n.dot(ref) < 0:
                n = -n
            tops.append(P)
            bots.append(P - n * t)
        rings.append([tops[0], tops[1], bots[1], bots[0]])
    return loft_rings(rings, color)


def tab(w, h, t=0.16, color="canvas"):
    """Scalloped valance flap hanging below z=0 in the XZ plane (depth along Y)."""
    poly = [(-w / 2, 0.0), (-w / 2, -0.55 * h), (-w * 0.22, -h), (w * 0.22, -h), (w / 2, -0.55 * h), (w / 2, 0.0)]
    return prism(poly, t, color)


def pennant(length=2.2, h=1.1, color="red_cloth", pole=3.0):
    """Pole with a swallowtail pennant flying towards +X. Base at z=0."""
    out = [cylinder(0.14, 0.11, pole, 5, "wood_dark")]
    out.append(lathe([(0.0, pole - 0.05), (0.26, pole + 0.08), (0.0, pole + 0.4)], 6, "gold"))
    poly = [(0.0, 0.0), (length, -0.05), (length * 0.72, h * 0.5), (length, h + 0.05), (0.0, h)]
    f = prism(poly, 0.14, color)
    f.bend(lambda v: (v.x, v.y + 0.18 * math.sin(v.x * 2.2), v.z))
    out.append(f.move(0.1, 0, pole - h - 0.25))
    return out


# ------------------------------------------------------------------ emblems / signs

def emblem_poly(kind, s=1.0):
    """2D outline (x, z) centred on 0, roughly 1.4 x 1.4 at s=1."""
    if kind == "star":
        pts = []
        for i in range(10):
            a = math.pi / 2 + math.pi * i / 5
            r = 0.72 if i % 2 == 0 else 0.3
            pts.append((math.cos(a) * r, math.sin(a) * r))
    elif kind == "sun":
        pts = []
        for i in range(16):
            a = math.pi * 2 * i / 16
            r = 0.72 if i % 2 == 0 else 0.5
            pts.append((math.cos(a) * r, math.sin(a) * r))
    elif kind == "crown":
        pts = [(-0.6, -0.45), (0.6, -0.45), (0.65, 0.45), (0.32, 0.08), (0.0, 0.55), (-0.32, 0.08), (-0.65, 0.45)]
    elif kind == "leaf":
        pts = [(0.0, -0.75), (0.18, -0.4), (0.45, -0.3), (0.32, -0.05), (0.55, 0.12), (0.3, 0.3), (0.38, 0.55),
               (0.0, 0.75), (-0.38, 0.55), (-0.3, 0.3), (-0.55, 0.12), (-0.32, -0.05), (-0.45, -0.3), (-0.18, -0.4)]
    elif kind == "anvil":
        pts = [(-0.55, -0.5), (0.55, -0.5), (0.38, -0.32), (0.2, -0.28), (0.2, 0.02), (0.48, 0.18), (0.95, 0.36),
               (0.5, 0.45), (-0.7, 0.45), (-0.7, 0.18), (-0.2, 0.02), (-0.2, -0.28), (-0.38, -0.32)]
    elif kind == "sheaf":
        pts = [(-0.28, -0.7), (0.28, -0.7), (0.12, -0.08), (0.6, 0.5), (0.3, 0.5), (0.18, 0.7), (0.0, 0.52),
               (-0.18, 0.7), (-0.3, 0.5), (-0.6, 0.5), (-0.12, -0.08)]
    elif kind == "apple":
        pts = []
        for i in range(10):
            a = math.pi * 2 * i / 10 - math.pi / 2
            r = 0.6 * (1.0 - 0.18 * max(0.0, math.cos(a - math.pi / 2)) ** 6)
            pts.append((math.cos(a) * r, math.sin(a) * r * 0.95 - 0.05))
    elif kind == "fish":
        pts = [(-0.78, 0.0), (-0.45, -0.3), (0.0, -0.38), (0.4, -0.2), (0.55, -0.05), (0.82, -0.4), (0.72, 0.0),
               (0.82, 0.4), (0.55, 0.05), (0.4, 0.2), (0.0, 0.38), (-0.45, 0.3)]
    elif kind == "jug":
        pts = [(-0.35, -0.68), (0.35, -0.68), (0.52, -0.2), (0.42, 0.2), (0.2, 0.4), (0.26, 0.64), (-0.26, 0.64),
               (-0.2, 0.4), (-0.42, 0.2), (-0.52, -0.2)]
    else:  # "disc"
        pts = [(math.cos(math.pi * 2 * i / 10) * 0.6, math.sin(math.pi * 2 * i / 10) * 0.6) for i in range(10)]
    return [(x * s, z * s) for x, z in pts]


KINGDOM_EMBLEM = {"red": "crown", "blue": "star", "green": "leaf", "yellow": "sun"}


def emblem(kind, s, depth, color):
    return prism(emblem_poly(kind, s), depth, color)


def hanging_sign(icon, icon_color, side=1, arm=3.2, w=2.6, h=1.9, board="wood_light", rim="timber"):
    """Signboard hanging from a bracket arm that sticks out along +X (side=1) or -X from a
    post face at the origin; arm at z=0. The icon is painted on both faces."""
    out = []
    out.append(box(arm, 0.32, 0.36, "timber").move(side * arm / 2, 0, -0.18))
    out.append(kit.oriented_box((0, 0, -1.7), (side * arm * 0.62, 0, -0.1), 0.26, 0.26, "timber",
                                Vector((0, 1, 0))))
    out.append(lathe([(0.0, -0.05), (0.2, 0.05), (0.0, 0.32)], 5, "iron").move(side * (arm - 0.15), 0, 0.0))
    c = side * arm * 0.62
    for dx in (-w * 0.36, w * 0.36):
        out.append(box(0.1, 0.1, 0.62, "iron_dark").move(c + dx, 0, -0.66))
    out.append(kit.bbox(w + 0.3, 0.34, h + 0.3, rim, 0.08).move(c, 0, -0.66 - h - 0.3))
    out.append(kit.bbox(w, 0.42, h, board, 0.06).move(c, 0, -0.66 - h - 0.15))
    out.append(emblem(icon, min(w, h) * 0.62, 0.52, icon_color).move(c, 0, -0.66 - h / 2 - 0.15))
    return out


def banner(kingdom, w=2.2, h=4.2, rod=None):
    """Hanging kingdom banner (cloth with swallowtail, trim band, emblem). Top at z=0,
    hangs down, plane XZ, faces -Y. Solid (0.2 thick)."""
    from lib.palette import kingdom_color as kc

    out = []
    poly = [(-w / 2, 0.0), (-w / 2, -h), (0.0, -h + 0.75), (w / 2, -h), (w / 2, 0.0)]
    out.append(prism(poly, 0.2, kc(kingdom, "cloth")).paint(grad=("range", 0.35, 0.85)))
    out.append(box(w + 0.1, 0.26, 0.32, kc(kingdom, "trim")).move(0, 0, -0.55))
    out.append(emblem(KINGDOM_EMBLEM[kingdom], w * 0.62, 0.3, kc(kingdom, "emblem")).move(0, 0, -h * 0.45))
    out.append(cylinder(0.13, 0.13, w + 0.8, 6, rod or "wood_dark").rotate(math.pi / 2, "Y").move(-(w + 0.8) / 2, 0, 0.05))
    return out


# ------------------------------------------------------------------ props

def barrel(s=1.0, color="wood", top=None):
    """The cottage barrel (lathe + two iron hoops), optional top disc (water, apples...)."""
    out = [lathe([(0.0, 0.0), (1.0 * s, 0.0), (1.18 * s, 1.0 * s), (1.18 * s, 1.5 * s), (1.0 * s, 2.5 * s),
                  (0.0, 2.5 * s)], 8, color)]
    for zz in (0.5, 1.85):
        out.append(cylinder(1.17 * s, 1.17 * s, 0.18 * s, 8, "iron_dark").move(0, 0, zz * s))
    if top:
        out.append(cylinder(0.93 * s, 0.93 * s, 0.08, 8, top).move(0, 0, 2.5 * s - 0.03))
    return out


def crate(sx, sy, sz, color="wood_light", band="wood"):
    out = [kit.bbox(sx, sy, sz, color, 0.1)]
    for z in (sz * 0.14, sz * 0.86 - 0.24):
        out.append(box(sx + 0.08, sy + 0.08, 0.24, band).move(0, 0, z))
    return out


def mound(sx, sy, h, color, rng=None, seg=6):
    m = lathe([(1.0, 0.0), (0.98, 0.3), (0.72, 0.78), (0.0, 1.0)], seg, color)
    m.scale(sx / 2 / math.cos(math.pi / seg), sy / 2 / math.cos(math.pi / seg), h)
    if rng:
        m.jitter(rng, min(sx, sy) * 0.03, axes=(1, 1, 0.6))
    return m.paint(smooth=True, grad=("range", 0.15, 0.9))


def fruit(kind, rng, s=1.0):
    """Single produce item centred at its base (z=0)."""
    if kind == "apple":
        r = 0.42 * s * rng.uniform(0.92, 1.08)
        p = icosphere(r, 1, rng.choice(("apple_red", "apple_red", "autumn_red"))).scale(1, 1, 0.9).move(0, 0, r * 0.9)
        return [p.paint(smooth=True, grad=("range", 0.35, 1.0))]
    if kind == "pear":
        r = 0.4 * s
        p = lathe([(0.0, 0.0), (r, r * 0.45), (r * 0.62, r * 1.5), (0.0, r * 2.1)], 6, "leaf_yellow")
        return [p.paint(smooth=True, grad=("range", 0.3, 1.0))]
    if kind == "cabbage":
        r = 0.72 * s * rng.uniform(0.9, 1.1)
        out = [icosphere(r, 1, "cabbage").scale(1, 1, 0.85).move(0, 0, r * 0.82).paint(smooth=True,
                                                                                   grad=("range", 0.3, 1.0))]
        out.append(lathe([(0.0, 0.0), (r * 0.9, 0.05), (r * 1.25, r * 0.6), (0.0, r * 0.3)], 6,
                         "crop_green").paint(smooth=True, grad=("range", 0.2, 0.8)))
        return out
    if kind == "pumpkin":
        r = 0.95 * s * rng.uniform(0.85, 1.15)
        seg = 8
        p = lathe([(0.0, 0.05), (r * 0.72, 0.0), (r, r * 0.5), (r * 0.62, r * 1.08), (0.0, r * 1.02)], seg,
                  rng.choice(("pumpkin", "pumpkin", "autumn_orange")))

        def rib(v):
            if math.hypot(v.x, v.y) < 1e-4:
                return v
            a = math.atan2(v.y, v.x) - math.pi / seg
            k = int(round(a / (2 * math.pi / seg)))
            f = 1.0 + (0.09 if k % 2 == 0 else -0.05)
            return Vector((v.x * f, v.y * f, v.z))

        p.bend(rib)
        out = [p.paint(smooth=True, grad=("range", 0.3, 1.0))]
        out.append(cylinder(0.12 * s, 0.08 * s, 0.45 * s, 5, "bark").rotate(0.25, "X").move(0, 0, r * 1.02))
        return out
    if kind == "loaf":
        L = 1.3 * s * rng.uniform(0.9, 1.1)
        r = 0.42 * s
        p = lathe([(0.0, 0.0), (r * 0.7, 0.05), (r, L * 0.3), (r, L * 0.7), (r * 0.7, L * 0.95), (0.0, L)], 6,
                  rng.choice(("wood_light", "wood_pale", "wood_light")))
        p.rotate(math.pi / 2, "Y").scale(1, 1, 0.75).move(-L / 2, 0, r * 0.75)
        out = [p.paint(smooth=True, grad=("range", 0.3, 1.0))]
        for j in range(3):  # scored crust
            out.append(box(0.12, r * 0.9, 0.08, "wood_pale").rotate(0.5, "Z").move(-L * 0.25 + j * L * 0.25, 0,
                                                                                   r * 1.38))
        return out
    if kind == "round_loaf":
        r = 0.7 * s * rng.uniform(0.9, 1.1)
        p = lathe([(0.0, 0.0), (r, 0.0), (r * 1.02, r * 0.3), (r * 0.75, r * 0.75), (0.0, r * 0.88)], 7,
                  rng.choice(("wood_light", "wood_pale")))
        return [p.paint(smooth=True, grad=("range", 0.3, 1.0))]
    if kind == "fish":
        L = 1.9 * s * rng.uniform(0.85, 1.1)
        r = 0.36 * s
        body = lathe([(0.0, 0.0), (r * 0.55, L * 0.12), (r, L * 0.42), (r * 0.7, L * 0.72), (r * 0.25, L * 0.88)], 6,
                     rng.choice(("stone_cool_light", "steel", "stone_cool_light")), cap_top=True)
        body.rotate(math.pi / 2, "Y").scale(1, 1.0, 0.55).move(-L / 2, 0, r * 0.55)
        tail = prism([(0.0, 0.0), (0.55 * s, 0.45 * s), (0.55 * s, -0.45 * s)], 0.12, "stone_cool")
        tail.rotate(math.pi / 2, "X").move(L * 0.38, 0, r * 0.55)
        return [body.paint(smooth=True, grad=("range", 0.4, 1.0)), tail]
    if kind == "bolt":
        L = 2.0 * s
        r = 0.42 * s
        c = cylinder(r, r, L, 8, rng.choice(("tunic_red", "tunic_blue", "tunic_green", "tunic_cream", "flower_purple",
                                            "autumn_yellow")))
        return [c.rotate(math.pi / 2, "Y").move(-L / 2, 0, r)]
    if kind == "jug":
        r = 0.55 * s * rng.uniform(0.9, 1.1)
        p = lathe([(0.0, 0.0), (r * 0.7, 0.0), (r, r * 0.8), (r * 0.42, r * 1.75), (r * 0.52, r * 2.2),
                   (0.0, r * 2.1)], 6, rng.choice(("clay", "clay", "dirt_light")))
        return [p.paint(smooth=True, grad=("range", 0.3, 1.0))]
    if kind == "cheese":
        r = 0.75 * s
        p = cylinder(r, r * 0.95, r * 0.7, 8, "autumn_yellow")
        return [p.paint(grad=("range", 0.4, 1.0))]
    raise ValueError(kind)


PILE_COLOR = {"apple": "apple_red", "pear": "leaf_yellow", "cabbage": "cabbage", "pumpkin": "pumpkin",
              "loaf": "wood_light", "round_loaf": "wood_light", "fish": "stone_cool_light", "bolt": "tunic_cream",
              "jug": "clay", "cheese": "autumn_yellow", "grain": "wheat", "carrot": "autumn_orange"}


def produce_pile(rng, kind, sx, sy, n=4, mound_h=None, s=1.0):
    """A heaped mound of produce with a few loose items on top (base z=0)."""
    h = mound_h if mound_h is not None else min(sx, sy) * 0.32
    out = [mound(sx, sy, h, PILE_COLOR.get(kind, "apple_red"), rng)]
    for i in range(n):
        u = (i + 0.5) / n - 0.5
        x = u * sx * 0.62 + rng.uniform(-0.12, 0.12)
        y = rng.uniform(-sy * 0.18, sy * 0.18)
        z = h * (1.0 - (2 * abs(u)) ** 2 * 0.55) - 0.25 * s
        for pc in fruit(kind, rng, s):
            out.append(pc.rotate(rng.uniform(0, math.pi), "Z").move(x, y, z))
    return out


def produce_crate(rng, kind, sx=2.4, sy=1.7, sz=1.0, color="wood_light", n=3, s=1.0):
    out = crate(sx, sy, sz, color)
    out += [p.move(0, 0, sz - 0.12) for p in produce_pile(rng, kind, sx - 0.25, sy - 0.25, n, s=s)]
    return out


def basket(rng, r=1.0, h=1.0, kind=None, color="straw", n=3):
    out = [lathe([(0.0, 0.0), (r * 0.72, 0.0), (r, h), (0.0, h)], 8, color).paint(grad=("range", 0.35, 0.95))]
    out.append(cylinder(r * 1.04, r * 1.06, 0.2, 8, "hay_dark").move(0, 0, h - 0.18))
    out.append(cylinder(r * 0.88, r * 0.9, 0.14, 8, "hay_dark").move(0, 0, h * 0.45))
    if kind:
        pile = produce_pile(rng, kind, r * 1.7, r * 1.7, n, mound_h=r * 0.4, s=0.85)
        out += [p.move(0, 0, h - 0.1) for p in pile]
    return out


def sack(rng, s=1.0, color=None, lying=False):
    color = color or rng.choice(("canvas_dark", "canvas_dark", "apron", "cloth_brown", "canvas"))
    prof = [(0.0, 0.0), (0.8, 0.03), (0.98, 0.6), (0.8, 1.35), (0.34, 1.72), (0.0, 1.95)]
    p = lathe([(r * s, z * s) for r, z in prof], 7, color)
    p.scale(1.0, 0.82, 1.0)
    p.jitter(rng, 0.05 * s)
    out = [p.paint(smooth=True, grad=("range", 0.3, 0.95))]
    out.append(cylinder(0.36 * s, 0.32 * s, 0.16 * s, 6, "rope").move(0, 0, 1.58 * s))
    out.append(lathe([(0.0, 1.6 * s), (0.3 * s, 1.85 * s), (0.18 * s, 2.15 * s), (0.0, 2.2 * s)], 5, color))
    if lying:
        for pc in out:
            pc.rotate(math.pi / 2 - 0.12, "Y").move(-0.9 * s, 0, 0.78 * s)
    return out


def sack_pile(rng, n, spread=3.2, s=1.0, color=None):
    """A heap of sacks: standing ones at the back, a couple lying in front."""
    out = []
    for i in range(n):
        lying = i % 3 == 2
        x = (i - (n - 1) / 2) * spread / max(1, n - 1) + rng.uniform(-0.15, 0.15)
        y = rng.uniform(-0.2, 0.2) - (1.4 * s if lying else 0)
        for pc in sack(rng, s * rng.uniform(0.9, 1.08), color, lying=lying):
            out.append(pc.rotate(rng.uniform(-0.5, 0.5), "Z").move(x, y, 0))
    return out


def crate_stack(rng, n=3, s=2.0, color="wood_light"):
    out = []
    base = min(n, 2)
    for i in range(base):
        out += [p.rotate(rng.uniform(-0.08, 0.08), "Z").move((i - (base - 1) / 2) * (s + 0.12), 0, 0)
                for p in crate(s, s, s, color)]
    if n > 2:
        out += [p.rotate(rng.uniform(-0.25, 0.25), "Z").move(rng.uniform(-0.3, 0.3), 0.1, s)
                for p in crate(s * 0.9, s * 0.9, s * 0.9, "wood")]
    return out


def log_pile(rng, length=3.0, rows=3, r=0.55):
    out = []
    for row in range(rows):
        for j in range(rows - row):
            x = -((rows - row - 1) * 1.15 * r * 2) / 2 + j * 2.3 * r
            z = r + row * 1.75 * r
            lg = cylinder(r, r, length, 7, "bark").rotate(math.pi / 2, "X").move(x, length / 2, z)
            out.append(lg)
            out.append(cylinder(r * 0.75, r * 0.75, 0.1, 7, "wood_pale").rotate(math.pi / 2, "X").move(x, -length / 2 + 0.02, z))
    return out


def ladder(p0, p1, width=1.8, rungs=None, color="wood"):
    """Ladder leaning from p0 (foot, centre) to p1 (top, centre); rails offset along X."""
    p0, p1 = Vector(p0), Vector(p1)
    L = (p1 - p0).length
    side = Vector((1, 0, 0))
    n = (p1 - p0).cross(side).normalized()
    out = []
    for s in (-1, 1):
        a = p0 + side * (s * width / 2)
        b = p1 + side * (s * width / 2)
        out.append(kit.oriented_box(a, b, 0.32, 0.32, color, n))
    k = rungs or max(3, int(L / 1.1))
    for i in range(1, k + 1):
        c = p0 + (p1 - p0) * (i / (k + 1))
        out.append(box(width, 0.24, 0.24, "wood_dark", base=False).move(c.x, c.y, c.z))
    return out


def rope_hoist(top, drop, load="crate", rng=None):
    """Pulley at `top` with a rope dropping `drop` studs to a hanging load."""
    tx, ty, tz = top
    out = [cylinder(0.5, 0.5, 0.36, 8, "wood_dark").rotate(math.pi / 2, "Y").move(tx - 0.18, ty, tz - 0.55)]
    out.append(box(0.16, 0.16, drop, "rope").move(tx, ty - 0.5, tz - drop - 0.3))
    if load == "crate":
        for p in crate(1.9, 1.9, 1.7, "wood_light"):
            out.append(p.rotate(0.2, "Z").move(tx, ty - 0.5, tz - drop - 2.0))
        out.append(box(2.2, 0.12, 0.12, "rope").move(tx, ty - 0.5, tz - drop - 0.35))
    else:
        for p in sack(rng, 0.95, "canvas_dark"):
            out.append(p.move(tx, ty - 0.5, tz - drop - 0.3 - 2.2 * 0.95))
    return out


def tube_arc(points, r=0.3, color="timber"):
    return tube(points, [r] * len(points), 5, color)


__all__ = ["KINGDOM_CYCLE", "KINGDOM_EMBLEM", "rect_pts", "plinth", "wall_stones", "post", "knee_brace", "mono_tile_roof", "sheet",
           "tab", "pennant", "emblem_poly", "emblem", "hanging_sign", "banner", "barrel", "crate", "mound", "fruit",
           "produce_pile", "produce_crate", "basket", "sack", "sack_pile", "crate_stack", "log_pile", "ladder",
           "rope_hoist", "tube_arc", "Matrix"]
