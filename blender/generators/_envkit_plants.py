"""Environment kit: bushes and flower tufts, style B (faceted lumps, vertex colours, 40-400 triangles each).

bush_NN follows the stand-in's colour classes by NN (Kit/Props.luau `bush`): NN % 3 == 1 plain, 2 white blossom, 0 red berries (bush_03
is the world's food node: its berries must read from the aerial camera). Four silhouettes (round, low and wide, tall, twin mound) rotate
through the eight ids. plant_flowers_NN: a leafy tuft with six large blooms; NN picks the colours (red, yellow, white, purple, two mixes).
"""

import math

from generators import _envkit_style as S
from lib.ckit import M, merge

BUSH_SHAPES = ["round", "low", "tall", "twin"]


def _gem(rng, cx, cy, cz, r, color, tag="bloom", n=6):
    """A faceted berry / blossom: a 20-facet icosahedron, lighter on top so it reads as a lit berry from above."""
    m = S.ico(rng, r, r * 0.92, r, cx, cy, cz, jitter=0.05, subdiv=0, color=color, tag=tag)
    for i, face in enumerate(m.f):
        nrm = S.face_normal(m, face)
        m.c[i] = S.mix(S.mul(color, 0.8), S.mix(color, (1, 1, 1), 0.12), min(1.0, 0.5 + 0.5 * nrm[1]))
    return m


def bush(variant, rng):
    kind = {1: "plain", 2: "white", 0: "berry"}[variant % 3]
    shape = BUSH_SHAPES[(variant - 1) % 4]
    # dome radii (x, y, z): the stand-in is a sphere of d 4.8-5.6 sunk 0.5 with three lobes tucked round its foot
    base = {"round": (2.75, 2.75, 2.75), "low": (3.1, 2.35, 2.8), "tall": (2.4, 3.1, 2.4), "twin": (2.5, 2.7, 2.5)}[shape]
    rx, ry, rz = (v * rng.uniform(0.96, 1.05) for v in base)
    sink = 0.45
    cy = ry - sink
    lobes, parts = [], []
    lobes.append(S.ico(rng, rx, ry, rz, 0.0, cy, 0.0, jitter=0.06, subdiv=1, squash_bottom=0.2, color=S.LEAF_LIGHT, tag="bush"))
    a0 = rng.uniform(0, math.tau)
    n_l = 4 if shape in ("low", "round") else 3
    for k in range(n_l):
        a = a0 + k * math.tau / n_l + rng.uniform(-0.25, 0.25)
        d = rng.uniform(1.6, 2.0) * (1.2 if shape == "low" else 1.0)
        r = min(rx, rz) * rng.uniform(0.72, 0.9)
        lobes.append(S.ico(rng, d, d * 0.9, d, math.cos(a) * r, d * 0.7 - sink, math.sin(a) * r, jitter=0.08, subdiv=0, squash_bottom=0.3, color=S.LEAF, tag="bush"))
    if shape == "twin":
        a = a0 + 0.9
        lobes.append(S.ico(rng, 2.1, 2.1, 2.1, math.cos(a) * 3.0, 2.1 - sink, math.sin(a) * 3.0, jitter=0.07, subdiv=1, squash_bottom=0.2, color=S.LEAF_LIGHT, tag="bush"))
    ymin = min(b.bounds()[0][1] for b in lobes)
    ymax = max(b.bounds()[1][1] for b in lobes)
    for b in lobes:
        S.paint_ramp(b, S.BUSH_RAMP, rng, ymin, ymax, up=0.40, height=0.42, noise=0.08)
    parts += lobes
    if kind != "plain":
        col = S.BERRY if kind == "berry" else S.FLOWER["white"]
        r0 = 0.8 if kind == "berry" else 0.7
        for i in range(7 if kind == "berry" else 6):
            a = a0 + i * 1.12 + rng.uniform(-0.2, 0.2)
            el = math.radians(26 + (i % 3) * 17 + rng.uniform(-4, 4))
            rr = max(rx, rz) * 0.97
            parts.append(_gem(rng, math.cos(a) * math.cos(el) * rr, cy + math.sin(el) * ry * 0.97, math.sin(a) * math.cos(el) * rr, r0, col,
                              tag="berry" if kind == "berry" else "blossom"))
    return S.assemble(parts), {"shape": shape, "kind": kind}


def _blade(rng, x, z, h, w, lean_deg, yaw, color_lo, color_hi):
    """A grass blade: a thin four-sided spike (3 triangles per face fan): base square, leaning tip."""
    lx, lz = math.sin(math.radians(lean_deg)) * h * 0.5, 0.0
    v = [(-w, 0.0, -w), (w, 0.0, -w), (w, 0.0, w), (-w, 0.0, w), (lx, h, lz)]
    f = [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (3, 2, 1, 0)]
    m = M(v, f, color=color_hi, smooth=False, tag="leaf")
    m.fix_winding()
    for i, face in enumerate(m.f):
        cy = sum(m.v[k][1] for k in face) / len(face)
        m.c[i] = S.mix(color_lo, color_hi, min(1.0, cy / h + rng.uniform(-0.08, 0.08)))
    m.rot(math.degrees(yaw), "y").move(x, 0.0, z)
    return m


def flowers(variant, rng):
    """plant_flowers_NN: a tuft of seven blades and six large faceted blooms on short stems (colours by NN)."""
    palettes = {1: ["red"], 2: ["yellow"], 3: ["white"], 4: ["purple"], 5: ["red", "yellow"], 6: ["white", "purple"]}
    cols = palettes[(variant - 1) % 6 + 1]
    parts = []
    # leaves: one low mound and a ring of blades, so the tuft is never a bare stalk with a ball
    mound = S.blob(rng, 12, 1.5, 0.7, 1.4, 0.0, 0.3, 0.0, jitter=0.12, squash_bottom=0.6, color=S.LEAF, tag="leaf", yaw=rng.uniform(0, math.tau))
    S.paint_ramp(mound, [S.LEAF_DARK, S.LEAF, S.LEAF_LIGHT], rng, 0.0, 1.0, up=0.3, height=0.5, noise=0.1)
    parts.append(mound)
    nblade = [7, 6, 8, 6, 7, 9][(variant - 1) % 6]
    for i in range(nblade):
        a = i * 6.3 / nblade + rng.uniform(-0.2, 0.2)
        r = rng.uniform(0.5, 1.8)
        parts.append(_blade(rng, math.cos(a) * r, math.sin(a) * r, rng.uniform(1.1, 1.8), rng.uniform(0.14, 0.2), rng.uniform(-24, 24), rng.uniform(0, math.tau),
                            S.LEAF_DARK, S.LEAF_LIGHT))
    nbloom = [6, 7, 5, 8, 6, 7][(variant - 1) % 6]
    for i in range(nbloom):
        a = i * 6.3 / nbloom + rng.uniform(-0.2, 0.2)
        r = rng.uniform(0.25, 2.05)
        top = (2.15 if r < 1.2 else 1.6) + rng.uniform(0.0, 0.6)
        col = S.FLOWER[cols[(i + variant) % len(cols)]]
        x, z = math.cos(a) * r, math.sin(a) * r
        # stem: a three-sided sliver; head: a flat faceted blossom with a yellow-ish centre nub
        stem = S.flat(S.slab([(-0.1, -0.08), (0.1, -0.08), (0.0, 0.12)], 0.0, top - 0.25, S.LEAF_DARK, tag="stem")).move(x, 0.0, z)
        parts.append(stem)
        head = S.blob(rng, 10, 0.78, 0.42, 0.78, x, top, z, jitter=0.1, color=col, tag="bloom", yaw=rng.uniform(0, math.tau))
        S.paint_ramp(head, [S.mul(col, 0.82), col, S.mix(col, (1, 1, 1), 0.2)], rng, top - 0.42, top + 0.42, up=0.5, height=0.3, noise=0.06)
        parts.append(head)
        centre = S.blob(rng, 6, 0.28, 0.24, 0.28, x, top + 0.32, z, jitter=0.05, color=S.FLOWER["yellow"] if col != S.FLOWER["yellow"] else S.WOOD_LIGHT, tag="centre")
        parts.append(centre)
    return S.assemble(parts), {"colours": cols}
