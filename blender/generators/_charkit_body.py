"""Character kit: heads (faces), hair, torsos, arms, sleeves, legs, boots (FL-0135).

Every function builds in ROBLOX RIG AXES at the rest pose (x right, y up, -z front, feet at y = 0) and registers the
piece with the Registry. Dimensions keep Kit/Character.luau's envelopes (legs 0.95 x 2.2 x 1.0, torso 1.7 tall,
arms 0.78 x 1.7, head ~1.6, neck 3.9, shoulders 3.5, hips 2.2); the meshes are stylised inside them.
Triangle discipline (D-057 (11): <= 1,000 per assembled citizen, tool <= 150): every ring costs 2 x seg tris.
"""

import math

from lib.ckit import M, Surface, box, cone, cyl, hull, loft, merge, prism, sphere, torus, tube

from . import _charkit_style as K
from ._charkit_style import (ARM_SPLAY, ARM_X, BLUSH, CANVAS, ERMINE, HEAD_Y, HIP_Y, INK, LEATHER, LEATHER_DARK, LEG_X,
                             MOUTH, NECK_Y, SHOULDER_Y, STEEL, STEEL_DARK, TINT, mix, ph, rgb)

SKIN_SHADOW = (0.8, 0.76, 0.74)  # baked darkening on skin-tinted detail (stubble)
DARK = (0.62, 0.62, 0.62)  # baked darker band on a tinted piece (cuffs, collars, vests)


# ================================================================== heads

# cranium rings (y, rx, rz, cx, cz): chin -> crown. Shared by every head so any hair / hat fits any face.
HEAD_RINGS = [
    (3.84, 0.27, 0.25, 0.0, -0.02),
    (4.04, 0.58, 0.55, 0.0, -0.02),
    (4.34, 0.76, 0.73, 0.0, -0.01),
    (4.72, 0.80, 0.77, 0.0, 0.0),
    (5.12, 0.68, 0.65, 0.0, 0.0),
    (5.38, 0.36, 0.34, 0.0, 0.0),
    (5.44, 0.0, 0.0, 0.0, 0.0),
]


def head_radius_at(y):
    """Interpolated (rx, rz, cz) of the shared cranium at height y."""
    rs = HEAD_RINGS
    if y <= rs[0][0]:
        return rs[0][1], rs[0][2], rs[0][4]
    for a, b in zip(rs[:-1], rs[1:]):
        if a[0] <= y <= b[0]:
            t = (y - a[0]) / (b[0] - a[0])
            return (a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[4] + (b[4] - a[4]) * t)
    return 0.0, 0.0, 0.0


# face variants: eye (w, h, spacing, y), brow (len, thick, y, tilt deg) or None, nose (w, h, out), mouth (w, y, kind),
# jaw width multiplier, ear size, extras
FACES = {
    "head_01": dict(eye=(0.13, 0.15, 0.31, 4.62), brow=(0.3, 0.06, 4.86, 6), nose=(0.1, 0.11, 0.1), mouth=(0.24, 4.27, "smile"),
                    jaw=1.0, ear=1.0),
    "head_02": dict(eye=(0.14, 0.11, 0.31, 4.62), brow=(0.36, 0.07, 4.84, -7), nose=(0.13, 0.14, 0.12),
                    mouth=(0.24, 4.27, "flat"), jaw=1.08, ear=1.0),
    "head_03": dict(eye=(0.13, 0.17, 0.29, 4.60), brow=(0.24, 0.05, 4.92, 10), nose=(0.08, 0.09, 0.08),
                    mouth=(0.12, 4.28, "o"), jaw=0.93, ear=0.9),
    "head_04": dict(eye=(0.12, 0.12, 0.30, 4.62), brow=(0.36, 0.08, 4.83, -8), nose=(0.11, 0.18, 0.15),
                    mouth=(0.24, 4.26, "flat"), jaw=1.04, ear=1.15, stubble=True),
    "head_05": dict(eye=(0.15, 0.1, 0.30, 4.66), brow=(0.28, 0.06, 4.88, 12), nose=(0.10, 0.11, 0.09),
                    mouth=(0.3, 4.29, "grin"), jaw=0.98, ear=1.0, freckles=True),
    "head_06": dict(eye=(0.13, 0.13, 0.30, 4.63), brow=(0.32, 0.07, 4.85, -4), nose=(0.12, 0.13, 0.11),
                    mouth=(0.2, 4.28, "flat"), jaw=1.1, ear=1.05, stubble=True, scar=True),
}


def _blob(S, rx, ry, rz, seg, color, tag, rings=2):
    return sphere(rx, ry, rz, seg=seg, rings=rings, color=color, smooth=S.smooth and rings > 2, tag=tag, phase=ph(S, seg))


def build_head(S, p):
    seg = S.seg(10, 8)
    jaw = p.get("jaw", 1.0)
    rings = []
    for i, (y, rx, rz, cx, cz) in enumerate(HEAD_RINGS):
        k = jaw if i in (1, 2) else (1 + (jaw - 1) * 0.5 if i == 3 else 1.0)
        rings.append((y, rx * k, rz, cx, cz))
    body = loft(rings, seg=seg, n=S.n if S.A else 2.5, phase=ph(S, seg), color=TINT, smooth=S.smooth, tag="skin")
    if p.get("stubble"):
        body.paint(mix(TINT, SKIN_SHADOW, 0.5), where=lambda x, y, z: y < 4.2 and z < 0.0)
    surf = Surface(body)
    parts = [body]

    def fz(x, y):
        z = surf.front_z(x, y)
        return z if z is not None else -0.75

    ew, eh, es, ey = p["eye"]
    eseg = S.seg(6, 4)
    for sx in (-1, 1):
        x = sx * es
        # poles along z: a flat bead seen from the front (a hexagon / square), not a diamond
        parts.append(_blob(S, ew, 0.045, eh, eseg, INK, "eye").rot(90, "x").move(x, ey, fz(x, ey) + 0.01))
    if p.get("brow"):
        bl, bt, by, btilt = p["brow"]
        for sx in (-1, 1):
            x = sx * (es + 0.01)
            br = cyl(bt * 0.6, bt * 0.6, bl, seg=3, color=mix(INK, (0.3, 0.2, 0.15), 0.4), smooth=False, tag="brow").rot(90, "z").move(bl / 2, 0, 0)
            parts.append(br.rot(sx * btilt, "z").move(x, by, fz(x, by) + 0.005))
    nw, nh, no = p["nose"]
    parts.append(_blob(S, nw, nh, no, S.seg(5, 4), TINT, "nose").move(0, 4.5, fz(0, 4.5) + no * 0.1))
    mw, my, mk = p["mouth"]
    mt = 0.045
    if mk == "o":
        mouth = box(0.09, 0.08, 0.04, color=MOUTH, tag="mouth")
    elif mk in ("smile", "grin", "frown"):
        sg = -1.0 if mk == "frown" else 1.0
        mouth = tube([(-mw * 0.5, 0.04 * sg, 0.0), (0.0, -0.025 * sg, 0.02), (mw * 0.5, 0.04 * sg, 0.0)], [0.03, 0.03, 0.03], seg=3,
                     n=2.0, color=MOUTH, smooth=False, tag="mouth")
    else:
        mouth = box(mw, mt, 0.04, color=MOUTH, tag="mouth")
    parts.append(mouth.move(0, my, fz(0, my) + 0.005))
    if p.get("blush"):
        for sx in (-1, 1):
            x = sx * 0.5
            parts.append(_blob(S, 0.1, 0.06, 0.02, eseg, mix(TINT, BLUSH, 0.45), "blush").move(x, 4.4, fz(x, 4.4) + 0.005))
    if p.get("freckles"):
        for sx in (-1, 1):
            for dx, dy in ((0.0, 0.0),):
                x = sx * (0.34 + dx)
                parts.append(box(0.04, 0.04, 0.03, color=mix(TINT, (0.65, 0.42, 0.28), 0.8), tag="freckle").move(
                    x, 4.46 + dy, fz(x, 4.46 + dy) + 0.003))
    if p.get("scar"):
        parts.append(box(0.34, 0.03, 0.03, color=mix(TINT, (0.55, 0.22, 0.2), 0.7), tag="scar").rot(-35, "z").move(
            0.3, 4.5, fz(0.3, 4.5) + 0.004))
    er = p.get("ear", 1.0)
    for sx in (-1, 1):
        parts.append(_blob(S, 0.08 * er, 0.2 * er, 0.14 * er, S.seg(5, 4), TINT, "ear").move(sx * 0.78, 4.55, 0.02))
    return merge(*parts)


# ================================================================== hair (tint "hair")

def _cap(S, grow, rim_y, tilt_z, rim_flare=0.0, thick=0.1):
    """Hair cap over the cranium: a lofted shell `grow` thicker than the head whose open rim is a tilted plane.

    rim_y: rim height on the centre line; tilt_z: the rim rises towards the front for negative values
    (y = rim_y + tilt_z * z). The rim is closed with a flat cap that sits inside the head.
    """
    seg = S.seg(12, 8)
    floor = rim_y + abs(tilt_z) * 0.8 + 0.06
    rings = [(5.44 + thick, 0.0, 0.0)]
    for y in (5.3, 5.0, 4.7, 4.4):
        if y > floor:
            rx, rz, cz = head_radius_at(y)
            rings.append((y, rx + grow + (thick * 0.4 if y > 5.2 else 0.0), rz + grow + (thick * 0.4 if y > 5.2 else 0.0),
                          0.0, cz))
    rx, rz, cz = head_radius_at(rim_y)
    rings.append((rim_y, rx + grow + rim_flare, rz + grow + rim_flare, 0.0, cz))
    rings = list(reversed(rings))
    m = loft(rings, seg=seg, n=S.n if S.A else 2.5, caps=(True, False), phase=ph(S, seg), color=TINT,
             smooth=S.smooth, tag="hair")
    tilt_rim(m, seg, rim_y, tilt_z, grow + rim_flare)
    return m


def tilt_rim(m, seg, rim_y, tilt_z, grow):
    """Tilt the open rim (the first `seg` vertices) like y += tilt_z * z and re-fit each rim vertex to the head contour at its new
    height, so the flat rim cap stays inside the cranium and no dark underside sliver shows below the front edge."""
    r0 = head_radius_at(rim_y)
    for i in range(seg):
        x, y, z = m.v[i]
        y2 = y + tilt_z * z
        r1 = head_radius_at(y2)
        sx = (r1[0] + grow) / (r0[0] + grow)
        sz = (r1[1] + grow) / (r0[1] + grow)
        m.v[i] = (x * sx, y2, z * sz)


def build_hair(S, R):
    seg = S.seg(12, 8)
    n = S.n if S.A else 2.5
    sm = S.smooth

    def reg(name, m):
        m.paint(TINT)
        R.add(name, m, "Head", "hair", "hair", weld="head", tags=("hair",))

    reg("hair_01", _cap(S, 0.05, 4.76, -0.34, thick=0.1))
    reg("hair_02", _cap(S, 0.08, 4.62, -0.3, rim_flare=0.04, thick=0.12))
    curtain = loft([(3.5, 0.55, 0.16, 0.0, 0.98), (4.0, 0.76, 0.22, 0.0, 0.9), (4.5, 0.86, 0.28, 0.0, 0.64), (5.0, 0.8, 0.2, 0.0, 0.64)],
                   seg=seg, n=n, caps=(True, True), phase=ph(S, seg), color=TINT, smooth=sm, tag="hair")
    reg("hair_03", merge(_cap(S, 0.07, 4.7, -0.3, thick=0.1), curtain))
    reg("hair_04", _cap(S, 0.1, 4.45, -0.5, rim_flare=0.1, thick=0.13))
    puff = [sphere(0.98, 0.7, 0.92, seg=S.seg(10, 7), rings=S.seg(4, 3), color=TINT, smooth=sm, tag="hair").move(0, 5.02, 0.12)]
    for (x, y, z, r) in ((-0.66, 4.74, 0.28, 0.3), (0.66, 4.74, 0.28, 0.3), (0.0, 5.64, 0.1, 0.3), (0.0, 4.7, 0.82, 0.34)):
        puff.append(sphere(r, seg=S.seg(6, 5), rings=2, color=TINT, smooth=sm, tag="hair").move(x, y, z))
    reg("hair_05", merge(*puff))
    tail = tube([(0, 5.0, 0.6), (0, 4.78, 0.98), (0, 4.28, 1.12), (0, 3.78, 0.98)], [0.17, 0.2, 0.17, 0.09], seg=S.seg(6, 4),
                n=2.0, color=TINT, smooth=sm, tag="hair")
    reg("hair_06", merge(_cap(S, 0.05, 4.8, -0.34, thick=0.1), tail))
    bun = sphere(0.34, 0.3, 0.34, seg=S.seg(8, 6), rings=S.seg(4, 3), color=TINT, smooth=sm, tag="hair").move(0, 5.62, 0.14)
    reg("hair_07", merge(_cap(S, 0.05, 4.78, -0.34, thick=0.1), bun))
    tails = [tube([(sx * 0.7, 4.72, 0.12), (sx * 0.98, 4.5, 0.12), (sx * 1.04, 4.2, 0.1), (sx * 0.98, 3.98, 0.1)],
                  [0.2, 0.19, 0.16, 0.08], seg=S.seg(6, 4), n=2.0, color=TINT, smooth=sm, tag="hair") for sx in (-1, 1)]
    reg("hair_08", merge(_cap(S, 0.05, 4.76, -0.3, thick=0.1), *tails))
    chin = sphere(0.74, 0.34, 0.64, seg=S.seg(10, 7), rings=S.seg(5, 4), color=TINT, smooth=sm, tag="hair").move(0, 4.22, -0.1)
    must = [sphere(0.22, 0.09, 0.1, seg=S.seg(8, 6), rings=2, color=TINT, smooth=sm, tag="hair").rot(sx * -14, "z").move(sx * 0.17, 4.36, -0.73)
            for sx in (-1, 1)]
    reg("hair_beard", merge(chin, *must))
    band = torus(0.8, 0.17, seg=seg, tseg=S.seg(5, 4), y=4.88, rz=0.77, color=TINT, smooth=sm, tag="hair", phase=ph(S, seg))
    reg("hair_09", band)


# ================================================================== torso (tint kingdom unless noted)

def _at(rings, y):
    """(y, rx, rz) of the profile `rings` (ascending y) at height y, linearly interpolated."""
    for lo, hi in zip(rings[:-1], rings[1:]):
        if lo[0] <= y <= hi[0]:
            t = (y - lo[0]) / (hi[0] - lo[0])
            return (y, lo[1] + (hi[1] - lo[1]) * t, lo[2] + (hi[2] - lo[2]) * t)
    return (y, rings[-1][1], rings[-1][2]) if y > rings[-1][0] else (y, rings[0][1], rings[0][2])


def _clip(rings, y0=HIP_Y):
    """The torso proper: the profile from the hips (y0) up. The Kit runtime wants the base torso piece to start at the hip joint
    (Pose's death fall pivots there); hems below it are separate `skirt_*` pieces."""
    if rings[0][0] >= y0 - 1e-6:
        return list(rings)
    return [_at(rings, y0)] + [r for r in rings if r[0] > y0 + 1e-6]


def _torso(S, rings, bands=(), n=None, color=TINT):
    """Torso shell from (y, rx, rz) rings (clipped at the hips); `bands` are (y0, y1, colour) faces painted by height."""
    seg = S.seg(10, 8)
    m = loft(_clip(rings), seg=seg, n=n or (S.n if S.A else 2.5), caps=(True, True), phase=ph(S, seg), color=color, smooth=S.smooth, tag="cloth")
    for (y0, y1, c) in bands:
        m.paint(c, where=lambda x, y, z, y0=y0, y1=y1: y0 <= y <= y1)
    return m


def _skirt(S, rings, color=TINT, bands=(), grow=0.015, top=HIP_Y + 0.14):
    """The hem below the hips of a long garment: the same profile from its hem up to just inside the torso, a hair wider."""
    seg = S.seg(10, 8)
    low = [r for r in rings if r[0] < top - 1e-6] + [_at(rings, top)]
    low = [(y, rx + grow, rz + grow) for (y, rx, rz) in low]
    m = loft(low, seg=seg, n=S.n if S.A else 2.5, caps=(True, True), phase=ph(S, seg), color=color, smooth=S.smooth, tag="cloth")
    for (y0, y1, c) in bands:
        m.paint(c, where=lambda x, y, z, y0=y0, y1=y1: y0 <= y <= y1)
    return m


def build_torsos(S, R):
    def reg(name, m, tint="cloth", width=2.0, tags=()):
        R.add(name, m, "Torso", "torso", tint, weld=None, tags=tags, info={"width": width})

    def reg_skirt(name, m, tint="cloth", tags=()):
        m.h = [1.0] * len(m.v)
        R.add(name, m, "Torso", "skirt", tint, weld="torso", tags=("skirt",) + tuple(tags))

    BELT = LEATHER_DARK

    # tunic: hip length, belted
    reg("torso_01", _torso(S, [(2.0, 0.98, 0.62), (2.58, 0.8, 0.5), (2.76, 0.8, 0.5), (3.2, 0.92, 0.55), (3.62, 0.98, 0.54),
                               (3.88, 0.51, 0.38)],
                           bands=[(2.55, 2.8, BELT), (3.8, 4.0, DARK)]), width=2.0, tags=("tunic",))
    # work: broad, wide leather belt
    reg("torso_02", _torso(S, [(2.04, 1.04, 0.66), (2.56, 0.88, 0.52), (2.82, 0.9, 0.52), (3.2, 0.99, 0.56), (3.62, 1.06, 0.56),
                               (3.88, 0.54, 0.40)],
                           bands=[(2.5, 2.86, BELT), (3.8, 4.0, DARK)]), width=2.2, tags=("work",))
    # vest: shirt (light) under a darker vest, an open front stripe
    v = _torso(S, [(2.06, 0.98, 0.62), (2.72, 0.8, 0.5), (3.2, 0.92, 0.55), (3.62, 0.98, 0.54), (3.88, 0.51, 0.38)])
    v.paint(DARK)
    v.paint(TINT, where=lambda x, y, z: abs(x) < 0.34 and z < 0 and 2.75 < y < 3.78)
    reg("torso_04", v, tint="cloth", width=2.0, tags=("vest",))
    # jerkin: leather jerkin with a laced front
    j = _torso(S, [(2.0, 0.99, 0.63), (2.68, 0.84, 0.52), (3.2, 0.94, 0.57), (3.62, 1.0, 0.57), (3.88, 0.53, 0.40)],
               bands=[(3.8, 4.0, DARK)])
    j = merge(j, *[box(0.12, 0.05, 0.05, color=LEATHER_DARK, tag="lace").move(0, yy, -0.57) for yy in (3.5, 3.1, 2.75)])
    reg("torso_03", j, width=2.1, tags=("jerkin",))
    # sleeveless: a tank, narrow shoulders (bare arms)
    reg("torso_05", _torso(S, [(2.04, 0.92, 0.58), (2.7, 0.76, 0.48), (3.2, 0.84, 0.52), (3.62, 0.86, 0.5), (3.88, 0.48, 0.36),
                               (3.9, 0.34, 0.3)], bands=[(3.7, 4.0, DARK)]), width=1.8, tags=("sleeveless",))
    # robe: long robe to y 1.5 with a sash (the numbered cut 06; the hem is skirt_06, the other five numbers have no skirt)
    robe_rings = [(1.5, 1.14, 0.8), (2.1, 0.96, 0.66), (2.56, 0.84, 0.54), (2.76, 0.84, 0.54), (3.22, 0.95, 0.57), (3.62, 1.0, 0.56),
                  (3.88, 0.54, 0.40)]
    reg("torso_06", _torso(S, robe_rings, bands=[(2.5, 2.8, DARK), (3.8, 4.0, DARK)]), width=2.1, tags=("robe",))
    reg_skirt("skirt_06", _skirt(S, robe_rings, bands=[(1.5, 1.62, (0.82, 0.82, 0.82))]), tags=("robe",))
    # the merchant's coat: the same cut in his own colour (baked), a gold hem
    merchant_c = (0.46, 0.25, 0.6)
    reg("torso_merchant", _torso(S, robe_rings, color=merchant_c, bands=[(2.5, 2.8, (0.2, 0.12, 0.26)), (3.8, 4.0, (0.86, 0.7, 0.2))]),
         tint="fixed", width=2.1, tags=("merchant",))
    reg_skirt("skirt_merchant", _skirt(S, robe_rings, color=merchant_c, bands=[(1.5, 1.64, (0.86, 0.7, 0.2))]), tint="fixed",
              tags=("merchant",))
    # smock: to the knee-ish, a patch pocket (healer): white linen, baked in the healer's colour
    smock_rings = [(1.82, 1.06, 0.7), (2.4, 0.9, 0.6), (3.0, 0.84, 0.55), (3.4, 0.95, 0.57), (3.64, 1.0, 0.56), (3.88, 0.53, 0.40)]
    sm = _torso(S, smock_rings, bands=[(3.8, 4.0, (0.62, 0.62, 0.6))], color=(0.96, 0.95, 0.91))
    reg("torso_smock", merge(sm, box(0.5, 0.34, 0.1, color=(0.82, 0.82, 0.78), smooth=False, tag="pocket").move(0.38, 2.4, -0.62)),
        tint="fixed", width=2.1, tags=("smock",))
    reg_skirt("skirt_smock", _skirt(S, smock_rings, color=(0.96, 0.95, 0.91)), tint="fixed", tags=("smock",))
    # tabard: soldier, broad shoulders, skirt to 1.84 (skirt_tabard, kingdom cloth)
    tabard_rings = [(1.84, 1.04, 0.66), (2.3, 0.98, 0.6), (2.56, 0.86, 0.54), (2.8, 0.86, 0.54), (3.22, 1.0, 0.58), (3.62, 1.06, 0.58),
                    (3.88, 0.59, 0.41)]
    reg("torso_tabard", _torso(S, tabard_rings, bands=[(2.5, 2.84, BELT), (3.8, 4.0, DARK)]), tint="kingdom", width=2.2,
        tags=("tabard", "soldier"))
    reg_skirt("skirt_tabard", _skirt(S, tabard_rings, bands=[(1.84, 1.96, (0.8, 0.8, 0.8))]), tint="kingdom", tags=("tabard", "soldier"))
    # regal: the ruler's long robe, high collar (its hem is skirt_regal)
    regal_rings = [(1.66, 1.18, 0.82), (2.1, 1.02, 0.7), (2.56, 0.9, 0.58), (2.8, 0.9, 0.58), (3.22, 1.02, 0.6), (3.64, 1.1, 0.6),
                   (3.88, 0.61, 0.43)]
    reg("torso_regal", _torso(S, regal_rings, bands=[(2.5, 2.84, DARK), (3.8, 4.0, (0.7, 0.7, 0.7))]), tint="kingdom", width=2.3,
        tags=("regal", "governor"))
    reg_skirt("skirt_regal", _skirt(S, regal_rings), tint="kingdom", tags=("regal", "governor"))
    # smith: sooty charcoal work shirt, very broad shoulders (baked colour: the smith has no job panel in Character.luau)
    reg("torso_smith", _torso(S, [(2.06, 1.0, 0.64), (2.72, 0.86, 0.52), (3.2, 0.98, 0.58), (3.62, 1.08, 0.58), (3.88, 0.56, 0.41)],
                              bands=[(3.8, 4.0, (0.14, 0.13, 0.13))], color=(0.27, 0.25, 0.26)), tint="fixed", width=2.2, tags=("smith",))


# ================================================================== arms / sleeves / legs / boots

ARM_PROFILE = [  # y, rx, rz, cx, cz (the right arm, unrotated, centred on x = 0): shoulder cap down to the fist
    (3.98, 0.0, 0.0, -0.08, 0.0),
    (3.84, 0.4, 0.38, -0.05, 0.0),
    (3.2, 0.38, 0.38, 0.0, 0.0),
    (2.62, 0.31, 0.34, 0.0, 0.0),
    (2.36, 0.32, 0.38, 0.0, -0.06),
    (2.2, 0.0, 0.0, 0.0, -0.05),
]


def place_arm(m):
    """Splay the right arm 7 degrees about its shoulder joint and move it to the joint's x."""
    return m.rot(ARM_SPLAY, "z", pivot=(0.0, SHOULDER_Y, 0.0)).move(ARM_X, 0, 0)


def arm_point(y):
    """Centre (x, y, z) of the right arm at height y after placement (for tool joints and fits)."""
    t = math.tan(math.radians(ARM_SPLAY))
    return (ARM_X + (SHOULDER_Y - y) * t, y, 0.0)


def build_arms(S, R):
    seg = S.seg(8, 6)
    n = S.n if S.A else 2.5
    ph0 = ph(S, seg)
    arm = loft(ARM_PROFILE, seg=seg, n=n, caps=(False, False), phase=ph0, color=TINT, smooth=S.smooth, tag="skin")
    R.add_sided("arm_bare", place_arm(arm), "arm", "skin", None, tags=("arm",))
    # a hand only (for long sleeves): the fist and wrist
    hand = loft([(2.78, 0.0, 0.0, 0.0, 0.0), (2.6, 0.3, 0.33, 0.0, 0.0), (2.36, 0.32, 0.38, 0.0, -0.06), (2.2, 0.0, 0.0, 0.0, -0.05)],
                seg=seg, n=n, caps=(False, False), phase=ph0, color=TINT, smooth=S.smooth, tag="skin")
    R.add_sided("arm_hand", place_arm(hand), "arm", "skin", None, tags=("hand",))

    def sleeve(prof, name, dark_y=None, tags=(), tint="cloth", band=DARK, base=TINT):
        m = loft(prof, seg=seg, n=n, caps=(True, True), phase=ph0, color=base, smooth=S.smooth, tag="cloth")
        if dark_y is not None:
            m.paint(band, where=lambda x, y, z: y < dark_y)
        R.add_sided(name, place_arm(m), "sleeve", tint, "arm", tags=tags)

    g = 0.055
    sleeve([(3.99, 0.1, 0.1, -0.08, 0.0), (3.84, 0.4 + g, 0.38 + g, -0.05, 0.0), (3.3, 0.38 + g, 0.38 + g, 0.0, 0.0)], "sleeve_short",
           dark_y=3.5, tags=("short",))
    sleeve([(3.99, 0.1, 0.1, -0.08, 0.0), (3.84, 0.4 + g, 0.38 + g, -0.05, 0.0), (3.1, 0.37 + g, 0.37 + g, 0.0, 0.0),
            (2.6, 0.31 + g, 0.34 + g, 0.0, 0.0)], "sleeve_long", dark_y=2.78, tags=("long",))
    sleeve([(3.99, 0.1, 0.1, -0.08, 0.0), (3.84, 0.44, 0.42, -0.05, 0.0), (3.1, 0.46, 0.46, 0.0, 0.0), (2.5, 0.52, 0.5, 0.0, 0.0)],
           "sleeve_robe", dark_y=2.75, tags=("robe",), tint="kingdom", band=(0.97, 0.97, 0.97))
    # soldier: the sleeve is kingdom cloth with a lighter shoulder cap (the colour reads from above); steel gauntlets are the arm piece
    sleeve([(3.99, 0.1, 0.1, -0.08, 0.0), (3.9, 0.5, 0.46, -0.05, 0.0), (3.62, 0.5, 0.46, 0.0, 0.0), (3.1, 0.4 + g, 0.4 + g, 0.0, 0.0),
            (2.9, 0.34 + g, 0.36 + g, 0.0, 0.0)], "sleeve_soldier", dark_y=3.0, tags=("soldier",), tint="kingdom", band=(0.55, 0.55, 0.55))
    gaunt = loft([(2.95, 0.0, 0.0, 0.0, 0.0), (2.9, 0.33, 0.36, 0.0, 0.0), (2.6, 0.31, 0.34, 0.0, 0.0), (2.36, 0.32, 0.38, 0.0, -0.06),
                  (2.2, 0.0, 0.0, 0.0, -0.05)], seg=seg, n=n, caps=(False, False), phase=ph0, color=STEEL, smooth=S.smooth, tag="mail")
    gaunt.paint(STEEL_DARK, where=lambda x, y, z: y > 2.8)
    R.add_sided("arm_gauntlet", place_arm(gaunt), "arm", "fixed", None, tags=("soldier",))


LEG_PROFILE = [  # y, rx, rz  (the right leg, centred on x = 0): hip -> ankle
    (2.24, 0.0, 0.0),  # the leg top sits at the hip joint (the Kit specs want the hip within 0.06 of the leg top)
    (2.2, 0.45, 0.47),
    (1.5, 0.43, 0.46),
    (0.45, 0.38, 0.41),
]


def build_legs(S, R):
    seg = S.seg(8, 6)
    n = S.n if S.A else 2.5
    ph0 = ph(S, seg)

    def leg(prof, name, color, tint, tags, paint=None):
        m = loft(prof, seg=seg, n=n, caps=(False, True), phase=ph0, color=color, smooth=S.smooth, tag="cloth")
        if paint:
            m.paint(paint[0], where=paint[1])
        R.add_sided(name, m.move(LEG_X, 0, 0), "leg", tint, None, tags=tags)

    leg(LEG_PROFILE, "leg_trousers", TINT, "cloth", ("trousers",), (DARK, lambda x, y, z: y < 0.7))
    leg([(2.24, 0.0, 0.0), (2.2, 0.48, 0.5), (1.5, 0.5, 0.53), (1.4, 0.4, 0.42), (0.45, 0.34, 0.37)], "leg_breeches", TINT, "cloth",
        ("breeches",), (mix(TINT, (0.86, 0.86, 0.9), 1.0), lambda x, y, z: y < 1.4))
    leg(LEG_PROFILE, "leg_mail", STEEL_DARK, "fixed", ("mail", "soldier"), (mix(STEEL_DARK, STEEL, 0.4), lambda x, y, z: 1.2 < y < 1.9))


def _boot(S, rings, color, sole=None):
    seg = S.seg(8, 6)
    n = S.n if S.A else 2.5
    m = loft(rings, seg=seg, n=n, caps=(True, True), phase=ph(S, seg), color=color, smooth=S.smooth, tag="boot")
    if sole is not None:
        m.paint(sole, where=lambda x, y, z: y < rings[1][0] * 0.9)
    return m


def build_boots(S, R):
    soleC = rgb(52, 36, 28)

    def reg(name, m, tags):
        R.add_sided(name, m.move(LEG_X, 0, 0), "boot", "fixed", "leg", tags=tags)

    reg("boot_01", _boot(S, [(0.0, 0.36, 0.56, 0, -0.12), (0.14, 0.45, 0.66, 0, -0.14), (0.7, 0.42, 0.47, 0, 0.0)], LEATHER, soleC), ("low",))
    reg("boot_03", _boot(S, [(0.0, 0.36, 0.56, 0, -0.12), (0.14, 0.46, 0.68, 0, -0.14), (0.7, 0.43, 0.49, 0, 0.0), (1.3, 0.49, 0.52, 0, 0.0)],
                           LEATHER, soleC), ("high",))
    reg("boot_02", _boot(S, [(0.0, 0.38, 0.58, 0, -0.12), (0.18, 0.48, 0.7, 0, -0.14), (0.84, 0.45, 0.5, 0, 0.0)], rgb(96, 64, 40), soleC),
        ("work",))
    reg("boot_plate", _boot(S, [(0.0, 0.36, 0.58, 0, -0.14), (0.14, 0.45, 0.7, 0, -0.18), (0.92, 0.44, 0.49, 0, 0.0)], STEEL_DARK,
                            rgb(40, 40, 46)), ("plate", "soldier"))


def build_body(S, R):
    for k, p in FACES.items():
        R.add(k, build_head(S, p), "Head", "head", "skin", weld=None, tags=("face",))
    build_hair(S, R)
    build_torsos(S, R)
    build_arms(S, R)
    build_legs(S, R)
    build_boots(S, R)
