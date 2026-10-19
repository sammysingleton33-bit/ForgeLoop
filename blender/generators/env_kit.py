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

# family -> (min triangles, max triangles) per mesh. D-057 (19): trees 300-900; bushes, rocks and flowers 40-400 (contract); a resource node is a
# composite (host rock + nuggets, strata + rubble) so it gets 500; a crop field is a plot of many tufts (budgets.json class `crop`: 3,000).
FAMILY_BUDGET = {"tree": (300, 900), "bush": (40, 400), "rock": (40, 400), "flower": (40, 400), "node": (40, 500), "crop": (200, 3000), "prop": (40, 400)}

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
        add(pid, "bush", lambda rng, i=i: PL.bush(i, rng), node=(i == 3))  # bush_03 is the world's food node
    for i, pid in enumerate(_ids("plant_flowers", 6), 1):
        add(pid, "flower", lambda rng, i=i: PL.flowers(i, rng))
    for size in ("s", "m", "l"):
        for i, pid in enumerate(_ids(f"rock_boulder_{size}", 3), 1):
            add(pid, "rock", lambda rng, i=i, size=size: RK.boulder(size, i, rng))
    for i, pid in enumerate(_ids("rock_cliff", 2), 1):
        add(pid, "rock", lambda rng, i=i: RK.cliff(i, rng))
    for i, pid in enumerate(_ids("resource_stone", 3), 1):
        add(pid, "node", lambda rng, i=i: RK.quarry(i, rng), node=True)
    for i, pid in enumerate(_ids("resource_ore", 6), 1):
        add(pid, "node", lambda rng, i=i: RK.ore(i, rng), node=True)
    for i, pid in enumerate(_ids("resource_wood", 2), 1):
        add(pid, "node", lambda rng, i=i: RK.wood(i, rng), node=True)
    for i, pid in enumerate(_ids("farm_field_wheat", 3), 1):
        add(pid, "crop", lambda rng, i=i: CR.wheat(i, rng, 3))
    add("farm_field_wheat_stage1", "crop", lambda rng: CR.wheat(1, rng, 1))
    add("farm_field_wheat_stage2", "crop", lambda rng: CR.wheat(1, rng, 2))
    for i, pid in enumerate(_ids("farm_field_cabbage", 3), 1):
        add(pid, "crop", lambda rng, i=i: CR.cabbage(i, rng))
    add("farm_haystack_01", "prop", lambda rng: CR.haystack(1, rng))
    for i, pid in enumerate(_ids("farm_fence", 2), 1):
        add(pid, "prop", lambda rng, i=i: CR.fence(i, rng))
    return plan


def all_ids():
    return [p[0] for p in _plan()]


def registry(seed=SEED, only=None):
    """{asset id: Prop} in a stable order. `only`: a set of ids to build (the dev renders); None = all."""
    out = {}
    for pid, family, node, builder in _plan():
        if only is not None and pid not in only:
            continue
        m, info = builder(S.rng_for(pid, seed))
        out[pid] = Prop(pid, family, m, node=node, info=info)
    return out
