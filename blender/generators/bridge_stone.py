"""Arched stone river bridges (1, 2 or 3 arches), storybook humpback profile.

Bridge runs along X (deck ends at x = +-L/2), arches face the front (-Y). Deck ends sit at
ground level (z ~ 0.5 after the slabs), the deck rises over the arches; the river channel
is expected to be carved below z = 0 under the arches. Walkable width between the
parapets is 12 studs; parapets 3.2 high above the deck (coping included).

Parts: one masonry body (spandrels + arch soffits + ramps), voussoir rings with keystones on
both faces, pointed pier cutwaters, string course, parapet walls with individual coping
stones, staggered flagstone (sett) deck, end pillars with caps, footing boulders with moss.
Sockets: end_a (x-) / end_b (x+) = centre of each deck end at ground level.
"""

import math

from lib import kit
from lib.geo import Piece, Vector, box, prism, recalc_normals

NAME = "bridge_stone"
VERSION = 1
CATEGORY = "bridge"
BUDGET = "bridge"
COLLISION = {"fidelity": "PreciseConvexDecomposition"}
CHECKS = {"min_arches": 1, "min_slabs": 40, "min_coping": 12}
DEFAULT_VARIANTS = 3
HERO_VIEW = {"azimuth": 30, "elevation": 18}
LINEUP_GAP = 6.0

WALK = 12.0  # clear deck width between parapets
PAR_T = 1.2  # parapet thickness
WT = WALK + 2 * PAR_T  # total width of the body

PALETTES = (
    {"body": "stone", "light": "stone_light", "dark": "stone_dark", "deck": "cobble", "pale": "stone_pale"},
    {"body": "sandstone", "light": "sandstone_light", "dark": "sandstone_dark", "deck": "path_sand",
     "pale": "sandstone_light"},
    {"body": "stone_cool", "light": "stone_cool_light", "dark": "stone_cool_dark", "deck": "cobble",
     "pale": "stone_pale"},
)


def variants(n, seed):
    out = []
    for i in range(n):
        arches = (1, 2, 3)[i % 3]
        out.append({"arches": arches, "length": (40.0, 48.0, 56.0)[i % 3], "palette": i % 3, "seed": seed * 1000 + i})
    return out


def asset_id(i, p):
    return f"{CATEGORY}_stone_{p['arches']}arch_{i // 3 + 1:02d}"


# ------------------------------------------------------------------ geometry helpers

def colored_prism_y(poly, depth, colors):
    """prism(axis Y) with per-side-face colours: colors[i] for the side from poly[i] to
    poly[i+1]; caps take colors[-1]... use the body colour passed as cap."""
    p = prism(poly, depth, colors["cap"], axis="Y")
    n = len(poly)
    fc = [colors["cap"], colors["cap"]] + [colors["side"](i) for i in range(n)]
    p.face_colors = fc
    return p


def ribbon(pts_lo, pts_hi, y0, y1, color):
    """Closed solid swept along stations: at station i the cross-section is the rectangle
    y0..y1 x z_lo..z_hi at x_i. pts_lo/hi: [(x, z)]."""
    verts, faces = [], []
    for (x, zl), (_, zh) in zip(pts_lo, pts_hi):
        verts += [(x, y0, zl), (x, y1, zl), (x, y1, zh), (x, y0, zh)]
    m = len(pts_lo)
    for i in range(m - 1):
        a, b = 4 * i, 4 * (i + 1)
        for k in range(4):
            k2 = (k + 1) % 4
            faces.append((a + k, b + k, b + k2, a + k2))
    faces.append((0, 1, 2, 3))
    e = 4 * (m - 1)
    faces.append((e + 3, e + 2, e + 1, e + 0))
    return recalc_normals(Piece(verts, faces, color))


def clamp0(piece):
    """Keep a piece above the ground plane (the deck ends must stay at z = 0)."""
    return piece.bend(lambda v: (v.x, v.y, max(v.z, 0.0)))


# ------------------------------------------------------------------ build

def build(b, p):
    rng = b.rng
    n = p["arches"]
    L = p["length"]
    pal = PALETTES[p["palette"]]
    body, light, dark, deckc = pal["body"], pal["light"], pal["dark"], pal["deck"]
    zend = 0.3
    if n == 1:
        Hc, u0 = rng.uniform(8.6, 9.0), 0.12
        arches = [(-11.0, 11.0)]
    elif n == 2:
        Hc, u0 = rng.uniform(8.0, 8.4), 0.3
        arches = [(-16.5, -2.2), (2.2, 16.5)]
    else:
        Hc, u0 = rng.uniform(8.2, 8.6), 0.3
        arches = [(-21.0, -10.2), (-7.0, 7.0), (10.2, 21.0)]

    def deck_z(x):
        u = abs(2 * x / L)
        top = 1 - 0.05 * (min(u, u0) / u0) ** 2 if u0 > 0 else 1.0
        if u <= u0:
            f = top
        else:
            t = min(1.0, (u - u0) / (1 - u0))
            f = top * math.cos(t * math.pi / 2) ** 1.3
        return zend + (Hc - zend) * f

    N = 18 if n == 1 else 20
    xs = [-L / 2 + L * i / N for i in range(N + 1)]
    top_pts = [(x, deck_z(x)) for x in xs]

    # --- masonry body outline (CCW in XZ): bottom with arch openings, ends, deck top
    arch_geo = []
    pts = [(-L / 2, 0.0, "b")]
    for a, c in arches:
        s_ = c - a
        m = (a + c) / 2
        h = deck_z(m) - 1.75
        R = (s_ * s_ / 4 + h * h) / (2 * h)
        zc = h - R
        th0 = math.atan2(0 - zc, a - m)  # left springing angle (> pi/2)
        th1 = math.atan2(0 - zc, c - m)
        seg = 10 if s_ > 12 else 8
        arch_geo.append((m, zc, R, th0, th1, h, s_))
        pts.append((a, 0.0, "b"))
        for i in range(1, seg):
            th = th0 + (th1 - th0) * i / seg
            pts.append((m + R * math.cos(th), zc + R * math.sin(th), "a"))
        pts.append((c, 0.0, "b"))
    pts.append((L / 2, 0.0, "b"))
    pts += [(x, z, "t") for x, z in reversed(top_pts)]
    outline = [(x, z) for x, z, _ in pts]

    def edge_col(i):
        t0, t1 = pts[i][2], pts[(i + 1) % len(pts)][2]
        if t0 == "t" and t1 == "t":
            return dark  # deck bed (shows as mortar between the flagstones)
        if "a" in (t0, t1):
            return dark  # arch soffit
        if t0 == "b" and t1 == "b":
            return dark  # underside / pier feet
        return body  # end faces

    bodyp = colored_prism_y(outline, WT, {"cap": body, "side": edge_col})
    b.add(bodyp, grad=("range", 0.25, 0.85))
    b.stats["arches"] = len(arches)

    # --- voussoir rings with keystones, both faces
    for (m, zc, R, th0, th1, h, s) in arch_geo:
        arc = R * abs(th0 - th1)
        nv = max(7, int(arc / 1.9)) | 1  # odd count so a keystone sits on the crown
        for i in range(nv):
            th = th0 + (th1 - th0) * (i + 0.5) / nv
            key = i == nv // 2
            r0, r1 = R - 0.05, R + (1.65 if key else 1.3) + rng.uniform(-0.08, 0.1)
            d = Vector((math.cos(th), 0, math.sin(th)))
            w = arc / nv - 0.14
            for sy in (-1, 1):
                y = sy * (WT / 2 + 0.08)
                p0 = Vector((m, y, zc)) + d * r0
                p1 = Vector((m, y, zc)) + d * r1
                vs = kit.oriented_box(p0, p1, w * (1.25 if key else 1.0), 0.5, light if (i % 2 == 0) else body,
                                      Vector((0, 1, 0)))
                b.add(clamp0(vs).paint(tint=rng.uniform(0.2, 0.8)))
        # impost blocks at the springing
        for xx in (m + R * math.cos(th0), m + R * math.cos(th1)):
            for sy in (-1, 1):
                b.add(box(1.6, 0.5, 0.8, dark).move(xx, sy * (WT / 2 + 0.1), 0.0))

    # --- pier cutwaters (pointed, both faces) between neighbouring arches
    for (a0, c0), (a1, c1) in zip(arches, arches[1:]):
        x0, x1 = c0, a1
        xm = (x0 + x1) / 2
        hcw = min(deck_z(x0), deck_z(x1)) - 4.4
        for sy in (-1, 1):
            yb = sy * (WT / 2 - 0.3)
            poly = [(x0 + 0.05, yb), (x1 - 0.05, yb), (xm, sy * (WT / 2 + 2.6))]
            if sy > 0:
                poly = [poly[0], poly[2], poly[1]]
            cw = prism(poly, hcw, body, axis="Z")
            b.add(cw.paint(grad=("range", 0.2, 0.8)))
            cap = prism(poly, 1.6, light, axis="Z")
            cy = sum(q[1] for q in poly) / 3
            cap.taper(0.0, 1.6, 1.0, 0.12, center=(xm, cy)).move(0, 0, hcw)
            b.add(cap)
            # pilaster rising from the cutwater to the string course
            ztop = min(deck_z(x0), deck_z(x1)) - 0.9
            b.add(box(min(2.4, x1 - x0 - 0.4), 0.7, ztop - hcw - 0.4, light)
                  .move(xm, sy * (WT / 2 + 0.05), hcw + 0.4), grad=("range", 0.3, 0.85))

    # --- ashlar accents on the spandrel faces (protruding blocks, staggered tints)
    nblk = {1: 16, 2: 13, 3: 10}[n]
    for sy in (-1, 1):
        placed = []
        tries = 0
        while len(placed) < nblk and tries < 400:
            tries += 1
            w, hh = rng.uniform(1.5, 2.6), rng.uniform(0.75, 0.95)
            x = rng.uniform(-L / 2 + 3.0, L / 2 - 3.0)
            z = rng.uniform(0.6, deck_z(x) - 1.3 - hh)
            if z < 0.5:
                continue
            corners = [(x - w / 2, z), (x + w / 2, z), (x - w / 2, z + hh), (x + w / 2, z + hh)]
            if any(cz > deck_z(cx) - 1.1 for cx, cz in corners):
                continue
            bad = False
            for (m, zc, R, th0, th1, h, s_) in arch_geo:
                for cx, cz in corners:
                    if math.hypot(cx - m, cz - zc) < R + 1.75 and abs(cx - m) < s_ / 2 + 1.8:
                        bad = True
            for (a0, c0), (a1, c1) in zip(arches, arches[1:]):
                if x + w / 2 > c0 - 1.4 and x - w / 2 < a1 + 1.4:
                    bad = True  # keep pier faces for the pilasters
            for px, pz, pw, ph in placed:
                if abs(px - x) < (pw + w) / 2 + 0.3 and abs(pz - z) < (ph + hh) / 2 + 0.25:
                    bad = True
            if bad:
                continue
            placed.append((x, z + hh / 2, w, hh))
            col = rng.choice((light, light, dark, body))
            blk = box(w, 0.36, hh, col).move(x, sy * (WT / 2 + 0.04), z)
            b.add(blk.paint(tint=rng.uniform(0.1, 0.9), grad=("range", 0.35, 0.8)))

    # --- string course under the parapets (every other station), both faces
    sc = top_pts[::2] if top_pts[::2][-1] == top_pts[-1] else top_pts[::2] + [top_pts[-1]]
    sc = [(x, z) for x, z in sc if z - 0.95 >= 0.15]  # dies into the ramps: nothing below ground (deck ends at z 0)
    for sy in (-1, 1):
        y0, y1 = sy * (WT / 2 - 0.2), sy * (WT / 2 + 0.42)
        lo = [(x, z - 0.95) for x, z in sc]
        hi = [(x, z - 0.35) for x, z in sc]
        b.add(ribbon(lo, hi, min(y0, y1), max(y0, y1), light), grad=("range", 0.5, 0.9))

    # --- parapet walls + coping stones
    xa, xb = -L / 2 + 1.7, L / 2 - 1.7
    par = [(xa, deck_z(xa))] + [(x, z) for x, z in top_pts if xa < x < xb] + [(xb, deck_z(xb))]
    coping = 0
    for sy in (-1, 1):
        y0, y1 = sy * (WT / 2 - PAR_T), sy * (WT / 2 + 0.06)
        lo = [(x, z - 0.3) for x, z in par]
        hi = [(x, z + 2.65) for x, z in par]
        b.add(ribbon(lo, hi, min(y0, y1), max(y0, y1), body), grad=("range", 0.3, 0.8))
        i = 0
        while i < len(par) - 1:  # coping stones of 1-2 segments (hand-laid rhythm)
            j = min(len(par) - 1, i + (2 if rng.random() < 0.6 else 1))
            (x0, z0), (x1, z1) = par[i], par[j]
            dvec = Vector((x1 - x0, 0, z1 - z0)).normalized()
            g = 0.06
            q0 = Vector((x0, sy * (WT / 2 - PAR_T / 2), z0 + 2.62 + 0.24)) + dvec * g
            q1 = Vector((x1, sy * (WT / 2 - PAR_T / 2), z1 + 2.62 + 0.24)) - dvec * g
            cs = kit.oriented_box(q0, q1, PAR_T + 0.35, 0.62 + rng.uniform(-0.04, 0.04), light, Vector((0, 0, 1)))
            b.add(cs.paint(tint=rng.uniform(0.15, 0.85)))
            coping += 1
            i = j
    b.stats["coping"] = coping

    # --- ashlar accents on both faces of each parapet (breaks up the long flat walls)
    npb = {1: 7, 2: 6, 3: 3}[n]
    for sy in (-1, 1):
        for face in (-1, 1):  # -1 inner (deck side), +1 outer
            yf = sy * (WT / 2 + 0.06) if face > 0 else sy * (WT / 2 - PAR_T)
            placed = []
            tries = 0
            while len(placed) < npb and tries < 200:
                tries += 1
                w, hh = rng.uniform(1.6, 2.6), rng.uniform(0.7, 0.9)
                x = rng.uniform(xa + 1.5, xb - 1.5)
                dz = rng.choice((0.35, 1.25))
                if any(abs(px - x) < (pw + w) / 2 + 0.6 for px, pw in placed):
                    continue
                placed.append((x, w))
                z = deck_z(x) + dz + (0.0 if face < 0 else 0.0)
                slope = math.atan2(deck_z(x + 0.5) - deck_z(x - 0.5), 1.0)
                blk = box(w, 0.3, hh, rng.choice((light, body, dark)), base=False).rotate(-slope, "Y")
                b.add(blk.move(x, yf + sy * face * 0.08, z + hh / 2).paint(tint=rng.uniform(0.1, 0.9)))

    # --- end pillars with pyramid caps
    for x in (-L / 2 + 0.85, L / 2 - 0.85):
        for sy in (-1, 1):
            y = sy * (WT / 2 - PAR_T / 2)
            z0 = deck_z(x) - 0.3
            b.add(kit.bbox(1.7, 1.7, 3.6, body, 0.14).move(x, y, z0))
            b.add(kit.bbox(2.0, 2.0, 0.45, light, 0.1).move(x, y, z0 + 3.6))
            if n > 1 and (x > 0) == (sy > 0):  # iron lantern on two diagonal pillars
                zl = z0 + 4.05
                b.add(box(1.1, 1.1, 0.25, "iron_dark").move(x, y, zl))
                b.add(box(0.8, 0.8, 1.1, "window_glow").move(x, y, zl + 0.25), grad=("range", 0.55, 1.0))
                for cx in (-1, 1):
                    for cy in (-1, 1):
                        b.add(box(0.16, 0.16, 1.1, "iron_dark").move(x + cx * 0.45, y + cy * 0.45, zl + 0.25))
                b.add(box(1.2, 1.2, 0.6, "iron_dark").taper(0.0, 0.6, 1.0, 0.15).move(x, y, zl + 1.35))
            else:
                cap = box(1.6, 1.6, 1.0, dark).taper(0.0, 1.0, 1.0, 0.2)
                b.add(cap.move(x, y, z0 + 4.05))

    # --- flagstone deck: staggered rows following the hump
    slabs = 0
    yl, yr = -WALK / 2 + 0.05, WALK / 2 - 0.05
    widths_a = [3.0, 3.0, 3.0, 3.0]
    widths_b = [1.8, 3.0, 3.2, 4.0]
    rows = [(x0, x1) for x0, x1 in zip(xs, xs[1:])]
    for ri, (x0, x1) in enumerate(rows):
        z0, z1 = deck_z(x0), deck_z(x1)
        ws = widths_a if ri % 2 == 0 else widths_b
        tot = sum(ws)
        y = yl
        for w in ws:
            ww = w * (yr - yl) / tot
            yc = y + ww / 2
            y += ww
            dvec = Vector((x1 - x0, 0, z1 - z0)).normalized()
            q0 = Vector((x0, yc, z0 + 0.06)) + dvec * 0.07
            q1 = Vector((x1, yc, z1 + 0.06)) - dvec * 0.07
            col = rng.choice((deckc, deckc, deckc, light, light, pal["pale"]))
            sl = kit.oriented_box(q0, q1, ww - 0.14, 0.3 + rng.uniform(-0.04, 0.04), col, Vector((0, 0, 1)))
            b.add(sl.paint(tint=rng.uniform(0.1, 0.9), grad=("range", 0.45, 0.75)))
            slabs += 1
    b.stats["slabs"] = slabs

    # --- footing boulders with moss at the springings (river edge)
    springs = [m + R * math.cos(t) for (m, zc, R, th0, th1, h, s) in arch_geo for t in (th0, th1)]
    if n == 3:
        springs = springs[::2] + springs[-1:]
    for xx in springs:
        if True:
            sy = rng.choice((-1, 1))
            bx = kit.bbox(rng.uniform(1.8, 2.4), rng.uniform(1.4, 1.8), rng.uniform(0.9, 1.2), dark, 0.25)
            bx.jitter(rng, 0.12).rotate(rng.uniform(0, 3), "Z")
            b.add(clamp0(bx.move(xx + rng.uniform(-0.6, 0.6), sy * (WT / 2 + 0.7), 0.0)).paint(tint=rng.uniform(0.2, 0.8)))
            moss = box(rng.uniform(1.3, 1.7), rng.uniform(0.9, 1.2), 0.3, "moss")
            b.add(moss.jitter(rng, 0.06).move(xx + rng.uniform(-0.6, 0.6), sy * (WT / 2 + 0.7), rng.uniform(0.8, 1.0)),
                  grad=("range", 0.3, 0.9))

    b.socket("end_a", -L / 2, 0, 0)
    b.socket("end_b", L / 2, 0, 0)
    b.stats["pieces"] = len(b.pieces)
