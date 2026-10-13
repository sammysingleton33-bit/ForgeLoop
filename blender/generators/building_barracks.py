"""Barracks: long, low military hall in kingdom stone with quoins and buttresses, either a jettied
timber-framed upper floor or one tall stone hall, kingdom tile roof (always), a projecting stone
entrance bay (crenellated gatehouse `keep` with a flag, or a cross `gable` with a heraldic shield),
a big double door up a flight of steps, kingdom banners flanking the door, spear-and-shield racks,
a dirt parade ground with straw training dummies and an archery butt, and a corner watch turret in
the kingdom's tower language (red spire, blue pyramid, green timber hoarding, yellow onion dome).

Front (door) faces Blender -Y. Sockets: door, spawn (trained units appear), rally (rally point).
"""

import math

from lib import kit
from lib.geo import Vector, bevel, box, prism
from lib.palette import kingdom_color

from generators import _village_large_common as C

NAME = "building_barracks"
VERSION = 2
CATEGORY = "building"
BUDGET = "building_large"
COLLISION = {"fidelity": "PreciseConvexDecomposition"}
CHECKS = {"min_pieces": 150, "min_windows": 8, "min_roof": 6, "min_banners": 2, "min_racks": 2,
          "min_dummies": 1, "min_turrets": 1}
DEFAULT_VARIANTS = 6
HERO_VIEW = {"azimuth": 32, "elevation": 20}

# kingdom, upper floor, entrance bay, turret corner (f/b front/back, l/r -X/+X), dummy side, chimney side, dummies
_TABLE = (
    ("red", "timber", "gable", "br", -1, -1, 2),
    ("blue", "hall", "keep", "fl", 1, 1, 2),
    ("green", "timber", "keep", "bl", 1, 1, 2),
    ("yellow", "hall", "gable", "fr", -1, -1, 2),
    ("red", "hall", "keep", "bl", 1, 1, 1),
    ("blue", "timber", "gable", "fr", -1, -1, 2),
)


def variants(n, seed):
    out = []
    for i in range(n):
        k, upper, bay, tur, yard, chim, dummies = _TABLE[i % len(_TABLE)]
        out.append({"kingdom": k, "upper": upper, "bay": bay, "turret": tur, "yard": yard, "chimney": chim,
                    "dummies": dummies, "seed": seed * 1000 + 300 + i})
    return out


def _posts_around(length, wins, min_gap=1.0):
    """Post positions for a framed wall: both ends plus a post either side of every window."""
    t = kit.TIMBER
    half = length / 2
    off = kit.WIN_W / 2 + 0.42 + t / 2 + 0.04
    ps = [-half + t / 2, half - t / 2]
    for w in wins:
        ps += [w - off, w + off]
    out = []
    for u in sorted(ps):
        if not out or u - out[-1] >= min_gap:
            out.append(u)
    return out


def _braces_for(posts, wins, rng):
    br = []
    for i in range(len(posts) - 1):
        a, b_ = posts[i], posts[i + 1]
        if b_ - a < 1.8 or any(a < w < b_ for w in wins):
            continue
        br.append((i, (i + rng.randint(0, 1)) % 2 == 0))
    return br


def _buttress(h, color):
    """Stepped stone buttress against a wall at y=0 (projecting to -Y), base z=0."""
    prof = [(0.3, 0.0), (-1.5, 0.0), (-1.5, h * 0.45), (-0.95, h * 0.58), (-0.95, h - 1.0), (0.3, h + 0.4)]
    return bevel(prism(prof, 1.3, color, axis="X"), 0.1).paint(grad=("range", 0.2, 0.8))


def _ashlar(b, rng, x0, x1, y, z0, z1, avoid, colors, n=3, normal_sign=-1):
    """A few proud stones on a plain stone wall (hand-made texture), avoiding openings."""
    placed = 0
    for _ in range(n * 8):
        if placed >= n:
            break
        x = rng.uniform(x0 + 1.2, x1 - 1.2)
        z = rng.uniform(z0 + 1.0, z1 - 1.0)
        if any(abs(x - ax) < aw and az0 - 0.8 < z < az1 + 0.8 for ax, aw, az0, az1 in avoid):
            continue
        st = box(rng.uniform(1.3, 2.3), 0.3, rng.uniform(0.75, 1.0), rng.choice(colors))
        b.add(st.move(x, y + normal_sign * 0.1, z))
        placed += 1


def build(b, p):
    rng = b.rng
    k = p["kingdom"]
    hall = p["upper"] == "hall"
    keep = p["bay"] == "keep"
    W = rng.uniform(40.0, 43.0)  # X
    D = rng.uniform(15.2, 16.0)  # Y
    z0 = 1.4
    st = kingdom_color(k, "stone")
    st_d = kingdom_color(k, "stone_dark")
    st_l = kingdom_color(k, "stone_light")
    shutter = kingdom_color(k, "shutter")
    roofc, roofd = kingdom_color(k, "roof"), kingdom_color(k, "roof_dark")
    windows = banners = racks = 0

    BW = 14.4  # entrance bay width
    P = 3.2  # bay projection
    bx = 0.0
    yf = -D / 2
    ybf = yf - P
    if hall:
        Hs = rng.uniform(13.0, 13.6)
        h2 = 0.0
        top = z0 + Hs
        jetty = 0.0
    else:
        Hs = rng.uniform(10.2, 10.6)
        h2 = rng.uniform(8.2, 8.6)
        jetty = 0.8
        top = z0 + Hs + 0.7 + h2
    Wr, Dr = W + 2 * jetty, D + 2 * jetty
    Ls = (W - BW) / 2  # length of each front wall segment beside the bay
    tur = p["turret"]
    tsx = -1 if tur[1] == "l" else 1
    tsy = -1 if tur[0] == "f" else 1
    pitch = rng.uniform(44, 48)
    rise = Dr / 2 * math.tan(math.radians(pitch))

    # --- plinth (main block + bay)
    e = 0.35
    bay_back = yf + (5.0 if keep else 1.0)
    pts = [(-W / 2 - e, yf - e, 0), (bx - BW / 2 - e, yf - e, 0), (bx - BW / 2 - e, ybf - e, 0),
           (bx + BW / 2 + e, ybf - e, 0), (bx + BW / 2 + e, yf - e, 0), (W / 2 + e, yf - e, 0),
           (W / 2 + e, D / 2 + e, 0), (-W / 2 - e, D / 2 + e, 0), (-W / 2 - e, yf - e, 0)]
    b.add(kit.stone_course(pts, z0, 1.0, st_d, rng, block=(4.2, 6.4), bev=0.12, colors=(st_d, "stone_dark", st_d)))
    b.add(box(W, D, z0, "stone_dark"))
    b.add(box(BW, P + 1.0, z0, "stone_dark").move(bx, ybf + (P + 1.0) / 2, 0))

    # --- stone ground floor / tall hall
    b.add(kit.bbox(W, D, Hs, st, 0.22).move(0, 0, z0).paint(grad=("range", 0.2, 0.8)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            if (sx, sy) != (tsx, tsy):
                b.add(C.quoins(sx * W / 2, sy * D / 2, sx, sy, z0, Hs - 0.6, st_l))
    b.add(kit.bbox(W + 0.5, D + 0.5, 0.55, st_d, 0.12).move(0, 0, z0 + Hs - 0.55))

    # --- entrance bay
    Hb = top - z0 + (3.4 if keep else 0.0)
    bd = bay_back - ybf
    b.add(kit.bbox(BW, bd, Hb, st, 0.22).move(bx, ybf + bd / 2, z0).paint(grad=("range", 0.2, 0.85)))
    for sx in (-1, 1):
        b.add(C.quoins(bx + sx * BW / 2, ybf, sx, -1, z0, Hb - 0.6, st_l))
    if not hall:
        b.add(kit.bbox(BW + 0.4, P + 1.4, 0.45, st_d, 0.1).move(bx, ybf + (P + 1.0) / 2, z0 + Hs - 0.45))
    if keep:
        zt = z0 + Hb
        # corbelled band, parapet wall, merlons on front and sides, a flag on a pole
        b.add(kit.bbox(BW + 1.0, bd + 0.6, 0.8, st_d, 0.15).move(bx, ybf + bd / 2 - 0.3, zt - 0.8))
        for i in range(9):
            u = bx - BW / 2 + 0.9 + (BW - 1.8) * i / 8
            b.add(box(0.7, 0.8, 0.9, st_d).move(u, ybf - 0.2, zt - 1.7))
        b.add(kit.bbox(BW + 1.0, 1.0, 1.0, st, 0.12).move(bx, ybf - 0.3, zt))
        for sx in (-1, 1):
            b.add(kit.bbox(1.0, bd - 1.0, 1.0, st, 0.12).move(bx + sx * (BW / 2 + 0.0), ybf + bd / 2 + 0.2, zt))
        b.add([pc.move(bx, ybf - 0.3, zt + 1.0) for pc in kit.crenellations(BW + 0.8, 1.0, 2.2, 2.2, 1.6, st, "x", rng)])
        for sx in (-1, 1):
            for pc in kit.crenellations(bd - 2.0, 1.0, 2.2, 2.2, 1.6, st, "y", rng):
                b.add(pc.move(bx + sx * BW / 2, ybf + bd / 2 - 0.3, zt + 1.0))
        b.add(box(BW - 0.4, bd - 0.6, 0.3, "slate_dark").move(bx, ybf + bd / 2, zt - 0.1))
        for pc in C.flag(k, 6.4, 3.8, 11.0):
            b.add(pc.move(bx - 0.6, ybf + 2.4, zt))

    # door (double, arched) up a flight of steps
    dw, dh = 5.8, 8.6
    for pc in kit.door(dw, dh, "wood_dark", st_l, step=None):
        b.add(pc.move(bx, ybf, z0))
    # double-door read: iron centre seam and a ring handle on each leaf
    b.add(box(0.26, 0.16, dh - dw / 2 + 2.5, "iron_dark").move(bx, ybf - 0.42, z0 + 0.1))
    for sx in (-1, 1):
        b.add(box(0.34, 0.2, 0.34, "iron").move(bx + sx * 0.7, ybf - 0.5, z0 + dh * 0.42))
    for sx in (-1, 1):
        for zz in (0.5, dh * 0.3, dh * 0.55):  # strap hinges
            b.add(box(1.2, 0.14, 0.26, "iron_dark").move(bx + sx * (dw / 2 - 0.7), ybf - 0.4, z0 + zz))
    b.add([pc.move(bx, ybf, 0) for pc in C.stairs(dw + 2.6, z0, 3, 1.1, "stone", rng)])
    b.socket("door", bx, ybf - 3.8, 0)
    b.socket("spawn", bx, ybf - 6.5, 0)
    b.socket("rally", bx, ybf - 17.0, 0)

    # kingdom banners flanking the door
    bt = min(top - 1.6, z0 + 13.0)
    bh = bt - (z0 + 3.4)
    for sx in (-1, 1):
        for pc in C.banner(k, 2.4, bh, tail="swallow"):
            b.add(pc.move(bx + sx * (BW / 2 - 1.85), ybf, bt))
        banners += 1

    # above the door: heraldic shield (hall / keep) and an upper window (timber)
    if hall or keep:
        for pc in C.heater_shield(k, 3.0, 3.7):
            b.add(pc.move(bx, ybf, z0 + dh + 2.9))
    if not hall:
        zw = z0 + Hs + 0.7 + 2.4
        if keep:
            for sx in (-1, 1):
                b.add(box(0.6, 0.3, 2.4, "window_dark").move(bx + sx * 2.6, ybf - 0.1, zw + 0.8))
                b.add(kit.bbox(1.1, 0.5, 0.4, st_l, 0.08).move(bx + sx * 2.6, ybf - 0.15, zw + 3.2))
        else:
            for pc in kit.window(kit.WIN_W, kit.WIN_H, "timber", shutter):
                b.add(pc.move(bx, ybf, zw))
            windows += 1

    # --- front wall segments: windows, buttress, weapon rack, upper framing
    for side in (-1, 1):
        edge = bx + side * BW / 2  # bay edge
        end_cut = 4.2 if (tsy == -1 and tsx == side) else 2.4
        eff = Ls - 1.0 - end_cut
        ds = [1.0 + eff * 0.22, 1.0 + eff * 0.78]
        xs = [edge + side * d for d in ds]
        avoid = []
        for wx in xs:
            if hall:
                for pc in kit.window(2.2, 5.6, "timber", None, arched=True):
                    b.add(pc.move(wx, yf, z0 + 3.4))
                avoid.append((wx, 2.2, z0 + 3.0, z0 + 9.4))
            else:
                for pc in kit.window(2.4, 3.4, "timber", None, arched=True):
                    b.add(pc.move(wx, yf, z0 + 3.6))
                avoid.append((wx, 2.2, z0 + 3.2, z0 + 7.4))
            windows += 1
        bxp = (xs[0] + xs[1]) / 2
        b.add(_buttress(Hs - (2.2 if hall else 1.6), st_d).move(bxp, yf, z0))
        avoid.append((bxp, 1.8, 0, 99))
        lo, hi = sorted((edge, edge + side * (Ls - end_cut + 1.0)))
        _ashlar(b, rng, lo, hi, yf, z0, z0 + Hs - 0.8, avoid, (st_l, st_d), n=3)
        for pc in C.weapon_rack(k, rng, 5.2, spears=5, shields=2):
            b.add(pc.move(xs[0], yf - 2.4, 0))
        racks += 1
        if not hall:  # timber upper floor: framing + one shuttered window per segment
            seg_len = Wr / 2 - BW / 2
            cx = side * (BW / 2 + seg_len / 2)
            uw = [side * (ds[0] + ds[1]) / 2 + edge - cx]
            zz = z0 + Hs + 0.7
            posts = _posts_around(seg_len, uw)
            fr = C.frame_wall(seg_len, h2, "x", -Dr / 2, posts, _braces_for(posts, uw, rng), rng=rng)
            b.add([f.move(cx, 0, zz) for f in fr])
            for pc in kit.window(kit.WIN_W, kit.WIN_H, "timber", shutter):
                b.add(pc.move(cx + uw[0], -Dr / 2, zz + 2.3))
            windows += 1

    # --- timber upper floor
    if not hall:
        zz = z0 + Hs
        b.add(kit.bbox(Wr + 0.4, Dr + 0.4, 0.7, "timber", 0.1).move(0, 0, zz))
        for i in range(13):  # joist ends under the jetty
            u = -W / 2 + 0.6 + (W - 1.2) * i / 12
            if abs(u - bx) < BW / 2 + 0.4:
                continue
            b.add(box(0.6, jetty + 0.4, 0.6, "timber").move(u, yf - jetty / 2, zz - 0.55))
        zz += 0.7
        plaster = rng.choice(("plaster", "plaster", "plaster_white"))
        b.add(kit.bbox(Wr, Dr, h2, plaster, 0.18).move(0, 0, zz).paint(grad=("range", 0.4, 0.85)))
        bw = [-Wr * 0.3, 0.0, Wr * 0.3]
        posts = _posts_around(Wr, bw)
        b.add([f.move(0, 0, zz) for f in C.frame_wall(Wr, h2, "x", Dr / 2, posts, _braces_for(posts, bw, rng), rng=rng)])
        for wx in bw:
            for pc in kit.window(kit.WIN_W, kit.WIN_H, "timber", None, mullion=False):
                b.add(pc.rotate(math.pi, "Z").move(wx, Dr / 2, zz + 2.3))
            windows += 1
        for sx in (-1, 1):
            sw = [0.0]
            posts = _posts_around(Dr, sw)
            b.add([f.move(0, 0, zz) for f in C.frame_wall(Dr, h2, "y", sx * Wr / 2, posts,
                                                         _braces_for(posts, sw, rng), rng=rng)])
            for pc in kit.window(kit.WIN_W, kit.WIN_H, "timber", shutter):
                b.add(pc.rotate(sx * math.pi / 2, "Z").move(sx * Wr / 2, 0, zz + 2.3))
            windows += 1

    # back + gable-end windows on the stone storey
    for wx in (-W * 0.3, W * 0.3) if hall else (-W * 0.3, 0.0, W * 0.3):
        for pc in kit.window(2.2 if hall else 2.4, 5.6 if hall else 3.4, "timber", None, arched=True, mullion=False):
            b.add(pc.rotate(math.pi, "Z").move(wx, D / 2, z0 + (3.4 if hall else 3.6)))
        windows += 1
    for sx in (-1, 1):
        for pc in kit.window(2.2, 5.0 if hall else 3.4, "timber", None, arched=True):
            b.add(pc.rotate(sx * math.pi / 2, "Z").move(sx * W / 2, -D * 0.12, z0 + 3.6))
        windows += 1
    if hall:  # back buttresses
        for u in (-W * 0.15, W * 0.15, -W * 0.45, W * 0.45):
            if tsy == 1 and u * tsx > W * 0.3:
                continue
            b.add(_buttress(Hs - 2.2, st_d).rotate(math.pi, "Z").move(u, D / 2, z0))

    # --- main roof (ridge along X), kingdom tiles
    roof, rise = kit.gable_roof(Dr, Wr, pitch, overhang=1.5, gable_overhang=1.1, thickness=0.8, color=roofc,
                                rows=6, ridge_color=roofd, style="tile", rng=rng)
    for pc in roof:
        b.add(pc.rotate(math.pi / 2, "Z").move(0, 0, top), tag="roof")
    for sx in (-1, 1):
        g = kit.gable_end(Dr, rise, 0.8, st if hall else "plaster")
        b.add(g.rotate(math.pi / 2, "Z").move(sx * (Wr / 2 - 0.4), 0, top).paint(grad=("range", 0.5, 0.85)))
        xg = sx * (Wr / 2 + 0.1)
        n = Vector((sx, 0, 0))
        if hall:
            for pc in C.oculus(1.5, st_l):
                b.add(pc.rotate(sx * math.pi / 2, "Z").move(xg - sx * 0.05, 0, top + rise * 0.38))
        else:
            b.add(kit.oriented_box((xg, -Dr / 2 + 0.5, top + 0.35), (xg, Dr / 2 - 0.5, top + 0.35), kit.TIMBER, 0.4,
                                   "timber", n))
            b.add(kit.oriented_box((xg, 0, top + 0.6), (xg, 0, top + rise - 0.8), kit.TIMBER, 0.4, "timber", n))
            for s in (-1, 1):
                b.add(kit.oriented_box((xg, s * Dr * 0.36, top + 0.6), (xg, s * 0.4, top + rise * 0.62),
                                       kit.TIMBER * 0.8, 0.4, "timber", n))

    # --- cross gable over the entrance bay (ridge along Y)
    if not keep:
        b.add(kit.bbox(BW + 0.5, P + 1.5, 0.55, st_d, 0.12).move(bx, ybf + (P + 1.0) / 2, top - 0.55))
        Lb = P + D / 2 + jetty
        yc = ybf + Lb / 2
        broof, brise = kit.gable_roof(BW, Lb, pitch, overhang=1.2, gable_overhang=1.0, thickness=0.75, color=roofc,
                                      rows=4, ridge_color=roofd, style="tile", rng=rng)
        for pc in broof:
            b.add(pc.move(bx, yc, top), tag="roof")
        b.add(kit.gable_end(BW, brise, 0.8, st).move(bx, ybf + 0.4, top).paint(grad=("range", 0.4, 0.85)))
        if hall:
            for pc in C.oculus(1.3, st_l):
                b.add(pc.move(bx, ybf, top + brise * 0.36))
        else:
            for pc in C.heater_shield(k, 2.8, 3.5):
                b.add(pc.move(bx, ybf, top + brise * 0.36))

    # --- chimney on the back slope
    cx = p["chimney"] * (W / 2 - 5.5)
    ch_h = top + rise * 0.8 + 2.6 - z0
    b.add([pc.move(cx, D * 0.2, z0) for pc in kit.chimney(ch_h, 2.6, "stone", "stone_dark")])

    # --- watch turret on one corner, rising well above the ridge
    th = top + rise * 0.95
    tx, ty = tsx * (W / 2 - 0.2), tsy * (D / 2 - 0.2)
    for pc in C.turret(k, rng, 3.0, th, st, st_d):
        b.add(pc.move(tx, ty, 0))
    b.stats["turrets"] = 1

    # --- parade ground in front: dummies on one side, archery butt on the other
    ys = p["yard"]
    y_front = ybf - 10.5
    pc_ = C.pad(W / 2 - 0.8, (yf - 1.0 - y_front) / 2, 22, rng, color="road")
    b.add(pc_.move(0, (yf - 1.0 + y_front) / 2, 0))
    nd = p["dummies"]
    for j in range(nd):
        for pc in C.dummy(rng, k):
            b.add(pc.rotate(rng.uniform(-0.5, 0.5), "Z").move(ys * (BW / 2 + 3.4 + j * 5.2), ybf - 6.2 - j * 0.8, 0))
    b.stats["dummies"] = nd
    tx_ = -ys * (BW / 2 + 6.0)
    for pc in C.archery_target(rng, k):
        b.add(pc.rotate(-ys * 0.2, "Z").move(tx_, ybf - 6.4, 0))
    b.add([pc.move(tx_ - ys * 3.4, ybf - 5.0, 0) for pc in C.barrel(0.8, 2.0, "wood")])
    for j in range(4):  # arrows in the barrel
        b.add(box(0.1, 0.1, 1.6, "wood_pale").rotate(rng.uniform(-0.25, 0.25), "X")
              .move(tx_ - ys * 3.4 + rng.uniform(-0.4, 0.4), ybf - 5.0 + rng.uniform(-0.4, 0.4), 1.8))

    b.stats["windows"] = windows
    b.stats["banners"] = banners
    b.stats["racks"] = racks
    b.stats["pieces"] = len(b.pieces)
    b.stats["roof"] = b.count_tag("roof")
