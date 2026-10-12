"""Village goods clusters: crates, barrels, sacks and baskets stacked to dress streets,
docks, markets and storehouses. Six arrangements, kingdom accents through tarps, cloth
bolts, painted lids and produce colours.

  crates     crate pyramid under a kingdom tarp tied with rope, a sack and a small cask
  barrels    three standing barrels, one lying on chocks with a spigot, a bucket
  sacks      grain-sack heap, a basket of grain with a scoop, a crate
  produce    plank pallet with baskets of apples / cabbages, pumpkins on the ground
  merchant   crates with kingdom cloth bolts, rope coil and clay jars
  storehouse tall two-level crate stack with a barrel on top, a ladder and sacks

Front faces -Y. Socket `interact` = in front of the cluster (pick-up / loot point).
"""

import math

from lib import kit
from lib.geo import Vector, box, cylinder, icosphere, lathe

from generators._kingdom_props_common import KINGDOMS, barrel, border, crate, field, kcol, rope, sack, sheet, sweep_loop

NAME = "prop_goods"
VERSION = 1
CATEGORY = "prop"
BUDGET = "prop"
COLLISION = {"fidelity": "Hull"}
CHECKS = {"min_items": 4}
DEFAULT_VARIANTS = 6
HERO_VIEW = {"azimuth": 32, "elevation": 24}
TYPES = ("crates", "barrels", "sacks", "produce", "merchant", "storehouse")


def variants(n, seed):
    return [{"kingdom": KINGDOMS[i % 4], "type": TYPES[i % 6], "seed": seed * 1000 + i} for i in range(n)]


def asset_id(i, p):
    return f"{CATEGORY}_goods_{p['type']}_{i // 6 + 1:02d}"


class Items:
    def __init__(self, b):
        self.b = b
        self.n = 0

    def add(self, pieces, x=0.0, y=0.0, z=0.0, rot=0.0):
        for pc in pieces if isinstance(pieces, (list, tuple)) else [pieces]:
            self.b.add(pc.rotate(rot, "Z").move(x, y, z))
        self.n += 1


def basket(fill, rng, r=0.95, h=0.9, n_fill=5):
    """Wicker basket (weave bands) heaped with apples / cabbages / grain."""
    out = [lathe([(0.0, 0.0), (r * 0.75, 0.0), (r, h), (r * 0.88, h), (0.0, h * 0.4)], 8, "wood_pale")]
    out.append(cylinder(r * 0.9, r * 0.96, 0.14, 8, "wood_light").move(0, 0, h * 0.45))
    out.append(sweep_loop([(r * 0.88, h - 0.05), (r + 0.08, h - 0.05), (r + 0.08, h + 0.1), (r * 0.88, h + 0.1)], 8,
                          "wood_light"))
    if fill == "grain":
        out.append(lathe([(r * 0.9, 0.0), (r * 0.6, 0.3), (0.0, 0.45)], 8, "wheat").move(0, 0, h - 0.1))
    else:
        col, rad = {"apple": ("apple_red", 0.3), "cabbage": ("cabbage", 0.4), "pear": ("leaf_yellow", 0.3)}[fill]
        for j in range(n_fill):
            a = math.tau * j / max(1, n_fill - 1)
            rr = 0.0 if j == n_fill - 1 else r * 0.5
            f = icosphere(rad, 1, col)
            f.noise_displace(rad * 0.1, 2.0, rng.uniform(0, 50))
            out.append(f.move(math.cos(a) * rr, math.sin(a) * rr, h - 0.05 + rad * (0.6 if rr else 1.1)))
    return out


def pumpkin(r=0.8, color="pumpkin"):
    prof = [(0.0, 0.0), (r * 0.7, 0.05), (r, r * 0.45), (r * 0.85, r * 0.95), (0.0, r * 1.05)]
    out = [lathe(prof, 8, color, smooth=True).paint(grad=("range", 0.3, 0.95))]
    out.append(cylinder(0.1, 0.07, 0.35, 5, "leaf_dark").move(0, 0, r * 1.0))
    return out


def jar(h=1.6, r=0.55):
    return [lathe([(0.0, 0.0), (r * 0.6, 0.0), (r, h * 0.35), (r * 0.9, h * 0.65), (r * 0.42, h * 0.85),
                   (r * 0.5, h), (0.0, h * 0.97)], 8, "clay", smooth=True).paint(grad=("range", 0.3, 0.9))]


def lying_barrel(rng, h=2.3, r=0.85):
    out = [pc.rotate(math.pi / 2, "Y") for pc in barrel(h, r, lid=True)]
    out = [pc.move(-h / 2, 0, r * 1.18) for pc in out]
    for sx in (-1, 1):  # chocks
        out.append(kit.oriented_box((sx * h * 0.3, -0.85, 0.0), (sx * h * 0.3, -0.35, 0.0), 0.3, 0.45, "wood_dark",
                                    Vector((0, 0, 1))))
        out.append(kit.oriented_box((sx * h * 0.3, 0.35, 0.0), (sx * h * 0.3, 0.85, 0.0), 0.3, 0.45, "wood_dark",
                                    Vector((0, 0, 1))))
    out.append(cylinder(0.12, 0.12, 0.45, 5, "iron").rotate(math.pi / 2, "X").move(0, -r * 1.05, r * 1.18))  # spigot
    return out


def tarp(k, W, D, H, rng, x0=0.0, y0=0.0, z0=0.0, hang=1.3):
    """Kingdom cloth thrown over a stack like a tablecloth: flat on top, hanging down every
    side by `hang` with wavy folds, corners dropping diagonally; trim band along the hem."""
    cloth, trim, dark = field(k), border(k), kcol(k, "cloth_dark")
    ph = rng.uniform(0, 6)

    def pos(u, v):
        xp = (u - 0.5) * (W + 2 * hang)
        yp = (v - 0.5) * (D + 2 * hang)
        ex, ey = max(0.0, abs(xp) - W / 2), max(0.0, abs(yp) - D / 2)
        e = math.hypot(ex, ey)
        x = math.copysign(min(abs(xp), W / 2 + 0.1), xp)
        y = math.copysign(min(abs(yp), D / 2 + 0.1), yp)
        fold = 0.18 * math.sin((xp + yp) * 2.4 + ph) * min(1.0, e / hang)
        x += math.copysign(fold + 0.1 * e / hang, xp) if ex > 0 else 0.0
        y += math.copysign(fold + 0.1 * e / hang, yp) if ey > 0 else 0.0
        z = z0 + H + 0.08 - e * 0.95 + (0.06 * math.sin(xp * 1.3 + ph) if e == 0 else 0.0)
        return (x0 + x, y0 + y, z)

    f = hang / (W + 2 * hang)
    g = hang / (D + 2 * hang)
    us = [0.0, f * 0.18, f * 0.55, f, 0.5, 1 - f, 1 - f * 0.55, 1 - f * 0.18, 1.0]
    vs = [0.0, g * 0.18, g * 0.55, g, 0.5, 1 - g, 1 - g * 0.55, 1 - g * 0.18, 1.0]

    def cols(kind, i, j):
        if kind == "edge":
            return dark
        return trim if i in (0, len(us) - 2) or j in (0, len(vs) - 2) else cloth

    return sheet(us, vs, pos, 0.16, cloth, cols, normal="auto")


def build(b, p):
    rng = b.rng
    k = p["kingdom"]
    t = p["type"]
    it = Items(b)
    if t == "crates":
        for x, s in ((-1.25, 2.2), (1.15, 2.0)):
            it.add(crate(s, s, s, rng=rng), x, rng.uniform(-0.2, 0.2), 0, rng.uniform(-0.12, 0.12))
        it.add(crate(1.9, 1.9, 1.8, color="wood", rng=rng, brace=False), -0.1, 0.1, 2.2, 0.15)
        b.add(tarp(k, 1.9, 1.9, 1.8, rng, x0=-0.1, y0=0.1, z0=2.2, hang=1.1).rotate(0.15, "Z"),
              grad=("range", 0.3, 0.9))
        b.add(rope([(-1.25, -1.3, 0.3), (-1.2, -1.3, 2.25), (1.0, -1.25, 2.2), (1.2, -1.25, 0.3)], r=0.08, seg=4))
        it.add(crate(1.2, 1.2, 1.1, color="wood_pale", rng=rng, brace=False), 0.6, -1.9, 0, 0.5)
        it.add(sack(rng, 0.7, 1.6, "canvas", lean=-0.25), 2.6, -0.6, 0)
        it.add(barrel(1.5, 0.55), -2.9, -0.5, 0)
    elif t == "barrels":
        for x, y in ((-1.3, 0.6), (0.95, 0.75), (-0.1, 2.3)):
            it.add(barrel(2.4, 0.9), x, y, 0)
        lid = cylinder(0.98, 0.98, 0.18, 8, kcol(k, "shutter")).move(0.95, 0.75, 2.4)
        b.add(lid)
        it.add(lying_barrel(rng), 0.0, -1.7, 0, 0.0)
        it.add(lathe([(0.0, 0.0), (0.5, 0.0), (0.62, 0.8), (0.54, 0.8), (0.0, 0.2)], 8, "wood_light"), 2.4, -1.3, 0)
        b.add(cylinder(0.56, 0.6, 0.1, 8, "iron_dark").move(2.4, -1.3, 0.55))
        b.add(cylinder(0.5, 0.5, 0.06, 8, "water").move(2.4, -1.3, 0.68))
    elif t == "sacks":
        # lying sacks side-on (long side to the front), two rows, standing sacks on top
        tie = field(k)  # emerald ties on every sack
        for x, y, z in ((-1.25, 0.9, 0.66), (1.05, 1.0, 0.66), (-0.2, -0.5, 0.64), (-0.15, 1.0, 1.85)):
            flip = rng.choice((1, -1))
            it.add(sack(rng, 0.85, 2.1, rng.choice(("canvas", "canvas_dark", "cloth_brown")), tie=tie, lean=-1.45),
                   x + flip * 1.05, y, z, flip * math.pi / 2 + rng.uniform(-0.12, 0.12))
        for x, y, lean in ((-1.5, 1.1, 0.12), (1.3, 1.2, -0.15)):
            it.add(sack(rng, 0.75, 1.7, rng.choice(("canvas", "cloth_brown")), tie=tie, lean=lean), x, y, 1.25,
                   rng.uniform(-0.6, 0.6))
        # emerald cloth band round the top sack: the variant's clear kingdom accent
        b.add(cylinder(0.78, 0.82, 0.38, 8, field(k)).move(-1.5, 1.1, 2.05).rotate(0.0, "Z"))
        it.add(basket("grain", rng), 2.4, -0.9, 0)
        b.add(kit.oriented_box((2.4, -0.9, 1.0), (3.0, -1.8, 2.0), 0.18, 0.18, "wood_light", Vector((1, 0, 0))))
        it.add(crate(1.5, 1.5, 1.3, rng=rng, brace=False), -2.7, -0.9, 0, 0.3)
        b.add(tarp(k, 1.5, 1.5, 1.3, rng, hang=0.75).rotate(0.3, "Z").move(-2.7, -0.9, 0), grad=("range", 0.3, 0.9))
    elif t == "produce":
        b.add(kit.bbox(5.4, 3.0, 0.45, "wood", 0.08).move(0, 0.3, 0.3))
        for x in (-2.2, 0.0, 2.2):
            for y in (-0.9, 1.5):
                b.add(box(0.5, 0.5, 0.32, "wood_dark").move(x, y, 0.0))
        for x, fill in ((-1.6, "apple"), (0.1, "cabbage"), (1.7, "pear")):
            it.add(basket(fill, rng, n_fill=5), x, 0.3 + rng.uniform(-0.2, 0.2), 0.75)
        for x, y, r in ((-2.0, -1.9, 0.75), (-0.8, -2.1, 0.6), (2.2, -1.8, 0.7)):
            it.add(pumpkin(r, rng.choice(("pumpkin", "autumn_orange"))), x, y, 0)
        it.add(crate(1.5, 1.4, 1.2, rng=rng, brace=False), 3.4, 1.0, 0, 0.2)
        cl = box(1.7, 1.6, 0.25, field(k)).rotate(0.2, "Z").move(3.4, 1.0, 1.15)
        b.add(cl)
    elif t == "merchant":
        it.add(crate(2.4, 1.8, 1.6, rng=rng), -0.9, 0.4, 0, 0.05)
        it.add(crate(1.8, 1.8, 1.5, color="wood", rng=rng, brace=False), 1.5, 0.6, 0, -0.1)
        cols = [kcol(k, "cloth"), "canvas", "cloth_white", kcol(k, "cloth_dark")]  # kingdom colour + neutrals only
        for i, c in enumerate(cols):  # cloth bolts on top of the big crate
            bolt = cylinder(0.36, 0.36, 2.2, 8, c).rotate(math.pi / 2, "Y")
            b.add(bolt.move(-2.0, 0.4 - 0.55 + (i % 3) * 0.72 - 0.35, 1.95 + 0.62 * (i // 3) + (0.3 if i == 3 else 0)))
            b.add(cylinder(0.38, 0.38, 0.15, 8, kcol(k, "trim")).rotate(math.pi / 2, "Y").move(-1.0, 0.4 - 0.55 +
                  (i % 3) * 0.72 - 0.35, 1.95 + 0.62 * (i // 3) + (0.3 if i == 3 else 0)))
        it.n += 1
        coil = []
        for j in range(2):
            coil.append(sweep_loop([(0.35, 0.0), (0.55, 0.0), (0.62, 0.15), (0.55, 0.3), (0.35, 0.3)], 9, "rope",
                                   phase=0.3 * j).move(0, 0, 0.3 * j))
        it.add(coil, 1.5, 0.6, 1.5)
        for x, y, h in ((2.9, -0.9, 1.7), (1.9, -1.3, 1.3), (-2.6, -1.2, 1.5)):
            it.add(jar(h, 0.5 + h * 0.05), x, y, 0)
    else:  # storehouse: sacks on a pallet under a lean-to with a kingdom-tile roof, hanging lantern
        b.add(kit.bbox(5.2, 3.4, 0.35, "wood", 0.08).move(0, 0.4, 0.45))
        for y in (-0.9, 0.4, 1.7):  # pallet skids
            b.add(box(5.0, 0.5, 0.45, "wood_dark").move(0, y, 0.0))
        zp = 0.8
        for x, y in ((-1.3, 1.2), (1.1, 1.3), (-0.1, -0.3)):
            flip = rng.choice((1, -1))
            it.add(sack(rng, 0.8, 2.0, rng.choice(("canvas", "canvas_dark", "cloth_brown")), lean=-1.45),
                   x + flip * 1.0, y, zp + 0.62, flip * math.pi / 2 + rng.uniform(-0.1, 0.1))
        for x, y, lean in ((-1.2, 1.1, 0.1), (0.9, 1.2, -0.12)):
            it.add(sack(rng, 0.72, 1.6, rng.choice(("canvas", "cloth_brown")), lean=lean), x, y, zp + 1.2,
                   rng.uniform(-0.5, 0.5))
        it.add(sack(rng, 0.75, 1.7, "canvas", lean=0.3), 2.9, -1.6, 0, 0.6)
        # lean-to: low front posts, tall back posts, top plates, mono-pitch kingdom-tile roof
        hf, hb, yf, yb = 4.4, 5.6, -1.6, 2.6
        for sx in (-1, 1):
            x = sx * 2.9
            b.add(kit.bbox(0.5, 0.5, hf, "timber", 0.06).move(x, yf, 0.0))
            b.add(kit.bbox(0.5, 0.5, hb, "timber", 0.06).move(x, yb, 0.0))
            b.add(kit.oriented_box((x, yf - 0.4, hf), (x, yb + 0.4, hb), 0.45, 0.45, "wood_dark", Vector((1, 0, 0))))
            b.add(kit.oriented_box((x, yf + 0.2, hf - 1.6), (x, yf + 1.6, hf - 0.1), 0.3, 0.3, "wood_dark",
                                   Vector((1, 0, 0))))  # knee brace
        sl = math.atan2(hb - hf, yb - yf)
        for i, f in enumerate((0.0, 0.34, 0.68)):  # three overlapping tile courses, lowest in front
            y = yf - 0.9 + (yb - yf + 1.6) * f
            z = hf + 0.35 + (y - yf) * math.tan(sl)
            sh = kit.bbox(7.0, 2.3, 0.32, kcol(k, "roof") if i else kcol(k, "roof_dark"), 0.08)
            b.add(sh.rotate(sl + 0.04, "X").move(0, y + 0.9, z - 0.1 * i), tag="roof")
        b.add(box(7.1, 0.35, 0.5, kcol(k, "roof_dark")).move(0, yb + 0.55, hb + 0.55))  # back ridge board
        # lantern hanging from the front plate
        b.add(box(0.12, 0.12, 0.9, "iron_dark").move(1.6, yf, hf - 0.6))
        b.add(box(0.6, 0.6, 0.15, "iron_dark").move(1.6, yf, hf - 1.45))
        b.add(box(0.45, 0.45, 0.6, "window_glow").move(1.6, yf, hf - 1.95), grad=("range", 0.55, 1.0))
        b.add(box(0.6, 0.6, 0.15, "iron_dark").move(1.6, yf, hf - 2.1))
    b.stats["items"] = it.n
    b.socket("interact", 0, -3.2, 0)
    b.stats["pieces"] = len(b.pieces)
