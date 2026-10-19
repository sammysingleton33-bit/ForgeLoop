"""Character kit: the rig definition shared by rig.json, the assembler and the renders (FL-0135).

JOINTS are the Sim/Pose.JOINTS pivots in the rig frame at rest (studs). ASSEMBLIES say which piece fills which slot
for each job; sided slots (arm, sleeve, leg, boot) name the base and the `_l` / `_r` pieces are implied.
Templates follow the Kit/CharacterMesh contract (lib/ckit_resolve.py): `%look.<axis>%` picks one of the numbered variants
(head_01..06, hair_01..10, torso_01..06, boot_01..03_l/_r, acc_01..02) from the citizen's look, `%kingdom%` the crest / shield colour.
"""

from . import _charkit_style as K

JOINTS = {
    "Torso": {"parent": "Root", "pos": [0.0, 2.2, 0.0]},
    "Head": {"parent": "Torso", "pos": [0.0, 3.9, 0.0]},
    "LeftArm": {"parent": "Torso", "pos": [-K.ARM_X, 3.5, 0.0]},
    "RightArm": {"parent": "Torso", "pos": [K.ARM_X, 3.5, 0.0]},
    "LeftLeg": {"parent": "Torso", "pos": [-K.LEG_X, 2.2, 0.0]},
    "RightLeg": {"parent": "Torso", "pos": [K.LEG_X, 2.2, 0.0]},
    # Tool: inside the right fist (filled from the arm geometry by ckit_kit)
    "Tool": {"parent": "RightArm", "pos": None},
    # the hauler's sack hangs off the Torso at the right shoulder blade (Motor6D "Tool" from the Torso, like Character.luau)
    "TorsoTool": {"parent": "Torso", "pos": [0.86, 3.8, 0.575]},
}

SIDED = ("arm", "sleeve", "leg", "boot")
KINGDOMS = ("crimson", "azure", "emerald", "gold")


def _sided(base):
    return [base + "_l", base + "_r"]


# slot key -> template(s). Sided slots list the left and the right piece. The slot keys "hair" and "acc" are special for the runtime
# (the part is named Hair / Accessory); "extras" and the rest are free labels.
_CITIZEN = dict(torso="torso_%look.outfit%", head="head_%look.face%", boot=_sided("boot_%look.boots%"))
ASSEMBLIES = {
    "farmer": dict(_CITIZEN, hat="hat_straw", hatband="hat_ribbon", arm=_sided("arm_bare"), sleeve=_sided("sleeve_short"),
                   leg=_sided("leg_trousers"), tool="tool_hoe", extras=["apron_farm", "mantle_kingdom"]),
    "woodcutter": dict(_CITIZEN, hat="hat_beanie", hatband="hat_pompom", arm=_sided("arm_bare"), sleeve=_sided("sleeve_long"),
                       leg=_sided("leg_trousers"), tool="tool_axe", extras=["mantle_kingdom"]),
    "miner": dict(_CITIZEN, hat="hat_miner", arm=_sided("arm_bare"), sleeve=_sided("sleeve_short"), leg=_sided("leg_trousers"),
                  tool="tool_pick", extras=["mantle_kingdom"]),
    "builder": dict(_CITIZEN, hat="hat_builder", arm=_sided("arm_hand"), sleeve=_sided("sleeve_long"), leg=_sided("leg_breeches"),
                    tool="tool_mallet", extras=["mantle_kingdom"]),
    "hauler": dict(_CITIZEN, hair="hair_%look.hair%", arm=_sided("arm_bare"), sleeve=_sided("sleeve_short"), leg=_sided("leg_trousers"),
                   tool="tool_sack", extras=["strap_kingdom", "mantle_kingdom"]),
    "blacksmith": dict(_CITIZEN, torso="torso_smith", hair="hair_beard", hat="hat_smith", arm=_sided("arm_bare"),
                       leg=_sided("leg_trousers"), tool="tool_hammer", extras=["apron_smith", "mantle_kingdom"]),
    "merchant": dict(_CITIZEN, torso="torso_merchant", hat="hat_merchant", hatband="hat_feather", arm=_sided("arm_hand"),
                     sleeve=_sided("sleeve_long"), leg=_sided("leg_breeches"), tool="tool_scale",
                     extras=["satchel_merchant", "mantle_kingdom"]),
    "healer": dict(_CITIZEN, torso="torso_smock", hat="hat_coif", arm=_sided("arm_hand"), sleeve=_sided("sleeve_long"),
                   leg=_sided("leg_trousers"), tool="tool_staff_healer", extras=["satchel_herb", "mantle_kingdom"]),
    "idle": dict(_CITIZEN, hair="hair_%look.hair%", acc="acc_%look.acc%", arm=_sided("arm_bare"), sleeve=_sided("sleeve_short"),
                 leg=_sided("leg_trousers"), extras=["mantle_kingdom"]),
    "soldier": dict(torso="torso_tabard", head="head_%look.face%", hat="hat_helm", crest="crest_%kingdom%", arm=_sided("arm_gauntlet"),
                    sleeve=_sided("sleeve_soldier"), leg=_sided("leg_mail"), boot=_sided("boot_plate"), tool="tool_spear",
                    toolband="tool_pennant"),
    "soldier_swordsman": dict(torso="torso_tabard", head="head_%look.face%", hat="hat_helm", crest="crest_%kingdom%",
                              arm=_sided("arm_gauntlet"), sleeve=_sided("sleeve_soldier"), leg=_sided("leg_mail"),
                              boot=_sided("boot_plate"), tool="tool_sword", extras=["shield_%kingdom%"]),
    "soldier_archer": dict(torso="torso_tabard", head="head_%look.face%", hat="hat_helm", crest="crest_%kingdom%",
                           arm=_sided("arm_gauntlet"), sleeve=_sided("sleeve_soldier"), leg=_sided("leg_mail"),
                           boot=_sided("boot_plate"), tool="tool_bow", extras=["quiver"]),
    "governor": dict(torso="torso_regal", head="head_%look.face%", hat="hat_crown", hatband="crown_cap", arm=_sided("arm_hand"),
                     sleeve=_sided("sleeve_robe"), leg=_sided("leg_trousers"), boot=_sided("boot_03"), tool="tool_staff_ruler",
                     extras=["cape", "collar_ermine", "trim_regal"]),
}

# Pieces with no mesh (variants that mean "none"): they exist only in rig.json (`empty: true`), never in the FBX.
EMPTY_PIECES = {"acc_01": dict(joint="Head", slot="acc", tint="fixed", tags=["idle", "none"])}

# Colours of `cloth` pieces: Kit/Character.clothColor (the job's panel, trousers for slot "leg", x the hair colour's dye). Jobs
# without a palette of their own (blacksmith, merchant, healer, idle, soldiers, governor) wear the folk set. Mirrors Character.luau.
LINEN = (226, 214, 186)
CANVAS_RT = (232, 220, 192)
CLOTH_PANELS = {
    "farmer": [(232, 222, 190), (214, 224, 196), (236, 214, 176)],
    "woodcutter": [(96, 66, 46), (84, 70, 66), (110, 66, 44)],
    "miner": [(122, 126, 136), (132, 124, 116), (110, 122, 140)],
    "builder": [(196, 158, 104), (186, 170, 120), (206, 160, 90)],
    "hauler": [(156, 118, 80), (146, 122, 92), (164, 112, 76)],
    "folk": [LINEN, CANVAS_RT, (196, 170, 128)],
}
CLOTH_LEGS = {
    "farmer": [(98, 104, 58), (86, 108, 66), (84, 100, 84)],
    "woodcutter": [(58, 42, 32), (50, 46, 48), (70, 40, 36)],
    "miner": [(70, 68, 72), (62, 70, 84), (74, 76, 64)],
    "builder": [(52, 62, 94), (60, 58, 100), (84, 84, 100)],
    "hauler": [(112, 68, 42), (96, 72, 52), (122, 76, 50)],
    "folk": [(110, 86, 60), (78, 58, 40), (88, 90, 98)],
}
DYE = [1, 0.94, 1.06, 0.9, 1.1, 0.97, 1.03, 0.92]  # per hairColor: individual dye factor on cloth colours (Character.luau)
TINT_SHIFT = [0, -0.1, 0.08, -0.16, 0.12, -0.05, 0.05, -0.12]  # per (hairColor + skin - 2) % 8: kingdom tint factor shift

# `tint_factor` of kingdom-tinted pieces (shade(kingdomColor, f)); keys are piece names without the _l/_r side suffix
KIT_TINT = {"sleeve_soldier": 0.85, "sleeve_robe": 0.72, "torso_tabard": 1.0, "torso_regal": 1.0, "hair_10": 0.72, "hat_ribbon": 0.85,
            "hat_pompom": 0.85, "crown_cap": 0.9, "strap_kingdom": 0.85, "cape": 0.58, "tool_pennant": 0.9, "crest_crimson": 1.0,
            "crest_azure": 1.0, "crest_emerald": 1.0, "crest_gold": 1.0, "crest_neutral": 1.0, "shield_neutral": 0.9, "shield_crimson": 0.9, "shield_azure": 0.9, "shield_emerald": 0.9,
            "shield_gold": 0.9, "mantle_kingdom": 0.95}

# registry piece ids (set by char_kit.registry()); resolution needs them for the %look.axis% variants
_PIECES = {}


def set_pieces(pieces):
    """`pieces` = {id: record-or-anything}; the empty variants of EMPTY_PIECES are added."""
    global _PIECES
    _PIECES = {pid: {} for pid in pieces}
    for pid, e in EMPTY_PIECES.items():
        _PIECES[pid] = dict(e, empty=True)


def names_for(job, look=None, kingdom="crimson"):
    """Piece ids (with geometry) of one citizen: the same resolution the runtime does (lib/ckit_resolve.py)."""
    from lib import ckit_resolve

    return ckit_resolve.resolve_assembly(ASSEMBLIES, _PIECES, job, look, kingdom)
