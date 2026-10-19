"""Tavern / inn: the biggest timber house in the village. 2-3 jettied storeys of plaster and
timber framing over a stone or framed ground floor, a wide frontage with a gabled entrance porch,
warm glowing ground-floor windows, a hanging tankard sign on a wrought-iron bracket, dormers in a
steep thatch or kingdom-tile roof, an oversized external hearth chimney, outdoor trestle tables
with benches and tankards, barrels, lanterns, optional side wing (cart shed) and bunting.

Front (door) faces Blender -Y. Sockets: door (in front of the porch), sign (sign board centre).
"""

import math

from lib import kit
from lib.geo import Vector, box, lathe
from lib.palette import kingdom_color

from generators import _village_large_common as C

NAME = "building_tavern"
VERSION = 1
CATEGORY = "building"
BUDGET = "building_large"
COLLISION = {"fidelity": "PreciseConvexDecomposition"}
CHECKS = {"min_pieces": 150, "min_windows": 10, "min_roof": 4, "min_tables": 2, "min_dormers": 2,
          "min_lanterns": 2, "has_sign": 1}
DEFAULT_VARIANTS = 6
HERO_VIEW = {"azimuth": 34, "elevation": 18}

# kingdom, storeys, roof, ground, wing, chimney side, dormers, porch (gable porch | pentice over the seating)
_TABLE = (
    ("red", 3, "tile", "stone", False, 1, 3, "gable"),
    ("blue", 2, "thatch", "plaster", True, -1, 2, "gable"),
    ("green", 3, "thatch", "plaster", False, -1, 2, "pentice"),
    ("yellow", 2, "tile", "stone", True, 1, 3, "pentice"),
    ("red", 2, "thatch", "plaster", False, -1, 3, "pentice"),
    ("blue", 3, "tile", "plaster", True, 1, 3, "gable"),
)


def variants(n, seed):
    out = []
    for i in range(n):
        k, storeys, roof, ground, wing, chim, dormers, porch = _TABLE[i % len(_TABLE)]
        out.append({"kingdom": k, "storeys": storeys, "roof": roof, "ground": ground, "wing": wing,
                    "chimney": chim, "dormers": dormers, "porch": porch, "seed": seed * 1000 + 500 + i})
    return out


def _framed_storey(b, rng, Wl, Dl, h, z, shutter, front_wins, side_win=(-1, 1), back_wins=(), glow=False,
                   win_h=kit.WIN_H, sill=2.3, side_y=None, mullion=True):
    """Plaster storey with timber framing on all four faces and windows; returns window count."""
    n = 0
    for wx in front_wins:
        for pc in kit.window(kit.WIN_W, win_h, "timber", shutter, glass="window_glow" if glow else "window_dark",
                             mullion=mullion):
            b.add(pc.move(wx, -Dl / 2, z + sill))
        n += 1
    ops = [(wx, kit.WIN_W / 2 + 0.42) for wx in front_wins]
    posts = C.posts_for(Wl, ops)
    b.add([f.move(0, 0, z) for f in C.frame_wall(Wl, h, "x", -Dl / 2, posts, C.braces_for(posts, ops, rng), rng=rng)])
    for wx in back_wins:
        for pc in kit.window(kit.WIN_W, win_h, "timber", None, mullion=False):
            b.add(pc.rotate(math.pi, "Z").move(wx, Dl / 2, z + sill))
        n += 1
    ops = [(wx, kit.WIN_W / 2 + 0.42) for wx in back_wins]
    posts = C.posts_for(Wl, ops)
    b.add([f.move(0, 0, z) for f in C.frame_wall(Wl, h, "x", Dl / 2, posts, C.braces_for(posts, ops, rng), rng=rng)])
    for sx in (-1, 1):
        sy_ = (side_y or {}).get(sx, 0.0)
        sw = [(sy_, kit.WIN_W / 2 + 0.42)] if sx in side_win else []
        if sx in side_win:
            for pc in kit.window(kit.WIN_W, win_h, "timber", shutter):
                b.add(pc.rotate(sx * math.pi / 2, "Z").move(sx * Wl / 2, sy_, z + sill))
            n += 1
        posts = C.posts_for(Dl, sw)
        b.add([f.move(0, 0, z) for f in C.frame_wall(Dl, h, "y", sx * Wl / 2, posts, C.braces_for(posts, sw, rng), rng=rng)])
    return n


def build(b, p):
    rng = b.rng
    k = p["kingdom"]
    ns = p["storeys"]
    W = rng.uniform(30.5, 32.5) if ns == 3 else rng.uniform(33.0, 35.5)  # X (wide frontage)
    D = rng.uniform(14.2, 15.2)  # Y
    z0 = 1.4
    h1 = rng.uniform(9.8, 10.2)
    hu = [rng.uniform(8.2, 8.6), rng.uniform(7.4, 7.8)][: ns - 1]
    jet = 0.9
    shutter = kingdom_color(k, "shutter")
    plaster = rng.choice(("plaster", "plaster", "plaster_white"))
    cs = p["chimney"]
    windows = 0
    lanterns = 0

    # --- plinth
    e = 0.35
    pts = [(-W / 2 - e, -D / 2 - e, 0), (W / 2 + e, -D / 2 - e, 0), (W / 2 + e, D / 2 + e, 0),
           (-W / 2 - e, D / 2 + e, 0), (-W / 2 - e, -D / 2 - e, 0)]
    b.add(kit.stone_course(pts, z0, 1.0, "stone", rng, block=(4.6, 7.0), bev=0.12,
                           colors=("stone", "stone_light", "stone")))
    b.add(box(W, D, z0, "stone_dark"))

    # --- ground floor (taproom)
    dx = rng.choice((-1, 1)) * rng.uniform(0.0, W * 0.06)
    porch_hw = 4.0
    gw = []
    for off in (6.6, 11.6):
        for s in (-1, 1):
            wx = dx + s * off
            if abs(wx) < W / 2 - 2.6:
                gw.append(wx)
    ground_stone = p["ground"] == "stone"
    if ground_stone:
        st, st_l = kingdom_color(k, "stone"), kingdom_color(k, "stone_light")
        b.add(kit.bbox(W, D, h1, st, 0.2).move(0, 0, z0).paint(grad=("range", 0.2, 0.8)))
        for sx in (-1, 1):
            for sy in (-1, 1):
                b.add(C.quoins(sx * W / 2, sy * D / 2, sx, sy, z0, h1 - 0.4, st_l))
        surround = st_l
    else:
        b.add(kit.bbox(W, D, h1, plaster, 0.2).move(0, 0, z0).paint(grad=("range", 0.35, 0.85)))
        ops = [(wx, kit.WIN_W / 2 + 0.42) for wx in gw] + [(dx, 2.5 + 0.8)]
        posts = C.posts_for(W, ops)
        b.add([f.move(0, 0, z0) for f in C.frame_wall(W, h1, "x", -D / 2, posts, C.braces_for(posts, ops, rng), rng=rng)])
        posts = C.posts_for(W, [(-W * 0.25, 1.72), (W * 0.25, 1.72)])
        b.add([f.move(0, 0, z0) for f in C.frame_wall(W, h1, "x", D / 2, posts,
                                                     C.braces_for(posts, [(-W * 0.25, 1), (W * 0.25, 1)], rng), rng=rng)])
        for sx in (-1, 1):
            posts = C.posts_for(D, [(0.0, 1.72)])
            b.add([f.move(0, 0, z0) for f in C.frame_wall(D, h1, "y", sx * W / 2, posts,
                                                         C.braces_for(posts, [(0.0, 1)], rng), rng=rng)])
        surround = "stone_light"
    for wx in gw:  # warm glowing taproom windows with kingdom shutters
        for pc in kit.window(kit.WIN_W + 0.4, kit.WIN_H, "timber", shutter, glass="window_glow"):
            b.add(pc.move(wx, -D / 2, z0 + kit.SILL_Z - 0.4))
        windows += 1
    for wx in (-W * 0.25, W * 0.25):
        for pc in kit.window(kit.WIN_W, kit.WIN_H, "timber", None, glass="window_glow", mullion=False):
            b.add(pc.rotate(math.pi, "Z").move(wx, D / 2, z0 + kit.SILL_Z - 0.4))
        windows += 1
    if not p["wing"]:
        for pc in kit.window(kit.WIN_W, kit.WIN_H, "timber", shutter, glass="window_glow"):
            b.add(pc.rotate(-cs * math.pi / 2, "Z").move(-cs * W / 2, -D * 0.165, z0 + kit.SILL_Z - 0.4))
        windows += 1

    # wide door in the kingdom colour
    dw, dh = 5.0, 8.0
    for pc in kit.door(dw, dh, shutter, surround, step=None):
        b.add(pc.move(dx, -D / 2, z0))
    b.add([pc.move(dx, -D / 2, 0) for pc in C.stairs(dw + 2.2, z0, 2, 1.2, "stone", rng)])
    b.socket("door", dx, -D / 2 - 6.0, 0)

    pstyle = "thatch" if p["roof"] == "thatch" else "tile"
    pcol = "thatch" if pstyle == "thatch" else kingdom_color(k, "roof")
    pcd = "thatch_dark" if pstyle == "thatch" else kingdom_color(k, "roof_dark")
    pentice = p["porch"] == "pentice"
    if not pentice:
        # gabled entrance porch on two posts, lanterns hanging from it
        py = -D / 2 - 3.6
        pz = z0 + dh + 1.0
        for sx in (-1, 1):
            b.add(kit.bbox(1.0, 1.0, 0.5, "stone", 0.1).move(dx + sx * porch_hw, py, 0))
            b.add(kit.bbox(0.62, 0.62, pz - 0.5, "wood", 0.06).move(dx + sx * porch_hw, py, 0.5))
            b.add(kit.oriented_box((dx + sx * porch_hw, py + 0.3, pz - 2.2),
                                   (dx + sx * (porch_hw - 1.6), py + 0.3, pz), 0.45, 0.45, "wood_dark",
                                   Vector((0, -1, 0))))
        b.add(kit.oriented_box((dx - porch_hw - 0.4, py, pz - 0.25), (dx + porch_hw + 0.4, py, pz - 0.25), 0.6, 0.6,
                               "timber", Vector((0, -1, 0))))
        for sx in (-1, 1):
            b.add(kit.oriented_box((dx + sx * porch_hw, py, pz - 0.25), (dx + sx * porch_hw, -D / 2, pz - 0.25),
                                   0.55, 0.55, "timber", Vector((1, 0, 0))))
        plen = 4.6
        proof, prise = kit.gable_roof(2 * porch_hw + 0.6, plen, 46, overhang=0.9, gable_overhang=0.6,
                                      thickness=0.6, color=pcol, rows=3, ridge_color=pcd, style=pstyle, rng=rng,
                                      pins=False)
        for pc in proof:
            b.add(pc.move(dx, -D / 2 - plen / 2 + 0.5, pz), tag="roof")
        b.add(kit.gable_end(2 * porch_hw + 0.6, prise, 0.4, plaster).move(dx, py - 0.1, pz)
              .paint(grad=("range", 0.5, 0.85)))
        b.add(kit.oriented_box((dx, py - 0.35, pz + 0.2), (dx, py - 0.35, pz + prise - 0.5), 0.5, 0.3, "timber",
                               Vector((0, -1, 0))))
        for sx in (-1, 1):
            b.add([pc.move(dx + sx * (porch_hw - 0.2), py - 0.1, pz - 0.6) for pc in C.lantern()])
            lanterns += 1
    else:
        # pentice: a long lean-to on posts sheltering the whole taproom frontage
        pd = 4.4
        py = -D / 2 - pd + 0.2
        zw = z0 + h1 - 0.45
        zf = z0 + 7.4
        ang = math.atan2(zw - zf, pd)
        posts = [dx - 3.5, dx + 3.5]
        for s_ in (-1, 1):
            u = dx + s_ * 3.5
            while True:
                u += s_ * 5.6
                if abs(u) > W / 2 - 1.6:
                    break
                posts.append(u)
            posts.append(s_ * (W / 2 - 0.9))
        posts = sorted(posts)
        for u in posts:
            b.add(box(0.9, 0.9, 0.45, "stone").move(u, py, 0))
            b.add(box(0.6, 0.6, zf - 0.45, "wood").move(u, py, 0.45))
            for s_ in (-1, 1):
                if (u == posts[0] and s_ < 0) or (u == posts[-1] and s_ > 0):
                    continue
                b.add(kit.oriented_box((u, py, zf - 1.9), (u + s_ * 1.3, py, zf - 0.3), 0.4, 0.4, "wood_dark",
                                       Vector((0, -1, 0))))
        b.add(kit.oriented_box((-W / 2 + 0.5, py, zf - 0.3), (W / 2 - 0.5, py, zf - 0.3), 0.6, 0.6, "timber",
                               Vector((0, -1, 0))))
        sl_len = (pd + 0.9) / math.cos(ang)
        shade = pcol if pstyle == "tile" else "wood_light"
        for r, (off, lift) in enumerate(((0.0, 0.0), (sl_len * 0.48, 0.12))):
            slab = kit.bbox(W - 0.2, sl_len * 0.56, 0.42, shade, 0.1, base=False)
            slab.move(0, -(off + sl_len * 0.28), lift)
            slab.rotate(ang, "X")
            b.add(slab.move(0, -D / 2 + 0.2, zw + 0.25).paint(grad=("range", 0.35 + 0.2 * (1 - r), 0.9)), tag="roof")
        for s_ in (-1, 1):
            b.add([pc.move(dx + s_ * 3.5, py - 0.05, zf - 0.6) for pc in C.lantern()])
            lanterns += 1

    # --- upper storeys (jettied)
    z = z0 + h1
    Wl, Dl = W, D
    for i, h in enumerate(hu):
        Wn, Dn = Wl + 2 * jet, Dl + 2 * jet
        b.add(kit.bbox(Wn + 0.4, Dn + 0.4, 0.7, "timber", 0.1).move(0, 0, z))
        for j in range(9):  # joist ends under the front jetty
            u = -Wl / 2 + 0.6 + (Wl - 1.2) * j / 8
            b.add(box(0.6, jet + 0.4, 0.6, "timber").move(u, -Dl / 2 - jet / 2, z - 0.55))
        z += 0.7
        Wl, Dl = Wn, Dn
        b.add(kit.bbox(Wl, Dl, h, plaster, 0.18).move(0, 0, z).paint(grad=("range", 0.4, 0.85)))
        nw = 4
        fw = [-Wl / 2 + Wl * (j + 0.5) / nw for j in range(nw)]
        windows += _framed_storey(b, rng, Wl, Dl, h, z, shutter, fw, side_win=(-cs,) if i else (-1, 1),
                                  back_wins=(-Wl * 0.25, Wl * 0.25) if i == 0 else (0.0,), glow=(i == 0 and rng.random() < 0.5),
                                  win_h=kit.WIN_H * (1.0 if i == 0 else 0.9), side_y={cs: -Dl * 0.24}, mullion=(i == 0))
        z += h
    top = z

    # --- hanging sign on a bracket from the first upper floor, beside the porch
    sside = 1 if dx <= 0 else -1
    sgx = dx + sside * (porch_hw + 3.6)
    if pentice:  # above the pentice, from the first upper floor
        zs, ys_ = z0 + h1 + 0.7 + 4.6, -D / 2 - jet
    else:  # under the jetty, beside the porch
        zs, ys_ = z0 + h1 - 0.7, -D / 2
    sign, sc = C.hanging_sign(k, 4.6, 4.6, 3.5)
    for pc in sign:
        b.add(pc.move(sgx, ys_, zs))
    b.socket("sign", sgx + sc[0], ys_ + sc[1], zs + sc[2])
    b.stats["sign"] = 1

    # --- roof (ridge along X): steep thatch or kingdom tiles, with dormers
    style = p["roof"]
    pitch = rng.uniform(50, 53) if style == "thatch" else rng.uniform(45, 48)
    color = "thatch" if style == "thatch" else kingdom_color(k, "roof")
    ridge_col = "thatch_dark" if style == "thatch" else kingdom_color(k, "roof_dark")
    roof, rise = kit.gable_roof(Dl, Wl, pitch, overhang=1.5, gable_overhang=1.1, thickness=0.8, color=color,
                                rows=6, ridge_color=ridge_col, style=style, rng=rng)
    for pc in roof:
        b.add(pc.rotate(math.pi / 2, "Z").move(0, 0, top), tag="roof")
    for sx in (-1, 1):
        g = kit.gable_end(Dl, rise, 0.8, plaster)
        b.add(g.rotate(math.pi / 2, "Z").move(sx * (Wl / 2 - 0.4), 0, top).paint(grad=("range", 0.5, 0.85)))
        n = Vector((sx, 0, 0))
        xg = sx * (Wl / 2 + 0.1)
        b.add(kit.oriented_box((xg, -Dl / 2 + 0.5, top + 0.35), (xg, Dl / 2 - 0.5, top + 0.35), kit.TIMBER, 0.4,
                               "timber", n))
        if sx != cs:  # attic window in the gable away from the chimney, flanked by two studs
            for pc in kit.window(2.2, 2.6, "timber", shutter):
                b.add(pc.rotate(sx * math.pi / 2, "Z").move(xg, 0, top + rise * 0.3))
            windows += 1
            for s in (-1, 1):
                b.add(kit.oriented_box((xg, s * 3.3, top + 0.6), (xg, s * 3.3, top + rise * 0.55), kit.TIMBER, 0.4,
                                       "timber", n))
            b.add(kit.oriented_box((xg, 0, top + rise * 0.3 + 3.4), (xg, 0, top + rise - 0.8), kit.TIMBER, 0.4,
                                   "timber", n))
        else:
            b.add(kit.oriented_box((xg, 0, top + 0.6), (xg, 0, top + rise - 0.8), kit.TIMBER, 0.4, "timber", n))
            for s in (-1, 1):
                b.add(kit.oriented_box((xg, s * Dl * 0.36, top + 0.6), (xg, s * 0.4, top + rise * 0.62),
                                       kit.TIMBER * 0.8, 0.4, "timber", n))

    ta = math.tan(math.radians(pitch))
    tt = 0.8 * (1.75 if style == "thatch" else 1.0) / math.cos(math.radians(pitch))
    nd = p["dormers"]
    dxs = [-Wl * 0.3, 0.0, Wl * 0.3] if nd == 3 else [-Wl * 0.22, Wl * 0.22]
    set_back = 1.4
    dwid = 4.2
    dbase = top + set_back * ta + tt - 0.3
    ddepth = Dl / 2 - set_back - 0.6
    dwall = 3.1
    for ux in dxs:
        yd = -Dl / 2 + set_back
        b.add(kit.bbox(dwid, ddepth, dbase + dwall - top + 0.5, plaster, 0.12).move(ux, yd + ddepth / 2, top - 0.5)
              .paint(grad=("range", 0.5, 0.85)))
        for sx in (-1, 1):
            b.add(box(kit.TIMBER, 0.4, dwall + 0.2, "timber").move(ux + sx * (dwid / 2 - kit.TIMBER / 2), yd - 0.1,
                                                                   dbase - 0.2))
        for pc in kit.window(2.0, 2.2, "timber", None, glass="window_glow" if rng.random() < 0.5 else "window_dark"):
            b.add(pc.move(ux, yd, dbase + 0.4))
        windows += 1
        droof, drise = kit.gable_roof(dwid, ddepth, 48, overhang=0.6, gable_overhang=0.5, thickness=0.55,
                                      color=color, rows=1, ridge_color=ridge_col,
                                      style=style if style == "tile" else "thatch", rng=rng, pins=False)
        for pc in droof:
            b.add(pc.move(ux, yd + ddepth / 2, dbase + dwall), tag="roof")
        b.add(kit.gable_end(dwid, drise, 0.4, plaster).move(ux, yd + 0.2, dbase + dwall)
              .paint(grad=("range", 0.5, 0.85)))
    b.stats["dormers"] = nd

    # --- big external hearth chimney on one gable end
    chx = cs * (W / 2 + 1.35)
    base_h = z0 + h1 * 0.85
    b.add(kit.bbox(2.7, 5.4, base_h, "stone", 0.18).move(chx, D * 0.16, 0).paint(grad=("range", 0.2, 0.8)))
    sh = kit.bbox(2.7, 5.4, 1.6, "stone_dark", 0.15).move(chx, D * 0.16, base_h)
    sh.taper(base_h, base_h + 1.6, 1.0, 0.62, center=(chx, D * 0.16))
    b.add(sh)
    flue_top = top + rise + 3.2
    b.add(kit.bbox(2.1, 3.4, flue_top - base_h - 1.2, "stone", 0.15).move(chx, D * 0.16, base_h + 1.2)
          .paint(grad=("range", 0.25, 0.85)))
    for zz in (top - 0.6, top + rise * 0.6):
        b.add(kit.bbox(2.5, 3.8, 0.45, "stone_dark", 0.1).move(chx, D * 0.16, zz))
    b.add(kit.bbox(2.7, 4.0, 0.5, "stone_dark", 0.1).move(chx, D * 0.16, flue_top))
    for dy in (-0.8, 0.8):  # clay pots like the kit chimney
        b.add(lathe([(0.46, 0.0), (0.38, 0.75), (0.46, 1.1), (0.0, 1.1)], 6, "clay").move(chx, D * 0.16 + dy,
                                                                                       flue_top + 0.45))
        b.add(box(0.4, 0.4, 0.08, "black").move(chx, D * 0.16 + dy, flue_top + 1.52))

    # --- side wing: cart shed with a mono-pitch roof (opposite the chimney)
    if p["wing"]:
        ws_ = -cs
        ww, wd, wh = 8.0, D * 0.8, 7.6
        wx = ws_ * (W / 2 + ww / 2)
        wy = D * 0.06
        b.add(kit.bbox(ww, wd, 0.8, "stone_dark", 0.12).move(wx, wy, 0))
        b.add(kit.bbox(ww - 0.6, wd - 0.6, wh - 0.8, plaster, 0.15).move(wx - ws_ * 0.3, wy, 0.8)
              .paint(grad=("range", 0.35, 0.85)))
        fr = C.frame_wall(ww - 0.6, wh - 0.8, "x", wy - wd / 2 + 0.3, C.posts_for(ww - 0.6, [(0.0, 2.6)]), (), rng=rng)
        b.add([f.move(wx - ws_ * 0.3, 0, 0.8) for f in fr])
        arch = kit.door(4.6, 6.0, "wood_dark", None, step=None)
        b.add([pc.move(wx - ws_ * 0.3, wy - wd / 2 + 0.3, 0.8) for pc in arch])
        ang = math.radians(16)
        sl = kit.bbox(ww + 1.6, wd + 1.4, 0.55, color if style == "tile" else "wood_light", 0.12)
        b.add(sl.rotate(ws_ * ang, "Y").move(wx, wy, wh + (ww / 2) * math.tan(ang) * 0.9 - 0.2), tag="roof")
        for j in range(3):  # barrels stacked by the cart shed
            for pc in C.barrel_lying(0.85, 2.2):
                b.add(pc.rotate(math.pi / 2, "Z").move(wx + ws_ * (ww / 2 + 1.6), wy - wd / 2 + 1.2 + j * 2.4, 0))
        for pc in C.barrel_lying(0.85, 2.2):
            b.add(pc.rotate(math.pi / 2, "Z").move(wx + ws_ * (ww / 2 + 1.6), wy - wd / 2 + 2.4, 1.75))

    # --- outdoor seating: two trestle tables with benches and tankards
    tables = 0
    for s in (-1, 1):
        tx = dx + s * (porch_hw + 6.4)
        if abs(tx) > W / 2 + 3:
            tx = s * (W / 2 - 1.0)
        ty = -D / 2 - 7.2
        rot = rng.uniform(-0.12, 0.12)
        grp = C.table(5.0, 2.4) + [pc.move(0, -2.2, 0) for pc in C.bench(5.0)] + \
            [pc.move(0, 2.2, 0) for pc in C.bench(5.0)]
        for j in range(3):
            grp += [pc.move(-1.6 + j * 1.5 + rng.uniform(-0.3, 0.3), rng.uniform(-0.6, 0.6), 3.02)
                    for pc in C.tankard()]
        for pc in grp:
            b.add(pc.rotate(rot, "Z").move(tx, ty, 0))
        tables += 1
    b.stats["tables"] = tables

    # barrels and a crate by the door, an upright barrel used as a standing table
    bx_ = dx - sside * (porch_hw + 1.9)
    b.add([pc.move(bx_, -D / 2 - 1.8, 0) for pc in C.barrel(1.0, 2.5)])
    b.add([pc.move(bx_ + rng.choice((-1, 1)) * 2.4, -D / 2 - 1.6, 0) for pc in C.barrel(0.9, 2.3)])
    b.add([pc.rotate(0.3, "Z").move(bx_, -D / 2 - 4.4, 0) for pc in C.crate(1.8)])
    b.add([pc.move(sgx, -D / 2 - 2.0, 0) for pc in C.barrel(1.0, 2.6, "wood_dark")])
    b.add([pc.move(sgx + 0.2, -D / 2 - 2.0, 2.62) for pc in C.tankard()])

    # bunting from the porch to the sign bracket
    cols = [kingdom_color(k, "cloth"), "cloth_white", kingdom_color(k, "cloth_light")]
    if not pentice:
        b.add(C.bunting((dx - sside * (porch_hw + 0.2), py, pz + 0.2), (-sside * (W / 2 - 0.3), -D / 2 - 0.2, z0 + h1 - 0.3),
                        6, cols, sag=0.8))

    b.stats["windows"] = windows
    b.stats["lanterns"] = lanterns
    b.stats["pieces"] = len(b.pieces)
    b.stats["roof"] = b.count_tag("roof")
