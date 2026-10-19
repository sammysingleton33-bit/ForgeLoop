"""Flower patches and clumps: a leafy base (soft mound + broad leaf blades) with stems and
solid flower heads: star-petal wildflowers, tulip cups, daisies, tall sunflowers, lavender
spikes and poppies. Ground cover / decoration; no collision. Front faces Blender -Y.
"""

import math

from lib.geo import TAU, Vector, lathe, look_rot, tube

from generators import _vegetation_common as vc

NAME = "plant_flowers"
VERSION = 1
CATEGORY = "plant"
BUDGET = "prop_small"
COLLISION = {"fidelity": "None"}
CHECKS = {"min_flowers": 3, "min_stems": 3}
DEFAULT_VARIANTS = 6
LINEUP_GAP = 1.5
GAMEPLAY_DISTANCE = 40.0
GAMEPLAY_HEIGHT = 8.0
HERO_VIEW = {"azimuth": 35, "elevation": 28}

KINDS = ("wildflowers", "tulips", "daisies", "sunflowers", "lavender", "poppies")
LEAF = ("leaf_dark", "leaf_mid", "leaf_light")


def variants(n, seed):
    return [{"kind": KINDS[i % len(KINDS)], "seed": seed * 1000 + 23 * i + 7} for i in range(n)]


def _stem(a, b_, r=0.09, color="crop_dark"):
    mid = (a + b_) / 2 + Vector((0, 0, 0.1))
    return tube([a, mid, b_], [r, r * 0.85, r * 0.7], 3, color).paint(grad=("range", 0.2, 0.9), tag="stem")


def _spots(rng, n, radius, min_d):
    pts = []
    tries = 0
    while len(pts) < n and tries < 400:
        tries += 1
        a = rng.uniform(0, TAU)
        r = radius * math.sqrt(rng.uniform(0.0, 1.0))
        p = Vector((math.cos(a) * r, math.sin(a) * r * 0.85, 0))
        if all((p - q).length >= min_d for q in pts):
            pts.append(p)
    return pts


def build(b, p):
    rng = b.rng
    kind = p["kind"]
    spec = {
        "wildflowers": dict(n=9, R=2.4, h=(1.6, 2.6), mound=1.5),
        "tulips": dict(n=7, R=1.5, h=(2.2, 3.0), mound=1.1),
        "daisies": dict(n=8, R=2.3, h=(1.3, 2.1), mound=1.4),
        "sunflowers": dict(n=3, R=1.2, h=(5.0, 6.4), mound=1.2),
        "lavender": dict(n=8, R=1.6, h=(2.0, 2.8), mound=1.3),
        "poppies": dict(n=7, R=2.2, h=(1.8, 2.6), mound=1.3),
    }[kind]
    R = spec["R"]

    # leafy base: a low soft mound and broad leaf blades
    m = spec["mound"]
    # (flattened underside instead of clamping a whole sphere: a folded bottom confuses normal recalculation)
    mound = vc.puff(rng, 1.0, vc.SCHEMES["bush"], hglob=0.3, subdiv=2, squash=1.0, bottom=0.08, lump=0.32)
    b.add(vc.clamp_ground(mound.scale(m * 1.15, m, m * 0.42).move(0, 0, 0.03)))
    nl = 6 if kind != "sunflowers" else 5
    for i in range(nl):
        a = TAU * i / nl + rng.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), math.sin(a), 0)) * rng.uniform(0.2, 0.6)
        b.add(vc.blade(rng, d, rng.uniform(0.9, 1.5) * (1.6 if kind == "sunflowers" else 1.0), 0.32,
                       rng.uniform(0.8, 1.3), a, LEAF, thick=0.3))

    flowers = stems = 0
    spots = _spots(rng, spec["n"], R, 0.55 if kind != "sunflowers" else 1.0)
    pal = {
        "wildflowers": ("flower_red", "flower_yellow", "flower_white", "flower_purple", "flower_blue"),
        "tulips": ("flower_red", "flower_yellow", "blossom_pink", "flower_red"),
        "daisies": ("flower_white",),
        "sunflowers": ("flower_yellow",),
        "lavender": ("flower_purple",),
        "poppies": ("flower_red", "apple_red"),
    }[kind]
    for k, sp in enumerate(spots):
        h = rng.uniform(*spec["h"])
        lean = Vector((sp.x, sp.y, 0)) * 0.22 + Vector((rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), 0))
        top = sp + lean + Vector((0, 0, h))
        col = pal[k % len(pal)]
        if kind != "lavender":
            b.add(_stem(sp, top, 0.11 if kind == "sunflowers" else 0.075))
            stems += 1
        if kind == "poppies":  # open bowl of petals with a dark seed boss
            bowl = lathe([(0.0, 0.0), (0.22, 0.04), (0.5, 0.24), (0.6, 0.42), (0.48, 0.4), (0.0, 0.22)], 5, col,
                         phase=rng.uniform(0, 1.0))
            boss = lathe([(0.15, 0.2), (0.13, 0.36), (0.0, 0.42)], 4, "black")
            tilt = (Vector((sp.x, sp.y, 0)) * 0.25 + Vector((0, -0.3, 1.0))).normalized()
            mrot = look_rot(tilt)
            for pc in (bowl.paint(smooth=True, grad=("range", 0.3, 1.0)), boss):
                pc.transform(mrot)
                b.add(pc.move(top.x, top.y, top.z - 0.05).paint(tag="flower"))
        elif kind in ("wildflowers", "daisies"):
            r = {"wildflowers": rng.uniform(0.38, 0.5), "daisies": rng.uniform(0.46, 0.56),
                 "poppies": rng.uniform(0.45, 0.58)}[kind]
            if kind == "daisies":
                parts = vc.flower_head(rng, r, "flower_white", "flower_yellow", petals=6, inner=0.5, thick=0.1,
                                       cup=0.06, dome_k=0.36)
            else:
                parts = vc.flower_head(rng, r, col, "flower_yellow" if col != "flower_yellow" else "ember",
                                       petals=5, inner=0.45, thick=0.12, cup=0.12)
            tilt = (Vector((sp.x, sp.y, 0)) * 0.25 + Vector((0, -0.35, 1.0))).normalized()
            mrot = look_rot(tilt)
            for pc in parts:
                pc.transform(mrot)
                b.add(pc.move(top.x, top.y, top.z).paint(tag="flower"))
        elif kind == "tulips":
            cup = lathe([(0.0, 0.0), (0.3, 0.08), (0.42, 0.42), (0.36, 0.8), (0.22, 0.86), (0.0, 0.66)], 6, col)
            b.add(cup.move(top.x, top.y, top.z - 0.05).paint(smooth=True, grad=("range", 0.3, 1.0), tag="flower"))
            # one broad leaf hugging each stem
            a = math.atan2(sp.y, sp.x) + rng.uniform(-0.5, 0.5)
            b.add(vc.blade(rng, sp, h * 0.6, 0.26, 0.5, a, LEAF, thick=0.3, curl=0.6))
        elif kind == "sunflowers":
            face = Vector((sp.x * 0.3, -0.75, 0.55)).normalized()
            parts = vc.flower_head(rng, 1.25, "flower_yellow", "wood_dark", petals=11, inner=0.62, thick=0.2,
                                   cup=0.1, dome_k=0.5)
            mrot = look_rot(face)
            for pc in parts:
                pc.transform(mrot)
                b.add(pc.move(top.x, top.y, top.z).paint(tag="flower"))
            for side in (-1, 1):  # big leaves on the stalk
                a = math.atan2(sp.y, sp.x) + side * 1.6 + rng.uniform(-0.3, 0.3)
                lp = sp.lerp(top, rng.uniform(0.35, 0.6))
                lf = vc.puff(rng, 0.55, vc.SCHEMES["bush"], hglob=0.4, subdiv=1, squash=0.35, bottom=1.0, lump=0.1)
                lf.scale(1.6, 0.9, 1.0).rotate(a, "Z")
                b.add(lf.move(lp.x + math.cos(a) * 0.7, lp.y + math.sin(a) * 0.7, lp.z))
        else:  # lavender: bumpy purple spike on a green stalk
            b.add(_stem(sp, sp + (top - sp) * 0.6, 0.07))
            stems += 1
            prof = [(0.0, 0.0), (0.16, 0.12), (0.1, 0.3), (0.19, 0.48), (0.1, 0.66), (0.17, 0.84), (0.08, 1.02),
                    (0.0, 1.14)]
            sk = lathe([(r_ * 1.15, z * 1.2) for r_, z in prof], 4, col)
            base = sp + (top - sp) * 0.6
            d = (top - base).normalized()
            sk.transform(look_rot(d))
            b.add(sk.move(base.x, base.y, base.z).paint(smooth=True, grad=("range", 0.2, 1.0), tag="flower"))
        flowers += 1

    b.stats["flowers"] = flowers
    b.stats["stems"] = stems
    b.socket("pick", 0.0, -R - 0.8, 0.0)
