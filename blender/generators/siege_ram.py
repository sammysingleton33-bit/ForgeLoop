"""Battering rams: an iron-capped log slung by ropes under a wheeled shed. Four covers so
the silhouettes differ, not just the colours:

  red     shed roofed with lashed wet hides at 40 deg over posts, kingdom drapes, ridge pennant
  blue    Frostmere "tortoise": steep 62 deg slate-shingle roof straight down to the rails (no
          walls), star shield on the open front gable, oversized steel ram head
  green   Thornwood steep 56 deg plank roof (shared-kit tile roof in timber), planked front hoarding
  yellow  low 24 deg roof of neutral hides draped long down the sides, gold-trimmed hem, front pavise

Front (ram head) faces Blender -Y. Sockets: crew_1 / crew_2 = pushing spots inside the shed
beside the log (ground level), ram_head = tip of the iron head (impact point for hits).
"""

import math

from lib import kit
from lib.geo import Vector, box, cylinder, lathe

from generators._kingdom_props_common import KINGDOMS, emblem, emblem_colors, kcol, rope, sheet, wheel
from generators.siege_catapult import EMB, drape, heater_shield, pennant

NAME = "siege_ram"
VERSION = 1
CATEGORY = "siege"
BUDGET = "siege"
COLLISION = {"fidelity": "Hull"}
CHECKS = {"min_wheels": 4, "min_rope": 2}
DEFAULT_VARIANTS = 4
HERO_VIEW = {"azimuth": 42, "elevation": 22}
ROOFS = {"red": "hides", "blue": "tortoise", "green": "planks", "yellow": "cloak"}
PITCH = {"hides": 40, "tortoise": 62, "planks": 56, "cloak": 24}


def variants(n, seed):
    return [{"kingdom": KINGDOMS[i % 4], "roof": ROOFS[KINGDOMS[i % 4]], "seed": seed * 1000 + i}
            for i in range(n)]


def asset_id(i, p):
    return f"{CATEGORY}_ram_{p['kingdom']}_{i // 4 + 1:02d}"


def beam(p0, p1, w, d, color="siege_wood", normal=(1, 0, 0), bev=0.0):
    return kit.oriented_box(p0, p1, w, d, color, Vector(normal), bev=bev)


def hide_patches(rng, nu, nv):
    """Irregular stitched hides: patches of 1-3 cells in a few leather tones."""
    tones = ("leather", "leather", "cloth_brown", "tunic_brown", "leather")
    patch = {}
    for jj in range(nv):
        for ii in range(nu):
            if (ii, jj) not in patch:
                c = rng.choice(tones)
                for di in range(rng.choice((1, 2, 2, 3))):
                    patch.setdefault((ii + di, jj), c)
                if rng.random() < 0.4:
                    patch.setdefault((ii, jj + 1), c)
    return patch


def build(b, p):
    rng = b.rng
    k = p["kingdom"]
    roof = p["roof"]
    L = {"hides": 13.4, "tortoise": 12.4, "planks": 13.8, "cloak": 13.0}[roof] + rng.uniform(-0.3, 0.3)
    Wd = 5.6 if roof == "tortoise" else 6.4
    R = 1.75
    zr = R - 0.4
    top = zr + 0.95
    ropes = 0
    # ---- chassis: rails, cross beams, axles, four spoked wheels
    for sx in (-1, 1):
        b.add(kit.bbox(0.9, L, 0.95, "siege_wood", 0.1).move(sx * Wd / 2, 0, zr))
    for y in (-L / 2 + 0.6, -L * 0.17, L * 0.17, L / 2 - 0.6):
        b.add(box(Wd + 1.2, 0.7, 0.6, "siege_wood_dark").move(0, y, zr + 0.2))
    yw = L / 2 - R - 0.5
    xw = Wd / 2 + 0.45 + 0.45 + 0.1
    for y in (-yw, yw):
        b.add(box(2 * xw, 0.6, 0.6, "siege_wood_dark").move(0, y, R - 0.3))
        for sx in (-1, 1):
            b.add([pc.move(sx * xw, y, R) for pc in wheel(R, 0.7, 6, 10, wood="wood", hub="siege_wood_dark")])
            b.stats["wheels"] = b.stats.get("wheels", 0) + 1
    for sx in (-1, 1):  # iron end straps
        for y in (-L / 2 + 0.3, L / 2 - 0.3):
            b.add(box(1.05, 0.25, 1.05, "iron_dark").move(sx * Wd / 2, y, zr - 0.05))

    pitch = PITCH[roof]
    ta = math.tan(math.radians(pitch))
    if roof == "tortoise":
        # ---- steep shingle roof straight off the rails; A-trusses carry the ridge beam
        span = Wd + 0.4
        rf, rise = kit.gable_roof(span, L - 0.4, pitch, overhang=0.25, gable_overhang=0.35, thickness=0.5,
                                  color=kcol(k, "roof"), rows=5, ridge_color=kcol(k, "roof_dark"), style="tile",
                                  rng=rng, trim=kcol(k, "trim"))
        for pc in rf:
            b.add(pc.move(0, 0, top + 0.05), tag="roof")
        posts_y = [-L / 2 + 0.7, 0.0, L / 2 - 0.7]
        zr_ = top + rise
        for y in posts_y:
            for sx in (-1, 1):
                b.add(beam((sx * (span / 2 - 0.2), y, top), (sx * 0.2, y, zr_ - 0.3), 0.55, 0.55, "siege_wood",
                           normal=(0, 1, 0)))
            b.add(box(span - 1.6, 0.45, 0.45, "siege_wood_dark").move(0, y, top + rise * 0.45))  # collar tie
        b.add(box(0.6, L - 0.8, 0.6, "siege_wood_dark").move(0, 0, zr_ - 1.4))  # ridge beam (ram hangs here)
        hang_z = zr_ - 1.4
        He = top + rise
        for pc in heater_shield(k, 2.0):  # star shield on the open front gable, above the ram head
            b.add(pc.move(0, -L / 2 - 0.35, top + rise * 0.66))
        b.add(box(1.6, 0.3, 0.3, "iron_dark").move(0, -L / 2 - 0.1, top + rise * 0.66 - 0.15))  # hanger bar
        pennant(b, k, 0.0, L / 2 - 0.5, top + rise + 0.2, rng, L=3.6, H=1.6)
    else:
        # ---- posts, tie beams, wall plates, side braces
        He = top + {"hides": 5.4, "planks": 4.9, "cloak": 5.0}[roof]
        posts_y = [-L / 2 + 0.9, 0.0, L / 2 - 0.9]
        for y in posts_y:
            for sx in (-1, 1):
                b.add(kit.bbox(0.65, 0.65, He - top + 0.1, "siege_wood", 0.07).move(sx * (Wd / 2 - 0.1), y, top - 0.1))
            b.add(box(Wd + 0.4, 0.55, 0.6, "siege_wood_dark").move(0, y, He - 0.6))  # tie beam
        for sx in (-1, 1):
            b.add(box(0.6, L - 1.0, 0.6, "siege_wood_dark").move(sx * (Wd / 2 - 0.1), 0, He - 0.6))  # wall plates
            for y0_, y1_ in zip(posts_y, posts_y[1:]):  # diagonal side braces
                b.add(beam((sx * (Wd / 2 - 0.1), y0_ + 0.3, top + 0.2), (sx * (Wd / 2 - 0.1), y1_ - 0.3, He - 0.7),
                           0.35, 0.35, "siege_wood_dark", normal=(1, 0, 0)))
        hang_z = He - 0.6
        rise = (Wd + 0.4) / 2 * ta
        if roof == "planks":
            rf, rise = kit.gable_roof(Wd + 0.4, L - 0.6, pitch, overhang=0.9, gable_overhang=0.5, thickness=0.5,
                                      color="wood", rows=4, ridge_color="wood_dark", style="tile", rng=rng,
                                      trim="siege_wood_dark")
            for pc in rf:
                b.add(pc.move(0, 0, He), tag="roof")
            # Thornwood front hoarding: planked gable screen above the ram, oak shield
            n = 7
            for i in range(n):
                x = -(Wd / 2) + Wd * (i + 0.5) / n
                hh = max(0.6, rise * (1 - abs(x) / (Wd / 2 + 0.2)))
                b.add(box(Wd / n - 0.06, 0.3, hh + 0.7, "wood_dark" if i % 2 else "wood")
                      .move(x, -L / 2 + 0.3, He - 0.7))
            for pc in heater_shield(k, 2.4):
                b.add(pc.move(0, -L / 2 + 0.05, He + 0.25))
        else:
            # hide roof over rafters and a ridge beam; red = 40 deg short eaves, yellow = 24 deg
            # with the hides cloaked far down the sides and a gold-trimmed hem
            cloak = roof == "cloak"
            b.add(box(0.6, L + 0.6, 0.6, "siege_wood_dark").move(0, 0, He + rise - 0.3))
            for y in posts_y:
                for sx in (-1, 1):
                    b.add(beam((sx * (Wd / 2 + 0.2), y, He - 0.3), (0.0, y, He + rise), 0.45, 0.45, "siege_wood",
                               normal=(0, 1, 0)))
            ov = 1.0
            us = [0.0, 0.25, 0.5, 0.75, 0.9, 1.0] if not cloak else [0.0, 0.3, 0.55, 0.7, 0.82, 0.93, 1.0]
            vs = [i / 8 for i in range(9)]
            for sx in (-1, 1):
                ph = rng.uniform(0, 6)
                patch = hide_patches(rng, len(us) - 1, len(vs) - 1)

                def pos(u, v, sx=sx, ph=ph):
                    y = -L / 2 - 0.2 + (L + 0.4) * v
                    if cloak and u > 0.7:  # past the eave the hide hangs down the side
                        f = (u - 0.7) / 0.3
                        x = sx * (Wd / 2 + 0.2 + ov + 0.15 * f)
                        z = He - 0.3 - ov * ta - f * 2.6 + 0.2 * math.sin(v * 15 + ph) * f
                        return (x, y, z)
                    uu = u / 0.7 if cloak else u
                    x = sx * uu * (Wd / 2 + 0.2 + ov)
                    z = He + rise + 0.25 - uu * (rise + ov * ta)
                    sag = 0.35 * math.sin(math.pi * ((v * (len(posts_y) - 1)) % 1.0)) * math.sin(math.pi * min(1, uu * 1.2))
                    hem = 0.25 * math.sin(v * 13 + ph) * uu ** 4 if not cloak else 0.0
                    return (x, y, z - sag + hem)

                def cols(kind, i, j, patch=patch):
                    if kind == "edge":
                        return "leather"
                    if cloak and i >= len(us) - 2:
                        return kcol(k, "cloth")  # gold trim band along the hem
                    return patch.get((i, j), "leather")

                b.add(sheet(us, vs, pos, 0.3, "leather", cols, normal="auto"), grad=("range", 0.3, 0.95), tag="roof")
            for y in (-L * 0.3, L * 0.3):  # rope lashings over the hides
                zz = He - 0.35 if not cloak else He - 0.3 - ov * ta - 0.3
                pts = [(-(Wd / 2 + 1.25), y, zz), (0.0, y, He + rise + 0.6), (Wd / 2 + 1.25, y, zz)]
                b.add(rope(pts, r=0.11, seg=4), tag="rope")
                ropes += 1
            if cloak:
                for sy in (-1, 1):  # gold ball finials on the ridge ends
                    b.add(lathe([(0.25, 0.0), (0.42, 0.25), (0.3, 0.6), (0.0, 0.75)], 6, "gold")
                          .move(0, sy * (L / 2 + 0.1), He + rise + 0.15))
                # pavise: tall sun shield standing on the nose beam in front of the ram, with a prop
                for pc in heater_shield(k, 3.0):
                    b.add(pc.move(0, -L / 2 - 0.25, top + 3.0))
                b.add(beam((0, -L / 2 + 0.1, top + 0.1), (0, -L / 2 + 0.05, top + 4.4), 0.3, 0.3, "siege_wood_dark"))
            else:
                for sx in (-1, 1):
                    drape(b, k, sx * (Wd / 2 + 0.55), -yw + R + 0.3, yw - R - 0.3, top - 0.05, 1.5, rng)
                pennant(b, k, 0.0, L / 2 - 0.2, He + rise + 0.2, rng, L=3.4, H=1.5)
        for sx in (-1, 1):
            if roof != "cloak":
                for pc in heater_shield(k, 2.2):
                    b.add(pc.rotate(sx * math.pi / 2, "Z").move(sx * (Wd / 2 + 0.75), 0.4, top + 1.6))

    # ---- the ram: log on rope slings, iron head with kingdom plates, bands
    big = roof == "tortoise"
    rl = 0.9 if big else 0.72
    y_head = -L / 2 - (3.6 if big else 2.6)
    y_tail = L / 2 - 0.6
    zl = top + (2.3 if big else 2.0)
    log = cylinder(rl, rl * 0.92, y_tail - y_head - 1.6, 8, "bark").rotate(math.pi / 2, "X")
    b.add(log.move(0, y_tail, zl), grad=("range", 0.3, 0.8))
    b.add(cylinder(rl * 0.8, rl * 0.8, 0.1, 8, "wood_pale").rotate(math.pi / 2, "X").move(0, y_tail + 0.08, zl))
    for f in (0.12, 0.4, 0.7):
        y = y_head + 1.6 + (y_tail - y_head - 1.6) * f
        b.add(cylinder(rl + 0.08, rl + 0.08, 0.35, 8, "iron_dark").rotate(math.pi / 2, "X").move(0, y + 0.17, zl))
    hs = 1.5 if big else 1.0  # oversized head on the tortoise
    head = lathe([(0.0, -0.2), ((rl + 0.15) * hs, 0.0), ((rl + 0.22) * hs, 0.9 * hs), (rl * 0.85 * hs, 1.5 * hs),
                  (rl * 0.45 * hs, 1.9 * hs), (0.0, 2.0 * hs)], 8, "steel" if big else "iron")
    b.add(head.rotate(math.pi / 2, "X").move(0, y_head + 1.8, zl))
    if big:  # flared collar behind the oversized head
        b.add(cylinder((rl + 0.3) * hs, (rl + 0.1), 0.6, 8, "iron_dark").rotate(math.pi / 2, "X")
              .move(0, y_head + 2.4, zl))
    for sx in (-1, 1):  # kingdom emblem plates riveted on the head
        for pc in emblem(EMB[k], 0.9 * hs, *emblem_colors(k, EMB[k]), depth=0.12, mid=None):
            b.add(pc.rotate(sx * math.pi / 2, "Z").move(sx * ((rl + 0.25) * hs), y_head + 1.8 - 0.7 * hs, zl))
    b.socket("ram_head", 0, y_head + 1.8 - 2.0 * hs, zl)
    # slings: ropes from the hanging beam down round the log
    for y in (-L * 0.2, L * 0.25):
        for sx in (-1, 1):
            b.add(rope([(sx * 0.3, y, hang_z), (sx * (rl + 0.05), y, zl + 0.2), (0.0, y, zl - rl - 0.12),
                        (-sx * (rl + 0.05), y, zl + 0.1)], r=0.1, seg=4), tag="rope")
            ropes += 1
        b.add(box(1.2, 0.4, 0.4, "iron_dark").move(0, y, hang_z - 0.2))
    # pushing bars across the log for the crew
    for y in (L * 0.08, L * 0.36):
        b.add(beam((-1.9, y, zl - 0.2), (1.9, y, zl - 0.2), 0.22, 0.22, "wood", normal=(0, 0, 1)))

    b.stats["rope"] = ropes
    b.socket("crew_1", -1.6, L * 0.22, 0)
    b.socket("crew_2", 1.6, L * 0.22, 0)
    b.stats["pieces"] = len(b.pieces)
