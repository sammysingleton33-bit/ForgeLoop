"""Village well: round stone curb of coursed blocks with capstones, water inside, two
timber posts with braces carrying a small gable roof (kingdom tiles or thatch from the
shared kit), a winch (axle, rope drum, iron crank) with a rope and a hanging bucket.

Variants mix roof style, curb size/height, a paved apron, a stone trough, a spare bucket
and flowers. Front faces -Y. Socket `interact`: where a character stands to use the well
(in front of the curb, ground level).
"""

import math

from lib import kit
from lib.geo import Vector, box, cylinder, lathe

from generators._kingdom_props_common import (KINGDOMS, border, emblem, emblem_colors, field, kcol, ring_solid,
                                              rope, sheet, wheel)

NAME = "prop_well"
VERSION = 1
CATEGORY = "prop"
BUDGET = "prop"
COLLISION = {"fidelity": "PreciseConvexDecomposition"}
CHECKS = {"min_blocks": 20, "min_posts": 2, "min_bucket": 1}
DEFAULT_VARIANTS = 4
HERO_VIEW = {"azimuth": 32, "elevation": 22}


def variants(n, seed):
    out = []
    for i in range(n):
        out.append({
            "kingdom": KINGDOMS[i % 4],
            "roof": ("tile", "pyramid", "frame", "thatch")[i % 4],
            "radius": (3.1, 3.5, 3.0, 3.3)[i % 4],
            "curb_h": (3.0, 2.6, 3.2, 2.8)[i % 4],
            "apron": i % 4 in (1, 3),
            "trough": i % 4 == 2,
            "seed": seed * 1000 + i,
        })
    return out


def asset_id(i, p):
    return f"{CATEGORY}_well_{i + 1:02d}"


def bucket(color="wood", r=0.62, h=1.0, handle=True):
    out = [lathe([(0.0, 0.0), (r * 0.82, 0.0), (r, h), (r * 0.9, h), (r * 0.78, h * 0.25), (0.0, h * 0.25)], 8,
                 color)]
    for zz in (h * 0.6,):
        out.append(cylinder(r * 0.86 + (r * 0.14) * zz / h + 0.04, r * 0.88 + (r * 0.14) * zz / h + 0.04, 0.12, 8,
                            "iron_dark").move(0, 0, zz))
    if handle:
        pts = [(-r, 0, h * 0.85), (-r * 0.75, 0, h + 0.45), (0, 0, h + 0.65), (r * 0.75, 0, h + 0.45), (r, 0, h * 0.85)]
        from lib.geo import tube
        out.append(tube(pts, [0.06] * 5, 4, "iron_dark"))
    return out


def build(b, p):
    rng = b.rng
    k = p["kingdom"]
    R = p["radius"]
    H = p["curb_h"]
    r_in = R - 1.05
    z0 = 0.0
    blocks = 0
    # paved apron (ring of flagstones) for some variants
    if p["apron"]:
        n = 9 if p["roof"] == "thatch" else 12
        ra, rb = R - 0.2, R + 1.5
        for i in range(n):
            a = math.tau * (i + rng.uniform(-0.05, 0.05)) / n
            fl = box(math.tau * (ra + rb) / 2 / n - 0.18, rb - ra, 0.4, rng.choice(("cobble", "stone_light", "stone")))
            fl.rotate(a + math.pi / 2, "Z").move(math.cos(a) * (ra + rb) / 2, math.sin(a) * (ra + rb) / 2, 0)
            b.add(fl.paint(tint=rng.uniform(0.1, 0.9)))
        z0 = 0.3
    # curb core + coursed blocks + capstones
    b.add(ring_solid(r_in, R - 0.18, H, 10, "stone_dark").move(0, 0, z0 + H / 2), grad=("range", 0.2, 0.7))
    courses = 3 if H >= 2.9 else 2
    ch = (H - 0.45) / courses
    for c in range(courses):
        n = max(8, round(math.tau * R / 2.4))
        for i in range(n):
            a = math.tau * (i + 0.5 * (c % 2) + rng.uniform(-0.06, 0.06)) / n
            seg = math.tau * R / n
            bl = box(seg - 0.16, 0.55, ch - 0.1, rng.choice(("stone", "stone", "stone_light", "stone_dark")))
            rr = R - 0.2 + rng.uniform(-0.05, 0.06)
            bl.rotate(a + math.pi / 2 + rng.uniform(-0.04, 0.04), "Z").move(math.cos(a) * rr, math.sin(a) * rr,
                                                                          z0 + c * ch + 0.05)
            b.add(bl.paint(tint=rng.uniform(0.1, 0.9), grad=("range", 0.3, 0.8)))
            blocks += 1
    nc = max(8, round(math.tau * R / 2.4))
    for i in range(nc):
        a = math.tau * (i + 0.25) / nc
        seg = math.tau * (R - 0.4) / nc
        cs = box(seg + 0.25, (R - r_in) + 0.4, 0.45, rng.choice(("stone_light", "stone_pale", "stone_light")))
        rr = (R + r_in) / 2 + 0.05
        cs.rotate(a + math.pi / 2, "Z").move(math.cos(a) * rr, math.sin(a) * rr, z0 + H - 0.45)
        b.add(cs.jitter(rng, 0.04).paint(tint=rng.uniform(0.1, 0.9)))
        blocks += 1
    b.stats["blocks"] = blocks
    b.add(cylinder(r_in + 0.05, r_in + 0.05, 0.2, 10, "water_deep").move(0, 0, z0 + H - 1.1),
          grad=("range", 0.4, 0.9))
    top = z0 + H

    px = (R + r_in) / 2
    zt = top + rng.uniform(4.4, 4.8)
    style = p["roof"]
    if style in ("tile", "thatch"):
        two_posts(b, px, zt, zt)
        build_gable(b, k, px, zt, style, rng)
        ax = px
    elif style == "pyramid":
        ax = build_pyramid(b, k, px, zt, top, rng)
    else:
        build_frame(b, k, px, zt + 1.0, rng)
        ax = px
    b.stats["posts"] = 4 if style == "pyramid" else 2
    build_winch(b, k, p, R, r_in, ax, top, z0, rng, wheel_crank=(style == "frame"))


def two_posts(b, px, zt, h):
    """Two posts set into the curb at +-px with knee braces under the top beams."""
    for sx in (-1, 1):
        b.add(kit.bbox(0.75, 0.75, h, "timber", 0.08).move(sx * px, 0, 0), grad=("range", 0.2, 0.8))
        for sy in (-1, 1):
            b.add(kit.oriented_box((sx * px, sy * 0.3, zt - 1.6), (sx * px, sy * 1.9, zt - 0.05), 0.4, 0.4, "timber",
                                   Vector((1, 0, 0))))


def build_pyramid(b, k, px, zt, top, rng):
    """Frostmere: four corner posts, square top frame, crisp square-pyramid shingle roof (kit
    cone_roof with 4 sides: stepped shingle courses) with a silver finial. Returns axle support x."""
    a = px * 0.72
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.add(kit.bbox(0.65, 0.65, zt, "timber", 0.07).move(sx * a, sy * a, 0), grad=("range", 0.2, 0.8))
        b.add(box(0.55, 2 * a + 0.6, 0.55, "wood_dark").move(sx * a, 0, zt))  # top frame (Y)
        b.add(box(0.5, 2 * a, 0.5, "wood_dark").move(sx * a, 0, top + 1.75))  # axle bearer
    for sy in (-1, 1):
        b.add(box(2 * a + 0.6, 0.55, 0.55, "wood_dark").move(0, sy * a, zt))  # top frame (X)
    half = a + 1.15  # eave half-side
    roof = kit.cone_roof(half * math.sqrt(2) - 0.6, 3.4, seg=4, color=kcol(k, "roof"), overhang=0.6, flare=True,
                         finial=kcol(k, "trim"), rows=3)
    for pc in roof:
        b.add(pc.move(0, 0, zt + 0.5), tag="roof")
    for sx in (-1, 1):  # king struts from the frame up into the roof
        b.add(kit.oriented_box((sx * a, 0, zt + 0.5), (0, 0, zt + 2.2), 0.35, 0.35, "timber", Vector((0, 1, 0))))
    return a


def build_frame(b, k, px, zt, rng):
    """Thornwood: open crank frame, no roof: two tall braced posts, a heavy head beam with an
    emerald oak-leaf board, raking side struts, emerald pennant."""
    two_posts(b, px, zt, zt)
    b.add(kit.bbox(2 * px + 1.8, 0.85, 0.75, "wood_dark", 0.1).move(0, 0, zt))  # head beam
    for sx in (-1, 1):
        for sy in (-1, 1):  # raking struts down to the ground outside the curb
            b.add(kit.oriented_box((sx * px, sy * 0.2, zt - 2.0), (sx * (px + 0.4), sy * 2.6, 0.0), 0.4, 0.4,
                                   "timber", Vector((1, 0, 0))))
    # kingdom board (ivory border, emerald field, oak leaf) on the head beam: reads at 80 studs
    emb = {"red": "crown", "blue": "star", "green": "oak", "yellow": "sun"}[k]
    b.add(kit.bbox(2.7, 0.3, 1.7, border(k), 0.06).move(0, -0.55, zt + 0.55))
    b.add(kit.bbox(2.3, 0.3, 1.35, field(k), 0.06).move(0, -0.65, zt + 0.72))
    for pc in emblem(emb, 1.25, *emblem_colors(k, emb), depth=0.14, mid=None):
        b.add(pc.move(0, -0.88, zt + 1.4))
    # pennant on the right post
    fx, fz = px, zt + 0.75
    b.add(cylinder(0.1, 0.08, 2.4, 6, "timber").move(fx, 0, fz))

    def pos(u, v):
        return (fx + 0.1 + u * 2.2, 0.15 * math.sin(u * 4) * u, fz + 2.3 - v * 1.0 * (1 - 0.75 * u) - 0.2 * u * u)

    b.add(sheet([0.0, 0.33, 0.66, 1.0], [0.0, 0.5, 1.0], pos, 0.16, field(k),
                lambda kind, i, j: border(k) if kind == "edge" else None), grad=("range", 0.3, 0.9))


def build_gable(b, k, px, zt, style, rng):
    """Gable roof from the shared kit on cross beams and purlins, timber gable trusses."""
    for sx in (-1, 1):
        b.add(box(0.7, 4.6, 0.6, "wood_dark").move(sx * px, 0, zt))  # cross beam
    b.add(box(2 * px + 1.6, 0.7, 0.6, "wood_dark").move(0, 0, zt))  # tie beam
    for sy in (-1, 1):  # eave purlins
        b.add(box(2 * px + 2.0, 0.5, 0.45, "timber").move(0, sy * 2.05, zt + 0.6))
    # roof (shared kit): ridge along X; tile = terracotta with kingdom-red trim (well_01),
    # thatch = muted straw with pinned ridge + layered rows, gold accents (well_04)
    pitch = rng.uniform(48, 53) if style == "thatch" else rng.uniform(40, 45)
    color = "thatch" if style == "thatch" else "clay"
    ridge = "thatch_dark" if style == "thatch" else kcol(k, "roof_dark")
    roof, rise = kit.gable_roof(4.6, 2 * px + 1.0, pitch, overhang=1.1, gable_overhang=0.9,
                                thickness=0.55 if style == "tile" else 0.72, color=color, rows=3,
                                ridge_color=ridge, style=style, rng=rng, pins=True, trim=kcol(k, "roof"))
    zr = zt + 1.05
    for pc in roof:
        b.add(pc.rotate(math.pi / 2, "Z").move(0, 0, zr), tag="roof")
    # gable trusses: king post + struts in timber
    for sx in (-1, 1):
        xg = sx * (px + 0.55)
        n_ = Vector((sx, 0, 0))
        b.add(kit.oriented_box((xg, 0, zr - 0.4), (xg, 0, zr + rise - 0.3), 0.45, 0.35, "timber", n_))
        for s in (-1, 1):
            b.add(kit.oriented_box((xg, s * 2.1, zr), (xg, s * 0.25, zr + rise * 0.8), 0.4, 0.35, "timber", n_))
    if style == "thatch":  # Sunspire: gold sun standing on the ridge on a short post + gold finial
        zs = zr + rise + 1.0
        b.add(cylinder(0.14, 0.12, 1.6, 6, "timber").move(0, 0, zs - 0.4))
        for pc in emblem("sun", 2.8, *emblem_colors(k, "sun"), depth=0.26, mid=None):
            b.add(pc.move(0, 0, zs + 2.4))
        b.add(lathe([(0.25, 0.0), (0.42, 0.25), (0.3, 0.6), (0.0, 0.75)], 6, "gold").move(px + 1.2, 0, zr + rise + 0.6))
    else:  # gold ridge finials on the terracotta roof
        for sx in (-1, 1):
            b.add(lathe([(0.0, 0.0), (0.3, 0.1), (0.32, 0.4), (0.0, 0.85)], 6, kcol(k, "trim"))
                  .move(sx * (px + 1.0), 0, zr + rise + 0.45))


def build_winch(b, k, p, R, r_in, px, top, z0, rng, wheel_crank=False):
    # winch: axle through the posts, rope drum, iron crank (or a big spoked hand-wheel) on +X
    za = top + 2.3
    span = 2 * px + 1.6
    b.add(cylinder(0.24, 0.24, span, 8, "wood_dark").rotate(math.pi / 2, "Y").move(-span / 2, 0, za))
    b.add(cylinder(0.55, 0.55, 2.0, 8, "wood").rotate(math.pi / 2, "Y").move(-1.0, 0, za))
    b.add(cylinder(0.68, 0.68, 1.4, 8, "rope").rotate(math.pi / 2, "Y").move(-0.7, 0, za))
    xc = span / 2
    if wheel_crank:
        b.add([pc.move(xc + 0.1, 0, za) for pc in wheel(1.7, 0.32, 6, 10, wood="wood", tyre="wood_dark",
                                                       hub="wood_dark", cap=None, hub_seg=6)])
        for i in range(4):  # handle pegs round the rim
            a = math.tau * (i + 0.5) / 4
            b.add(cylinder(0.11, 0.11, 0.7, 5, "wood_light").rotate(math.pi / 2, "Y")
                  .move(xc + 0.2, math.cos(a) * 1.75, za + math.sin(a) * 1.75))
    else:
        b.add(box(0.2, 0.3, 1.4, "iron_dark").move(xc - 0.1, 0, za - 1.25))
        b.add(kit.oriented_box((xc - 0.2, 0, za - 1.15), (xc + 0.9, 0, za - 1.15), 0.22, 0.22, "iron",
                               Vector((0, 0, 1))))
        b.add(cylinder(0.16, 0.16, 0.8, 6, "wood_dark").rotate(math.pi / 2, "Y").move(xc + 0.25, 0, za - 1.15))
    # rope + hanging bucket
    bz = top + 0.25
    b.add(rope([(0.15, -0.55, za - 0.4), (0.15, -0.55, bz + 1.6)], r=0.1), tag="rope")
    for pc in bucket():
        b.add(pc.move(0.15, -0.55, bz), tag="bucket")
    # spare bucket on the rim, or a stone trough
    if p["trough"]:
        tx = -(R + 2.2)
        b.add(kit.bbox(2.0, 4.2, 1.4, "stone", 0.15).move(tx, 0.4, 0))
        b.add(box(1.4, 3.6, 0.2, "water").move(tx, 0.4, 1.2))
    elif not p["apron"]:
        a = math.radians(rng.uniform(-60, -40))
        for pc in bucket(handle=False):
            b.add(pc.move(math.cos(a) * (R + r_in) / 2, math.sin(a) * (R + r_in) / 2, top))
    # leafy flower tufts at the foot of the curb
    for i in range(1 if p["roof"] == "thatch" else 2):
        aa = math.radians(-140 + 75 * i + rng.uniform(-12, 12))
        rr = R + 0.35
        cx, cy = math.cos(aa) * rr, math.sin(aa) * rr
        tuft = lathe([(0.0, 0.0), (0.55, 0.15), (0.6, 0.45), (0.3, 0.8), (0.0, 0.9)], 5, "leaf_mid", smooth=True)
        b.add(tuft.move(cx, cy, z0), grad=("range", 0.1, 0.9))
        fc = rng.choice(("flower_yellow", "flower_white", "flower_red"))
        for j in range(2):
            fa = rng.uniform(0, math.tau)
            b.add(lathe([(0.0, 0.0), (0.2, 0.08), (0.0, 0.22)], 4, fc)
                  .move(cx + math.cos(fa) * 0.3, cy + math.sin(fa) * 0.3, z0 + 0.62))
    b.socket("interact", 0, -(R + 1.8), 0)
    b.stats["roof"] = b.count_tag("roof")
    b.stats["bucket"] = 1
    b.stats["pieces"] = len(b.pieces)
