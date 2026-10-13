"""Castle curtain wall: a straight 32-stud module along X (ends flush at x = +-16 so modules tile),
wall-walk at z = 24 (6.3 studs usable between the parapets), battered base, ashlar courses on
both faces, outer parapet in the kingdom's language, arrow slits, moss at the foot.

Front (field side) faces -Y. Pivot = base centre = wall centreline: every variant has the same
two-step foundation apron (y = +-8.4) so modules of different variants line up on one axis.

The KINGDOM sets the cross-section (identical at both module ends, so a kingdom's variants tile):
  red     machicolated parapet on a corbel table, swallowtail (Ghibelline) merlons
  blue    crisp merlons, each capped by a small slate pyramid (the Frostmere pyramid language)
  green   timber hoarding: a roofed wooden fighting gallery projecting over the field
  yellow  massive sandstone talus, tall stepped (Moorish) merlons, purple/ivory frieze
The VARIANT adds features between the ends:
  _01 'curtain'  arrow-slit gallery, central banner; red/yellow add a corner turret (red cone /
                 gold onion), green adds two gabled dormers that break the hoarding roofline
  _02 'bastion'  buttresses, a corbelled bartizan in the kingdom roof language, banners and an
                 inner stair from the courtyard to the walk (gameplay access)
"""

import math

from lib import kit
from lib.geo import box, cylinder, lathe, prism
from generators import _castle_common as cc
from generators._castle_common import kc

NAME = "castle_wall"
VERSION = 1
CATEGORY = "castle"
BUDGET = "castle_wall"
COLLISION = {"fidelity": "PreciseConvexDecomposition"}
CHECKS = {"min_pieces": 90, "min_merlons": 6, "min_slits": 2}
DEFAULT_VARIANTS = 8
LINEUP_GAP = 3.0
HERO_VIEW = {"azimuth": 32, "elevation": 16}

HALF = cc.MODULE / 2  # 16
WALK = cc.WALK_Z  # 24
YO, YI = -cc.WALL_T / 2, cc.WALL_T / 2  # outer / inner face of the wall body (-4.2 / 4.2)
PAR_IN = -2.9  # walk-side face of the outer parapet
RAIL_IN = 3.4  # walk-side face of the inner rail
APRON = 8.4  # half-depth of the foundation apron (= the asset's Y bounds)
LIM = 8.35  # nothing else may pass this (keeps the pivot on the wall axis)

PROFILE = {"red": "mach", "blue": "caps", "green": "hoarding", "yellow": "talus"}
MERLONS = {"red": ("swallow", 7, 3.0), "blue": ("pyramid", 7, 3.0), "green": ("square", 7, 1.0),
           "yellow": ("stepped", 8, 4.0)}
KINDS = ("curtain", "bastion")


def variants(n, seed):
    out = []
    for i in range(n):
        k = cc.KINGDOMS[(i // 2) % 4]
        kind = KINDS[i % 2]
        out.append({"kingdom": k, "kind": kind, "profile": PROFILE[k], "seed": seed * 1000 + 500 + i})
    return out


def asset_id(i, params):
    return f"castle_wall_{params['kingdom']}_{i % 2 + 1:02d}"


# ------------------------------------------------------------------ parts

def moss_strip(b, rng, n, y, zs=(0.6, 1.4)):
    for _ in range(n):
        r = rng.uniform(0.9, 1.3)
        m = lathe([(0.0, 0.0), (r, 0.0), (r * 0.9, 0.4 * r), (r * 0.5, 0.75 * r), (0.0, 0.9 * r)], 5, "moss")
        m.scale(rng.uniform(1.8, 2.6), rng.uniform(0.9, 1.2), rng.uniform(0.8, 1.1))
        x = rng.uniform(-HALF + 3.5, HALF - 3.5)
        m.move(x, y, rng.uniform(*zs))
        maxy = max(v.y for v in m.verts)
        if maxy > LIM:
            m.move(0, LIM - maxy, 0)
        b.add(clamp_front([m])[0].paint(grad=("range", 0.15, 0.9), smooth=True))


def buttress(b, k, rng, x, w=3.2, proj=3.4):
    """Two-stage stepped buttress on the outer face (projecting towards -Y) with sloped weatherings;
    courses wrap its corners so it reads as masonry from the front and the sides."""
    sd, st, sl = kc(k, "stone_dark"), kc(k, "stone"), kc(k, "stone_light")
    p2 = proj * 0.55
    poly = [(YO + 0.5, 0.0), (YO - proj, 0.0), (YO - proj, 12.5), (YO - p2, 14.6), (YO - p2, 19.0),
            (YO + 0.2, 21.2), (YO + 0.5, 21.2)]
    b.add(cc.profile_x(poly, x - w / 2, x + w / 2, st).paint(grad=("range", 0.25, 0.8)))
    courses = [(0.6, 3.1), (3.1, 5.6), (5.6, 8.1), (8.1, 10.4), (10.4, 12.4), (14.6, 16.8), (16.8, 18.9)]
    for j, (za, zb) in enumerate(courses):
        pr = proj if za < 12.5 else p2
        ww = w + (0.3 if j % 2 == 0 else 0.12)
        b.add(cc.ybox(x - ww / 2, x + ww / 2, YO - pr - (0.14 if j % 2 == 0 else 0.06), YO, za + 0.08, zb - 0.08,
                      cc.pick(rng, (st, sl, sd), (0.45, 0.4, 0.15))).paint(grad=("range", 0.2 + 0.04 * j, 0.7 + 0.03 * j)))
    for (y0, z0, y1, z1) in ((YO - proj, 12.5, YO - p2, 14.6), (YO - p2, 19.0, YO + 0.2, 21.2)):
        b.add(kit.oriented_box((x, y0 - 0.15, z0 - 0.1), (x, y1 - 0.05, z1 - 0.1), w + 0.35, 0.45, sl,
                               normal=(0, -0.7, 0.7)))


def clamp_front(pieces):
    """Shift a group of pieces towards +Y so nothing passes -LIM (keeps the bounds symmetric)."""
    miny = min(v.y for p in pieces for v in p.verts)
    if miny < -LIM:
        for p in pieces:
            p.move(0, -LIM - miny, 0)
    return pieces


def merlon_xs(n):
    pitch = cc.MODULE / n
    return [-HALF + pitch * (i + 0.5) for i in range(n)], pitch


def bartizan(b, k, rng, x, z_base, z_top, big=False):
    """Corbelled sentry turret on the outer parapet, roofed in the kingdom language; built at the
    outer face and pulled in so nothing passes LIM (symmetric bounds)."""
    sd, st, sl = kc(k, "stone_dark"), kc(k, "stone"), kc(k, "stone_light")
    out, roof = [], []
    if k == "blue":
        h = 2.4 if big else 1.85
        out.append(cc.square_lathe([(0.35, z_base - 2.8), (h, z_base), (h, z_top)], sd))
        zz = z_base + 0.2
        while zz < z_top - 1.0:
            out.append(cc.square_lathe([(h + 0.12, zz), (h + 0.12, min(zz + 2.5, z_top - 0.2))], st)
                       .paint(grad=("range", 0.4, 0.9)))
            zz += 2.7
        out.append(cc.square_lathe([(h + 0.35, z_top - 0.1), (h + 0.35, z_top + 0.45)], sl))
        roof, apex = cc.pyramid(k, h + 0.1, 9.0 if big else 7.2, overhang=0.55, rows=1, flare=True)
        r_slit = h + 0.12
    else:
        r = 2.1 if k == "red" else 2.9  # gold: a chunky drum, never a slim ringed shaft
        seg = 10
        out.append(lathe([(0.3, z_base - 3.2), (r * 0.6, z_base - 1.2), (r, z_base), (r, z_top)], seg, st)
                   .paint(grad=("range", 0.3, 0.9)))
        if k == "red":
            zz = (z_base + z_top) / 2
            out.append(cc.annulus(r - 0.2, r + 0.18, zz, zz + 0.45, seg, sl))
        out.append(cc.annulus(r - 0.3, r + 0.4, z_top - 0.1, z_top + 0.45, seg, sl))
        if k == "red":
            roof, apex = cc.spire(k, r, 9.0, seg=8, overhang=0.45, rows=1)
        else:
            roof, apex = cc.dome(k, r * 0.92, 5.4, onion=True, seg=10, fin="simple", ribs=False)
        r_slit = r + 0.05
    for q in roof:
        out.append(q.move(0, 0, z_top + 0.45).paint(tag="roof"))
    for th in (-0.75, 0.75):
        out.append(cc.on_ring([box(0.4, 0.3, 1.8, "window_dark")], th, r_slit, z_top - 3.0)[0])
    for q in out:
        q.move(x, YO - 4.0, 0)
    b.add(clamp_front(out))
    b.stats["turrets"] = 1


def stair(b, k, rng):
    """Inner stair (courtyard -> walk) along the inner face: solid masonry flight with 20 steps (1.2 rise),
    landing at walk level, low sloped parapet. Returns (bottom, top) socket points."""
    st, sd, sl = kc(k, "stone"), kc(k, "stone_dark"), kc(k, "stone_light")
    y0, y1 = YI, YI + 4.0
    n = 20
    rise = WALK / n
    run = 1.0
    x_top = -5.0
    x_bot = x_top + n * run  # 15.0
    land = -10.0
    poly = [(x_bot + 0.4, 0.0), (land, 0.0), (land, WALK - 0.4), (x_top, WALK - 0.4)]
    b.add(prism(poly, y1 - y0, st, axis="Y").move(0, (y0 + y1) / 2, 0).paint(grad=("range", 0.25, 0.8)))
    for i in range(n):
        x1 = x_bot - i * run
        step = box(run + 0.25, y1 - y0 - 0.25, rise + 0.02, sl if i % 2 else st)
        b.add(step.move(x1 - run / 2, (y0 + y1) / 2 - 0.12, i * rise).paint(grad=("range", 0.4, 0.9)))
    b.add(cc.ybox(land, x_top, y0, y1, WALK - 0.4, WALK, "cobble").paint(grad=0.55))
    b.add(kit.oriented_box((x_bot - 0.6, y1 - 0.35, 0.6), (x_top, y1 - 0.35, WALK - 0.4), 0.7, 2.2, sl,
                           normal=(0, 0, 1)).move(0, 0, 1.1))
    b.add(cc.ybox(land, x_top + 0.4, y1 - 0.7, y1, WALK, WALK + 2.4, sl))
    for u, zz in ((-7.5, 6.0), (-2.0, 12.5), (6.0, 1.0)):
        b.add(cc.ybox(u - 1.5, u + 1.5, y1 - 0.2, y1 + 0.14, zz, zz + 2.2, cc.pick(rng, (st, sl, sd))))
    b.stats["stair_steps"] = n
    return (x_bot + 1.8, (y0 + y1) / 2, 0.0), ((land + x_top) / 2, (y0 + y1) / 2, WALK)


def hoarding_gallery(b, k, rng, dormers=False):
    """Green: continuous timber hoarding at walk level, projecting 1.6 over the field, under a low
    moss-green roof that runs flush to the module ends (modules continue the roof)."""
    tim, wd = "timber", kc(k, "wood")
    yo = YO - 1.6
    z0, z1 = WALK - 0.8, WALK + 5.0
    for i in range(8):
        x = -HALF + 2.0 + i * 4.0
        b.add(cc.ybox(x - 0.32, x + 0.32, yo - 0.5, PAR_IN, WALK - 1.4, WALK - 0.7, tim))
        b.add(kit.oriented_box((x, YO + 0.05, WALK - 5.4), (x, yo - 0.2, WALK - 1.3), 0.48, 0.48, tim, normal=(1, 0, 0)))
        b.add(cc.ybox(x - 0.3, x + 0.3, yo - 0.25, yo + 0.3, z0 - 0.2, z1 + 0.1, tim))
        lx = x + 2.0 if i < 7 else x - 1.0
        b.add(cc.ybox(lx - 0.25, lx + 0.25, yo - 0.12, yo, WALK + 1.4, WALK + 3.0, "black"))
    b.add(cc.ybox(-HALF, HALF, yo, YO + 0.2, WALK - 0.7, WALK, "wood_dark"))  # gallery floor
    b.add(cc.ybox(-HALF, HALF, yo, yo + 0.4, z0, z1, wd).paint(grad=("range", 0.3, 0.9)))
    for zz in (z0 + 0.1, z1 - 0.55):
        b.add(cc.ybox(-HALF, HALF, yo - 0.3, yo, zz, zz + 0.45, tim))
    span = (YI + 0.3) - yo
    roof, rise = kit.gable_roof(span, cc.MODULE, 30.0, overhang=1.0, gable_overhang=0.0, thickness=0.6,
                                color=kc(k, "roof"), rows=2, ridge_color=kc(k, "roof_dark"), style="tile", trim=None,
                                sag=0.0)
    roof = roof[:-1]  # the kit ridge cap overhangs the module ends; replaced by an exact one
    ymid = (YI + 0.3 + yo) / 2
    for q in roof:
        b.add(q.rotate(math.pi / 2, "Z").move(0, ymid, z1), tag="roof")
    cap = box(cc.MODULE, 0.96, 0.96, kc(k, "roof_dark"), base=False).rotate(math.radians(45), "X")
    b.add(cap.move(0, ymid, z1 + rise + 0.27), tag="roof")
    for i in range(4):
        x = -HALF + 4.0 + i * 8.0
        b.add(cc.ybox(x - 0.3, x + 0.3, RAIL_IN - 0.2, RAIL_IN + 0.4, WALK + 2.4, z1 + 0.2, tim))
    b.add(cc.ybox(-HALF, HALF, RAIL_IN - 0.25, RAIL_IN + 0.45, z1 - 0.45, z1 + 0.1, tim))
    if dormers:  # two gabled dormers break the long roofline
        for x in (-8.0, 8.0):
            b.add([q.move(x, yo + 0.5, z1 + 0.15) for q in cc.dormer(k, 2.8, 2.6, 4.2)], tag="roof")
    b.stats["hoarding"] = 1
    return z1 + rise


def breteche(b, k, x):
    """Green bastion: a timber turret bulging out of the hoarding, with its own low cone."""
    tim, wd = "timber", kc(k, "wood")
    rh = 2.4
    roof, apex = cc.low_cone(k, rh, 2.8, seg=8, overhang=0.6, rows=1)
    z0, z1 = WALK - 1.2, WALK + 6.6
    out = [cc.poly_lathe([(0.4, z0 - 2.6), (rh - 0.2, z0), (rh - 0.2, z0 + 0.5)], 8, "wood_dark")]
    for i in range(8):
        th = 2 * math.pi * i / 8
        ap = rh * math.cos(math.pi / 8)
        L = 2 * rh * math.sin(math.pi / 8) + 0.1
        out.append(box(L, 0.35, z1 - z0, wd).move(0, -ap, z0).rotate(th + math.pi / 8, "Z")
                   .paint(grad=("range", 0.3, 0.9)))
        out.append(box(0.45, 0.45, z1 - z0 + 0.3, tim).move(0, -rh, z0 - 0.15).rotate(th, "Z"))
        if i in (1, 2, 5, 6):
            out.append(box(0.45, 0.2, 1.5, "black").move(0, -ap - 0.12, WALK + 1.6).rotate(th + math.pi / 8, "Z"))
    for q in roof:
        out.append(q.rotate(math.pi / 8, "Z").move(0, 0, z1).paint(tag="roof"))
    for q in out:
        q.move(x, YO - 4.0, 0)
    b.add(clamp_front(out))
    b.stats["turrets"] = 1


# ------------------------------------------------------------------ build

def build(b, p):
    rng = b.rng
    k = p["kingdom"]
    kind = p["kind"]
    prof = PROFILE[k]
    sd, st, sl = kc(k, "stone_dark"), kc(k, "stone"), kc(k, "stone_light")
    bastion = kind == "bastion"
    mach = prof == "mach"
    talus = prof == "talus"
    y_par = YO - 1.2 if mach else YO  # outer face of the parapet
    z_par0 = WALK - 2.3 if mach else WALK - 0.3
    z_bat = 11.0 if talus else 5.6  # top of the outer batter / talus
    y_bat = -8.0 if talus else -6.3

    # --- foundation apron (two steps; defines the symmetric bounds) and battered core
    b.add(cc.ybox(-HALF, HALF, -APRON, APRON, 0.0, 0.35, sd).paint(grad=("range", 0.05, 0.3)))
    b.add(cc.ybox(-HALF, HALF, -APRON + 1.0, APRON - 1.0, 0.35, 0.7, sd).paint(grad=("range", 0.15, 0.4)))
    core = [(y_bat, 0.0), (6.0, 0.0), (YI, 4.6), (YI, WALK - 0.3), (YO, WALK - 0.3), (YO, z_bat)]
    b.add(cc.profile_x(core, -HALF, HALF, sd).paint(grad=("range", 0.15, 0.55)))

    # --- openings on the outer face
    holes_o = []
    if kind == "curtain":
        xs_s = [-12.0, -5.5, 5.5, 12.0]  # banners hang centred between slits
    else:
        xs_s = {"red": [-14.0, 14.0], "blue": [-13.8, 14.0], "green": [0.8, 8.0], "yellow": [-0.2, 14.0]}[k]
    zs = 14.0 if talus else 12.0
    for x in xs_s:
        b.add([q.move(x, YO - 0.08, zs) for q in cc.arrow_slit(k, 3.4)])
        holes_o.append((x - 1.1, x + 1.1, zs - 0.6, zs + 3.9))
    b.stats["slits"] = len(xs_s)

    # --- buttresses (bastion)
    if bastion:
        bxs = {"red": [-9.0, 9.0], "blue": [-11.0, 0.0, 11.0], "green": [-11.5, 11.5], "yellow": [-10.5, 10.5]}[k]
        for x in bxs:
            narrow = k == "blue"
            buttress(b, k, rng, x, w=2.6 if narrow else 3.2, proj=2.8 if narrow else 3.6)
            holes_o.append((x - 1.9, x + 1.9, 5.0, 21.5))

    # --- outer face masonry: tilted batter/talus courses + ashlar
    nb = 4 if talus else 2
    tilt = math.atan2(-y_bat + YO, z_bat)
    ch = (z_bat - 0.7) / nb
    for ci in range(nb):
        za, zb = 0.7 + ci * ch, 0.7 + (ci + 1) * ch
        zm = (za + zb) / 2
        yface = YO - (z_bat - zm) * ((-y_bat + YO) / z_bat)
        row = cc.ashlar_plane(k, rng, -HALF, HALF, za, zb, course=ch, blen=(4.2, 7.0), shade_t=0.05 + 0.08 * ci,
                              weights=(0.45, 0.25, 0.3))
        for q in row:
            q.move(0, 0, -zm).rotate(-tilt, "X").move(0, yface, zm)
        b.add(row)
    b.add(cc.string_course_x(-HALF, HALF, YO, z_bat - 0.2, sl, proj=0.45, h=0.55))
    z_top_o = z_par0 if mach else WALK - 0.3
    b.add([q.move(0, YO, 0) for q in cc.ashlar_plane(k, rng, -HALF, HALF, z_bat + 0.35, z_top_o, course=2.75,
                                                     blen=(4.3, 7.2), holes=holes_o)])

    # --- inner face masonry (bigger blocks) + string courses
    holes_i = [(-10.2, HALF, 0.0, WALK)] if bastion else []
    row = cc.ashlar_plane(k, rng, -HALF, HALF, 4.6, WALK - 1.0, course=3.1, blen=(4.8, 8.0), holes=holes_i,
                          weights=(0.55, 0.3, 0.15))
    b.add([q.rotate(math.pi, "Z").move(0, YI, 0) for q in row])
    b.add(cc.string_course_x(-HALF, HALF, -YI, 4.2, sl, proj=0.4, h=0.5).rotate(math.pi, "Z"))
    b.add(cc.string_course_x(-HALF, HALF, -YI, WALK - 1.0, sl, proj=0.35, h=0.5).rotate(math.pi, "Z"))

    # --- walk, parapets, rail
    b.add(cc.ybox(-HALF, HALF, PAR_IN - 0.05, RAIL_IN + 0.05, WALK - 0.3, WALK, "cobble").paint(grad=0.55))
    if mach:
        n_c = 8
        for i in range(n_c):
            x = -HALF + cc.MODULE / n_c * (i + 0.5)
            b.add([q.move(x, YO, z_par0 + 0.05) for q in cc.corbel(sl, proj=1.25, w=1.1, h=2.3)])
            if i < n_c - 1:
                b.add(cc.ybox(x + 1.4, x + 2.6, y_par - 0.05, y_par + 0.3, z_par0, z_par0 + 0.75, "black"))
    par_top = WALK + (1.0 if prof == "hoarding" else cc.PARAPET_H)
    b.add(cc.ybox(-HALF, HALF, y_par, PAR_IN, z_par0, par_top, st).paint(grad=("range", 0.4, 0.85)))
    if prof != "hoarding":
        b.add([q.move(0, y_par, 0) for q in cc.ashlar_plane(k, rng, -HALF, HALF, z_par0 + 0.1, par_top - 0.1,
                                                            course=(par_top - z_par0) / (2 if mach else 1),
                                                            blen=(4.4, 7.0), proud=0.16, shade_t=0.75)])
        b.add(cc.ybox(-HALF, HALF, y_par - 0.12, PAR_IN + 0.12, par_top - 0.3, par_top, sl))  # coping
    b.add(cc.ybox(-HALF, HALF, RAIL_IN, YI, WALK, WALK + 2.4, st).paint(grad=("range", 0.4, 0.85)))
    b.add(cc.ybox(-HALF, HALF, RAIL_IN - 0.15, YI + 0.15, WALK + 2.4, WALK + 2.8, sl))
    if talus:  # purple + ivory frieze under the parapet (Sunspire trim)
        b.add(cc.ybox(-HALF, HALF, YO - 0.3, YO + 0.2, WALK - 1.15, WALK - 0.75, kc(k, "trim")))
        b.add(cc.ybox(-HALF, HALF, YO - 0.24, YO + 0.2, WALK - 1.6, WALK - 1.15, kc(k, "accent")))

    # --- merlons (hidden behind the timber gallery for green: the gallery wall is the parapet)
    style, nm, mh = MERLONS[k]
    xs, pitch = merlon_xs(nm)
    gaps = [x + pitch / 2 for x in xs[:-1]]
    if prof != "hoarding":
        for i, x in enumerate(xs):
            t = PAR_IN - y_par
            mw = min(cc.MERLON_W + (0.5 if style == "stepped" else 0.0), pitch - 1.7)
            pcs = cc.merlon(style, k, w=mw, h=mh, t=t, cap=True)
            b.add([q.move(x, (y_par + PAR_IN) / 2, par_top) for q in pcs])
            if i % 2 == 1 and style in ("swallow", "square"):
                b.add(box(0.36, 0.3, 1.5, "window_dark").move(x, y_par - 0.1, par_top + 0.6))
        b.stats["merlons"] = len(xs)
    else:
        b.stats["merlons"] = 8  # loopholed hoarding bays
    z_mtop = par_top + mh

    # --- kingdom crowns
    if prof == "hoarding":
        hoarding_gallery(b, k, rng, dormers=not bastion)

    # --- variant features
    if bastion:
        if k == "green":
            breteche(b, k, 4.0)
        else:
            bx = {"red": 0.0, "blue": -5.5, "yellow": 4.5}[k]
            bartizan(b, k, rng, bx, WALK - 3.4, z_mtop + {"red": 1.8, "blue": 0.2, "yellow": 0.6}[k])
        bot, top = stair(b, k, rng)
        b.socket("stair_bottom", *bot)
        b.socket("stair_top", *top)
        ban = {"red": [-4.6, 4.6], "blue": [5.5], "green": [-4.0], "yellow": [-4.5]}[k]
    else:
        ban = [0.0]
        if k in ("red", "yellow"):  # corner turret carries the kingdom roof shape on the curtain too
            bartizan(b, k, rng, -11.0, WALK - 3.4, z_mtop + (1.8 if k == "red" else 0.6))
        elif k == "blue":  # one strong pyramid-capped turret over the merlon row
            bartizan(b, k, rng, 10.0, WALK - 3.4, z_mtop + 1.0, big=True)
    yb = {"mach": y_par, "caps": YO, "hoarding": YO - 1.6, "talus": YO}[prof]
    zb = {"mach": z_par0 - 0.4, "caps": WALK - 0.6, "hoarding": WALK - 1.6, "talus": WALK - 1.7}[prof]
    for x in ban:
        b.add([q.move(x, yb - 0.02, zb) for q in cc.banner(k, 3.4, 8.4, tail="swallow" if k in ("red", "green")
                                                            else "point")])
    b.stats["banners"] = len(ban)

    # --- moss and weathering at the foot
    moss_strip(b, rng, 3, -6.0 if not talus else -7.2, (0.5, 1.2))
    moss_strip(b, rng, 1, YI + 1.4, (0.65, 1.1))

    # --- sockets (Blender coords; build.py converts)
    b.socket("end_left", -HALF, 0.0, WALK)
    b.socket("end_right", HALF, 0.0, WALK)
    b.socket("walk_center", 0.0, 0.25, WALK)
    for i, gx in enumerate((gaps[0], gaps[len(gaps) // 2], gaps[-1])):
        b.socket(f"archer_{i + 1}", gx, PAR_IN + 0.9, WALK)
    b.stats["pieces"] = len(b.pieces)
