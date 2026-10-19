"""Timber river bridges: plank decks on trestle bents, three types.

  plank    32 long, low deck on one central trestle and two ramp bents, timber railings
  trestle  44 long, tall deck on four braced trestle bents on stone footings, rope handrails
  humped   40 long storybook footbridge: curved deck on laminated arch ribs + posts, railings

Bridge runs along X; deck ends meet the ground (z ~ 0.3) at x = +-L/2 so carts can roll on.
Planks run across the deck (13 long, 12.4 clear between railings), stringers underneath.
Sockets: end_a (x-) / end_b (x+) = centre of each deck end at ground level.
"""

import math

from lib import kit
from lib.geo import Vector, box

from generators._kingdom_props_common import lashing, rope

NAME = "bridge_wood"
VERSION = 1
CATEGORY = "bridge"
BUDGET = "bridge"
COLLISION = {"fidelity": "PreciseConvexDecomposition"}
CHECKS = {"min_planks": 20, "min_bents": 1}
DEFAULT_VARIANTS = 3
HERO_VIEW = {"azimuth": 30, "elevation": 20}
LINEUP_GAP = 6.0
TYPES = ("plank", "trestle", "humped")
DECK_W = 13.0


def variants(n, seed):
    return [{"type": TYPES[i % 3], "length": (32.0, 44.0, 40.0)[i % 3], "seed": seed * 1000 + i} for i in range(n)]


def asset_id(i, p):
    return f"{CATEGORY}_wood_{p['type']}_{i // 3 + 1:02d}"


def beam(p0, p1, w, d, color="timber", normal=(0, 0, 1), bev=0.0):
    return kit.oriented_box(p0, p1, w, d, color, Vector(normal), bev=bev)


def clamp0(piece):
    return piece.bend(lambda v: (v.x, v.y, max(v.z, 0.0)))


def build(b, p):
    rng = b.rng
    t = p["type"]
    L = p["length"]
    zend = 0.3
    if t == "plank":
        H, lr = 3.4, 8.5
    elif t == "trestle":
        H, lr = 6.4, 14.0
    else:
        H, lr = 5.6, 0.0

    def deck_z(x):
        """top of the planks."""
        if t == "humped":
            u = min(1.0, abs(2 * x / L))
            return zend + (H - zend) * math.cos(u * math.pi / 2) ** 1.25
        d = L / 2 - abs(x)
        if d >= lr:
            return H
        s = d / lr
        return zend + (H - zend) * (3 * s * s - 2 * s * s * s)  # smooth ramp

    # --- planks across the deck (individually tilted to the slope), a few lifted/skewed
    pw = 1.4
    n = int(L / pw)
    planks = 0
    for i in range(n):
        x = -L / 2 + pw * (i + 0.5) * L / (n * pw)
        z = deck_z(x)
        sl = math.atan2(deck_z(x + 0.4) - deck_z(x - 0.4), 0.8)
        col = rng.choice(("wood", "wood", "wood", "wood_light", "wood_light", "wood_dark"))
        pl = box(pw - 0.08, DECK_W * rng.uniform(0.97, 1.0), 0.35, col, base=False)
        pl.rotate(-sl + rng.uniform(-0.015, 0.015), "Y").rotate(rng.uniform(-0.012, 0.012), "Z")
        b.add(clamp0(pl.move(x, rng.uniform(-0.15, 0.15), z - 0.175)).paint(tint=rng.uniform(0.1, 0.9)), tag="plank")
        planks += 1
    b.stats["planks"] = planks

    # --- wheel treadways: two longitudinal plank strips over the cross planks (cart tracks)
    if t != "humped":
        tw = [-L / 2 + 0.2] + [-L / 2 + lr * f for f in (0.2, 0.4, 0.6, 0.8, 1.0)] + \
             [L / 2 - lr * f for f in (1.0, 0.8, 0.6, 0.4, 0.2)] + [L / 2 - 0.2]
        for y in (-2.6, 2.6):
            for x0, x1 in zip(tw, tw[1:]):
                q0 = Vector((x0, y, deck_z(x0) + 0.12))
                q1 = Vector((x1, y, deck_z(x1) + 0.12))
                d = (q1 - q0).normalized()
                b.add(clamp0(beam(q0 + d * 0.04, q1 - d * 0.04, 1.7, 0.24, "wood_light")).paint(tint=rng.uniform(0.2, 0.8)))

    # --- stringers under the planks, following the profile
    st = [(-L / 2 + 0.3)] + [x for x in [-L / 2 + L * i / 10 for i in range(1, 10)]] + [L / 2 - 0.3]
    if t != "humped":
        st = [-L / 2 + 0.3] + [-L / 2 + lr * f for f in (0.25, 0.5, 0.75, 1.0)] + \
             [L / 2 - lr * f for f in (1.0, 0.75, 0.5, 0.25)] + [L / 2 - 0.3]
        st = sorted(set(st))
    for y in (-5.2, -1.75, 1.75, 5.2):
        for x0, x1 in zip(st, st[1:]):
            q0 = Vector((x0, y, deck_z(x0) - 0.35 - 0.4))
            q1 = Vector((x1, y, deck_z(x1) - 0.35 - 0.4))
            b.add(clamp0(beam(q0, q1, 0.7, 0.8, "timber")))

    # --- supports
    bents = 0

    def bent(x, posts=4, batter=0.35, footing=True, xbrace=True):
        nonlocal bents
        zt = deck_z(x) - 0.35 - 0.8  # underside of the stringers
        ys = [-5.6, -2.0, 2.0, 5.6] if posts == 4 else [-5.6, 5.6]
        b.add(kit.bbox(1.0, DECK_W + 0.6, 0.75, "wood_dark", 0.08).move(x, 0, zt - 0.75))  # cap beam
        for y in ys:
            outer = abs(y) > 4
            yb = y + (math.copysign(batter * zt / 4, y) if outer else 0.0)
            b.add(beam((x, yb, 0.0), (x, y, zt - 0.7), 0.6, 0.6, "timber", normal=(1, 0, 0)))
        if footing:  # timber mud sill on a stone footing course
            yo = 5.6 + batter * zt / 4
            b.add(kit.bbox(1.7, 2 * yo + 1.6, 0.55, rng.choice(("stone", "stone_dark")), 0.15).move(x, 0, 0.0)
                  .paint(tint=rng.uniform(0.2, 0.8)))
            b.add(box(1.0, 2 * yo + 1.0, 0.45, "wood_dark").move(x, 0, 0.5))
        if xbrace and zt > 2.2:
            lo, hi = 0.9, zt - 1.0
            b.add(beam((x - 0.42, -5.4, lo), (x - 0.42, 5.4, hi), 0.35, 0.3, "wood_dark", normal=(1, 0, 0)))
            b.add(beam((x + 0.42, 5.4, lo), (x + 0.42, -5.4, hi), 0.35, 0.3, "wood_dark", normal=(1, 0, 0)))
            for y in (-5.6, 5.6):  # iron bolt plates at the brace ends
                b.add(box(0.12, 0.6, 0.6, "iron_dark").move(x + 0.62 * (1 if y > 0 else -1), y * 0.97, hi - 0.3))
        bents += 1

    if t == "plank":
        bent(0.0)
        for sx in (-1, 1):
            bent(sx * (L / 2 - lr), posts=4, xbrace=False)
            # stone sill under each deck end
            b.add(kit.bbox(1.8, DECK_W + 1.0, 0.4, "stone", 0.12).move(sx * (L / 2 - 0.9), 0, 0.0))
    elif t == "trestle":
        for x in (-L / 2 + lr * 0.5, -L / 2 + lr, 0.0, L / 2 - lr, L / 2 - lr * 0.5):
            bent(x)
        for sx in (-1, 1):
            b.add(kit.bbox(1.8, DECK_W + 1.0, 0.4, "stone", 0.12).move(sx * (L / 2 - 0.9), 0, 0.0))
        # longitudinal sway braces between the middle bents
        for y in (-5.6, 5.6):
            x0, x1 = -L / 2 + lr, L / 2 - lr
            b.add(beam((x0, y, 1.2), (x1, y, deck_z(0) - 2.4), 0.35, 0.3, "wood_dark", normal=(0, 1, 0)))
            b.add(beam((x1, y, 1.2), (x0, y, deck_z(0) - 2.4), 0.35, 0.3, "wood_dark", normal=(0, 1, 0)))
    else:
        # laminated arch ribs under the deck, springing from stone pads, posts up to the deck
        span = L * 0.72
        rise = H - 1.9
        for y in (-5.0, 5.0):
            pts = []
            for i in range(11):
                u = i / 10
                x = -span / 2 + span * u
                pts.append(Vector((x, y, rise * math.sin(math.pi * u))))
            for q0, q1 in zip(pts, pts[1:]):
                b.add(clamp0(beam(q0, q1, 0.8, 0.9, "wood", normal=(0, 1, 0))))
                b.add(clamp0(beam(q0 + Vector((0, 0, -0.5)), q1 + Vector((0, 0, -0.5)), 0.85, 0.25, "wood_dark",
                                  normal=(0, 1, 0))))
            for x in (-span / 2, span / 2):
                b.add(kit.bbox(2.4, 2.0, 1.0, "stone", 0.15).move(x, y, 0.0))
            for i in (2, 4, 6, 8):  # spandrel posts
                q = pts[i]
                b.add(beam((q.x, y, q.z + 0.3), (q.x, y, deck_z(q.x) - 1.1), 0.5, 0.5, "timber", normal=(1, 0, 0)))
        for i in (3, 5, 7):  # cross ties between the ribs
            x = -span / 2 + span * i / 10
            z = rise * math.sin(math.pi * i / 10) + 0.2
            b.add(beam((x, -5.0, z), (x, 5.0, z), 0.45, 0.45, "wood_dark", normal=(0, 0, 1)))
        bents = 2
        for sx in (-1, 1):
            b.add(kit.bbox(1.8, DECK_W + 1.0, 0.4, "stone", 0.12).move(sx * (L / 2 - 0.9), 0, 0.0))
    b.stats["bents"] = bents

    # --- railings: posts every ~3.6 along both edges
    m = max(6, int(L / 3.6))
    xs = [-L / 2 + 1.0 + (L - 2.0) * i / m for i in range(m + 1)]
    rail_h = 3.1
    for sy in (-1, 1):
        y = sy * (DECK_W / 2 - 0.1)
        tops = []
        for i, x in enumerate(xs):
            z0 = max(0.0, deck_z(x) - 0.9)
            big = i in (0, len(xs) - 1)
            hgt = deck_z(x) + rail_h + (0.5 if big else 0.0) - z0
            b.add(box(0.5 if not big else 0.75, 0.5 if not big else 0.75, hgt, "timber").move(x, y, z0))
            if big:
                b.add(kit.bbox(0.95, 0.95, 0.3, "wood_dark", 0.08).move(x, y, z0 + hgt))
            tops.append(Vector((x, y, deck_z(x) + rail_h)))
        if t == "trestle":  # sagging rope handrails between the posts, lashed at each post
            for q0, q1 in zip(tops, tops[1:]):
                mid = (q0 + q1) / 2 - Vector((0, 0, 0.35))
                b.add(rope([q0 - Vector((0, 0, 0.2)), mid, q1 - Vector((0, 0, 0.2))], r=0.13, seg=4))
            for q in tops[::3]:  # rope lashings on every third post
                b.add(lashing(0.3, 0.45, seg=6, turns=1)[0].move(q.x, q.y, q.z - 0.45))
        else:
            for q0, q1 in zip(tops, tops[1:]):
                b.add(beam(q0, q1, 0.32, 0.4, "wood_light"))  # handrail
                lo0, lo1 = q0 - Vector((0, 0, 1.5)), q1 - Vector((0, 0, 1.5))
                b.add(beam(lo0, lo1, 0.26, 0.32, "wood"))  # mid rail
                if t == "humped":  # X braces in each panel
                    b.add(beam(lo0 + Vector((0.25, 0, -1.0)), q1 + Vector((-0.25, 0, -0.2)), 0.18, 0.22, "wood_dark",
                               normal=(0, 1, 0)))
    # lanterns on the end posts of the humped bridge, a hanging lantern hook on the plank bridge
    if t == "humped":
        for x in (xs[0], xs[-1]):
            for sy in (-1, 1):
                z = deck_z(x) + rail_h + 0.5 + 0.3
                b.add(box(0.75, 0.75, 0.18, "iron_dark").move(x, sy * (DECK_W / 2 - 0.1), z))
                b.add(box(0.55, 0.55, 0.8, "window_glow").move(x, sy * (DECK_W / 2 - 0.1), z + 0.18),
                      grad=("range", 0.55, 1.0))
                b.add(box(0.85, 0.85, 0.4, "iron_dark").taper(0.0, 0.4, 1.0, 0.25)
                      .move(x, sy * (DECK_W / 2 - 0.1), z + 0.98))
    b.socket("end_a", -L / 2, 0, 0)
    b.socket("end_b", L / 2, 0, 0)
    b.stats["pieces"] = len(b.pieces)
