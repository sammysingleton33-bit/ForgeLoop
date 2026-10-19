"""Windmills: a tapered round stone (or whitewashed) tower mill, an octagonal timber smock mill on a
stone base, or a timber post mill (weatherboarded buck on a trestle with ladder and tail pole), a turning timber cap (conical, boat-gabled tile or thatch,
or a domed cap echoing the kingdom's tower language), four big lattice sails (whips, sail
bars, longitudinal bars, angled slats or spread canvas: all solid geometry), a tail pole with a
winding wheel, an optional timber gallery, a walkable door, small windows with kingdom-colour
shutters, a hanging kingdom banner (emblem) and grain sacks + a spare millstone at the foot.

Front (door, sails) faces Blender -Y. ~33-39 studs tall including the sails.
"""

import math

from lib import kit
from lib.geo import Vector, box, cylinder, lathe
from lib.palette import kingdom_color

from generators import _farm_common as fc

NAME = "farm_windmill"
VERSION = 2
CATEGORY = "farm"
BUDGET = "building_medium"
COLLISION = {"fidelity": "PreciseConvexDecomposition"}
CHECKS = {"min_sails": 4, "min_windows": 2, "min_sacks": 3}
DEFAULT_VARIANTS = 4
HERO_VIEW = {"azimuth": 30, "elevation": 14}
LINEUP_GAP = 6.0

PLANS = [
    {"kingdom": "red", "tower": "stone", "cap": "cone", "sails": "canvas", "gallery": False, "angle": 12},
    {"kingdom": "green", "tower": "smock", "cap": "thatch", "sails": "mixed", "gallery": False, "angle": 40},
    {"kingdom": "blue", "tower": "white", "cap": "boat", "sails": "mixed", "gallery": True, "angle": 0},
    {"kingdom": "yellow", "tower": "post", "cap": "post", "sails": "canvas", "gallery": False, "angle": 28},
]


def asset_id(i, params):
    return f"{CATEGORY}_windmill_{i + 1:02d}"


def variants(n, seed):
    out = []
    for i in range(n):
        p = dict(PLANS[i % len(PLANS)])
        p["seed"] = seed * 1000 + 600 + i
        out.append(p)
    return out


# ------------------------------------------------------------------ tower

def tower_radius(z, r0, r1, H):
    t = max(0.0, min(1.0, z / H))
    return r0 + (r1 - r0) * t ** 0.85


def facing(phi):
    """Z rotation that turns a kit facade (normal -Y) to face direction angle phi."""
    return phi + math.pi / 2


def round_tower(b, rng, p, r0, r1, H, z0, k=None):
    """Lathe tower body with course bands, scattered proud stones and string courses."""
    kind = p["tower"]
    seg = 14
    nb = 11
    prof = [(tower_radius(H * k / nb, r0, r1, H), z0 + H * k / nb) for k in range(nb + 1)]
    prof = [(0.0, z0)] + prof + [(0.0, z0 + H)]
    ks = kingdom_color(k, "stone") if k else "stone"
    ksd = kingdom_color(k, "stone_dark") if k else "stone_dark"
    ksl = kingdom_color(k, "stone_light") if k else "stone_light"
    base, alt = {"stone": (ks, ksd), "white": ("plaster_white", "plaster"),
                 "sand": ("sandstone", "sandstone_light")}[kind]
    body = lathe(prof, seg, base)
    body.jitter(rng, 0.06)
    # faces per band: band 0 is the bottom pole fan; alternate tones for coursed masonry
    body.face_colors = [(alt if (fi // seg) % 3 == 1 else base) for fi in range(len(body.faces))]
    b.add(body.paint(grad=("range", 0.25, 0.9)), tag="tower")
    # proud stones (on the whitewashed tower: patches where the lime has fallen off)
    stones = (ksl, ks, ksd) if kind != "sand" else ("sandstone_light", "sandstone_dark")
    if kind == "white":
        stones = ("stone", "stone_light")
    for k in range(26 if kind != "white" else 14):
        phi = rng.uniform(0, math.tau)
        z = rng.uniform(1.0, H - 1.5)
        if abs(math.atan2(math.sin(phi + math.pi / 2), math.cos(phi + math.pi / 2))) < 0.7 and z < 10:
            continue  # keep the door clear
        r = tower_radius(z, r0, r1, H)
        st = kit.bbox(rng.uniform(1.2, 2.0), 0.5, rng.uniform(0.6, 0.9), rng.choice(stones), 0.0)
        st.jitter(rng, 0.06).rotate(facing(phi), "Z")
        st.move(math.cos(phi) * (r - 0.12), math.sin(phi) * (r - 0.12), z0 + z)
        b.add(st.paint(tint=rng.uniform(0, 1)), tag="stone")
    # string courses
    for zz in (H * 0.42, H - 0.6):
        r = tower_radius(zz, r0, r1, H)
        band = lathe([(r + 0.25, 0.0), (r + 0.25, 0.45), (r - 0.2, 0.45), (r - 0.2, 0.0)], seg,
                     "stone_dark" if kind == "stone" else ("timber" if kind == "white" else "sandstone_dark"))
        b.add(band.move(0, 0, z0 + zz), tag="band")
    # plinth: irregular block course around the foot
    pts = []
    for k in range(seg + 1):
        a = math.tau * k / seg
        pts.append((math.cos(a) * (r0 + 0.3), math.sin(a) * (r0 + 0.3), 0.0))
    pc = ("stone", "stone_dark") if kind != "sand" else ("sandstone_dark", "sandstone")
    b.add(kit.stone_course(pts, z0 + 0.15, 1.2, pc[0], rng, block=(2.0, 2.8), colors=pc), tag="plinth")


def smock_tower(b, rng, p, r0, r1, H, z0):
    """Octagonal timber smock mill on a stone base: boarded walls, corner posts."""
    base_h = 4.2
    seg = 8
    sb = lathe([(r0 + 0.5, 0.0), (r0 + 0.5, base_h), (0.0, base_h)], seg, "stone")
    sb.jitter(rng, 0.05)
    b.add(sb.paint(grad=("range", 0.2, 0.85)), tag="tower")
    b.add(lathe([(r0 + 0.75, 0.0), (r0 + 0.75, 0.4), (r0 + 0.55, 0.4), (r0 + 0.55, 0.0)], seg, "stone_dark")
          .move(0, 0, base_h - 0.4), tag="band")
    for k in range(18):  # dressed stones on the base
        a = math.tau * (k + rng.uniform(-0.3, 0.3)) / 18
        if abs(math.atan2(math.sin(a + math.pi / 2), math.cos(a + math.pi / 2))) < 0.55:
            continue
        ap = (r0 + 0.5) * math.cos(math.pi / seg)
        st = kit.bbox(rng.uniform(1.0, 1.6), 0.4, rng.uniform(0.6, 0.9), rng.choice(("stone_light", "stone_dark")), 0)
        st.rotate(facing(round(a / (math.tau / seg)) * (math.tau / seg)), "Z")
        aa = round(a / (math.tau / seg)) * (math.tau / seg)
        off = rng.uniform(-1.0, 1.0)
        st.move(math.cos(aa) * ap - math.sin(aa) * off, math.sin(aa) * ap + math.cos(aa) * off, rng.uniform(0.3, 3.3))
        b.add(st.paint(tint=rng.uniform(0, 1)), tag="stone")
    nb = 16
    Hb = H - base_h
    prof = [(0.0, 0.0)] + [(tower_radius(base_h + Hb * k / nb, r0, r1, H), base_h + Hb * k / nb)
                           for k in range(nb + 1)] + [(0.0, H)]
    body = lathe(prof, seg, "wood")
    body.face_colors = [("wood_light" if (fi // seg) % 2 else "wood") for fi in range(len(body.faces))]
    b.add(body.paint(grad=("range", 0.25, 0.9)), tag="tower")
    for k in range(seg):  # corner posts
        a = math.pi / seg + math.tau * k / seg
        rb = tower_radius(base_h, r0, r1, H) + 0.1
        rt = tower_radius(H, r0, r1, H) + 0.1
        b.add(kit.oriented_box((math.cos(a) * rb, math.sin(a) * rb, base_h),
                               (math.cos(a) * rt, math.sin(a) * rt, H), 0.55, 0.4, "timber",
                               Vector((math.cos(a), math.sin(a), 0))), tag="post")
    return base_h


# ------------------------------------------------------------------ cap and sails

def sail(rng, length, width, style, angle, hub_r=0.9, cloth="canvas_dark"):
    """One sail in the XZ plane (hub at origin), pointing along `angle`: whip + lattice frame on
    the trailing side, cross bars, then slats (louvres) or a spread canvas."""
    out = []
    u = Vector((math.cos(angle), 0, math.sin(angle)))
    v = Vector((-math.sin(angle), 0, math.cos(angle)))
    n = Vector((0, -1, 0))
    out.append(kit.oriented_box(u * hub_r * 0.5, u * length, 0.6, 0.5, "wood_dark", n))  # whip
    s0, s1 = length * 0.2, length - 0.25
    out.append(kit.oriented_box(u * s0 + v * width, u * s1 + v * width, 0.32, 0.3, "wood", n))
    out.append(kit.oriented_box(u * s0 + v * (width * 0.5), u * s1 + v * (width * 0.5), 0.22, 0.24, "wood", n))
    nbar = int((s1 - s0) / 1.25)
    for k in range(nbar + 1):
        s = s0 + (s1 - s0) * k / nbar
        p0 = u * s - v * 0.7
        p1 = u * s + v * (width + 0.2)
        out.append(kit.oriented_box(p0, p1, 0.2, 0.22, "wood_light", n).move(0, 0.12, 0))
    if style == "slats":
        for k in range(nbar):
            s = s0 + (s1 - s0) * (k + 0.5) / nbar
            tilt = Vector((0, -math.cos(0.55), 0)) + u * math.sin(0.55)  # louvre angle
            sl = kit.oriented_box(u * s + v * 0.35, u * s + v * (width - 0.15), 0.78, 0.1, "wood_pale", tilt)
            out.append(sl.move(0, 0.25, 0))
    elif style == "canvas":
        c = kit.oriented_box(u * (s0 + 0.2) + v * (width * 0.5), u * (s1 - 0.2) + v * (width * 0.5),
                             width - 0.2, 0.1, cloth, n)
        c.bend(lambda q: (q.x, q.y + 0.18 * math.sin(math.pi * max(0.0, min(1.0, (q.dot(u) - s0) / (s1 - s0)))), q.z))
        out.append(c.move(0, 0.3, 0))
    return out


def sails(rng, style, angle0, length=15.0, width=3.6, cloth="canvas_dark"):
    out = []
    for k in range(4):
        a = math.radians(angle0) + k * math.pi / 2
        st = style
        if style == "canvas" and k % 2:
            st = "bare"  # two sails spread, two left as open lattice
        if style == "mixed":
            st = "canvas" if k % 2 == 0 else "slats"
        out += sail(rng, length, width, st, a, cloth=cloth)
    hub = kit.bbox(1.6, 1.4, 1.6, "wood_dark", 0.15, base=False)
    out.append(hub)
    out.append(cylinder(0.5, 0.5, 0.5, 8, "iron_dark").rotate(math.pi / 2, "X").move(0, -0.7, 0))
    return out


def cap(b, rng, p, rt, ztop, k):
    """Cap on the tower top; returns (hub position, cap height)."""
    style = p["cap"]
    thatch = style == "thatch" or not k  # thatch stays muted straw; the kingdom shows on banner + sails
    roof = "thatch" if thatch else kingdom_color(k, "roof")
    roof_d = "thatch_dark" if thatch else kingdom_color(k, "roof_dark")
    trim = kingdom_color(k, "trim") if k else "wood_dark"
    # curb ring
    curb = kingdom_color(k, "roof_dark") if (k and style != "thatch") else "timber"
    b.add(lathe([(rt + 0.45, 0.0), (rt + 0.45, 0.6), (rt - 0.3, 0.6), (rt - 0.3, 0.0)], 14, curb)
          .move(0, 0, ztop), tag="cap")
    z = ztop + 0.6
    if style in ("boat", "thatch"):
        cw, cl, ch = rt * 2 + 0.6, rt * 2 + 1.6, 1.8
        b.add(kit.bbox(cw, cl, ch, "wood", 0.12).move(0, 0.3, z).paint(grad=("range", 0.3, 0.85)), tag="cap")
        for x in (-cw / 2 + 0.2, cw / 2 - 0.2):  # corner posts of the cap frame
            for yy in (-cl / 2 + 0.2, cl / 2 - 0.2):
                b.add(box(0.55, 0.55, ch, "timber").move(x, yy + 0.3, z), tag="cap")
        pitch = 50 if style == "thatch" else 47
        pieces, rise = kit.gable_roof(cw, cl, pitch, overhang=0.8, gable_overhang=0.7, thickness=0.6,
                                      color=roof, rows=4, ridge_color=roof_d,
                                      style="thatch" if style == "thatch" else "tile", rng=rng, pins=False)
        for q in pieces:
            b.add(q.move(0, 0.3, z + ch), tag="roof")
        for sy in (-1, 1):
            g = kit.gable_end(cw, rise, 0.5, "wood_dark")
            b.add(g.move(0, 0.3 + sy * (cl / 2 - 0.25), z + ch).paint(grad=("range", 0.4, 0.85)), tag="cap")
        hub = Vector((0, -cl / 2 - 2.3, z + ch + rise * 0.3))
        cap_h = ch + rise + 0.6
    elif style == "cone":
        b.add(cylinder(rt + 0.3, rt + 0.2, 1.5, 14, "wood").move(0, 0, z).paint(grad=("range", 0.3, 0.85)), tag="cap")
        for q in kit.cone_roof(rt + 0.2, 7.0, 14, roof, overhang=0.6, flare=True, finial="gold", rows=2):
            b.add(q.move(0, 0, z + 1.5), tag="roof")
        b.add(box(1.8, 0.1, 1.1, kingdom_color(k, "cloth")).move(1.05, 0, z + 1.5 + 8.4), tag="flag")
        hub = Vector((0, -rt - 2.6, z + 1.6))
        b.add(kit.bbox(2.0, 2.6, 2.0, "wood_dark", 0.12).move(0, -rt - 0.6, z + 0.6), tag="cap")
        cap_h = 10.5
    else:  # dome
        b.add(cylinder(rt + 0.3, rt + 0.25, 1.4, 14, "wood").move(0, 0, z).paint(grad=("range", 0.3, 0.85)), tag="cap")
        R = rt + 0.55
        dome = lathe([(R, 0.0), (R, 0.45), (R * 0.98, 1.5), (R * 0.86, 2.9), (R * 0.62, 4.1), (R * 0.3, 4.9),
                      (0.0, 5.2)], 14, roof, smooth=True)
        b.add(dome.move(0, 0, z + 1.4).paint(grad=("range", 0.25, 1.0)), tag="roof")
        for zz, rr in ((1.5, R * 0.98), (2.9, R * 0.86)):
            b.add(lathe([(rr + 0.2, zz - 0.35), (rr + 0.2, zz), (rr * 0.9, zz + 0.5)], 14, roof_d)
                  .move(0, 0, z + 1.4), tag="roof")
        b.add(lathe([(0.35, 0.0), (0.6, 0.6), (0.3, 1.1), (0.5, 1.6), (0.0, 2.6)], 7, "gold").move(0, 0, z + 6.4),
              tag="roof")
        b.add(box(1.8, 0.1, 1.1, kingdom_color(k, "cloth")).move(1.0, 0, z + 7.5), tag="flag")
        b.add(cylinder(0.07, 0.07, 1.6, 4, "iron_dark").move(0.1, 0, z + 7.3), tag="flag")
        hub = Vector((0, -R - 2.2, z + 1.8))
        b.add(kit.bbox(2.0, 2.4, 2.0, "wood_dark", 0.12).move(0, -R - 0.4, z + 0.7), tag="cap")
        cap_h = 9.0
    # windshaft from the cap to the hub, tilted up a little
    b.add(kit.oriented_box((0, hub.y + 3.2, hub.z - 0.35), (0, hub.y, hub.z), 0.9, 0.9, "wood_dark",
                           Vector((1, 0, 0))), tag="cap")
    # tail pole with a winding wheel at the back
    pole_top = Vector((0, rt + 0.6, ztop + 0.8))
    foot = Vector((0, rt + 8.5, 2.6))
    b.add(kit.oriented_box(pole_top, foot, 0.55, 0.55, "wood", Vector((1, 0, 0))), tag="tail")
    for sx in (-1, 1):
        b.add(kit.oriented_box((sx * (rt - 0.4), rt - 0.2, ztop + 0.3), foot + Vector((0, -1.8, 1.0)), 0.32, 0.32,
                               "wood_dark", Vector((1, 0, 0))), tag="tail")
    for q in fc.wheel(1.3, 0.3, 6, "wood", "iron_dark", 10, hub_len=0.6):
        b.add(q.move(0, foot.y + 0.3, foot.z - 0.6 + 0.0), tag="tail")
    return hub, cap_h, trim


def gallery(b, rng, r, z, color="wood"):
    """Timber stage around the tower: deck ring, brackets, posts, rail."""
    seg = 14
    w = 2.4
    b.add(lathe([(r - 0.2, 0.0), (r + w, 0.0), (r + w, 0.35), (r - 0.2, 0.35)], seg, color).move(0, 0, z),
          tag="gallery")
    for k in range(seg):
        a = math.tau * (k + 0.5) / seg
        c, s = math.cos(a), math.sin(a)
        b.add(kit.oriented_box((c * (r + w - 0.15), s * (r + w - 0.15), z + 0.35),
                               (c * (r + w - 0.15), s * (r + w - 0.15), z + 3.2), 0.24, 0.24, "timber",
                               Vector((c, s, 0))), tag="gallery")
        if k % 2 == 0 and abs(math.atan2(math.sin(a + math.pi / 2), math.cos(a + math.pi / 2))) > 0.6:
            b.add(kit.oriented_box((c * (r - 0.1), s * (r - 0.1), z - 2.2), (c * (r + w * 0.8), s * (r + w * 0.8), z),
                                   0.28, 0.28, "timber", Vector((-s, c, 0))), tag="gallery")
    rr = r + w - 0.15
    for zz in (z + 1.7, z + 3.15):
        b.add(lathe([(rr + 0.12, 0.0), (rr + 0.12, 0.2), (rr - 0.12, 0.2), (rr - 0.12, 0.0)], seg, "wood_dark")
              .move(0, 0, zz), tag="gallery")


# ------------------------------------------------------------------ build

def sack_pile(b, rng, x0, y0, side=1):
    """Grain sacks stacked by the door (two lying on top) and a banded barrel. Returns sack count."""
    n = 0
    pile = ((0.0, 0.0, 0.0, 0.0), (1.5, 0.35, 0.0, 0.0), (0.6, -1.15, 0.0, 0.0), (2.7, -0.7, 0.0, 0.0),
            (0.8, -0.2, 1.25, 1.35), (2.0, -0.4, 1.2, 1.25))  # x, y, z, lying (rotation about X)
    for dx, dy, dz, lie in pile:
        col = rng.choice(("cloth_brown", "canvas_dark", "apron", "canvas_dark"))
        for q in fc.sack(rng, rng.uniform(1.9, 2.2), col):
            if lie:
                q.move(0, 0, -0.9).rotate(lie, "X").move(0, 0, 0.75)
            b.add(q.rotate(rng.uniform(-0.5, 0.5), "Z").move(x0 + side * dx, y0 + dy, dz), tag="sack")
        n += 1
    barrel = lathe([(0.0, 0.0), (1.0, 0.0), (1.18, 1.0), (1.18, 1.5), (1.0, 2.5), (0.0, 2.5)], 8, "wood")
    bx, by = x0 + side * 4.4, y0 + 1.0
    b.add(barrel.move(bx, by, 0), tag="prop")
    for zz in (0.5, 1.85):
        b.add(cylinder(1.17, 1.17, 0.18, 8, "iron_dark").move(bx, by, zz), tag="prop")
    return n


def banner_on(b, k, x, y, ztop, face_phi, h=5.6, w=2.6):
    """Kingdom banner hanging from a short wall bracket, facing direction face_phi."""
    for q in fc.kingdom_banner(k, h, w):
        b.add(q.move(0, 0, ztop - h - 0.12).rotate(facing(face_phi), "Z").move(x, y, 0), tag="banner")
    for sx in (-1, 1):  # bracket arms back to the wall
        c, s_ = math.cos(face_phi), math.sin(face_phi)
        px, py = x + sx * (w / 2 + 0.2) * -s_, y + sx * (w / 2 + 0.2) * c
        b.add(kit.oriented_box((px - c * 0.9, py - s_ * 0.9, ztop), (px, py, ztop), 0.2, 0.2, "iron_dark",
                               Vector((0, 0, 1))), tag="banner")


def post_mill(b, rng, p, k):
    """Timber post mill: weatherboarded buck (body) turning on a central post carried by a
    trestle of cross-trees and quarter-bars on stone piers; kingdom-gold roof and sails on the
    front, steps and tail pole at the back."""
    roof, roof_d = kingdom_color(k, "roof"), kingdom_color(k, "roof_dark")
    shutter = kingdom_color(k, "shutter")
    # trestle
    for (x, y) in ((4.9, 0.0), (-4.9, 0.0), (0.0, 4.9), (0.0, -4.9)):
        b.add(kit.bbox(1.7, 1.7, 1.3, rng.choice(("stone", "stone_light")), 0.12).move(x, y, 0), tag="trestle")
    b.add(kit.bbox(10.6, 1.0, 0.9, "timber", 0.08).move(0, 0, 1.3), tag="trestle")
    b.add(kit.bbox(1.0, 10.6, 0.9, "timber", 0.08).move(0, 0, 2.2), tag="trestle")
    zb = 9.6
    b.add(kit.bbox(1.4, 1.4, zb - 1.3, "wood_dark", 0.12).move(0, 0, 1.3), tag="trestle")
    for (x, y) in ((4.6, 0.0), (-4.6, 0.0), (0.0, 4.6), (0.0, -4.6)):
        z0 = 2.2 if x else 3.1
        b.add(kit.oriented_box((x, y, z0), (x * 0.12, y * 0.12, 7.0), 0.55, 0.55, "timber",
                               Vector((-y, x, 0)).normalized()), tag="trestle")
    # buck
    BW, BD, BH = 7.4, 9.0, 10.2
    b.add(kit.bbox(BW + 0.5, BD + 0.5, 0.7, "timber", 0.08).move(0, 0, zb), tag="buck")
    b.add(kit.bbox(BW, BD, BH, "wood", 0.1).move(0, 0, zb + 0.7).paint(grad=("range", 0.3, 0.85)), tag="buck")
    rows = 11
    for r in range(rows):  # weatherboards, alternating tones
        z = zb + 0.8 + r * (BH - 0.4) / rows
        col = ("wood_light", "wood")[r % 2]
        for sy in (-1, 1):
            b.add(box(BW + 0.12, 0.12, 0.62, col).move(0, sy * (BD / 2 + 0.03), z), tag="board")
        for sx in (-1, 1):
            b.add(box(0.12, BD + 0.12, 0.62, col).move(sx * (BW / 2 + 0.03), 0, z), tag="board")
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.add(box(0.5, 0.5, BH, "timber").move(sx * (BW / 2 - 0.05), sy * (BD / 2 - 0.05), zb + 0.7), tag="buck")
    ztop = zb + 0.7 + BH
    pieces, rise = kit.gable_roof(BW, BD, 38, overhang=0.7, gable_overhang=0.6, thickness=0.55, color=roof, rows=3,
                                  ridge_color=roof_d, style="tile", rng=rng, trim="timber", pins=False)
    for q in pieces:
        b.add(q.move(0, 0, ztop), tag="roof")
    for sy in (-1, 1):
        b.add(kit.gable_end(BW, rise, 0.4, "wood").move(0, sy * (BD / 2 - 0.2), ztop), tag="buck")
    for sy in (-1, 1):  # gold fascia under the eaves
        b.add(box(BW + 1.2, 0.2, 0.4, roof_d).move(0, sy * (BD / 2 + 0.25), ztop - 0.4), tag="trim")
    for sx in (-1, 1):
        b.add(box(0.2, BD + 0.6, 0.4, roof_d).move(sx * (BW / 2 + 0.25), 0, ztop - 0.4), tag="trim")
    # windows: front-left side and rear-right side
    windows = 0
    for sx, wy in ((-1, -1.8), (1, 2.4)):
        for q in kit.window(1.7, 2.2, "timber", shutter, arched=False):
            b.add(q.rotate(sx * math.pi / 2, "Z").move(sx * (BW / 2 + 0.1), wy, zb + 5.4), tag="window")
        windows += 1
    for q in kit.window(1.6, 1.9, "timber", shutter, arched=False):
        b.add(q.move(-1.9, -BD / 2 - 0.1, zb + 3.2), tag="window")
    windows += 1
    # windshaft + sails on the breast
    hub = Vector((0.8, -BD / 2 - 2.2, zb + BH * 0.84))
    b.add(kit.oriented_box((hub.x, -BD / 2 + 1.0, hub.z - 0.4), (hub.x, hub.y, hub.z), 0.9, 0.9, "wood_dark",
                           Vector((1, 0, 0))), tag="cap")
    for q in sails(rng, p["sails"], p["angle"], 13.4, cloth=kingdom_color(k, "cloth")):
        q.rotate(math.radians(-6), "X")
        b.add(q.move(hub.x, hub.y, hub.z), tag="sail")
    # back: landing, door, steps and tail pole
    b.add(kit.bbox(3.6, 1.8, 0.35, "wood", 0.06).move(0, BD / 2 + 0.9, zb + 0.35), tag="steps")
    for q in kit.door(2.8, 5.2, "wood_dark", None, arched=False, step=None):
        b.add(q.rotate(math.pi, "Z").move(0, BD / 2 + 0.1, zb + 0.7), tag="door")
    foot_y = BD / 2 + 7.4
    for sx in (-1, 1):
        b.add(kit.oriented_box((sx * 1.3, BD / 2 + 1.6, zb + 0.6), (sx * 1.5, foot_y, 0.0), 0.32, 0.32, "wood",
                               Vector((0, 0, 1))), tag="steps")
    for j in range(10):
        t = (j + 0.5) / 10
        yy = BD / 2 + 1.6 + (foot_y - BD / 2 - 1.6) * t
        zz = zb + 0.6 - (zb + 0.6) * t
        b.add(box(2.9, 0.7, 0.18, "wood_light").move(0, yy, zz), tag="steps")
    b.add(kit.oriented_box((-0.6, BD / 2, zb + 0.4), (-2.8, foot_y + 2.6, 1.6), 0.5, 0.5, "timber",
                           Vector((0, 0, 1))), tag="tail")
    for q in fc.wheel(1.1, 0.26, 6, "wood", "iron_dark", 10, hub_len=0.5):
        b.add(q.rotate(0.3, "Z").move(-2.9, foot_y + 2.8, 1.1), tag="tail")
    b.socket("door", 0.0, foot_y + 1.6, 0.0)
    # banner on the right flank, facing the hero camera side
    banner_on(b, k, BW / 2 + 1.05, -1.4, ztop - 0.5, 0.0, h=6.6, w=3.1)
    sacks = sack_pile(b, rng, 3.0, foot_y - 0.4, 1)
    b.socket("deposit", 4.2, foot_y + 1.6, 0.0)
    b.stats["windows"] = windows
    b.stats["sacks"] = sacks
    b.stats["sails"] = 4


def build(b, p):
    rng = b.rng
    k = p["kingdom"]
    if p["tower"] == "post":
        post_mill(b, rng, p, k)
        return
    shutter = kingdom_color(k, "shutter") if k else "wood"
    if p["tower"] == "smock":
        r0, r1, H = 5.6, 3.7, 21.0
    else:
        r0, r1, H = rng.uniform(5.6, 6.1), rng.uniform(3.7, 4.1), rng.uniform(20.5, 22.0)
    z0 = 0.0
    door_z = 0.6
    if p["tower"] == "smock":
        smock_tower(b, rng, p, r0, r1, H, z0)
        door_y = -(r0 + 0.5) * math.cos(math.pi / 8)
    else:
        round_tower(b, rng, p, r0, r1, H, z0, k)
        door_y = -tower_radius(0.5, r0, r1, H) + 0.25
    surround = "stone_light" if p["tower"] != "sand" else "sandstone_light"
    b.add([q.move(0, door_y, door_z) for q in kit.door(kit.DOOR_W, kit.DOOR_H, "wood_dark", surround)], tag="door")
    b.socket("door", 0.0, door_y - 2.2, 0.0)
    # windows climbing round the tower
    windows = 0
    for i, (phi_deg, zf) in enumerate(((-90, 0.62), (-18, 0.36), (-150, 0.8), (40, 0.55))):
        phi = math.radians(phi_deg + rng.uniform(-8, 8))
        zz = H * zf
        if p["tower"] == "smock":
            phi = round(phi / (math.pi / 4)) * (math.pi / 4)
            r = tower_radius(zz, r0, r1, H) * math.cos(math.pi / 8)
        else:
            r = tower_radius(zz, r0, r1, H)
        for q in kit.window(1.9, 2.5, "timber", shutter if i < 3 else None, arched=p["tower"] != "smock"):
            b.add(q.rotate(facing(phi), "Z").move(math.cos(phi) * (r - 0.05), math.sin(phi) * (r - 0.05), zz),
                  tag="window")
        windows += 1
    if p["gallery"]:
        gallery(b, rng, tower_radius(H * 0.45, r0, r1, H), H * 0.45)
    rt = tower_radius(H, r0, r1, H)
    hub, cap_h, trim = cap(b, rng, p, rt, H, k)
    sl = 14.8 if p["tower"] != "smock" else 14.3
    cloth = kingdom_color(k, "cloth") if k else "canvas_dark"
    for q in sails(rng, p["sails"], p["angle"], sl, cloth=cloth):
        q.rotate(math.radians(-8), "X")
        b.add(q.move(hub.x, hub.y, hub.z), tag="sail")
    b.stats["sails"] = 4
    # hoist beam (lucam) with a sack on a rope, sacks + spare millstone at the foot
    side = 1
    hz = H * 0.72
    hr = tower_radius(hz, r0, r1, H)
    ha = math.radians(-35)
    b.add(kit.oriented_box((math.cos(ha) * (hr - 0.4), math.sin(ha) * (hr - 0.4), hz),
                           (math.cos(ha) * (hr + 2.4), math.sin(ha) * (hr + 2.4), hz), 0.45, 0.45, "timber",
                           Vector((0, 0, 1))), tag="hoist")
    hx, hy = math.cos(ha) * (hr + 2.2), math.sin(ha) * (hr + 2.2)
    b.add(box(0.1, 0.1, 4.0, "rope").move(hx, hy, hz - 4.0), tag="hoist")
    b.add([q.move(hx, hy, hz - 5.6) for q in fc.sack(rng, 1.7, "canvas_dark")], tag="hoist")
    sx0 = kit.DOOR_W / 2 + 1.6
    sacks = sack_pile(b, rng, side * sx0, door_y - 1.6, side)
    stone = lathe([(0.55, 0.0), (2.0, 0.0), (2.0, 0.75), (0.55, 0.75)], 12, "stone_light")
    stone.rotate(math.pi / 2, "X").rotate(0.12, "Y").rotate(0.25, "Z").move(-(sx0 + 1.3), door_y - 0.5, 2.0)
    b.add(stone.paint(grad=("range", 0.3, 0.9)), tag="millstone")
    b.socket("deposit", side * (sx0 + 1.2), door_y - 3.2, 0.0)
    # hanging kingdom banner on the front-left of the tower (from the gallery rail when there is one)
    if k:
        phi = math.radians(-60)
        if p["gallery"]:
            zg = H * 0.45
            rr = tower_radius(zg, r0, r1, H) + 2.55
            banner_on(b, k, math.cos(phi) * rr, math.sin(phi) * rr, zg + 0.2, phi, h=5.0, w=2.4)
        else:
            zt = H * 0.52
            if p["tower"] == "smock":
                phi = math.radians(-45)
                rr = tower_radius(zt, r0, r1, H) * math.cos(math.pi / 8) + 1.05
            else:
                rr = tower_radius(zt, r0, r1, H) + 1.05
            banner_on(b, k, math.cos(phi) * rr, math.sin(phi) * rr, zt, phi)
    for j in range(7):  # weeds and flowers hugging the foot of the tower
        a = math.radians(rng.uniform(-60, 230))
        rr = r0 + 0.9
        x, y = math.cos(a) * rr, math.sin(a) * rr
        for q in range(3):
            bl = fc.blade(0.13, rng.uniform(0.7, 1.2), rng.choice(("grass", "grass_dark", "grass_light")))
            b.add(bl.rotate(rng.uniform(0.1, 0.5), "Y").rotate(rng.uniform(0, 6.3), "Z")
                  .move(x + rng.uniform(-0.3, 0.3), y + rng.uniform(-0.3, 0.3), 0), tag="weed")
        if j % 2 == 0:
            b.add(fc.spindle(0.22, 0.35, rng.choice(("flower_red", "flower_yellow", "flower_white")), seg=5)
                  .move(x, y, rng.uniform(0.7, 1.0)), tag="weed")
    b.stats["windows"] = windows
    b.stats["sacks"] = sacks
