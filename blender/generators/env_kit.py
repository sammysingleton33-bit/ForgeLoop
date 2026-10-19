"""Environment mesh kit (FL-0136 phase 2, D-057 (19)): style-B nature and crops for the Kit's prop path (`Kit.prop(assetId)`).

One FBX (`games/game-001/art/env_kit/env_kit.fbx`, every prop its own mesh object named by ASSET ID, vertex colours, one material) plus
`games/game-001/art/env_kit/env.json` (per prop: bounding box, measured triangles, the stand-in it replaces, node flag, fit figures).
Original work (project-original): built procedurally, no third-party mesh is used. Style: faceted flat-shaded chunky low-poly, the same
direction as the citizen kit (games/game-001/art/reviews/char-mesh.md); see games/game-001/art/reviews/env-mesh.md "Phase 2".

Build:  ~/forge-bpy/bin/python blender/build.py --generator env_kit [--no-render]
Frame: Roblox axes in studs, base on y = 0 (a foot or root may sink up to `sink` below it), centred on x = 0, z = 0, front -Z.
The asset ids are exactly the ones Kit/WorldPlan.luau and world/Layout.luau place (and the spares the Props stand-ins define);
a missing id falls back to its part-built stand-in, so a partial kit is always safe.
"""

import bpy  # noqa: F401  (mathutils needs bpy imported first)

from generators import _envkit_crops as CR
from generators import _envkit_plants as PL
from generators import _envkit_rocks as RK
from generators import _envkit_style as S
from generators import _envkit_trees as TR

NAME = "env_kit"
VERSION = 1
CATEGORY = "env"
BUDGET = "env_kit"
ENV_KIT = True  # multi-prop kit: build.py hands over to lib/envkit_build.run_generator
LICENSE = "project-original"
DEFAULT_VARIANTS = 1
COLLISION = {"fidelity": "Box"}
CHECKS = {}
STYLE = "B"

# family -> (min triangles, max triangles) per mesh: the Kit's budget (games/game-001/art/env_kit/env_to_luau.py BUDGET = Kit/EnvMesh.BUDGET): trees 300-900 (D-057 (19)),
# bushes, rocks (boulders, cliffs and the resource nodes: stone and ore) and flowers 40-400 (the contract), crops 40-1,500, haystack and fence 40-600.
FAMILY_BUDGET = {"tree": (300, 900), "bush": (40, 400), "rock": (40, 400), "flower": (40, 400), "crop": (40, 1500), "haystack": (40, 600), "fence": (40, 600)}

SEED = 7


class Prop:
    __slots__ = ("id", "family", "m", "node", "placed", "info")

    def __init__(self, pid, family, m, node=False, info=None):
        self.id, self.family, self.m, self.node, self.info = pid, family, m, node, dict(info or {})
        self.placed = True


def variants(n, seed):
    return [{"seed": seed, "style": STYLE}]


def build(b, params):
    raise RuntimeError("env_kit is a multi-prop kit: build.py calls registry() through lib/envkit_build.run_generator")


def _ids(prefix, n, width=2):
    return [f"{prefix}_{i:0{width}d}" for i in range(1, n + 1)]


def _plan():
    """[(id, family, node, builder(rng) -> (M, info))] in the kit's stable order, nothing built yet."""
    plan = []

    def add(pid, family, builder, node=False):
        plan.append((pid, family, node, builder))

    for i, pid in enumerate(_ids("tree_oak", 8), 1):
        add(pid, "tree", lambda rng, i=i: TR.oak(i, rng))
    for i, pid in enumerate(_ids("tree_pine", 6), 1):
        add(pid, "tree", lambda rng, i=i: TR.pine(i, rng))
    for i, pid in enumerate(_ids("tree_birch", 6), 1):
        add(pid, "tree", lambda rng, i=i: TR.birch(i, rng))
    for i, pid in enumerate(_ids("bush", 8), 1):
        add(pid, "bush", lambda rng, i=i: PL.bush(i, rng))
    for i, pid in enumerate(_ids("plant_flowers", 6), 1):
        add(pid, "flower", lambda rng, i=i: PL.flowers(i, rng))
    for size in ("s", "m", "l"):
        for i, pid in enumerate(_ids(f"rock_boulder_{size}", 3), 1):
            add(pid, "rock", lambda rng, i=i, size=size: RK.boulder(size, i, rng))
    for i, pid in enumerate(_ids("rock_cliff", 2), 1):
        add(pid, "rock", lambda rng, i=i: RK.cliff(i, rng))
    for i, pid in enumerate(_ids("resource_stone", 3), 1):
        add(pid, "rock", lambda rng, i=i: RK.quarry(i, rng), node=True)
    for i, pid in enumerate(_ids("resource_ore", 6), 1):
        add(pid, "rock", lambda rng, i=i: RK.ore(i, rng), node=True)
    for i, pid in enumerate(_ids("resource_wood", 2), 1):
        add(pid, "rock", lambda rng, i=i: RK.wood(i, rng), node=True)
    for i, pid in enumerate(_ids("farm_field_wheat", 3), 1):
        add(pid, "crop", lambda rng, i=i: CR.wheat(i, rng, 3))
    # the growth stages (nothing places them: the world's fields are static and ripe): 04 = stage 1 (furrows, first shoots), 05 = stage 2 (green wheat)
    add("farm_field_wheat_04", "crop", lambda rng: CR.wheat(1, rng, 1))
    add("farm_field_wheat_05", "crop", lambda rng: CR.wheat(1, rng, 2))
    for i, pid in enumerate(_ids("farm_field_cabbage", 3), 1):
        add(pid, "crop", lambda rng, i=i: CR.cabbage(i, rng))
    add("farm_haystack_01", "haystack", lambda rng: CR.haystack(1, rng))
    for i, pid in enumerate(_ids("farm_fence", 2), 1):
        add(pid, "fence", lambda rng, i=i: CR.fence(i, rng))
    return plan


def all_ids():
    return [p[0] for p in _plan()]


# families whose footprint and height are brought inside the stand-in's window by a small non-uniform scale when a design lands outside it
# (crops are exact by construction; stage ids and the growth stages inherit the wheat stand-in)
FIT_FAMILIES = ("tree", "bush", "rock", "flower", "haystack", "fence")
SEATED_FAMILIES = ("tree", "bush", "haystack")
FIT_WINDOW = (0.93, 1.07)  # footprint max(x, z) and height against the stand-in: well inside the Kit's 85-115 % / 75-125 %
FIT_WINDOW_NODE = (0.88, 1.0)  # an id the world also places as a resource node: the Kit allows 85-102 % of the footprint (selection and keep-out use it)


def _standin_for(pid, standins):
    return standins.get(pid) or standins.get("farm_field_wheat_01" if pid in ("farm_field_wheat_04", "farm_field_wheat_05") else pid)


# Horizontal trims applied after the fit window (a factor on x and z about the pivot axis; height untouched). tree_oak_05 is the wood node whose real mesh outline
# (farthest vertex 12.58 studs from the trunk) reached 0.35 stud into the 8-stud buffer NodeKeepOut keeps between a node and the starting quarry (allowed 12.23
# at crimson_wood4); 0.95 brings it to 11.95 (footprint 95 % of the stand-in's, inside the node window 85 to 102 %). FORGE-00 2026-10-19: Layout is not moved.
RADIAL_TRIM = {"tree_oak_05": 0.95}


def registry(seed=SEED, only=None):
    """{asset id: Prop} in a stable order. `only`: a set of ids to build (the dev renders); None = all."""
    from lib import envkit_standin

    standins = envkit_standin.load()["standins"]
    out = {}
    for pid, family, node, builder in _plan():
        if only is not None and pid not in only:
            continue
        m, info = builder(S.rng_for(pid, seed))
        st = _standin_for(pid, standins)
        if st and family in FIT_FAMILIES:
            is_node = bool(node or st["node"])
            kr, kh = S.fit_to(m, max(st["size"][0], st["size"][2]), st["size"][1], FIT_WINDOW_NODE if is_node else FIT_WINDOW, (0.9, 1.1))
            if (kr, kh) != (1.0, 1.0):
                info["fit_scale"] = [kr, kh]
        if pid in RADIAL_TRIM:  # after the fit: xz about the pivot axis only, so one prop moves and every other mesh stays byte-identical
            k = RADIAL_TRIM[pid]
            m.map(lambda p, k=k: (p[0] * k, p[1], p[2] * k))
            info["radial_trim"] = k
        if family in SEATED_FAMILIES:  # a trunk, bush or stack stands ON the ground: its lowest vertex sits 0.08 under it (rocks embed more, see below)
            m.move(0.0, -0.08 - m.bounds()[0][1], 0.0)
        out[pid] = Prop(pid, family, m, node=bool(node or (st and st["node"])), info=info)  # node: the world places this id as a resource node too
    return out


def split_placed(reg):
    """(ids the world places, spare ids): the Kit's spec fails on an id the world never places, so only placed ids go in env.json / env_kit.fbx;
    the rest (wood nodes, the iron and crystal ore, wheat 03 and the growth stages) ship as a second kit that nothing reads: the world places no
    growth stage (crop fields are static dressing, FORGE-00 2026-10-19) and iron and crystal are not game resources. The mesh-only dressing ids
    (envkit_standin.MESH_DRESSING) are placed, so they ship with the main kit."""
    from lib import envkit_standin

    st = envkit_standin.load()["standins"]
    main = [pid for pid in reg if st.get(pid, {}).get("placed") or pid in envkit_standin.MESH_DRESSING]
    spares = [pid for pid in reg if pid not in set(main)]
    for pid in spares:
        reg[pid].placed = False  # the data files say so too (the growth stages wheat_04 / _05 used to read "placed": true)
    return main, spares
