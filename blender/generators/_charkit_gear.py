"""Character kit: hats, hair accessories, held tools, armour, regalia and body extras (FL-0135).

Tools are authored in a local frame (grip point = origin, +y along the handle, forward = -z) and placed at the right
fist by `held()`. Everything here is registered in rig axes at the rest pose.
"""

import math

from lib.ckit import M, box, cone, cyl, hull, loft, merge, prism, sphere, tube

from . import _charkit_style as K
from ._charkit_body import HEAD_RINGS, _cap, arm_point, head_radius_at
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


BEANIE = (0.97, 0.5, 0.1)  # woodcutter's orange knit (baked: the runtime's cloth palette would turn it umber)
KNIT_CUFF = (0.98, 0.93, 0.84)
MINER_HELMET = (0.98, 0.8, 0.12)  # miner's yellow pot helmet: a value no other job's head has
HARDHAT = (0.06, 0.7, 0.72)  # builder's teal hard hat: the one saturated cyan on the field
MERCHANT_HAT = (0.5, 0.27, 0.74)  # merchant's violet beret (a lighter value than the dark first pass: reads on the grass)
HAULER_CAP = (0.1, 0.26, 0.86)  # hauler's cobalt flat cap: the one royal blue on the field
TABARD_GREEN = (0.1, 0.42, 0.22)  # healer's forest-green tabard (white cross)
COIF = (0.97, 0.96, 0.93)  # healer's white headscarf
SMITH_CAP = (0.2, 0.18, 0.18)  # blacksmith's soot-black skull cap
ROSE = rgb(222, 132, 148)  # the wanderer's cloth (idle's bindle and satchel): a hue no job wears
ROSE_DARK = rgb(176, 92, 108)


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
    brim = loft([(4.98, 1.9, 1.9), (5.1, 1.9, 1.9)], seg=S.seg(12, 8), n=2.0, caps=(True, True), phase=ph(S, S.seg(12, 8)),
                color=STRAW, smooth=sm, tag="straw")
    crown = loft([(5.08, 0.96, 0.94), (5.36, 0.92, 0.9), (5.76, 0.66, 0.64), (5.98, 0.0, 0.0)], seg=seg, n=n, caps=(True, False), phase=p0,
                 color=STRAW, smooth=sm, tag="straw")
    crown.paint(WOOD_DARK, where=lambda x, y, z: 5.1 < y < 5.4)
    hat(R, "hat_straw", merge(brim, crown), tags=("farmer",))

    # ---- tall knit cap with a folded cuff (woodcutter): orange, a long point; the pompom is a separate kingdom piece
    dome = loft([(4.9, 0.9, 0.86), (5.06, 0.95, 0.91), (5.4, 0.9, 0.86), (5.9, 0.68, 0.64), (6.3, 0.36, 0.34), (6.62, 0.0, 0.0)], seg=seg,
                n=n, caps=(True, False), phase=p0, color=BEANIE, smooth=sm, tag="cloth")
    dome.paint(KNIT_CUFF, where=lambda x, y, z: y < 5.14)
    hat(R, "hat_beanie", dome, tint="fixed", tags=("woodcutter",))
    pom = sphere(0.34, 0.34, 0.34, seg=S.seg(7, 5), rings=S.seg(4, 3), color=TINT, smooth=sm, tag="cloth").move(0, 6.68, 0.0)
    hat(R, "hat_pompom", pom, slot="hatband", tint="kingdom", tags=("woodcutter",))

    # ---- miner's pot helmet: yellow iron dome, a wide rim, a big lamp on the front
    pot = loft([(4.99, 1.3, 1.28), (5.1, 1.26, 1.24), (5.42, 0.96, 0.94), (5.78, 0.7, 0.68), (5.98, 0.0, 0.0)], seg=seg,
               n=n, caps=(True, False), phase=p0, color=MINER_HELMET, smooth=sm, tag="iron")
    pot.paint(mix(MINER_HELMET, (0.55, 0.4, 0.1), 0.45), where=lambda x, y, z: y < 5.12)
    lamp = merge(box(0.62, 0.5, 0.36, color=IRON, smooth=False, tag="lamp").move(0, 5.42, -1.0),
                 box(0.36, 0.3, 0.12, color=LAMP, smooth=False, tag="lamp").move(0, 5.42, -1.24))
    hat(R, "hat_miner", merge(pot, lamp), tags=("miner",))

    # ---- builder's hard hat: teal, a big peak and a white ridge along the crown (reads from above)
    hh = loft([(4.98, 0.92, 0.92), (5.3, 0.91, 0.91), (5.64, 0.74, 0.72), (5.86, 0.0, 0.0)], seg=seg, n=n, caps=(True, False), phase=p0,
              color=HARDHAT, smooth=sm, tag="cloth")
    peak = box(1.3, 0.12, 0.6, color=mix(HARDHAT, (0.0, 0.3, 0.35), 0.4), smooth=False, tag="cloth").move(0, 5.06, -1.14)
    ridge = box(0.24, 0.16, 1.5, color=(0.97, 0.97, 0.94), smooth=False, tag="cloth").move(0, 5.8, 0.0)
    hat(R, "hat_builder", merge(hh, peak, ridge), tint="fixed", tags=("builder",))

    # ---- hood: kingdom cowl closed over the head, the face opening in front
    hood = _hood(S, 0.11, 4.55, -0.5, back=False)
    hood.h = [1.0] * len(hood.v)
    R.add("hair_10", hood, "Head", "hair", "kingdom", weld="head", tags=("hair", "hood"))

    # ---- merchant's floppy beret with a feather
    beret = sphere(1.4, 0.5, 1.3, seg=S.seg(9, 8), rings=S.seg(4, 3), color=MERCHANT_HAT, smooth=sm, tag="cloth", phase=p0)
    beret = beret.rot(-8, "z").move(0.12, 5.3, 0.0)
    brimb = loft([(4.95, 0.93, 0.9), (5.12, 0.95, 0.92)], seg=seg, n=n, caps=(True, True), phase=p0, color=mix(MERCHANT_HAT, (0.15, 0.1, 0.2), 0.5),
                 smooth=sm, tag="cloth")
    feather = loft([(0.0, 0.0, 0.0), (0.3, 0.07, 0.04), (1.0, 0.16, 0.04), (1.6, 0.05, 0.02), (1.7, 0.0, 0.0)], seg=4, n=1.6,
                   caps=(False, False), color=rgb(246, 208, 66), smooth=False, tag="feather")
    feather = feather.scale(1.4, 1.0, 1.4).rot(-52, "z").rot(-14, "x").move(1.0, 5.4, -0.22)
    hat(R, "hat_merchant", merge(beret, brimb, feather), tint="fixed", tags=("merchant",))  # one piece with its feather (room for the tuft)

    # ---- healer coif: a linen coif with a wide stiff white brim (a big white ring from above) and a flat top carrying a big green cross
    coif = _hood(S, 0.07, 4.55, -0.5, back=False, color=COIF)
    wing = loft([(4.97, 1.5, 1.42), (5.07, 1.5, 1.42)], seg=S.seg(10, 8), n=2.0, caps=(True, True), phase=ph(S, S.seg(10, 8)), color=COIF,
                smooth=sm, tag="cloth")
    green = rgb(34, 150, 74)
    drum = loft([(5.3, 0.74, 0.74), (5.5, 0.74, 0.74)], seg=5, n=2.0, caps=(True, True), phase=0.0, color=COIF, smooth=False, tag="cloth")
    # a green cross on the flat top (seen from the aerial camera) and one on the front of the hood (seen in the card portrait)
    top_cross = merge(box(1.5, 0.08, 0.4, color=green, smooth=False, tag="cross"), box(0.4, 0.08, 1.5, color=green, smooth=False, tag="cross")).move(0, 5.52, 0.0)
    front_cross = merge(box(0.6, 0.17, 0.07, color=green, smooth=False, tag="cross"), box(0.17, 0.6, 0.07, color=green, smooth=False, tag="cross")).rot(
        -24, "x").move(0, 5.2, -0.78)
    hat(R, "hat_coif", merge(coif, wing, drum, top_cross, front_cross), tint="fixed", tags=("healer",))

    # ---- blacksmith: a wide soot-black forge hat (broad brim, flat crown, an ember-orange band); the beard is his hair piece
    sbrim = loft([(4.96, 1.26, 1.22), (5.06, 1.26, 1.22)], seg=S.seg(10, 8), n=2.0, caps=(True, True), phase=ph(S, S.seg(10, 8)),
                 color=mix(SMITH_CAP, (0.5, 0.42, 0.34), 0.35), smooth=sm, tag="leather")
    scrown = loft([(5.04, 0.97, 0.94), (5.3, 0.95, 0.92), (5.62, 0.84, 0.82), (5.72, 0.0, 0.0)], seg=seg, n=n, caps=(True, False), phase=p0,
                  color=SMITH_CAP, smooth=sm, tag="leather")
    scrown.paint((0.95, 0.42, 0.1), where=lambda x, y, z: 5.06 < y < 5.28)
    hat(R, "hat_smith", merge(sbrim, scrown), tint="fixed", tags=("blacksmith",))
    # ---- hauler's flat cap: cobalt blue, a wide squashed crown and a short peak (the only blue head on the field)
    hcrown = loft([(4.97, 0.98, 0.95), (5.12, 1.02, 0.99), (5.36, 0.98, 0.95), (5.5, 0.62, 0.6), (5.54, 0.0, 0.0)], seg=seg, n=n,
                  caps=(True, False), phase=p0, color=HAULER_CAP, smooth=sm, tag="cloth")
    hpeak = box(1.1, 0.1, 0.55, color=mix(HAULER_CAP, (0.0, 0.0, 0.25), 0.5), smooth=False, tag="cloth").move(0, 5.04, -1.12)
    hat(R, "hat_hauler", merge(hcrown, hpeak), tint="fixed", tags=("hauler",))
    # headband (idle accessory): a band with a knot
    hb = loft([(4.88, 0.92, 0.88), (5.02, 0.93, 0.89)], seg=seg, n=n, caps=(True, True), phase=p0, color=TINT, smooth=sm, tag="cloth")
    hbk = sphere(0.26, 0.3, 0.2, seg=S.seg(6, 5), rings=2, color=TINT, smooth=sm, tag="cloth").rot(-16, "z").move(0.0, 4.95, 0.94)
    hat(R, "acc_02", merge(hb, hbk), slot="acc", tint="cloth", tags=("idle", "headband"))


def _hood(S, thick, rim_y, tilt_z, tip=0.0, flare=0.0, back=True, color=TINT):
    """Cowl over the head: a shell whose rim is tilted (high at the forehead, low at the nape) and a drape at the back.

    The tilt is a shear that fades out towards the crown (no fold where a lower ring would stick up past the raised front
    rim); every vertex is then re-fitted to the head contour at its new height, so the shell hugs the cranium."""
    seg = S.seg(10, 8)
    n = S.n if S.A else 2.5
    top = 5.3
    rings = []
    for y in (5.3, 5.05, 4.8):
        if y > rim_y + 0.05:
            rx, rz, cz = head_radius_at(y)
            rings.append((y, rx + thick, rz + thick, 0.0, cz))
    rx, rz, cz = head_radius_at(rim_y)
    rings.append((rim_y, rx + thick + flare, rz + thick + flare, 0.0, cz))
    rings = [(5.42 + thick + tip, 0.0, 0.0)] + rings
    rings = list(reversed(rings))
    m = loft(rings, seg=seg, n=n, caps=(True, False), phase=ph(S, seg), color=color, smooth=S.smooth, tag="cloth")
    for i, (x, y, z) in enumerate(m.v):
        w = min(1.0, max(0.0, (top - y) / (top - rim_y)))
        if w <= 0.0 or i >= len(m.v) - 1 and False:
            continue
        y2 = y + tilt_z * z * w
        r0, r1 = head_radius_at(y), head_radius_at(y2)
        g = thick + flare * w
        m.v[i] = (x * (r1[0] + g) / (r0[0] + g), y2, z * (r1[1] + g) / (r0[1] + g))
    if back:  # a fold of cloth round the neck / shoulders
        neck = loft([(3.9, 0.7, 0.62), (4.12, 0.9, 0.82), (4.34, 0.88, 0.8)], seg=seg, n=n, caps=(True, True), phase=ph(S, seg),
                    color=color, smooth=S.smooth, tag="cloth")
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

    # ---- hoe: long pale shaft, steel socket, a big flat blade angled down at the top (about 1.3x the old one)
    shaft = _shaft(S, -1.75, 4.3, 0.16, WOOD_LIGHT, 0.14)
    sock = _shaft(S, 3.8, 4.35, 0.22, STEEL_DARK, tag="metal")
    neck = box(0.24, 0.22, 0.85, color=STEEL_DARK, smooth=False, tag="metal").move(0, 4.15, -0.5)
    blade = _side_prism([(0.2, 4.25), (1.05, 4.15), (1.65, 3.2), (1.7, 2.75), (0.9, 3.05), (0.2, 3.7)], 0.5, rgb(170, 180, 196))
    tool(R, "tool_hoe", held(merge(shaft, sock, neck, blade), lean=3), tags=("farmer",))

    # ---- axe: long haft + a heavy bearded head (about 1.35x), bright steel
    haft = _shaft(S, -1.1, 3.8, 0.18, WOOD, 0.16)
    back = hull([(sx * 0.19, y, f) for sx in (-1, 1) for (f, y) in ((0.22, 2.7), (0.22, 4.1), (-0.38, 3.1), (-0.38, 3.7))],
                color=STEEL_DARK, smooth=False, tag="metal")
    back = _swap_fy(back)
    wedge = _swap_fy(hull([(sx * 0.19, y, f) for sx in (-1, 1) for (f, y) in ((0.18, 2.55), (0.18, 4.25))]
                          + [(0.0, y, f) for (f, y) in ((1.85, 1.75), (1.85, 5.0))], color=rgb(206, 214, 224), smooth=False, tag="metal"))
    tool(R, "tool_axe", held(merge(haft, back, wedge), lean=8), tags=("woodcutter",))

    # ---- pickaxe: dark haft, a long one-sided mattock head (long curved end outward, short blunt end inward)
    haft2 = _shaft(S, -1.2, 3.95, 0.18, WOOD_DARK, 0.16)
    pts, rad = [], []
    for u in (-0.5, -0.2, 0.0, 1.1, 2.3):  # along the head axis: a short blunt end (-) and a long curved pick end (+)
        t = u / 2.2
        pts.append((u, 4.0 + 0.4 * (1 - t * t) - 0.24 * abs(t) ** 1.6, 0.0))
        rad.append(0.035 + 0.2 * (1 - min(1.0, abs(t)) ** 1.4) + (0.1 if u < 0 else 0.0))
    head = tube(pts, rad, seg=S.seg(5, 4), n=2.0, color=rgb(150, 158, 170), smooth=sm, tag="metal")
    boss = box(0.5, 0.52, 0.5, color=IRON, smooth=False, tag="metal").move(0, 4.02, 0)
    pick = merge(head, boss).rot(55, "y", pivot=(0, 0, 0))
    tool(R, "tool_pick", held(merge(haft2, pick), lean=3), tags=("miner",))

    # ---- mallet: builder's wooden maul with iron bands, a big head lying front to back
    h3 = _shaft(S, -0.9, 2.4, 0.17, WOOD_PALE)
    mh = box(1.7, 0.9, 0.9, color=rgb(150, 104, 62), smooth=False, tag="wood").move(0, 2.7, 0)
    bands = [box(0.18, 0.96, 0.96, color=IRON, smooth=False, tag="metal").move(sx * 0.6, 2.7, 0) for sx in (-1, 1)]
    mall = merge(h3, mh, *bands).rot(90, "y")
    tool(R, "tool_mallet", held(mall, lean=4), tags=("builder",))

    # ---- smith hammer: a thick handle, a huge steel head with a peen (about 1.6x the first kit's)
    h4 = _shaft(S, -0.9, 2.8, 0.22, WOOD_DARK, 0.2)
    head4 = merge(box(1.6, 1.4, 1.4, color=rgb(200, 208, 220), smooth=False, tag="metal").move(0, 3.2, 0),
                  hull([(0.8, 3.9, -0.7), (0.8, 2.5, -0.7), (0.8, 3.9, 0.7), (0.8, 2.5, 0.7), (1.9, 3.55, -0.15),
                        (1.9, 2.85, -0.15), (1.9, 3.55, 0.15), (1.9, 2.85, 0.15)], color=STEEL_DARK, smooth=False, tag="metal"))
    tool(R, "tool_hammer", held(merge(h4, head4.rot(30, "y")), lean=10), tags=("blacksmith",))

    # ---- merchant's hand scale: a short stave with a forward arm; the beam (4 studs) hangs out in front of the chest below the chin, so the card
    # portrait's head stays clear while the long beam and the two big pans still read from above
    st = _shaft(S, -0.9, 1.0, 0.12, WOOD_DARK)
    fwd = tube([(0, 1.0, 0.0), (0, 1.0, -1.25)], [0.1, 0.1], seg=4, color=WOOD_DARK, smooth=False, tag="wood")
    beam = box(4.0, 0.18, 0.18, color=GOLD, smooth=False, tag="metal").move(0, 1.0, -1.25)
    fin = cone(0.17, 0.2, seg=4, y0=1.09, color=GOLD, smooth=False, tag="metal").move(0, 0, -1.25)
    pans = []
    for sx in (-1, 1):
        cx = sx * 1.9
        pans.append(cyl(0.85, 0.46, 0.16, seg=S.seg(8, 6), y0=-0.16, color=GOLD_DARK, smooth=sm, tag="metal").move(cx, 0, -1.25))
        pans.append(box(0.06, 1.0, 0.06, color=IRON, smooth=False, tag="metal").move(cx, 0.5, -1.25))
    scale = merge(st, fwd, beam, fin, *pans)
    tool(R, "tool_scale", held(scale, lean=4), tags=("merchant",))

    # ---- healer's staff: a tall wooden stave, a big crook at the top with a herb bundle
    st2 = _shaft(S, -1.8, 4.6, 0.16, WOOD_LIGHT, 0.14)
    crook = tube([(0, 4.55, 0), (0, 5.2, -0.25), (0, 5.2, -0.85), (0, 4.7, -1.1)], [0.16, 0.14, 0.13, 0.1],
                 seg=S.seg(5, 4), color=WOOD_LIGHT, smooth=sm, tag="wood")
    leaf_c = rgb(86, 160, 62)
    leaves = [_leaf(0.38, 0.95, leaf_c).rot(a, "z").move(0, 4.45, -1.1) for a in (-30, 30)]
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

    # ---- hauler's sack (Torso joint "TorsoTool"): a big lumpy burlap ball tied high above the shoulders; strap on the chest
    body = sphere(1.12, 1.3, 1.15, seg=S.seg(8, 7), rings=S.seg(5, 4), color=BURLAP, smooth=sm, tag="sack")
    body = body.map(lambda p: (p[0] + 0.05 * math.sin(p[1] * 3), p[1], p[2] + 0.06 * math.sin(p[0] * 4 + p[1]))).move(0.1, 3.75, 2.15)
    neck = loft([(4.5, 0.6, 0.55), (4.95, 0.34, 0.32), (5.45, 0.55, 0.5)], seg=S.seg(8, 6), n=2.0, caps=(True, True),
                color=BURLAP, smooth=sm, tag="sack").move(0.1, 0, 2.15)
    tie = _shaft(S, 4.88, 5.06, 0.4, rgb(176, 36, 52), seg=6, tag="tie").move(0.1, 0, 2.15)
    sack = merge(body, neck, tie)
    sack.h = [1.0] * len(sack.v)
    R.add("tool_sack", sack, "TorsoTool", "tool", "fixed", weld=None, tags=("tool", "hauler"))
    path = [(0.64, 3.95, 0.12), (0.7, 3.78, -0.3), (0.42, 3.34, -0.55), (-0.12, 2.9, -0.58), (-0.62, 2.5, -0.5), (-0.78, 2.32, -0.25)]
    strap = tube(path, [0.12] * 6, seg=S.seg(4, 4), n=2.0, color=TINT, smooth=sm, tag="cloth", rz_scale=0.55)
    strap.h = [1.0] * len(strap.v)
    R.add("strap_kingdom", strap, "Torso", "extra", "kingdom", weld="torso", tags=("hauler",))


def _swap_fy(m):
    """hull() points were given as (x, y, f); rotate so f (forward) maps to -z (the grip frame's forward)."""
    return m.map(lambda p: (p[0], p[1], -p[2])).fix_winding()  # a mirror: restore outward winding


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

    def crest(name, poly, rise=0.0, height=1.24):
        # the emblem is scaled to a fixed height: the Kit specs keep every body part (hats and crests included) under 7.2 studs
        ys = [p[1] for p in poly]
        k = height / (max(ys) - min(ys))
        poly = [(x * k, y * k) for x, y in poly]
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
    crest("crest_neutral", [(-0.6, 0.0), (0.6, 0.0), (0.6, 0.8), (0.0, 1.55), (-0.6, 0.8)])  # a plain plume: no kingdom emblem


def build_regalia(S, R):
    sm = S.smooth
    seg = S.seg(10, 8)
    n = S.n if S.A else 2.5
    p0 = ph(S, seg)
    # crown: gold band + five points with a red jewel on the front point
    band = loft([(5.0, 1.0, 0.98), (5.4, 1.0, 0.98)], seg=S.seg(8, 8), n=n, caps=(True, True), phase=ph(S, S.seg(8, 8)), color=GOLD, smooth=sm, tag="metal")
    band.paint(GOLD_DARK, where=lambda x, y, z: y < 5.1)
    pts = []
    for i in range(5):
        a = math.tau * i / 5
        c = cone(0.26, 0.95, seg=3, y0=5.36, color=GOLD, smooth=False, tag="metal").move(math.sin(a) * 0.9, 0, math.cos(a) * -0.88)
        pts.append(c)
    gem = sphere(0.18, 0.18, 0.12, seg=S.seg(5, 4), rings=2, color=RED_GEM, smooth=False, tag="gem").move(0, 5.2, -1.0)
    hat(R, "hat_crown", merge(band, gem, *pts), tags=("governor",))
    cap = loft([(5.2, 0.86, 0.84), (5.5, 0.82, 0.8), (5.78, 0.52, 0.5), (5.9, 0.0, 0.0)], seg=seg, n=n, caps=(True, False), phase=p0,
               color=TINT, smooth=sm, tag="cloth")
    hat(R, "crown_cap", cap, slot="hatband", tint="kingdom", tags=("governor",))
    # cape: a back panel hanging from the shoulders to just above the hips (clears every leg swing); kingdom
    rx_of = lambda y: torso_r(y)[0] + 0.14
    rz_of = lambda y: torso_r(y)[1]
    cape = panel(rx_of, rz_of, 2.3, 3.85, -0.9, 0.9, 0.1, front=False, nx=S.seg(4, 3), ny=2, off=0.12, flare=0.5, color=TINT,
                 smooth=sm, tag="cloth")
    cape.paint((0.8, 0.8, 0.8), where=lambda x, y, z: y < 2.7)
    cape.paint((0.9, 0.9, 0.9), where=lambda x, y, z: y > 3.7)
    cape.h = [1.0] * len(cape.v)
    R.add("cape", cape, "Torso", "cape", "kingdom", weld="torso", tags=("governor",))
    # ermine collar (white, black spots painted on a deterministic subset of faces)
    col = loft([(3.4, 1.32, 0.8), (3.74, 1.28, 0.76), (4.02, 0.5, 0.4)], seg=seg, n=n, caps=(True, True), phase=p0,
               color=ERMINE, smooth=sm, tag="fur")
    for i in range(len(col.f)):
        if (i * 7 + 3) % 6 == 0:
            col.c[i] = ERMINE_SPOT
    col.h = [1.0] * len(col.v)
    # gold trim: a front stripe down the robe and a hem band
    rx2 = lambda y: torso_r(y)[0]
    stripe = panel(rx2, rz_of, 1.72, 3.8, -0.2, 0.2, 0.06, front=True, nx=1, ny=3, off=0.025, color=GOLD, smooth=False, tag="metal")
    hem = loft([(1.66, 1.21, 0.85), (1.84, 1.17, 0.81)], seg=seg, n=n, caps=(True, True), phase=p0, color=GOLD, smooth=sm, tag="metal")
    trim = merge(stripe, hem, col)  # one piece: the ermine collar, the gold front stripe and the hem band (fixed colours)
    trim.h = [1.0] * len(trim.v)
    R.add("trim_regal", trim, "Torso", "extra", "fixed", weld="torso", tags=("governor", "ermine"))


def _extra(R, name, m, joint="Torso", tint="fixed", weld="torso", slot="extra", tags=()):
    m.h = [1.0] * len(m.v)
    R.add(name, m, joint, slot, tint, weld=weld, tags=tags)


def build_extras(S, R):
    sm = S.smooth
    seg = S.seg(8, 6)
    rz_of = lambda y: torso_r(y)[1]
    rx_of = lambda y: torso_r(y)[0]
    # ---- aerial gear (fixed colours): one piece per job so the piece count stays; each reads from above at 170 studs
    # farmer: canvas apron + a wicker basket of wheat on the back (gold sheaf above the shoulders)
    ap = panel(rx_of, rz_of, 2.1, 3.55, -0.62, 0.62, 0.06, front=True, nx=1, ny=1, off=0.03, flare=0.03, color=CANVAS,
               smooth=False, tag="canvas")
    pocket = box(0.6, 0.3, 0.07, color=mix(CANVAS, (0.8, 0.76, 0.66), 1.0), smooth=False, tag="canvas").move(0, 2.5, -0.74)
    basket = cyl(0.7, 0.55, 1.0, seg=S.seg(7, 6), y0=2.7, color=rgb(168, 118, 62), smooth=False, tag="basket").move(0, 0, 1.05)
    sheaf = cone(0.62, 1.2, seg=S.seg(7, 6), y0=3.7, color=rgb(240, 200, 70), smooth=False, tag="wheat").move(0, 0, 1.05)
    _extra(R, "gear_farmer", merge(ap, pocket, basket, sheaf), tags=("farmer",))
    # woodcutter: a standing bundle of three logs on the back, pale cut tops above the shoulders
    logs = []
    for (lx, lz) in ((-0.4, 1.15), (0.4, 1.15), (0.0, 1.65)):
        lg = cyl(0.34, 0.34, 2.9, seg=5, y0=2.3, color=rgb(104, 68, 40), smooth=False, tag="log").move(lx, 0, lz)
        lg.paint(rgb(232, 196, 138), where=lambda x, y, z: y > 5.1)
        logs.append(lg)
    _extra(R, "gear_woodcutter", merge(*logs), tags=("woodcutter",))
    # miner: a canvas pack with a lit lantern hung on it
    pack = box(1.5, 1.6, 0.8, color=rgb(70, 86, 112), smooth=False, tag="pack").move(0, 3.1, 1.0)
    lantern = merge(box(0.34, 0.4, 0.34, color=rgb(255, 232, 120), smooth=False, tag="lamp").move(0.0, 4.15, 1.2),
                    box(0.44, 0.1, 0.44, color=IRON, smooth=False, tag="metal").move(0.0, 4.4, 1.2))
    _extra(R, "gear_miner", merge(pack, lantern), tags=("miner",))
    # builder: a bundle of three pale planks standing on the back, leaning away from the head
    planks = [box(1.0, 3.2, 0.14, color=rgb(214, 176, 122), smooth=False, tag="plank").rot(-5, "x", pivot=(0, 2.0, 1.0)).move(0, 3.5, 0.98 + i * 0.16)
              for i in range(3)]
    _extra(R, "gear_builder", merge(*planks), tags=("builder",))
    # blacksmith: a pale leather apron (value contrast on the charcoal shirt), bib to the neck, a dark chest strap
    sa = panel(rx_of, rz_of, 2.05, 3.78, -0.7, 0.7, 0.07, front=True, nx=1, ny=2, off=0.03, flare=0.03, color=rgb(206, 160, 104),
               smooth=False, tag="leather")
    sa.paint(rgb(60, 40, 26), where=lambda x, y, z: y > 3.55)
    anv_c, anv_top = rgb(86, 92, 104), rgb(170, 178, 192)
    anvil = merge(box(1.0, 0.22, 0.62, color=anv_c, smooth=False, tag="anvil").move(0, 3.0, 1.08),
                  box(0.5, 0.42, 0.46, color=anv_c, smooth=False, tag="anvil").move(0, 3.32, 1.08),
                  box(1.9, 0.36, 0.64, color=anv_c, smooth=False, tag="anvil").move(0.12, 3.7, 1.08),
                  cone(0.3, 0.95, seg=4, color=anv_c, smooth=False, tag="anvil").rot(-90, "z").move(-1.05, 3.7, 1.08))
    anvil.paint(anv_top, where=lambda x, y, z: y > 3.84)
    _extra(R, "gear_smith", merge(sa, anvil), tags=("blacksmith",))
    # merchant: a big pack with a yellow bedroll on top and two shoulder straps
    mpack = box(1.6, 1.5, 0.9, color=rgb(120, 62, 40), smooth=False, tag="pack").move(0, 3.1, 1.05)
    roll = cyl(0.42, 0.42, 1.9, seg=5, y0=0.0, color=rgb(246, 208, 66), smooth=False, tag="roll").rot(90, "z").move(0.0, 3.95, 1.4)
    straps = [box(0.16, 1.4, 0.1, color=LEATHER_DARK, smooth=False, tag="leather").move(sx * 0.45, 3.2, 0.58) for sx in (-1, 1)]
    _extra(R, "gear_merchant", merge(mpack, roll, *straps), tags=("merchant",))
    # healer: a forest-green tabard (front and back) with a big white cross: a body colour no other job has
    white = rgb(246, 244, 236)
    tab = [panel(rx_of, rz_of, 2.42, 3.5, -0.74, 0.74, 0.06, front=fr, nx=1, ny=1, off=0.03, flare=0.03, color=TABARD_GREEN, smooth=False, tag="cloth")
           for fr in (True, False)]
    crosses = []
    for sgn in (-1.0, 1.0):
        zc = sgn * (rz_of(3.0) + 0.12)
        crosses.append(box(0.3, 0.9, 0.07, color=white, smooth=False, tag="cross").move(0, 2.95, zc))
        crosses.append(box(0.8, 0.28, 0.07, color=white, smooth=False, tag="cross").move(0, 3.1, zc))
    _extra(R, "gear_healer", merge(*tab, *crosses), tags=("healer",))
    # archer's quiver on the back with three arrows
    qv = loft([(2.7, 0.28, 0.28), (3.85, 0.34, 0.34)], seg=seg, n=2.0, caps=(True, True), color=LEATHER, smooth=sm, tag="leather")
    arrows = [cyl(0.05, 0.05, 0.9, seg=4, y0=3.78, color=ASH, smooth=False, tag="arrow").move(dx, 0, dz) for dx, dz in ((-0.1, 0.0), (0.1, 0.06), (0.0, -0.08))]
    fl = [box(0.14, 0.34, 0.03, color=rgb(230, 224, 206), smooth=False, tag="feather").move(dx, 4.5, dz) for dx, dz in ((-0.1, 0.0), (0.1, 0.06))]
    q = merge(qv, *arrows, *fl).rot(12, "z", pivot=(0, 3.3, 0)).rot(-8, "x", pivot=(0, 3.3, 0)).move(-0.4, 0.0, 0.86)
    _extra(R, "quiver", q, tags=("soldier", "archer"))
    # kite shields (left arm), one per kingdom: kingdom-tinted face, dark rim, a raised emblem
    heater = [(-0.7, 0.95), (0.7, 0.95), (0.72, 0.2), (0.0, -0.95), (-0.72, 0.2)]
    for name, emblem in (("shield_crimson", _em_crown), ("shield_azure", _em_star), ("shield_emerald", _em_leaf), ("shield_gold", _em_sun),
                         ("shield_neutral", _em_chevron)):
        rim = prism(heater, -0.09, 0.09, color=mix(TINT, (0.4, 0.4, 0.4), 1.0), smooth=False, tag="rim")
        face = prism([(x * 0.84, y * 0.86 + 0.04) for x, y in heater], -0.09, 0.14, color=mix(TINT, (0.7, 0.7, 0.7), 1.0), smooth=False,
                     tag="cloth")
        ep = emblem()
        cy = (min(p[1] for p in ep) + max(p[1] for p in ep)) / 2
        em = prism([(p[0] * 0.5, (p[1] - cy) * 0.5 + 0.08) for p in ep], 0.14, 0.24, color=TINT, smooth=False, tag="emblem")
        shield = merge(rim, face, em).rot(180, "y").move(-1.68, 3.0, -0.66)
        _extra(R, name, shield, joint="LeftArm", tint="kingdom", weld="arm", slot="shield", tags=("soldier", name.split("_")[1]))


def _em_chevron():
    return [(-0.62, 0.0), (0.0, 1.0), (0.62, 0.0), (0.36, 0.0), (0.0, 0.5), (-0.36, 0.0)]


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


def build_mantle(S, R):
    """The citizens' team mark: a kingdom-coloured shoulder mantle (yoke) round the neck, over the job-coloured tunic.

    It is the large kingdom-coloured area seen from above; the job lives in the tunic colour, hat and tool. Wider than the
    torso by 0.04 at the sides (the sleeves start at x = 1.01) and 0.12 in front / behind (clear of aprons and straps)."""
    seg = S.seg(10, 8)
    rings = [(y, torso_r(y)[0] + 0.04, torso_r(y)[1] + 0.12) for y in (3.46, 3.7, 3.86)] + [(3.97, 0.5, 0.42)]
    m = loft(rings, seg=seg, n=S.n if S.A else 2.5, caps=(True, True), phase=ph(S, seg), color=TINT, smooth=S.smooth, tag="cloth")
    m.paint((0.8, 0.8, 0.8), where=lambda x, y, z: y < 3.56)  # a darker hem band
    m.h = [1.0] * len(m.v)
    R.add("mantle_kingdom", m, "Torso", "extra", "kingdom", weld="torso", tags=("citizen",))


# ================================================================== hair under a hat (tufts) and idle's accessories

def _head_arc(y, a0, a1, grow, n, droop=0.0):
    """Points on the cranium's ellipse at height y from angle a0 to a1 degrees (0 = straight back, + towards +x), `grow` outside it."""
    pts = []
    for i in range(n):
        a = math.radians(a0 + (a1 - a0) * i / (n - 1))
        yy = y - droop * abs(math.sin(a))
        rx, rz, cz = head_radius_at(yy)
        pts.append((math.sin(a) * (rx + grow), yy, math.cos(a) * (rz + grow) + cz))
    return pts


def _short_locks(color, sm):
    """Two short locks beside the cheeks (8 triangles each), so that every tuft style shows in the front view."""
    rx, rz, cz = head_radius_at(4.55)
    return [tube([(sx * (rx + 0.03), 4.74, -0.22), (sx * (rx + 0.12), 4.34, -0.12)], [0.14, 0.09], seg=3, color=color, smooth=sm, tag="hair") for sx in (-1, 1)]


def tuft_mesh(S, style, color, max_tris=60):
    """Six small hair pieces that show under a hat brim (below y 4.88) so that hat jobs vary by look: 1 sideburns and a nape fringe,
    2 a nape roll, 3 a short ponytail, 4 side locks, 5 curls, 6 a back curtain. Authored for the Head joint in rig axes; all of them stay
    inside the brim of every hat (brims start at y 4.9) and behind the face (z > -0.45)."""
    sm = S.smooth
    sg = S.seg(5, 4)
    parts = []
    if style == 1:  # sideburns in front of the ears + a fringe across the nape
        for sx in (-1, 1):
            rx, rz, cz = head_radius_at(4.5)
            parts.append(box(0.18, 0.62, 0.24, color=color, smooth=False, tag="hair").rot(sx * 6, "z").move(sx * (rx + 0.05), 4.48, -0.3))
        parts.append(tube(_head_arc(4.52, -60, 60, 0.1, 3), 0.15, seg=3, color=color, smooth=sm, tag="hair"))
    elif style == 2:  # a roll of hair round the nape, ear to ear
        parts.append(tube(_head_arc(4.6, -98, 98, 0.15, 5, 0.1), 0.22, seg=3, color=color, smooth=sm, tag="hair"))
    elif style == 3:  # a short ponytail out of the nape
        parts.append(sphere(0.2, 0.2, 0.2, seg=sg, rings=2, color=color, smooth=sm, tag="hair").move(0, 4.72, 0.86))
        parts.append(tube([(0, 4.7, 0.84), (0, 4.45, 1.08), (0, 4.1, 1.16), (0, 3.85, 1.02)], [0.17, 0.22, 0.19, 0.08], seg=3, color=color,
                          smooth=sm, tag="hair"))
        parts.extend(_short_locks(color, sm))
    elif style == 4:  # locks down both sides of the head to the shoulders
        for sx in (-1, 1):
            parts.append(tube([(sx * 0.84, 4.8, 0.0), (sx * 1.02, 4.4, 0.06), (sx * 1.04, 3.98, 0.08)], [0.2, 0.24, 0.1], seg=3, color=color,
                              smooth=sm, tag="hair"))
    elif style == 5:  # a ring of curls under the brim at the back and sides
        for ang in (-72, -36, 0, 36, 72):
            a = math.radians(ang)
            rx, rz, cz = head_radius_at(4.68)
            parts.append(sphere(0.33, 0.31, 0.33, seg=sg, rings=2, color=color, smooth=sm, tag="hair").move(
                math.sin(a) * (rx + 0.1), 4.64, math.cos(a) * (rz + 0.1) + cz))
    else:  # a curtain of hair down the back of the head
        parts.append(loft([(4.14, 0.55, 0.14, 0.0, 0.82), (4.5, 0.84, 0.22, 0.0, 0.74), (4.88, 0.8, 0.18, 0.0, 0.66)],
                          seg=5, n=2.0, caps=(True, True), color=color, smooth=sm, tag="hair"))
        parts.extend(_short_locks(color, sm))
    m = merge(*parts)
    if m.tris > max_tris:
        raise ValueError(f"tuft {style} has {m.tris} triangles, limit {max_tris}")
    return m


def build_tufts(S, R):
    """tuft_01..06, picked by the look's hair style: the hair that shows under the hat of farmer, miner, builder, hauler, blacksmith and
    merchant (the healer's coif and the woodcutter's pompom, which has no room for another piece, keep their looks)."""
    for i in range(1, 7):
        m = tuft_mesh(S, i, TINT, max_tris=44)
        m.h = [1.0] * len(m.v)
        R.add(f"tuft_{i:02d}", m, "Head", "hair", "hair", weld="head", tags=("hair", "tuft"))


def build_idle_acc(S, R):
    """The idle citizen's wanderer kit (some looks): acc_03 a bandana (head-cloth, on the Head; acc_01 none and acc_02 headband are built with
    the hats), and the packs on the back (slot extra, Torso; pack_01 and pack_02 are empty): pack_03 a bindle (bundle on a stick) and pack_04 a
    small rucksack, in a rose cloth no job wears."""
    sm = S.smooth
    seg = S.seg(10, 8)
    # --- acc_03: a bandana hugging the head with a knot at the back (cloth tint: the light folk linen)
    cap = _cap(S, 0.14, 4.78, -0.4, thick=0.12)
    cap.paint(TINT)
    knot = sphere(0.3, 0.34, 0.22, seg=S.seg(6, 5), rings=2, color=TINT, smooth=sm, tag="cloth").rot(18, "z").move(0.05, 4.62, 0.98)
    bandana = merge(cap, knot)
    bandana.h = [1.0] * len(bandana.v)
    R.add("acc_03", bandana, "Head", "acc", "cloth", weld="head", tags=("idle", "bandana"))
    # --- pack_03: a bindle: a rose bundle tied to the back and a stick poking up over the right shoulder
    bundle = sphere(0.78, 0.82, 0.68, seg=S.seg(8, 6), rings=S.seg(4, 3), color=ROSE, smooth=sm, tag="bundle").move(0.1, 3.5, 1.05)
    bundle.paint(ROSE_DARK, where=lambda x, y, z: y < 3.1)
    tie = box(0.5, 0.14, 0.14, color=CANVAS, smooth=False, tag="bundle").move(0.1, 4.04, 1.05)
    stick = tube([(-0.35, 2.75, 1.22), (0.35, 3.9, 1.1), (0.95, 4.85, 0.9)], [0.07, 0.07, 0.06], seg=3, color=WOOD_LIGHT, smooth=False, tag="wood")
    bindle = merge(bundle, tie, stick)
    bindle.h = [1.0] * len(bindle.v)
    R.add("pack_03", bindle, "Torso", "extra", "fixed", weld="torso", tags=("idle", "bindle"))
    # --- pack_04: a small rucksack on the back: a leather bag with a rose flap and two straps up to the shoulders
    bag = box(1.2, 1.0, 0.55, color=LEATHER, smooth=False, tag="bag").move(0.0, 3.2, 0.96)
    flap = box(1.25, 0.34, 0.6, color=ROSE, smooth=False, tag="bag").move(0.0, 3.55, 0.97)
    straps = [box(0.16, 1.0, 0.08, color=LEATHER_DARK, smooth=False, tag="bag").move(sx * 0.4, 3.45, 0.74) for sx in (-1, 1)]
    ruck = merge(bag, flap, *straps)
    ruck.h = [1.0] * len(ruck.v)
    R.add("pack_04", ruck, "Torso", "extra", "fixed", weld="torso", tags=("idle", "rucksack"))


def build_gear(S, R):
    build_hats(S, R)
    build_tools(S, R)
    build_armour(S, R)
    build_regalia(S, R)
    build_extras(S, R)
    build_mantle(S, R)
    build_tufts(S, R)
    build_idle_acc(S, R)
