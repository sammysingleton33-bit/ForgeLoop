"""Environment kit: crop fields (wheat in three plot variants and two growth stages, cabbage), haystack and fence, style B.

A field is ONE mesh with the footprint of the part-built stand-in (Kit/Props.luau `cropField`: 38 x 28 studs, a 0.5 soil bed, rows on
it), so the terrain field under it (40 x 30) and the placement clearance stay exactly as they are. Rows are made of tufts: a chunky
tapered clump of stalks with a leaning ear cap, each tuft its own height, lean and shade, so a field is never a wall of identical cones
(the phase-1 reviewer's variation 2). How the game shows growth today (read for FL-0136): the world places a field once, ripe, for
good (`farm_field_<crop>_NN`, NN = 1 + field index % 3); the only growth is the farm BUILDING's construction stages (furrows, shoots,
young wheat). So 01-03 are three ripe plot variants and `farm_field_wheat_stage1` / `_stage2` are the earlier growth stages, ready for a
farm that grows a crop; nothing places them yet.
"""

import math

from generators import _envkit_style as S
from lib.ckit import M, merge

FW, FD = 38.0, 28.0  # the crop plot: inside the 40 x 30 terrain field
BED = 0.5  # soil bed height (the terrain field's top is 0.2 above ground: the bed clears it)


def _soil_bed(rng, w=FW, d=FD, tag="soil"):
    """The bed: a slab with chipped corners and a slightly lighter, uneven top (flat faces, two browns)."""
    pts = []
    for sx in (-1, 1):
        for sz in (-1, 1):
            pts.append((sx * w / 2, 0.0, sz * d / 2))
            pts.append((sx * (w / 2 - 0.35), BED, sz * (d / 2 - 0.35)))
    m = S.flat(S.hull(pts, color=S.SOIL, smooth=False, tag=tag), tag)
    for i, f in enumerate(m.f):
        n = S.face_normal(m, f)
        m.c[i] = S.mix(S.SOIL_DARK, S.SOIL_RIDGE, 0.55 + 0.4 * n[1] + rng.uniform(-0.1, 0.1))
    return m


def _tuft(rng, x, z, h, w, d, stalk, ear, lean_deg=0.0, ears=True, ear_len=0.8, base=BED, tag="stalks"):
    """One crop tuft: a tapered clump (wide at the ground, narrow at the top) and, when ripe, a leaning four-sided ear."""
    a, b = w / 2, d / 2
    sk = rng.uniform(0.35, 0.65)
    lx = math.tan(math.radians(lean_deg)) * h
    pts = [(-a, base, -b), (a, base, -b), (-a, base, b), (a, base, b),
           (-a * 0.55 + lx, base + h, -b * sk), (a * 0.55 + lx, base + h, -b * sk), (-a * 0.55 + lx, base + h, b * sk), (a * 0.55 + lx, base + h, b * sk)]
    c = S.hull([(p[0] + x, p[1], p[2] + z) for p in pts], color=stalk, smooth=False, tag=tag)
    S.flat(c, tag)
    for i, f in enumerate(c.f):  # lighter toward the top, brighter on the sunny faces
        cy = sum(c.v[k][1] for k in f) / len(f)
        n = S.face_normal(c, f)
        c.c[i] = S.mul(stalk, 0.84 + 0.2 * (cy - base) / max(1e-6, h) + 0.08 * n[1] + rng.uniform(-0.04, 0.04))
    out = [c]
    if ears:
        r = rng.uniform(0.34, 0.46)
        e = S.cone(r * 1.15, ear_len, seg=3, y0=0.0, color=ear, smooth=False, tag="ear")
        S.flat(e, "ear")
        for i, f in enumerate(e.f):
            n = S.face_normal(e, f)
            e.c[i] = S.mul(ear, 0.88 + 0.16 * (0.5 + 0.5 * n[1]) + rng.uniform(-0.05, 0.05))
        e.rot(rng.uniform(-14, 14) + lean_deg * 0.5, "z").rot(rng.uniform(-10, 10), "x")
        e.move(x + lx * 0.95, base + h - 0.08, z)
        out.append(e)
    return out


def _sheaf(rng, x, z, hgt, r, color_a, color_b, base=BED):
    """A bound sheaf: a faceted cone of straw with a darker band, standing on the bed."""
    body = S.cone(r, hgt, seg=6, y0=base, color=color_a, smooth=False, tag="sheaf")
    S.flat(body, "sheaf")
    for i, f in enumerate(body.f):
        cy = sum(body.v[k][1] for k in f) / len(f)
        n = S.face_normal(body, f)
        body.c[i] = S.mul(color_b if (cy - base) < hgt * 0.38 else color_a, 0.9 + 0.2 * (0.5 + 0.5 * n[1]) + rng.uniform(-0.04, 0.04))
    return body.move(x, 0.0, z)


def wheat(variant, rng, stage=3):
    """farm_field_wheat_NN (ripe: variants 01 golden rows along x, 02 amber rows along z with poppies, 03 pale straw with a worn path and a scarecrow)
    and the growth stages (stage 1 shoots in furrows, stage 2 green-yellow wheat)."""
    parts = [_soil_bed(rng)]
    pal = {1: (S.rgb(214, 170, 62), S.rgb(244, 208, 96)), 2: (S.rgb(206, 150, 52), S.rgb(238, 186, 72)), 3: (S.rgb(206, 182, 92), S.rgb(240, 222, 140))}
    if stage == 3:
        stalk, ear = pal[variant]
        tuft_h, ears = {1: 1.45, 2: 1.5, 3: 1.4}[variant], True
    elif stage == 2:
        stalk, ear = S.rgb(140, 180, 66), S.rgb(176, 200, 84)
        tuft_h, ears = 1.15, False
    else:
        stalk, ear = S.rgb(112, 168, 70), S.rgb(142, 192, 84)
        tuft_h, ears = 0.55, False
    along_x = variant != 2 or stage != 3
    rows = 6 if along_x else 8
    length = FW - 5.0 if along_x else FD - 4.0
    span = FD - 3.0 if along_x else FW - 3.4
    pitch = span / rows
    ntuft = 13 if along_x else 9
    ridge_w = pitch * 0.55
    for r in range(rows):
        pos = -span / 2 + pitch * (r + 0.5)
        # a row ridge (slightly lighter soil) the tufts stand on
        if along_x:
            rb = S.box(length + 0.4, 0.22, ridge_w, color=S.SOIL_RIDGE, smooth=False, tag="ridge").move(0.0, BED + 0.08, pos)
        else:
            rb = S.box(ridge_w, 0.22, length + 0.4, color=S.SOIL_RIDGE, smooth=False, tag="ridge").move(pos, BED + 0.08, 0.0)
        for i, f in enumerate(rb.f):
            rb.c[i] = S.mix(S.SOIL_DARK, S.SOIL_RIDGE, 0.5 + rng.uniform(-0.2, 0.3))
        parts.append(S.flat(rb))
        wave = rng.uniform(0, math.tau)
        for k in range(ntuft):
            t = (k + 0.5) / ntuft
            u = -length / 2 + length * t + rng.uniform(-0.3, 0.3)
            if stage == 3 and variant == 3 and abs(u if along_x else 0.0) < 1.6 and along_x:
                continue  # the worn path across the plot
            sh = tuft_h * (0.84 + 0.16 * math.sin(wave + t * 6.0) + rng.uniform(-0.08, 0.1))
            col = S.mul(stalk, rng.uniform(0.9, 1.07))
            if stage == 3 and variant == 3 and rng.random() < 0.25:
                col = S.mix(col, S.rgb(150, 178, 64), 0.55)  # late patches still turning
            cw = (length / ntuft) * 1.06
            cd = pitch * 0.62
            if along_x:
                tf = _tuft(rng, u, pos + rng.uniform(-0.15, 0.15), sh, cw, cd, col, ear, rng.uniform(-8, 8), ears=ears)
            else:
                tf = _tuft(rng, pos + rng.uniform(-0.15, 0.15), u, sh, cd, cw, col, ear, rng.uniform(-8, 8), ears=ears)
            parts += tf
    if stage == 1:  # shoots: the furrows are mostly bare soil with the first green blades
        pass
    if stage == 3:
        if variant == 1:
            for x in (-FW * 0.33, 0.0, FW * 0.33):
                parts.append(_sheaf(rng, x + rng.uniform(-1, 1), FD / 2 - 0.9, 2.0, 0.95, S.rgb(226, 184, 82), S.rgb(186, 150, 64)))
        elif variant == 2:
            for z in (-FD * 0.3, 0.0, FD * 0.3):
                parts.append(_sheaf(rng, -FW / 2 + 0.9, z + rng.uniform(-1, 1), 2.1, 1.0, S.rgb(226, 170, 70), S.rgb(176, 128, 52)))
            for _ in range(7):  # poppies among the rows, on short stems
                px, pz = rng.uniform(-FW / 2 + 3, FW / 2 - 3), rng.uniform(-FD / 2 + 3, FD / 2 - 3)
                parts.append(S.flat(S.slab([(-0.07, -0.06), (0.07, -0.06), (0.0, 0.08)], BED, BED + tuft_h + 0.2, S.LEAF_DARK, tag="stem")).move(px, 0.0, pz))
                parts.append(S.blob(rng, 8, 0.42, 0.3, 0.42, px, BED + tuft_h + 0.42, pz, jitter=0.08, color=S.FLOWER["red"], tag="poppy"))
        else:
            # a scarecrow in the middle of the worn path: post, cross arm, sack head and a hat
            cx, cz = 0.0, -2.0
            post = S.flat(S.slab([(-0.16, -0.16), (0.16, -0.16), (0.16, 0.16), (-0.16, 0.16)], BED, BED + 3.1, S.WOOD, tag="scarecrow")).move(cx, 0.0, cz)
            arm = S.flat(S.slab([(-1.5, -0.12), (1.5, -0.12), (1.5, 0.12), (-1.5, 0.12)], 0.0, 0.22, S.WOOD, tag="scarecrow")).move(cx, BED + 2.2, cz)
            head = S.blob(rng, 8, 0.46, 0.46, 0.46, cx, BED + 3.3, cz, jitter=0.06, color=S.rgb(220, 200, 150), tag="scarecrow")
            hat = S.flat(S.cone(0.78, 0.55, seg=5, y0=BED + 3.55, color=S.rgb(120, 78, 46), smooth=False, tag="scarecrow")).move(cx, 0.0, cz)
            parts += [post, arm, head, hat]
            for x in (-FW * 0.36, FW * 0.36):
                parts.append(_sheaf(rng, x, FD / 2 - 0.9, 2.2, 0.95, S.rgb(214, 196, 110), S.rgb(176, 150, 70)))
    info = {"stage": stage, "rows": rows, "along": "x" if along_x else "z"}
    if stage == 3 and variant == 3:
        info["fit_note"] = ("the scarecrow reaches 4.2 studs (a citizen is 5.4) so it reads at 82 studs; the crop itself stands 2.9, the same row height as the farm "
                            "building's own wheat beside it (2.2 + ears 1.3)")
    elif stage < 3:
        info["fit_note"] = "a growth stage: shorter than the ripe field by design (stage 1 furrows and shoots, stage 2 green wheat)"
    return S.assemble(parts), info


def _cabbage(rng, x, z, d, light, y0=BED + 0.25):
    """One cabbage head: a faceted lump with two flat outer leaves."""
    head = S.ico(rng, d / 2, d * 0.42, d / 2, x, y0 + d * 0.38, z, jitter=0.07, subdiv=0, squash_bottom=0.5, color=light, tag="cabbage")
    for i, f in enumerate(head.f):
        n = S.face_normal(head, f)
        head.c[i] = S.mix(S.mul(light, 0.78), S.mix(light, (1, 1, 1), 0.12), min(1.0, 0.45 + 0.5 * n[1] + rng.uniform(-0.12, 0.12)))
    leaves = []
    for q in range(1):
        a = rng.uniform(0, math.tau)
        w = d * 0.62
        leaf = S.hull([(math.cos(a + k * math.pi / 2) * w * (1.0 if k % 2 == 0 else 0.55) + x, y0 + (0.28 if k % 2 else 0.1) + 0.0, math.sin(a + k * math.pi / 2) * w *
                        (1.0 if k % 2 == 0 else 0.55) + z) for k in range(4)] + [(x, y0 + 0.5 + 0.2 * q, z)], color=S.LEAF_DARK, smooth=False, tag="leaf")
        S.flat(leaf, "leaf")
        for i, f in enumerate(leaf.f):
            leaf.c[i] = S.mul(S.LEAF, rng.uniform(0.82, 1.0))
        leaves.append(leaf)
    return [head] + leaves


def cabbage(variant, rng):
    """farm_field_cabbage_NN: six ridges of eight cabbage heads in three greens (the placed id is 03; the stand-in has seven rows of smaller balls)."""
    parts = [_soil_bed(rng)]
    shades = [S.rgb(150, 200, 90), S.rgb(112, 178, 70), S.rgb(88, 156, 62)]
    for r in range(6):
        z = -10.5 + r * 4.2
        rb = S.box(34.0, 0.3, 2.4, color=S.SOIL_RIDGE, smooth=False, tag="ridge").move(0.0, BED + 0.1, z)
        for i in range(len(rb.f)):
            rb.c[i] = S.mix(S.SOIL_DARK, S.SOIL_RIDGE, 0.5 + rng.uniform(-0.2, 0.3))
        parts.append(S.flat(rb))
        for k in range(8):
            d = rng.uniform(2.3, 2.7)
            x = (k - 3.5) * 4.2 + rng.uniform(-0.35, 0.35) + (1.0 if (r + variant) % 2 else -0.6)
            col = shades[(k + r + variant) % 3]
            parts += _cabbage(rng, x, z + rng.uniform(-0.2, 0.2), d, col)
    return S.assemble(parts), {}


def haystack(variant, rng):
    """farm_haystack_NN: a round-shouldered stack of hay with two darker bands and a pitchfork leaning on it."""
    seg = 9
    rings = [(0.0, 3.05), (1.6, 3.2), (3.1, 3.05), (4.2, 2.35), (5.3, 1.35), (6.1, 0.0)]
    from lib.ckit import loft

    m = loft([(y, r, r) for y, r in rings], seg=seg, caps=(True, False), phase=rng.uniform(0, 1), color=S.HAY, smooth=False, tag="hay")
    S.flat(m, "hay")
    for i, f in enumerate(m.f):
        cy = sum(m.v[k][1] for k in f) / len(f)
        n = S.face_normal(m, f)
        band = S.HAY_DARK if (1.1 < cy < 1.7 or 3.0 < cy < 3.5) else S.HAY
        m.c[i] = S.mul(S.mix(band, S.rgb(236, 210, 120), 0.35 * max(0.0, n[1])), 0.92 + rng.uniform(-0.05, 0.06))
    # ragged tufts of hay on the shoulder so the outline is not a perfect dome
    parts = [m]
    for k in range(5):
        a = rng.uniform(0, math.tau)
        parts.append(S.blob(rng, 8, 0.7, 0.5, 0.7, math.cos(a) * 2.7, rng.uniform(2.2, 4.0), math.sin(a) * 2.7, jitter=0.1, color=S.HAY, tag="hay"))
    handle = S.flat(S.slab([(-0.13, -0.13), (0.13, -0.13), (0.13, 0.13), (-0.13, 0.13)], 0.0, 5.0, S.WOOD, tag="fork")).rot(-18, "z").move(3.3, 0.0, -0.8)
    parts.append(handle)
    for dz in (-0.35, 0.0, 0.35):
        tine = S.flat(S.slab([(-0.05, -0.05), (0.05, -0.05), (0.05, 0.05), (-0.05, 0.05)], 0.0, 1.0, S.IRON, tag="fork")).rot(-18, "z").move(4.6, 4.6, -0.8 + dz)
        parts.append(tine)
    return S.assemble(parts), {}


def fence(variant, rng):
    """farm_fence_NN: five posts and one (odd NN) or two (even NN) rails, 16.2 long, 2.7 high (a low field fence)."""
    parts = []
    for i in range(5):
        h = 2.7 + (0.1 if i % 2 == 0 else -0.1)
        p = S.hull([(sx * 0.25 * (1.0 if sy == 0 else 0.8), sy * h, sz * 0.25 * (1.0 if sy == 0 else 0.8)) for sx in (-1, 1) for sy in (0, 1) for sz in (-1, 1)],
                   color=S.WOOD, smooth=False, tag="post")
        S.flat(p, "post")
        for k, f in enumerate(p.f):
            n = S.face_normal(p, f)
            p.c[k] = S.mul(S.WOOD, 0.9 + 0.12 * n[1] + rng.uniform(-0.04, 0.04))
        parts.append(p.move(-8.0 + i * 4.0, 0.0, 0.0))
    for y in ((1.0, 1.95) if variant % 2 == 0 else (1.7,)):
        r = S.box(16.2, 0.32, 0.28, color=S.WOOD_LIGHT, smooth=False, tag="rail").move(0.0, y, 0.0)
        for k in range(len(r.f)):
            r.c[k] = S.mul(S.WOOD_LIGHT, rng.uniform(0.92, 1.05))
        parts.append(S.flat(r))
    return S.assemble(parts), {}
