"""Character kit: the rig definition shared by rig.json, the assembler and the renders (FL-0135).

JOINTS are the Sim/Pose.JOINTS pivots in the rig frame at rest (studs). ASSEMBLIES say which piece fills which slot
for each job; sided slots (arm, sleeve, leg, boot) name the base and the `_l` / `_r` pieces are implied.
"%face%", "%hair%", "%torso%", "%boot%" and "%kingdom%" are filled from the look / kingdom (see LOOKS).
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

# slot -> piece (a list for extras). Slots without a piece are left out.
ASSEMBLIES = {
    "farmer": dict(torso="torso_tunic", head="%face%", hat="hat_straw", hatband="hat_ribbon", arm="arm_bare", sleeve="sleeve_short",
                   leg="leg_trousers", boot="boot_work", tool="tool_hoe", extras=["apron_farm"]),
    "woodcutter": dict(torso="torso_work", head="%face%", hat="hat_beanie", hatband="hat_pompom", arm="arm_bare", sleeve="sleeve_long",
                       leg="leg_trousers", boot="boot_high", tool="tool_axe", extras=[]),
    "miner": dict(torso="torso_vest", head="%face%", hat="hat_miner", arm="arm_bare", sleeve="sleeve_short", leg="leg_trousers",
                  boot="boot_work", tool="tool_pick", extras=[]),
    "builder": dict(torso="torso_jerkin", head="%face%", hat="hat_builder", arm="arm_hand", sleeve="sleeve_long", leg="leg_breeches",
                    boot="boot_work", tool="tool_mallet", extras=[]),
    "hauler": dict(torso="torso_work", head="%face%", hair="%hair%", arm="arm_bare", sleeve="sleeve_short", leg="leg_trousers",
                   boot="boot_low", tool="tool_sack", extras=["strap_kingdom"]),
    "blacksmith": dict(torso="torso_smith", head="%face%", hair="hair_beard", arm="arm_bare", leg="leg_trousers", boot="boot_work",
                       tool="tool_hammer", extras=["apron_smith"]),
    "merchant": dict(torso="torso_vest", head="%face%", hat="hat_merchant", hatband="hat_feather", arm="arm_hand", sleeve="sleeve_long",
                     leg="leg_breeches", boot="boot_high", tool="tool_scale", extras=["satchel_merchant"]),
    "healer": dict(torso="torso_smock", head="%face%", hat="hat_coif", arm="arm_hand", sleeve="sleeve_long", leg="leg_trousers",
                   boot="boot_low", tool="tool_staff_healer", extras=["satchel_herb"]),
    "idle": dict(torso="%torso%", head="%face%", hair="%hair%", arm="arm_bare", sleeve="sleeve_short", leg="leg_trousers", boot="boot_low",
                 extras=[]),
    "soldier": dict(torso="torso_tabard", head="%face%", hat="hat_helm", crest="crest_%kingdom%", arm="arm_hand", sleeve="sleeve_mail",
                    leg="leg_mail", boot="boot_plate", tool="tool_spear", toolband="tool_pennant", extras=[]),
    "soldier_sword": dict(torso="torso_tabard", head="%face%", hat="hat_helm", crest="crest_%kingdom%", arm="arm_hand", sleeve="sleeve_mail",
                          leg="leg_mail", boot="boot_plate", tool="tool_sword", extras=["shield_%kingdom%"]),
    "soldier_bow": dict(torso="torso_tabard", head="%face%", hat="hat_helm", crest="crest_%kingdom%", arm="arm_hand", sleeve="sleeve_mail",
                        leg="leg_mail", boot="boot_plate", tool="tool_bow", extras=["quiver"]),
    "governor": dict(torso="torso_regal", head="%face%", hat="hat_crown", hatband="crown_cap", arm="arm_hand", sleeve="sleeve_robe",
                     leg="leg_trousers", boot="boot_high", tool="tool_staff_ruler", extras=["cape", "collar_ermine", "trim_regal"]),
}

# Looks (CitizenLook = { skin, hair, hairColor, outfit }, 1-based, G13.2 ranges 6, 6, 8, 6). The Kit owns the mapping; this is
# the recommended deterministic one (the Blender renders use it too).
HAIR_SETS = [  # by hairColor <= 4 / > 4, indexed by look.hair - 1: all ten hair styles reachable
    ["hair_crop", "hair_bowl", "hair_long", "hair_curls", "hair_ponytail", "hair_beard"],
    ["hair_bob", "hair_pigtails", "hair_bun", "hair_tonsure", "hair_crop", "hair_long"],
]
OUTFIT_TORSOS = ["torso_tunic", "torso_sleeveless", "torso_vest", "torso_work", "torso_robe", "torso_jerkin"]  # look.outfit 1..6
FACES = ["head_01", "head_02", "head_03", "head_04", "head_05", "head_06"]
BOOTS = {"idle": ["boot_low", "boot_work", "boot_high"], "hauler": ["boot_low", "boot_work"], "farmer": ["boot_work", "boot_low"],
         "default": ["boot_work", "boot_high", "boot_low"]}

# per-job cloth colours (sRGB 0-255) for pieces whose tint is "cloth", by slot; mirrors Kit/Character.luau JOBS panels
LINEN = (226, 214, 186)
CLOTH = {
    "farmer": {"sleeve": LINEN, "leg": (98, 104, 58), "torso": (232, 222, 190), "default": (232, 222, 190)},
    "woodcutter": {"sleeve": (96, 66, 46), "leg": (58, 42, 32), "hat": (52, 58, 70), "torso": (96, 66, 46), "default": (96, 66, 46)},
    "miner": {"sleeve": (122, 126, 136), "leg": (70, 68, 72), "torso": (122, 126, 136), "default": (122, 126, 136)},
    "builder": {"sleeve": (196, 158, 104), "leg": (52, 62, 94), "hat": (240, 214, 160), "torso": (196, 158, 104), "default": (196, 158, 104)},
    "hauler": {"sleeve": (156, 118, 80), "leg": (112, 68, 42), "torso": (156, 118, 80), "default": (156, 118, 80)},
    "blacksmith": {"sleeve": (80, 72, 70), "leg": (60, 52, 48), "torso": (96, 84, 78), "default": (96, 84, 78)},
    "merchant": {"sleeve": (232, 224, 204), "leg": (84, 60, 52), "torso": (122, 40, 60), "hat": (46, 84, 96), "default": (122, 40, 60)},
    "healer": {"sleeve": (236, 232, 218), "leg": (150, 150, 140), "torso": (236, 232, 218), "hat": (240, 236, 224), "default": (236, 232, 218)},
    "idle": {"sleeve": LINEN, "leg": (110, 86, 60), "torso": (190, 160, 120), "hat": (170, 84, 52), "default": (190, 160, 120)},
    "soldier": {"sleeve": (84, 90, 100), "leg": (84, 90, 100), "default": (84, 90, 100)},
    "governor": {"sleeve": (242, 238, 228), "leg": (72, 52, 60), "default": (242, 238, 228)},
}

# KitTint factors for kingdom-tinted pieces (shade(kingdomColor, f), as the part-built rigs do)
KIT_TINT = {"torso_tunic": 0.8, "torso_work": 0.85, "torso_jerkin": 1.0, "torso_sleeveless": 0.85, "torso_robe": 0.66, "torso_tabard": 1.0,
            "torso_regal": 1.0, "hat_hood": 0.72, "hat_ribbon": 0.85, "hat_pompom": 0.85, "crown_cap": 0.9, "strap_kingdom": 0.85,
            "cape": 1.0, "tool_pennant": 0.9, "crest_crimson": 1.0, "crest_azure": 1.0, "crest_emerald": 1.0, "crest_gold": 1.0,
            "shield_crimson": 0.9, "shield_azure": 0.9, "shield_emerald": 0.9, "shield_gold": 0.9}


def hair_for(look):
    s = HAIR_SETS[0 if look["hairColor"] <= 4 else 1]
    return s[(look["hair"] - 1) % len(s)]


def face_for(look):
    return FACES[(look["hair"] + 2 * look["outfit"] + look["skin"]) % len(FACES)]


def boot_for(job, look):
    lst = BOOTS.get(job, BOOTS["default"])
    return lst[(look["outfit"] + look["skin"]) % len(lst)]


def names_for(job, look=None, kingdom="crimson", face=None, hair=None):
    """Piece names for one citizen (sided slots expanded). `look` = {skin, hair, hairColor, outfit} (1-based)."""
    look = look or {"skin": 1, "hair": 1, "hairColor": 1, "outfit": 1}
    a = ASSEMBLIES[job]
    face = face or face_for(look)
    hair = hair or hair_for(look)
    out = []
    for slot, val in a.items():
        if slot == "extras":
            out += [v.replace("%kingdom%", kingdom) for v in val]
            continue
        if val is None:
            continue
        val = (val.replace("%face%", face).replace("%kingdom%", kingdom).replace("%hair%", hair)
               .replace("%torso%", OUTFIT_TORSOS[(look["outfit"] - 1) % len(OUTFIT_TORSOS)]))
        if slot == "boot" and job in BOOTS:
            val = boot_for(job, look)
        if slot in SIDED:
            out += [val + "_l", val + "_r"]
        else:
            out.append(val)
    return out
