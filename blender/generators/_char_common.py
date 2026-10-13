"""Shared character kit for the char_* generators (FORGE-02 characters family).

Chunky, storybook-stylised medieval humans at Roblox R15 scale (5.5 studs to the top of the
head). Every body part is its own closed shell (or a few closed shells) so a later rig can
split the mesh by part: head (+ hair, headwear), upper torso (+ tabard, belt), lower torso
(pelvis, skirt), upper/lower arm + hand per side, upper/lower leg + boot per side.

Coordinates: Blender Z up, character faces -Y, character's RIGHT side is -X.
`Body` holds the joint positions (studs); generators place accessories relative to them and
`Body.sockets(b)` exports them (rig_* sockets) so the future rig gets exact pivots per asset.
"""

import math

from lib import kit
from lib.geo import Matrix, Vector, box, cylinder, lathe, look_rot, loft_rings, prism, tube, uvsphere
from lib.palette import kingdom_color

from generators import _kingdom_props_common as kp

KINGDOMS = ("red", "blue", "green", "yellow")

# Joint table for a 5.5-stud character (x for the LEFT side; the right side mirrors to -x).
BASE = {
    "ankle": (0.47, 0.0, 0.42),
    "knee": (0.46, -0.05, 1.30),
    "hip": (0.42, 0.0, 2.26),
    "root": (0.0, 0.0, 2.30),
    "waist": (0.0, 0.0, 2.62),
    "chest": (0.0, 0.0, 3.35),
    "neck": (0.0, 0.0, 4.10),
    "head": (0.0, 0.0, 4.80),
    "shoulder": (0.98, 0.0, 3.80),
}
HEAD_R = 0.67  # head radius (stylised: ~1/4 of the height)

# Arm poses for the LEFT arm: (elbow, wrist); mirrored for the right arm.
ARM_POSES = {
    "rest": ((1.27, 0.10, 3.02), (1.47, -0.02, 2.28)),  # relaxed A-pose
    "grip": ((1.30, 0.16, 3.02), (1.50, -0.40, 2.70)),  # fist forward holding a vertical shaft
    "low": ((1.25, 0.08, 2.98), (1.42, -0.14, 2.22)),  # hanging, holding a tool
    "carry": ((1.20, 0.14, 3.00), (1.26, -0.62, 2.86)),  # forearm forward (basket, pouch)
    "hip": ((1.55, 0.22, 3.06), (1.06, -0.10, 2.62)),  # hand on hip
    "stick": ((1.32, 0.06, 3.00), (1.48, -0.50, 2.50)),  # leaning on a walking stick
}

# ------------------------------------------------------------------ small primitives


def ellipsoid(rx, ry, rz, color, seg=8, rings=5, **kw):
    return uvsphere(1.0, seg, rings, color, **kw).scale(rx, ry, rz)


def along(piece, direction):
    """Rotate a piece modelled along +Z so that +Z points along `direction`."""
    return piece.transform(look_rot(Vector(direction)))


def elathe(profile, seg, color, sx=1.0, sy=1.0, **kw):
    """Elliptical lathe: revolve then squash X/Y (torsos, skirts, hats)."""
    return lathe(profile, seg, color, **kw).scale(sx, sy, 1.0)


def slab(poly, depth, color, **kw):
    """2D outline (x, z) extruded along Y (shields, emblems, aprons); centred on y=0."""
    return prism(poly, depth, color, **kw)


def shrink(poly, f, cx=0.0, cz=None):
    if cz is None:
        cz = sum(z for _, z in poly) / len(poly)
    return [(cx + (x - cx) * f, cz + (z - cz) * f) for x, z in poly]


def interp(profile, z):
    """Radius of a (r, z) lathe profile at height z (linear)."""
    for (r0, z0), (r1, z1) in zip(profile, profile[1:]):
        if z0 <= z <= z1:
            t = 0.0 if z1 == z0 else (z - z0) / (z1 - z0)
            return r0 + (r1 - r0) * t
    return profile[0][0] if z < profile[0][1] else profile[-1][0]


# ------------------------------------------------------------------ emblems (ART_DIRECTION §3)


def emblem_poly(k):
    """Kingdom emblem outline in a unit box (x -0.5..0.5, z 0..1), CCW. (No yellow: the kit-wide sun
    is layered, see `emblem`.)"""
    if k == "red":  # flame
        return [(0.0, 0.0), (0.26, 0.03), (0.42, 0.18), (0.46, 0.4), (0.38, 0.58), (0.42, 0.8), (0.24, 0.64),
                (0.18, 0.84), (0.02, 1.0), (-0.06, 0.78), (-0.2, 0.9), (-0.26, 0.66), (-0.42, 0.5),
                (-0.46, 0.28), (-0.3, 0.05)]
    if k == "blue":  # five-point star
        pts = []
        for i in range(10):
            a = math.pi / 2 + i * math.pi / 5
            r = 0.52 if i % 2 == 0 else 0.22
            pts.append((math.cos(a) * r, 0.48 + math.sin(a) * r))
        return pts
    if k == "green":  # oak leaf with three lobes a side and a stem
        right = []
        for j in range(11):
            t = j / 10
            env = 0.4 * math.sin(math.pi * min(1.0, 0.08 + 0.92 * t)) ** 0.7
            lob = 0.62 + 0.38 * abs(math.cos(3 * math.pi * t))
            right.append((max(0.05, env * lob), 0.16 + 0.84 * t))
        right[-1] = (0.03, 1.0)
        return [(-0.05, 0.0), (0.05, 0.0)] + right + [(-x, z) for x, z in reversed(right)]
    raise ValueError("emblem_poly('yellow'): the kit-wide sun is layered, draw it with emblem('yellow', ...)")


EMBLEM_STYLE = {  # fill, outline (None = no outline) when drawn on kingdom cloth
    "red": ("red_trim", "red_cloth_dark"),
    "blue": ("blue_emblem", "blue_cloth_dark"),
    "green": ("green_emblem", "green_cloth_dark"),
}  # yellow: see `sun`


def sun(size, depth=0.08, roundel=True):
    """The kit-wide Sunspire sun (_kingdom_props_common.sun_outlines: 8 long deep-gold rays + a raised
    16-sided disc) as two cheap prisms, centred on the origin, facing -Y. roundel=True (on gold cloth,
    D-033): it sits on the shared ivory roundel with a bronze rim, 0.6 x size in radius (the old
    outlined sun's footprint); roundel=False (on an ivory field): the bare sun, 0.56 x size in radius."""
    out = []
    if roundel:
        r = 0.6 * size
        out.append(kp.roundel(r, depth * 0.75).move(0, depth * 0.375, 0).paint(tint=0.5))  # back at +0.75 depth
        s = r / kp.SUN_ROUNDEL
    else:
        s = 0.56 * size
    rays, disc = kp.sun_outlines(s)
    y = depth * 0.3 - depth / 2  # rays' back sunk 0.3 x depth into the roundel (or field) face at y = 0
    out.append(slab(rays, depth, kp.SUN_RAYS).move(0, y, 0))
    out.append(slab(disc, depth, kp.SUN_DISC).move(0, y - depth * 0.3, 0))
    return [p.paint(grad=("range", 0.55, 0.95)) for p in out]


def emblem(k, size, depth=0.08, outline=True):
    """Emblem slab centred on the origin, facing -Y. outline=None: only where the fill needs it.
    Yellow is the kit-wide sun (`sun`); its "outline" is the ivory roundel it needs on gold cloth."""
    if k == "yellow":
        return sun(size, depth, roundel=outline is not False)
    poly = [(x * size, (z - 0.5) * size) for x, z in emblem_poly(k)]
    fill, line = EMBLEM_STYLE[k]
    out = [slab(poly, depth, fill)]
    if outline and line:  # (None: no outline; only the yellow sun needed one, now its roundel)
        o = slab(shrink(poly, 1.16, 0.0, 0.0), depth * 0.6, line)
        out.append(o.move(0, depth * 0.45, 0))
    return [p.paint(grad=("range", 0.55, 0.95)) for p in out]


# ------------------------------------------------------------------ shield outlines


def kite_poly(W, H, n=6):
    pts = [(0.0, 0.0)]
    for j in range(1, n + 1):
        u = j / n
        pts.append((W / 2 * math.sin(u * math.pi / 2) ** 0.8, 0.8 * H * u))
    for j in range(1, 6):
        a = math.pi * j / 6
        pts.append((W / 2 * math.cos(a), 0.8 * H + 0.2 * H * math.sin(a) ** 0.8))
    for j in range(n, 0, -1):
        u = j / n
        pts.append((-W / 2 * math.sin(u * math.pi / 2) ** 0.8, 0.8 * H * u))
    return pts


def heater_poly(W, H, n=6):
    pts = [(0.0, 0.0)]
    for j in range(1, n + 1):
        u = j / n
        pts.append((W / 2 * math.sin(u * math.pi / 2) ** 0.55, 0.62 * H * u))
    pts += [(W / 2, H * 0.9), (W * 0.3, H), (-W * 0.3, H), (-W / 2, H * 0.9)]
    for j in range(n, 0, -1):
        u = j / n
        pts.append((-W / 2 * math.sin(u * math.pi / 2) ** 0.55, 0.62 * H * u))
    return pts


def almond_poly(W, H, n=7):
    """Pointed oval (lens) standing on its lower point."""
    right, left = [], []
    for j in range(1, n):
        u = -1 + 2 * j / n
        x = W / 2 * (1 - u * u)
        right.append((x, H / 2 * (1 + u)))
    pts = [(0.0, 0.0)] + right + [(0.0, H)] + [(-x, z) for x, z in reversed(right)]
    return pts


def round_poly(R, n=12):
    return [(math.cos(math.tau * i / n + math.pi / n) * R, R + math.sin(math.tau * i / n + math.pi / n) * R)
            for i in range(n)]


def shield(k, poly, emblem_size, rim=None, field=None, boss=False, depth=0.2):
    """Shield standing on its lowest point at the origin, face towards -Y.
    Returns (pieces, centre_z)."""
    sun_on_ivory = k == "yellow" and field is None  # D-033: the gold sun gets an ivory field, not gold
    rim = rim or kingdom_color(k, "trim")
    field = field or kingdom_color(k, "accent" if sun_on_ivory else "cloth")
    zs = [z for _, z in poly]
    cz = (min(zs) + max(zs)) / 2
    out = [slab(poly, depth, rim).paint(grad=("range", 0.3, 0.9))]
    out.append(slab(shrink(poly, 0.86, 0.0, cz), depth * 0.6, field).move(0, -depth * 0.4, 0)
               .paint(grad=("range", 0.35, 0.9)))
    ez = cz + (max(zs) - cz) * 0.12
    for e in emblem(k, emblem_size, 0.08, outline=not sun_on_ivory):
        out.append(e.move(0, -depth * 0.75, ez))
    if boss:
        out.append(lathe([(0.0, 0.0), (0.3, 0.0), (0.26, 0.12), (0.0, 0.2)], 8, rim).rotate(math.pi / 2, "X")
                   .move(0, -depth * 0.8, cz))
    return out, cz


# ------------------------------------------------------------------ body


class Body:
    """Joint positions and build of one character (Blender coords, studs)."""

    def __init__(self, h=1.0, w=1.0, lean=0.0, arm_l="rest", arm_r="rest", fem=False):
        self.h, self.w, self.lean, self.fem = h, w, lean, fem
        self.dy = 0.82 * (0.55 + 0.45 * w)  # depth scale of the torso
        self.j = {}
        for name, (x, y, z) in BASE.items():
            if x:
                self.j[name + "_l"] = self._p(x, y, z)
                self.j[name + "_r"] = self._p(-x, y, z)
            else:
                self.j[name] = self._p(x, y, z)
        for side, pose in (("l", arm_l), ("r", arm_r)):
            s = 1 if side == "l" else -1
            el, wr = ARM_POSES[pose] if isinstance(pose, str) else pose
            self.j["elbow_" + side] = self._p(s * el[0], el[1], el[2])
            self.j["wrist_" + side] = self._p(s * wr[0], wr[1], wr[2])
        # lean the upper body forward about the waist (elders, blacksmiths)
        if lean:
            for name in list(self.j):
                if name.split("_")[0] in ("chest", "neck", "head", "shoulder", "elbow", "wrist"):
                    self.j[name] = self.upper_pt(self.j[name])
        for side in ("l", "r"):
            d = (self.j["wrist_" + side] - self.j["elbow_" + side]).normalized()
            self.j["hand_" + side] = self.j["wrist_" + side] + d * 0.24
            self.j["handdir_" + side] = d
        self.head_c = self.j["head"]
        self.head_top = self.head_c + Vector((0, 0, HEAD_R * self.h + 0.02))

    def _p(self, x, y, z):
        return Vector((x * self.w, y, z * self.h))

    @property
    def upper_m(self):
        wz = self.j["waist"].z
        return Matrix.Translation((0, 0, wz)) @ Matrix.Rotation(self.lean, 4, "X") @ Matrix.Translation((0, 0, -wz))

    def upper_pt(self, v):
        return self.upper_m @ Vector(v)

    def upper(self, piece):
        """Apply the upper-body lean to a piece modelled in the un-leaned pose."""
        if self.lean:
            piece.transform(self.upper_m)
        return piece

    # torso profile (r, z) before the elliptical squash
    def torso_profile(self):
        h = self.h
        if self.fem:
            prof = [(0.0, 2.2), (0.54, 2.22), (0.6, 2.5), (0.56, 2.8), (0.66, 3.2), (0.72, 3.5), (0.66, 3.82),
                    (0.4, 4.02), (0.0, 4.08)]
        else:
            prof = [(0.0, 2.18), (0.56, 2.2), (0.64, 2.45), (0.66, 2.85), (0.72, 3.3), (0.77, 3.6), (0.70, 3.86),
                    (0.42, 4.04), (0.0, 4.1)]
        return [(r, z * h) for r, z in prof]

    @property
    def sx(self):
        return 1.24 * self.w

    def front_y(self, z, x=0.0):
        """Front surface (negative y) of the un-leaned torso at height z and offset x."""
        r = interp(self.torso_profile(), z)
        a, bb = r * self.sx, r * self.dy
        t = min(0.98, abs(x) / max(1e-6, a))
        return -bb * math.sqrt(1 - t * t)

    def half_w(self, z):
        return interp(self.torso_profile(), z) * self.sx

    # -------------------------------------------------------------- building
    def build(self, b, skin, top, sleeve, pants, boots, sleeves="long", forearm=None, cuff=None,
              gloves=None, boot_cuff=None, legs=True, pelvis=None, head=True):
        """Core body: pelvis, torso, neck, head, arms + hands, legs + boots."""
        h = self.h
        forearm = forearm or (sleeve if sleeves == "long" else skin)
        upper_c = sleeve if sleeves in ("long", "short") else skin
        # lower torso (pelvis) -- part 'pelvis'
        pel = elathe([(0.0, 1.9 * h), (0.56, 1.93 * h), (0.67, 2.2 * h), (0.64, 2.62 * h), (0.0, 2.68 * h)], 8,
                     pelvis or pants, 1.2 * self.w, self.dy * 1.02)
        b.add(pel, tag="pelvis")
        # upper torso -- part 'torso'
        tor = elathe(self.torso_profile(), 10, top, self.sx, self.dy)
        b.add(self.upper(tor.paint(grad=("range", 0.35, 0.9))), tag="torso")
        neck = cylinder(0.26, 0.24, 0.45, 8, skin).move(0, 0, 3.92 * h)
        b.add(self.upper(neck), tag="head")
        # head -- part 'head' (knights: the closed helm is the head shell)
        if head:
            self.head(b, skin)
        # arms
        for side in ("l", "r"):
            self.arm(b, side, upper_c, forearm, skin, cuff, gloves)
        if legs:
            for side in ("l", "r"):
                self.leg(b, side, pants, boots, boot_cuff)

    def head(self, b, skin):
        c = self.head_c
        R = HEAD_R
        prof = [(0.0, -0.98), (0.54, -0.92), (0.83, -0.66), (0.98, -0.25), (1.0, 0.15), (0.9, 0.55), (0.62, 0.86),
                (0.0, 1.0)]
        hd = lathe([(r * R, z * R) for r, z in prof], 12, skin, smooth=True).scale(1, 0.94, self.h)
        hd.paint(grad=("range", 0.5, 0.95))
        b.add(self.upper(hd.move(*self.unleaned("head"))), tag="head")
        # two small dark eyes (Roblox face decals do the rest)
        for s in (-1, 1):
            e = ellipsoid(0.085, 0.07, 0.13, "black", 6, 3).move(s * 0.23, -0.575, 0.02 * self.h)
            b.add(self.upper(e.move(*self.unleaned("head"))), tag="head", grad=0.4)

    def unleaned(self, name):
        x, y, z = BASE[name]
        return (0.0, y, z * self.h)

    def arm(self, b, side, upper_c, fore_c, skin, cuff=None, gloves=None):
        s = 1 if side == "l" else -1
        sh, el, wr = self.j["shoulder_" + side], self.j["elbow_" + side], self.j["wrist_" + side]
        tag = "arm_" + side
        b.add(ellipsoid(0.36, 0.34, 0.34, upper_c, 8, 4).move(*sh), tag=tag, smooth=True)
        b.add(tube([sh, el], [0.31, 0.275], 8, upper_c), tag=tag, smooth=True)
        b.add(ellipsoid(0.275, 0.275, 0.275, fore_c, 8, 3).move(*el), tag=tag, smooth=True)
        b.add(tube([el, wr], [0.27, 0.235], 8, fore_c), tag=tag, smooth=True)
        d = (wr - el).normalized()
        if cuff:
            b.add(tube([wr - d * 0.2, wr + d * 0.02], [0.28, 0.28], 8, cuff), tag=tag)
        hand = ellipsoid(0.28, 0.23, 0.31, gloves or skin, 8, 4)
        hc = self.j["hand_" + side]
        b.add(along(hand, d).move(*hc), tag=tag, smooth=True, grad=("range", 0.45, 0.9))
        th = ellipsoid(0.11, 0.1, 0.16, gloves or skin, 5, 3)
        b.add(th.move(hc.x - s * 0.17, hc.y - 0.14, hc.z + 0.08), tag=tag, smooth=True)

    def leg(self, b, side, pants, boots, boot_cuff=None):
        hp, kn, an = self.j["hip_" + side], self.j["knee_" + side], self.j["ankle_" + side]
        tag = "leg_" + side
        b.add(tube([hp + Vector((0, 0, 0.15)), kn], [0.39, 0.32], 8, pants), tag=tag, smooth=True)
        b.add(ellipsoid(0.32, 0.32, 0.3, pants, 8, 3).move(*kn), tag=tag, smooth=True)
        b.add(tube([kn, an], [0.31, 0.27], 8, pants), tag=tag, smooth=True)
        self.boot(b, side, boots, boot_cuff)

    def boot(self, b, side, color, cuff=None):
        an = self.j["ankle_" + side]
        s = 1 if side == "l" else -1
        tag = "leg_" + side
        top = 1.0 * self.h
        shaft = lathe([(0.32, 0.12), (0.35, top)], 8, color)
        b.add(shaft.move(an.x, an.y, 0), tag=tag)
        if cuff:
            b.add(lathe([(0.37, top - 0.08), (0.41, top + 0.16)], 8, cuff).move(an.x, an.y, 0), tag=tag)
        foot = kit.bbox(0.74, 1.12, 0.5, color, 0.17).move(0, -0.2, 0.05)
        foot.rotate(s * 0.12, "Z")
        b.add(foot.move(an.x + s * 0.02, an.y, 0), tag=tag, grad=("range", 0.3, 0.8))
        sole = box(0.8, 1.18, 0.14, "timber").move(0, -0.2, 0.0).rotate(s * 0.12, "Z")
        b.add(sole.move(an.x + s * 0.02, an.y, 0), tag=tag, grad=0.5)

    # -------------------------------------------------------------- sockets
    def sockets(self, b, head_top_z=None):
        top = self.head_top.copy()
        if head_top_z is not None:
            top.z = head_top_z
        b.socket("head_top", top.x, top.y, top.z + 0.25)
        b.socket("hand_r", *self.j["hand_r"])
        b.socket("hand_l", *self.j["hand_l"])
        for name in ("root", "waist", "neck"):
            b.socket("rig_" + name, *self.j[name])
        b.socket("rig_head", *self.head_c)
        for side in ("l", "r"):
            for name in ("shoulder", "elbow", "wrist", "hip", "knee", "ankle"):
                b.socket(f"rig_{name}_{side}", *self.j[f"{name}_{side}"])
        b.stats["sockets"] = len(b.sockets)

    # -------------------------------------------------------------- clothing helpers
    def skirt(self, z_top, z_bot, r_top, r_bot, color, seg=10, dags=0, sy=None, front_open=0.0):
        """Flared skirt / tunic hem (lower torso part), elliptical, optional dagged hem."""
        h = self.h
        prof = [(r_bot, z_bot * h), (r_bot * 0.97, (z_bot + 0.12) * h), (r_top * 1.02, (z_top - 0.1) * h),
                (r_top, z_top * h)]
        p = elathe(prof, seg, color, 1.18 * self.w, sy or self.dy * 1.08)
        if dags:
            zb = z_bot * h

            def f(v):
                if v.z < zb + 0.01:
                    a = math.atan2(v.y, v.x)
                    v.z += 0.13 * (0.5 + 0.5 * math.cos(a * dags))
                return v

            p.bend(f)
        return p.paint(grad=("range", 0.3, 0.85))

    def belt(self, z, color="leather", buckle="iron", height=0.24, over=0.0):
        """Belt hugging the torso at base height z; `over` = extra front depth (worn over a tabard)."""
        h = self.h
        r = interp(self.torso_profile(), z * h)
        a = r * self.sx + 0.06 + over * 0.25
        d = r * self.dy + 0.06 + over
        p = elathe([(1.0, (z - height / 2) * h), (1.0, (z + height / 2) * h)], 12, color, a, d)
        out_ = [p]
        out_.append(box(0.38, 0.14, height * 1.3, buckle).move(0, -d - 0.03, (z - height * 0.65) * h))
        return out_

    def panel(self, z_bot, z_top, w_bot, w_top, color, back=False, t=0.13, flare=0.0, gap=0.05, n=4):
        """Cloth panel hugging the torso front (or back): tabards, aprons, bibs.
        Built in the un-leaned pose; caller applies `upper()` if needed."""
        h = self.h
        zs = [z_bot * h, 2.5 * h, 3.3 * h, 3.62 * h, z_top * h]
        zs = sorted(set(round(z, 4) for z in zs if z is not None and z_bot * h <= z <= z_top * h))
        sgn = 1 if back else -1
        rings = []
        for z in zs:
            u = (z - zs[0]) / max(1e-6, zs[-1] - zs[0])
            wx = w_bot + (w_top - w_bot) * u
            ring_f, ring_b = [], []
            for i in range(n):
                x = -wx + 2 * wx * i / (n - 1)
                if z >= 2.45 * h:
                    yb = -self.front_y(z, x) + gap
                else:
                    yb = -self.front_y(2.45 * h, x) * 1.02 + gap + flare * (2.45 * h - z) / max(0.1, 2.45 * h - zs[0])
                ring_f.append(Vector((x, sgn * (yb + t), z)))
                ring_b.append(Vector((x, sgn * yb, z)))
            rings.append(ring_f + list(reversed(ring_b)))
        return loft_rings(rings, color).paint(grad=("range", 0.3, 0.9))


# ------------------------------------------------------------------ hair, beards, headwear


def hair_cap(body, color, front=0.32, back=-0.5, puff=1.06):
    """Short hair dome over the head; hairline raised at the front, lower at the nape."""
    R = HEAD_R
    c = body.head_c
    prof = [(1.03, -0.12), (1.06, 0.22), (0.95, 0.56), (0.66, 0.88), (0.0, 1.06)]
    p = lathe([(r * R * puff, z * R) for r, z in prof], 10, color)
    zb, zt = -0.12 * R, 1.06 * R

    def f(v):
        t = (v.y / (R * puff) + 1) / 2  # 0 front .. 1 back
        off = front * (1 - t) + back * t + 0.12 * R
        k = 1 - (v.z - zb) / (zt - zb)
        v.z += off * k * k
        return v

    p.bend(f).scale(1, 0.96, body.h)
    return body.upper(p.move(*body.unleaned("head")).paint(smooth=True, grad=("range", 0.25, 0.9)))


def hair_long(body, color):
    """Back hair volume falling to the shoulders (women, elders)."""
    c = body.unleaned("head")
    p = ellipsoid(0.66, 0.36, 0.7, color, 10, 5).move(c[0], c[1] + 0.34, c[2] - 0.42 * body.h)
    return body.upper(p.paint(smooth=True))


def beard(body, color, size=1.0, moustache=True):
    c = Vector(body.unleaned("head"))
    out = [ellipsoid(0.5 * size, 0.32, 0.46 * size, color, 10, 5).move(c.x, c.y - 0.38, c.z - 0.5 * body.h)
           .paint(smooth=True)]
    if moustache:
        m = tube([(-0.36, -0.58, -0.26), (-0.14, -0.66, -0.16), (0.14, -0.66, -0.16), (0.36, -0.58, -0.26)],
                 [0.07, 0.11, 0.11, 0.07], 6, color)
        out.append(m.move(*c))
    return [body.upper(p) for p in out]


def hood(body, color, tail=0.0, peak=0.0, cape=None, dags=0, cape_r=1.12, cape_len=0.75):
    """Hood around the face (face stays open) + optional liripipe tail, pointed peak and
    shoulder capelet. Part: head (hood) / torso (capelet)."""
    R = HEAD_R
    c = Vector(body.unleaned("head"))
    h = body.h
    prof = [(0.0, -0.95), (0.8, -0.85), (1.12, -0.45), (1.2, 0.1), (1.1, 0.6), (0.72, 1.0), (0.0, 1.22 + peak)]
    p = lathe([(r * R, z * R) for r, z in prof], 10, color).scale(1, 1.0, h)

    def f(v):
        v.y += 0.16
        if v.y < -0.3 and v.z < 0.62 * R:  # open the face
            v.y = -0.3 + (v.y + 0.3) * 0.15
        return v

    p.bend(f)
    out = [p.move(*c).paint(grad=("range", 0.3, 0.9))]
    if tail:
        tp = [Vector((0, 0.55, 0.62)), Vector((0, 0.95, 0.15)), Vector((0, 1.15, -0.45 - tail * 0.5)),
              Vector((0, 1.2, -0.6 - tail))]
        out.append(tube([q + c for q in tp], [0.34, 0.22, 0.14, 0.09], 6, color))
    if cape is not False:
        cz = 4.02 * h
        prof = [(cape_r, cz - cape_len * h), (cape_r * 1.02, cz - (cape_len - 0.13) * h), (0.86, cz - 0.15 * h),
                (0.55, cz + 0.12 * h), (0.4, cz + 0.2 * h)]
        cp = elathe(prof, 10, cape or color, body.sx * 0.94, body.dy * 1.25)
        if dags:
            zb = cz - cape_len * h

            def g(v):
                if v.z < zb + 0.01:
                    a = math.atan2(v.y, v.x)
                    v.z += 0.16 * (0.5 + 0.5 * math.cos(a * dags))
                return v

            cp.bend(g)
        out.append(cp.paint(grad=("range", 0.35, 0.9)))
    return [body.upper(q) for q in out]


def brimmed_hat(body, color, brim_r=1.25, crown_r=0.74, crown_h=0.62, band=None, z_off=0.38, seg=12, cone=False):
    c = Vector(body.unleaned("head"))
    z0 = c.z + z_off * body.h
    out = [lathe([(brim_r, 0.0), (brim_r + 0.04, 0.12), (crown_r + 0.1, 0.2), (0.0, 0.16)], seg, color)
           .move(c.x, c.y, z0)]
    if cone:
        crown = lathe([(crown_r, 0.0), (crown_r * 0.9, crown_h * 0.45), (crown_r * 0.45, crown_h * 0.85),
                       (0.0, crown_h)], seg, color)
    else:
        crown = lathe([(crown_r, 0.0), (crown_r * 0.96, crown_h * 0.8), (crown_r * 0.75, crown_h),
                       (0.0, crown_h * 1.04)], seg, color)
    out.append(crown.move(c.x, c.y, z0 + 0.1))
    if band:
        out.append(lathe([(crown_r + 0.03, 0.0), (crown_r * 0.98 + 0.03, 0.2)], seg, band).move(c.x, c.y, z0 + 0.16))
    return [body.upper(p.paint(grad=("range", 0.35, 0.95))) for p in out]


def scarf_head(body, color, knot=True):
    """Close-fitting headscarf (face open) with a knot at the nape."""
    out = hood(body, color, cape=False)
    c = Vector(body.unleaned("head"))
    if knot:
        out.append(body.upper(ellipsoid(0.24, 0.2, 0.2, color, 8, 4).move(c.x, c.y + 0.82, c.z - 0.25)))
        for s in (-1, 1):
            t = tube([(s * 0.05, 0.86, -0.3), (s * 0.18, 0.95, -0.7), (s * 0.24, 0.92, -0.95)], [0.13, 0.1, 0.07], 6,
                     color)
            out.append(body.upper(t.move(*c)))
    return out


def helmet(body, k, metal="armor", trim=None):
    """Kingdom helmet, echoing each kingdom's tower-roof language (ART_DIRECTION §3):
    red conical spire + finial, blue square pyramid, green low cone with a wide brim,
    yellow onion dome + gold point. Returns pieces (part: head)."""
    R = HEAD_R
    c = Vector(body.unleaned("head"))
    z0 = c.z + 0.1 * body.h
    trim = trim or kingdom_color(k, "trim")
    out = []
    if k == "red":
        out.append(lathe([(0.8, 0.0), (0.8, 0.18), (0.74, 0.42), (0.5, 0.86), (0.2, 1.22), (0.0, 1.45)], 10, metal))
        out.append(lathe([(0.84, -0.04), (0.86, 0.12), (0.84, 0.24)], 10, trim))
        out.append(lathe([(0.1, 1.3), (0.1, 1.6), (0.17, 1.66), (0.0, 1.95)], 6, trim))
        out.append(box(0.2, 0.14, 0.62, metal).move(0, -0.82, -0.42))  # nasal
    elif k == "blue":
        sq = lathe([(1.08, 0.0), (1.1, 0.26), (0.98, 0.42), (0.0, 1.2)], 4, metal, phase=math.pi / 4)
        out.append(sq.scale(1, 0.92, 1))
        out.append(lathe([(1.13, -0.04), (1.15, 0.12), (1.12, 0.26)], 4, trim, phase=math.pi / 4).scale(1, 0.92, 1))
        out.append(ellipsoid(0.14, 0.14, 0.14, trim, 6, 4).move(0, 0, 1.24))
        for s in (-1, 1):  # cheek guards
            out.append(box(0.16, 0.5, 0.62, metal).move(s * 0.68, -0.08, -0.6))
    elif k == "green":
        out.append(lathe([(1.32, -0.04), (1.36, 0.06), (0.86, 0.2), (0.8, 0.42), (0.52, 0.82), (0.0, 0.96)], 10,
                         metal))
        out.append(lathe([(1.38, -0.08), (1.4, 0.06), (1.34, 0.12)], 10, trim))
        out.append(lathe([(0.84, 0.18), (0.83, 0.34)], 10, trim))
    else:  # yellow onion
        out.append(lathe([(0.8, 0.0), (0.82, 0.22), (0.9, 0.5), (0.72, 0.9), (0.32, 1.16), (0.12, 1.36),
                          (0.0, 1.5)], 10, metal))
        out.append(lathe([(0.84, -0.04), (0.88, 0.12), (0.86, 0.26)], 10, trim))
        out.append(lathe([(0.0, 1.32), (0.12, 1.4), (0.14, 1.62), (0.0, 1.9)], 6, "gold"))
    top = 0.0
    for p in out:
        p.scale(1, 1, body.h).move(c.x, c.y, z0)
        p.paint(grad=("range", 0.35, 0.95))
        top = max(top, p.bounds()[1].z)
    return [body.upper(p) for p in out], top


# ------------------------------------------------------------------ weapons and tools


def spear(base, length, k, head="leaf", pennant=True):
    """Vertical spear standing at `base` (x, y, z). Returns pieces."""
    x, y, z = base
    out = [cylinder(0.11, 0.1, length, 6, "wood").move(x, y, z).paint(grad=("range", 0.3, 0.85))]
    out.append(cylinder(0.14, 0.13, 0.4, 6, "iron_dark").move(x, y, z + length - 0.3))
    top = z + length + 0.1
    if head == "pike":
        blade = lathe([(0.14, 0.0), (0.2, 0.2), (0.12, 0.9), (0.0, 1.5)], 4, "steel", phase=0.0).scale(1, 0.5, 1)
    elif head == "wing":
        blade = lathe([(0.14, 0.0), (0.26, 0.35), (0.22, 0.75), (0.0, 1.3)], 4, "steel", phase=0.0).scale(1, 0.45, 1)
        out.append(box(0.7, 0.12, 0.14, "iron").move(x, y, top - 0.05))
    elif head == "broad":
        blade = lathe([(0.14, 0.0), (0.36, 0.3), (0.3, 0.7), (0.0, 1.25)], 4, "steel", phase=0.0).scale(1, 0.4, 1)
    else:
        blade = lathe([(0.14, 0.0), (0.3, 0.42), (0.22, 0.85), (0.0, 1.35)], 4, "steel", phase=0.0).scale(1, 0.42, 1)
    out.append(blade.move(x, y, top - 0.1).paint(grad=("range", 0.45, 1.0)))
    out.append(cylinder(0.13, 0.11, 0.25, 6, "iron_dark").move(x, y, z - 0.02))  # butt cap
    if pennant:
        out += pennant_flag((x, y, top - 1.15), k, 1.5, 0.8)
    return out


def pennant_flag(attach, k, length=1.5, height=0.8, side=-1, t=0.1):
    """Tapered pennant flying to `side` (-1 = -X) from a vertical pole at `attach` (top edge)."""
    x0, y0, z0 = attach
    rings = []
    n = 4
    for i in range(n + 1):
        u = i / n
        hh = height * (1 - 0.82 * u)
        xx = x0 + side * (0.08 + length * u)
        yy = y0 + 0.14 * math.sin(u * math.pi * 1.5)
        zt = z0 - 0.12 * u
        rings.append([Vector((xx, yy - t / 2, zt)), Vector((xx, yy - t / 2, zt - hh)),
                      Vector((xx, yy + t / 2, zt - hh)), Vector((xx, yy + t / 2, zt))])
    p = loft_rings(rings, kingdom_color(k, "cloth")).paint(grad=("range", 0.4, 0.95))
    stripe = []
    for i in range(n + 1):
        u = i / n
        hh = height * (1 - 0.82 * u)
        xx = x0 + side * (0.08 + length * u)
        yy = y0 + 0.14 * math.sin(u * math.pi * 1.5)
        zm = z0 - 0.12 * u - hh * 0.5
        stripe.append([Vector((xx, yy - t / 2 - 0.03, zm + hh * 0.14)), Vector((xx, yy - t / 2 - 0.03, zm - hh * 0.14)),
                       Vector((xx, yy + t / 2 + 0.03, zm - hh * 0.14)), Vector((xx, yy + t / 2 + 0.03, zm + hh * 0.14))])
    s = loft_rings(stripe, kingdom_color(k, "trim")).paint(grad=0.75)
    return [p, s]


def bow(hand, length, k, outward=1, recurve=0.0, color="wood", grip="leather"):
    """Bow held vertically at `hand` in the XZ plane, belly towards the body, tips `outward` (+X).
    Returns pieces."""
    hx, hy, hz = hand
    pts, radii = [], []
    n = 9
    half = length / 2
    for i in range(n):
        u = -1 + 2 * i / (n - 1)
        x = outward * 0.42 * u * u
        if recurve and abs(u) > 0.7:
            x -= outward * recurve * ((abs(u) - 0.7) / 0.3) ** 2
        pts.append(Vector((hx + x, hy, hz + u * half)))
        radii.append(0.13 - 0.06 * abs(u))
    out = [tube(pts, radii, 6, color).paint(grad=("range", 0.3, 0.9))]
    out.append(cylinder(0.15, 0.15, 0.6, 6, grip).move(hx, hy, hz - 0.3))
    tip_t, tip_b = pts[-1], pts[0]
    out.append(tube([tip_b + Vector((0, 0, 0.05)), tip_t - Vector((0, 0, 0.05))], [0.05, 0.05], 4, "cloth_white"))
    for tp in (tip_t, tip_b):
        out.append(ellipsoid(0.09, 0.09, 0.09, kingdom_color(k, "trim"), 6, 3).move(*tp))
    return out


def quiver(base, axis, k, length=1.7, arrows=5, color="leather"):
    """Quiver tube from `base` along `axis`, arrows with kingdom-coloured fletching."""
    ax = Vector(axis).normalized()
    b0 = Vector(base)
    out = [along(lathe([(0.27, 0.0), (0.3, length * 0.9), (0.33, length)], 8, color), ax).move(*b0)]
    out.append(along(lathe([(0.35, length - 0.08), (0.35, length + 0.1)], 8, "leather"), ax).move(*b0))
    out.append(along(lathe([(0.32, length * 0.25), (0.32, length * 0.35)], 8, kingdom_color(k, "trim")), ax).move(*b0))
    top = b0 + ax * length
    perp = ax.cross(Vector((0, 1, 0))).normalized()
    perp2 = ax.cross(perp).normalized()
    for i in range(arrows):
        a = math.tau * i / arrows
        off = perp * math.cos(a) * 0.15 + perp2 * math.sin(a) * 0.15
        tip = top + off + ax * (0.42 + 0.1 * (i % 2))
        out.append(tube([top + off - ax * 0.3, tip], [0.045, 0.045], 4, "wood_pale"))
        fl = kit.oriented_box(tip - ax * 0.4, tip + ax * 0.04, 0.26, 0.07, kingdom_color(k, "cloth_light"), perp2)
        out.append(fl)
    return out


def sword(hand, direction, blade=2.4, k=None):
    """Sword whose grip sits in `hand`, blade pointing along `direction`."""
    d = Vector(direction).normalized()
    hc = Vector(hand)
    trim = kingdom_color(k, "trim") if k else "gold"
    out = []
    out.append(along(cylinder(0.1, 0.1, 0.62, 6, "leather"), d).move(*(hc - d * 0.3)))
    out.append(along(ellipsoid(0.16, 0.16, 0.16, trim, 6, 4), d).move(*(hc - d * 0.38)))
    g = kit.oriented_box(hc + d * 0.32 + Vector((-0.5, 0, 0)), hc + d * 0.32 + Vector((0.5, 0, 0)), 0.18, 0.2, trim,
                         Vector((0, -1, 0)))
    out.append(g)
    bl = lathe([(0.16, 0.0), (0.15, blade * 0.85), (0.0, blade)], 4, "steel", phase=0.0).scale(1, 0.35, 1)
    out.append(along(bl, d).move(*(hc + d * 0.36)).paint(grad=("range", 0.5, 1.0)))
    return out


def hammer(hand, direction, color="wood"):
    d = Vector(direction).normalized()
    hc = Vector(hand)
    out = [along(cylinder(0.11, 0.1, 1.9, 6, color), d).move(*(hc - d * 0.35))]
    head_c = hc + d * 1.45
    hd = kit.bbox(0.5, 0.5, 0.95, "iron_dark", 0.08, base=False)
    hd.rotate(math.pi / 2, "X")
    out.append(hd.move(*head_c).paint(grad=("range", 0.4, 0.9)))
    return out


def pitchfork(base, length, side=-1):
    x, y, z = base
    out = [cylinder(0.1, 0.09, length, 6, "wood_light").move(x, y, z)]
    top = z + length
    out.append(box(0.9, 0.14, 0.16, "iron").move(x, y, top))
    for u in (-0.38, 0.0, 0.38):
        out.append(lathe([(0.06, 0.0), (0.06, 0.8), (0.0, 1.0)], 4, "iron").move(x + u, y, top + 0.1))
    return out


def basket(center, color="straw", r=0.62, hgt=0.62):
    cx, cy, cz = center
    out = [lathe([(r * 0.78, 0.0), (r, hgt * 0.75), (r * 1.06, hgt), (r * 0.96, hgt - 0.02), (0.0, hgt * 0.92)], 10,
                 color).move(cx, cy, cz)]
    out.append(lathe([(r * 1.07, hgt - 0.12), (r * 1.1, hgt + 0.02)], 10, "hay_dark").move(cx, cy, cz))
    hdl = tube([(cx - r * 0.9, cy, cz + hgt), (cx - r * 0.6, cy, cz + hgt + 0.55), (cx, cy, cz + hgt + 0.72),
                (cx + r * 0.6, cy, cz + hgt + 0.55), (cx + r * 0.9, cy, cz + hgt)], [0.07] * 5, 5, "hay_dark")
    out.append(hdl)
    for i, col in enumerate(("apple_red", "cabbage", "apple_red")):
        out.append(ellipsoid(0.2, 0.2, 0.18, col, 6, 4).move(cx - 0.22 + i * 0.22, cy + (0.1 if i == 1 else -0.08),
                                                            cz + hgt))
    return out


def pouch(center, color="leather", r=0.32):
    cx, cy, cz = center
    out = [lathe([(0.0, -r), (r * 0.9, -r * 0.6), (r, 0.0), (r * 0.55, r * 0.75), (r * 0.45, r * 0.95), (0.0, r)], 8,
                 color).move(cx, cy, cz)]
    out.append(lathe([(r * 0.52, r * 0.7), (r * 0.52, r * 0.88)], 8, "gold").move(cx, cy, cz))
    return out


def stick(base, top, color="bark"):
    out = [tube([base, (Vector(base) + Vector(top)) / 2 + Vector((0.05, 0, 0)), top], [0.12, 0.11, 0.12], 6, color)]
    out.append(ellipsoid(0.2, 0.2, 0.22, "bark_dark", 6, 4).move(*Vector(top)))
    return out


def great_helm(body, k, metal="armor"):
    """Closed knight's helm enclosing the head (eye slit + cross), kingdom-shaped top:
    red sugarloaf + gold crown, blue flat top + square pyramid crest, green round bascinet +
    oak-leaf crest, yellow onion dome + gold point. Returns (pieces, top_z)."""
    c = Vector(body.unleaned("head"))
    h = body.h
    trim = kingdom_color(k, "trim")
    base = [(0.7, -0.78), (0.8, -0.5), (0.83, 0.0), (0.82, 0.42)]
    if k == "red":
        prof = base + [(0.72, 0.72), (0.42, 1.08), (0.0, 1.42)]
    elif k == "blue":
        prof = base + [(0.82, 0.74), (0.74, 0.8), (0.0, 0.82)]
    elif k == "green":
        prof = base + [(0.7, 0.8), (0.4, 1.02), (0.0, 1.1)]
    else:
        prof = base + [(0.88, 0.62), (0.7, 0.94), (0.3, 1.18), (0.1, 1.36), (0.0, 1.46)]
    out = [lathe(prof, 10, metal).paint(grad=("range", 0.3, 0.95))]
    out.append(box(0.82, 0.18, 0.15, "black").move(0, -0.72, 0.0))  # eye slit
    out.append(box(0.2, 0.14, 0.95, trim).move(0, -0.82, -0.62))  # vertical band
    out.append(lathe([(0.86, 0.12), (0.87, 0.3)], 10, trim))  # brow band
    top = max(z for _, z in prof)
    if k == "red":  # crown circlet
        out.append(lathe([(0.75, 0.62), (0.78, 0.86)], 10, "gold"))
        for i in range(5):
            a = math.tau * i / 5 - math.pi / 2
            out.append(lathe([(0.12, 0.0), (0.0, 0.34)], 4, "gold").move(math.cos(a) * 0.72, math.sin(a) * 0.72, 0.82))
    elif k == "blue":
        out.append(lathe([(0.42, 0.0), (0.0, 0.42)], 4, trim, phase=math.pi / 4).move(0, 0, 0.8))
        top += 0.4
    elif k == "green":
        lf = slab([(x * 0.95, z * 0.95) for x, z in emblem_poly("green")], 0.12, trim)
        out.append(lf.move(0, 0.05, 0.92))
        top += 0.85
    else:
        out.append(lathe([(0.0, 1.4), (0.12, 1.46), (0.13, 1.66), (0.0, 1.92)], 6, "gold"))
        top = 1.92
    for p in out:
        p.scale(1, 0.96, h).move(c.x, c.y, c.z)
    return [body.upper(p) for p in out], c.z + top * h


def axe(hand, up=2.0, down=0.9, side=-1):
    """Bearded axe held upright; blade towards `side` (x)."""
    hx, hy, hz = hand
    out = [cylinder(0.11, 0.1, up + down, 6, "wood").move(hx, hy, hz - down)]
    top = hz + up
    blade = [(0.0, 0.0), (0.55, -0.15), (0.85, -0.55), (0.95, 0.25), (0.7, 0.5), (0.0, 0.42)]
    bl = slab([(side * x, z) for x, z in blade], 0.14, "steel").paint(grad=("range", 0.45, 1.0))
    out.append(bl.move(hx, hy, top - 0.55))
    out.append(box(0.3, 0.2, 0.5, "iron_dark").move(hx, hy, top - 0.55))
    out.append(lathe([(0.12, 0.0), (0.0, 0.3)], 4, "iron").move(hx, hy, top))
    return out


def mace(hand, direction, length=1.9):
    d = Vector(direction).normalized()
    hc = Vector(hand)
    out = [along(cylinder(0.11, 0.1, length, 6, "wood_dark"), d).move(*(hc - d * 0.35))]
    hd = hc + d * (length - 0.3)
    out.append(ellipsoid(0.3, 0.3, 0.36, "iron", 8, 4).move(*hd))
    for i in range(4):
        a = math.tau * i / 4
        out.append(along(box(0.12, 0.44, 0.62, "steel", base=False), d).rotate(a, "Z").move(*hd))
    return out


__all__ = ["KINGDOMS", "BASE", "HEAD_R", "ARM_POSES", "Body", "ellipsoid", "along", "elathe", "slab", "shrink",
           "interp", "emblem_poly", "sun", "emblem", "kite_poly", "heater_poly", "almond_poly", "round_poly", "shield", "hair_cap",
           "hair_long", "beard", "hood", "brimmed_hat", "scarf_head", "helmet", "spear", "pennant_flag", "bow",
           "quiver", "sword", "hammer", "great_helm", "axe", "mace", "pitchfork", "basket", "pouch", "stick"]
