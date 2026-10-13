"""Big barn: gable end to the front (Blender -Y) with huge double doors (9.2 x 10.6 opening,
open on some variants so the hay-filled interior shows), a hayloft door with a hoist beam,
pulley and rope, board-and-batten plank walls in NEUTRAL natural wood or whitewash on an
irregular stone plinth (ART_DIRECTION 3: walls never take the kingdom colour), small shuttered
windows, hay bales, tools and a trough by the door. The kingdom shows on the roof, the door
braces / shutters and a banner.

Massing varies per variant: 01 gambrel roof + cupola, 02 thatch + side lean-to woodshed +
kingdom banner, 03 gold-kingdom tile roof + attached round stone silo with a gold dome,
04 catslide roof sweeping down over a side aisle (wider footprint, aisle door) + cupola.

The walls are separate solid slabs, so the open doorway is a real walkable opening into the
barn (floor at z 0.4). Collision boxes for the walls are emitted for gameplay.
"""

import math

from lib import kit
from lib.geo import Vector, box, cylinder, frustum_box, lathe, prism
from lib.palette import kingdom_color

from generators import _farm_common as fc

NAME = "farm_barn"
VERSION = 2
CATEGORY = "farm"
BUDGET = "building_medium"
COLLISION = {"fidelity": "None"}  # wall/floor boxes below keep the doorway walkable
CHECKS = {"min_battens": 40, "min_windows": 2, "min_roof": 2}
DEFAULT_VARIANTS = 4
HERO_VIEW = {"azimuth": 32, "elevation": 16}
LINEUP_GAP = 6.0

PLANS = [
    {"kingdom": "red", "walls": "wood", "roof": "gambrel", "doors": "open", "loft": "closed", "cupola": True,
     "extra": None},
    {"kingdom": "blue", "walls": "wood_light", "roof": "thatch", "doors": "closed", "loft": "open", "cupola": False,
     "extra": "lean_to"},
    {"kingdom": "yellow", "walls": "whitewash", "roof": "tile", "doors": "half", "loft": "open", "cupola": False,
     "extra": "silo"},
    {"kingdom": "green", "walls": "wood", "roof": "catslide", "doors": "open", "loft": "open", "cupola": True,
     "extra": "aisle"},
]

DW, DH = 9.2, 10.6  # main door opening
T = 0.6  # wall slab thickness


def asset_id(i, params):
    return f"{CATEGORY}_barn_{i + 1:02d}"


def variants(n, seed):
    out = []
    for i in range(n):
        p = dict(PLANS[i % len(PLANS)])
        p["seed"] = seed * 1000 + 700 + i
        out.append(p)
    return out


# ------------------------------------------------------------------ parts

def battens_x(b, rng, x0, x1, y, z0, ztop_fn, color, sgn, pitch=1.25, skip=None):
    """Vertical cover battens on a wall running along X at y (normal sign sgn on Y)."""
    n = 0
    x = x0 + pitch / 2
    while x < x1 - 0.2:
        if skip and skip[0] < x < skip[1]:
            x += pitch
            continue
        zt = ztop_fn(x)
        if zt - z0 > 0.4:
            bt = box(0.26, 0.16, zt - z0, color).move(x + rng.uniform(-0.04, 0.04), y + sgn * 0.08, z0)
            b.add(bt.paint(tint=rng.uniform(0, 1)), tag="batten")
            n += 1
        x += pitch
    return n


def battens_y(b, rng, y0, y1, x, z0, z1, color, sgn, pitch=1.25, skip=()):
    n = 0
    y = y0 + pitch / 2
    while y < y1 - 0.2:
        if any(a < y < c for a, c in skip):
            y += pitch
            continue
        bt = box(0.16, 0.26, z1 - z0, color).move(x + sgn * 0.08, y + rng.uniform(-0.04, 0.04), z0)
        b.add(bt.paint(tint=rng.uniform(0, 1)), tag="batten")
        n += 1
        y += pitch
    return n


def door_leaf(rng, w, h, color, trim):
    """Barn door leaf in local coords: hinge at x=0, leaf along +X, face toward -Y, base z=0.
    Planked leaf with a trim frame and a Z brace."""
    out = [box(w, 0.35, h, color).move(w / 2, 0, 0).paint(grad=("range", 0.3, 0.85))]
    for k in range(int(w / 1.1)):
        u = 0.55 + k * 1.1
        out.append(box(0.18, 0.1, h - 0.4, kingdom_shade(color)).move(u, -0.2, 0.2))
    t = 0.45
    for fy in (-0.26, 0.26):  # trim frame and Z braces on both faces (open leaves show their backs)
        for (cx, cz, sx, sz) in ((t / 2, 0, t, h), (w - t / 2, 0, t, h), (w / 2, 0, w, t), (w / 2, h - t, w, t),
                                 (w / 2, h / 2 - t / 2, w, t)):
            out.append(box(sx, 0.18, sz, trim).move(cx, fy, cz))
        for (za, zb) in ((t, h / 2 - t / 2), (h / 2 + t / 2, h - t)):
            out.append(kit.oriented_box((t, fy, za), (w - t, fy, zb), 0.42, 0.18, trim, Vector((0, -1, 0))))
    for z in (1.2, h - 1.6):
        out.append(box(1.4, 0.12, 0.3, "iron_dark").move(0.75, -0.4, z))
    return out


def kingdom_shade(color):
    """Batten shade one step darker than the wall boards."""
    return {"wood": "wood_dark", "wood_light": "wood", "plaster": "plaster_shadow"}.get(color, "wood_dark")


def cupola(rng, roof, roof_d):
    out = [kit.bbox(2.8, 2.8, 0.5, "timber", 0.08)]
    out.append(box(2.4, 2.4, 2.4, "wood_dark").move(0, 0, 0.5))
    for k in range(4):  # louvres on each face
        a = k * math.pi / 2
        for j in range(4):
            sl = box(1.8, 0.14, 0.32, "wood_pale").rotate(0.5, "X").move(0, -1.24, 0.95 + j * 0.45)
            out.append(sl.rotate(a, "Z"))
        post = box(0.3, 0.3, 2.4, "timber").move(1.2, -1.2, 0.5)
        out.append(post.rotate(a, "Z"))
    out.append(frustum_box(3.6, 3.6, 0.3, 0.3, 2.2, roof).move(0, 0, 2.9).paint(grad=("range", 0.3, 0.95)))
    out.append(cylinder(0.08, 0.08, 2.6, 4, "iron_dark").move(0, 0, 4.9))
    for a in (0.0, math.pi / 2):
        out.append(box(1.4, 0.07, 0.07, "iron_dark").rotate(a, "Z").move(0, 0, 6.2))
    # rooster weathervane
    rooster = prism([(-0.8, 0.0), (0.5, 0.0), (0.9, 0.5), (0.7, 0.9), (0.85, 1.2), (0.45, 1.25), (0.3, 0.55),
                     (-0.4, 0.6), (-0.95, 1.1), (-0.85, 0.35)], 0.08, "iron_dark")
    out.append(rooster.move(0, 0, 6.8))
    return out


def gambrel_roof(W, D, color, ridge, trim, a1=62.0, a2=27.0, frac=0.36, t=0.6, go=1.2, eave=1.1, rows=3):
    """Gambrel roof over walls of width W (X), length D (Y), eaves at z=0: steep lower slopes and
    shallow upper slopes, each laid in stepped tile courses, a ridge cap and barge boards.
    Returns (pieces, (half, xb, rise1, rise2))."""
    out = []
    half = W / 2
    run1 = half * frac
    r1, r2 = math.radians(a1), math.radians(a2)
    rise1 = run1 * math.tan(r1)
    xb = half - run1
    rise2 = xb * math.tan(r2)
    L = D + 2 * go
    for side in (-1, 1):
        for (x0, z0, x1, z1, a, ext) in ((half, 0.0, xb, rise1, r1, eave), (xb, rise1, 0.0, rise1 + rise2, r2, 0.35)):
            # slope line from outer (x0, z0) to inner (x1, z1); extend outwards by `ext`
            dx, dz = x1 - x0, z1 - z0
            ln = math.hypot(dx, dz)
            ux, uz = dx / ln, dz / ln
            ox, oz = x0 - ux * ext, z0 - uz * ext
            tot = ln + ext + (0.25 if a == r1 else 0.0)
            nrm = Vector((side * math.sin(a), 0.0, math.cos(a)))
            for k in range(rows):
                s0, s1 = tot * k / rows - 0.15, tot * (k + 1) / rows + 0.15
                cx = ox + ux * (s0 + s1) / 2
                cz = oz + uz * (s0 + s1) / 2
                lift = t / 2 + 0.06 * k
                c = Vector((side * cx, 0.0, cz)) + nrm * lift
                slab = kit.oriented_box((c.x, -L / 2, c.z), (c.x, L / 2, c.z), s1 - s0, t, color, nrm, bev=0.08)
                slab.grad = ("range", 0.3 + 0.2 * k / rows, 0.9)
                out.append(slab)
    top = rise1 + rise2
    cap = kit.bbox(t * 1.5, L + 0.4, t * 1.5, ridge, 0.12, base=False)
    out.append(cap.rotate(math.radians(45), "Y").move(0, 0, top + t * 0.55))
    for yy in (-L / 2 + 0.2, L / 2 - 0.2):  # barge boards following the outline
        for side in (-1, 1):
            pts = [(side * (half + eave * math.cos(r1) * 0.9), -eave * math.sin(r1) * 0.9 + 0.1),
                   (side * xb, rise1 + 0.35), (0.0, top + 0.3)]
            for (xa, za), (xc, zc) in zip(pts, pts[1:]):
                out.append(kit.oriented_box((xa, yy, za), (xc, yy, zc), 0.5, 0.4, trim, Vector((0, 1, 0))))
    return out, (half, xb, rise1, rise2)


def silo(b, rng, k, x, y, R, H):
    """Round fieldstone silo with iron hoops, a kingdom dome cap + finial, slit windows, a ladder
    and the kingdom banner (gold barn)."""
    seg = 12
    nb = 6
    prof = [(0.0, 0.0)] + [(R * (1.0 - 0.03 * j / nb), H * j / nb) for j in range(nb + 1)] + [(0.0, H)]
    body = lathe(prof, seg, "stone")
    body.face_colors = [("stone_light" if (fi // seg) % 2 else "stone") for fi in range(len(body.faces))]
    body.jitter(rng, 0.05)
    b.add(body.move(x, y, 0).paint(grad=("range", 0.25, 0.9)), tag="silo")
    b.add(lathe([(R + 0.45, 0.0), (R + 0.45, 1.3), (R - 0.2, 1.3), (R - 0.2, 0.0)], seg, "stone_dark").move(x, y, 0),
          tag="silo")
    for zz in (H * 0.38, H * 0.72):
        rr = R * (1.0 - 0.03 * zz / H)
        b.add(lathe([(rr + 0.12, 0.0), (rr + 0.12, 0.3), (rr - 0.1, 0.3), (rr - 0.1, 0.0)], seg, "iron_dark")
              .move(x, y, zz), tag="silo")
    rt = R * 0.97
    dome = lathe([(rt + 0.45, 0.0), (rt + 0.45, 0.35), (rt * 0.96, 1.3), (rt * 0.72, 2.6), (rt * 0.36, 3.5),
                  (0.0, 3.8)], seg, kingdom_color(k, "roof"), smooth=True)
    b.add(dome.move(x, y, H).paint(grad=("range", 0.25, 1.0)), tag="roof")
    b.add(lathe([(0.3, 0.0), (0.55, 0.6), (0.25, 1.0), (0.45, 1.5), (0.0, 2.4)], 6, kingdom_color(k, "roof_dark"))
          .move(x, y, H + 3.7), tag="roof")
    for zz in (H * 0.55, H * 0.85):  # slit windows facing front
        b.add(box(0.5, 0.4, 1.4, "window_dark").move(x - 1.2, y - R + 0.05, zz), tag="silo")
    lx = x + R + 0.15  # ladder up the outer flank
    for sy in (-1, 1):
        b.add(box(0.2, 0.2, H - 0.6, "wood").move(lx, y + sy * 0.7, 0.5), tag="silo")
    for j in range(int((H - 1.5) / 1.4)):
        b.add(box(0.16, 1.6, 0.16, "wood_light").move(lx, y, 1.2 + j * 1.4), tag="silo")
    for q in fc.kingdom_banner(k, 6.2, 2.8):  # gold sun banner on the silo front
        b.add(q.move(x + 0.9, y - R - 0.45, H * 0.58 - 6.3), tag="banner")
    for sx in (-1, 1):
        b.add(box(0.2, 0.7, 0.2, "iron_dark").move(x + 0.9 + sx * 1.6, y - R - 0.2, H * 0.58 - 0.2), tag="banner")


# ------------------------------------------------------------------ build

def build(b, p):
    rng = b.rng
    k = p["kingdom"]
    W = rng.uniform(19.0, 20.5)
    D = rng.uniform(26.0, 29.0)
    Hz = rng.uniform(11.6, 12.4)  # eaves height
    plinth = 1.4
    wall = {"wood": "wood", "wood_light": "wood_light", "whitewash": "plaster"}[p["walls"]]
    trim = "timber"
    bat = kingdom_shade(wall)
    ktrim = kingdom_color(k, "shutter")  # kingdom colour on door braces, loft door, shutters only
    leaf_col = "wood_dark" if wall == "plaster" else wall
    yf, yb = -D / 2, D / 2
    half = W / 2
    extra = p["extra"]
    A = 5.2 if extra == "aisle" else 0.0  # side aisle width (+X)

    # --- floor, plinth
    b.add(kit.bbox(W - 0.2, D - 0.2, 0.4, "wood_dark", 0.08), tag="floor")
    xr = half + A
    pts_l = [(-DW / 2 - 0.9, yf, 0), (-half, yf, 0), (-half, yb, 0), (xr, yb, 0), (xr, yf, 0), (DW / 2 + 0.9, yf, 0)]
    b.add(kit.stone_course(pts_l, plinth, 1.0, "stone", rng, block=(2.0, 3.2), bev=0.0,
                           colors=("stone", "stone_light", "stone_dark")), tag="plinth")
    # --- walls (separate solid slabs so the doorway is a real opening)
    side_x = half - T / 2
    for sx in (-1, 1):
        b.add(kit.bbox(T, D, Hz, wall, 0.1).move(sx * side_x, 0, 0).paint(grad=("range", 0.3, 0.85)), tag="wall")
    b.add(kit.bbox(W - 2 * T, T, Hz, wall, 0.1).move(0, yb - T / 2, 0).paint(grad=("range", 0.3, 0.85)), tag="wall")
    pw = (W - DW) / 2 - T
    for sx in (-1, 1):
        b.add(kit.bbox(pw, T, Hz, wall, 0.1).move(sx * (DW / 2 + pw / 2), yf + T / 2, 0)
              .paint(grad=("range", 0.3, 0.85)), tag="wall")
    b.add(kit.bbox(DW + 0.2, T, Hz - DH, wall, 0.06).move(0, yf + T / 2, DH).paint(grad=("range", 0.3, 0.85)),
          tag="wall")
    b.add(box(W - 2 * T - 0.4, 0.2, Hz, "wood").move(0, yb - T - 0.1, 0), tag="lining")
    for sx in (-1, 1):
        b.add(box(0.2, D - 2 * T, Hz, "wood").move(sx * (side_x - T / 2 - 0.1), 0, 0), tag="lining")
    # --- roof + gables
    style = p["roof"]
    roof_c, ridge_c = kingdom_color(k, "roof"), kingdom_color(k, "roof_dark")
    if style == "gambrel":
        roof, (_, xb, rise1, rise2) = gambrel_roof(W, D, roof_c, ridge_c, trim)
        rise = rise1 + rise2
        a1, a2 = math.radians(62.0), math.radians(27.0)

        def roof_z(x):
            ax = abs(x)
            return (half - ax) * math.tan(a1) if ax >= xb else rise1 + (xb - ax) * math.tan(a2)

        gpoly = [(-half, 0.0), (half, 0.0), (xb, rise1), (0.0, rise), (-xb, rise1)]
    else:
        pitch = 50.0 if style == "catslide" else rng.uniform(52, 56)
        color = "thatch" if style == "thatch" else roof_c
        rc = "thatch_dark" if style == "thatch" else ridge_c
        ext = None
        if style == "catslide":
            ext = (1, (A + 0.9 - 1.4) / math.cos(math.radians(pitch)))
        roof, rise = kit.gable_roof(W, D, pitch, overhang=1.4, gable_overhang=1.3, thickness=0.75, color=color,
                                    rows=6, ridge_color=rc, style="thatch" if style == "thatch" else "tile", rng=rng,
                                    pins=False, extend=ext)
        ta = math.tan(math.radians(pitch))

        def roof_z(x):
            return max(0.0, rise - abs(x) * ta)

        gpoly = [(-half, 0.0), (half, 0.0), (0.0, rise)]
    for q in roof:
        b.add(q.move(0, 0, Hz), tag="roof")
    for yy in (yf + T / 2, yb - T / 2):
        g = prism(gpoly, T, wall, axis="Y")
        b.add(g.move(0, yy, Hz).paint(grad=("range", 0.4, 0.9)), tag="wall")

    def gable_top(x):
        return Hz + roof_z(x) - 0.25

    # --- battens: front (around the door, up the gable), back, sides
    nb = 0
    x = -half + 0.62
    while x < half - 0.3:
        z0 = plinth if abs(x) > DW / 2 + 0.3 else DH + 0.6
        zt = gable_top(x)
        if abs(x) < 2.6 and zt > Hz + 1.2:
            zt_lo = Hz + 1.0
            if zt_lo - z0 > 0.4:
                b.add(box(0.26, 0.16, zt_lo - z0, bat).move(x, yf - 0.08, z0), tag="batten")
                nb += 1
            z0 = Hz + 6.4
        if zt - z0 > 0.4:
            b.add(box(0.26, 0.16, zt - z0, bat).move(x + rng.uniform(-0.04, 0.04), yf - 0.08, z0)
                  .paint(tint=rng.uniform(0, 1)), tag="batten")
            nb += 1
        x += 1.25
    nb += battens_x(b, rng, -half, half, yb, plinth, gable_top, bat, 1)
    win_y = (-D * 0.22, D * 0.22)
    for sx in ((-1,) if A else (-1, 1)):
        nb += battens_y(b, rng, yf, yb, sx * half, plinth, Hz - 0.2, bat, sx,
                        skip=tuple((wy - 2.0, wy + 2.0) for wy in win_y))
    # corner + door trim (timber), door frame in the kingdom colour
    for sx in (-1, 1):
        for yy in (yf, yb):
            sy = -1 if yy < 0 else 1
            if sx > 0 and A:
                continue
            b.add(box(0.7, 0.2, Hz - plinth, trim).move(sx * (half - 0.35), yy + sy * 0.1, plinth), tag="trim")
            b.add(box(0.2, 0.7, Hz - plinth, trim).move(sx * (half + 0.1), yy - sy * 0.35, plinth), tag="trim")
        b.add(box(0.6, 0.3, DH + 0.6, ktrim).move(sx * (DW / 2 + 0.3), yf - 0.15, 0), tag="trim")
    b.add(box(DW + 1.2, 0.3, 0.6, ktrim).move(0, yf - 0.15, DH), tag="trim")
    b.add(box(W + 0.3, 0.3, 0.45, trim).move(0, yf - 0.15, Hz - 0.45), tag="trim")
    # --- main doors (planks in the wall wood, braces in the kingdom colour)
    lw = DW / 2
    mode = p["doors"]
    angles = {"open": (math.radians(165), math.radians(160)), "closed": (0.0, 0.0),
              "half": (math.radians(150), math.radians(8))}[mode]
    for s, ang in zip((-1, 1), angles):
        for q in door_leaf(rng, lw - 0.05, DH - 0.2, leaf_col, ktrim):
            if s > 0:
                q.scale(-1, 1, 1)  # mirror: leaf extends -X from the right jamb
            q.rotate(s * ang, "Z").move(s * DW / 2, yf - 0.25, 0.2)  # mirrored winding: finalize recalcs normals
            b.add(q, tag="door")
    b.add(kit.bbox(DW + 0.6, 2.2, 0.35, "wood_dark", 0.08).move(0, yf - 1.0, 0), tag="floor")
    b.socket("door", 0.0, yf - 3.0, 0.0)
    # interior hay (seen through open doors) + hayloft floor
    if mode != "closed":
        b.add(kit.bbox(W - 2 * T - 0.4, D * 0.45, 0.4, "wood", 0.06).move(0, yb - D * 0.225 - T, Hz - 1.2),
              tag="loft")
        prof = [(0.0, 0.0), (5.0, 0.0), (5.4, 0.8), (4.3, 2.4), (2.2, 3.4), (0.0, 3.7)]
        b.add(fc.hay_mound(rng, prof, 12, "hay", 0.35, 0.7, sx=1.5, sy=0.55,
                           bands=("hay_dark", "hay", "thatch", "hay", "straw")).move(0, yb - 4.2, Hz - 0.8), tag="hay")
        b.add(fc.hay_mound(rng, [(0.0, 0.0), (3.4, 0.0), (3.2, 1.0), (1.8, 2.4), (0.0, 2.8)], 10, "hay", 0.3, 0.8,
                           sx=1.3).move(-3.0, yb - 6.0, 0.4), tag="hay")
        spill = [(0.0, 0.0), (3.2, 0.0), (3.0, 0.5), (1.8, 1.3), (0.0, 1.6)]
        b.add(fc.hay_mound(rng, spill, 10, "hay", 0.25, 0.9, sx=1.2, sy=0.8,
                           bands=("hay_dark", "hay", "straw", "straw")).move(-1.2, yf + 1.6, 0.35), tag="hay")
        b.add([q.move(-1.2, yf + 1.6, 0.35) for q in fc.straw_tufts(rng, spill, 12, sx=1.2, sy=0.8)], tag="tuft")
        for (x, y, z, rot) in ((2.6, yf + 3.0, 0.4, 0.1), (2.7, yf + 4.7, 0.4, -0.05), (2.5, yf + 3.9, 1.75, 0.2)):
            b.add([q.rotate(rot + math.pi / 2, "Z").move(x, y, z) for q in fc.square_bale(rng)], tag="hay")
    # --- hayloft door + hoist
    lz = Hz + 1.0
    lwid, lh = 4.0, 5.0
    b.add(box(lwid + 1.0, 0.3, 0.5, trim).move(0, yf - 0.2, lz - 0.5), tag="trim")
    b.add(box(lwid + 1.0, 0.3, 0.45, trim).move(0, yf - 0.2, lz + lh), tag="trim")
    for sx in (-1, 1):
        b.add(box(0.5, 0.3, lh, trim).move(sx * (lwid / 2 + 0.25), yf - 0.2, lz), tag="trim")
    if p["loft"] == "open":
        b.add(box(lwid, 0.2, lh, "black").move(0, yf - 0.05, lz), tag="loft_door")
        b.add(fc.hay_mound(rng, [(0.0, 0.0), (1.9, 0.0), (1.6, 0.8), (0.0, 1.3)], 8, "hay", 0.18, 1.0,
                           sx=1.0, sy=0.6).move(0, yf - 0.1, lz), tag="hay")
        for s in (-1, 1):  # leaves swung out ~100 degrees
            lf = box(lwid / 2, 0.25, lh, leaf_col).move(lwid / 4, 0, 0)
            if s > 0:
                lf.scale(-1, 1, 1)
            b.add(lf.rotate(s * math.radians(100), "Z").move(s * lwid / 2, yf - 0.3, lz), tag="loft_door")
    else:
        for s in (-1, 1):
            b.add(box(lwid / 2 - 0.05, 0.25, lh, leaf_col).move(s * lwid / 4, yf - 0.25, lz), tag="loft_door")
        b.add(kit.oriented_box((-lwid / 2 + 0.3, yf - 0.42, lz + 0.3), (lwid / 2 - 0.3, yf - 0.42, lz + lh - 0.3),
                               0.4, 0.15, ktrim, Vector((0, -1, 0))), tag="loft_door")
    hz = lz + lh + 1.6
    b.add(kit.oriented_box((0, yf + 1.5, hz), (0, yf - 3.6, hz), 0.6, 0.6, "timber", Vector((0, 0, 1))), tag="hoist")
    b.add(cylinder(0.45, 0.45, 0.35, 8, "iron_dark").move(0, 0, -0.175).rotate(math.pi / 2, "Y")
          .move(0, yf - 3.2, hz - 0.55), tag="hoist")
    rope_len = 5.5 if p["loft"] == "open" else 3.0
    b.add(box(0.1, 0.1, rope_len, "rope").move(0, yf - 3.2, hz - 0.7 - rope_len), tag="hoist")
    b.add(box(0.14, 0.5, 0.14, "iron_dark").move(0, yf - 3.2, hz - 0.8 - rope_len), tag="hoist")
    if p["loft"] == "open":
        bale = fc.square_bale(rng, 2.6, 1.4, 1.2)
        b.add([q.rotate(0.3, "Z").move(0, yf - 3.2, hz - 2.25 - rope_len) for q in bale], tag="hay")
    # --- side windows (kingdom shutters)
    windows = 0
    for sx in ((-1,) if A else (-1, 1)):
        for wy in win_y:
            for q in kit.window(2.2, 2.8, "timber", ktrim, mullion=True):
                b.add(q.rotate(sx * math.pi / 2, "Z").move(sx * half, wy, 5.0), tag="window")
            windows += 1
    # --- cupola on the ridge
    if p["cupola"]:
        for q in cupola(rng, roof_c, ridge_c):
            b.add(q.move(0, rng.uniform(-1, 1), Hz + rise + 0.2), tag="cupola")
    # --- massing extras
    if extra == "aisle":  # catslide side aisle on +X, its own small door at the front
        ta = math.tan(math.radians(50.0))
        ha = Hz - A * ta
        b.add(kit.bbox(T, D, ha, wall, 0.1).move(xr - T / 2, 0, 0).paint(grad=("range", 0.3, 0.85)), tag="wall")
        for yy in (yf + T / 2, yb - T / 2):
            ep = prism([(half, 0.0), (xr, 0.0), (xr, ha), (half, Hz)], T, wall, axis="Y")
            b.add(ep.move(0, yy, 0).paint(grad=("range", 0.3, 0.85)), tag="wall")
        nb += battens_x(b, rng, half, xr, yf, plinth, lambda xx: Hz - (xx - half) * ta - 0.3, bat, -1,
                        skip=(half + A / 2 - 2.2, half + A / 2 + 2.2))
        nb += battens_x(b, rng, half, xr, yb, plinth, lambda xx: Hz - (xx - half) * ta - 0.3, bat, 1)
        aw_y = (-D * 0.2, D * 0.25)
        nb += battens_y(b, rng, yf, yb, xr, plinth, ha - 0.2, bat, 1, skip=tuple((wy - 1.9, wy + 1.9) for wy in aw_y))
        for wy in aw_y:
            for q in kit.window(2.0, 2.3, "timber", ktrim, mullion=True):
                b.add(q.rotate(math.pi / 2, "Z").move(xr, wy, 2.3), tag="window")
            windows += 1
        for q in kit.door(3.2, 4.8, "wood_dark", "stone_light", arched=True, step="stone"):
            b.add(q.move(half + A / 2, yf, 0.0), tag="door")
        for yy in (yf, yb):
            sy = -1 if yy < 0 else 1
            b.add(box(0.7, 0.2, ha - plinth, trim).move(xr - 0.35, yy + sy * 0.1, plinth), tag="trim")
            b.add(box(0.2, 0.7, ha - plinth, trim).move(xr + 0.1, yy - sy * 0.35, plinth), tag="trim")
        b.collision_box(xr - T / 2, 0, ha / 2, T, D, ha, "aisle_wall")
    elif extra == "lean_to":  # open woodshed on +X with a mono-pitch roof and a log stack
        lw2, ld, lh2 = 6.0, D * 0.55, 7.2
        lx = half + lw2 / 2
        b.add(kit.bbox(lw2, ld, 0.5, "stone_dark", 0.1).move(lx, D * 0.1, 0), tag="shed")
        for yy in (D * 0.1 - ld / 2 + 0.4, D * 0.1, D * 0.1 + ld / 2 - 0.4):
            b.add(kit.bbox(0.6, 0.6, lh2, "timber", 0.06).move(lx + (lw2 / 2 - 0.4), yy, 0.5), tag="shed")
        a = math.radians(20)
        sl = kit.bbox(lw2 + 1.6, ld + 1.2, 0.5, "wood_dark", 0.1)
        b.add(sl.rotate(a, "Y").move(lx, D * 0.1, lh2 + 0.5 + (lw2 / 2) * math.tan(a) - 0.2), tag="roof")
        for row in range(3):
            for j in range(5 - row):
                px = lx - 0.3 - 2.0 + j * 1.05 + row * 0.5
                pz = 0.5 + 0.55 + row * 0.95
                b.add(cylinder(0.55, 0.55, ld * 0.8, 7, "bark").rotate(math.pi / 2, "X").move(px, D * 0.1 + ld * 0.4, pz),
                      tag="logs")
                b.add(cylinder(0.42, 0.42, 0.1, 7, "wood_pale").rotate(math.pi / 2, "X")
                      .move(px, D * 0.1 - ld * 0.4 + 0.02, pz), tag="logs")
        b.collision_box(lx, D * 0.1, 3.0, lw2, ld, 6.0, "lean_to")
    elif extra == "silo":
        R, Hs = 3.6, Hz + 9.0
        sx_, sy_ = half + R - 0.4, yb - R - 2.2
        silo(b, rng, k, sx_, sy_, R, Hs)
        b.collision_box(sx_, sy_, Hs / 2, 2 * R, 2 * R, Hs, "silo")
    if k and style == "thatch":  # thatch carries its kingdom on a big banner beside the doors
        bxn = DW / 2 + 0.6 + pw / 2
        for q in fc.kingdom_banner(k, 6.2, 2.6):
            b.add(q.move(bxn, yf - 0.6, Hz - 0.8 - 6.4), tag="banner")
        for sx in (-1, 1):
            b.add(box(0.2, 0.6, 0.2, "iron_dark").move(bxn + sx * 1.6, yf - 0.4, Hz - 1.0), tag="banner")
    b.stats["battens"] = nb
    b.stats["windows"] = windows
    # --- props by the door: bales, trough, cart wheel, lantern, pitchfork
    bx = DW / 2 + 3.2
    for (dx, dy, dz, rot) in ((0.0, -2.2, 0.0, 0.05), (0.2, -4.0, 0.0, -0.08), (0.1, -3.1, 1.32, 0.2)):
        b.add([q.rotate(rot, "Z").move(bx + dx, yf + dy, dz) for q in fc.square_bale(rng)], tag="prop")
    b.add(kit.bbox(3.6, 1.4, 1.1, "wood", 0.1).move(-bx - 0.5, yf - 2.2, 0), tag="prop")
    b.add(box(3.2, 1.0, 0.1, "water").move(-bx - 0.5, yf - 2.2, 0.95), tag="prop")
    for q in fc.wheel(1.6, 0.3, 6, "wood", "iron_dark", 12, hub_len=0.6):
        b.add(q.rotate(-0.25, "X").move(-half - 0.45, yf + 4.0, 1.55), tag="prop")
    b.socket("deposit", bx - 1.4, yf - 3.0, 0.0)
    lan_x = -(DW / 2 + 0.3)
    b.add(box(0.12, 0.9, 0.12, "iron_dark").move(lan_x, yf - 0.6, DH - 1.2), tag="prop")
    b.add(frustum_box(0.6, 0.6, 0.45, 0.45, 0.8, "window_glow").move(lan_x, yf - 1.0, DH - 2.0), tag="prop")
    b.add(frustum_box(0.75, 0.75, 0.2, 0.2, 0.35, "iron_dark").move(lan_x, yf - 1.0, DH - 1.2), tag="prop")
    b.add(box(0.7, 0.7, 0.12, "iron_dark").move(lan_x, yf - 1.0, DH - 2.1), tag="prop")
    b.add([q.rotate(-0.3, "X").rotate(0.2, "Z").move(bx + 2.2, yf - 1.2, 0) for q in fc.pitchfork(6.0)], tag="prop")
    b.stats["roof"] = b.count_tag("roof")
    # collision boxes for the hollow shell (walls only; the doorway stays open)
    b.collision_box(-side_x, 0, Hz / 2, T, D, Hz, "wall_left")
    b.collision_box(side_x, 0, Hz / 2, T, D, Hz, "wall_right")
    b.collision_box(0, yb - T / 2, Hz / 2, W, T, Hz, "wall_back")
    for sx in (-1, 1):
        b.collision_box(sx * (DW / 2 + pw / 2), yf + T / 2, Hz / 2, pw, T, Hz, f"front_{'l' if sx < 0 else 'r'}")
    b.collision_box(0, yf + T / 2, (Hz + DH) / 2, DW, T, Hz - DH, "front_header")
    b.collision_box(0, 0, 0.2, W, D, 0.4, "floor")
    b.collision_box(bx, yf - 3.1, 1.35, 3.4, 3.6, 2.7, "bales")
