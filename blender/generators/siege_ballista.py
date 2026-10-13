"""Siege ballistas (giant torsion crossbows), one per kingdom, cocked with a bolt loaded.

  red     field carriage: two spoked wheels + split trail, flame-red fletching
  blue    square stone dais with a round turntable and pivot post, star badge on the frame
  green   Thornwood sled runners (iron shoes, upturned noses), spiked mantlet with emerald bands
  yellow  four-legged trestle stand on a turntable, bronze-capped skeins, sun badge

Shared parts: stock with a slider and claw, spring frame (capitulum) with two twisted rope
skeins and iron washers, two bow arms drawn back, rope bowstring, iron-headed bolt with
kingdom-cloth fletching, rear windlass with handspikes, kingdom shield + pennant.
Front (shooting direction) faces Blender -Y. Sockets: crew_1 / crew_2 = crew spots beside the
windlass (ground), projectile = bolt nock (spawn point of the shot).
"""

import math

from lib import kit
from lib.geo import Matrix, Vector, bevel, box, cone, cylinder, lathe, look_rot

from generators._kingdom_props_common import KINGDOMS, fan_solid, field, kcol, lashing, rope, wheel
from generators.siege_catapult import heater_shield, pennant

NAME = "siege_ballista"
VERSION = 1
CATEGORY = "siege"
BUDGET = "siege"
COLLISION = {"fidelity": "Hull"}
CHECKS = {"min_rope": 3, "min_bolt": 1}
DEFAULT_VARIANTS = 4
HERO_VIEW = {"azimuth": 58, "elevation": 26}


def variants(n, seed):
    out = []
    for i in range(n):
        k = KINGDOMS[i % 4]
        out.append({"kingdom": k, "mount": {"red": "carriage", "green": "skid", "blue": "dais",
                                            "yellow": "stand"}[k],
                    "seed": seed * 1000 + i})
    return out


def asset_id(i, p):
    return f"{CATEGORY}_ballista_{p['kingdom']}_{i // 4 + 1:02d}"


def beam(p0, p1, w, d, color="siege_wood", normal=(1, 0, 0), bev=0.0):
    return kit.oriented_box(p0, p1, w, d, color, Vector(normal), bev=bev)


def obox(p0, p1, side, up_size, color, up=(0.0, 0.0, 1.0), bev=0.0):
    """Beam p0->p1 whose cross-section is `side` wide (horizontal, across the beam) and
    `up_size` tall (along `up`); vertical beams use +Y as the reference instead."""
    p0, p1 = Vector(p0), Vector(p1)
    axis = p1 - p0
    length = axis.length
    a = axis.normalized()
    upv = Vector(up)
    if abs(a.dot(upv)) > 0.95:
        upv = Vector((0.0, 1.0, 0.0))
    sd = a.cross(upv).normalized()
    u = sd.cross(a).normalized()
    pc = box(side, up_size, length, color)
    if bev > 0:
        pc = bevel(pc, bev)
    pc.transform(Matrix((sd, u, a)).transposed().to_4x4())
    return pc.move(*p0)


def build(b, p):
    rng = b.rng
    k = p["kingdom"]
    stand = p["mount"] in ("stand", "dais")
    big = k in ("green", "yellow")
    S = 1.22 if big else 1.1  # overall scale of the weapon
    zp = (4.3 if stand else 3.9) * (1.0 if not big else 1.04)  # pivot height (stock underside)
    tilt = math.radians(-6)  # front of the stock raised
    ropes = 0

    # ---------------- mount
    if p["mount"] == "dais":
        # Frostmere: crisp square stone dais, round timber turntable with an iron rim, pivot post
        sc = kcol(k, "stone")
        b.add(kit.bbox(5.6, 5.6, 0.9, kcol(k, "stone_dark"), 0.15))
        b.add(kit.bbox(4.6, 4.6, 0.6, sc, 0.15).move(0, 0, 0.9))
        for i in range(4):  # corner quoin blocks
            a = math.pi / 4 + i * math.pi / 2
            b.add(kit.bbox(1.1, 1.1, 0.7, kcol(k, "stone_light"), 0.1).move(math.cos(a) * 3.5, math.sin(a) * 3.5, 0.0))
        b.add(cylinder(2.3, 2.3, 0.45, 12, "siege_wood_dark").move(0, 0, 1.5))
        b.add(cylinder(2.38, 2.38, 0.18, 12, "iron_dark").move(0, 0, 1.6))
        b.add(kit.bbox(1.1, 1.1, zp - 2.85, "siege_wood", 0.08).move(0, 0, 1.95))
        for sy in (-1, 1):  # raking braces from the turntable to the post
            b.add(beam((0, sy * 1.9, 1.95), (0, sy * 0.4, zp - 1.3), 0.4, 0.4, "siege_wood_dark", normal=(1, 0, 0)))
        b.add(cylinder(0.8, 0.8, 0.3, 8, "iron_dark").move(0, 0, zp - 0.9))
    elif stand:
        # turntable on four splayed legs with cross braces
        b.add(cylinder(1.25, 1.25, 0.45, 10, "siege_wood_dark").move(0, 0, zp - 0.95))
        b.add(cylinder(0.95, 0.95, 0.2, 10, "iron_dark").move(0, 0, zp - 0.5))
        for i in range(4):
            a = math.pi / 4 + i * math.pi / 2
            foot = Vector((math.cos(a) * 3.1, math.sin(a) * 3.1, 0.0))
            top = Vector((math.cos(a) * 0.8, math.sin(a) * 0.8, zp - 0.9))
            b.add(beam(foot, top, 0.6, 0.6, "siege_wood", normal=(-math.sin(a), math.cos(a), 0), bev=0.07))
            b.add(kit.bbox(1.0, 1.0, 0.35, "stone_dark", 0.1).move(foot.x, foot.y, 0.0))
        for i in range(4):
            a0 = math.pi / 4 + i * math.pi / 2
            a1 = a0 + math.pi / 2
            r = 2.0
            z = zp * 0.32
            b.add(beam((math.cos(a0) * r, math.sin(a0) * r, z), (math.cos(a1) * r, math.sin(a1) * r, z), 0.32, 0.32,
                       "siege_wood_dark", normal=(0, 0, 1)))
    elif p["mount"] == "skid":
        # Thornwood: heavy sled runners with upturned noses and iron shoes, cross sleepers, pivot post
        R = 2.1
        for sx in (-1, 1):
            x = sx * 2.2
            b.add(kit.bbox(1.0, 9.0, 0.8, "siege_wood_dark", 0.12).move(x, 1.4, 0.0))
            b.add(beam((x, -2.9, 0.4), (x, -4.2, 1.7), 0.95, 0.7, "siege_wood_dark", normal=(1, 0, 0)))  # nose
            b.add(box(0.14, 8.4, 0.3, "iron_dark").move(x + sx * 0.52, 1.4, 0.2))  # iron shoe
        for y in (-1.6, 0.6, 2.8, 5.0):
            b.add(box(5.4, 0.7, 0.5, "siege_wood").move(0, y, 0.8))  # sleepers
        b.add(kit.bbox(1.1, 1.1, zp - 1.9, "siege_wood", 0.08).move(0, 0.6, 1.3))  # pivot post
        for sy in (-1, 1):
            b.add(beam((0, 0.6 + sy * 2.1, 1.3), (0, 0.6 + sy * 0.45, zp - 1.3), 0.45, 0.45, "siege_wood_dark",
                       normal=(1, 0, 0)))
        b.add(cylinder(0.75, 0.75, 0.3, 8, "iron_dark").move(0, 0.6, zp - 0.6))
    else:
        # field carriage: axle, two wheels, split trail to the rear, pivot post
        R = 2.1
        xw = 2.5
        b.add(kit.bbox(2 * xw + 0.4, 0.8, 0.8, "siege_wood_dark", 0.08).move(0, 0.6, R - 0.4))
        for sx in (-1, 1):
            b.add([pc.move(sx * xw, 0.6, R) for pc in wheel(R, 0.7, 6, 10, wood="wood", hub="siege_wood_dark",
                                                            cap=None)])
            b.add(beam((sx * 1.3, -0.4, R + 0.2), (sx * 0.55, 7.2, 0.3), 0.7, 0.75, "siege_wood", normal=(0, 0, 1),
                       bev=0.07))
        b.add(box(1.7, 0.6, 0.55, "siege_wood_dark").move(0, 5.6, 0.75))
        b.add(box(1.4, 0.9, 0.3, "iron_dark").move(0, 7.0, 0.05))  # trail spade
        b.add(kit.bbox(1.0, 1.0, zp - R - 0.2, "siege_wood", 0.08).move(0, 0.6, R + 0.2))  # pivot post
        b.add(cylinder(0.75, 0.75, 0.3, 8, "iron_dark").move(0, 0.6, zp - 0.6))
        b.stats["wheels"] = 2
    # yoke on the pivot
    for sx in (-1, 1):
        b.add(box(0.25, 1.1, 0.9, "iron_dark").move(sx * 0.62, 0.6 if not stand else 0.0, zp - 0.45))

    # ---------------- stock (rotated about the pivot by `tilt`, front up)
    py = 0.6 if not stand else 0.0
    L = 10.5 * S
    y0, y1 = -4.6 * S, L - 4.6 * S

    def T(x, y, z):
        """stock-local -> world: rotate about X through the pivot (py, zp)."""
        dy, dz = y - py, z
        return Vector((x, py + dy * math.cos(tilt) - dz * math.sin(tilt), zp + dy * math.sin(tilt) + dz * math.cos(tilt)))

    up = (0.0, -math.sin(tilt), math.cos(tilt))

    def sbeam(a, c, w, d, color="siege_wood", bev=0.0):
        """stock-local beam a->c, w across (X or Y), d tall (stock up)."""
        return obox(T(*a), T(*c), w, d, color, up=up, bev=bev)

    b.add(sbeam((0, y0, 0.0), (0, y1, 0.0), 1.1, 0.5, "siege_wood_dark", bev=0.06))  # base board (centre z .25)
    for sx in (-1, 1):  # groove rails
        b.add(sbeam((sx * 0.38, y0 + 0.3, 0.45), (sx * 0.38, y1 - 0.4, 0.45), 0.32, 0.42, "siege_wood"))
    for f in (0.12, 0.62, 0.92):  # iron bands round the stock
        y = y0 + (y1 - y0) * f
        b.add(sbeam((0, y - 0.15, 0.2), (0, y + 0.15, 0.2), 1.25, 0.95, "iron_dark"))

    # ---------------- capitulum (spring frame) at the front of the stock
    yc = y0 + 1.0 * S
    hw = 1.2 * S  # skein offset
    hh = 1.25 * S
    for z in (-hh, hh):
        b.add(sbeam((-(hw + 0.7), yc - 0.45, z + 0.3), (hw + 0.7, yc - 0.45, z + 0.3), 0.6, 0.55 + 0.1 * (z > 0),
                    "siege_wood", bev=0.05))
    for sx in (-1, 1):
        x = sx * hw
        c0, c1 = T(x, yc - 0.45, -hh + 0.3), T(x, yc - 0.45, hh + 0.3)
        b.add(cylinder(0.5, 0.5, (c1 - c0).length, 8, "rope").move(c0.x, c0.y, c0.z))  # twisted skein
        b.add(lathe([(0.32, 0.0), (0.56, 0.12), (0.56, (c1 - c0).length * 0.5), (0.32, (c1 - c0).length)], 8, "rope")
              .move(c0.x, c0.y, c0.z))  # bulge of the twisted bundle
        ropes += 1
        for zz in (hh + 0.62, -hh - 0.05):  # iron washers with levers
            c = T(x, yc - 0.45, zz)
            b.add(cylinder(0.95, 0.95, 0.45, 8, "iron_dark").move(c.x, c.y, c.z - 0.2))
            b.add(sbeam((x - 0.95, yc - 0.45, zz + 0.12), (x + 0.95, yc - 0.45, zz + 0.12), 0.3, 0.3, "iron"))
        b.add(sbeam((sx * (hw + 0.85), yc - 0.45, -hh), (sx * (hw + 0.85), yc - 0.45, hh + 0.6), 0.35, 0.5,
                    "siege_wood_dark"))  # outer stanchion
        if k == "yellow":  # bronze skein caps (no domes on a siege engine)
            c = T(x, yc - 0.45, hh + 0.86)
            b.add(cylinder(0.8, 0.6, 0.35, 8, kcol(k, "trim")).move(c.x, c.y, c.z))
    # bow arms: two-segment, swept back (drawn), iron bands, horn tips
    tips = []
    for sx in (-1, 1):
        a0 = (sx * hw, yc - 0.45, 0.3)
        a1 = (sx * (hw + 1.9 * S), yc + 0.35 * S, 0.3)
        a2 = (sx * (hw + 3.7 * S), yc + 1.75 * S, 0.3)
        b.add(sbeam(a0, a1, 0.95, 0.95, "siege_wood_dark", bev=0.06))
        b.add(sbeam(a1, a2, 0.78, 0.8, "siege_wood_dark", bev=0.06))
        b.add(sbeam((a1[0] - sx * 0.18, a1[1] - 0.12, 0.3), (a1[0] + sx * 0.18, a1[1] + 0.12, 0.3), 1.1, 1.1,
                    "iron_dark"))
        tip = T(*a2)
        b.add(lathe([(0.44, 0.0), (0.5, 0.4), (0.0, 1.0)], 6, kcol(k, "trim")).move(tip.x, tip.y, tip.z - 0.3))
        tips.append(tip)
    # claw on the slider, bowstring drawn back to it
    ycl = yc + 5.2 * S
    b.add(sbeam((0, ycl - 0.6, 0.5), (0, ycl + 0.6, 0.5), 0.75, 0.6, "siege_wood"))
    b.add(sbeam((0, ycl - 0.7, 0.85), (0, ycl - 0.2, 0.85), 0.42, 0.42, "iron_dark"))
    nock = T(0, ycl - 0.8, 0.85)
    b.add(rope([tips[0], nock, tips[1]], r=0.18, seg=4), tag="rope")
    ropes += 1
    # bolt: shaft along the groove, iron head, kingdom fletching
    bl = 6.6 * S
    q0 = T(0, ycl - 0.75, 0.85)
    q1 = T(0, ycl - 0.75 - bl, 0.85)
    b.add(beam(q0, q1, 0.42, 0.42, "wood_light", normal=(1, 0, 0)))
    d = (q1 - q0).normalized()
    head = lathe([(0.42, 0.0), (0.66, 0.35), (0.0, 1.5)], 4, "steel")
    b.add(head.transform(look_rot(d)).move(*q1))
    for ang in (0.0, 2.1, -2.1):
        fl = fan_solid([(0.0, 0.0), (0.55, 0.0), (0.6, 1.0), (0.0, 1.5)], 0.1, field(k), center=(0.25, 0.6),
                       mid=None)
        fl.rotate(math.pi / 2, "X").rotate(ang + math.pi / 2, "Y")
        fl.rotate(tilt, "X").move(*(q0 + d * 0.3))
        b.add(fl)
    b.stats["bolt"] = 1
    b.socket("projectile", nock.x, nock.y, nock.z)

    # ---------------- rear windlass with handspikes
    yw = y1 - 0.9
    for sx in (-1, 1):
        b.add(sbeam((sx * 0.75, yw, 0.0), (sx * 0.75, yw, 0.95), 0.3, 0.7, "siege_wood_dark"))
    c = T(0, yw, 0.6)
    b.add(cylinder(0.32, 0.32, 2.6, 8, "siege_wood_dark").rotate(math.pi / 2, "Y").move(-1.3, c.y, c.z))
    b.add(cylinder(0.46, 0.46, 1.0, 8, "rope").rotate(math.pi / 2, "Y").move(-0.5, c.y, c.z))
    ropes += 1
    for sx in (-1, 1):
        for a in (0.7, 0.7 + math.pi / 2):
            dd = Vector((0, math.cos(a), math.sin(a))) * 1.25
            b.add(beam(Vector((sx * 1.2, c.y, c.z)) - dd, Vector((sx * 1.2, c.y, c.z)) + dd, 0.2, 0.2, "wood"))
    b.add(rope([T(0, yw - 0.3, 0.75), T(0, ycl + 0.4, 0.75)], r=0.08, seg=4), tag="rope")
    # trigger lever
    b.add(sbeam((0.45, ycl + 0.7, 0.5), (0.45, ycl + 1.6, -0.6), 0.16, 0.16, "iron"))

    # ---------------- kingdom extras
    if k == "green":
        # Thornwood: spiked planked mantlet on skids in front of the carriage
        ym = -5.2 * S
        n = 8
        Wm = 6.2 * S
        hm = zp - 1.0  # stays below the bow arms so the weapon reads over it
        for i in range(n):
            x = -Wm / 2 + Wm * (i + 0.5) / n
            h_ = hm + (0.3 if i % 2 else 0.0)
            b.add(box(Wm / n - 0.08, 0.35, h_, rng.choice(("wood", "wood_dark", "wood"))).move(x, ym, 0.0)
                  .paint(tint=rng.uniform(0.2, 0.8)))
            b.add(cone(0.3, 0.55, 4, "wood_dark").move(x, ym, h_))
        for z in (0.6, hm - 0.7):
            b.add(box(Wm + 0.3, 0.3, 0.45, field(k)).move(0, ym - 0.3, z))  # emerald bands
        for sx in (-1, 1):
            b.add(beam((sx * (Wm / 2 - 0.6), ym + 0.2, hm - 0.5), (sx * (Wm / 2 - 0.6), ym + 2.0, 0.0), 0.3, 0.3,
                       "siege_wood_dark", normal=(1, 0, 0)))
        for pc in heater_shield(k, 3.2):
            b.add(pc.move(0.0, ym - 0.5, hm * 0.5))
        b.add([pc.move(0, 0.6, R + 0.5) for pc in lashing(0.55, 0.9, turns=2)])
    else:
        # big kingdom badge shield bolted to the front of the spring frame, under the bolt
        hs = 3.4
        c = T(0, yc - 1.1, -hh * 0.2 - hs * 0.5 + 0.2)
        for pc in heater_shield(k, hs):
            b.add(pc.move(c.x, c.y, c.z))
        b.add(sbeam((0, yc - 0.9, -hh * 0.6), (0, yc - 0.4, -hh * 0.6), 0.6, 0.6, "iron_dark"))  # mount bracket
    pf = T(-(hw + 0.85), yc - 0.45, hh + 0.7)
    pennant(b, k, pf.x, pf.y, pf.z, rng, L=3.2, H=1.4)

    b.stats["rope"] = ropes
    cw = T(0, yw, 0)
    b.socket("crew_1", -2.6, cw.y + 0.6, 0)
    b.socket("crew_2", 2.6, cw.y + 0.6, 0)
    b.stats["pieces"] = len(b.pieces)
