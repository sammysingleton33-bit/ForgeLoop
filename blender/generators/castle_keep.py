"""Castle keep: the centrepiece of each kingdom and the biggest mass in the world. A raised podium
with a grand stair to an arched door, a two-storey ashlar hall block with corner turrets in the
kingdom roof language, an upper volume with the kingdom's signature crown, banners, a balcony
over the door and a tall flag. Front (door) faces -Y.

  red    Emberhold: a vertical cluster of spires - round corner turrets with spires and a tall round
         donjon with a giant spire and a slender stair turret
  blue   Frostmere: crisp square massing - square corner towers and a square donjon under steep
         slate pyramids with dormers, silver finials
  green  Thornwood: a stone hall carrying a jettied timber-framed upper storey (the village's
         cottage language at castle scale) under a big moss-green roof with a timber lantern;
         round corner towers with timber hoardings and low cones
  yellow Sunspire: sandstone palace - stepped merlons, purple/ivory friezes, corner towers with
         onion domes and a great onion dome on a tall windowed drum
"""

import math

from lib import kit
from lib.geo import box, cylinder, lathe
from generators import _castle_common as cc
from generators._castle_common import kc

NAME = "castle_keep"
VERSION = 1
CATEGORY = "castle"
BUDGET = "castle_keep"
COLLISION = {"fidelity": "PreciseConvexDecomposition"}
CHECKS = {"min_pieces": 300, "min_windows": 10, "min_turrets": 4, "min_roof": 4}
DEFAULT_VARIANTS = 4
LINEUP_GAP = 8.0
HERO_VIEW = {"azimuth": 33, "elevation": 17}

POD = 3.2  # podium height = ground-floor level


def variants(n, seed):
    out = []
    for i in range(n):
        k = cc.KINGDOMS[i % 4]
        out.append({"kingdom": k, "seed": seed * 1000 + 700 + i})
    return out


def asset_id(i, params):
    return f"castle_keep_{params['kingdom']}_{i // 4 + 1:02d}"


def rotate_xy(x, y, th):
    c, s = math.cos(th), math.sin(th)
    return x * c - y * s, x * s + y * c


# ------------------------------------------------------------------ openings

def opening_piece(k, kind):
    """(pieces authored at y=0 facing -Y, base z=0), hole half-width, hole height."""
    if kind == "win":  # shuttered kit window (village language), scaled up
        return cc.castle_window(k, 3.0, 4.6, shutters=True, arched=True), 3.0, 4.9
    if kind == "win_s":
        return cc.castle_window(k, 2.4, 3.6, shutters=True, arched=True), 2.6, 3.9
    if kind == "tall":
        return cc.stone_window(k, 2.8, 5.6, arched=True, mullion=True), 2.2, 5.8
    if kind == "slit":
        return cc.arrow_slit(k, 3.2), 1.1, 3.4
    raise ValueError(kind)


def volume(b, k, rng, W, D, z0, z1, specs, quoin=True, course=3.1, blen=(4.8, 7.8), core=None, faces=(0, 1, 2, 3)):
    """Rectangular ashlar volume centred on the origin. specs: (face, u, z, kind) openings
    (face 0 = front -Y, 1 = +X, 2 = back, 3 = -X; u along the face, z absolute)."""
    b.add(cc.ybox(-W / 2, W / 2, -D / 2, D / 2, z0, z1, core or kc(k, "stone_dark")).paint(grad=("range", 0.2, 0.6)))
    holes = {f: [] for f in range(4)}
    for f, u, z, kind in specs:
        pcs, hw, hh = opening_piece(k, kind)
        dist = D / 2 if f in (0, 2) else W / 2
        b.add(cc.place([q.move(u, -dist - 0.12, 0) for q in pcs], f * math.pi / 2, 0, 0, z))
        holes[f].append((u - hw, u + hw, z - 0.5, z + hh + 0.4))
        if kind.startswith("win") or kind == "tall":
            b.stats["windows"] = b.stats.get("windows", 0) + 1
    for f in faces:
        L = W if f in (0, 2) else D
        dist = D / 2 if f in (0, 2) else W / 2
        m = 1.0 if quoin else 0.0
        blocks = cc.ashlar_plane(k, rng, -L / 2 + m, L / 2 - m, z0, z1, course=course, blen=blen, holes=holes[f])
        b.add([q.move(0, -dist, 0).rotate(f * math.pi / 2, "Z") for q in blocks])
    if quoin:
        for sx in (-1, 1):
            for sy in (-1, 1):
                b.add(cc.quoins(k, rng, sx * W / 2, sy * D / 2, z0, z1, sx, sy, size=(2.8, 1.5), course=course))


def string_course(b, k, W, D, z, proj=0.45, h=0.6, color=None):
    b.add(cc.ybox(-W / 2 - proj, W / 2 + proj, -D / 2 - proj, D / 2 + proj, z, z + h, color or kc(k, "stone_light")))


def crown_rect(b, k, rng, W, D, z, style, merlon_h=cc.MERLON_H, corbels=True, skip_corners=0.0):
    """Corbel table, projecting parapet and merlons round a rectangle; walk at z. Returns parapet top."""
    sl, st = kc(k, "stone_light"), kc(k, "stone")
    pr = 1.1
    if corbels:
        for f in range(4):
            L = W if f in (0, 2) else D
            dist = D / 2 if f in (0, 2) else W / 2
            n = max(2, int((L - 2 * skip_corners) // 3.6))
            for i in range(n):
                u = -L / 2 + skip_corners + (L - 2 * skip_corners) * (i + 0.5) / n
                b.add(cc.place([q.move(u, -dist, z - 0.55) for q in cc.corbel(sl, proj=pr + 0.1, w=1.05, h=2.1)],
                               f * math.pi / 2))
    Wp, Dp = W + 2 * pr, D + 2 * pr
    for f in range(4):
        L = Wp if f in (0, 2) else Dp
        dist = Dp / 2 if f in (0, 2) else Wp / 2
        b.add(cc.ybox(-L / 2, L / 2, -dist, -dist + 1.2, z - 0.6, z + 2.9, st).rotate(f * math.pi / 2, "Z")
              .paint(grad=("range", 0.4, 0.85)))
        b.add(cc.ybox(-L / 2 - 0.1, L / 2 + 0.1, -dist - 0.12, -dist + 1.32, z + 2.6, z + 2.95, sl).rotate(f * math.pi / 2, "Z"))
        Lm = L - 2 * skip_corners
        n = max(2, int(Lm // 4.6))
        for i in range(n):
            u = -Lm / 2 + Lm * (i + 0.5) / n
            m = cc.merlon(style, k, w=cc.MERLON_W + (0.4 if style == "stepped" else 0.0), h=merlon_h, t=1.2,
                          cap=style == "square")
            b.add(cc.place([q.move(u, -dist + 0.6, z + 2.95) for q in m], f * math.pi / 2))
            b.stats["merlons"] = b.stats.get("merlons", 0) + 1
    b.add(cc.ybox(-W / 2, W / 2, -D / 2, D / 2, z - 0.3, z + 0.05, "cobble").paint(grad=0.55))
    return z + 2.95 + merlon_h


def round_turret(b, k, rng, x, y, r, z0, z1, seg=12, slits=True, course=3.4, seg_len=5.2, hidden_to=None):
    """Corner turret shaft (ashlar ring, string course, slits); returns top z. Below `hidden_to`
    the quadrant buried in the hall gets no blocks."""
    b.add(cylinder(r, r, z1 - z0, seg, kc(k, "stone_dark")).move(x, y, z0))
    holes = []
    ths = []
    if slits:
        th_out = math.atan2(x, -y)
        for j, zz in enumerate((z0 + (z1 - z0) * 0.35, z0 + (z1 - z0) * 0.7)):
            th = th_out + (0.35 if j else -0.35)
            ths.append((th, zz))
            holes.append((th, 1.15 / r, zz - 0.5, zz + 3.6))
    th_out = math.atan2(x, -y)
    if hidden_to and hidden_to > z0:
        nlo = max(1, int(round((hidden_to - z0) / course)))
        zsplit = z0 + nlo * course
        b.add(cc.place(cc.ashlar_ring(k, rng, r, z0, zsplit, seg_len=seg_len, course=course, holes=holes, n_min=6,
                                      arc=(th_out, 0.78 * math.pi)), 0, x, y, 0))
        b.add(cc.place(cc.ashlar_ring(k, rng, r, zsplit, z1, seg_len=seg_len, course=course, holes=holes, n_min=6,
                                      shade_lo=0.6), 0, x, y, 0))
    else:
        b.add(cc.place(cc.ashlar_ring(k, rng, r, z0, z1, seg_len=seg_len, course=course, holes=holes, n_min=6),
                       0, x, y, 0))
    for th, zz in ths:
        b.add(cc.place(cc.on_ring(cc.arrow_slit(k, 3.0), th, r + 0.1, zz), 0, x, y, 0))
    b.add(cc.annulus(r - 0.3, r + 0.5, z1 - 0.1, z1 + 0.55, seg, kc(k, "stone_light")).move(x, y, 0))
    b.stats["turrets"] = b.stats.get("turrets", 0) + 1
    return z1 + 0.55


def podium_and_door(b, k, rng, W, D, door_w=6.4, door_h=10.6):
    """Podium with a course of big blocks, a grand front stair, the arched door, an emblem shield and a
    balcony above the door. Returns (door socket, balcony socket)."""
    sd, st, sl = kc(k, "stone_dark"), kc(k, "stone"), kc(k, "stone_light")
    Wp, Dp = W + 8.0, D + 7.0
    b.add(cc.ybox(-Wp / 2, Wp / 2, -Dp / 2, Dp / 2, 0.0, POD, sd).paint(grad=("range", 0.1, 0.4)))
    b.add(cc.ybox(-Wp / 2 - 0.2, Wp / 2 + 0.2, -Dp / 2 - 0.2, Dp / 2 + 0.2, POD - 0.45, POD, sl))
    for f in range(4):
        L = Wp if f in (0, 2) else Dp
        dist = Dp / 2 if f in (0, 2) else Wp / 2
        holes = [(-8.0, 8.0, 0.0, POD)] if f == 0 else []
        blocks = cc.ashlar_plane(k, rng, -L / 2, L / 2, 0.15, POD - 0.45, course=POD - 0.6, blen=(5.0, 8.4),
                                 holes=holes, shade_t=0.1, weights=(0.45, 0.25, 0.3))
        b.add([q.move(0, -dist, 0).rotate(f * math.pi / 2, "Z") for q in blocks])
    # grand stair: 4 steps down from the podium edge, flanked by low cheek walls with urns/lion blocks
    n = 4
    rise = POD / n
    for i in range(n):
        y_out = -Dp / 2 - (n - i) * 1.3
        b.add(cc.ybox(-7.0, 7.0, y_out, -Dp / 2 + 0.3, i * rise, (i + 1) * rise, sl if i % 2 else st)
              .paint(grad=("range", 0.4, 0.9)))
    for sx in (-1, 1):
        b.add(cc.ybox(sx * 7.0 - 0.9, sx * 7.0 + 0.9, -Dp / 2 - n * 1.3 - 0.2, -Dp / 2 + 0.3, 0.0, POD + 1.0, st))
        b.add(cc.ybox(sx * 7.0 - 1.1, sx * 7.0 + 1.1, -Dp / 2 - n * 1.3 - 0.4, -Dp / 2 - n * 1.3 + 1.6, POD + 1.0,
                      POD + 1.5, sl))
        b.add(lathe([(0.0, 0.0), (0.7, 0.1), (0.9, 0.7), (0.5, 1.4), (0.75, 1.6), (0.0, 1.7)], 8, kc(k, "trim"))
              .move(sx * 7.0, -Dp / 2 - n * 1.3 + 0.6, POD + 1.5))
    # door
    b.add([q.move(0, -D / 2 - 0.15, POD) for q in cc.arched_door(k, door_w, door_h, jw=1.3, m=9, step=False)])
    # emblem shield above the door
    sh_z = POD + door_h + 2.6
    b.add([q.move(0, -D / 2, sh_z) for q in cc.shield_crest(k, 2.2)])
    # balcony over the door (stone slab on corbels, balustrade), door onto it
    bz = POD + 14.6
    b.add(cc.ybox(-5.0, 5.0, -D / 2 - 3.0, -D / 2 + 0.2, bz - 0.6, bz, sl))
    for u in (-4.0, -1.35, 1.35, 4.0):
        b.add([q.move(u, -D / 2, bz - 0.6) for q in cc.corbel(sl, proj=2.8, w=0.9, h=2.4)])
    b.add(cc.ybox(-5.0, 5.0, -D / 2 - 3.0, -D / 2 - 2.5, bz, bz + 2.6, st).paint(grad=("range", 0.4, 0.9)))
    b.add(cc.ybox(-5.2, 5.2, -D / 2 - 3.15, -D / 2 - 2.35, bz + 2.6, bz + 3.0, sl))
    for sx in (-1, 1):
        b.add(cc.ybox(sx * 5.0 - 0.5 * sx - 0.25, sx * 5.0 - 0.5 * sx + 0.25, -D / 2 - 3.0, -D / 2, bz, bz + 2.6, st))
    b.add([q.move(0, -D / 2 - 0.12, bz) for q in cc.arched_door(k, 3.6, 6.4, step=False, jw=0.7, m=7)])
    b.stats["windows"] = b.stats.get("windows", 0) + 1
    return (0.0, -Dp / 2 - n * 1.3 - 2.0, 0.0), (0.0, -D / 2 - 1.6, bz)


def moss_base(b, rng, W, D, n=5):
    """Moss clumps along the foot of the podium (weathering, same language as walls/towers)."""
    Wp, Dp = W + 8.0, D + 7.0
    for i in range(n):
        side = i % 3
        r = rng.uniform(0.9, 1.3)
        m = lathe([(0.0, 0.0), (r, 0.0), (r * 0.9, 0.4 * r), (r * 0.5, 0.75 * r), (0.0, 0.9 * r)], 5, "moss")
        m.scale(rng.uniform(1.8, 2.6), rng.uniform(0.9, 1.2), rng.uniform(0.7, 1.0))
        if side == 0:
            m.move(rng.choice((-1, 1)) * rng.uniform(9.5, Wp / 2 - 2.0), -Dp / 2 - 0.3, 0.0)
        elif side == 1:
            m.rotate(math.pi / 2, "Z").move(Wp / 2 + 0.3, rng.uniform(-Dp / 2 + 2, Dp / 2 - 2), 0.0)
        else:
            m.rotate(math.pi / 2, "Z").move(-Wp / 2 - 0.3, rng.uniform(-Dp / 2 + 2, Dp / 2 - 2), 0.0)
        b.add(m.paint(grad=("range", 0.15, 0.9), smooth=True))


def big_banners(b, k, D, xs, z_top, h=12.0, w=4.2):
    for x in xs:
        b.add([q.move(x, -D / 2 - 0.1, z_top) for q in cc.banner(k, w, h, tail="swallow" if k in ("red", "green")
                                                                    else "point")])


# ------------------------------------------------------------------ kingdoms

def keep_red(b, k, rng):
    W, D = 34.0, 26.0
    zm = POD + 24.0
    door, balc = podium_and_door(b, k, rng, W, D)
    specs = [(0, -11.0, POD + 2.6, "tall"), (0, 11.0, POD + 2.6, "tall"),
             (0, -11.0, POD + 14.0, "win"), (0, 11.0, POD + 14.0, "win"),
             (1, -5.0, POD + 3.0, "tall"), (1, 5.0, POD + 14.0, "win"), (3, 5.0, POD + 3.0, "tall"),
             (3, -5.0, POD + 14.0, "win"), (2, -8.0, POD + 14.0, "win"), (2, 8.0, POD + 14.0, "win"),
             (2, 0.0, POD + 3.0, "tall")]
    holes_door = [(0, 0.0, POD, "door")]
    volume(b, k, rng, W, D, POD, zm, specs, quoin=False, faces=())
    face_blocks(b, k, rng, W, D, POD, zm, specs, extra_holes={0: [(-4.6, 4.6, POD, POD + 19.0)]})
    string_course(b, k, W, D, POD + 12.2)
    crown_rect(b, k, rng, W, D, zm, "swallow", skip_corners=4.0)
    big_banners(b, k, D, (-5.6, 5.6), POD + 12.0, 10.5, 3.4)
    # corner turrets with spires
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * W / 2, sy * D / 2
            zt = round_turret(b, k, rng, x, y, 4.4, POD, zm + 7.0, hidden_to=zm)
            pcs, apex = cc.spire(k, 4.4, 14.0, seg=12, overhang=0.7, rows=2)
            b.add(cc.place(pcs, 0, x, y, zt), tag="roof")
    # donjon: round, corbelled crenels, drum + giant spire, slender stair turret
    R = 8.6
    cy = 2.0
    zd = zm + 15.0
    b.add(cylinder(R, R, zd - zm + 0.5, 16, kc(k, "stone_dark")).move(0, cy, zm - 0.5))
    holes = [(0.0, 0.32, zm + 3.5, zm + 9.0), (math.pi / 2, 0.3, zm + 4.0, zm + 9.0), (-math.pi / 2, 0.3, zm + 4.0, zm + 9.0)]
    b.add(cc.place(cc.ashlar_ring(k, rng, R, zm - 0.5, zd - 2.3, seg_len=6.2, course=3.4, holes=holes), 0, 0, cy, 0))
    for th, _, za, _ in holes:
        b.add(cc.place(cc.on_ring(cc.castle_window(k, 2.6, 4.0), th, R + 0.2, za + 0.5), 0, 0, cy, 0))
        b.stats["windows"] += 1
    for i in range(14):
        th = 2 * math.pi * (i + 0.5) / 14
        b.add(cc.place(cc.on_ring(cc.corbel(kc(k, "stone_light"), proj=1.3, w=1.05, h=2.2), th, R, zd - 0.55), 0, 0, cy, 0))
    Rp = R + 1.25
    b.add(cc.annulus(R + 0.05, Rp, zd - 0.6, zd + 3.0, 16, kc(k, "stone")).move(0, cy, 0))
    b.add(cc.annulus(R - 0.2, Rp + 0.15, zd + 2.7, zd + 3.05, 16, kc(k, "stone_light")).move(0, cy, 0))
    n = int(2 * math.pi * (Rp - 0.6) // 4.6)
    for i in range(n):
        b.add(cc.place(cc.on_ring(cc.merlon("swallow", k, t=1.2), 2 * math.pi * i / n, Rp - 0.6, zd + 3.0), 0, 0, cy, 0))
    b.add(lathe([(0.0, zd - 0.3), (R + 0.3, zd - 0.3), (R + 0.3, zd + 0.05), (0.0, zd + 0.05)], 16, "cobble").move(0, cy, 0))
    Rd = 5.8
    b.add(cylinder(Rd, Rd, 7.0, 12, kc(k, "stone")).move(0, cy, zd).paint(grad=("range", 0.4, 0.95)))
    for th in (-0.5, 0.5, math.pi):
        b.add(cc.place(cc.on_ring(cc.stone_window(k, 1.8, 3.2), th, Rd + 0.1, zd + 1.8), 0, 0, cy, 0))
    b.add(cc.annulus(Rd - 0.3, Rd + 0.55, zd + 6.9, zd + 7.5, 12, kc(k, "stone_light")).move(0, cy, 0))
    pcs, apex = cc.spire(k, Rd, 24.0, seg=16, overhang=0.9, rows=3)
    b.add(cc.place(pcs, 0, 0, cy, zd + 7.5), tag="roof")
    b.add(cc.place(cc.dormer(k, 2.6, 2.8, 4.0), 0, 0, cy - Rd - 0.4, zd + 9.6))
    flag_z = zd + 7.5 + apex
    # stair turret on the donjon's back-right
    tx, ty = 6.0, cy + 6.6
    b.add(cylinder(2.6, 2.6, zd + 9.0 - zm, 10, kc(k, "stone")).move(tx, ty, zm).paint(grad=("range", 0.35, 0.95)))
    for zz in (zd - 0.6, zd + 4.5):
        b.add(cc.annulus(2.4, 2.9, zz, zz + 0.5, 10, kc(k, "stone_light")).move(tx, ty, 0))
    pcs, apex2 = cc.spire(k, 2.6, 10.0, seg=10, overhang=0.5, rows=1)
    b.add(cc.place(pcs, 0, tx, ty, zd + 9.0), tag="roof")
    return door, balc, (0, cy, flag_z)


def face_blocks(b, k, rng, W, D, z0, z1, specs, extra_holes=None, course=3.1, blen=(4.8, 7.8), m=0.0):
    """Ashlar on the four faces honouring the opening specs (used when turrets cover the corners)."""
    holes = {f: list((extra_holes or {}).get(f, [])) for f in range(4)}
    for f, u, z, kind in specs:
        if kind == "door":
            continue
        _, hw, hh = opening_piece(k, kind)
        holes[f].append((u - hw, u + hw, z - 0.5, z + hh + 0.4))
    for f in range(4):
        L = W if f in (0, 2) else D
        dist = D / 2 if f in (0, 2) else W / 2
        blocks = cc.ashlar_plane(k, rng, -L / 2 + m, L / 2 - m, z0, z1, course=course, blen=blen, holes=holes[f])
        b.add([q.move(0, -dist, 0).rotate(f * math.pi / 2, "Z") for q in blocks])


def keep_blue(b, k, rng):
    W, D = 36.0, 26.0
    zm = POD + 24.0
    door, balc = podium_and_door(b, k, rng, W, D)
    specs = [(0, -10.0, POD + 2.6, "tall"), (0, 10.0, POD + 2.6, "tall"),
             (0, -9.5, POD + 14.0, "win"), (0, 9.5, POD + 14.0, "win"),
             (1, 0.0, POD + 14.0, "win"), (3, 0.0, POD + 14.0, "win"), (2, -6.0, POD + 14.0, "win"),
             (2, 6.0, POD + 14.0, "win"), (2, 0.0, POD + 3.0, "tall")]
    volume(b, k, rng, W, D, POD, zm, specs, quoin=False, faces=())
    face_blocks(b, k, rng, W, D, POD, zm, specs, extra_holes={0: [(-4.6, 4.6, POD, POD + 19.0)]})
    string_course(b, k, W, D, POD + 12.2)
    crown_rect(b, k, rng, W, D, zm, "peaked", skip_corners=4.6)
    big_banners(b, k, D, (-5.6, 5.6), POD + 12.0, 10.5, 3.4)
    # square corner towers with pyramids
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * W / 2, sy * D / 2
            h = 4.3
            zt = zm + 9.0
            b.add(cc.ybox(x - h, x + h, y - h, y + h, POD, zt, kc(k, "stone_dark")))
            for f in range(4):
                th = f * math.pi / 2
                ox, oy = rotate_xy(0, -h, th)
                inner = (f == 0 and sy > 0) or (f == 2 and sy < 0) or (f == 1 and sx < 0) or (f == 3 and sx > 0)
                z_start = zm if inner else POD
                bl = cc.ashlar_plane(k, rng, -h, h, z_start, zt, course=3.0, blen=(2.8, 4.6), end_gap=False)
                b.add([q.move(0, -h, 0).rotate(th, "Z").move(x, y, 0) for q in bl])
            for f in range(4):  # corbel table under the eaves on the two outward faces
                th = f * math.pi / 2
                ox, oy = rotate_xy(0, -1, th)
                if ox * sx < 0.5 and oy * sy < 0.5:
                    continue
                b.add(cc.place([q.move(u, -h, zt - 0.05) for u in (-2.2, 2.2) for q in
                                cc.corbel(kc(k, "stone_light"), 0.6, 0.9, 1.4)], th, x, y))
            b.add(cc.ybox(x - h - 0.7, x + h + 0.7, y - h - 0.7, y + h + 0.7, zt - 0.1, zt + 0.5, kc(k, "stone_light")))
            b.add(box(0.5, 0.3, 2.8, "window_dark").move(x, y - h - 0.2 if sy < 0 else y + h + 0.2, zt - 5.0))
            pcs, apex = cc.pyramid(k, h + 0.5, 12.5, overhang=0.6, rows=2)
            b.add(cc.place(pcs, 0, x, y, zt + 0.5), tag="roof")
            b.stats["turrets"] = b.stats.get("turrets", 0) + 1
    # square donjon with a steep pyramid and dormers
    Wd, Dd = 18.0, 15.0
    zd = zm + 13.0
    cy = 1.5
    dspecs = [(0, -4.5, zm + 3.2, "win_s"), (0, 4.5, zm + 3.2, "win_s"), (1, 0.0, zm + 3.2, "win_s"),
              (3, 0.0, zm + 3.2, "win_s"), (2, 0.0, zm + 3.2, "win_s")]
    pcs_before = len(b.pieces)
    volume(b, k, rng, Wd, Dd, zm - 0.3, zd, dspecs, quoin=True, course=3.2, blen=(4.0, 6.4))
    for q in b.pieces[pcs_before:]:
        q.move(0, cy, 0)
    string_course(b, k, Wd, Dd, zd - 0.6, proj=0.6, h=0.7)
    b.pieces[-1].move(0, cy, 0)
    pcs, apex = cc.pyramid(k, Wd / 2, 22.0, overhang=1.0, rows=3)
    for q in pcs:
        q.scale(1.0, Dd / Wd, 1.0)
    b.add(cc.place(pcs, 0, 0, cy, zd + 0.1), tag="roof")
    for th, off in ((0.0, Dd / 2), (math.pi, Dd / 2)):
        dx, dy = rotate_xy(0, -(off - 1.6), th)
        b.add(cc.place(cc.dormer(k, 3.0, 3.0, 4.4), th, dx, cy + dy, zd + 3.2))
    for th in (math.pi / 2, -math.pi / 2):
        dx, dy = rotate_xy(0, -(Wd / 2 - 1.6), th)
        b.add(cc.place(cc.dormer(k, 2.6, 2.6, 4.0), th, dx, cy + dy, zd + 3.0))
    return door, balc, (0, cy, zd + 0.1 + apex)


def keep_green(b, k, rng):
    W, D = 38.0, 27.0
    zm = POD + 13.0
    door, balc = podium_and_door(b, k, rng, W, D, door_w=6.4, door_h=9.6)
    specs = [(0, -11.0, POD + 2.6, "tall"), (0, 11.0, POD + 2.6, "tall"), (1, 0.0, POD + 2.6, "tall"),
             (3, 0.0, POD + 2.6, "tall"), (2, -7.0, POD + 2.6, "tall"), (2, 7.0, POD + 2.6, "tall")]
    volume(b, k, rng, W, D, POD, zm, specs, quoin=False, faces=())
    face_blocks(b, k, rng, W, D, POD, zm, specs, extra_holes={0: [(-4.6, 4.6, POD, zm)]})
    # jettied timber-framed upper storey (the cottage language at castle scale), two storeys high
    j = 1.2
    Wu, Du = W - 2.0 + 2 * j, D - 2.0 + 2 * j
    b.add(cc.ybox(-Wu / 2 - 0.2, Wu / 2 + 0.2, -Du / 2 - 0.2, Du / 2 + 0.2, zm, zm + 0.8, "timber"))
    for i in range(13):  # joist ends under the jetty (front)
        u = -W / 2 + 1.6 + (W - 3.2) * i / 12
        b.add(box(0.7, j + 0.6, 0.7, "timber").move(u, -D / 2 - j / 2 + 0.2, zm - 0.65))
    zu = zm + 0.8
    hu = 15.0
    b.add(cc.ybox(-Wu / 2, Wu / 2, -Du / 2, Du / 2, zu, zu + hu, "plaster").paint(grad=("range", 0.35, 0.85)))
    for off in (-Du / 2, Du / 2):
        fr = kit.wall_face_frame(Wu, hu, "x", off, "timber", posts=6, braces=True, rng=rng, rail=hu * 0.5)
        b.add([f.move(0, 0, zu) for f in fr])
    for off in (-Wu / 2, Wu / 2):
        fr = kit.wall_face_frame(Du, hu, "y", off, "timber", posts=4, braces=True, rng=rng, rail=hu * 0.5)
        b.add([f.move(0, 0, zu) for f in fr])
    xs = [-Wu / 2 + Wu * (i + 0.5) / 5 for i in range(5)]
    for row, zz in enumerate((zu + 2.4, zu + 2.4 + hu * 0.5)):
        for i, x in enumerate(xs):
            if row == 1 and i == 2:
                continue
            b.add([q.move(x, -Du / 2, zz) for q in cc.castle_window(k, 2.4, 3.4, arched=False)])
            b.stats["windows"] = b.stats.get("windows", 0) + 1
        for x in (-Wu / 4, Wu / 4):
            b.add([q.rotate(math.pi, "Z").move(x, Du / 2, zz) for q in cc.window_v(2.4, 3.4, "timber", None)])
    for sx in (-1, 1):
        for y in (-Du / 4, Du / 4):
            b.add([q.rotate(sx * math.pi / 2, "Z").move(sx * Wu / 2, y, zu + 2.4) for q in
                   cc.castle_window(k, 2.4, 3.4, arched=False)])
            b.stats["windows"] += 1
    top = zu + hu
    roof, rise = kit.gable_roof(Du, Wu, 48.0, overhang=1.8, gable_overhang=1.4, thickness=0.9,
                                color=kc(k, "roof"), rows=5, ridge_color=kc(k, "roof_dark"), style="tile", rng=rng)
    for q in roof:
        b.add(q.rotate(math.pi / 2, "Z").move(0, 0, top), tag="roof")
    for sx in (-1, 1):
        g = kit.gable_end(Du, rise, 0.8, "plaster")
        b.add(g.rotate(math.pi / 2, "Z").move(sx * (Wu / 2 - 0.4), 0, top).paint(grad=("range", 0.5, 0.85)))
        xg = sx * (Wu / 2 + 0.1)
        from lib.geo import Vector
        n = Vector((sx, 0, 0))
        b.add(kit.oriented_box((xg, 0, top + 0.6), (xg, 0, top + rise - 1.0), kit.TIMBER, 0.4, "timber", n))
        for s in (-1, 1):
            b.add(kit.oriented_box((xg, s * Du * 0.38, top + 0.6), (xg, s * 0.4, top + rise * 0.6), kit.TIMBER,
                                   0.4, "timber", n))
        b.add([q.rotate(sx * math.pi / 2, "Z").move(sx * Wu / 2 + sx * 0.4, 0, top + rise * 0.25) for q in
               cc.window_v(2.0, 2.6, "timber", kc(k, "shutter"))])
    # dormers on the front slope
    for x in (-9.0, 9.0):
        b.add(cc.place(cc.dormer(k, 3.2, 3.2, 5.0), 0, x, -Du / 2 + 1.4, top + 1.6))
    # timber lantern on the ridge with a low cone + flag
    lz = top + rise - 0.6
    rl = 3.0
    b.add(cc.ybox(-rl, rl, -rl, rl, lz, lz + 4.5, kc(k, "wood")).paint(grad=("range", 0.3, 0.9)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.add(box(0.6, 0.6, 4.8, "timber").move(sx * (rl - 0.1), sy * (rl - 0.1), lz))
    for f in range(4):
        b.add(box(1.6, 0.2, 2.0, "black").move(0, -rl - 0.05, lz + 1.6).rotate(f * math.pi / 2, "Z"))
    pcs, apex = cc.low_cone(k, rl * 1.2, 3.6, seg=8, overhang=0.9, rows=1)
    for q in pcs:
        q.rotate(math.pi / 8, "Z")
    b.add(cc.place(pcs, 0, 0, 0, lz + 4.5), tag="roof")
    flag = (0, 0, lz + 4.5 + apex)
    # chimney
    b.add([q.move(W / 2 - 8.0, 4.0, zm) for q in kit.chimney(top + rise - zm + 2.0, 2.6, kc(k, "stone"), kc(k, "stone_dark"))])
    # round corner towers with hoardings and low cones
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (W / 2 + 0.6), sy * (D / 2 + 0.6)
            r = 5.0
            zt = round_turret(b, k, rng, x, y, r, POD, zm + 15.0, hidden_to=zm + 15.0)
            hoard_ring(b, k, x, y, r, zt)
    big_banners(b, k, D, (-6.0, 6.0), POD + 10.5, 8.5, 3.4)
    return door, (0.0, -D / 2 - 1.6, POD + 14.6), flag


def hoard_ring(b, k, x, y, r, z):
    """Timber hoarding ring + low cone crowning a round corner tower (green)."""
    N = 8
    Rh = r + 1.2
    step = 2 * math.pi / N
    ap = Rh * math.cos(step / 2)
    b.add(lathe([(0.0, z - 0.2), (Rh, z - 0.2), (Rh, z + 0.2), (0.0, z + 0.2)], N, "wood_dark", phase=0.0).move(x, y, 0))
    for i in range(N):
        th = step * i
        if i % 2 == 0:
            b.add(cc.place([kit.oriented_box((0, -(r - 0.2), z - 4.0), (0, -(Rh + 0.3), z - 0.1), 0.5, 0.5,
                                             "timber", normal=(1, 0, 0))], th, x, y, 0))
        thm = th + step / 2
        L = 2 * Rh * math.sin(step / 2) + 0.12
        b.add(cc.place([box(L, 0.4, 4.2, kc(k, "wood")).move(0, -ap, z).paint(grad=("range", 0.3, 0.9))], thm, x, y, 0))
        b.add(cc.place([box(0.5, 0.2, 1.4, "black").move(0, -ap - 0.12, z + 1.4)], thm, x, y, 0))
        b.add(cc.place([box(0.55, 0.55, 4.5, "timber").move(0, -Rh, z - 0.1)], th, x, y, 0))
    pcs, apex = cc.low_cone(k, Rh, Rh * 0.75, seg=N, overhang=1.1, rows=1)
    for q in pcs:
        q.rotate(math.pi / N, "Z")
    b.add(cc.place(pcs, 0, x, y, z + 4.2), tag="roof")
    b.stats["turrets"] = b.stats.get("turrets", 0) + 1


def keep_yellow(b, k, rng):
    W, D = 36.0, 28.0
    zm = POD + 22.0
    door, balc = podium_and_door(b, k, rng, W, D)
    specs = [(0, -10.5, POD + 2.6, "tall"), (0, 10.5, POD + 2.6, "tall"),
             (0, -10.5, POD + 13.2, "win"), (0, 10.5, POD + 13.2, "win"),
             (1, -5.0, POD + 13.2, "win"), (1, 5.0, POD + 13.2, "win"), (3, -5.0, POD + 13.2, "win"),
             (3, 5.0, POD + 13.2, "win"), (2, 0.0, POD + 3.0, "tall"), (2, -8.0, POD + 13.2, "win"),
             (2, 8.0, POD + 13.2, "win")]
    volume(b, k, rng, W, D, POD, zm, specs, quoin=False, faces=())
    face_blocks(b, k, rng, W, D, POD, zm, specs, extra_holes={0: [(-4.6, 4.6, POD, POD + 19.0)]})
    string_course(b, k, W, D, POD + 11.6)
    # purple + ivory frieze under the parapet
    string_course(b, k, W, D, zm - 1.6, proj=0.3, h=0.45, color=kc(k, "accent"))
    string_course(b, k, W, D, zm - 1.15, proj=0.36, h=0.4, color=kc(k, "trim"))
    crown_rect(b, k, rng, W, D, zm, "stepped", merlon_h=3.6, corbels=False, skip_corners=4.0)
    big_banners(b, k, D, (-5.6, 5.6), POD + 11.4, 10.0, 3.4)
    # round corner towers, gallery ring and onion domes
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * W / 2, sy * D / 2
            r = 4.3
            zt = round_turret(b, k, rng, x, y, r, POD, zm + 9.0, hidden_to=zm)
            b.add(cc.annulus(r - 0.3, r + 0.6, zt, zt + 0.8, 12, kc(k, "accent")).move(x, y, 0))
            for i in range(4):  # four broad piers of the open belvedere (chunky, not slender posts)
                th = 2 * math.pi * (i + 0.5) / 4
                px, py = rotate_xy(0, -(r - 0.8), th)
                b.add(box(1.5, 1.5, 3.4, kc(k, "stone_light")).rotate(th, "Z").move(x + px, y + py, zt + 0.8))
            b.add(cylinder(r - 1.0, r - 1.0, 3.4, 8, "window_dark").move(x, y, zt + 0.8))
            b.add(cc.annulus(r - 0.4, r + 0.5, zt + 4.2, zt + 4.9, 12, kc(k, "stone_light")).move(x, y, 0))
            pcs, apex = cc.dome(k, r * 0.92, r * 2.0, onion=True, seg=10, fin="simple", ribs=False, collar=False)
            b.add(cc.place(pcs, 0, x, y, zt + 4.9), tag="roof")
    # great drum with arched windows and a gallery, onion dome with a sun finial
    Rd = 8.4
    cy = 1.0
    zd0, zd1 = zm - 0.3, zm + 13.0
    holes = []
    wins = []
    for i in range(6):
        th = 2 * math.pi * i / 6
        wins.append(th)
        holes.append((th, 2.0 / Rd, zd0 + 4.0, zd0 + 10.0))
    b.add(cylinder(Rd, Rd, zd1 - zd0, 16, kc(k, "stone_dark")).move(0, cy, zd0))
    b.add(cc.place(cc.ashlar_ring(k, rng, Rd, zd0, zd1, seg_len=5.8, course=3.3, holes=holes), 0, 0, cy, 0))
    for th in wins:
        b.add(cc.place(cc.on_ring(cc.stone_window(k, 2.4, 5.0), th, Rd + 0.12, zd0 + 4.4), 0, 0, cy, 0))
        b.stats["windows"] += 1
    b.add(cc.annulus(Rd - 0.3, Rd + 0.5, zd1 - 0.1, zd1 + 0.5, 16, kc(k, "accent")).move(0, cy, 0))
    b.add(cc.annulus(Rd - 0.6, Rd + 0.15, zd1 + 0.5, zd1 + 1.4, 16, "gold_dark").move(0, cy, 0))
    pcs, apex = cc.dome(k, Rd, 18.0, onion=True, seg=16)
    b.add(cc.place(pcs, 0, 0, cy, zd1 + 1.4), tag="roof")
    # two chunky crenellated back towers (square, squat, gold half-dome caps): the gold kingdom's
    # identity is big domes on chunky drums, never slim ringed shafts
    for sx in (-1, 1):
        x, y = sx * 10.5, D / 2 - 1.5
        h = 4.2
        zt = zm + 8.5
        b.add(cc.ybox(x - h, x + h, y - h, y + h, POD, zt, kc(k, "stone_dark")))
        for f in (1, 2, 3):  # outward faces (back, sides); the front face is buried in the hall
            th = f * math.pi / 2
            z_start = zm if (f == 3 and sx > 0) or (f == 1 and sx < 0) else POD
            bl = cc.ashlar_plane(k, rng, -h, h, z_start, zt, course=3.2, blen=(3.6, 5.6), end_gap=False)
            b.add([q.move(0, -h, 0).rotate(th, "Z").move(x, y, 0) for q in bl])
        b.add(cc.ybox(x - h - 0.5, x + h + 0.5, y - h - 0.5, y + h + 0.5, zt - 0.1, zt + 0.5, kc(k, "stone_light")))
        for f in range(4):
            th = f * math.pi / 2
            for u in (-2.2, 2.2):
                ox, oy = rotate_xy(u, -h + 0.1, th)
                b.add(cc.place(cc.merlon("stepped", k, w=2.0, h=2.6, t=0.9), th, x + ox, y + oy, zt + 0.5))
                b.stats["merlons"] = b.stats.get("merlons", 0) + 1
        b.add(cc.ybox(x - 2.6, x + 2.6, y - 2.6, y + 2.6, zt + 0.5, zt + 2.1, kc(k, "stone_light")))
        pcs2, _ = cc.dome(k, 3.0, 3.0, onion=False, seg=10, fin="simple", ribs=False, collar=False)
        b.add(cc.place(pcs2, 0, x, y, zt + 2.1), tag="roof")
        b.stats["turrets"] = b.stats.get("turrets", 0) + 1
    return door, balc, (0, cy, zd1 + 1.4 + apex)


# ------------------------------------------------------------------ build

def build(b, p):
    rng = b.rng
    k = p["kingdom"]
    b.stats["windows"] = 0
    fn = {"red": keep_red, "blue": keep_blue, "green": keep_green, "yellow": keep_yellow}[k]
    door, balc, flag_at = fn(b, k, rng)
    W, D = {"red": (34.0, 26.0), "blue": (36.0, 26.0), "green": (38.0, 27.0), "yellow": (36.0, 28.0)}[k]
    moss_base(b, rng, W, D)
    pole, ptop = cc.flagpole(k, 8.0, rng, 7.0, 3.8)
    b.add(cc.place(pole, 0, flag_at[0], flag_at[1], flag_at[2] - 0.8))
    b.socket("door", *door)
    b.socket("balcony", *balc)
    b.socket("flag", flag_at[0], flag_at[1], flag_at[2] - 0.8 + ptop)
    b.stats["pieces"] = len(b.pieces)
    b.stats["roof"] = b.count_tag("roof")
