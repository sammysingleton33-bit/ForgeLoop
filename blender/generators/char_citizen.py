"""Village citizens (static NPC visual prototypes, rig later): peasant man, peasant woman,
farmer, merchant, blacksmith and elder.

Clothing is warm and neutral (tunic_*, cloth_*, apron, leather); each citizen wears ONE
kingdom accent in kingdom cloth (sash, bodice, neckerchief, hat, bandana, stole) taken from
params["kingdom"], so a village reads as belonging to its kingdom without looking military.

Every body part is a separate closed shell (see _char_common.py); rig_* sockets carry the
joint pivots. Faces -Y; the character's right hand is on -X.
"""

import math

from lib import kit
from lib.geo import Vector, box, cylinder, lathe, tube
from lib.palette import kingdom_color

from generators import _char_common as C

NAME = "char_citizen"
VERSION = 1
CATEGORY = "char"
BUDGET = "character"
COLLISION = {"fidelity": "Box"}
CHECKS = {"min_pieces": 35, "min_sockets": 3, "min_kingdom_accent": 1}
DEFAULT_VARIANTS = 6
HERO_VIEW = {"azimuth": 30, "elevation": 10}
LINEUP_GAP = 2.5
GAMEPLAY_DISTANCE = 40.0

KINGDOM_CYCLE = ("red", "blue", "green", "yellow")
KINDS = ("peasant_man", "peasant_woman", "farmer", "merchant", "blacksmith", "elder")
SKINS = ("skin_2", "skin_1", "skin_3", "skin_1", "skin_4", "skin_2")
HAIRS = ("hair_brown", "hair_red", "hair_blond", "hair_dark", "hair_dark", "hair_brown")


def variants(n, seed):
    out = []
    for i in range(n):
        out.append({
            "kingdom": KINGDOM_CYCLE[i % 4],
            "kind": KINDS[i % len(KINDS)],
            "skin": SKINS[i % len(SKINS)],
            "hair": HAIRS[i % len(HAIRS)],
            "seed": seed * 1000 + i,
        })
    return out


# ------------------------------------------------------------------ props


def bucket(hand):
    hx, hy, hz = hand
    zb = hz - 1.35
    out = [lathe([(0.42, 0.0), (0.5, 0.85), (0.47, 0.85 - 0.02), (0.0, 0.7)], 8, "wood").move(hx, hy, zb)]
    for z in (0.15, 0.62):
        out.append(lathe([(0.47 + z * 0.09, z), (0.49 + z * 0.09, z + 0.12)], 8, "iron_dark").move(hx, hy, zb))
    out.append(tube([(hx - 0.48, hy, zb + 0.82), (hx - 0.3, hy, zb + 1.25), (hx, hy, zb + 1.38),
                     (hx + 0.3, hy, zb + 1.25), (hx + 0.48, hy, zb + 0.82)], [0.05] * 5, 4, "iron"))
    out.append(lathe([(0.44, 0.0), (0.44, 0.06)], 8, "water").move(hx, hy, zb + 0.66))
    return out


def sash_tail(body, k, z, side=1):
    """Hanging end of a knotted waist sash (kingdom accent)."""
    h = body.h
    x = side * body.half_w(z * h) * 0.6
    y = body.front_y(z * h, x) - 0.12
    col = kingdom_color(k, "cloth")
    out = [C.ellipsoid(0.2, 0.14, 0.17, col, 6, 4).move(x, y, z * h)]
    out.append(tube([(x, y - 0.02, z * h - 0.05), (x + side * 0.08, y - 0.08, z * h - 0.55),
                     (x + side * 0.05, y - 0.06, z * h - 0.95)], [0.13, 0.12, 0.1], 5, col))
    return out


# ------------------------------------------------------------------ kinds


def peasant_man(b, p, k, rng):
    body = C.Body(h=rng.uniform(0.98, 1.02), w=rng.uniform(0.98, 1.04), arm_r="low", arm_l="rest")
    tunic = rng.choice(("tunic_brown", "tunic_cream"))
    hood_c = "tunic_green" if k != "green" else "cloth_brown"
    body.build(b, p["skin"], tunic, tunic, "cloth_grey", "leather", cuff="cloth_brown", boot_cuff="wood_light")
    b.add(body.skirt(2.62, 1.55, 0.68, 0.82, tunic, dags=0), tag="pelvis")
    b.add(body.belt(2.55, kingdom_color(k, "cloth"), "iron"), tag="torso")
    b.add(sash_tail(body, k, 2.5), tag="torso")
    b.add(C.hood(body, hood_c, tail=0.6, dags=10), tag="head")
    b.add(bucket(body.j["hand_r"]), tag="prop")
    b.stats["kingdom_accent"] = 1
    return body, body.head_c.z + 1.25 * C.HEAD_R


def peasant_woman(b, p, k, rng):
    body = C.Body(h=rng.uniform(0.95, 0.98), w=0.92, arm_r="rest", arm_l="carry", fem=True)
    dress = rng.choice(("cloth_brown", "tunic_brown"))
    body.build(b, p["skin"], dress, "cloth_white", "cloth_brown", "leather", legs=False, cuff=dress)
    for side in ("l", "r"):
        body.boot(b, side, "leather")
    r_bot = 1.08
    b.add(body.skirt(2.62, 0.14, 0.64, r_bot, dress), tag="pelvis")
    # apron over the skirt
    gap = 0.05
    base = -body.front_y(2.45 * body.h) * 1.02 + gap
    flare = r_bot * body.dy * 1.08 - base + 0.05
    b.add(body.panel(0.55, 2.5, 0.72, 0.56, "apron", t=0.1, flare=flare, gap=gap), tag="pelvis")
    b.add(body.belt(2.55, "apron", "apron", height=0.2), tag="torso")
    # bodice in kingdom cloth (accent)
    acc = kingdom_color(k, "cloth")
    b.add(body.panel(2.4, 3.55, 0.6, 0.62, acc, t=0.1, gap=0.03), tag="torso")
    b.add(body.panel(2.4, 3.55, 0.6, 0.62, acc, back=True, t=0.1, gap=0.03), tag="torso")
    for i in range(3):  # lacing
        z = (2.6 + i * 0.3) * body.h
        b.add(box(0.36, 0.06, 0.07, "cloth_white").move(0, body.front_y(z) - 0.15, z), tag="torso")
    # hair + headscarf
    b.add(C.hair_long(body, p["hair"]), tag="head")
    b.add(C.hair_cap(body, p["hair"], front=0.22, back=-0.3), tag="head")
    b.add(C.scarf_head(body, "canvas"), tag="head")
    c = body.head_c  # braid over the right shoulder
    b.add(tube([(c.x - 0.55, c.y + 0.05, c.z - 0.25), (c.x - 0.75, c.y - 0.2, c.z - 0.8),
                (c.x - 0.7, c.y - 0.42, c.z - 1.35)], [0.17, 0.15, 0.1], 6, p["hair"]), tag="head")
    # basket on the left forearm
    hl = body.j["hand_l"]
    b.add(C.basket((hl.x + 0.05, hl.y + 0.15, hl.z - 0.95), r=0.6, hgt=0.6), tag="prop")
    b.stats["kingdom_accent"] = 1
    return body, body.head_c.z + 1.22 * C.HEAD_R


def farmer(b, p, k, rng):
    body = C.Body(h=rng.uniform(1.0, 1.03), w=rng.uniform(0.98, 1.03), arm_r="grip", arm_l="rest")
    shirt = "tunic_cream"
    body.build(b, p["skin"], "tunic_green", shirt, "cloth_brown", "leather", sleeves="short",
               boot_cuff="wood_light")
    b.add(body.skirt(2.62, 1.7, 0.68, 0.78, "tunic_green"), tag="pelvis")
    b.add(body.belt(2.55, "rope", "wood"), tag="torso")
    # shirt collar showing above the jerkin and rolled sleeve cuffs
    for side in ("l", "r"):
        el = body.j["elbow_" + side]
        b.add(C.ellipsoid(0.32, 0.32, 0.2, shirt, 8, 3).move(*el), tag="arm_" + side)
    # neckerchief (kingdom accent)
    acc = kingdom_color(k, "cloth")
    z = 3.95 * body.h
    b.add(C.elathe([(0.62, z - 0.08), (0.5, z + 0.16)], 10, acc, body.sx * 0.9, body.dy * 1.12), tag="torso")
    tri = C.slab([(-0.58, 0.0), (0.58, 0.0), (0.0, -0.85)], 0.12, acc)
    b.add(tri.move(0, body.front_y(3.7 * body.h) - 0.08, z + 0.02), tag="torso")
    b.add(C.hair_cap(body, p["hair"]), tag="head")
    b.add(C.brimmed_hat(body, "straw", brim_r=1.42, crown_r=0.74, crown_h=0.6, band="hay_dark", z_off=0.28), tag="head")
    hr = body.j["hand_r"]
    b.add(C.pitchfork((hr.x, hr.y, 0.02), 5.6), tag="prop")
    b.stats["kingdom_accent"] = 1
    return body, body.head_c.z + 1.0


def merchant(b, p, k, rng):
    body = C.Body(h=rng.uniform(1.0, 1.02), w=1.14, arm_r="carry", arm_l="hip")
    coat = {"red": "tunic_red", "blue": "tunic_blue", "green": "tunic_green", "yellow": "tunic_brown"}[k]
    fur = "cloth_white"
    body.build(b, p["skin"], coat, coat, "cloth_grey", "leather", cuff=fur, boot_cuff=None)
    b.add(body.skirt(2.62, 0.75, 0.72, 1.02, coat), tag="pelvis")
    b.add(C.elathe([(1.06, 0.68 * body.h), (1.07, 0.88 * body.h)], 10, fur, 1.18 * body.w, body.dy * 1.1),
          tag="pelvis")
    # fur collar, gold chain + medallion, buttons
    z = 3.92 * body.h
    b.add(C.elathe([(0.7, z - 0.12), (0.76, z + 0.05), (0.55, z + 0.25)], 10, fur, body.sx * 0.95, body.dy * 1.2),
          tag="torso")
    chain = []
    for i in range(7):
        u = -1 + 2 * i / 6
        zz = (3.55 + 0.3 * u * u) * body.h
        x = u * 0.52
        chain.append(Vector((x, body.front_y(zz, x) - 0.05, zz)))
    b.add(tube(chain, [0.06] * 7, 4, "gold"), tag="torso")
    b.add(C.ellipsoid(0.16, 0.06, 0.16, "gold", 6, 3).move(0, body.front_y(3.5 * body.h) - 0.08, 3.48 * body.h),
          tag="torso")
    for i in range(3):
        zz = (2.75 + i * 0.25) * body.h
        b.add(C.ellipsoid(0.07, 0.05, 0.07, "gold", 4, 3).move(0, body.front_y(zz) - 0.02, zz), tag="torso")
    b.add(body.belt(2.62, "leather", "gold"), tag="torso")
    b.add(C.pouch((0.62 * body.w, body.front_y(2.3 * body.h, 0.62) - 0.2, 2.25 * body.h)), tag="prop")
    # coin purse in the right hand
    hr = body.j["hand_r"]
    b.add(C.pouch((hr.x, hr.y - 0.1, hr.z - 0.35), r=0.3), tag="prop")
    # beard + puffy chaperon hat (kingdom accent)
    b.add(C.hair_cap(body, p["hair"]), tag="head")
    b.add(C.beard(body, p["hair"], 0.85), tag="head")
    acc = kingdom_color(k, "cloth")
    c = body.head_c
    z0 = c.z + 0.3 * body.h
    roll = lathe([(0.66, -0.06), (0.88, -0.02), (0.98, 0.14), (0.9, 0.32), (0.66, 0.36)], 10, acc)
    crown = lathe([(0.68, 0.1), (0.78, 0.5), (0.55, 0.85), (0.0, 0.92)], 10, kingdom_color(k, "cloth_dark"))
    tail = tube([(0.35, 0.72, 0.2), (0.45, 0.98, -0.25), (0.42, 1.08, -0.85), (0.36, 1.04, -1.3)],
                [0.2, 0.17, 0.14, 0.1], 6, acc)
    for pc in (roll, crown, tail):
        b.add(pc.move(c.x, c.y, z0).paint(grad=("range", 0.35, 0.95)), tag="head")
    b.stats["kingdom_accent"] = 1
    return body, z0 + 0.95


def blacksmith(b, p, k, rng):
    body = C.Body(h=rng.uniform(1.0, 1.03), w=1.16, arm_r="low", arm_l="rest")
    shirt = "cloth_grey"
    body.build(b, p["skin"], shirt, shirt, "cloth_brown", "leather", sleeves="none", gloves="leather",
               boot_cuff=None)
    for side in ("l", "r"):  # short sleeves + thick leather wrist guards
        sh, el, wr = body.j["shoulder_" + side], body.j["elbow_" + side], body.j["wrist_" + side]
        b.add(tube([sh, sh + (el - sh) * 0.45], [0.36, 0.34], 8, shirt), tag="arm_" + side)
        b.add(tube([wr - (wr - el).normalized() * 0.45, wr + (wr - el).normalized() * 0.05], [0.31, 0.31], 8,
                   "leather"), tag="arm_" + side)
    b.add(body.skirt(2.62, 1.85, 0.68, 0.76, shirt), tag="pelvis")
    # leather apron with a bib, neck strap and a tool pocket
    gap = 0.05
    base = -body.front_y(2.45 * body.h) * 1.02 + gap
    b.add(body.panel(1.05, 3.62, 0.74, 0.5, "leather", t=0.14, flare=0.3, gap=gap), tag="torso")
    b.add(tube([(-0.38, body.front_y(3.6) - 0.1, 3.6 * body.h), (-0.3, -0.1, 4.12 * body.h),
                (0.3, -0.1, 4.12 * body.h), (0.38, body.front_y(3.6) - 0.1, 3.6 * body.h)], [0.07] * 4, 4,
               "leather"), tag="torso")
    b.add(kit.bbox(0.7, 0.14, 0.55, "wood_dark", 0.05).move(0.18, -(base + 0.25) - 0.08, 1.8 * body.h), tag="torso")
    b.add(body.belt(2.55, "leather", "iron", over=0.15), tag="torso")
    # bald, big beard, kingdom bandana (accent)
    b.add(C.beard(body, p["hair"], 1.15), tag="head")
    acc = kingdom_color(k, "cloth")
    c = body.head_c
    band = C.elathe([(0.7, -0.02), (0.72, 0.22)], 12, acc, 1.0, 0.95).move(c.x, c.y, c.z + 0.26 * body.h)
    b.add(band, tag="head")
    for s in (-1, 1):
        b.add(tube([(c.x + s * 0.06, c.y + 0.7, c.z + 0.34), (c.x + s * 0.28, c.y + 0.92, c.z + 0.05),
                    (c.x + s * 0.34, c.y + 0.95, c.z - 0.3)], [0.12, 0.1, 0.07], 5, acc), tag="head")
    hr = body.j["hand_r"]
    b.add(C.hammer(hr, body.j["handdir_r"] + Vector((0, -0.25, 0))), tag="prop")
    b.stats["kingdom_accent"] = 1
    return body, body.head_top.z


def elder(b, p, k, rng):
    body = C.Body(h=0.95, w=0.96, lean=0.3, arm_r="stick", arm_l="rest")
    robe = rng.choice(("cloth_brown", "tunic_cream"))
    grey = "stone_pale"  # no grey hair swatch in palette v1 (requested: hair_grey)
    body.build(b, p["skin"], robe, robe, robe, "leather", legs=False, cuff="cloth_brown")
    for side in ("l", "r"):
        body.boot(b, side, "leather")
    b.add(body.skirt(2.62, 0.14, 0.66, 0.98, robe), tag="pelvis")
    b.add(body.upper(C.Body.belt(body, 2.6, "rope", "wood")[0]), tag="torso")
    # stole / shoulder cape in kingdom cloth (accent)
    b.add(C.hood(body, kingdom_color(k, "cloth"), dags=0, cape_r=1.18)[1:], tag="torso")
    # bald crown with grey side hair, long beard, bushy brows
    b.add(C.hair_cap(body, grey, front=0.55, back=-0.45), tag="head")
    c = Vector(body.unleaned("head"))
    b.add(body.upper(C.ellipsoid(0.52, 0.52, 0.28, p["skin"], 10, 4).move(c.x, c.y - 0.02, c.z + 0.5)), tag="head")
    b.add(C.beard(body, grey, 1.05), tag="head")
    b.add(body.upper(C.ellipsoid(0.36, 0.26, 0.6, grey, 8, 4).move(c.x, c.y - 0.52, c.z - 0.95)), tag="head")
    hr = body.j["hand_r"]
    b.add(C.stick((hr.x - 0.05, hr.y - 0.1, 0.0), (hr.x, hr.y, hr.z + 0.45)), tag="prop")
    b.stats["kingdom_accent"] = 1
    return body, body.head_top.z


KIND_FN = {"peasant_man": peasant_man, "peasant_woman": peasant_woman, "farmer": farmer, "merchant": merchant,
           "blacksmith": blacksmith, "elder": elder}


def build(b, p):
    k = p["kingdom"]
    body, top = KIND_FN[p["kind"]](b, p, k, b.rng)
    body.sockets(b, top)
    r = body.j["root"]
    b.collision_box(r.x, r.y, 2.85 * body.h, 2.6 * body.w, 1.6, 5.7 * body.h, "body")
    b.stats["pieces"] = len(b.pieces)
