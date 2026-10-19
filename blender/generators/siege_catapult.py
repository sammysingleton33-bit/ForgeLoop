"""Wooden siege catapults on spoked, iron-tyred wheels: one per kingdom, two families.

  torsion (red, green)       mangonel: twisted rope skein between the rails, arm cocked back
                             with a stone in its bucket, A-frame with a padded stop beam
  counterweight (blue, yellow) hinged counterweight box on a short arm end between two
                             A-frame towers, long arm pulled down to the rear by the winch

Shared: chunky bevelled timber chassis, iron corner straps, rear winch with rope, kingdom
heater shields on the rails and a kingdom pennant. Kingdom extras: red big crown shield, green
front timber mantlet (Thornwood hoardings), blue crisp compact frame, yellow gilded domes.

Front (firing direction) faces Blender -Y. Sockets: crew_1 / crew_2 = crew standing spots
beside the winch (ground level), projectile = centre of the loaded bucket.
"""

import math

from lib import kit
from lib.geo import Vector, box, cone, cylinder, lathe

from generators._kingdom_props_common import (KINGDOMS, border, emblem, emblem_colors, fan_solid, field, kcol,
                                              lashing, rope, sheet, stone_ball, wheel)

NAME = "siege_catapult"
VERSION = 1
CATEGORY = "siege"
BUDGET = "siege"
COLLISION = {"fidelity": "Hull"}
CHECKS = {"min_wheels": 2, "min_spokes": 12, "min_rope": 3}
DEFAULT_VARIANTS = 4
HERO_VIEW = {"azimuth": 40, "elevation": 20}

EMB = {"red": "crown", "blue": "star", "green": "oak", "yellow": "sun"}


def variants(n, seed):
    out = []
    for i in range(n):
        k = KINGDOMS[i % 4]
        out.append({
            "kingdom": k,
            "kind": "torsion" if k in ("red", "green") else "counterweight",
            "seed": seed * 1000 + i,
        })
    return out


def asset_id(i, p):
    return f"{CATEGORY}_catapult_{p['kingdom']}_{i // 4 + 1:02d}"


def beam(p0, p1, w, d, color="siege_wood", normal=(0, 0, 1), bev=0.0):
    return kit.oriented_box(p0, p1, w, d, color, Vector(normal), bev=bev)


def shield_field(k):
    """Shield field: never the emblem's own colour; the gold kingdom's sun sits on ivory."""
    return kcol(k, "accent") if k == "yellow" else field(k)


def heater_shield(k, h=2.6, depth=0.25):
    """Kingdom heater shield in the XZ plane facing -Y, centred on the origin: rim in the kingdom
    border metal / ivory, field, and a large raised emblem (56 % of the height)."""
    w = h * 0.42
    pts = [(0.0, -h * 0.5), (w * 0.62, -h * 0.26), (w * 0.9, h * 0.05), (w, h * 0.42), (w * 0.5, h * 0.5),
           (-w * 0.5, h * 0.5), (-w, h * 0.42), (-w * 0.9, h * 0.05), (-w * 0.62, -h * 0.26)]
    out = [fan_solid(pts, depth, border(k), center=(0, h * 0.05), mid=None)]
    inner = [(x * 0.84, z * 0.86 + h * 0.03) for x, z in pts]
    out.append(fan_solid(inner, depth, shield_field(k), center=(0, h * 0.06), mid=None).move(0, -0.08, 0))
    for pc in emblem(EMB[k], h * 0.56, *emblem_colors(k, EMB[k]), depth=0.16, mid=None):
        out.append(pc.move(0, -0.24, h * 0.07))
    return out


def chassis(b, k, L, Wd, R, rng, spokes, layout="four"):
    """Two rails, cross beams, axles, spoked wheels, iron straps. layout 'four' = four wheels;
    'skid' = two big rear wheels and front sled runners (Thornwood). Returns rail top z."""
    wood, dark = "siege_wood", "siege_wood_dark"
    zr = R - 0.55  # rail bottom
    rh = 1.05
    for sx in (-1, 1):
        b.add(kit.bbox(0.95, L, rh, wood, 0.12).move(sx * Wd / 2, 0, zr), grad=("range", 0.3, 0.85))
    ys = [-L / 2 + 0.7, -L * 0.18, L * 0.16, L / 2 - 0.7]
    for y in ys:
        b.add(kit.bbox(Wd + 1.5, 0.85, 0.8, dark, 0.1).move(0, y, zr + 0.12))
    yw = L / 2 - R - 0.6
    xw = Wd / 2 + 0.95 + 0.45
    axles = (-yw, yw) if layout == "four" else (yw,)
    for y in axles:
        b.add(box(2 * xw + 1.2, 0.7, 0.7, dark).move(0, y, R - 0.35))  # axle beam
        for sx in (-1, 1):
            b.add([pc.move(sx * xw, y, R) for pc in wheel(R, 0.75, spokes, 10, wood="wood", hub="siege_wood_dark",
                                                          cap=None)])
            b.stats["wheels"] = b.stats.get("wheels", 0) + 1
            b.stats["spokes"] = b.stats.get("spokes", 0) + spokes
    if layout == "skid":
        # heavy sled runners with upturned noses under the front half, block posts up to the rails
        for sx in (-1, 1):
            x = sx * Wd / 2
            y0, y1 = -L / 2 - 0.6, -L * 0.05
            b.add(kit.bbox(1.1, y1 - y0, 0.75, dark, 0.12).move(x, (y0 + y1) / 2, 0.0))
            b.add(beam((x, y0 + 0.3, 0.35), (x, y0 - 0.8, 1.5), 1.0, 0.7, dark, normal=(1, 0, 0)))  # nose
            for y in (y0 + 1.6, y1 - 1.2):
                b.add(kit.bbox(0.85, 0.85, zr - 0.7, wood, 0.08).move(x, y, 0.7))
            b.add(box(0.14, y1 - y0 - 0.6, 0.3, "iron_dark").move(x + sx * 0.56, (y0 + y1) / 2, 0.2))  # shoe
    # iron corner straps on the rail ends + rail/beam joints
    for sx in (-1, 1):
        for y in (ys[0], ys[-1]):
            b.add(box(0.12, 1.3, rh + 0.1, "iron_dark").move(sx * (Wd / 2 + 0.52), y, zr - 0.05))
        b.add(box(1.07, 0.3, rh + 0.08, "iron_dark").move(sx * Wd / 2, -L / 2 + 0.12, zr - 0.04))
    return zr + rh, ys, yw, xw


def winch(b, Wd, y, z, rng):
    """Rear windlass between the rails with crossed handspikes outside the rails."""
    span = Wd + 1.8
    for sx in (-1, 1):  # bearing blocks on the rails
        b.add(kit.bbox(1.15, 1.4, 0.9, "siege_wood_dark", 0.1).move(sx * Wd / 2, y, z - 0.75))
    b.add(cylinder(0.55, 0.55, span, 8, "siege_wood_dark").rotate(math.pi / 2, "Y").move(-span / 2, y, z))
    b.add(cylinder(0.78, 0.78, Wd * 0.45, 8, "rope").rotate(math.pi / 2, "Y").move(-Wd * 0.225, y, z), tag="rope")
    for sx in (-1, 1):
        x = sx * (span / 2 - 0.25)
        for a in (0.8, 0.8 + math.pi / 2):
            d = Vector((0, math.cos(a), math.sin(a))) * 1.9
            b.add(beam(Vector((x, y, z)) - d, Vector((x, y, z)) + d, 0.28, 0.28, "wood", normal=(1, 0, 0)))


def pennant(b, k, x, y, z, rng, L=3.6, H=1.6):
    """Small kingdom pennant on a short staff, flying towards +X."""
    b.add(cylinder(0.12, 0.1, 3.4, 6, "timber").move(x, y, z))
    b.add(lathe([(0.0, 0.0), (0.22, 0.12), (0.18, 0.35), (0.0, 0.6)], 5, kcol(k, "trim")).move(x, y, z + 3.4))
    top = z + 3.25

    def pos(u, v):
        xx = x + 0.1 + u * L
        return (xx, y + 0.25 * math.sin(u * 4.5 + 0.6) * u, top - v * H * (1 - 0.8 * u) - 0.35 * u * u)

    b.add(sheet([0.0, 0.25, 0.5, 0.75, 1.0], [0.0, 0.5, 1.0], pos, 0.18, field(k),
                lambda kind, i, j: kcol(k, "cloth_dark") if kind == "edge" else None), grad=("range", 0.3, 0.9))


def drape(b, k, x, y0, y1, ztop, h, rng):
    """Kingdom cloth hung along the outside of a rail, three pointed tails, trim bands."""
    cloth, trim, dark = field(k), border(k), kcol(k, "cloth_dark")
    sx = 1 if x > 0 else -1
    ph = rng.uniform(0, 6)

    def pos(u, v):
        y = y0 + (y1 - y0) * v
        z = ztop - u * (h - 0.7 * abs(math.sin(v * math.pi * 3)))
        return (x + sx * (0.08 * math.sin(y * 1.7 + ph) * u + 0.1 * u), y, z)

    us = [0.0, 0.14, 0.8, 1.0]
    vs = [i / 6 for i in range(7)]

    def cols(kind, i, j):
        if kind == "edge":
            return dark
        return trim if i in (0, 2) else cloth

    b.add(sheet(us, vs, pos, 0.2, cloth, cols, normal=(1, 0, 0)), grad=("range", 0.3, 0.9), tag="cloth")


def trestle(b, Wd, y, top, zt):
    """Rest for the cocked arm: two posts on the rails and a cross beam whose top is at zt."""
    for sx in (-1, 1):
        x = sx * Wd / 2
        b.add(beam((x, y, top - 0.1), (x, y, zt), 0.6, 0.6, "siege_wood", normal=(1, 0, 0)))
        b.add(beam((x, y + 1.4, top - 0.1), (x, y + 0.1, zt - 1.0), 0.45, 0.45, "siege_wood_dark", normal=(1, 0, 0)))
    b.add(kit.bbox(Wd + 0.9, 0.75, 0.7, "siege_wood_dark", 0.1).move(0, y, zt - 0.7))
    b.add(box(1.2, 0.85, 0.2, "iron_dark").move(0, y, zt - 0.05))


def bucket(b, x, y, z, tilt, r=1.15, color="siege_wood_dark"):
    """Open cup (closed solid: outer wall, rim, inner wall) with iron band; returns centre."""
    cup = lathe([(0.0, 0.0), (r * 0.7, 0.05), (r, r * 0.55), (r * 1.05, r * 0.9), (r * 0.82, r * 0.92),
                 (r * 0.66, r * 0.42), (0.0, r * 0.36)], 8, color)
    band = cylinder(r * 1.02, r * 1.06, 0.2, 8, "iron_dark").move(0, 0, r * 0.62)
    for pc in (cup, band):
        pc.rotate(tilt, "X").move(x, y, z)
        b.add(pc)


def build_torsion(b, p, rng):
    k = p["kingdom"]
    green = k == "green"
    L = rng.uniform(17.0, 18.0) if green else rng.uniform(15.5, 16.5)
    Wd = rng.uniform(6.2, 6.6) if green else rng.uniform(5.6, 6.0)
    R = 2.7 if green else 2.3
    top, ys, yw, xw = chassis(b, k, L, Wd, R, rng, 6, layout="skid" if green else "four")
    zc = top - 0.5
    yp = -L * 0.22  # skein axis
    # torsion skein: thick rope bundle through the rails, iron washers + ratchet levers outside
    b.add(cylinder(0.85, 0.85, Wd - 0.9, 10, "rope").rotate(math.pi / 2, "Y").move(-(Wd - 0.9) / 2, yp, zc),
          tag="rope")
    for sx in (-1, 1):
        xo = sx * (Wd / 2 + 0.5)
        b.add(cylinder(1.05, 1.05, 0.32, 10, "iron_dark").rotate(sx * math.pi / 2, "Y").move(xo, yp, zc))
        b.add(beam((xo + sx * 0.3, yp - 1.6, zc + 0.9), (xo + sx * 0.3, yp + 1.6, zc - 0.9), 0.3, 0.3, "iron",
                   normal=(1, 0, 0)))
    # throwing arm, cocked back towards +Y and resting on the rear cross beam
    a = math.radians(rng.uniform(22, 26))
    arm_len = (L / 2 - 2.2 - yp) / math.cos(a)
    p0 = Vector((0, yp, zc))
    p1 = p0 + Vector((0, math.cos(a), math.sin(a))) * arm_len
    yt = p1.y - 2.4
    trestle(b, Wd, yt, top, zc + (yt - yp) * math.tan(a) - 0.42)
    b.add(beam(p0 - Vector((0, 0.5, 0)), p1, 0.85, 0.85, "siege_wood", normal=(1, 0, 0), bev=0.1))
    for f in (0.25, 0.55, 0.85):  # iron bands
        c = p0 + (p1 - p0) * f
        b.add(beam(c - Vector((0, 0.18, 0)), c + Vector((0, 0.18, 0)), 1.0, 1.0, "iron_dark", normal=(1, 0, 0)))
    bucket(b, 0, p1.y - 0.5, p1.z + 0.25, 0.0, r=1.25)
    st = stone_ball(rng, 0.9, "stone")
    b.add(st.move(0, p1.y - 0.5, p1.z + 0.6))
    b.socket("projectile", 0, p1.y - 0.5, p1.z + 1.4)
    # A-frame posts with a padded stop beam
    yf = yp - 1.0
    hz = top + rng.uniform(5.6, 6.2)
    for sx in (-1, 1):
        x = sx * (Wd / 2)
        b.add(beam((x, yf, top - 0.1), (x, yf + 0.5, hz), 0.75, 0.75, "siege_wood", normal=(1, 0, 0), bev=0.08))
        b.add(beam((x, ys[0] + 0.3, top - 0.1), (x, yf + 0.35, hz - 1.6), 0.6, 0.6, "siege_wood_dark",
                   normal=(1, 0, 0)))
        b.add(beam((x, yf + 0.25, top + 1.6), (x, yp + 1.4, top - 0.1), 0.5, 0.5, "siege_wood_dark",
                   normal=(1, 0, 0)))
        b.add(box(0.95, 0.95, 0.35, "iron_dark").move(x, yf + 0.5, hz - 1.0))
    b.add(kit.bbox(Wd + 1.4, 0.9, 0.95, "siege_wood", 0.1).move(0, yf + 0.55, hz - 0.2))
    pad = lathe([(0.0, -Wd * 0.3), (0.5, -Wd * 0.28), (0.62, 0.0), (0.5, Wd * 0.28), (0.0, Wd * 0.3)], 6,
                field(k), smooth=True)
    b.add(pad.rotate(math.pi / 2, "Y").scale(1.0, 0.8, 1.0).move(0, yf + 1.05, hz + 0.25))
    for sx in (-1, 1):
        b.add(cylinder(0.66, 0.66, 0.22, 6, "rope").rotate(math.pi / 2, "Y")
              .move(sx * Wd * 0.17, (yf + 1.05), hz + 0.25))
    # rear winch and the rope that holds the arm down
    yw_ = L / 2 - 1.6
    zw = top + 0.5
    winch(b, Wd, yw_, zw, rng)
    b.add(rope([(0, yw_ - 0.6, zw + 0.3), (0, p1.y - 1.6, p1.z - 0.1), (0, p1.y - 2.1, p1.z + 0.2)], r=0.14),
          tag="rope")
    b.add(rope([(0.9, yp + 0.3, zc + 0.8), (0.9, yp + 1.6, zc + 0.75)], r=0.13), tag="rope")
    b.add(rope([(-0.9, yp + 0.3, zc + 0.8), (-0.9, yp + 1.6, zc + 0.75)], r=0.13), tag="rope")
    # kingdom drapes and shields on the rails
    for sx in (-1, 1):
        if not green:  # Thornwood carries its colour on the mantlet, shields, pad and pennant instead
            drape(b, k, sx * (Wd / 2 + 0.6), yp + 1.3, yw - R - 0.3, top - 0.05, 1.9, rng)
        for pc in heater_shield(k, 2.8):  # angled 45 deg so the front camera reads them
            b.add(pc.rotate(sx * 0.8, "Z").move(sx * (Wd / 2 + 0.95), (yp + yw - R) / 2 + 0.5, top + 0.3))
    if k == "red":
        # Emberhold: big crown shield on the front frame facing the camera (no fire: red never uses a flame)
        for pc in heater_shield(k, 3.6):
            b.add(pc.move(0, -L / 2 - 0.15, top + 1.3))
        b.add(box(1.6, 0.3, 0.4, "iron_dark").move(0, -L / 2 + 0.05, top + 2.4))  # hanger bracket
        pennant(b, k, Wd / 2, yf + 0.5, hz + 0.3, rng)
    else:
        # Thornwood timber mantlet across the front: vertical planks with a sight slot
        ym = -L / 2 - 0.2
        mh = 5.2
        n = 9
        for i in range(n):
            x = -Wd / 2 - 0.5 + (Wd + 1.0) * (i + 0.5) / n
            hh = mh * (1.0 if i % 2 else 0.92) + rng.uniform(-0.1, 0.1)
            pl = box((Wd + 1.0) / n - 0.08, 0.4, hh, "wood" if i % 3 else "wood_dark")
            b.add(pl.move(x, ym, top - 0.6).paint(tint=rng.uniform(0.2, 0.8)))
            b.add(cone(0.38, 0.6, 4, "wood_dark").move(x, ym, top - 0.6 + hh))
        for z in (top + 0.6, top + 3.4):
            b.add(box(Wd + 1.3, 0.3, 0.45, "siege_wood_dark").move(0, ym - 0.32, z))
        for pc in heater_shield(k, 3.6):
            b.add(pc.move(0, ym - 0.55, top + 2.2))
        pennant(b, k, -Wd / 2, yf + 0.5, hz + 0.3, rng)
    b.socket("crew_1", -(Wd / 2 + 2.2), yw_, 0)
    b.socket("crew_2", Wd / 2 + 2.2, yw_, 0)


def build_counterweight(b, p, rng):
    k = p["kingdom"]
    yellow = k == "yellow"
    L = rng.uniform(17.5, 18.5) if yellow else rng.uniform(16.0, 17.0)
    Wd = rng.uniform(6.4, 6.8) if yellow else rng.uniform(5.8, 6.2)
    R = 2.2
    top, ys, yw, xw = chassis(b, k, L, Wd, R, rng, 6)
    # towers on both rails: blue = crisp A-frames, yellow = tall vertical trestle towers with
    # X-braces, raking struts and gold ball finials (Sunspire)
    H = top + (rng.uniform(10.0, 10.4) if yellow else rng.uniform(6.4, 6.8))
    ya = -L * 0.12
    spread = 3.6 if yellow else 4.2
    for sx in (-1, 1):
        x = sx * Wd / 2
        if yellow:
            for sy in (-1, 1):
                b.add(beam((x, ya + sy * 1.3, top - 0.1), (x, ya + sy * 1.3, H - 0.4), 0.7, 0.7, "siege_wood",
                           normal=(1, 0, 0)))
                b.add(beam((x, ya + sy * 3.9, top - 0.1), (x, ya + sy * 1.5, top + (H - top) * 0.62), 0.5, 0.5,
                           "siege_wood_dark", normal=(1, 0, 0)))  # raking strut
                b.add(lathe([(0.3, 0.0), (0.44, 0.25), (0.3, 0.6), (0.0, 0.75)], 6, "gold")
                      .move(x, ya + sy * 1.3, H + 0.2))
            for z0, z1 in ((top + (H - top) * 0.45, H - 0.8),):
                b.add(beam((x, ya - 1.2, z0), (x, ya + 1.2, z1), 0.32, 0.32, "siege_wood_dark", normal=(1, 0, 0)))
                b.add(beam((x, ya + 1.2, z0), (x, ya - 1.2, z1), 0.32, 0.32, "siege_wood_dark", normal=(1, 0, 0)))
            b.add(kit.bbox(0.9, 3.6, 0.6, "siege_wood", 0.08).move(x, ya, H - 0.4))  # cap beam
            b.add(box(0.95, 3.7, 0.18, kcol(k, "trim")).move(x, ya, H + 0.2))  # bronze cap strap
        else:
            for sy in (-1, 1):
                b.add(beam((x, ya + sy * spread, top - 0.1), (x, ya + sy * 0.25, H), 0.75, 0.75, "siege_wood",
                           normal=(1, 0, 0), bev=0.08))
            zm = top + (H - top) * 0.42
            b.add(beam((x, ya - spread * 0.6, zm), (x, ya + spread * 0.6, zm), 0.5, 0.6, "siege_wood_dark",
                       normal=(1, 0, 0)))
            b.add(lashing(0.5, 0.8, turns=1)[0].rotate(math.pi / 2, "X").move(x, ya + 0.4, zm))
            # Frostmere square-pyramid caps on the A-frame apexes (crisp, silver-tipped)
            for pc in kit.cone_roof(0.75, 1.3, seg=4, color=kcol(k, "roof"), overhang=0.25, flare=False,
                                    finial=None, rows=0):
                b.add(pc.move(x, ya, H + 0.35))
        b.add(box(1.0, 1.4, 1.0, "iron_dark").move(x, ya, H - 0.6))  # axle bearing
    # axle across the towers
    b.add(cylinder(0.32, 0.32, Wd + 1.4, 8, "iron").rotate(math.pi / 2, "Y").move(-(Wd + 1.4) / 2, ya, H - 0.2))
    # arm: long end pulled down to the rear, short end up front carrying the counterweight
    pv = Vector((0, ya, H - 0.2))
    tail = Vector((0, L / 2 - 2.6, top + 2.4))
    d = (tail - pv).normalized()
    short = pv - d * (3.3 if yellow else 2.8)
    b.add(beam(short, tail, 0.8, 0.8, "siege_wood", normal=(1, 0, 0), bev=0.1))
    for f in (0.15, 0.5, 0.8):
        c = short + (tail - short) * f
        b.add(beam(c - d * 0.18, c + d * 0.18, 0.95, 0.95, "iron_dark", normal=(1, 0, 0)))
    yt = tail.y - 2.2
    trestle(b, Wd, yt, top, pv.z + (yt - pv.y) * d.z / d.y - 0.4)
    bucket(b, 0, tail.y - 0.2, tail.z + 0.3, 0.0, r=1.1)
    st = stone_ball(rng, 0.8, "stone")
    b.add(st.move(0, tail.y - 0.2, tail.z + 0.55))
    b.socket("projectile", 0, tail.y - 0.2, tail.z + 1.3)
    # hanging counterweight: iron hanger bars + plank box full of stones, kingdom stripe
    cw, cd, ch = (3.0, 2.4, 2.6) if yellow else (2.6, 2.1, 2.3)
    zt = short.z - 2.2
    for sx in (-1, 1):
        b.add(beam((sx * 0.55, short.y, short.z), (sx * (cw / 2 - 0.2), short.y, zt), 0.22, 0.3, "iron_dark",
                   normal=(0, 1, 0)))
    b.add(kit.bbox(cw, cd, ch, "wood_dark", 0.12).move(0, short.y, zt - ch))
    b.add(box(cw + 0.1, cd + 0.1, 0.5, field(k)).move(0, short.y, zt - ch * 0.62))
    for zz in (zt - ch + 0.15, zt - 0.4):
        b.add(box(cw + 0.12, cd + 0.12, 0.22, "iron_dark").move(0, short.y, zz))
    for i in range(3):
        b.add(stone_ball(rng, 0.62, "stone_dark", 1).move(-0.75 + i * 0.75, short.y + rng.uniform(-0.3, 0.3),
                                                       zt - 0.75))
    # rear winch holding the arm down
    yw_ = L / 2 - 1.2
    zw = top + 0.5
    winch(b, Wd, yw_, zw, rng)
    b.add(rope([(0, yw_ - 0.6, zw + 0.3), (0, tail.y - 0.9, tail.z - 0.1), (0, tail.y - 1.6, tail.z + 0.3)],
               r=0.14), tag="rope")
    # trigger hook with its release lanyard
    b.add(box(0.3, 0.9, 0.3, "iron").move(0, tail.y - 1.0, tail.z - 0.6))
    b.add(rope([(0.1, tail.y - 1.0, tail.z - 0.7), (0.9, yw_ - 1.4, top + 0.4)], r=0.07, seg=4), tag="rope")
    # guy ropes from the tower tops to the rail ends
    for sx in (-1, 1) if not yellow else ():  # the trestle towers need no guy ropes
        b.add(rope([(sx * Wd / 2, ya + 0.3, H - 1.0), (sx * Wd / 2, ys[-1], top + 0.1)], r=0.09, seg=4), tag="rope")
    # kingdom drapes, shields (clear of the towers, between tower and rear wheel) and pennant
    ysh = (ya + spread + (yw - R)) / 2 + (0.3 if yellow else 0.0)
    for sx in (-1, 1):
        drape(b, k, sx * (Wd / 2 + 0.6), -yw + R + 0.3, yw - R - 0.3, top - 0.05, 1.9, rng)
        for pc in heater_shield(k, 2.8):  # angled 45 deg so the front camera reads them
            b.add(pc.rotate(sx * 0.8, "Z").move(sx * (Wd / 2 + 0.95), ysh, top + 0.3))
    for pc in heater_shield(k, 3.6):  # big front shield on the nose beam, faces the gameplay camera
        b.add(pc.move(0, -L / 2 - 0.1, top + 0.6))
    pennant(b, k, (1 if not yellow else -1) * Wd / 2, ya, H + (0.2 if not yellow else 1.4), rng, L=4.2, H=1.8)
    b.socket("crew_1", -(Wd / 2 + 2.2), yw_, 0)
    b.socket("crew_2", Wd / 2 + 2.2, yw_, 0)


def build(b, p):
    rng = b.rng
    (build_torsion if p["kind"] == "torsion" else build_counterweight)(b, p, rng)
    b.stats["rope"] = b.count_tag("rope")
    b.stats["pieces"] = len(b.pieces)
