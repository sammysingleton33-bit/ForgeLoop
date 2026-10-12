"""Kingdom heraldry: four banner types, two per kingdom (ART_DIRECTION 3).

  pole      tall banner hanging from a crossbar on a pole, finial on top, stone foot
  mast      swallow-tailed flag flying from a tall mast, halyard rope, stepped plinth
  wall      wall-hanging banner on an iron rod with wall brackets (back plane = wall)
  standard  war standard: emblem topper, short gonfalon with tails, streamers, cairn foot

Cloth is solid (0.3 thick) and waves gently (grid lofted through stations); the kingdom
emblem (red crown, blue star, green oak leaf, yellow sun) is raised geometry that is
bent onto the same wave. Trim bands and tassels use the kingdom trim metal colour.

Sockets: `base` = foot of the pole/mast on the ground (wall banner: bottom centre on the
wall plane); `top` = finial tip / mounting point (wall banner: rod centre on the wall).
"""

import math

from lib import kit
from lib.geo import Vector, box, cone, cylinder, lathe

from generators._kingdom_props_common import (KINGDOMS, bend_onto, border, emblem, field, kcol, lashing, rope, sheet)

NAME = "prop_banner"
VERSION = 1
CATEGORY = "prop"
BUDGET = "banner"
COLLISION = {"fidelity": "Hull"}
CHECKS = {"min_emblem": 1, "min_cloth": 1}
DEFAULT_VARIANTS = 8
HERO_VIEW = {"azimuth": 28, "elevation": 14}
LINEUP_GAP = 3.0

TYPES = ("pole", "mast", "wall", "standard")
EMBLEMS = {"red": ("crown", "crown"), "blue": ("star", "star"), "green": ("oak", "oak"), "yellow": ("sun", "sun")}
THICK = 0.3


def variants(n, seed):
    out = []
    for i in range(n):
        k = KINGDOMS[(i // 2) % 4]
        j = i % 2
        out.append({
            "kingdom": k,
            "type": TYPES[(KINGDOMS.index(k) + j) % 4],
            "emblem": EMBLEMS[k][j],
            "n": j + 1,
            "seed": seed * 1000 + i,
        })
    return out


def asset_id(i, p):
    return f"{CATEGORY}_banner_{p['kingdom']}_{p['n']:02d}"


# ------------------------------------------------------------------ cloth

def emblem_cols(k, emb):
    """(main, accent) colours of an emblem on kingdom cloth."""
    if emb == "flame":
        return kcol(k, "trim"), kcol(k, "glow")
    if emb in ("crown", "oak"):
        return kcol(k, "trim"), kcol(k, "emblem")
    return kcol(k, "emblem"), kcol(k, "trim")


def hanging_cloth(b, k, W, L, top, bottom, emb, rng, x0=0.0, y0=0.0, amp=0.3, fringe=True, side_trim=True,
                  emb_size=None, emb_z=0.42, lean=0.15, emb_mid=0.5, us=None):
    """Banner cloth hanging from a crossbar at z=top, centred on x0, mid-plane y0 at the
    top, leaning `lean` towards -Y at the bottom (away from pole / wall).
    bottom: 'point' | 'swallow' | 'tails' | 'flat'. Returns the bottom-most z."""
    cloth, dark, trim = field(k), kcol(k, "cloth_dark"), border(k)
    lam = rng.uniform(4.4, 5.2)
    ph = rng.uniform(0, math.tau)

    def drop(v):
        c = abs(2 * v - 1)  # 0 centre .. 1 edges
        if bottom == "point":
            return L + 1.6 * (1 - c)
        if bottom == "swallow":
            return L - 1.9 * (1 - c)
        if bottom == "tails":  # three tails (edges + centre), notches at v = 0.25 / 0.75
            return L - 1.5 * abs(math.sin(v * math.pi * 2.0))
        return L

    def wave(x, z):
        u = min(1.0, max(0.0, (top - z) / L))
        return amp * math.sin(math.tau * (x - x0) / lam + ph) * (0.2 + 0.8 * u) - lean * u

    def pos(u, v):
        x = x0 + (v - 0.5) * W * (1 + 0.04 * u)
        z = top - u * drop(v)
        return (x, y0 + wave(x, z), z)

    us = list(us or (0.0, 0.07, 0.3, 0.55, 0.8, 0.91, 1.0))
    vs = [0.0, 0.08, 0.3, 0.5, 0.7, 0.92, 1.0] if bottom != "tails" else \
        [0.0, 0.1, 0.25, 0.375, 0.5, 0.625, 0.75, 0.9, 1.0]
    nU, nV = len(us), len(vs)

    def cols(kind, i, j):
        if kind == "edge":
            return dark
        if i == 0:
            return dark  # top hem
        if i >= nU - 2:
            return trim  # bottom trim band follows the cut
        if side_trim and (j == 0 or j == nV - 2):
            return trim
        return cloth

    b.add(sheet(us, vs, pos, THICK, cloth, cols), grad=("range", 0.3, 0.9), tag="cloth")
    es = emb_size or W * 0.74
    ez = top - L * emb_z
    parts = emblem(emb, es, *emblem_cols(k, emb), mid=emb_mid)
    for p in parts:
        p.move(x0, y0 - THICK / 2 - 0.08, ez)
    bend_onto(parts, wave)
    b.add(parts, grad=("range", 0.45, 0.95), tag="emblem")
    b.stats["emblem"] = 1
    low = top
    if fringe:
        for j in range(9):
            v = (j + 0.5) / 9
            x, y, z = pos(1.0, v)
            t = cone(0.2, 0.6, 3, trim).rotate(math.pi, "X").move(x, y, z + 0.05)
            b.add(t, grad=("range", 0.3, 0.8))
            low = min(low, z - 0.5)
    else:
        low = min(pos(1.0, v)[2] for v in vs)
    return low


def flying_flag(b, k, L, H, top, emb, rng, x0=0.0, notch=2.0, amp=0.45):
    """Swallow-tailed flag attached to a mast at x0, flying towards +X, top edge at z=top."""
    cloth, dark, trim = field(k), kcol(k, "cloth_dark"), border(k)
    lam = rng.uniform(5.5, 6.5)
    ph = rng.uniform(0.3, 1.2)

    def reach(v):
        return L - notch * (1 - abs(2 * v - 1))

    def wave(x, z):
        u = min(1.0, max(0.0, (x - x0) / L))
        return amp * math.sin(math.tau * (x - x0) / lam + ph) * u ** 0.8

    def droop(u):
        return 0.7 * u * u

    def pos(u, v):
        x = x0 + 0.25 + u * reach(v)
        z = top - v * H - droop(u) + 0.1 * math.sin(u * 5.0)
        return (x, wave(x, z), z)

    us = [0.0, 0.08, 0.24, 0.42, 0.6, 0.78, 0.9, 1.0]
    vs = [0.0, 0.1, 0.3, 0.5, 0.7, 0.9, 1.0]
    nV = len(vs)

    def cols(kind, i, j):
        if kind == "edge":
            return dark
        if i == 0:
            return dark  # hoist sleeve
        if j == 0 or j == nV - 2:
            return trim  # trim stripes along top and bottom
        return cloth

    b.add(sheet(us, vs, pos, THICK, cloth, cols), grad=("range", 0.3, 0.9), tag="cloth")
    es = H * 0.56
    ex = x0 + 0.25 + L * 0.36
    ez = top - H * 0.5 - droop(0.36)
    parts = emblem(emb, es, *emblem_cols(k, emb))
    for p in parts:
        p.move(ex, -THICK / 2 - 0.08, ez)
    bend_onto(parts, wave)
    b.add(parts, grad=("range", 0.45, 0.95), tag="emblem")
    b.stats["emblem"] = 1
    # rope ties at the hoist
    for zz in (top - 0.25, top - H + 0.25):
        b.add(cylinder(0.42, 0.42, 0.3, 6, "rope").move(x0, 0, zz - 0.15))


# ------------------------------------------------------------------ banner types

def finial(k, style):
    trim = "gold" if k == "yellow" else kcol(k, "trim")  # Sunspire: gold finials on bronze trim
    if style == "spear":
        return [lathe([(0.3, 0.0), (0.36, 0.25), (0.18, 0.45), (0.42, 1.0), (0.0, 2.1)], 6, trim)]
    if style == "ball":
        return [lathe([(0.2, 0.0), (0.42, 0.2), (0.52, 0.55), (0.4, 0.92), (0.0, 1.1)], 6, trim)]
    # crown-ish open finial
    return [lathe([(0.28, 0.0), (0.5, 0.3), (0.62, 0.8), (0.3, 0.95), (0.0, 1.6)], 6, trim)]


def build_pole(b, p, rng):
    k = p["kingdom"]
    sun = p["emblem"] == "sun"
    H = rng.uniform(17.0, 18.0) if sun else rng.uniform(15.0, 16.0)
    W = rng.uniform(5.6, 6.0) if sun else rng.uniform(5.0, 5.4)
    L = rng.uniform(8.8, 9.4) if sun else rng.uniform(7.4, 8.0)
    stone, sdark = kcol(k, "stone"), kcol(k, "stone_dark")
    yb = -0.46  # crossbar and cloth hang in front of the pole
    # stepped stone foot with an iron collar
    b.add(kit.bbox(3.2, 3.2, 0.7, sdark, 0.15))
    b.add(kit.bbox(2.4, 2.4, 1.3, stone, 0.18).move(0, 0, 0.7).paint(tint=rng.uniform(0.3, 0.7)))
    b.add(cylinder(0.5, 0.42, 0.6, 8, "iron_dark").move(0, 0, 2.0))
    b.add(cylinder(0.3, 0.24, H - 2.0, 8, "timber").move(0, 0, 2.0), grad=("range", 0.25, 0.8))
    cz = H - 1.4
    bar = cylinder(0.2, 0.2, W + 1.4, 6, "wood_dark").rotate(math.pi / 2, "Y").move(-(W + 1.4) / 2, yb, cz)
    b.add(bar)
    for sx in (-1, 1):
        b.add(lathe([(0.0, 0.0), (0.32, 0.12), (0.32, 0.4), (0.0, 0.66)], 6, kcol(k, "trim"))
              .rotate(sx * math.pi / 2, "Y").move(sx * (W + 1.4) / 2, yb, cz))
    b.add([pc.move(0, 0, cz - 0.5) for pc in lashing(0.27, 1.0, turns=1)])
    b.add(finial(k, "spear" if k in ("red", "green") else "crown"), tag="finial")
    for pc in b.pieces:
        if pc.tag == "finial":
            pc.move(0, 0, H)
            pc.tag = ""
    hanging_cloth(b, k, W, L, cz + 0.05, "point" if k in ("red", "yellow") else "swallow",
                  p["emblem"], rng, y0=yb, lean=0.45, emb_z=0.4)
    b.socket("base", 0, 0, 0)
    b.socket("top", 0, 0, H + 2.0)


def build_mast(b, p, rng):
    k = p["kingdom"]
    H = rng.uniform(20.0, 23.0)
    L = rng.uniform(9.4, 10.4) if p["n"] == 1 else rng.uniform(8.4, 9.0)
    FH = rng.uniform(5.0, 5.5) if p["n"] == 1 else rng.uniform(4.6, 5.0)
    stone, sdark = kcol(k, "stone"), kcol(k, "stone_dark")
    b.add(kit.bbox(3.6, 3.6, 0.8, sdark, 0.15))
    b.add(kit.bbox(2.6, 2.6, 0.9, stone, 0.15).move(0, 0, 0.8))
    for a in range(4):  # timber wedges around the mast foot
        w = kit.oriented_box((0, -0.95, 1.7), (0, -0.45, 3.1), 0.5, 0.4, "wood", Vector((0, -1, 0.35)))
        b.add(w.rotate(a * math.pi / 2 + math.pi / 4, "Z"))
    b.add(cylinder(0.36, 0.24, H - 1.7, 8, "timber").move(0, 0, 1.7), grad=("range", 0.25, 0.8))
    b.add(cylinder(0.4, 0.4, 0.4, 8, "iron_dark").move(0, 0, 4.2))
    b.add(cylinder(0.33, 0.33, 0.35, 8, "iron_dark").move(0, 0, H - 2.4))
    b.add([pc.move(0, 0, H) for pc in finial(k, "ball")])
    top = H - 0.6
    flying_flag(b, k, L, FH, top, p["emblem"], rng, notch=2.2 if p["n"] == 1 else 1.6)
    # halyard: from the truck down the mast to a cleat
    b.add(rope([(0.3, -0.3, H - 0.3), (0.36, -0.36, H * 0.55), (0.42, -0.34, 4.9)], r=0.07, seg=4))
    b.add(box(0.25, 0.9, 0.25, "iron_dark").move(0.4, -0.2, 4.6))
    b.socket("base", 0, 0, 0)
    b.socket("top", 0, 0, H + 1.1)


def build_wall(b, p, rng):
    k = p["kingdom"]
    W = rng.uniform(5.4, 6.2) if p["n"] == 2 else rng.uniform(4.8, 5.4)
    L = rng.uniform(10.5, 12.0)
    trim = kcol(k, "trim")
    bottom = "swallow" if k in ("blue", "red") else "point"
    top = L + 2.2
    yw = 0.0  # wall plane (back of the brackets)
    yc = -1.15  # cloth mid-plane
    # iron rod with knob ends, held by two L brackets on wall plates
    rod = cylinder(0.16, 0.16, W + 1.6, 6, "iron_dark").rotate(math.pi / 2, "Y").move(-(W + 1.6) / 2, yc, top)
    b.add(rod)
    for sx in (-1, 1):
        b.add(lathe([(0.0, 0.0), (0.32, 0.15), (0.3, 0.45), (0.0, 0.7)], 6, trim)
              .rotate(sx * math.pi / 2, "Y").move(sx * (W + 1.6) / 2, yc, top))
        xb = sx * (W / 2 + 0.35)
        b.add(box(0.7, 0.18, 1.6, "iron_dark").move(xb, yw - 0.09, top - 1.1))  # wall plate
        b.add(kit.oriented_box((xb, yw - 0.15, top + 0.05), (xb, yc - 0.1, top + 0.05), 0.22, 0.22, "iron_dark",
                               Vector((0, 0, 1))))
        b.add(kit.oriented_box((xb, yw - 0.15, top - 1.0), (xb, yc * 0.45, top - 0.05), 0.18, 0.18, "iron_dark",
                               Vector((1, 0, 0))))
        b.add(box(0.26, 0.12, 0.26, "iron").move(xb, yw - 0.22, top - 0.4))  # nail head
    # ornamental top board above the rod (painted pelmet)
    pel = kit.bbox(W + 0.6, 0.35, 0.9, kcol(k, "cloth_dark"), 0.1).move(0, yc - 0.05, top + 0.25)
    b.add(pel)
    b.add(box(W + 0.75, 0.42, 0.18, trim).move(0, yc - 0.05, top + 0.25))
    b.add(box(W + 0.75, 0.42, 0.18, trim).move(0, yc - 0.05, top + 0.97))
    low = hanging_cloth(b, k, W, L, top - 0.05, bottom, p["emblem"], rng, y0=yc, amp=0.22, emb_z=0.36)
    b.socket("base", 0, yw, low)
    b.socket("top", 0, yw, top)


def build_standard(b, p, rng):
    k = p["kingdom"]
    big = p["emblem"] == "oak"
    H = rng.uniform(15.0, 15.8) if big else rng.uniform(12.2, 12.8)
    W = rng.uniform(5.6, 6.0) if big else rng.uniform(4.2, 4.6)
    L = rng.uniform(6.6, 7.0) if big else rng.uniform(4.6, 5.0)
    trim = kcol(k, "trim")
    # cairn of field stones around the iron-shod butt
    for i in range(2):
        a = math.tau * i / 2 + rng.uniform(-0.25, 0.25) + 0.6
        r = rng.uniform(0.95, 1.1)
        st = kit.bbox(rng.uniform(1.5, 1.8), rng.uniform(1.2, 1.4), rng.uniform(0.9, 1.2), "stone", 0.22)
        st.rotate(a + rng.uniform(-0.4, 0.4), "Z").move(math.cos(a) * r, math.sin(a) * r, 0)
        b.add(st.jitter(rng, 0.08).paint(tint=rng.uniform(0.2, 0.8)))
    b.add(box(1.4, 1.4, 1.6, "stone_dark").rotate(0.4, "Z").jitter(rng, 0.06))  # half hidden by the cairn
    b.add(cylinder(0.3, 0.26, H, 8, "wood_dark"), grad=("range", 0.25, 0.8))
    b.add(cylinder(0.35, 0.35, 0.4, 8, "iron_dark").move(0, 0, 2.2))
    yb = -0.44
    cz = H - 2.6
    bar = cylinder(0.18, 0.18, W + 1.0, 6, "wood_dark").rotate(math.pi / 2, "Y").move(-(W + 1.0) / 2, yb, cz)
    b.add(bar)
    for sx in (-1, 1):
        b.add(cone(0.32, 0.75, 6, trim).rotate(sx * math.pi / 2, "Y").move(sx * (W + 1.0) / 2, yb, cz))
    hanging_cloth(b, k, W, L, cz + 0.02, "tails", p["emblem"], rng, y0=yb, amp=0.2, side_trim=False,
                  emb_size=W * 0.62, emb_z=0.36, fringe=False, lean=0.35, emb_mid=None,
                  us=(0.0, 0.07, 0.35, 0.68, 0.87, 1.0))
    # 3D emblem topper in trim metal on a socket
    es = 2.8 if big else 3.2
    parts = emblem(p["emblem"], es, trim, kcol(k, "emblem"), depth=0.4, mid=None)
    for pc in parts:
        pc.move(0, 0, H + 0.5 + es / 2)
    b.add(parts, grad=("range", 0.4, 1.0), tag="emblem")
    b.add(lathe([(0.24, 0.0), (0.44, 0.25), (0.2, 0.7), (0.2, 0.95)], 6, trim).move(0, 0, H - 0.1))
    b.socket("base", 0, 0, 0)
    b.socket("top", 0, 0, H + 0.5 + es)


def build(b, p):
    rng = b.rng
    {"pole": build_pole, "mast": build_mast, "wall": build_wall, "standard": build_standard}[p["type"]](b, p, rng)
    b.stats["cloth"] = b.count_tag("cloth")
    b.stats["pieces"] = len(b.pieces)
