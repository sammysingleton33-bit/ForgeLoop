"""Citizen character mesh kit (FL-0135, D-057): rigid pieces for the Kit's segmented MeshPart rigs.

One FBX (`exports/citizen_kit.fbx`, every piece its own mesh object named by piece id, vertex colours, one material) plus
`games/game-001/art/char_kit/rig.json` (joints, per-piece bounding boxes, assemblies per job, looks, tints, measured budgets).
Original work (project-original): built procedurally, no third-party mesh is used. Style direction: see
games/game-001/art/reviews/char-mesh.md.

Build:  ~/forge-bpy/bin/python blender/build.py --generator char_kit [--no-render]
Rig frame: Roblox axes, studs (+X right, +Y up, -Z front, feet at y = 0). Joints keep Sim/Pose.JOINTS names.
"""

import bpy  # noqa: F401  (mathutils needs bpy imported first)

from generators import _charkit_body as B
from generators import _charkit_gear as G
from generators import _charkit_rig as RIG
from generators import _charkit_style as K

NAME = "char_kit"
VERSION = 1
CATEGORY = "char"
BUDGET = "citizen_rig"
COLLISION = {"fidelity": "Box"}
CHECKS = {}
DEFAULT_VARIANTS = 1
KIT = True  # multi-piece kit: build.py hands over to lib/ckit_kit.run_generator
LICENSE = "project-original"
STYLE = "A"


def variants(n, seed):
    return [{"seed": seed, "style": STYLE}]


def build(b, params):
    raise RuntimeError("char_kit is a multi-piece kit: build.py calls registry() through lib/ckit_kit.run_generator")


def registry():
    """(Registry with every piece, rig definition module, right-fist joint position)."""
    S = K.STYLE_A if STYLE == "A" else K.STYLE_B
    R = K.Registry(S)
    B.build_body(S, R)
    G.build_gear(S, R)
    return R, RIG, G.HAND
