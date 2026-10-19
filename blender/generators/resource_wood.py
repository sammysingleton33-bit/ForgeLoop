"""Lumber node (wood resource): one stack shape per variant (round pile, log crib, single
row, plank-shored stack, rope-bound bundle, felled trunk on chocks with upright rounds), logs
of varied girth in three bark shades with knots / bark ridges and two-tone cut ends, plus one
work prop each (stump + axe on two, bucksaw, chopping block with split wedges, firewood
barrow), wood chips.

Reads at 60 studs as "wood": warm brown bark masses dotted with pale cut-end discs.
Front faces Blender -Y (log ends face the front). Pivot at base centre.
Sockets: `harvest` (worker stands in front of the pile), `hit` (front log ends, for VFX).
Stats: harvest_radius (studs), logs (count).
"""

import math

from lib import kit
from lib.geo import Matrix, Vector, box, cone, cylinder, frustum_box, lathe, look_rot, prism
from generators import _rock_common as rc

NAME = "resource_wood"
VERSION = 2
CATEGORY = "resource"
BUDGET = "resource"
COLLISION = {"fidelity": "Hull"}
CHECKS = {"min_logs": 6, "has_harvest_radius": 1}
DEFAULT_VARIANTS = 6
HERO_VIEW = {"azimuth": -32, "elevation": 24}

PLANS = [
    {"pile": "round", "extra": "stump", "scale": 1.0},
    {"pile": "crib", "extra": "bucksaw", "scale": 1.0},
    {"pile": "felled", "extra": "rounds", "scale": 1.0},
    {"pile": "row", "extra": "block", "scale": 1.0},
    {"pile": "shored", "extra": "barrow", "scale": 1.0},
    {"pile": "bundle", "extra": "stump", "scale": 1.05},
]
BARKS = (("bark_dark", 0.22), ("bark", 0.45), ("bark_light", 0.33))


def variants(n, seed):
    out = []
    for i in range(n):
        p = dict(PLANS[i % len(PLANS)])
        p["seed"] = seed * 1000 + 900 + i
        out.append(p)
    return out


def _bark(rng):
    u = rng.random()
    for name, w in BARKS:
        if u < w:
            return name
        u -= w
    return BARKS[-1][0]


def _log(rng, b, x, y, z, length, r, bark=None, yaw=0.0, rings=(True, False), seg=7, tag="log", taper=None,
         detail=0.45, upright=False):
    """Log along Y (or standing up when `upright`) with pale ends + darker heart disc (two-tone),
    and sometimes a knot or a raised bark ridge on its upper side."""
    taper = rng.uniform(0.86, 0.96) if taper is None else taper
    bark = bark or _bark(rng)
    pcs = rc.log(rng, length, r, seg=seg, bark=bark, rings=rings, chamfer=False, taper=taper, heart="wood")
    if rng.random() < detail:
        th = rng.uniform(0.25, 0.75) * math.pi  # upper half
        u = rng.uniform(-0.3, 0.3) * length
        if rng.random() < 0.5:  # knot
            d = Vector((math.cos(th), 0.0, math.sin(th)))
            kn = cone(r * 0.24, r * 0.32, 5, "bark_dark").transform(look_rot(d)).move(d.x * r * 0.88, u, d.z * r * 0.88)
            pcs.append(kn.paint(grad=("range", 0.2, 0.7)))
        else:  # bark ridge
            rd = box(0.16, length * rng.uniform(0.4, 0.6), 0.12, "bark_dark", base=False).move(0, u * 0.5, r * 0.98)
            pcs.append(rd.rotate(th - math.pi / 2, "Y").paint(grad="flat"))
    for pc in pcs:
        if upright:
            pc.rotate(-math.pi / 2, "X").move(0, 0, length / 2)
        b.add(pc.rotate(yaw, "Z").move(x, y, z), tag=tag)


def _split(rng, r, length, bark):
    """Half log (split firewood): semicircle prism, pale flat face, bark round side, along Y."""
    seg = 5
    poly = [(math.cos(math.pi * i / seg) * r, math.sin(math.pi * i / seg) * r) for i in range(seg + 1)]
    pc = prism(poly, length, "wood_pale")
    fc = []
    for f in pc.faces:
        zs = [pc.verts[i].z for i in f]
        ys = [pc.verts[i].y for i in f]
        if len(f) > 4 or max(ys) - min(ys) < 1e-4:
            fc.append("wood_pale")  # end caps
        elif max(zs) < 1e-4:
            fc.append("wood_light")  # flat split face
        else:
            fc.append(bark)
    pc.face_colors = fc
    return pc.paint(grad=("range", 0.25, 0.95))


def _chip(rng, x, y):
    s = rng.uniform(0.35, 0.6)
    pc = prism([(0.0, 0.0), (s, 0.0), (s * 0.3, s * 0.45)], 0.1, rng.choice(("wood_pale", "wood_light", "wood_pale")),
               axis="Z")
    return pc.rotate(rng.uniform(0, 6.3), "Z").move(x, y, 0.0).paint(grad="flat")


def _stump(rng, b, x, y, r, h, bark, axe=True):
    prof = [(r * 1.38, 0.0), (r * 1.12, 0.35), (r * 1.0, 0.9), (r * 0.98, h)]
    st = lathe(prof, 8, bark, phase=rng.uniform(0, 1))
    fc = [bark] * len(st.faces)
    fc[-1] = "wood_pale"
    st.face_colors = fc
    b.add(st.paint(grad=("range", 0.1, 0.85)).move(x, y, 0), tag="stump")
    b.add(cylinder(r * 0.5, r * 0.5, 0.06, 8, "wood_light").move(x, y, h - 0.02).paint(grad="flat"), tag="stump")
    for k in range(4):  # root flare
        a = k * math.tau / 4 + rng.uniform(-0.4, 0.4)
        rt = cone(r * 0.38, r * 1.6, 5, bark).rotate(math.pi / 2 - 0.35, "Y").rotate(a, "Z")
        b.add(rt.move(x + math.cos(a) * r * 0.7, y + math.sin(a) * r * 0.7, 0.05).paint(grad=("range", 0.1, 0.6)),
              tag="stump")
    if axe:
        tilt = rng.uniform(0.35, 0.55)
        a = rng.uniform(-0.6, 0.6) - math.pi / 2
        d = Vector((math.cos(a) * math.sin(tilt), math.sin(a) * math.sin(tilt), math.cos(tilt)))
        bite = Vector((x, y, h - 0.15))
        top = bite + d * 3.4
        b.add(rc.beam(bite + d * 0.2, top, 0.28, 0.3, "wood_light", Vector((-math.sin(a), math.cos(a), 0))),
              tag="tool")
        hd = box(0.5, 1.5, 0.95, "iron", base=False)
        edge = box(0.24, 1.75, 0.6, "steel", base=False).move(0, 0, -0.55)
        for pc in (hd, edge):
            pc.rotate(tilt, "Y" if abs(math.cos(a)) > 0.7 else "X").rotate(a + math.pi / 2, "Z")
            pc.move(*(bite + d * 0.35))
            b.add(pc, tag="tool")


def _bucksaw(b, x, y, lean, side):
    """Bow/buck saw: two arms, a stretcher, a steel blade and a twisted cord, leaning on a stack."""
    parts = [rc.beam((-1.1, 0, 0.0), (-1.0, 0, 1.7), 0.18, 0.18, "wood_light", (0, 1, 0)),
             rc.beam((1.1, 0, 0.0), (1.0, 0, 1.7), 0.18, 0.18, "wood_light", (0, 1, 0)),
             rc.beam((-1.05, 0, 0.95), (1.05, 0, 0.95), 0.14, 0.14, "wood", (0, 1, 0)),
             box(2.4, 0.05, 0.22, "steel").move(0, 0, 0.12),
             rc.beam((-1.0, 0, 1.6), (1.0, 0, 1.6), 0.08, 0.08, "rope", (0, 1, 0))]
    for pc in parts:
        b.add(pc.rotate(lean, "X").rotate(side, "Z").move(x, y, 0.08), tag="saw")


def _barrow(rng, b, x, y, yaw):
    """Wheelbarrow heaped with split firewood."""
    parts = [frustum_box(1.5, 1.1, 2.1, 1.5, 0.75, "wood").move(0, 0, 0.75),
             cylinder(0.55, 0.55, 0.22, 8, "wood_dark").rotate(math.pi / 2, "Y").move(-0.11, -1.35, 0.55),
             cylinder(0.18, 0.18, 0.4, 6, "iron_dark").rotate(math.pi / 2, "Y").move(-0.2, -1.35, 0.55)]
    for sx in (-1, 1):
        parts.append(rc.beam((sx * 0.6, -1.35, 0.55), (sx * 0.75, 1.9, 0.95), 0.16, 0.16, "wood_light", (0, 0, 1)))
        parts.append(rc.beam((sx * 0.6, 0.6, 0.0), (sx * 0.6, 0.6, 0.85), 0.16, 0.16, "wood_light", (1, 0, 0)))
    for i in range(4):
        sp = _split(rng, rng.uniform(0.3, 0.38), 1.5, _bark(rng)).rotate(rng.choice((0.0, math.pi)), "Y")
        parts.append(sp.rotate(math.pi / 2 + rng.uniform(-0.2, 0.2), "Z").move(-0.45 + i * 0.32, rng.uniform(-0.3, 0.3),
                                                                               1.5 + (i % 2) * 0.25))
    for pc in parts:
        b.add(pc.rotate(yaw, "Z").move(x, y, 0), tag="barrow")


def build(b, p):
    rng = b.rng
    S = p["scale"]
    pile = p["pile"]
    logs = 0
    r0 = rng.uniform(0.72, 0.82) * S
    L = rng.uniform(8.5, 10.5) * S
    front = -L / 2
    hit_z = r0
    W2 = 4.0  # half footprint of the main stack (updated per shape)

    def var_r():  # girth varies about +-25 %
        return r0 * rng.uniform(0.76, 1.22)

    if pile in ("round", "row", "shored"):
        # sleepers under the stack
        n0 = {"round": 5, "row": 7, "shored": 4}[pile]
        pitch = 2.0 * r0 * 1.12
        for sy in (-L * 0.3, L * 0.3):
            for pc in rc.log(rng, n0 * pitch + 1.0, 0.32, seg=6, bark="bark_dark", rings=(False, False),
                             chamfer=False):
                b.add(pc.rotate(math.pi / 2, "Z").move(0, sy, 0.32), tag="log")
        rows = {"round": 4, "row": 1, "shored": 3}[pile]
        for row in range(rows):
            n = n0 - row if pile == "round" else (n0 if pile == "shored" else n0)
            z = 0.55 + r0 + row * pitch * (0.87 if pile == "round" else 0.98)
            x0 = -(n - 1) * pitch / 2 + (pitch * 0.25 if (pile == "shored" and row % 2) else 0.0)
            for i in range(n):
                r = var_r()
                dy = rng.uniform(-0.5, 0.5) - (1.3 if (row == 0 and i == n // 2 - 1) else 0.0)
                _log(rng, b, x0 + i * pitch, dy, z - r0 + r * 0.92, L * rng.uniform(0.9, 1.05), r)
                logs += 1
                front = min(front, dy - L / 2)
        if pile == "row":  # two logs resting in the grooves on top
            for i in (2, 4):
                r = var_r()
                _log(rng, b, -(n0 - 1) * pitch / 2 + (i - 0.5) * pitch, rng.uniform(-0.4, 0.4),
                     0.55 + r0 * 2 + r * 0.6, L * 0.85, r)
                logs += 1
        W2 = n0 * pitch / 2 + 0.5
        if pile == "shored":
            # a stake on one side; on the other a plank shoring the stack, footed on a chock
            side_p = rng.choice((-1, 1))
            sh = 0.55 + r0 + 2 * pitch * 0.98 + r0
            for sy in (-L * 0.3, L * 0.3):
                xs_ = -side_p * (W2 + 0.1)
                b.add(rc.beam((xs_, sy, 0.0), (xs_ - side_p * 0.2, sy, sh + 0.3), 0.36, 0.36, "wood", (0, 1, 0)),
                      tag="stake")
            px = side_p * (W2 + 0.0)
            plank = kit.bbox(0.3, L * 0.8, sh * 1.12, "wood_light", 0.05)
            b.add(plank.rotate(-side_p * 0.42, "Y").move(px + side_p * 1.75, 0, 0.0), tag="plank")
            b.add(kit.bbox(0.9, L * 0.6, 0.6, "wood_dark", 0.06).move(px + side_p * 2.3, 0, 0), tag="plank")
            W2 += 2.5
    elif pile == "crib":
        # log crib: layers of three short logs, each layer crossing the one below
        rc_ = r0 * 0.85
        sp_ = 2.15 * rc_
        Lc = 2 * sp_ + 2 * rc_ + 1.2
        for k in range(5):
            z = rc_ + k * rc_ * 1.8
            for i in (-1, 0, 1):
                r = rc_ * rng.uniform(0.85, 1.15)
                if k % 2 == 0:
                    _log(rng, b, i * sp_, rng.uniform(-0.3, 0.3), z - rc_ + r, Lc, r, seg=6)
                else:
                    _log(rng, b, rng.uniform(-0.3, 0.3), i * sp_, z - rc_ + r, Lc, r, yaw=math.pi / 2, seg=6)
                logs += 1
        front = -Lc / 2
        hit_z = rc_ * 3
        W2 = Lc / 2
    elif pile == "bundle":
        # seven logs packed hexagonally and bound with rope bands, on two sleepers
        rb = r0 * 1.05
        Lb = L * 1.05
        for sy in (-Lb * 0.3, Lb * 0.3):
            b.add(kit.bbox(6.0 * rb, 0.8, 0.5, "wood_dark", 0.06).move(0, sy, 0), tag="log")
        cz = 0.5 + rb * 2.0
        for i in range(7):
            if i == 0:
                cx, czz = 0.0, cz
            else:
                a = math.pi / 6 + (i - 1) * math.tau / 6
                cx, czz = math.cos(a) * 2 * rb, cz + math.sin(a) * 2 * rb
            r = rb * rng.uniform(0.85, 1.05)
            _log(rng, b, cx, rng.uniform(-0.4, 0.4), czz, Lb * rng.uniform(0.93, 1.03), r, seg=7)
            logs += 1
        for sy in (-Lb * 0.27, Lb * 0.27):  # rope bands: a hexagon of rope lashed round the pack
            ring = [Vector((math.cos(math.pi / 6 + q * math.tau / 6) * rb * 3.05, sy,
                            cz + math.sin(math.pi / 6 + q * math.tau / 6) * rb * 3.05)) for q in range(6)]
            for q in range(6):
                b.add(rc.beam(ring[q], ring[(q + 1) % 6], 0.3, 0.22, "rope", (0, 1, 0)), tag="rope")
        front = -Lb / 2 - 0.4
        hit_z = cz
        W2 = rb * 3.2
    elif pile == "felled":
        # felled trunk raised on two chocks, with sawn-off branch stubs
        Lf = rng.uniform(13.0, 15.0)
        rf = rng.uniform(1.05, 1.2)
        fz = rf + 1.05
        for u in (-Lf * 0.3, Lf * 0.28):
            ch = prism([(-1.0, 0.0), (1.0, 0.0), (0.6, 1.25), (-0.6, 1.25)], 1.8, "wood")
            b.add(ch.move(u, -1.0, 0).paint(grad=("range", 0.2, 0.8)), tag="chock")
        _log(rng, b, 0.0, -1.0, fz, Lf, rf, yaw=math.pi / 2 + rng.uniform(-0.06, 0.06), rings=(True, True), seg=8,
             detail=1.0)
        logs += 1
        for k in range(3):
            u = -Lf * 0.3 + Lf * 0.62 * (k + rng.uniform(0.1, 0.9)) / 3
            st = cylinder(0.5, 0.4, 2.0, 6, "bark")
            fc = ["bark"] * len(st.faces)
            fc[-1] = "wood_pale"
            st.face_colors = fc
            st.rotate(rng.uniform(0.3, 0.6) * (1 if k % 2 else -1), "X")
            b.add(st.move(u, -1.0, fz + rf * 0.4).paint(grad=("range", 0.2, 0.8)), tag="log")
        front = -1.0 - rf
        hit_z = fz
        W2 = Lf / 2

    # ---- secondary work prop (stump + axe only on two variants)
    extra = p["extra"]
    side = rng.choice((-1, 1))
    ex = side * (W2 + 2.4)
    ey = front + rng.uniform(1.2, 2.2)
    if extra == "stump":
        _stump(rng, b, ex, ey, rng.uniform(0.95, 1.15) * S, rng.uniform(1.6, 2.1), "bark", axe=True)
        for j in range(2):
            sp = _split(rng, rng.uniform(0.45, 0.6), rng.uniform(1.4, 1.9), _bark(rng))
            sp.rotate(math.pi / 2 * rng.choice((0, 1, 2, 3)) + rng.uniform(-0.3, 0.3), "Y" if j == 0 else "Z")
            mz = min(v.z for v in sp.verts)
            b.add(sp.move(ex + side * rng.uniform(1.5, 2.4), ey + rng.uniform(-1.6, 0.6), -mz), tag="split")
    elif extra == "bucksaw":
        _bucksaw(b, side * W2 * 0.45, front - 0.75, -0.38, side * 0.15)
        for j in range(3):  # sawn rounds by the crib
            _log(rng, b, ex + rng.uniform(-1.0, 1.0), ey + j * 1.3 - 1.0, 0.0, rng.uniform(0.7, 1.0), rng.uniform(0.55, 0.7),
                 upright=True, rings=(True, False), seg=7, detail=0.0)
            logs += 1
    elif extra == "rounds":  # an upright stack of bucked rounds (two tiers) + one with a splitting wedge
        sx_, sy_ = ex * 0.6, front - 3.2
        hg = 1.35
        for j in range(7):
            tier = 0 if j < 5 else 1
            a = j * math.tau / 5 + rng.uniform(-0.15, 0.15) if tier == 0 else (j - 5) * math.pi + 0.5
            rr = 1.45 if tier == 0 else 0.75
            _log(rng, b, sx_ + math.cos(a) * rr, sy_ + math.sin(a) * rr, tier * hg, hg, rng.uniform(0.62, 0.76),
                 upright=True, rings=(True, False), seg=7, detail=0.0)
            logs += 1
        _log(rng, b, sx_ - side * 3.2, sy_ + 0.4, 0.0, 1.2, 0.8, upright=True, rings=(True, False), seg=7, detail=0.0)
        b.add(rc.wedge(sx_ - side * 3.2, sy_ + 0.4, 1.45, 0.4, color="iron"), tag="tool")
        logs += 1
        ey = sy_
    elif extra == "block":  # chopping block with split wedges standing on / around it
        bh = 1.2
        _log(rng, b, ex, ey, 0.0, bh, 0.95, upright=True, rings=(True, False), seg=8, detail=0.0)
        logs += 1
        for j in range(5):
            sp = _split(rng, rng.uniform(0.32, 0.42), rng.uniform(1.1, 1.5), _bark(rng))
            if j == 0:  # one wedge of wood stood on the block, waiting to be split
                sp.rotate(-math.pi / 2, "X").move(0, 0, 0)
                mz = min(v.z for v in sp.verts)
                b.add(sp.move(ex, ey, bh - mz), tag="split")
            else:
                sp.rotate(rng.uniform(0, math.tau), "Z")
                mz = min(v.z for v in sp.verts)
                a = rng.uniform(0, math.tau)
                b.add(sp.move(ex + math.cos(a) * 1.7, ey + math.sin(a) * 1.7, -mz), tag="split")
    elif extra == "barrow":
        _barrow(rng, b, ex + side * 0.4, ey - 0.5, side * 0.5 + math.pi)
    for j in range(rng.randint(8, 10)):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(1.2, 2.8)
        b.add(_chip(rng, ex + math.cos(a) * d, ey + math.sin(a) * d), tag="chip")

    # ---- grass at the edges
    for j in range(3):
        a = rng.uniform(0, math.tau)
        b.add(rc.grass_tuft(rng, math.cos(a) * (W2 + 0.6), math.sin(a) * L * 0.5, size=1.0), tag="grass")

    hx = -side * min(1.5, W2 * 0.3)
    b.socket("harvest", hx, front - 2.4, 0.0)
    b.socket("hit", hx, front, hit_z)
    b.stats["logs"] = logs
    xs = [v.x for pc in b.pieces for v in pc.verts]
    ys = [v.y for pc in b.pieces for v in pc.verts]
    b.stats["harvest_radius"] = round(max(max(xs) - min(xs), max(ys) - min(ys)) / 2 + 2.0, 1)
    rc.rest_on_ground(b)
    b.stats["pieces"] = len(b.pieces)
