"""Modular farm fences: one 16-stud segment along X with a post at each end, so segments chain
end-to-end at a 16-stud pitch (sockets `end_left` / `end_right` sit on the end-post centres).
All variants share the SAME end post (identical geometry and shading, no jitter), so mixed
fence types chain cleanly and coincident end posts of neighbouring segments render identically.

Variants: split-rail fence, picket fence, woven wattle fence (rods really weave over/under the
stakes), open double gate between rail wings, dry-stone wall with a timber top rail, and a
rustic log fence with X braces. Height 3.0-3.4 (chest height); gate posts stand taller.
Front faces Blender -Y; the gate opens inwards (+Y).
"""

import math

from lib import kit
from lib.geo import Vector, box, cylinder, frustum_box, prism

from generators import _farm_common as fc

NAME = "farm_fence"
VERSION = 1
CATEGORY = "farm"
BUDGET = "prop_small"
COLLISION = {"fidelity": "None"}  # explicit boxes per style (gate opening stays open)
CHECKS = {"min_members": 6}
DEFAULT_VARIANTS = 6
HERO_VIEW = {"azimuth": 28, "elevation": 16}

SEG = 16.0  # end-post centre to end-post centre
POST_W, POST_H = 0.8, 3.0  # end posts: 0.8 square, 3.0 + 0.35 cap = 3.35 tall

STYLES = ["rail", "picket", "wattle", "gate", "stonewall", "xbrace"]


def asset_id(i, params):
    return f"{CATEGORY}_fence_{i + 1:02d}"


def variants(n, seed):
    return [{"style": STYLES[i % len(STYLES)], "seed": seed * 1000 + 400 + i} for i in range(n)]


# ------------------------------------------------------------------ shared members

def end_post(x):
    """The shared chaining post (deterministic: fixed tint, no jitter)."""
    body = kit.bbox(POST_W, POST_W, POST_H, "wood", 0.1).paint(tint=0.5, grad=("range", 0.25, 0.85))
    cap = frustum_box(POST_W + 0.12, POST_W + 0.12, 0.2, 0.2, 0.35, "wood_dark").paint(tint=0.5)
    return [body.move(x, 0, 0), cap.move(x, 0, POST_H)]


def post(rng, x, h=3.0, w=0.62, color="wood_dark", y=0.0):
    p = kit.bbox(w, w, h, color, 0.08).jitter(rng, 0.03)
    p.rotate(rng.uniform(-0.03, 0.03), "Y").move(x, y, 0)
    cap = frustum_box(w + 0.08, w + 0.08, 0.12, 0.12, 0.28, "wood_dark").move(x, y, h)
    return [p.paint(grad=("range", 0.25, 0.85)), cap]


def rail(rng, x0, x1, z, y=0.0, w=0.5, t=0.34, color="wood_light", sag=0.08):
    """Split rail between two posts: slightly sagging, twisted, jittered box."""
    L = x1 - x0
    r = box(L, t, w, color, base=False)
    r.bend(lambda v: (v.x, v.y, v.z - sag * (1 - (2 * v.x / L) ** 2)))
    r.jitter(rng, 0.04).rotate(rng.uniform(-0.04, 0.04), "X")
    return r.move((x0 + x1) / 2, y, z).paint(grad=("range", 0.35, 0.9))


def log(rng, p0, p1, r=0.22, color="bark_light", seg=6):
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    c = cylinder(r, r * 0.92, d.length, seg, color)
    c.transform(d.to_track_quat("Z", "Y").to_matrix().to_4x4())
    return c.move(*p0).paint(grad=("range", 0.3, 0.85))


# ------------------------------------------------------------------ styles

def style_rail(b, rng):
    xs = [-SEG / 2 + SEG * i / 4 for i in range(5)]
    n = 0
    for x in xs[1:-1]:
        b.add(post(rng, x + rng.uniform(-0.1, 0.1), 2.9 + rng.uniform(-0.1, 0.1)), tag="post")
        n += 1
    for a, c in zip(xs, xs[1:]):
        for z in (0.95, 1.85, 2.7):
            b.add(rail(rng, a + 0.2, c - 0.2, z + rng.uniform(-0.06, 0.06), y=-0.42,
                       color=rng.choice(("wood", "bark_light", "wood_light"))), tag="rail")
            n += 1
    b.collision_box(0, 0, 1.68, SEG + POST_W, 1.0, 3.35, "fence")
    return n


def style_picket(b, rng):
    """Pointed pickets on two back rails, tops dipping in a gentle scallop between the posts."""
    n = 0
    b.add(post(rng, 0.0, 2.9), tag="post")
    for z in (0.7, 2.0):
        b.add(box(SEG - 0.6, 0.26, 0.38, "wood", base=False).move(0, -0.25, z).paint(grad=("range", 0.3, 0.85)),
              tag="rail")
        n += 1
    x = -SEG / 2 + 1.0
    while x < SEG / 2 - 0.7:
        if abs(x) < 0.6:
            x += 1.15
            continue
        t = (abs(x) % (SEG / 2)) / (SEG / 2)  # 0 at a post .. 1 at the next post
        h = 2.25 + 0.6 * (2 * t - 1) ** 2 + rng.uniform(-0.05, 0.05)
        poly = [(-0.24, 0.0), (0.24, 0.0), (0.24, h - 0.38), (0.0, h), (-0.24, h - 0.38)]
        pk = prism(poly, 0.16, rng.choice(("wood_pale", "wood_pale", "wood_light")), axis="Y")
        pk.rotate(rng.uniform(-0.04, 0.04), "Y").move(x, -0.5, 0.25)
        b.add(pk.paint(grad=("range", 0.3, 1.0)), tag="picket")
        n += 1
        x += 1.15
    b.collision_box(0, 0, 1.68, SEG + POST_W, 1.0, 3.35, "fence")
    return n


def style_wattle(b, rng):
    """Six withy rods woven over/under eleven stakes (real weave, alternating phase per rod)."""
    n = 0
    stakes = [-SEG / 2 + SEG * i / 10 for i in range(11)]
    for i, x in enumerate(stakes[1:-1], 1):
        st = fc.stake(3.15 + rng.uniform(-0.12, 0.15), 0.19, "bark", seg=3, point=0.35)
        b.add(st.rotate(rng.uniform(-0.04, 0.04), "X").move(x, 0, 0), tag="stake")
        n += 1
    rods = 6
    for r in range(rods):
        z = 0.42 + r * 0.44
        pts = []
        for i, x in enumerate(stakes):
            off = 0.2 if (i + r) % 2 == 0 else -0.2
            if i in (0, len(stakes) - 1):
                off *= 0.4
            pts.append((x if 0 < i < len(stakes) - 1 else x * 0.97, off, z + rng.uniform(-0.05, 0.05)))
        rod = fc.tube(pts, [0.21] * len(pts), 4, ("bark_light", "wood_light")[r % 2])
        b.add(rod.paint(grad=("range", 0.3, 0.95)), tag="rod")
        n += 1
    b.collision_box(0, 0, 1.68, SEG + POST_W, 1.0, 3.35, "fence")
    return n


def gate_leaf(rng, w, h, hinge_side):
    """Five-bar gate leaf in local coords: hinge stile at x=0, leaf extending +X, base z=0."""
    out = []
    out.append(box(0.36, 0.3, h, "wood").move(0.18, 0, 0))  # hinge stile
    out.append(box(0.3, 0.3, h * 0.92, "wood").move(w - 0.15, 0, 0))  # latch stile
    for k in range(5):
        z = 0.35 + (h - 0.6) * k / 4
        out.append(box(w - 0.3, 0.24, 0.3 if k else 0.38, rng.choice(("wood_light", "wood")), base=False)
                   .move(w / 2, 0, z).paint(grad=("range", 0.35, 0.9)))
    out.append(kit.oriented_box((0.4, 0, 0.35), (w - 0.35, 0, h - 0.35), 0.28, 0.24, "wood", Vector((0, -1, 0))))
    for z in (0.5, h - 0.6):  # iron strap hinges
        out.append(box(1.2, 0.34, 0.16, "iron_dark", base=False).move(0.6, 0, z))
    out.append(box(0.18, 0.4, 0.4, "iron").move(w - 0.1, 0, h * 0.55))  # latch
    return out


def style_gate(b, rng):
    n = 0
    open_w = 7.6  # clear opening between the gate posts
    gx = open_w / 2 + 0.5
    for s in (-1, 1):
        gp = kit.bbox(1.0, 1.0, 3.9, "wood_dark", 0.12).move(s * gx, 0, 0).paint(grad=("range", 0.25, 0.85))
        b.add(gp, tag="post")
        b.add(frustum_box(1.15, 1.15, 0.25, 0.25, 0.45, "timber").move(s * gx, 0, 3.9), tag="post")
        b.add(box(1.3, 1.3, 0.22, "iron_dark").move(s * gx, 0, 3.55), tag="post")
        # short rail wings to the end posts
        a, c = sorted((s * (gx + 0.5), s * (SEG / 2 - 0.4)))
        for z in (0.95, 1.85, 2.7):
            b.add(rail(rng, a, c, z + rng.uniform(-0.05, 0.05), y=-0.42, sag=0.04,
                       color=rng.choice(("wood", "bark_light"))), tag="rail")
            n += 1
        # leaf: hinged on this post, swung open ~72 degrees inwards (+Y)
        lw = open_w / 2 - 0.05
        leaf = gate_leaf(rng, lw, 3.0, s)
        ang = math.radians(72 + rng.uniform(-6, 6))
        for q in leaf:
            if s > 0:
                q.rotate(math.pi, "Z")  # leaf extends -X from the right post
            q.rotate(-s * ang, "Z").move(s * (gx - 0.55), 0.35, 0.25)
            b.add(q, tag="gate")
        n += 2
    # worn path stones through the opening
    for k in range(3):
        st = fc.fieldstone(rng, rng.uniform(1.5, 2.1), rng.uniform(1.1, 1.4), 0.34, rng.choice(("cobble", "stone")))
        b.add(st.rotate(rng.uniform(-0.3, 0.3), "Z").move(rng.uniform(-1.6, 1.6), -1.6 + k * 1.5, -0.2)
              .paint(tint=rng.uniform(0, 1)), tag="path")
    for s in (-1, 1):
        mid = s * (gx + SEG / 2) / 2
        b.collision_box(mid, 0, 1.68, SEG / 2 - gx + 0.9, 1.0, 3.35, f"wing_{'l' if s < 0 else 'r'}")
    b.socket("gate", 0.0, -1.5, 0.0)
    return n


def style_stonewall(b, rng):
    n = 0
    x0, x1 = -SEG / 2 + 0.5, SEG / 2 - 0.5
    courses = [(0.0, 0.85, 1.45), (0.82, 0.75, 1.3), (1.55, 0.42, 1.5)]
    for ci, (z, h, d) in enumerate(courses):
        cols = ("stone", "stone_light", "granite") if ci < 2 else ("stone_light", "stone_pale", "granite_light")
        blk = (1.3, 2.1) if ci < 2 else (1.6, 2.4)
        u = x0 + (0.0 if ci % 2 == 0 else -0.6)
        while u < x1 - 0.3:
            bl = min(rng.uniform(*blk), x1 - max(u, x0))
            if x1 - (u + bl) < 0.8:
                bl = x1 - max(u, x0)
            lo = max(u, x0)
            st = fc.fieldstone(rng, bl - 0.1, d * rng.uniform(0.92, 1.05), h * rng.uniform(0.9, 1.1), rng.choice(cols))
            st.rotate(rng.uniform(-0.03, 0.03), "Z").move(lo + bl / 2, rng.uniform(-0.05, 0.05), z)
            b.add(st.paint(tint=rng.uniform(0, 1), grad=("range", 0.25, 0.9)), tag="stone")
            n += 1
            u = lo + bl
    # timber top: short posts set into the cap, one rail on top
    top = 1.97
    for x in (-SEG / 4, 0.0, SEG / 4):
        b.add([q.move(0, 0, top) for q in post(rng, x, 1.25, 0.5)], tag="post")
    b.add(rail(rng, -SEG / 2 + 0.4, SEG / 2 - 0.4, top + 1.05, y=0.0, w=0.42, t=0.42, sag=0.03), tag="rail")
    b.add(rail(rng, -SEG / 2 + 0.4, SEG / 2 - 0.4, top + 0.45, y=0.0, w=0.32, t=0.3, sag=0.03), tag="rail")
    n += 3
    b.collision_box(0, 0, 1.68, SEG + POST_W, 1.5, 3.35, "wall")
    return n


def style_xbrace(b, rng):
    n = 0
    xs = [-SEG / 2 + SEG * i / 4 for i in range(5)]
    for x in xs[1:-1]:
        b.add(log(rng, (x, 0, 0), (x + rng.uniform(-0.05, 0.05), 0, 3.05), 0.3, "bark"), tag="post")
        b.add(cylinder(0.31, 0.24, 0.14, 6, "wood_pale").move(x, 0, 3.02), tag="post")
        n += 1
    yb = -0.5
    for a, c in zip(xs, xs[1:]):
        a2, c2 = a + 0.35, c - 0.35
        b.add(log(rng, (a2 - 0.25, yb, 2.75), (c2 + 0.25, yb, 2.75 + rng.uniform(-0.05, 0.05)), 0.21), tag="rail")
        b.add(log(rng, (a2 - 0.25, yb, 0.45), (c2 + 0.25, yb, 0.45), 0.19, "bark"), tag="rail")
        b.add(log(rng, (a2, yb - 0.05, 0.6), (c2, yb - 0.05, 2.55), 0.17), tag="brace")
        b.add(log(rng, (a2, yb + 0.12, 2.55), (c2, yb + 0.12, 0.6), 0.17), tag="brace")
        n += 4
    b.collision_box(0, 0, 1.68, SEG + POST_W, 1.2, 3.35, "fence")
    return n


def tuft(rng, x, y, n=4, color="grass"):
    """Grass tuft at a post foot: a few solid blades (accent that seats the fence in the terrain)."""
    out = []
    for k in range(n):
        bl = fc.blade(0.12, rng.uniform(0.55, 0.95), rng.choice((color, "grass_light", "grass_dark")))
        bl.rotate(rng.uniform(0.15, 0.45), "Y").rotate(rng.uniform(0, math.tau), "Z")
        out.append(bl.move(x + rng.uniform(-0.2, 0.2), y + rng.uniform(-0.2, 0.2), 0).paint(grad=("range", 0.2, 1.0)))
    return out


def flowers(rng, x, y, n=3):
    out = []
    for k in range(n):
        px, py = x + rng.uniform(-0.5, 0.5), y + rng.uniform(-0.25, 0.25)
        h = rng.uniform(0.6, 1.0)
        out.append(box(0.07, 0.07, h, "crop_dark").move(px, py, 0))
        out.append(fc.spindle(0.2, 0.32, rng.choice(("flower_red", "flower_yellow", "flower_white", "flower_purple")),
                              seg=5).move(px, py, h - 0.1))
    return out


def accents(b, rng, style):
    if style == "picket":
        for x in (-SEG / 4 + rng.uniform(-1, 1), SEG / 4 + rng.uniform(-1, 1)):
            b.add(flowers(rng, x, -0.85, 3), tag="flower")
            b.add(tuft(rng, x + 0.6, -0.8, 3), tag="tuft")
    elif style == "wattle":
        for x in (-SEG / 2 + 1.6, SEG / 2 - 1.6):  # withy ties on the end stakes
            b.add(cylinder(0.24, 0.24, 0.16, 4, "rope").move(x, 0, 2.95), tag="tie")
    elif style == "stonewall":
        for k in range(3):  # moss on the cap stones
            m = fc.fieldstone(rng, rng.uniform(1.0, 1.8), rng.uniform(0.9, 1.3), 0.14, rng.choice(("moss", "grass_dark")))
            b.add(m.move(rng.uniform(-6.5, 6.5), rng.uniform(-0.1, 0.1), 1.92), tag="moss")
        for k in range(3):  # fallen stones and weeds at the foot
            x = rng.uniform(-6.5, 6.5)
            st = fc.fieldstone(rng, rng.uniform(0.6, 0.9), 0.6, 0.45, rng.choice(("stone", "granite")))
            b.add(st.rotate(rng.uniform(0, 3), "Z").move(x, -1.05, 0), tag="stone")
            b.add(tuft(rng, x + 0.6, -0.95, 3), tag="tuft")
    elif style == "xbrace":
        for k in range(4):  # iron bolts where the braces cross
            x = -SEG / 2 + SEG * (k + 0.5) / 4
            b.add(box(0.26, 0.2, 0.26, "iron_dark", base=False).move(x, -0.78, 1.58), tag="bolt")
    elif style == "rail":
        for x in (-SEG / 4, 0.0, SEG / 4):  # rope lashings where the rails meet the posts
            for z in (0.95, 1.85, 2.7):
                if rng.random() < 0.6:
                    b.add(box(0.3, 0.8, 0.62, "rope").move(x, -0.25, z - 0.31), tag="tie")
        b.add(tuft(rng, rng.uniform(-6, 6), -0.6, 4), tag="tuft")


def build(b, p):
    rng = b.rng
    for x in (-SEG / 2, SEG / 2):
        b.add(end_post(x), tag="end_post")
    style = p["style"]
    n = {"rail": style_rail, "picket": style_picket, "wattle": style_wattle, "gate": style_gate,
         "stonewall": style_stonewall, "xbrace": style_xbrace}[style](b, rng)
    accents(b, rng, style)
    b.socket("end_left", -SEG / 2, 0.0, 0.0)
    b.socket("end_right", SEG / 2, 0.0, 0.0)
    b.stats["members"] = n
