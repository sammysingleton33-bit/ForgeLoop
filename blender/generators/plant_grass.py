"""Grass tufts: clumps of tapered solid blades (flat triangular cross-section, dark base ->
light tip) fanning out from a small root crown. Kinds: short tuft, tall tuft, wide meadow
clump, dry (straw) tuft, seed-head grass and reeds with cattails. Ground cover; no collision.
Front faces Blender -Y.
"""

import math

from lib.geo import TAU, Vector, lathe, look_rot, tube

from generators import _vegetation_common as vc

NAME = "plant_grass"
VERSION = 1
CATEGORY = "plant"
BUDGET = "prop_small"
COLLISION = {"fidelity": "None"}
CHECKS = {"min_blades": 14}
DEFAULT_VARIANTS = 6
LINEUP_GAP = 1.5
GAMEPLAY_DISTANCE = 40.0
GAMEPLAY_HEIGHT = 8.0
HERO_VIEW = {"azimuth": 35, "elevation": 24}

GREEN = ("grass_dark", "grass", "grass_light")
LUSH = ("grass_dark", "leaf_light", "grass_light")
DRY = ("hay_dark", "hay", "straw")
REED = ("crop_dark", "moss", "grass_light")

PLAN = (
    # kind, blades, height range, crown radius, spread, colours
    ("short", 30, (1.4, 2.4), 0.5, 1.0, GREEN),
    ("tall", 30, (3.0, 4.6), 0.55, 2.1, LUSH),
    ("meadow", 40, (1.6, 3.2), 1.6, 1.3, GREEN),
    ("dry", 32, (2.0, 3.4), 0.6, 1.6, DRY),
    ("seed", 24, (1.8, 3.0), 0.6, 1.2, GREEN),
    ("reeds", 20, (4.0, 6.0), 0.7, 0.6, REED),
)


def variants(n, seed):
    out = []
    for i in range(n):
        kind = PLAN[i % len(PLAN)][0]
        out.append({"kind": kind, "seed": seed * 1000 + 37 * i + 19})
    return out


def build(b, p):
    rng = b.rng
    kind, nb, hr, crown, spread, cols = next(x for x in PLAN if x[0] == p["kind"])
    blades = 0
    golden = math.pi * (3 - math.sqrt(5))
    ph = rng.uniform(0, TAU)
    for i in range(nb):
        # sunflower-seed layout: inner blades tall and upright, outer ones shorter and leaning out
        f = math.sqrt((i + 0.5) / nb)
        a = ph + golden * i
        r = crown * f
        base = Vector((math.cos(a) * r, math.sin(a) * r * 0.9, 0))
        h = hr[0] + (hr[1] - hr[0]) * (1.0 - 0.7 * f) * rng.uniform(0.8, 1.1)
        lean = spread * (0.5 + 0.9 * f) * rng.uniform(0.7, 1.2) * (h / hr[1]) ** 0.5
        ang = a + rng.uniform(-0.35, 0.35)
        w = (0.2 if kind in ("short", "meadow", "seed") else 0.24) * rng.uniform(0.85, 1.2)
        if kind == "reeds":
            w = 0.2 * rng.uniform(0.9, 1.2)
        curl = 1.0 if kind != "reeds" else 0.45
        b.add(vc.blade(rng, base, h, w, lean, ang, cols, thick=0.38, curl=curl))
        blades += 1
    # root crown: a low dark disc that hides where the blades meet the ground
    rc = lathe([(crown * 0.85 + 0.15, 0.0), (crown * 0.55 + 0.1, 0.12), (0.0, 0.16)], 7, cols[0])
    b.add(rc.jitter(rng, 0.05, (1, 1, 0)).paint(smooth=True, grad=("range", 0.0, 0.5), tag="crown"))

    extras = 0
    if kind == "seed":  # thin stalks with oval seed heads above the blades
        for i in range(6):
            a = ph + i * 2.4
            s = Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.1))
            top = s + Vector((math.cos(a) * 0.9, math.sin(a) * 0.9, hr[1] + rng.uniform(0.4, 1.2)))
            b.add(tube([s, (s + top) / 2 + Vector((0, 0, 0.2)), top], [0.06, 0.05, 0.04], 3, "crop_dark").paint(
                tag="stalk"))
            head = lathe([(0.0, 0.0), (0.16, 0.2), (0.2, 0.55), (0.12, 0.85), (0.0, 1.0)], 5,
                         "wheat" if i % 2 else "wheat_dark")
            d = (top - (s + top) / 2).normalized()
            head.transform(look_rot(d))
            b.add(head.move(top.x, top.y, top.z - 0.1).paint(smooth=True, grad=("range", 0.3, 1.0), tag="seed"))
            extras += 1
    if kind == "reeds":  # cattails: brown velvet heads on straight stalks
        for i in range(3):
            a = ph + i * 2.1 + rng.uniform(-0.3, 0.3)
            s = Vector((math.cos(a) * 0.35, math.sin(a) * 0.35, 0.1))
            hgt = hr[1] + rng.uniform(0.6, 1.6)
            top = s + Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, hgt))
            b.add(tube([s, (s + top) / 2, top + Vector((0, 0, 0.9))], [0.08, 0.07, 0.03], 3, "crop_dark").paint(
                tag="stalk"))
            cat = lathe([(0.0, 0.0), (0.2, 0.12), (0.26, 0.6), (0.24, 1.3), (0.14, 1.55), (0.0, 1.62)], 6,
                        "wood_dark")
            b.add(cat.move(top.x, top.y, top.z - 1.4).paint(smooth=True, grad=("range", 0.3, 0.9), tag="cattail"))
            extras += 1
    if kind == "short":  # a couple of clover-like leaf blobs at the foot
        for i in range(2):
            a = ph + 1.3 + i * 3.0
            lf = vc.puff(rng, 0.42, vc.SCHEMES["bush"], hglob=0.6, subdiv=1, squash=0.5, bottom=0.3, lump=0.1)
            b.add(lf.move(math.cos(a) * (crown + 0.5), math.sin(a) * (crown + 0.5), 0.12))
    b.stats["blades"] = blades
    b.stats["extras"] = extras
