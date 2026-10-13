"""Kingdom soldiers (static NPC visual prototypes, rig later): spearman, archer and knight
for each of the four kingdoms.

Kingdom identity at 60 studs comes from tabard + shield + pennant/hood colours with the
kingdom emblem (red flame, blue star, green oak leaf, yellow sun), and is backed up by SHAPE
for colour-blind players: helmets echo each kingdom's tower roofs (red conical spire, blue
square pyramid, green wide-brim low cone, yellow onion dome).

Every body part is a separate closed shell (see _char_common.py); rig_* sockets carry the
joint pivots. Faces -Y; the character's right hand (spear, sword) is on -X.
"""

import math

from lib import kit
from lib.geo import Vector, box, cylinder, lathe, tube
from lib.palette import kingdom_color

from generators import _char_common as C

NAME = "char_soldier"
VERSION = 1
CATEGORY = "char"
BUDGET = "character"
COLLISION = {"fidelity": "Box"}
CHECKS = {"min_pieces": 45, "min_sockets": 3, "min_kingdom_marks": 3}
DEFAULT_VARIANTS = 12
HERO_VIEW = {"azimuth": 30, "elevation": 10}
LINEUP_GAP = 2.5
GAMEPLAY_DISTANCE = 40.0

KINGDOM_CYCLE = ("red", "blue", "green", "yellow")
ROLES = ("spearman", "archer", "knight")
SKINS = ("skin_1", "skin_2", "skin_3", "skin_4")
HAIRS = ("hair_dark", "hair_brown", "hair_blond", "hair_red")

SPEAR = {  # kingdom -> (spear length, head style, tilt sideways, tilt forward)
    "red": (8.2, "leaf", 0.0, 0.0),
    "blue": (8.9, "pike", -0.13, 0.0),
    "green": (7.7, "wing", 0.1, -0.08),
    "yellow": (8.4, "broad", 0.0, -0.16),
}
# kingdom shield shapes (shape backs up colour for colour-blind players)
SHIELD = {
    "red": lambda: C.kite_poly(1.62, 2.55),
    "blue": lambda: C.heater_poly(1.75, 2.15),
    "green": lambda: C.round_poly(1.0, 12),
    "yellow": lambda: C.almond_poly(1.5, 2.7),
}


def _tilt(pieces, pivot, side, fwd):
    px, py, pz = pivot
    for pc in pieces:
        pc.move(-px, -py, -pz)
        if side:
            pc.rotate(side, "Y")
        if fwd:
            pc.rotate(fwd, "X")
        pc.move(px, py, pz)
    return pieces


def variants(n, seed):
    out = []
    for i in range(n):
        role = ROLES[(i // 4) % 3]
        out.append({
            "kingdom": KINGDOM_CYCLE[i % 4],
            "role": role,
            "skin": SKINS[(i * 3 + i // 4) % 4],
            "hair": HAIRS[(i * 5 + 1) % 4],
            "seed": seed * 1000 + i,
        })
    return out


def _tabard(b, body, k, z_bot=1.45, z_top=3.95, w=0.64, flare=0.08, emblem_size=0.82, back=True, trim=True,
            emblem_z=3.28):
    t, gap = 0.13, 0.05
    cloth = kingdom_color(k, "cloth")
    b.add(body.upper(body.panel(z_bot, z_top, w * 1.04, w * 0.92, cloth, t=t, flare=flare, gap=gap)), tag="torso")
    if back:
        b.add(body.upper(body.panel(z_bot, z_top, w * 1.04, w * 0.92, cloth, back=True, t=t, flare=flare, gap=gap)),
              tag="torso")
    if trim:
        for bk in ((False, True) if back else (False,)):
            hem = body.panel(z_bot - 0.02, z_bot + 0.2, w * 1.07, w * 1.06, kingdom_color(k, "trim"), back=bk,
                             t=t + 0.04, flare=flare, gap=gap - 0.01)
            b.add(body.upper(hem), tag="torso")
    zc = emblem_z * body.h
    fy = body.front_y(zc) - gap - t
    for e in C.emblem(k, emblem_size, 0.08, outline=None):
        b.add(body.upper(e.move(0, fy - 0.03, zc)), tag="torso")
    return 1


def _gambeson_rings(b, body, color):
    """Quilting rings on the gambeson sleeves (secondary detail that reads as padding)."""
    for side in ("l", "r"):
        sh, el = body.j["shoulder_" + side], body.j["elbow_" + side]
        for u in (0.45, 0.8):
            p = sh + (el - sh) * u
            d = (el - sh).normalized()
            b.add(tube([p - d * 0.06, p + d * 0.06], [0.315, 0.315], 8, color), tag="arm_" + side)


def build_spearman(b, p, k):
    rng = b.rng
    body = C.Body(h=rng.uniform(0.98, 1.03), w=rng.uniform(0.98, 1.06), arm_r="grip", arm_l="rest")
    gamb = "apron"
    pants = rng.choice(("cloth_brown", "cloth_grey", "cloth_grey"))
    body.build(b, p["skin"], gamb, gamb, pants, "leather", cuff="cloth_brown", boot_cuff="wood_light",
               gloves="leather")
    b.add(body.skirt(2.62, 1.6, 0.68, 0.8, gamb), tag="pelvis")
    marks = _tabard(b, body, k)
    b.add(body.belt(2.55, "leather", kingdom_color(k, "trim"), over=0.17), tag="torso")
    # helmet over a short hair fringe
    b.add(C.hair_cap(body, p["hair"], front=0.3), tag="head")
    hel, top = C.helmet(body, k)
    b.add(hel, tag="helmet")
    # spear in the right hand, planted beside the right foot
    hr = body.j["hand_r"]
    length, style, ts, tf = SPEAR[k]
    b.add(_tilt(C.spear((hr.x, hr.y, 0.02), length, k, head=style), hr, ts, tf), tag="weapon")
    marks += 1
    # kite shield resting on its tip beside the left leg, held by the left hand
    hl = body.j["hand_l"]
    th = 0.6
    n = Vector((math.sin(th), -math.cos(th), 0))
    pc = Vector((hl.x, hl.y, 0)) + n * 0.34
    poly = SHIELD[k]()
    pieces, _ = C.shield(k, poly, 0.95 if k != "green" else 1.05, boss=False)
    lift = 0.03 if k in ("red", "yellow") else 0.35
    for pc_ in pieces:
        b.add(pc_.rotate(th, "Z").move(pc.x, pc.y, lift), tag="shield")
    marks += 1
    # short sword on the left hip
    b.add(tube([(0.92, 0.05, 2.5), (1.02, 0.2, 1.3)], [0.13, 0.11], 6, "leather"), tag="torso")
    b.add(box(0.5, 0.14, 0.14, kingdom_color(k, "trim")).move(0.9, 0.03, 2.5), tag="torso")
    b.stats["kingdom_marks"] = marks
    body.sockets(b, top)
    return body


def build_archer(b, p, k):
    rng = b.rng
    bowlen, recurve, quiv, cap = {
        "red": (4.3, 0.0, "back", "tail"),
        "blue": (3.7, 0.28, "back", "peak"),
        "green": (4.5, 0.0, "back", "bycocket"),
        "yellow": (3.3, 0.38, "hip", "peak"),
    }[k]
    body = C.Body(h=rng.uniform(0.97, 1.02), w=rng.uniform(0.94, 1.0), arm_r="low",
                  arm_l="carry" if k == "yellow" else "rest")
    jerkin = rng.choice(("tunic_brown", "leather", "tunic_green" if k != "green" else "tunic_brown"))
    pants = rng.choice(("cloth_brown", "cloth_grey", "tunic_cream"))
    body.build(b, p["skin"], jerkin, "tunic_cream", pants, "leather", cuff="leather", boot_cuff="wood_light")
    b.add(body.skirt(2.62, 1.75, 0.68, 0.78, jerkin, dags=8), tag="pelvis")
    marks = _tabard(b, body, k, z_bot=1.7, z_top=3.85, w=0.58, flare=0.06, emblem_size=0.62, back=False, trim=True,
                    emblem_z=2.92)
    b.add(body.belt(2.55, "leather", "iron", over=0.17), tag="torso")
    # bracer on the bow arm
    el, wr = body.j["elbow_l"], body.j["wrist_l"]
    b.add(tube([el + (wr - el) * 0.35, wr], [0.3, 0.27], 8, "leather"), tag="arm_l")
    # headwear
    cloth = kingdom_color(k, "cloth")
    top = body.head_top.z
    if cap == "bycocket":
        hat = C.brimmed_hat(body, kingdom_color(k, "cloth_dark"), brim_r=1.05, crown_r=0.72, crown_h=0.6,
                            z_off=0.3, cone=True)
        # upturned back brim + feather
        c = body.head_c
        hat.append(box(1.5, 0.22, 0.5, kingdom_color(k, "cloth_dark")).rotate(-0.5, "X").move(c.x, c.y + 0.82,
                                                                                            c.z + 0.36))
        hat.append(tube([(c.x + 0.5, c.y + 0.3, c.z + 0.6), (c.x + 0.85, c.y + 0.7, c.z + 1.2),
                         (c.x + 1.0, c.y + 1.1, c.z + 1.6)], [0.12, 0.14, 0.04], 6, "flower_red"))
        b.add(hat, tag="head")
        b.add(C.hood(body, cloth, cape=None, dags=10, cape_len=0.5)[1:], tag="torso")  # capelet only
        top = c.z + 1.25
    else:
        tail = 1.1 if cap == "tail" else 0.0
        peak = 0.55 if cap == "peak" else 0.0
        hd = C.hood(body, cloth, tail=tail, peak=peak, dags=10 if k != "yellow" else 0, cape_len=0.5)
        b.add(hd, tag="head")
        top = body.head_c.z + (1.22 + peak) * C.HEAD_R
    marks += 1
    if k == "blue":  # travelling cloak down to the calves
        b.add(body.panel(1.0, 3.95, 0.98, 0.9, kingdom_color(k, "cloth_dark"), back=True, t=0.14, flare=0.45,
                         gap=0.24), tag="torso")
    if k == "yellow":  # gold circlet over the hood
        c = body.head_c
        b.add(lathe([(0.8, 0.0), (0.82, 0.16)], 10, "gold").move(c.x, c.y + 0.14, c.z + 0.28), tag="head")
    # bow in the left hand
    hl = body.j["hand_l"]
    bw = C.bow(hl, bowlen, k, outward=1, recurve=recurve)
    if k == "yellow":  # composite bow carried slanted across the front
        _tilt(bw, hl, -0.55, 0.0)
    b.add(bw, tag="weapon")
    # quiver
    if quiv == "back":
        b.add(C.quiver((0.42, 0.74, 2.45), (-0.9, 0.25, 1.0), k, length=1.95), tag="quiver")
        b.add(kit.oriented_box((0.8, -0.6, 2.8), (-0.62, -0.68, 3.95), 0.2, 0.1, "leather", Vector((0, -1, 0))),
              tag="torso")
    else:
        b.add(C.quiver((-1.05, 0.35, 1.25), (-0.18, 0.25, 1.0), k, length=1.45), tag="quiver")
    marks += 1
    # an arrow in the right hand
    hr = body.j["hand_r"]
    d = body.j["handdir_r"]
    b.add(tube([hr - d * 0.5, hr + d * 1.4], [0.05, 0.05], 4, "wood_pale"), tag="weapon")
    b.add(C.ellipsoid(0.09, 0.05, 0.18, "iron", 4, 3).move(*(hr + d * 1.45)), tag="weapon")
    b.stats["kingdom_marks"] = marks
    body.sockets(b, top)
    return body


KNIGHT = {  # kingdom -> (right-arm pose, weapon)
    "red": ("low", "sword_down"),
    "blue": ("grip", "sword_up"),
    "green": ("grip", "axe"),
    "yellow": ("low", "mace"),
}


def build_knight(b, p, k):
    rng = b.rng
    pose, weapon = KNIGHT[k]
    body = C.Body(h=rng.uniform(1.02, 1.05), w=rng.uniform(1.07, 1.12), arm_r=pose, arm_l="rest")
    plate, plate_l, plate_d = "armor", "armor_light", "armor_dark"
    body.build(b, p["skin"], plate, "chainmail", plate, plate_d, sleeves="long", forearm=plate, gloves=plate_d,
               head=False)
    # pauldrons and knee cops
    for side in ("l", "r"):
        sh = body.j["shoulder_" + side]
        s = 1 if side == "l" else -1
        pa = lathe([(0.0, -0.22), (0.52, -0.2), (0.6, 0.08), (0.46, 0.36), (0.0, 0.48)], 8, plate_l)
        b.add(pa.rotate(s * -0.38, "Y").move(sh.x + s * 0.08, sh.y, sh.z + 0.04), tag="arm_" + side)
        b.add(lathe([(0.62, -0.32), (0.66, -0.14)], 8, kingdom_color(k, "trim")).rotate(s * -0.38, "Y")
              .move(sh.x + s * 0.08, sh.y, sh.z + 0.04), tag="arm_" + side)
        kn = body.j["knee_" + side]
        b.add(C.ellipsoid(0.36, 0.3, 0.3, plate_l, 8, 3).move(kn.x, kn.y - 0.06, kn.z), tag="leg_" + side)
    b.add(body.skirt(2.62, 1.55, 0.7, 0.86, "chainmail"), tag="pelvis")
    # long surcoat in kingdom cloth + cape
    marks = _tabard(b, body, k, z_bot=1.2, z_top=3.95, w=0.7, flare=0.12, emblem_size=0.9)
    b.add(body.belt(2.5, "leather", "gold", over=0.17), tag="torso")
    cape = body.panel(0.75, 3.95, 1.05, 0.95, kingdom_color(k, "cloth_dark"), back=True, t=0.14, flare=0.4, gap=0.22)
    b.add(cape, tag="torso")
    # closed great helm (the helm is the head shell) + plume
    hel, top = C.great_helm(body, k, metal=plate)
    b.add(hel, tag="head")
    c = body.head_c
    pz = top - (0.45 if k in ("blue", "green") else 0.2)
    plume = tube([(c.x, c.y + 0.1, pz), (c.x, c.y + 0.45, pz + 0.55), (c.x, c.y + 1.0, pz + 0.5),
                  (c.x, c.y + 1.45, pz - 0.2)], [0.18, 0.28, 0.22, 0.08], 6, kingdom_color(k, "cloth_light"))
    b.add(plume, tag="head")
    marks += 1
    hr = body.j["hand_r"]
    if weapon == "sword_down":
        b.add(C.sword(hr, (0.05, -0.35, -1.0), 2.3, k), tag="weapon")
    elif weapon == "sword_up":
        b.add(C.sword(hr, (-0.04, 0.0, 1.0), 2.6, k), tag="weapon")
    elif weapon == "axe":
        b.add(C.axe(hr, 2.2, 1.1, side=-1), tag="weapon")
    else:
        b.add(C.mace(hr, (0.0, -0.25, -1.0)), tag="weapon")
    # big kingdom-shaped shield on the left side
    hl = body.j["hand_l"]
    th = 0.55
    n = Vector((math.sin(th), -math.cos(th), 0))
    pc = Vector((hl.x, hl.y, 0)) + n * 0.38
    poly = {"red": C.kite_poly(1.85, 2.9), "blue": C.heater_poly(2.0, 2.45), "green": C.round_poly(1.18, 12),
            "yellow": C.almond_poly(1.75, 3.0)}[k]
    pieces, _ = C.shield(k, poly, 1.15 if k != "green" else 1.3, boss=k == "green")
    lift = {"red": 0.05, "blue": 0.3, "green": 0.45, "yellow": 0.05}[k]
    for pc_ in pieces:
        b.add(pc_.rotate(th, "Z").move(pc.x, pc.y, lift), tag="shield")
    marks += 1
    b.stats["kingdom_marks"] = marks
    body.sockets(b, top + 0.35)
    return body


def build(b, p):
    k = p["kingdom"]
    role = p["role"]
    if role == "spearman":
        body = build_spearman(b, p, k)
    elif role == "archer":
        body = build_archer(b, p, k)
    else:
        body = build_knight(b, p, k)
    # body-only collision proxy (the mesh bounds include the spear/bow)
    r = body.j["root"]
    b.collision_box(r.x, r.y, 2.85 * body.h, 2.6 * body.w, 1.5, 5.7 * body.h, "body")
    b.stats["pieces"] = len(b.pieces)
