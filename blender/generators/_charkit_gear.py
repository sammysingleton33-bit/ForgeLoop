"""Character kit: hats, hair accessories, held tools, armour, regalia and body extras (FL-0135).

Tools are authored in a local frame (grip point = origin, +y along the handle, forward = -z) and placed at the right
fist by `held()`. Everything here is registered in rig axes at the rest pose.
"""

import math

from lib.ckit import M, box, cone, cyl, hull, loft, merge, prism, sphere, tube

from . import _charkit_style as K
from ._charkit_body import HEAD_RINGS, arm_point, head_radius_at
from ._charkit_style import (ASH, BLADE, BURLAP, CANVAS, ERMINE, ERMINE_SPOT, GOLD, GOLD_DARK, HEAD_Y, INK, IRON, LAMP,
                             LEATHER, LEATHER_DARK, LINEN, SHOULDER_Y, STEEL, STEEL_DARK, STRAW, STRAW_DARK, TINT, WOOD,
                             WOOD_DARK, WOOD_LIGHT, WOOD_PALE, mix, ph, rgb)

HAND = arm_point(2.45)  # (x, y, z) of the right fist centre (the Tool joint sits here)
GRIP_Z = -0.48  # handle axis, in front of the fist so a held shaft clears the arm
RED_GEM = rgb(176, 36, 52)


def held(m, lean=0.0):
    """Place a tool built in the grip frame (origin = grip point on the handle axis, +y up, forward -z)."""
    m.rot(-lean, "z")
    return m.move(HAND[0], HAND[1], HAND[2] + GRIP_Z)


def _seg(S, a, b=None):
    return S.seg(a, b)


def panel(rx_of, rz_of, y0, y1, x0, x1, thick, front=True, nx=6, ny=2, off=0.03, flare=0.0, color=TINT, smooth=True, tag="",
          flare_pow=2.0):
    """Closed curved slab hugging a torso-like ellipse: x in [x0, x1], y in [y0, y1], `thick` thick, `off` clear of the
    body (flare widens it towards y0)."""
    sgn = -1.0 if front else 1.0
    verts, idx_o, idx_i = [], [], []

    def zat(x, y, d):
        rx, rz = rx_of(y), rz_of(y)
        t = (y1 - y) / max(1e-6, (y1 - y0))
        f = flare * (t ** flare_pow)
        u = max(-0.999, min(0.999, x / (rx + 1e-9)))
        return sgn * (rz * math.sqrt(1 - u * u) + d + f)

    for j in range(ny + 1):
        y = y1 - (y1 - y0) * j / ny
        ro, ri = [], []
        for i in range(nx + 1):
            x = x0 + (x1 - x0) * i / nx
            verts.append((x, y, zat(x, y, off + thick)))
            ro.append(len(verts) - 1)
            verts.append((x, y, zat(x, y, off)))
            ri.append(len(verts) - 1)
        idx_o.append(ro)
        idx_i.append(ri)
    faces = []
    for j in range(ny):
        for i in range(nx):
            faces.append((idx_o[j][i], idx_o[j][i + 1], idx_o[j + 1][i + 1], idx_o[j + 1][i]))
            faces.append((idx_i[j][i], idx_i[j + 1][i], idx_i[j + 1][i + 1], idx_i[j][i + 1]))
    for j in range(ny):  # left / right edges
        faces.append((idx_o[j][0], idx_o[j + 1][0], idx_i[j + 1][0], idx_i[j][0]))
        faces.append((idx_o[j][nx], idx_i[j][nx], idx_i[j + 1][nx], idx_o[j + 1][nx]))
    for i in range(nx):  # top / bottom edges
        faces.append((idx_o[0][i], idx_i[0][i], idx_i[0][i + 1], idx_o[0][i + 1]))
        faces.append((idx_o[ny][i], idx_o[ny][i + 1], idx_i[ny][i + 1], idx_i[ny][i]))
    m = M(verts, faces, color=color, smooth=smooth, tag=tag)
    return m.fix_winding()


def torso_r(y, w=1.0):
    """Representative torso half extents (rx, rz) at height y (for panels and straps)."""
    pts = [(1.4, 1.0, 0.7), (2.1, 0.96, 0.62), (2.7, 0.82, 0.54), (3.22, 0.95, 0.57), (3.62, 1.0, 0.56), (3.84, 0.64, 0.45),
           (3.93, 0.36, 0.32)]
    if y <= pts[0][0]:
        return pts[0][1] * w, pts[0][2]
    for a, b in zip(pts[:-1], pts[1:]):
        if a[0] <= y <= b[0]:
            t = (y - a[0]) / (b[0] - a[0])
            return (a[1] + (b[1] - a[1]) * t) * w, a[2] + (b[2] - a[2]) * t
    return pts[-1][1] * w, pts[-1][2]


def hat(R, name, m, slot="hat", tint="fixed", tags=()):
    m.h = [1.0] * len(m.v)
    R.add(name, m, "Head", slot, tint, weld="head", tags=("hat",) + tuple(tags))


# ================================================================== hats / headwear

def build_hats(S, R):
    seg = S.seg(10, 8)
    n = S.n if S.A else 2.5
    p0 = ph(S, seg)
    sm = S.smooth
    GREY = (0.66, 0.66, 0.66)

    # ---- straw hat: a wide flat brim, a domed crown with a dark band (farmer)
    brim = loft([(4.98, 1.58, 1.58), (5.1, 1.58, 1.58)], seg=S.seg(12, 8), n=2.0, caps=(True, True), phase=ph(S, S.seg(12, 8)),
                color=STRAW, smooth=sm, tag="straw")
    crown = loft([(5.08, 0.92, 0.9), (5.34, 0.88, 0.86), (5.66, 0.62, 0.6), (5.82, 0.0, 0.0)], seg=seg, n=n, caps=(True, False), phase=p0,
                 color=STRAW, smooth=sm, tag="straw")
    crown.paint(WOOD_DARK, where=lambda x, y, z: 5.1 < y < 5.4)
    hat(R, "hat_straw", merge(brim, crown), tags=("farmer",))
    # the kingdom ribbon round the crown (tinted): visible from above between the brim and the dome
    rib = loft([(5.12, 0.95, 0.93), (5.4, 0.91, 0.89)], seg=seg, n=n, caps=(True, True), phase=p0, color=TINT, smooth=sm, tag="cloth")
    hat(R, "hat_ribbon", rib, slot="hatband", tint="kingdom", tags=("farmer",))

    # ---- knit beanie with a folded cuff (woodcutter); the pompom is a separate kingdom piece
    dome = loft([(4.9, 0.9, 0.86), (5.06, 0.92, 0.88), (5.32, 0.84, 0.81), (5.62, 0.62, 0.6), (5.78, 0.0, 0.0)], seg=seg, n=n,
                caps=(True, False), phase=p0, color=TINT, smooth=sm, tag="cloth")
    dome.paint(GREY, where=lambda x, y, z: y < 5.1)
    hat(R, "hat_beanie", dome, tint="cloth", tags=("woodcutter",))
    pom = sphere(0.3, 0.3, 0.3, seg=S.seg(7, 5), rings=S.seg(4, 3), color=TINT, smooth=sm, tag="cloth").move(0, 5.84, 0.0)
    hat(R, "hat_pompom", pom, slot="hatband", tint="kingdom", tags=("woodcutter",))

    # ---- miner's pot helmet: ochre iron dome, wide rim, a lamp on the front
    ochre = rgb(168, 104, 34)
    pot = loft([(4.99, 1.08, 1.06), (5.1, 1.04, 1.02), (5.4, 0.9, 0.88), (5.72, 0.68, 0.66), (5.86, 0.0, 0.0)], seg=seg,
               n=n, caps=(True, False), phase=p0, color=ochre, smooth=sm, tag="iron")
    pot.paint(mix(ochre, (0.55, 0.35, 0.15), 0.4), where=lambda x, y, z: y < 5.1)
    lamp = merge(box(0.5, 0.4, 0.3, color=IRON, smooth=False, tag="lamp").move(0, 5.4, -0.94),
                 box(0.28, 0.24, 0.1, color=LAMP, smooth=False, tag="lamp").move(0, 5.4, -1.12))
    hat(R, "hat_miner", merge(pot, lamp), tags=("miner",))

    # ---- builder's cap: a hard hat with a peak
    hh = loft([(4.98, 0.92, 0.9), (5.3, 0.92, 0.9), (5.62, 0.72, 0.7), (5.8, 0.0, 0.0)], seg=seg, n=n, caps=(True, False), phase=p0,
              color=TINT, smooth=sm, tag="cloth")
    peak = box(1.3, 0.12, 0.6, color=TINT, smooth=False, tag="cloth").move(0, 5.04, -1.14)
    hat(R, "hat_builder", merge(hh, peak), tint="cloth", tags=("builder",))

    # ---- hood: kingdom cowl closed over the head, the face opening in front
    hat(R, "hat_hood", _hood(S, 0.11, 4.2, -0.26, back=False), tint="kingdom", tags=("hood",))

    # ---- merchant's floppy beret with a feather
    beret = sphere(1.05, 0.5, 0.98, seg=S.seg(9, 8), rings=S.seg(4, 3), color=TINT, smooth=sm, tag="cloth", phase=p0)
    beret = beret.rot(-8, "z").move(0.12, 5.3, 0.0)
    brimb = loft([(4.95, 0.93, 0.9), (5.12, 0.95, 0.92)], seg=seg, n=n, caps=(True, True), phase=p0, color=mix(TINT, GREY, 0.7),
                 smooth=sm, tag="cloth")
    feather = loft([(0.0, 0.0, 0.0), (0.3, 0.07, 0.04), (1.0, 0.16, 0.04), (1.6, 0.05, 0.02), (1.7, 0.0, 0.0)], seg=4, n=1.6,
                   caps=(False, False), color=rgb(238, 232, 214), smooth=False, tag="feather")
    feather = feather.rot(-70, "z").rot(-14, "x").move(0.92, 5.34, -0.22)
    hat(R, "hat_merchant", merge(beret, brimb), tint="cloth", tags=("merchant",))
    hat(R, "hat_feather", feather, slot="hatband", tint="fixed", tags=("merchant",))

    # ---- healer coif: a linen headscarf wrapped over the head, knotted at the back
    coif = _hood(S, 0.07, 4.35, -0.2, back=False)
    knot = sphere(0.26, 0.2, 0.2, seg=S.seg(6, 5), rings=2, color=TINT, smooth=sm, tag="cloth").move(0, 4.9, 0.9)
    tail = tube([(0, 4.82, 0.85), (0, 4.4, 1.05), (0, 3.95, 1.0)], [0.2, 0.16, 0.08], seg=S.seg(4, 3), color=TINT, smooth=sm, tag="cloth")
    hat(R, "hat_coif", merge(coif, knot, tail), tint="cloth", tags=("healer",))
    # headband (idle accessory): a band with a knot and two tails
    hb = loft([(4.9, 0.84, 0.8), (5.02, 0.85, 0.81)], seg=seg, n=n, caps=(True, True), phase=p0, color=TINT, smooth=sm, tag="cloth")
    hbk = sphere(0.17, 0.14, 0.12, seg=S.seg(6, 4), rings=2, color=TINT, smooth=sm, tag="cloth").move(0.0, 4.96, 0.82)
    hbt = [box(0.1, 0.5, 0.05, color=TINT, smooth=False, tag="cloth").rot(sx * 14, "z").move(sx * 0.1, 4.62, 0.92) for sx in (-1, 1)]
    hat(R, "hat_headband", merge(hb, hbk, *hbt), tint="cloth", tags=("idle",))


def _hood(S, thick, rim_y, tilt_z, tip=0.0, flare=0.0, back=True):
    """Cowl over the head: a shell with the rim tilted (high at the forehead, low at the nape) and a drape at the back."""
    seg = S.seg(10, 8)
    n = S.n if S.A else 2.5
    rings = []
    ys = (5.3, 5.0, 4.7)
    for y in ys:
        rx, rz, cz = head_radius_at(y)
        rings.append((y, rx + thick, rz + thick, 0.0, cz))
    rings.append((rim_y, head_radius_at(rim_y)[0] + thick + flare, head_radius_at(rim_y)[1] + thick + flare, 0.0, 0.0))
    rings = [(5.42 + thick + tip, 0.0, 0.0)] + rings
    rings = list(reversed(rings))
    m = loft(rings, seg=seg, n=n, caps=(True, False), phase=ph(S, seg), color=TINT, smooth=S.smooth, tag="cloth")
    m.v = [(x, y + tilt_z * z, z) if i < seg else (x, y, z) for i, (x, y, z) in enumerate(m.v)]
    if back:  # a fold of cloth round the neck / shoulders
        neck = loft([(3.9, 0.7, 0.62), (4.12, 0.9, 0.82), (4.34, 0.88, 0.8)], seg=seg, n=n, caps=(True, True), phase=ph(S, seg),
                    color=TINT, smooth=S.smooth, tag="cloth")
        m = merge(m, neck)
    return m


# ================================================================== held tools (joint Tool, slot tool)

def _shaft(S, y0, y1, r, color, r1=None, tag="wood", seg=None):
    seg = seg or S.seg(7, 6)
    r1 = r if r1 is None else r1
    return loft([(y0, r), (y1, r1)], seg=seg, n=2.0, caps=(True, True), phase=0.0, color=color, smooth=S.smooth, tag=tag)


def _side_prism(poly_fy, hw, color, tag="metal"):
    """Extrude a polygon given in (forward, up) coordinates by +-hw across x."""
    return prism(poly_fy, -hw, hw, color=color, smooth=False, tag=tag).rot(90, "y")


def tool(R, name, m, slot="tool", tint="fixed", joint="Tool", weld=None, tags=()):
    m.h = [1.0] * len(m.v)
    R.add(name, m, joint, slot, tint, weld=weld, tags=("tool",) + tuple(tags))


def build_tools(S, R):
    sm = S.smooth
    sg = S.seg(8, 6)

    # ---- hoe: long pale shaft, steel socket, a flat blade angled down at the top
    shaft = _shaft(S, -1.75, 3.55, 0.15, WOOD_LIGHT, 0.13)
    sock = _shaft(S, 3.05, 3.6, 0.2, STEEL_DARK, tag="metal")
    neck = box(0.22, 0.2, 0.7, color=STEEL_DARK, smooth=False, tag="metal").move(0, 3.4, -0.4)
    blade = _side_prism([(0.2, 3.5), (0.85, 3.42), (1.25, 2.65), (1.3, 2.28), (0.7, 2.5), (0.2, 3.0)], 0.42, BLADE)
    tool(R, "tool_hoe", held(merge(shaft, sock, neck, blade), lean=12), tags=("farmer",))

    # ---- axe: haft + a heavy bearded head
    haft = _shaft(S, -1.1, 3.1, 0.17, WOOD, 0.15)
    back = hull([(sx * 0.17, y, f) for sx in (-1, 1) for (f, y) in ((0.2, 2.05), (0.2, 3.35), (-0.3, 2.45), (-0.3, 2.95))],
                color=STEEL_DARK, smooth=False, tag="metal")
    back = _swap_fy(back)
    wedge = _swap_fy(hull([(sx * 0.17, y, f) for sx in (-1, 1) for (f, y) in ((0.15, 1.95), (0.15, 3.45))]
                          + [(0.0, y, f) for (f, y) in ((1.35, 1.45), (1.35, 3.8))], color=BLADE, smooth=False, tag="metal"))
    tool(R, "tool_axe", held(merge(haft, back, wedge), lean=8), tags=("woodcutter",))

    # ---- pickaxe: dark haft, a curved double-sided iron head (a clear T seen from the front and side)
    haft2 = _shaft(S, -1.2, 3.3, 0.17, WOOD_DARK, 0.15)
    pts, rad = [], []
    for i in range(5):
        t = -1.0 + i / 2.0
        pts.append((t * 1.8, 3.42 + 0.34 * (1 - t * t) - 0.42 * t * t * 0 - 0.2 * abs(t) ** 1.6, 0.0))
        rad.append(0.03 + 0.17 * (1 - abs(t) ** 1.4))
    head = tube(pts, rad, seg=S.seg(5, 4), n=2.0, color=STEEL_DARK, smooth=sm, tag="metal")
    boss = box(0.42, 0.46, 0.42, color=IRON, smooth=False, tag="metal").move(0, 3.44, 0)
    pick = merge(head, boss).rot(40, "y", pivot=(0, 0, 0))
    tool(R, "tool_pick", held(merge(haft2, pick), lean=6), tags=("miner",))

    # ---- mallet: builder's wooden maul with iron bands
    h3 = _shaft(S, -0.9, 2.2, 0.16, WOOD_PALE)
    mh = box(1.75, 1.0, 1.0, color=WOOD, smooth=False, tag="wood").move(0, 2.45, 0)
    bands = [box(0.16, 1.06, 1.06, color=IRON, smooth=False, tag="metal").move(sx * 0.62, 2.45, 0) for sx in (-1, 1)]
    mall = merge(h3, mh, *bands).rot(35, "y")
    tool(R, "tool_mallet", held(mall, lean=10), tags=("builder",))

    # ---- smith hammer: short thick handle, a big steel head with a peen
    h4 = _shaft(S, -0.9, 2.0, 0.19, WOOD_DARK, 0.17)
    head4 = merge(box(0.9, 0.85, 0.85, color=STEEL, smooth=False, tag="metal").move(0, 2.35, 0),
                  hull([(0.45, 2.78, -0.42), (0.45, 1.92, -0.42), (0.45, 2.78, 0.42), (0.45, 1.92, 0.42), (1.2, 2.5, -0.1),
                        (1.2, 2.2, -0.1), (1.2, 2.5, 0.1), (1.2, 2.2, 0.1)], color=STEEL_DARK, smooth=False, tag="metal"))
    tool(R, "tool_hammer", held(merge(h4, head4.rot(30, "y")), lean=10), tags=("blacksmith",))

    # ---- merchant's hand scale: a short stave, a beam and two pans
    st = _shaft(S, -1.0, 2.6, 0.1, WOOD_DARK)
    beam = box(2.6, 0.13, 0.13, color=GOLD, smooth=False, tag="metal").move(0, 2.7, 0)
    fin = cone(0.15, 0.3, seg=4, y0=2.6, color=GOLD, smooth=False, tag="metal")
    pans = []
    for sx in (-1, 1):
        cx = sx * 1.22
        pans.append(cyl(0.55, 0.3, 0.14, seg=S.seg(8, 6), y0=1.3, color=GOLD_DARK, smooth=sm, tag="metal").move(cx, 0, 0))
        pans.append(box(0.05, 1.3, 0.05, color=IRON, smooth=False, tag="metal").move(cx, 2.0, 0))
    scale = merge(st, beam, fin, *pans)
    tool(R, "tool_scale", held(scale, lean=6), tags=("merchant",))

    # ---- healer's staff: wooden stave, a crook at the top with a herb bundle
    st2 = _shaft(S, -1.8, 3.9, 0.15, WOOD_LIGHT, 0.13)
    crook = tube([(0, 3.85, 0), (0, 4.4, -0.2), (0, 4.4, -0.7), (0, 4.0, -0.9)], [0.14, 0.12, 0.11, 0.09],
                 seg=S.seg(5, 4), color=WOOD_LIGHT, smooth=sm, tag="wood")
    leaf_c = rgb(86, 150, 62)
    leaves = [_leaf(0.3, 0.75, leaf_c).rot(a, "z").move(0, 3.75, -0.9) for a in (-30, 30)]
    tool(R, "tool_staff_healer", held(merge(st2, crook, *leaves), lean=5), tags=("healer",))

    # ---- spear: long ash shaft, steel leaf head, socket
    sp = _shaft(S, -2.3, 6.9, 0.15, ASH, 0.13)
    sock2 = _shaft(S, 6.55, 7.15, 0.21, STEEL_DARK, tag="metal")
    sp_head = loft([(7.1, 0.12, 0.12), (7.3, 0.3, 0.1), (7.75, 0.34, 0.08), (8.4, 0.14, 0.05), (8.9, 0.0, 0.0)], seg=4, n=1.0,
                   caps=(True, False), phase=0.0, color=BLADE, smooth=False, tag="metal")
    tool(R, "tool_spear", held(merge(sp, sock2, sp_head), lean=2), tags=("soldier",))
    # pennant: a kingdom flag streaming from the shaft (welded to the tool), swallow-tailed, facing front/back
    flag = prism([(0.12, 4.5), (1.7, 4.62), (1.25, 4.98), (1.7, 5.34), (0.12, 5.46)], -0.05, 0.05, color=TINT, smooth=False, tag="cloth")
    tool(R, "tool_pennant", held(flag, lean=2), slot="toolband", tint="kingdom", joint="Tool", weld="tool", tags=("soldier",))

    # ---- sword (with a shield on the left arm)
    bl = loft([(0.28, 0.0, 0.0), (0.3, 0.16, 0.05), (2.7, 0.14, 0.04), (3.3, 0.0, 0.0)], seg=4, n=1.2, caps=(True, False), phase=0.0,
              color=BLADE, smooth=False, tag="metal")
    grd = box(1.0, 0.13, 0.2, color=GOLD_DARK, smooth=False, tag="metal").move(0, 0.2, 0)
    grip = _shaft(S, -0.62, 0.15, 0.1, LEATHER_DARK, seg=6)
    pom = sphere(0.15, seg=5, rings=2, color=GOLD_DARK, smooth=False, tag="metal").move(0, -0.7, 0)
    tool(R, "tool_sword", held(merge(bl, grd, grip, pom), lean=14), tags=("soldier",))

    # ---- bow: a curved limb pair, a string; belly away from the archer
    pts2 = []
    rad2 = []
    for i in range(7):
        t = -1.0 + i / 3.0
        pts2.append((0.0, t * 1.9, 0.5 * t * t))
        rad2.append(0.07 + 0.08 * (1 - abs(t)) ** 0.7)
    bow = tube(pts2, rad2, seg=S.seg(5, 4), n=2.0, color=WOOD, smooth=sm, tag="wood")
    wrap = _shaft(S, -0.28, 0.28, 0.2, LEATHER_DARK, seg=6)
    string = box(0.035, 3.8, 0.035, color=rgb(226, 220, 200), smooth=False, tag="string").move(0, 0, 0.5)
    tool(R, "tool_bow", held(merge(bow, wrap, string), lean=0), tags=("archer", "soldier"))

    # ---- ruler's staff: gold stave, a ringed orb with prongs
    gs = _shaft(S, -1.5, 4.9, 0.18, GOLD, 0.17, tag="metal", seg=S.seg(7, 6))
    ring = cyl(0.3, 0.3, 0.16, seg=S.seg(8, 6), y0=4.7, color=GOLD_DARK, smooth=sm, tag="metal")
    orb = sphere(0.5, seg=S.seg(8, 6), rings=S.seg(4, 3), color=GOLD, smooth=sm, tag="metal").move(0, 5.5, 0)
    prongs = [cone(0.11, 0.55, seg=4, color=GOLD, smooth=False, tag="metal").rot(a, "z").move(0, 5.7, 0) for a in (-52, 0, 52)]
    gem = sphere(0.2, seg=5, rings=2, color=RED_GEM, smooth=False, tag="gem").move(0, 5.55, -0.45)
    tool(R, "tool_staff_ruler", held(merge(gs, ring, orb, gem, *prongs), lean=3), tags=("governor",))

    # ---- hauler's sack (Torso joint "TorsoTool"): lumpy burlap ball tied at the neck; strap on the chest
    body = sphere(1.05, 1.28, 1.12, seg=S.seg(8, 7), rings=S.seg(5, 4), color=BURLAP, smooth=sm, tag="sack")
    body = body.map(lambda p: (p[0] + 0.05 * math.sin(p[1] * 3), p[1], p[2] + 0.06 * math.sin(p[0] * 4 + p[1]))).move(0.1, 3.0, 1.95)
    neck = loft([(3.9, 0.55, 0.5), (4.25, 0.3, 0.28), (4.75, 0.5, 0.46)], seg=S.seg(8, 6), n=2.0, caps=(True, True),
                color=BURLAP, smooth=sm, tag="sack").move(0.1, 0, 1.95)
    tie = _shaft(S, 4.18, 4.34, 0.36, LEATHER_DARK, seg=6, tag="tie").move(0.1, 0, 1.95)
    sack = merge(body, neck, tie)
    sack.h = [1.0] * len(sack.v)
    R.add("tool_sack", sack, "TorsoTool", "tool", "fixed", weld=None, tags=("tool", "hauler"))
    path = [(0.64, 3.95, 0.12), (0.7, 3.78, -0.3), (0.42, 3.34, -0.55), (-0.12, 2.9, -0.58), (-0.62, 2.5, -0.5), (-0.78, 2.32, -0.25)]
    strap = tube(path, [0.12] * 6, seg=S.seg(4, 4), n=2.0, color=TINT, smooth=sm, tag="cloth", rz_scale=0.55)
    strap.h = [1.0] * len(strap.v)
    R.add("strap_kingdom", strap, "Torso", "extra", "kingdom", weld="torso", tags=("hauler",))


def _swap_fy(m):
    """hull() points were given as (x, y, f); rotate so f (forward) maps to -z (the grip frame's forward)."""
    return m.map(lambda p: (p[0], p[1], -p[2]))


def _leaf(w, l, color):
    """A flat pointed leaf lying in the xy plane, 0.05 thick, base at the origin, pointing +y."""
    poly = [(0.0, 0.0), (w * 0.8, l * 0.35), (w * 0.4, l * 0.8), (0.0, l), (-w * 0.4, l * 0.8), (-w * 0.8, l * 0.35)]
    return prism(poly, -0.03, 0.03, color=color, smooth=False, tag="leaf")


# ================================================================== armour, regalia, extras

def build_armour(S, R):
    sm = S.smooth
    seg = S.seg(10, 8)
    n = S.n if S.A else 2.5
    p0 = ph(S, seg)
    # kettle helm: wide brim, dome, a nasal bar; the face stays visible
    brim = loft([(4.99, 1.22, 1.2), (5.1, 1.2, 1.18)], seg=seg, n=2.0, caps=(True, True), phase=p0, color=STEEL, smooth=sm, tag="metal")
    dome = loft([(5.06, 0.93, 0.91), (5.4, 0.92, 0.9), (5.72, 0.74, 0.72), (5.96, 0.0, 0.0)], seg=seg, n=n, caps=(True, False), phase=p0,
                color=STEEL, smooth=sm, tag="metal")
    dome.paint(mix(STEEL, STEEL_DARK, 0.5), where=lambda x, y, z: y < 5.12)
    nasal = box(0.13, 0.52, 0.07, color=STEEL_DARK, smooth=False, tag="metal").move(0, 4.8, -0.88)
    hat(R, "hat_helm", merge(brim, dome, nasal), tags=("soldier",))

    # kingdom crests on the helm top (D-057 emblems via Parts.hueStyle: crimson crown, azure star, emerald oak leaf, gold sun):
    # a chunky upright emblem plate standing on the helm (tint kingdom), readable from the front and the side
    top = 5.94
    th = 0.2

    def crest(name, poly, rise=0.0):
        m = prism(poly, -th, th, color=TINT, smooth=False, tag="cloth").move(0, top - 0.05 + rise, 0)
        m = merge(m, cyl(0.26, 0.3, 0.14, seg=S.seg(6, 4), y0=top - 0.1, color=mix(TINT, (0.7, 0.7, 0.7), 1.0), smooth=False, tag="cloth"))
        hat(R, name, m, slot="crest", tint="kingdom", tags=("soldier",))

    crest("crest_crimson", [(-0.72, 0.0), (0.72, 0.0), (0.72, 0.6), (0.52, 0.5), (0.74, 1.35), (0.34, 0.95), (0.0, 1.5), (-0.34, 0.95),
                            (-0.74, 1.35), (-0.52, 0.5), (-0.72, 0.6)])
    star = []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5
        r = 0.9 if i % 2 == 0 else 0.4
        star.append((math.cos(a) * r, 0.78 + math.sin(a) * r))
    crest("crest_azure", [(-p[0], p[1]) for p in reversed(star)])
    leaf = [(0.0, 0.0), (0.18, 0.2), (0.5, 0.18), (0.38, 0.5), (0.7, 0.6), (0.44, 0.85), (0.6, 1.1), (0.26, 1.2), (0.0, 1.62),
            (-0.26, 1.2), (-0.6, 1.1), (-0.44, 0.85), (-0.7, 0.6), (-0.38, 0.5), (-0.5, 0.18), (-0.18, 0.2)]
    crest("crest_emerald", leaf)
    sun = []
    for i in range(16):
        a = math.pi / 2 + i * math.pi / 8
        r = 0.88 if i % 2 == 0 else 0.55
        sun.append((math.cos(a) * r, 0.9 + math.sin(a) * r))
    crest("crest_gold", [(-p[0], p[1]) for p in reversed(sun)])


def build_regalia(S, R):
    sm = S.smooth
    seg = S.seg(10, 8)
    n = S.n if S.A else 2.5
    p0 = ph(S, seg)
    # crown: gold band + five points with a red jewel on the front point
    band = loft([(5.0, 0.9, 0.88), (5.34, 0.9, 0.88)], seg=S.seg(8, 8), n=n, caps=(True, True), phase=ph(S, S.seg(8, 8)), color=GOLD, smooth=sm, tag="metal")
    band.paint(GOLD_DARK, where=lambda x, y, z: y < 5.1)
    pts = []
    for i in range(5):
        a = math.tau * i / 5
        c = cone(0.17, 0.5, seg=3, y0=5.3, color=GOLD, smooth=False, tag="metal").move(math.sin(a) * 0.82, 0, math.cos(a) * -0.8)
        pts.append(c)
    gem = sphere(0.14, 0.14, 0.1, seg=S.seg(5, 4), rings=2, color=RED_GEM, smooth=False, tag="gem").move(0, 5.17, -0.9)
    hat(R, "hat_crown", merge(band, gem, *pts), tags=("governor",))
    cap = loft([(5.2, 0.86, 0.84), (5.5, 0.82, 0.8), (5.78, 0.52, 0.5), (5.9, 0.0, 0.0)], seg=seg, n=n, caps=(True, False), phase=p0,
               color=TINT, smooth=sm, tag="cloth")
    hat(R, "crown_cap", cap, slot="hatband", tint="kingdom", tags=("governor",))
    # cape: a back panel hanging from the shoulders to just above the hips (clears every leg swing); kingdom
    rx_of = lambda y: torso_r(y)[0] + 0.14
    rz_of = lambda y: torso_r(y)[1]
    cape = panel(rx_of, rz_of, 2.4, 3.85, -0.88, 0.88, 0.1, front=False, nx=S.seg(4, 3), ny=2, off=0.1, flare=0.35, color=TINT,
                 smooth=sm, tag="cloth")
    cape.paint((0.72, 0.72, 0.72), where=lambda x, y, z: y < 2.78)
    cape.paint((0.9, 0.9, 0.9), where=lambda x, y, z: y > 3.7)
    cape.h = [1.0] * len(cape.v)
    R.add("cape", cape, "Torso", "cape", "kingdom", weld="torso", tags=("governor",))
    # ermine collar (white, black spots painted on a deterministic subset of faces)
    col = loft([(3.5, 1.1, 0.68), (3.78, 1.06, 0.65), (4.02, 0.5, 0.4)], seg=seg, n=n, caps=(True, True), phase=p0,
               color=ERMINE, smooth=sm, tag="fur")
    for i in range(len(col.f)):
        if (i * 7 + 3) % 6 == 0:
            col.c[i] = ERMINE_SPOT
    col.h = [1.0] * len(col.v)
    R.add("collar_ermine", col, "Torso", "extra", "fixed", weld="torso", tags=("governor",))
    # gold trim: a front stripe down the robe and a hem band
    rx2 = lambda y: torso_r(y)[0]
    stripe = panel(rx2, rz_of, 1.5, 3.8, -0.2, 0.2, 0.06, front=True, nx=1, ny=3, off=0.025, color=GOLD, smooth=False, tag="metal")
    hem = loft([(1.42, 1.25, 0.89), (1.62, 1.2, 0.85)], seg=seg, n=n, caps=(True, True), phase=p0, color=GOLD, smooth=sm, tag="metal")
    trim = merge(stripe, hem)
    trim.h = [1.0] * len(trim.v)
    R.add("trim_regal", trim, "Torso", "extra", "fixed", weld="torso", tags=("governor",))


def _extra(R, name, m, joint="Torso", tint="fixed", weld="torso", slot="extra", tags=()):
    m.h = [1.0] * len(m.v)
    R.add(name, m, joint, slot, tint, weld=weld, tags=tags)


def build_extras(S, R):
    sm = S.smooth
    seg = S.seg(8, 6)
    rz_of = lambda y: torso_r(y)[1]
    rx_of = lambda y: torso_r(y)[0]
    # farmer's canvas apron: a front panel from the chest to just below the hips, a patch pocket
    ap = panel(rx_of, rz_of, 1.95, 3.55, -0.62, 0.62, 0.06, front=True, nx=S.seg(3, 2), ny=2, off=0.03, flare=0.04, color=CANVAS,
               smooth=False, tag="canvas")
    pocket = box(0.6, 0.3, 0.07, color=mix(CANVAS, (0.8, 0.76, 0.66), 1.0), smooth=False, tag="canvas").move(0, 2.5, -0.74)
    _extra(R, "apron_farm", merge(ap, pocket), tags=("farmer",))
    # blacksmith's leather apron: bib to the neck, dark, with a chest strap
    sa = panel(rx_of, rz_of, 1.9, 3.78, -0.7, 0.7, 0.07, front=True, nx=S.seg(3, 2), ny=2, off=0.03, flare=0.04, color=LEATHER_DARK,
               smooth=False, tag="leather")
    sa.paint(mix(LEATHER_DARK, LEATHER, 0.5), where=lambda x, y, z: y > 3.3)
    _extra(R, "apron_smith", sa, tags=("blacksmith",))
    # merchant's satchel: a cross strap and a bag on the back hip
    strap = tube([(-0.7, 3.88, 0.1), (-0.72, 3.5, -0.4), (0.0, 3.0, -0.58), (0.7, 2.6, -0.5), (0.95, 2.45, -0.1)], [0.1] * 5, seg=S.seg(4, 4),
                 n=2.0, color=LEATHER, smooth=sm, tag="leather", rz_scale=0.5)
    bag = merge(box(0.9, 0.75, 0.42, color=LEATHER, smooth=False, tag="leather").move(0.9, 2.45, 0.18),
                box(0.94, 0.28, 0.46, color=LEATHER_DARK, smooth=False, tag="leather").move(0.9, 2.72, 0.18))
    _extra(R, "satchel_merchant", merge(strap, bag), tags=("merchant",))
    # healer's herb satchel: a strap and a cloth bag with green herbs sticking out
    strap2 = tube([(0.7, 3.88, 0.1), (0.72, 3.5, -0.4), (0.0, 3.0, -0.58), (-0.7, 2.6, -0.5), (-0.95, 2.45, -0.1)], [0.1] * 5, seg=S.seg(4, 4),
                  n=2.0, color=LEATHER, smooth=sm, tag="leather", rz_scale=0.5)
    bag2 = merge(box(0.9, 0.72, 0.46, color=mix(CANVAS, (0.86, 0.8, 0.66), 1.0), smooth=False, tag="cloth").move(-0.9, 2.45, 0.2),
                 *[_leaf(0.18, 0.7, rgb(86, 150, 62)).rot(a, "z").move(-0.9 + dx, 2.78, 0.2) for a, dx in ((-20, -0.15), (20, 0.15))])
    _extra(R, "satchel_herb", merge(strap2, bag2), tags=("healer",))
    # archer's quiver on the back with three arrows
    qv = loft([(2.7, 0.28, 0.28), (3.85, 0.34, 0.34)], seg=seg, n=2.0, caps=(True, True), color=LEATHER, smooth=sm, tag="leather")
    arrows = [cyl(0.05, 0.05, 0.9, seg=4, y0=3.78, color=ASH, smooth=False, tag="arrow").move(dx, 0, dz) for dx, dz in ((-0.1, 0.0), (0.1, 0.06), (0.0, -0.08))]
    fl = [box(0.14, 0.34, 0.03, color=rgb(230, 224, 206), smooth=False, tag="feather").move(dx, 4.5, dz) for dx, dz in ((-0.1, 0.0), (0.1, 0.06))]
    q = merge(qv, *arrows, *fl).rot(14, "z").rot(-8, "x").move(-0.42, 0.0, 0.82)
    _extra(R, "quiver", q, tags=("soldier", "archer"))
    # kite shields (left arm), one per kingdom: kingdom-tinted face, dark rim, a raised emblem
    heater = [(-0.7, 0.95), (0.7, 0.95), (0.72, 0.2), (0.0, -0.95), (-0.72, 0.2)]
    for name, emblem in (("shield_crimson", _em_crown), ("shield_azure", _em_star), ("shield_emerald", _em_leaf), ("shield_gold", _em_sun)):
        rim = prism(heater, -0.09, 0.09, color=mix(TINT, (0.4, 0.4, 0.4), 1.0), smooth=False, tag="rim")
        face = prism([(x * 0.84, y * 0.86 + 0.04) for x, y in heater], -0.09, 0.14, color=mix(TINT, (0.7, 0.7, 0.7), 1.0), smooth=False,
                     tag="cloth")
        ep = emblem()
        cy = (min(p[1] for p in ep) + max(p[1] for p in ep)) / 2
        em = prism([(p[0] * 0.5, (p[1] - cy) * 0.5 + 0.08) for p in ep], 0.14, 0.24, color=TINT, smooth=False, tag="emblem")
        shield = merge(rim, face, em).rot(180, "y").move(-1.68, 3.0, -0.66)
        _extra(R, name, shield, joint="LeftArm", tint="kingdom", weld="arm", slot="shield", tags=("soldier", name.split("_")[1]))


def _em_crown():
    return [(-0.72, 0.0), (0.72, 0.0), (0.72, 0.6), (0.52, 0.5), (0.74, 1.35), (0.34, 0.95), (0.0, 1.5), (-0.34, 0.95), (-0.74, 1.35), (-0.52, 0.5),
            (-0.72, 0.6)]


def _em_star():
    pts = []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5
        r = 0.9 if i % 2 == 0 else 0.4
        pts.append((math.cos(a) * r, 0.78 + math.sin(a) * r))
    return [(-p[0], p[1]) for p in reversed(pts)]


def _em_leaf():
    return [(0.0, 0.0), (0.18, 0.2), (0.5, 0.18), (0.38, 0.5), (0.7, 0.6), (0.44, 0.85), (0.6, 1.1), (0.26, 1.2), (0.0, 1.62), (-0.26, 1.2),
            (-0.6, 1.1), (-0.44, 0.85), (-0.7, 0.6), (-0.38, 0.5), (-0.5, 0.18), (-0.18, 0.2)]


def _em_sun():
    pts = []
    for i in range(16):
        a = math.pi / 2 + i * math.pi / 8
        r = 0.88 if i % 2 == 0 else 0.55
        pts.append((math.cos(a) * r, 0.9 + math.sin(a) * r))
    return [(-p[0], p[1]) for p in reversed(pts)]


def build_gear(S, R):
    build_hats(S, R)
    build_tools(S, R)
    build_armour(S, R)
    build_regalia(S, R)
    build_extras(S, R)
