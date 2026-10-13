"""Hay: a big domed rick (pitchfork, ladder, weighted ropes), round bales, a pyramid of square
bales, a loaded hay wain, pole stacks (stogs) on branch platforms, and a mixed pile with a
wheelbarrow. Soft lumpy hay masses (noise-displaced, smooth) with straw tufts poking out,
twine bands, and the farm tools that tell the story.

Front faces Blender -Y; socket `interact` marks where a character stands to fork/collect hay.
"""

import math

from lib import kit
from lib.geo import Vector, box, cylinder, frustum_box, lathe

from generators import _farm_common as fc

NAME = "farm_haystack"
VERSION = 1
CATEGORY = "farm"
BUDGET = "prop"
COLLISION = {"fidelity": "Hull"}
CHECKS = {"min_hay": 1}
DEFAULT_VARIANTS = 6

KINDS = ["rick", "rounds", "squares", "cart", "stogs", "pile"]


def asset_id(i, params):
    return f"{CATEGORY}_haystack_{i + 1:02d}"


def variants(n, seed):
    return [{"kind": KINDS[i % len(KINDS)], "seed": seed * 1000 + 500 + i} for i in range(n)]


# ------------------------------------------------------------------ helpers

def placed(pieces, x=0.0, y=0.0, z=0.0, rz=0.0):
    return [q.rotate(rz, "Z").move(x, y, z) if rz else q.move(x, y, z) for q in pieces]


def stuck_fork(x, y, z, tilt, heading, length=5.8):
    """Pitchfork with its tines buried at (x, y, z), handle tilted `tilt` rad from vertical."""
    out = []
    for q in fc.pitchfork(length):
        q.move(0, 0, -(length + 0.2)).rotate(math.pi + tilt, "Y").rotate(heading, "Z").move(x, y, z)
        out.append(q)
    return out


def ladder(rng, h=8.0, w=1.5, rungs=7):
    out = []
    for s in (-1, 1):
        out.append(box(0.24, 0.2, h, "wood").move(s * w / 2, 0, 0).jitter(rng, 0.02))
    for k in range(rungs):
        z = 0.7 + (h - 1.1) * k / (rungs - 1)
        out.append(box(w + 0.2, 0.16, 0.16, "wood_light").move(0, 0, z))
    return out


def rope_over(rng, prof, ang, lift=0.32, z_min=2.0, r=0.09):
    """Rope thrown over a lathe-profile stack in the vertical plane at angle `ang`, plus the two
    hanging weight stones. Returns pieces."""
    pts_side = [(rr + lift, z + lift * 0.5) for rr, z in prof if z >= z_min and rr > 0.3]
    top_z = max(z for _, z in prof) + lift
    c, s = math.cos(ang), math.sin(ang)
    pts = [(c * rr, s * rr, z) for rr, z in pts_side]
    pts += [(0.0, 0.0, top_z)]
    pts += [(-c * rr, -s * rr, z) for rr, z in reversed(pts_side)]
    out = [fc.tube(pts, [r] * len(pts), 4, "rope")]
    for sg in (-1, 1):
        rr, z = pts_side[0]
        st = fc.fieldstone(rng, 0.75, 0.6, 0.7, rng.choice(("stone", "granite")))
        out.append(st.move(sg * c * (rr + 0.25), sg * s * (rr + 0.25), z - 1.2))
        out.append(fc.tube([(sg * c * rr, sg * s * rr, z), (sg * c * (rr + 0.25), sg * s * (rr + 0.25), z - 0.55)],
                           [r, r], 4, "rope"))
    return out


# ------------------------------------------------------------------ kinds

def rick(b, rng):
    H = 8.4

    def R(z):  # dome radius at height z
        t = z / H
        return 4.6 + 0.55 * math.sin(min(1.0, t / 0.3) * math.pi / 2) - 4.6 * max(0.0, (t - 0.3) / 0.7) ** 1.6

    prof, cols = fc.layered_profile(R, H, 4, lip=0.28)
    b.add(fc.hay_mound(rng, prof, 14, "hay", 0.3, 0.55, bands=cols), tag="hay")
    skirt = lathe([(4.4, 0.0), (6.0, 0.0), (5.6, 0.32), (4.7, 0.62)], 12, "hay_dark", smooth=True)
    skirt.noise_displace(0.25, 0.7, rng.uniform(0, 50))
    b.add(skirt.paint(grad=("range", 0.2, 0.9)), tag="hay")
    b.add(cylinder(0.17, 0.14, 2.4, 5, "wood").move(0.1, 0, 7.8), tag="pole")
    b.add(fc.spindle(0.45, 1.2, "thatch_dark", seg=5).move(0.1, 0, 9.6), tag="pole")
    for a in (0.4, 0.4 + math.pi / 2):
        b.add(rope_over(rng, prof, a), tag="rope")
    b.add(fc.straw_tufts(rng, prof, 40, lo=0.08, hi=0.85), tag="tuft")
    # pitchfork leaning on the front, ladder on the side
    b.add([q.rotate(-0.55, "X").rotate(-0.25, "Z").move(2.2, -6.6, 0) for q in fc.pitchfork(6.4)], tag="tool")
    b.add([q.rotate(-0.38, "X").rotate(math.radians(-68), "Z").move(-5.6, -1.6, 0) for q in ladder(rng, 7.6)],
          tag="tool")
    b.socket("interact", 2.0, -7.2, 0.0)


def rounds(b, rng):
    r, w = 1.75, 2.6
    for i, yy in enumerate((-r, r)):
        x = rng.uniform(-0.15, 0.15)
        b.add(fc.round_bale(r, w).move(x, yy, 0), tag="hay")
        for u in (-0.55, 0.55):
            b.add(fc.twine_ring(r + 0.03).move(x + u, yy, r), tag="twine")
    top_z = r * math.sqrt(3)
    b.add(fc.round_bale(r, w).rotate(0.12, "Z").move(0.2, 0, top_z), tag="hay")
    for u in (-0.55, 0.55):
        b.add(fc.twine_ring(r + 0.03).rotate(0.12, "Z").move(0.2 + u, 0.07 * u, top_z + r), tag="twine")
    # one bale stood on its end, one rolled out in front
    up = fc.round_bale(r * 0.95, w * 0.95).move(0, 0, -r * 0.95).rotate(math.pi / 2, "Y")
    b.add(up.move(3.2, 1.0, w * 0.95 / 2), tag="hay")
    b.add(fc.twine_ring(r * 0.95 + 0.03).rotate(math.pi / 2, "Y").move(3.2, 1.0, w * 0.95 / 2 + 0.5), tag="twine")
    lone = fc.round_bale(r * 0.92, w * 0.95).rotate(math.radians(60), "Z").move(3.6, -2.9, 0)
    b.add(lone, tag="hay")
    # spilled straw at the foot
    for k in range(3):
        pr = [(0.0, 0.0), (1.1, 0.0), (0.9, 0.25), (0.0, 0.4)]
        b.add(fc.hay_mound(rng, pr, 7, "straw", 0.12, 1.2, sx=1.4).move(rng.uniform(-1.5, 2.5),
                                                                         rng.uniform(-4.0, -3.0), 0), tag="hay")
    b.socket("interact", 0.0, -4.6, 0.0)


def squares(b, rng):
    L, w, h = 3.0, 1.6, 1.35
    layers = [
        [(-1.55, -0.85, 0), (1.55, -0.85, 0), (-1.55, 0.85, 0), (1.55, 0.85, 0)],
        [(-1.7, 0.0, 90), (0.0, 0.0, 90), (1.7, 0.0, 90)],
        [(0.0, -0.85, 0), (0.0, 0.85, 0)],
        [(0.0, 0.0, 90)],
    ]
    n = 0
    for li, lay in enumerate(layers):
        for (x, y, rot) in lay:
            bale = fc.square_bale(rng, L, w, h, rng.choice(("hay", "hay", "straw")))
            jx, jy, jr = rng.uniform(-0.12, 0.12), rng.uniform(-0.1, 0.1), rng.uniform(-0.06, 0.06)
            b.add(placed(bale, x + jx, y + jy, li * (h - 0.04), math.radians(rot) + jr), tag="hay")
            n += 1
    # a fallen bale and a burst one spilling straw
    fb = fc.square_bale(rng, L, w, h, "hay")
    b.add([q.rotate(math.radians(78), "X").rotate(0.5, "Z").move(4.2, -1.8, 0.75) for q in fb], tag="hay")
    pr = [(0.0, 0.0), (1.6, 0.0), (1.4, 0.4), (0.7, 0.75), (0.0, 0.85)]
    b.add(fc.hay_mound(rng, pr, 9, "straw", 0.18, 0.9, sx=1.5).move(-4.0, -1.6, 0), tag="hay")
    b.add([q.move(-4.0, -1.6, 0) for q in fc.straw_tufts(rng, pr, 8, sx=1.5)], tag="tuft")
    b.add(stuck_fork(-4.0, -1.6, 0.35, 0.45, 0.6), tag="tool")
    b.socket("interact", 0.0, -3.4, 0.0)


def cart(b, rng):
    R = 2.0
    bz = 2.25  # bed underside
    BL, BW = 7.6, 3.8
    for s in (-1, 1):
        b.add(placed(fc.wheel(R, 0.38, 8, "wood", "iron_dark", 12), 0.6, s * (BW / 2 + 0.55), R), tag="wheel")
    b.add(box(0.36, BW + 1.6, 0.36, "wood_dark", base=False).move(0.6, 0, R), tag="cart")
    b.add(kit.bbox(BL, BW, 0.32, "wood", 0.08).move(0, 0, bz), tag="cart")
    for s in (-1, 1):  # side boards + hay ladders (racks)
        b.add(box(BL, 0.22, 0.7, "wood_light").move(0, s * (BW / 2 - 0.11), bz + 0.3), tag="cart")
        top = bz + 2.3
        b.add(box(BL + 0.6, 0.24, 0.26, "wood", base=False).move(0, s * (BW / 2 + 0.55), top), tag="cart")
        for k in range(7):
            x = -BL / 2 + 0.3 + (BL - 0.6) * k / 6
            b.add(kit.oriented_box((x, s * (BW / 2 - 0.1), bz + 0.3), (x, s * (BW / 2 + 0.55), top), 0.2, 0.2,
                                   "wood", Vector((0, 0, 1))), tag="cart")
    for s in (-1, 1):  # shafts resting on the ground
        b.add(kit.oriented_box((-BL / 2 + 0.6, s * 1.15, bz + 0.05), (-BL / 2 - 5.2, s * 1.0, 0.25), 0.28, 0.28,
                               "wood", Vector((0, 0, 1))), tag="cart")
    b.add(box(0.26, 2.6, 0.26, "wood_dark", base=False).move(-BL / 2 - 2.5, 0, 1.25), tag="cart")
    # the load: a big lumpy mound overflowing the racks
    prof = [(0.0, 0.0), (2.4, 0.0), (2.9, 0.9), (2.85, 2.2), (2.2, 3.3), (1.1, 3.9), (0.0, 4.1)]
    load = fc.hay_mound(rng, prof, 14, "hay", 0.4, 0.85, sx=1.45, sy=0.9,
                        bands=("hay_dark", "hay", "hay", "thatch", "straw", "straw")).move(0, 0, bz + 0.3)
    b.add(load, tag="hay")
    b.add([q.move(0, 0, bz + 0.3) for q in fc.straw_tufts(rng, prof, 34, sx=1.45, sy=0.9, lo=0.25)], tag="tuft")
    for x in (-1.6, 1.6):  # ropes across the load
        pts = [(x, -2.75, bz + 1.0), (x, -2.4, bz + 3.0), (x, -1.2, bz + 4.1), (x, 0.0, bz + 4.5),
               (x, 1.2, bz + 4.1), (x, 2.4, bz + 3.0), (x, 2.75, bz + 1.0)]
        b.add(fc.tube(pts, [0.09] * len(pts), 4, "rope"), tag="rope")
    b.add(stuck_fork(2.2, -0.6, bz + 3.3, 0.5, 0.4, 5.6), tag="tool")
    b.socket("interact", 0.0, -4.6, 0.0)
    b.socket("hitch", -BL / 2 - 5.2, 0.0, 0.0)


def stog(rng, h=8.9, r=2.7):

    def R(z):  # bulging cone: widest a quarter of the way up, drawn to a point
        t = z / h
        return r * (1.0 + 0.1 * math.sin(min(1.0, t / 0.25) * math.pi / 2)) * (1.0 - max(0.0, t - 0.2) / 0.8) ** 0.9

    prof, cols = fc.layered_profile(R, h, 3, lip=0.2, tuck=0.08)
    out = [fc.hay_mound(rng, prof, 12, "hay", 0.2, 0.6, bands=cols).move(0, 0, 0.55)]
    out.append(cylinder(0.15, 0.12, h + 1.8, 5, "wood").move(0, 0, 0))
    for a in (0.3, 0.3 + math.pi / 2):  # branch platform under the stack
        lg = cylinder(0.2, 0.18, r * 2.5, 6, "bark")
        lg.move(0, 0, -r * 1.25).rotate(math.pi / 2, "Y").rotate(a, "Z").move(0, 0, 0.32)
        out.append(lg)

    out.append(fc.spindle(0.35, 1.0, "thatch_dark", seg=5).move(0, 0, h + 0.4))
    out += [q.move(0, 0, 0.55) for q in fc.straw_tufts(rng, prof, 22, lo=0.1, hi=0.75)]
    return out


def stogs(b, rng):
    b.add(placed(stog(rng, 9.4, 2.8), -2.2, 0.6), tag="hay")
    b.add(placed(stog(rng, 6.8, 2.1), 3.4, -0.4), tag="hay")
    b.add([q.rotate(0.35, "X").rotate(-0.4, "Z").move(1.0, -3.4, 0) for q in fc.rake(5.8)], tag="tool")
    b.socket("interact", 0.5, -4.0, 0.0)


def wheelbarrow(rng):
    out = []
    tray = frustum_box(2.6, 1.9, 2.1, 1.4, 0.9, "wood")
    tray.rotate(math.pi, "X").move(0, 0, 0.9)  # wide at the top
    out.append(tray.move(0, 0, 1.0))
    out.append(fc.hay_mound(rng, [(0.0, 0.0), (1.2, 0.0), (1.0, 0.5), (0.0, 0.8)], 7, "hay", 0.12, 1.0,
                            sx=1.3, sy=0.85).move(0, 0, 1.75))
    out += placed(fc.wheel(0.75, 0.25, 6, "wood", "iron_dark", 10, hub_len=0.5), -1.8, 0, 0.75)
    for s in (-1, 1):
        out.append(kit.oriented_box((-1.9, s * 0.4, 0.75), (2.6, s * 0.75, 1.15), 0.2, 0.2, "wood_dark",
                                    Vector((0, 0, 1))))
        out.append(box(0.18, 0.18, 1.0, "wood_dark").move(0.9, s * 0.6, 0.0))
    return out


def pile(b, rng):
    prof = [(0.0, 0.0), (3.5, 0.0), (3.8, 0.6), (3.1, 1.7), (1.8, 2.7), (0.0, 3.1)]
    b.add(fc.hay_mound(rng, prof, 14, "hay", 0.42, 0.85, sx=1.3, bands=("hay_dark", "hay", "thatch", "hay", "straw"))
          .move(-1.5, 0.6, 0), tag="hay")
    b.add([q.move(-1.5, 0.6, 0) for q in fc.straw_tufts(rng, prof, 30, sx=1.3, lo=0.1)], tag="tuft")
    for k, (x, y, z, rot) in enumerate(((3.6, 1.2, 0.0, 0.1), (3.5, 1.3, 1.31, -0.15))):
        b.add(placed(fc.square_bale(rng, 3.0, 1.6, 1.35, "hay"), x, y, z, rot), tag="hay")
    b.add(placed(wheelbarrow(rng), 3.4, -2.6, 0.0, 0.35), tag="tool")
    b.add(stuck_fork(-0.6, 0.2, 2.1, 0.5, -2.4), tag="tool")
    b.add([q.rotate(0.3, "X").rotate(-0.2, "Z").move(-5.6, 2.6, 0) for q in fc.rake(5.4)], tag="tool")
    b.add(placed(fc.basket(rng, 0.8, 0.85, "wood_light", fill="straw"), -4.8, -2.4), tag="tool")
    b.socket("interact", -1.5, -4.6, 0.0)


def build(b, p):
    rng = b.rng
    {"rick": rick, "rounds": rounds, "squares": squares, "cart": cart, "stogs": stogs, "pile": pile}[p["kind"]](b, rng)
    b.stats["hay"] = b.count_tag("hay")
