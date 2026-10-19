"""Carpenter's / lumber workshop: an open-sided timber work shed on stone pads (shingle or kingdom
tile roof, exposed truss on the open gable) with a plank tool wall, joiner's bench, a log on two
sawhorses with a crosscut saw half-way through, sawdust; sawn-plank stacks and a log pile in the
yard; a timber jib crane or a treadwheel crane lifting a log; and a small attached house (plaster
and timber or kingdom stone) with a kingdom-coloured door and shutters.

Front faces Blender -Y. Sockets: interact (work position at the sawhorses), deposit (lumber drop
in front of the plank stacks).
"""

import math

from lib import kit
from lib.geo import Vector, box, cylinder, lathe
from lib.palette import kingdom_color

from generators import _village_large_common as C

NAME = "building_workshop"
VERSION = 1
CATEGORY = "building"
BUDGET = "building_medium"
COLLISION = {"fidelity": "PreciseConvexDecomposition"}
CHECKS = {"min_pieces": 120, "min_windows": 2, "min_roof": 4, "min_plank_stacks": 1, "has_crane": 1,
          "min_sawhorses": 2}
DEFAULT_VARIANTS = 6
HERO_VIEW = {"azimuth": 34, "elevation": 22}

# kingdom, house side (+1 = +X), crane, house roof, shed roof, house ground, shed bays, house storeys
_TABLE = (
    ("red", 1, "treadwheel", "thatch", "tile", "plaster", 2, 1),
    ("blue", -1, "jib", "tile", "shingle", "stone", 2, 2),
    ("green", 1, "jib", "thatch", "shingle", "plaster", 3, 1),
    ("yellow", -1, "treadwheel", "thatch", "tile", "stone", 3, 1),
    ("red", -1, "jib", "thatch", "shingle", "plaster", 3, 2),
    ("blue", 1, "treadwheel", "tile", "tile", "stone", 2, 2),
)


def variants(n, seed):
    out = []
    for i in range(n):
        k, hs, crane, hroof, sroof, ground, bays, storeys = _TABLE[i % len(_TABLE)]
        out.append({"kingdom": k, "house_side": hs, "crane": crane, "house_roof": hroof, "shed_roof": sroof,
                    "house_ground": ground, "bays": bays, "storeys": storeys, "seed": seed * 1000 + 700 + i})
    return out


def build(b, p):
    rng = b.rng
    k = p["kingdom"]
    hs = p["house_side"]
    os_ = -hs  # open side of the shed (crane side)
    shutter = kingdom_color(k, "shutter")
    plaster = rng.choice(("plaster", "plaster", "plaster_white"))
    windows = 0

    # ------------------------------------------------ open work shed
    nbays = p["bays"]
    bay = rng.uniform(7.2, 7.8)
    Ws = nbays * bay + 0.9  # X
    Ds = rng.uniform(11.5, 12.5)  # Y
    Hs = rng.uniform(9.8, 10.3)  # top of posts
    b.add(C.pad(Ws / 2 + 5.0, Ds / 2 + 4.0, 20, rng, color="dirt_light").move(-hs * 4.0, -3.0, 0))
    xo = os_ * (Ws / 2 - 0.45)  # open-end post line
    post_x = [xo - os_ * i * bay for i in range(nbays)]
    ny = Vector((0, -1, 0))
    for x in post_x:
        for sy in (-1, 1):
            y = sy * (Ds / 2 - 0.45)
            b.add(box(1.3, 1.3, 0.6, "stone").move(x, y, 0))
            b.add(kit.bbox(0.85, 0.85, Hs - 0.6, "wood", 0.08).move(x, y, 0.6).paint(grad=("range", 0.3, 0.85)))
            for s_ in (-1, 1):  # knee braces to the plates
                if x == xo and s_ == os_:
                    continue
                b.add(kit.oriented_box((x, y, Hs - 2.6), (x + s_ * 1.9, y, Hs - 0.7), 0.42, 0.42, "wood_dark", ny))
    hw = hs * Ws / 2  # house wall line
    for sy in (-1, 1):  # wall plates along X
        y = sy * (Ds / 2 - 0.45)
        b.add(kit.oriented_box((xo - os_ * 0.0 + os_ * 0.5, y, Hs - 0.35), (hw, y, Hs - 0.35), 0.75, 0.75, "timber", ny))
    for x in post_x:  # tie beams along Y
        b.add(kit.oriented_box((x, -Ds / 2 + 0.2, Hs - 0.35), (x, Ds / 2 - 0.2, Hs - 0.35), 0.7, 0.7, "timber",
                               Vector((1, 0, 0))))
    # roof (ridge along X), overhanging the open end
    pitch = rng.uniform(33, 37)
    scol = kingdom_color(k, "roof") if p["shed_roof"] == "tile" else "wood_light"
    sridge = kingdom_color(k, "roof_dark") if p["shed_roof"] == "tile" else "wood"
    sroof, srise = kit.gable_roof(Ds, Ws, pitch, overhang=0.9, gable_overhang=1.0, thickness=0.65, color=scol,
                                  rows=4, ridge_color=sridge, style="tile", rng=rng)
    for pc in sroof:
        b.add(pc.rotate(math.pi / 2, "Z").move(os_ * 0.6, 0, Hs), tag="roof")
    # exposed truss on the open gable and over the first inner tie beam
    for x in post_x[:2]:
        nx = Vector((1, 0, 0))
        b.add(kit.oriented_box((x, 0, Hs), (x, 0, Hs + srise - 0.5), 0.5, 0.5, "timber", nx))
        for sy in (-1, 1):
            b.add(kit.oriented_box((x, sy * (Ds / 2 - 0.6), Hs), (x, 0, Hs + srise - 0.3), 0.5, 0.5, "timber", nx))
            b.add(kit.oriented_box((x, sy * 0.3, Hs + 0.2), (x, sy * Ds * 0.22, Hs + srise * 0.5), 0.36, 0.36,
                                   "wood_dark", nx))
    # tool wall: vertical boards between the back posts, tools hung on it, bench in front
    yb = Ds / 2 - 0.45
    x0, x1 = sorted((xo, hw))
    nb = int((x1 - x0) // 1.15)
    bw_ = (x1 - x0) / nb
    for i in range(nb):
        bd = box(bw_ - 0.06, 0.36, Hs - 0.7, "wood").move(x0 + bw_ * (i + 0.5), yb + 0.05, 0.0)
        b.add(bd.paint(tint=rng.uniform(0.1, 0.9), grad=("range", 0.25, 0.8)))
    b.add(box(x1 - x0, 0.3, 0.35, "wood_dark").move((x0 + x1) / 2, yb - 0.2, 2.2))
    tx = (xo + hw) / 2 + hs * 1.0
    b.add([pc.move(tx, yb - 0.15, 0) for pc in C.tool_wall_tools(rng, 7.5)])
    b.add([pc.move(tx - hs * 0.6, yb - 0.15, 0) for pc in C.workbench(rng, 6.2)])
    # the job on the floor: a log on two sawhorses with a crosscut saw, sawdust
    lx = xo - os_ * bay * 0.55
    ly = -Ds / 2 - 3.4
    b.add([pc.rotate(rng.uniform(-0.08, 0.08), "Z").move(lx, ly, 0) for pc in C.log_being_sawn(rng, 7.6, 0.75)])
    b.stats["sawhorses"] = 2
    b.socket("interact", lx, ly - 3.6, 0)

    # ------------------------------------------------ attached house (ridge along X, gable wall to the shed)
    Wh = rng.uniform(10.0, 11.0)
    Dh = rng.uniform(11.0, 12.0)
    z0 = 1.2
    hh = rng.uniform(9.6, 10.2)
    hx = hs * (Ws / 2 + Wh / 2)
    hy = 0.0
    e = 0.3
    pts = [(hx - Wh / 2 - e, hy - Dh / 2 - e, 0), (hx + Wh / 2 + e, hy - Dh / 2 - e, 0),
           (hx + Wh / 2 + e, hy + Dh / 2 + e, 0), (hx - Wh / 2 - e, hy + Dh / 2 + e, 0),
           (hx - Wh / 2 - e, hy - Dh / 2 - e, 0)]
    b.add(kit.stone_course(pts, z0, 0.9, "stone", rng, block=(3.2, 4.8), bev=0.1,
                           colors=("stone", "stone_light", "stone")))
    b.add(box(Wh, Dh, z0, "stone_dark").move(hx, hy, 0))
    stone_ground = p["house_ground"] == "stone"
    dxh = hx + os_ * Wh * 0.18  # door towards the shed
    wxh = hx - os_ * Wh * 0.24
    if stone_ground:
        st, st_l = kingdom_color(k, "stone"), kingdom_color(k, "stone_light")
        b.add(kit.bbox(Wh, Dh, hh, st, 0.2).move(hx, hy, z0).paint(grad=("range", 0.2, 0.8)))
        for sy in (-1, 1):
            b.add(C.quoins(hx + hs * Wh / 2, hy + sy * Dh / 2, hs, sy, z0, hh - 0.4, st_l))
        surround = st_l
    else:
        b.add(kit.bbox(Wh, Dh, hh, plaster, 0.18).move(hx, hy, z0).paint(grad=("range", 0.35, 0.85)))
        ops = [(dxh - hx, 2.2 + 0.8), (wxh - hx, 1.72)]
        posts = C.posts_for(Wh, ops)
        b.add([f.move(hx, 0, z0) for f in C.frame_wall(Wh, hh, "x", hy - Dh / 2, posts, C.braces_for(posts, ops, rng), rng=rng)])
        posts = C.posts_for(Dh, [(0.0, 1.72)])
        b.add([f.move(0, 0, z0) for f in C.frame_wall(Dh, hh, "y", hx + hs * Wh / 2, posts,
                                                     C.braces_for(posts, [(0.0, 1.72)], rng), rng=rng)])
        surround = "stone_light"
    for pc in kit.door(kit.DOOR_W, kit.DOOR_H, shutter, surround, step="stone"):
        b.add(pc.move(dxh, hy - Dh / 2, z0))
    for pc in kit.window(kit.WIN_W, kit.WIN_H, "timber", shutter):
        b.add(pc.move(wxh, hy - Dh / 2, z0 + kit.SILL_Z))
    windows += 1
    for pc in kit.window(kit.WIN_W, kit.WIN_H, "timber", shutter):
        b.add(pc.rotate(hs * math.pi / 2, "Z").move(hx + hs * Wh / 2, hy, z0 + kit.SILL_Z))
    windows += 1
    for pc in kit.window(kit.WIN_W, kit.WIN_H, "timber", None, mullion=False):
        b.add(pc.rotate(math.pi, "Z").move(hx, hy + Dh / 2, z0 + kit.SILL_Z))
    windows += 1
    b.add(kit.bbox(4.0, 1.0, 0.9, "wood", 0.1).move(wxh, hy - Dh / 2 - 1.0, z0 + kit.SILL_Z - 1.35))
    b.add(kit.bbox(3.7, 0.8, 0.5, "leaf_mid", 0.15).move(wxh, hy - Dh / 2 - 1.0, z0 + kit.SILL_Z - 0.5))
    for j in range(5):
        fl = lathe([(0.0, 0.0), (0.42, 0.2), (0.4, 0.55), (0.0, 0.75)], 5,
                   rng.choice(("flower_red", "flower_yellow", "flower_white", "flower_purple")))
        b.add(fl.move(wxh - 1.4 + j * 0.7, hy - Dh / 2 - 1.0 + rng.uniform(-0.2, 0.2), z0 + kit.SILL_Z - 0.35))

    htop = z0 + hh
    if p["storeys"] == 2:  # framed upper storey (the carpenter's own work) over the ground floor
        h2 = rng.uniform(7.4, 7.9)
        b.add(kit.bbox(Wh + 0.5, Dh + 0.5, 0.6, "timber", 0.1).move(hx, hy, htop))
        for j in range(6):
            u = hx - Wh / 2 + 0.6 + (Wh - 1.2) * j / 5
            b.add(box(0.55, 0.9, 0.55, "timber").move(u, hy - Dh / 2 - 0.2, htop - 0.45))
        htop += 0.6
        b.add(kit.bbox(Wh, Dh, h2, plaster, 0.18).move(hx, hy, htop).paint(grad=("range", 0.4, 0.85)))
        uw = [(-Wh * 0.24, 1.72), (Wh * 0.24, 1.72)]
        posts = C.posts_for(Wh, uw)
        b.add([f.move(hx, 0, htop) for f in C.frame_wall(Wh, h2, "x", hy - Dh / 2, posts,
                                                        C.braces_for(posts, uw, rng), rng=rng)])
        for u, _ in uw:
            for pc in kit.window(kit.WIN_W, kit.WIN_H * 0.9, "timber", shutter):
                b.add(pc.move(hx + u, hy - Dh / 2, htop + 2.2))
            windows += 1
        posts = C.posts_for(Dh, [(0.0, 1.72)])
        b.add([f.move(0, 0, htop) for f in C.frame_wall(Dh, h2, "y", hx + hs * Wh / 2, posts,
                                                       C.braces_for(posts, [(0.0, 1.72)], rng), rng=rng)])
        for pc in kit.window(kit.WIN_W, kit.WIN_H * 0.9, "timber", shutter):
            b.add(pc.rotate(hs * math.pi / 2, "Z").move(hx + hs * Wh / 2, hy, htop + 2.2))
        windows += 1
        htop += h2
    style = p["house_roof"]
    hpitch = rng.uniform(48, 53) if style == "thatch" else rng.uniform(45, 49)
    hcol = "thatch" if style == "thatch" else kingdom_color(k, "roof")
    hrc = "thatch_dark" if style == "thatch" else kingdom_color(k, "roof_dark")
    hroof, hrise = kit.gable_roof(Dh, Wh, hpitch, overhang=1.4, gable_overhang=1.0, thickness=0.75, color=hcol,
                                  rows=5, ridge_color=hrc, style=style, rng=rng)
    for pc in hroof:
        b.add(pc.rotate(math.pi / 2, "Z").move(hx, hy, htop), tag="roof")
    for sx in (-1, 1):
        g = kit.gable_end(Dh, hrise, 0.8, plaster)
        b.add(g.rotate(math.pi / 2, "Z").move(hx + sx * (Wh / 2 - 0.4), hy, htop).paint(grad=("range", 0.5, 0.85)))
        if sx == hs:  # outer gable: timbers and a loft door with a hoist beam
            xg = hx + sx * (Wh / 2 + 0.1)
            n = Vector((sx, 0, 0))
            b.add(kit.oriented_box((xg, hy - Dh / 2 + 0.5, htop + 0.35), (xg, hy + Dh / 2 - 0.5, htop + 0.35),
                                   kit.TIMBER, 0.4, "timber", n))
            for s in (-1, 1):
                b.add(kit.oriented_box((xg, hy + s * Dh * 0.36, htop + 0.6), (xg, hy + s * 1.9, htop + hrise * 0.6),
                                       kit.TIMBER * 0.8, 0.4, "timber", n))
            b.add(box(0.5, 2.6, 3.2, kingdom_color(k, "wood")).move(xg, hy, htop + 0.9))
            b.add(kit.oriented_box((xg - sx * 0.4, hy, htop + 4.6), (xg + sx * 2.4, hy, htop + 4.6), 0.55, 0.55,
                                   "timber", Vector((0, -1, 0))))
            b.add(box(0.08, 0.08, 2.4, "rope").move(xg + sx * 2.1, hy, htop + 2.2))
    chx = hx + hs * (Wh / 2 - 1.8)
    b.add([pc.move(chx, hy + Dh * 0.22, z0) for pc in kit.chimney(htop + hrise * 0.75 + 2.4 - z0, 2.2, "stone",
                                                                    "stone_dark")])

    # ------------------------------------------------ yard: plank stacks (deposit), log pile, crane
    # sawn-plank stacks run front-to-back beside the shed, under the crane jib (deposit point in front)
    stacks = 0
    sl_ = rng.uniform(8.4, 9.2)
    sy_ = -Ds / 2 - sl_ / 2 + 0.2
    for j in range(2):
        st_ = C.plank_stack(rng, sl_ * (1.0 - 0.08 * j), 3.4, 5 - j)
        b.add([pc.rotate(math.pi / 2, "Z").move(os_ * (Ws / 2 + 2.2 + j * 4.4), sy_ - j * 0.5, 0) for pc in st_])
        stacks += 1
    b.stats["plank_stacks"] = stacks
    b.socket("deposit", os_ * (Ws / 2 + 4.4), sy_ - sl_ / 2 - 2.0, 0)
    b.add([pc.move(os_ * (Ws / 2 + 7.6), Ds * 0.45, 0) for pc in C.log_pile(rng, 7.0, 3, 0.75)])

    crane = p["crane"]
    mast_x, mast_y = os_ * (Ws / 2 + 2.4), Ds * 0.15
    if crane == "treadwheel":
        cx, cy = os_ * (Ws / 2 + 7.2), -0.2
        b.add([pc.move(cx, cy, 0) for pc in C.treadwheel(3.8, 2.2)])
    Hm = rng.uniform(17.5, 19.0)
    b.add(kit.bbox(2.4, 2.4, 0.8, "stone", 0.12).move(mast_x, mast_y, 0))
    b.add(kit.bbox(1.0, 1.0, Hm - 0.8, "wood", 0.08).move(mast_x, mast_y, 0.8).paint(grad=("range", 0.3, 0.85)))
    for a in range(4):
        ang = math.tau * a / 4 + math.pi / 4
        b.add(C.grounded(kit.oriented_box((mast_x + math.cos(ang) * 2.6, mast_y + math.sin(ang) * 2.6, 0),
                                          (mast_x, mast_y, 4.2), 0.42, 0.42, "wood_dark", Vector((0, 0, 1)))))
    # jib: forward and out over the yard, braced to the mast head
    j0 = Vector((mast_x, mast_y - 0.4, Hm - 6.0))
    j1 = Vector((mast_x + os_ * 6.6, mast_y - 8.2, Hm - 2.0))
    b.add(kit.oriented_box(j0, j1, 0.95, 0.95, "timber", Vector((1, 0, 0))))
    b.add(kit.oriented_box((mast_x, mast_y, Hm - 0.4), tuple(j1 + Vector((0, 0.2, 0.2))), 0.3, 0.3, "rope",
                           Vector((1, 0, 0))))
    b.add(kit.oriented_box((mast_x, mast_y - 0.3, Hm - 9.5), tuple(j0.lerp(j1, 0.55)), 0.5, 0.5, "wood_dark",
                           Vector((1, 0, 0))))
    b.add(cylinder(0.45, 0.45, 0.5, 8, "wood_dark").rotate(math.pi / 2, "Y").move(j1.x - 0.25, j1.y, j1.z - 0.35))
    # hoist rope, hook and a slung log
    zl = 5.6
    b.add(box(0.12, 0.12, j1.z - 0.6 - (zl + 2.2), "rope").move(j1.x, j1.y, zl + 2.2))
    b.add(lathe([(0.0, 0.0), (0.3, 0.2), (0.3, 0.6), (0.0, 0.9)], 5, "iron_dark").move(j1.x, j1.y, zl + 1.5))
    for sx in (-1, 1):
        b.add(kit.oriented_box((j1.x, j1.y, zl + 1.6), (j1.x + sx * 1.8, j1.y, zl + 0.75), 0.12, 0.12, "rope",
                               Vector((0, -1, 0))))
    b.add([pc.move(j1.x, j1.y, zl) for pc in C.log(6.0, 0.7, rng)])
    if crane == "treadwheel":  # rope from the jib root down to the wheel axle
        b.add(kit.oriented_box((mast_x, mast_y - 0.6, Hm - 6.2), (cx, cy + 1.3, 4.3), 0.12, 0.12, "rope",
                               Vector((1, 0, 0))))
    else:  # winch drum with cranks at the mast foot
        b.add(cylinder(0.6, 0.6, 2.4, 8, "wood_dark").rotate(math.pi / 2, "Y").move(mast_x - 1.2, mast_y - 1.4, 1.8))
        for sx in (-1, 1):
            b.add(box(0.3, 0.3, 2.6, "wood").move(mast_x + sx * 1.3, mast_y - 1.4, 0))
            b.add(kit.oriented_box((mast_x + sx * 1.5, mast_y - 1.4, 1.8), (mast_x + sx * 1.5, mast_y - 2.5, 2.6),
                                   0.18, 0.18, "iron_dark", Vector((1, 0, 0))))
        b.add(kit.oriented_box((mast_x, mast_y - 0.6, Hm - 6.2), (mast_x, mast_y - 1.4, 2.4), 0.12, 0.12, "rope",
                               Vector((1, 0, 0))))
    b.add([pc.move(mast_x, mast_y, Hm) for pc in C.pennant(k, 3.6, 1.8)])
    b.stats["crane"] = 1

    # small extras: a barrel and a crate of offcuts by the house door
    b.add([pc.move(dxh + os_ * 3.4, hy - Dh / 2 - 2.0, 0) for pc in C.barrel(0.85, 2.2)])

    b.stats["windows"] = windows
    b.stats["pieces"] = len(b.pieces)
    b.stats["roof"] = b.count_tag("roof")
