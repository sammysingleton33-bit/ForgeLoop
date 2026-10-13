"""Castle tower: sits on a wall joint (footprint ~18 x 18, centred on the origin), taller than the
curtain wall, crowned in its kingdom's roof language (ART_DIRECTION section 3):
  red    round towers, tall conical spires with gold finials (big roofed spire / drum + stair turret)
  blue   square towers, crisp pyramid slate roofs with silver finials (big pyramid / corner bartizans)
  green  timber hoardings (wooden fighting galleries) under low green cones
  yellow sandstone, stepped Moorish merlons, onion dome / domed corner kiosks, gold sun finials

Front (field side) faces -Y like castle_wall. Ground door faces +Y (courtyard); arched wall-walk
doors at x = +-R, z = 24 open onto castle_wall walks; the top walk is at `walk` (31-35; roofed
spires/pyramids cover it like a fighting gallery). Every crown is big: the roof is the identity.
"""

import math

from lib import kit
from lib.geo import box, cylinder, lathe
from generators import _castle_common as cc
from generators._castle_common import kc

NAME = "castle_tower"
VERSION = 1
CATEGORY = "castle"
BUDGET = "castle_tower"
COLLISION = {"fidelity": "PreciseConvexDecomposition"}
CHECKS = {"min_pieces": 150, "min_openings": 6, "min_merlons": 8, "min_roof": 1}
DEFAULT_VARIANTS = 8
LINEUP_GAP = 6.0

# (kingdom, form, crown, walk level)
PLAN = [
    ("red", "round", "spire_big", 33.0),
    ("red", "round", "spire_turret", 35.0),
    ("blue", "square", "pyramid_big", 33.0),
    ("blue", "square", "bartizans", 34.0),
    ("green", "round", "hoarding", 32.0),
    ("green", "octagon", "hoarding_lookout", 35.0),
    ("yellow", "round", "onion", 33.0),
    ("yellow", "square", "kiosks", 29.0),
]

R_ROUND = 7.0
HW_SQUARE = 6.8


def variants(n, seed):
    out = []
    for i in range(n):
        k, form, crown, walk = PLAN[i % len(PLAN)]
        out.append({"kingdom": k, "form": form, "crown": crown, "walk": walk, "seed": seed * 1000 + 300 + i})
    return out


def asset_id(i, params):
    same = [j for j in range(i) if PLAN[j % len(PLAN)][0] == params["kingdom"]]
    return f"castle_tower_{params['kingdom']}_{len(same) + 1:02d}"


def rotate_xy(x, y, th):
    c, s = math.cos(th), math.sin(th)
    return x * c - y * s, x * s + y * c


# ------------------------------------------------------------------ bodies

def moss(b, rng, pts, scale=1.0, limit=None, square=False):
    """Soft moss clumps on the battered base; pulled inwards so they never pass `limit` (keeps the
    bounds symmetric)."""
    for x, y, z in pts:
        r = rng.uniform(0.7, 1.3) * scale
        m = lathe([(0.0, 0.0), (r, 0.0), (r * 0.85, 0.35 * r), (r * 0.4, 0.62 * r), (0.0, 0.7 * r)], 6, "moss")
        m.scale(rng.uniform(1.2, 2.0), rng.uniform(0.8, 1.2), rng.uniform(0.5, 0.8))
        m.rotate(rng.uniform(0, math.pi), "Z").move(x, y, z)
        if limit:
            if square:
                over = max(max(abs(v.x), abs(v.y)) for v in m.verts) - limit
                d = (1 if x > 0 else -1, 0) if abs(x) > abs(y) else (0, 1 if y > 0 else -1)
            else:
                over = max(math.hypot(v.x, v.y) for v in m.verts) - limit
                L = math.hypot(x, y)
                d = (x / L, y / L)
            if over > 0:
                m.move(-d[0] * over, -d[1] * over, 0)
        b.add(m.paint(grad=("range", 0.15, 0.9), smooth=True))


def footing(b, k, r, seg):
    """Low foundation apron of dark stone: grounds the tower and keeps its bounds symmetric
    (the pivot stays on the tower axis = the wall joint)."""
    sd = kc(k, "stone_dark")
    if seg == 4:
        b.add(cc.square_lathe([(r, 0.0), (r, 0.3), (r - 0.5, 0.55)], sd).paint(grad=("range", 0.1, 0.4)))
    elif seg == 8:
        b.add(cc.poly_lathe([(r, 0.0), (r, 0.3), (r - 0.5, 0.55)], 8, sd).paint(grad=("range", 0.1, 0.4)))
    else:
        b.add(lathe([(r, 0.0), (r, 0.3), (r - 0.5, 0.55)], seg, sd).paint(grad=("range", 0.1, 0.4)))


def ring_openings(b, k, R, rng, slits, windows):
    """Arrow slits, stone windows, wall-walk doors (+-X at z=24) and the ground door (+Y) on a round
    shaft. Returns ashlar ring holes (theta, half-width rad, za, zb)."""
    holes = []

    def put(pcs, th, z, half_w, h, r_off):
        b.add(cc.on_ring(pcs, th, R + r_off, z))
        holes.append((th, half_w / R, z - 0.5, z + h + 0.5))
        b.stats["openings"] = b.stats.get("openings", 0) + 1

    for th, z in slits:
        put(cc.arrow_slit(k, 3.2), th, z, 1.1, 3.2, 0.1)
    for th, z, w, h in windows:
        put(cc.stone_window(k, w, h, arched=True, mullion=w > 2.4), th, z, w / 2 + 0.7, h, 0.12)
    for th in (math.pi / 2, -math.pi / 2):
        put(cc.opening(4.0, 6.8, kc(k, "stone_light"), k), th, cc.WALK_Z, 3.0, 7.0, 0.12)
    put(cc.castle_door(k), math.pi, 0.0, 3.4, kit.DOOR_H + 0.4, 0.15)
    return holes


def round_body(b, k, rng, R, walk, holes, seg=16):
    sd = kc(k, "stone_dark")
    zc = walk - 2.3
    if seg == 8:
        b.add(cc.poly_lathe([(R + 1.6, 0.0), (R + 1.6, 0.35), (R, 5.6), (R, walk)], 8, sd)
              .paint(grad=("range", 0.2, 0.6)))
    else:
        b.add(lathe([(R + 1.6, 0.0), (R + 1.6, 0.35), (R, 5.6), (R, walk)], seg, sd).paint(grad=("range", 0.2, 0.6)))
    sl = 5.6 if seg == 8 else 5.4
    b.add(cc.ashlar_ring(k, rng, R + 1.5, 0.35, 5.5, r1=R + 0.1, seg_len=sl, course=2.6, shade_hi=0.25,
                         weights=(0.45, 0.25, 0.3), n_min=8))
    b.add(cc.annulus(R - 0.4, R + 0.5, 5.5, 6.1, seg, kc(k, "stone_light"), phase=math.pi / 8 if seg == 8 else None))
    b.add(cc.ashlar_ring(k, rng, R, 6.1, zc, seg_len=5.6 if seg == 8 else 5.0, course=3.0, holes=holes,
                         shade_lo=0.25, n_min=8))
    if seg == 8:
        for i in range(8):  # quoin columns on the octagon corners
            th = math.pi / 8 + i * math.pi / 4
            b.add(cc.on_ring(cc.quoins(k, rng, 0.0, 0.0, 6.1, zc, 0, 0, size=(1.3, 1.3), course=3.0), th,
                             R / math.cos(math.pi / 8) - 0.25))
    moss(b, rng, [(math.sin(a) * (R + 1.3), -math.cos(a) * (R + 1.3), 0.15)
                  for a in (rng.uniform(-1.2, -0.3), rng.uniform(0.2, 1.4), rng.uniform(2.0, 3.0))], 0.9,
         limit=R + 2.2)
    footing(b, k, R + 2.5, seg)
    return zc


def square_body(b, k, rng, hw, walk, face_specs):
    """Battered square body. face_specs: (face, u, z, kind); face 0 = front (-Y), 1 = +X, 2 = back, 3 = -X."""
    sd = kc(k, "stone_dark")
    zc = walk - 2.3
    holes = {0: [], 1: [], 2: [], 3: []}
    for f, u, z, kind in face_specs:
        if kind == "slit":
            pcs, hw_, hh = cc.arrow_slit(k, 3.2), 1.1, 3.2
        elif kind == "win":
            pcs, hw_, hh = cc.stone_window(k, 2.2, 3.8), 1.8, 3.8
        elif kind == "win2":
            pcs, hw_, hh = cc.stone_window(k, 2.8, 4.4, mullion=True), 2.1, 4.4
        elif kind == "walkdoor":
            pcs, hw_, hh = cc.opening(4.0, 6.8, kc(k, "stone_light"), k), 3.0, 7.0
        else:
            pcs, hw_, hh = cc.castle_door(k), 3.4, kit.DOOR_H + 0.4
        b.add(cc.place([q.move(u, -hw - 0.12, 0) for q in pcs], f * math.pi / 2, 0, 0, z))
        holes[f].append((u - hw_, u + hw_, z - 0.5, z + hh + 0.5))
        b.stats["openings"] = b.stats.get("openings", 0) + 1
    b.add(cc.square_lathe([(hw + 1.6, 0.0), (hw + 1.6, 0.35), (hw, 5.6), (hw, walk)], sd)
          .paint(grad=("range", 0.2, 0.6)))
    batter = 1.6 / 5.25
    tilt = math.atan(batter)
    for f in range(4):
        theta = f * math.pi / 2
        pcs = []
        for ci, (za, zb) in enumerate(((0.35, 2.95), (2.95, 5.55))):
            zm = (za + zb) / 2
            inset = (zm - 0.35) * batter
            half = hw + 1.6 - inset
            row = cc.ashlar_plane(k, rng, -half + 0.3, half - 0.3, za, zb, course=2.6, blen=(3.8, 6.4),
                                  shade_t=0.1 * ci, weights=(0.45, 0.25, 0.3))
            for q in row:
                q.move(0, 0, -zm).rotate(-tilt, "X").move(0, -half, zm)
            pcs += row
        shaft = cc.ashlar_plane(k, rng, -hw + 0.9, hw - 0.9, 6.1, zc, course=3.0, blen=(4.0, 6.6),
                                holes=holes[f])
        pcs += [q.move(0, -hw, 0) for q in shaft]
        b.add([q.rotate(theta, "Z") for q in pcs])
        b.add(cc.string_course_x(-hw - 0.5, hw + 0.5, -hw, 5.5, kc(k, "stone_light"), proj=0.5, h=0.6)
              .rotate(theta, "Z"))
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.add(cc.quoins(k, rng, sx * hw, sy * hw, 6.1, zc, sx, sy, size=(2.4, 1.3), course=3.0))
    moss(b, rng, [(rng.uniform(-5, 5), -hw - 1.2, 0.15), (hw + 1.2, rng.uniform(-5, 5), 0.15),
                  (rng.uniform(-5, 5), hw + 1.2, 0.15)], 0.9, limit=hw + 2.0, square=True)
    footing(b, k, hw + 2.2, 4)
    return zc


# ------------------------------------------------------------------ crowns

def round_crown(b, k, rng, R, walk, style="square", seg=16, merlon_h=cc.MERLON_H, slits=True, n_corbel=14,
                skip=()):
    """Corbel table, machicolation slots, projecting parapet ring, walk floor and merlons.
    Returns (parapet radius, merlon top z)."""
    Rp = R + 1.25
    sl = kc(k, "stone_light")
    for i in range(n_corbel):
        th = 2 * math.pi * (i + 0.5) / n_corbel
        b.add(cc.on_ring(cc.corbel(sl, proj=1.3, w=1.05, h=2.2), th, R, walk - 0.55))
        if i % 2 == 0:
            b.add(cc.on_ring([box(0.9, 0.3, 0.75, "black")], th + math.pi / n_corbel, Rp - 0.08, walk - 0.6))
    b.add(cc.annulus(R + 0.05, Rp, walk - 0.6, walk + 3.0, seg, kc(k, "stone_dark")))
    b.add(cc.ashlar_ring(k, rng, Rp, walk - 0.5, walk + 2.95, seg_len=4.6, course=3.45, proud=0.15,
                         shade_lo=0.8, shade_hi=0.8))
    b.add(lathe([(0.0, walk - 0.3), (R + 0.3, walk - 0.3), (R + 0.3, walk + 0.05), (0.0, walk + 0.05)], seg,
                "cobble").paint(grad=0.55))
    rm = Rp - 0.62
    n = max(8, int(2 * math.pi * rm // 4.4))
    for i in range(n):
        th = 2 * math.pi * i / n
        if any(abs(cc.wrap(th - a)) < 0.42 for a in skip):
            continue  # room for a corbelled turret
        b.add(cc.on_ring(cc.merlon(style, k, h=merlon_h, t=1.25, cap=style == "square" and slits), th, rm,
                         walk + 3.0))
        if slits and i % 3 == 1 and style in ("square", "swallow"):
            b.add(cc.on_ring([box(0.36, 0.3, 1.5, "window_dark").move(0, -0.62, 0.5)], th, rm, walk + 3.0))
    b.stats["merlons"] = n
    return Rp, walk + 3.0 + merlon_h


def square_crown(b, k, rng, hw, walk, style="square", corners=True, merlon_h=cc.MERLON_H, cap=True):
    """Corbel table + projecting square parapet + merlons. Returns (parapet half-width, merlon top z)."""
    hp = hw + 1.2
    sl, sd = kc(k, "stone_light"), kc(k, "stone_dark")
    n_c = 4
    for f in range(4):
        th = f * math.pi / 2
        for i in range(n_c):
            u = -hw + 1.0 + (2 * hw - 2.0) * i / (n_c - 1)
            b.add(cc.place(cc.corbel(sl, proj=1.2, w=1.05, h=2.2), th, *rotate_xy(u, -hw, th), walk - 0.55))
            if i == 1:
                u2 = u + (2 * hw - 2.0) / (n_c - 1) / 2
                b.add(cc.place([box(0.9, 0.3, 0.75, "black")], th, *rotate_xy(u2, -hp + 0.08, th), walk - 0.6))
        wall = cc.ybox(-hp, hp, -hp, -hp + 1.2, walk - 0.6, walk + 3.0, sd)
        b.add(wall.rotate(th, "Z"))
        blocks = cc.ashlar_plane(k, rng, -hp + 0.2, hp - 0.2, walk - 0.5, walk + 2.95, course=3.45, proud=0.15,
                                 shade_t=0.8, blen=(4.4, 6.4))
        b.add([q.move(0, -hp, 0).rotate(th, "Z") for q in blocks])
    b.add(cc.ybox(-hw - 0.2, hw + 0.2, -hw - 0.2, hw + 0.2, walk - 0.3, walk + 0.05, "cobble").paint(grad=0.55))
    Lp = 2 * hp - 1.25
    n = max(3, int(Lp // 4.4) + 1)
    count = 0
    for f in range(4):
        th = f * math.pi / 2
        for i in range(n):
            if not corners and i == 0:
                continue
            u = -Lp / 2 + i * Lp / n
            b.add(cc.place(cc.merlon(style, k, h=merlon_h, t=1.25, cap=cap), th, *rotate_xy(u, -hp + 0.62, th),
                           walk + 3.0))
            count += 1
    b.stats["merlons"] = count
    return hp, walk + 3.0 + merlon_h


def drum(b, k, rng, Rd, z0, h, seg=12, windows=2, door_back=True, shutters=True):
    """Upper drum standing on the walk; returns top z (cornice included)."""
    b.add(cylinder(Rd, Rd, h, seg, kc(k, "stone_dark")).move(0, 0, z0))
    holes = []
    wins = []
    for j in range(windows):
        th = (j - (windows - 1) / 2) * 0.95
        wins.append(th)
        holes.append((th, 1.9 / Rd, z0 + 1.6, z0 + 1.6 + 3.9))
    if door_back:
        holes.append((math.pi, 2.7 / Rd, z0, z0 + 6.4))
    b.add(cc.ashlar_ring(k, rng, Rd, z0, z0 + h, seg_len=3.8, course=2.8, holes=holes, shade_lo=0.6,
                         shade_hi=1.0, n_min=8))
    for th in wins:
        if shutters:
            b.add(cc.on_ring(cc.castle_window(k, 2.0, 3.0, shutters=True, arched=True), th, Rd + 0.2, z0 + 2.2))
        else:
            b.add(cc.on_ring(cc.stone_window(k, 1.9, 3.2), th, Rd + 0.15, z0 + 2.2))
        b.stats["openings"] = b.stats.get("openings", 0) + 1
    if door_back:
        b.add(cc.on_ring(cc.opening(3.2, 5.4, kc(k, "stone_light"), k), math.pi, Rd + 0.15, z0 + 0.05))
    b.add(cc.annulus(Rd - 0.3, Rd + 0.55, z0 + h - 0.15, z0 + h + 0.5, seg, kc(k, "stone_light")))
    return z0 + h + 0.5


def hoarding(b, k, rng, R, walk, seg, lookout=False):
    """Green: timber fighting gallery on beams + struts, plank walls with loopholes, low cone.
    Returns flag position."""
    N = 12 if seg != 8 else 8
    Rh = R + 1.55
    tim, wd = "timber", kc(k, "wood")
    z0, z1 = walk - 0.9, walk + 4.6
    b.add(cc.annulus(R - 0.3, R + 0.45, walk - 1.6, walk - 0.9, 16 if seg != 8 else 8, kc(k, "stone_light"),
                     phase=None if seg != 8 else math.pi / 8))
    b.add(lathe([(0.0, walk - 0.3), (Rh - 0.2, walk - 0.3), (Rh - 0.2, walk + 0.05), (0.0, walk + 0.05)], N,
                "wood_dark", phase=0.0).paint(grad=0.5))
    step = 2 * math.pi / N
    ap = Rh * math.cos(step / 2)
    for i in range(N):
        th = step * i
        b.add(box(0.65, Rh - R + 2.6, 0.7, tim).move(0, -(R + Rh) / 2 - 0.4, walk - 1.6).rotate(th, "Z"))
        p0 = rotate_xy(0, -(R - 0.2), th)
        p1 = rotate_xy(0, -(Rh + 0.3), th)
        b.add(kit.oriented_box((p0[0], p0[1], walk - 6.2), (p1[0], p1[1], walk - 1.45), 0.5, 0.5, tim,
                               normal=(math.cos(th), math.sin(th), 0)))
        thm = th + step / 2
        L = 2 * Rh * math.sin(step / 2) + 0.12
        b.add(box(L, 0.4, z1 - z0, wd).move(0, -ap, z0).rotate(thm, "Z").paint(grad=("range", 0.3, 0.9)))
        for u in (-L * 0.27, L * 0.27):  # vertical battens
            b.add(box(0.28, 0.2, z1 - z0 - 0.4, "wood_dark").move(u, -ap - 0.25, z0 + 0.2).rotate(thm, "Z"))
        b.add(box(0.55, 0.2, 1.6, "black").move(0, -ap - 0.12, walk + 1.3).rotate(thm, "Z"))
        b.add(box(0.62, 0.62, z1 - z0 + 0.3, tim).move(0, -Rh, z0 - 0.15).rotate(th, "Z"))
    for zz in (z0, z1 - 0.5):
        for i in range(N):
            thm = step * (i + 0.5)
            L = 2 * Rh * math.sin(step / 2) + 0.3
            b.add(box(L, 0.3, 0.5, tim).move(0, -ap - 0.3, zz).rotate(thm, "Z"))
    b.stats["hoarding_panels"] = N
    b.stats["merlons"] = N  # loopholed panels stand in for merlons on the timber gallery
    hc = Rh * (0.72 if not lookout else 0.8)
    pcs, apex = cc.low_cone(k, Rh, hc, seg=N, overhang=1.4, rows=2)
    for q in pcs:
        q.rotate(math.pi / N, "Z")
    b.add(cc.place(pcs, 0, 0, 0, z1), tag="roof")
    if not lookout:
        return (0, 0, z1 + apex)
    zl = z1 + hc * 0.42
    rl = 3.0
    b.add(cylinder(rl + 0.4, rl + 0.4, 0.55, 8, "wood_dark").move(0, 0, zl))
    for i in range(8):
        th = 2 * math.pi * i / 8
        b.add(box(0.5, 0.5, 4.6, tim).move(*rotate_xy(0, -rl, th), zl + 0.5))
    b.add(cc.annulus(rl - 0.2, rl + 0.3, zl + 1.7, zl + 2.3, 8, wd, phase=math.pi / 8))
    for i in range(8):  # plank breastwork panels
        thm = 2 * math.pi * (i + 0.5) / 8
        L = 2 * rl * math.sin(math.pi / 8) + 0.1
        b.add(box(L, 0.25, 1.2, wd).move(0, -rl * math.cos(math.pi / 8), zl + 0.55).rotate(thm, "Z"))
    pcs2, apex2 = cc.low_cone(k, rl, 3.4, seg=8, overhang=0.9, rows=1)
    for q in pcs2:
        q.rotate(math.pi / 8, "Z")
    b.add(cc.place(pcs2, 0, 0, 0, zl + 5.1), tag="roof")
    return (0, 0, zl + 5.1 + apex2)


def bartizan(b, k, x, y, walk, h=2.0):
    """Blue: square corner turret corbelled out of the parapet corner, small pyramid roof."""
    sd = kc(k, "stone_dark")
    b.add(cc.square_lathe([(0.3, walk - 4.8), (h, walk - 0.8), (h, walk + 4.6)], sd).move(x, y, 0))
    for zz in (walk - 0.6, walk + 2.1):
        b.add(cc.square_lathe([(h + 0.12, zz), (h + 0.12, zz + 2.4)], kc(k, "stone")).move(x, y, 0)
              .paint(grad=("range", 0.4, 0.9)))
    b.add(cc.square_lathe([(h + 0.35, walk + 4.5), (h + 0.35, walk + 5.0)], kc(k, "stone_light")).move(x, y, 0))
    sx = 1 if x > 0 else -1
    sy = 1 if y > 0 else -1
    b.add(box(0.45, 0.2, 2.0, "window_dark").move(x, y + sy * (h + 0.15), walk + 1.4))
    b.add(box(0.2, 0.45, 2.0, "window_dark").move(x + sx * (h + 0.15), y, walk + 1.4))
    pcs, apex = cc.pyramid(k, h + 0.1, 6.4, overhang=0.55, rows=0, flare=False)
    b.add(cc.place(pcs, 0, x, y, walk + 5.0), tag="roof")
    b.stats["turrets"] = b.stats.get("turrets", 0) + 1


def kiosk(b, k, x, y, z, r=1.75):
    """Yellow: domed corner kiosk (chhatri): plinth, four slender posts, purple lintel, onion dome."""
    tr = kc(k, "trim")
    s = r + 0.1
    b.add(cc.ybox(x - s, x + s, y - s, y + s, z, z + 0.6, kc(k, "stone_light")))
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.add(box(0.85, 0.85, 3.6, kc(k, "stone_light")).move(x + sx * (r - 0.55), y + sy * (r - 0.55), z + 0.6))
    b.add(cc.ybox(x - s - 0.15, x + s + 0.15, y - s - 0.15, y + s + 0.15, z + 4.2, z + 4.8, kc(k, "accent")))
    b.add(cc.ybox(x - s - 0.05, x + s + 0.05, y - s - 0.05, y + s + 0.05, z + 4.05, z + 4.25, tr))
    pcs, apex = cc.dome(k, r * 0.92, r * 2.3, onion=True, seg=6, fin="simple", ribs=False, collar=False)
    b.add(cc.place(pcs, 0, x, y, z + 4.8), tag="roof")
    b.stats["turrets"] = b.stats.get("turrets", 0) + 1


def house(b, k, rng, h, z0, z1):
    """Square cap house on the top walk: smooth light stone with quoins, shuttered window front,
    door back, cornice."""
    b.add(cc.ybox(-h, h, -h, h, z0, z1, kc(k, "stone")).paint(grad=("range", 0.45, 0.95)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.add(cc.quoins(k, rng, sx * h, sy * h, z0, z1, sx, sy, size=(1.8, 1.0), course=2.1))
    b.add(cc.place([q.move(0, -h - 0.15, 0) for q in cc.castle_window(k, 2.0, 3.0)], 0, 0, 0, z0 + 2.0))
    b.add(cc.place([q.move(0, -h - 0.15, 0) for q in cc.castle_door(k, 3.0, 5.0, step=False)], math.pi, 0, 0,
                   z0 + 0.05))
    b.add(cc.ybox(-h - 0.4, h + 0.4, -h - 0.4, h + 0.4, z1 - 0.1, z1 + 0.45, kc(k, "stone_light")))


def mini_turret(b, k, x, y, walk, r=1.5):
    """Red: small corbelled turret standing in the parapet ring, with a needle cone and gold knob."""
    sl, st = kc(k, "stone_light"), kc(k, "stone")
    z0, z1 = walk + 0.2, walk + 6.4
    b.add(lathe([(0.3, z0 - 3.4), (r * 0.6, z0 - 1.4), (r, z0), (r, z1)], 8, st).move(x, y, 0)
          .paint(grad=("range", 0.3, 0.9)))
    b.add(cc.annulus(r - 0.2, r + 0.3, z1 - 0.1, z1 + 0.4, 8, sl).move(x, y, 0))
    th = math.atan2(x, -y)
    b.add(cc.place(cc.on_ring([box(0.4, 0.3, 1.6, "window_dark")], th, r + 0.05, z0 + 2.4), 0, x, y, 0))
    pcs, apex = cc.spire(k, r, 6.8, seg=8, overhang=0.35, rows=1)
    b.add(cc.place(pcs, 0, x, y, z1 + 0.4), tag="roof")
    b.stats["turrets"] = b.stats.get("turrets", 0) + 1


def stair_turret(b, k, rng, walk):
    """Red: slender stair turret rising out of the walk ring (back-left) with its own needle spire."""
    tx, ty = rotate_xy(0.0, -5.3, math.radians(145))
    rt = 2.5
    zt0, zt1 = walk - 6.5, walk + 15.5
    b.add(cc.place(cc.corbel(kc(k, "stone_light"), proj=0.9, w=1.5, h=1.6), math.radians(145), tx, ty, zt0 + 0.1))
    b.add(cylinder(rt, rt, zt1 - zt0, 10, kc(k, "stone")).move(tx, ty, zt0).paint(grad=("range", 0.35, 0.95)))
    th = math.atan2(tx, -ty)
    for zz in (walk - 1.0, walk + 5.2):
        b.add(cc.place([cc.annulus(rt - 0.2, rt + 0.22, zz, zz + 0.5, 10, kc(k, "stone_light"))], 0, tx, ty, 0))
    for a, za in ((th, walk + 2.0), (th + 0.9, walk + 7.4)):
        b.add(cc.place(cc.on_ring(cc.arrow_slit(k, 1.9, 0.4), a, rt + 0.05, za), 0, tx, ty, 0))
    b.add(cc.place([cc.annulus(rt - 0.3, rt + 0.45, zt1 - 0.1, zt1 + 0.45, 10, kc(k, "stone_light"))], 0, tx, ty, 0))
    pcs, apex = cc.spire(k, rt, 12.5, seg=10, overhang=0.55, rows=2)
    b.add(cc.place(pcs, 0, tx, ty, zt1 + 0.45), tag="roof")
    pole, _ = cc.flagpole(k, 3.0, rng, 2.8, 1.1, pennant=True)
    b.add(cc.place(pole, 0, tx, ty, zt1 + 0.45 + apex - 0.3))
    b.stats["turrets"] = b.stats.get("turrets", 0) + 1


# ------------------------------------------------------------------ build

def build(b, p):
    rng = b.rng
    k = p["kingdom"]
    form, crown, walk = p["form"], p["crown"], p["walk"]
    b.stats["openings"] = 0
    roofed = crown in ("spire_big", "pyramid_big")

    if form in ("round", "octagon"):
        R = R_ROUND
        seg = 16 if form == "round" else 8
        slits = [(-0.62, 10.5), (0.66, 17.5), (2.3, 12.5), (-2.3, 19.0)]
        if crown == "spire_turret":
            slits = slits[:3]
        wins = [(0.05, 13.0, 2.2, 3.8), (-0.22, walk - 9.4, 2.6, 4.4)]
        holes = ring_openings(b, k, R, rng, slits, wins)
        round_body(b, k, rng, R, walk, holes, seg)
        if crown.startswith("hoarding"):
            flag_at = hoarding(b, k, rng, R, walk, seg, lookout=crown == "hoarding_lookout")
        else:
            style = {"red": "swallow", "yellow": "stepped", "blue": "peaked"}.get(k, "square")
            if crown == "spire_big":
                Rp, mz = round_crown(b, k, rng, R, walk, style="square", seg=seg, merlon_h=2.6, slits=False)
                pcs, apex = cc.spire(k, Rp + 0.1, 23.0, seg=16, overhang=0.55, rows=3)
                b.add(cc.place(pcs, 0, 0, 0, mz), tag="roof")
                b.add(cc.place(cc.dormer(k, 2.8, 3.0, 4.2), 0, 0, -(Rp - 0.2), mz + 2.2))
                flag_at = (0, 0, mz + apex)
            else:
                skip = (-0.85, 0.85) if crown == "spire_turret" else ()
                Rp, mz = round_crown(b, k, rng, R, walk, style=style, seg=seg, skip=skip,
                                     n_corbel=12 if skip else 14)
                if crown == "spire_turret":
                    z = drum(b, k, rng, 5.3, walk, 7.4, windows=2, shutters=False)
                    pcs, apex = cc.spire(k, 5.3, 21.0, seg=12, overhang=0.9, rows=2)
                    b.add(cc.place(pcs, 0, 0, 0, z), tag="roof")
                    flag_at = (0, 0, z + apex)
                    stair_turret(b, k, rng, walk)
                    for th in skip:  # two corbelled front turrets with needle cones: a spire cluster
                        mini_turret(b, k, *rotate_xy(0.0, -7.0, th), walk)
                else:  # onion
                    z = drum(b, k, rng, 5.0, walk, 5.4, windows=2)
                    b.add(cc.annulus(4.2, 5.6, z, z + 0.9, 12, kc(k, "accent")))
                    pcs, apex = cc.dome(k, 5.7, 12.0, onion=True, seg=12)  # broad bulb
                    b.add(cc.place(pcs, 0, 0, 0, z + 0.9), tag="roof")
                    flag_at = (0, 0, z + 0.9 + apex)
    else:  # square
        hw = HW_SQUARE
        specs = [(0, -3.0, 10.5, "slit"), (0, 3.0, 17.5, "slit"), (0, 0.0, 13.0, "win"),
                 (0, 0.0, walk - 9.4, "win2"), (1, 2.6, 12.0, "slit"),
                 (1, 0.0, cc.WALK_Z, "walkdoor"), (3, 0.0, cc.WALK_Z, "walkdoor"), (2, 0.0, 0.0, "door")]
        square_body(b, k, rng, hw, walk, specs)
        if crown == "pyramid_big":
            hp, mz = square_crown(b, k, rng, hw, walk, "square", merlon_h=2.6, cap=False)
            pcs, apex = cc.pyramid(k, hp + 0.1, 17.5, overhang=0.6)
            b.add(cc.place(pcs, 0, 0, 0, mz), tag="roof")
            b.add(cc.place(cc.dormer(k, 2.8, 3.0, 4.2), 0, 0, -(hp - 0.1), mz + 2.0))
            flag_at = (0, 0, mz + apex)
        elif crown == "bartizans":
            hp, mz = square_crown(b, k, rng, hw, walk, "peaked", corners=False)
            for sx in (-1, 1):
                for sy in (-1, 1):
                    bartizan(b, k, sx * (hp - 1.4), sy * (hp - 1.4), walk)
            hz = walk + 6.2
            house(b, k, rng, 4.8, walk, hz)
            pcs, apex = cc.pyramid(k, 4.8, 13.5, overhang=1.0, rows=2)
            b.add(cc.place(pcs, 0, 0, 0, hz + 0.45), tag="roof")
            flag_at = (0, 0, hz + 0.45 + apex)
        else:  # kiosks
            hp, mz = square_crown(b, k, rng, hw, walk, "stepped", corners=False)
            for sx in (-1, 1):
                for sy in (-1, 1):
                    kiosk(b, k, sx * (hp - 1.75), sy * (hp - 1.75), walk + 0.05)
            z = drum(b, k, rng, 4.9, walk, 8.4, windows=2, seg=12, shutters=False)  # chunky raised drum
            b.add(cc.annulus(4.1, 5.5, z, z + 0.8, 12, kc(k, "accent")))
            pcs, apex = cc.dome(k, 5.1, 10.5, onion=True, seg=12)  # true onion: bulb, pinched neck, tip
            b.add(cc.place(pcs, 0, 0, 0, z + 0.8), tag="roof")
            flag_at = (0, 0, z + 0.8 + apex)

    # front banner under the parapet and the main flag
    bz = walk - 3.3 if not crown.startswith("hoarding") else walk - 6.6
    rb = R_ROUND + 0.35 if form != "square" else HW_SQUARE + 0.15
    if form == "octagon":
        rb = R_ROUND + 0.2
    b.add(cc.on_ring(cc.banner(k, 3.2, 7.4, tail="swallow" if k in ("red", "green") else "point"), 0.0, rb, bz))
    pole, ptop = cc.flagpole(k, 6.0, rng, 5.2, 3.0)
    b.add(cc.place(pole, 0, flag_at[0], flag_at[1], flag_at[2] - 0.6))

    ring_r = (R_ROUND - 1.4) if form != "square" else (HW_SQUARE - 1.2)
    b.socket("top", 0.0, -ring_r, walk)
    b.socket("door", 0.0, 9.6, 0.0)
    b.socket("flag", flag_at[0], flag_at[1], flag_at[2] - 0.6 + ptop)
    b.socket("walk_left", -R_ROUND - 0.4, 0.0, cc.WALK_Z)
    b.socket("walk_right", R_ROUND + 0.4, 0.0, cc.WALK_Z)
    b.stats["pieces"] = len(b.pieces)
    b.stats["roof"] = b.count_tag("roof")
    b.stats["roofed_walk"] = int(roofed)
