"""Character kit: the rig definition shared by rig.json, the assembler and the renders (FL-0135).

JOINTS are the Sim/Pose.JOINTS pivots in the rig frame at rest (studs). ASSEMBLIES say which piece fills which slot
for each job; sided slots (arm, sleeve, leg, boot) name the base and the `_l` / `_r` pieces are implied.
"%face%", "%hair%", "%torso%", "%boot%", "%accessory%" and "%kingdom%" are filled from the look / kingdom (see LOOKS).
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
    "farmer": dict(torso="%torso%", head="%face%", hat="hat_straw", hatband="hat_ribbon", arm="arm_bare", sleeve="sleeve_short",
                   leg="leg_trousers", boot="boot_work", tool="tool_hoe", extras=["apron_farm"]),
    "woodcutter": dict(torso="%torso%", head="%face%", hat="hat_beanie", hatband="hat_pompom", arm="arm_bare", sleeve="sleeve_long",
                       leg="leg_trousers", boot="boot_high", tool="tool_axe", extras=[]),
    "miner": dict(torso="%torso%", head="%face%", hat="hat_miner", arm="arm_bare", sleeve="sleeve_short", leg="leg_trousers",
                  boot="boot_work", tool="tool_pick", extras=[]),
    "builder": dict(torso="%torso%", head="%face%", hat="hat_builder", arm="arm_hand", sleeve="sleeve_long", leg="leg_breeches",
                    boot="boot_work", tool="tool_mallet", extras=[]),
    "hauler": dict(torso="%torso%", head="%face%", hair="%hair%", arm="arm_bare", sleeve="sleeve_short", leg="leg_trousers",
                   boot="boot_low", tool="tool_sack", extras=["strap_kingdom"]),
    "blacksmith": dict(torso="%torso%", head="%face%", hair="hair_beard", arm="arm_bare", leg="leg_trousers", boot="boot_work",
                       tool="tool_hammer", extras=["apron_smith"]),
    "merchant": dict(torso="%torso%", head="%face%", hat="hat_merchant", hatband="hat_feather", arm="arm_hand", sleeve="sleeve_long",
                     leg="leg_breeches", boot="boot_high", tool="tool_scale", extras=["satchel_merchant"]),
    "healer": dict(torso="%torso%", head="%face%", hat="hat_coif", arm="arm_hand", sleeve="sleeve_long", leg="leg_trousers",
                   boot="boot_low", tool="tool_staff_healer", extras=["satchel_herb"]),
    "idle": dict(torso="%torso%", head="%face%", hair="%hair%", arm="arm_bare", sleeve="sleeve_short", leg="leg_trousers", boot="boot_low",
                 extras=["%accessory%"]),
    "soldier": dict(torso="torso_tabard", head="%face%", hat="hat_helm", crest="crest_%kingdom%", arm="arm_gauntlet", sleeve="sleeve_soldier",
                    leg="leg_mail", boot="boot_plate", tool="tool_spear", toolband="tool_pennant", extras=[]),
    "soldier_sword": dict(torso="torso_tabard", head="%face%", hat="hat_helm", crest="crest_%kingdom%", arm="arm_gauntlet",
                          sleeve="sleeve_soldier", leg="leg_mail", boot="boot_plate", tool="tool_sword", extras=["shield_%kingdom%"]),
    "soldier_bow": dict(torso="torso_tabard", head="%face%", hat="hat_helm", crest="crest_%kingdom%", arm="arm_gauntlet",
                        sleeve="sleeve_soldier", leg="leg_mail", boot="boot_plate", tool="tool_bow", extras=["quiver"]),
    "governor": dict(torso="torso_regal", head="%face%", hat="hat_crown", hatband="crown_cap", arm="arm_hand", sleeve="sleeve_robe",
                     leg="leg_trousers", boot="boot_high", tool="tool_staff_ruler", extras=["cape", "collar_ermine", "trim_regal"]),
}

# Looks (CitizenLook = { skin, hair, hairColor, outfit }, 1-based, G13.2 ranges 6, 6, 8, 6). The Kit owns the mapping; this is the
# recommended deterministic one (the Blender renders use it too, through rig.json only).
HAIR_SETS = [  # by hairColor <= 4 / > 4, indexed by look.hair - 1: all ten hair styles and the hood are reachable
    ["hair_crop", "hair_bowl", "hair_long", "hair_curls", "hair_ponytail", "hair_beard"],
    ["hair_bob", "hair_pigtails", "hair_bun", "hair_tonsure", "hat_hood", "hair_crop"],
]
# look.outfit (1..6) -> torso piece, per job (>= 3 variants where it makes sense; soldiers and rulers keep theirs)
TORSO_VARIANTS = {
    "farmer": ["torso_tunic", "torso_vest", "torso_jerkin", "torso_work", "torso_sleeveless", "torso_tunic"],
    "woodcutter": ["torso_work", "torso_jerkin", "torso_vest", "torso_work", "torso_jerkin", "torso_sleeveless"],
    "miner": ["torso_vest", "torso_work", "torso_jerkin", "torso_vest", "torso_work", "torso_sleeveless"],
    "builder": ["torso_jerkin", "torso_work", "torso_tunic", "torso_jerkin", "torso_vest", "torso_work"],
    "hauler": ["torso_work", "torso_tunic", "torso_jerkin", "torso_sleeveless", "torso_work", "torso_vest"],
    "blacksmith": ["torso_smith", "torso_work", "torso_sleeveless", "torso_smith", "torso_jerkin", "torso_work"],
    "merchant": ["torso_vest", "torso_robe", "torso_jerkin", "torso_tunic", "torso_vest", "torso_robe"],
    "healer": ["torso_smock", "torso_robe", "torso_tunic", "torso_smock", "torso_robe", "torso_vest"],
    "idle": ["torso_tunic", "torso_sleeveless", "torso_vest", "torso_work", "torso_robe", "torso_jerkin"],
}
FACES = ["head_01", "head_02", "head_03", "head_04", "head_05", "head_06"]
BOOTS = {"idle": ["boot_low", "boot_work", "boot_high"], "hauler": ["boot_low", "boot_work"], "farmer": ["boot_work", "boot_low"],
         "healer": ["boot_low", "boot_high"], "merchant": ["boot_high", "boot_low"], "woodcutter": ["boot_high", "boot_work"],
         "default": ["boot_work", "boot_high", "boot_low"]}
ACCESSORIES = [None, "hat_headband", "neck_scarf", None, "hat_headband", "neck_scarf"]  # idle citizens: (outfit + 2*hair + 3*skin) % 6

# per-job cloth colours (sRGB 0-255) for pieces whose tint is "cloth", by slot, three variants of one value band (look.hairColor picks
# (hairColor - 1) % 3); the first mirrors Kit/Character.luau JOBS panels / legsSet / hat palettes. torso = the colour of cloth-tinted
# torsos (vest, smith), hat = cloth-tinted hats, default = anything else.
LINEN = (226, 214, 186)
CLOTH_VARIANTS = {
    "farmer": [{"sleeve": LINEN, "leg": (98, 104, 58), "torso": (232, 222, 190), "default": (232, 222, 190)},
               {"sleeve": (214, 224, 196), "leg": (86, 108, 66), "torso": (214, 224, 196), "default": (214, 224, 196)},
               {"sleeve": (236, 214, 176), "leg": (84, 100, 84), "torso": (236, 214, 176), "default": (236, 214, 176)}],
    "woodcutter": [{"sleeve": (96, 66, 46), "leg": (58, 42, 32), "hat": (52, 58, 70), "torso": (96, 66, 46), "default": (96, 66, 46)},
                   {"sleeve": (84, 70, 66), "leg": (50, 46, 48), "hat": (40, 52, 84), "torso": (84, 70, 66), "default": (84, 70, 66)},
                   {"sleeve": (110, 66, 44), "leg": (70, 40, 36), "hat": (44, 64, 50), "torso": (110, 66, 44), "default": (110, 66, 44)}],
    "miner": [{"sleeve": (122, 126, 136), "leg": (70, 68, 72), "torso": (122, 126, 136), "default": (122, 126, 136)},
              {"sleeve": (132, 124, 116), "leg": (62, 70, 84), "torso": (132, 124, 116), "default": (132, 124, 116)},
              {"sleeve": (110, 122, 140), "leg": (74, 76, 64), "torso": (110, 122, 140), "default": (110, 122, 140)}],
    "builder": [{"sleeve": (196, 158, 104), "leg": (52, 62, 94), "hat": (240, 214, 160), "torso": (196, 158, 104), "default": (196, 158, 104)},
                {"sleeve": (186, 170, 120), "leg": (60, 58, 100), "hat": (246, 224, 140), "torso": (186, 170, 120), "default": (186, 170, 120)},
                {"sleeve": (206, 160, 90), "leg": (84, 84, 100), "hat": (244, 208, 170), "torso": (206, 160, 90), "default": (206, 160, 90)}],
    "hauler": [{"sleeve": (156, 118, 80), "leg": (112, 68, 42), "torso": (156, 118, 80), "default": (156, 118, 80)},
               {"sleeve": (146, 122, 92), "leg": (96, 72, 52), "torso": (146, 122, 92), "default": (146, 122, 92)},
               {"sleeve": (164, 112, 76), "leg": (122, 76, 50), "torso": (164, 112, 76), "default": (164, 112, 76)}],
    "blacksmith": [{"sleeve": (80, 72, 70), "leg": (60, 52, 48), "torso": (96, 84, 78), "default": (96, 84, 78)},
                   {"sleeve": (74, 76, 82), "leg": (54, 54, 60), "torso": (88, 90, 96), "default": (88, 90, 96)},
                   {"sleeve": (92, 70, 56), "leg": (66, 50, 42), "torso": (108, 82, 64), "default": (108, 82, 64)}],
    "merchant": [{"sleeve": (232, 224, 204), "leg": (84, 60, 52), "torso": (122, 40, 60), "hat": (46, 84, 96), "default": (122, 40, 60)},
                 {"sleeve": (226, 232, 214), "leg": (60, 70, 84), "torso": (44, 96, 80), "hat": (122, 40, 60), "default": (44, 96, 80)},
                 {"sleeve": (236, 226, 206), "leg": (72, 60, 74), "torso": (156, 104, 40), "hat": (60, 70, 120), "default": (156, 104, 40)}],
    "healer": [{"sleeve": (236, 232, 218), "leg": (150, 150, 140), "torso": (236, 232, 218), "hat": (240, 236, 224), "default": (236, 232, 218)},
               {"sleeve": (222, 236, 222), "leg": (140, 150, 140), "torso": (222, 236, 222), "hat": (228, 240, 228), "default": (222, 236, 222)},
               {"sleeve": (236, 224, 214), "leg": (150, 140, 132), "torso": (236, 224, 214), "hat": (242, 232, 222), "default": (236, 224, 214)}],
    "idle": [{"sleeve": LINEN, "leg": (110, 86, 60), "torso": (190, 160, 120), "hat": (170, 84, 52), "default": (190, 160, 120)},
             {"sleeve": (214, 206, 186), "leg": (88, 90, 98), "torso": (172, 150, 120), "hat": (60, 72, 120), "default": (172, 150, 120)},
             {"sleeve": (232, 214, 176), "leg": (104, 70, 44), "torso": (160, 128, 92), "hat": (176, 84, 52), "default": (160, 128, 92)}],
    "soldier": [{"leg": (84, 90, 100), "default": (84, 90, 100)}],
    "governor": [{"sleeve": (242, 238, 228), "leg": (72, 52, 60), "default": (242, 238, 228)}],
}
DYE = [1, 0.94, 1.06, 0.9, 1.1, 0.97, 1.03, 0.92]  # per hairColor: individual dye factor on cloth colours (Character.luau)
TINT_SHIFT = [0, -0.1, 0.08, -0.16, 0.12, -0.05, 0.05, -0.12]  # per (hairColor + skin - 2) % 8: kingdom tint factor shift

# KitTint factors for kingdom-tinted pieces (shade(kingdomColor, f), as the part-built rigs do); keys are piece names without the
# _l/_r side suffix
KIT_TINT = {"sleeve_soldier": 0.85, "sleeve_robe": 0.72, "torso_tunic": 0.8, "torso_work": 0.85, "torso_jerkin": 1.0,
            "torso_sleeveless": 0.85, "torso_robe": 0.66, "torso_tabard": 1.0, "torso_regal": 1.0, "hat_hood": 0.72, "hat_ribbon": 0.85,
            "hat_pompom": 0.85, "crown_cap": 0.9, "strap_kingdom": 0.85, "cape": 0.58, "tool_pennant": 0.9, "crest_crimson": 1.0,
            "crest_azure": 1.0, "crest_emerald": 1.0, "crest_gold": 1.0, "shield_crimson": 0.9, "shield_azure": 0.9, "shield_emerald": 0.9,
            "shield_gold": 0.9, "neck_scarf": 0.8}


def hair_for(look):
    s = HAIR_SETS[0 if look["hairColor"] <= 4 else 1]
    return s[(look["hair"] - 1) % len(s)]


def face_for(look):
    return FACES[(look["hair"] + 2 * look["outfit"] + look["skin"]) % len(FACES)]


def boot_for(job, look):
    lst = BOOTS.get(job, BOOTS["default"])
    return lst[(look["outfit"] + look["skin"]) % len(lst)]


def torso_for(job, look):
    lst = TORSO_VARIANTS.get(job)
    return lst[(look["outfit"] - 1) % len(lst)] if lst else None


def accessory_for(look):
    return ACCESSORIES[(look["outfit"] + 2 * look["hair"] + 3 * look["skin"]) % len(ACCESSORIES)]


DEFAULT_LOOK = {"skin": 1, "hair": 1, "hairColor": 1, "outfit": 1}


def names_for(job, look=None, kingdom="crimson", face=None, hair=None):
    """Piece names for one citizen (sided slots expanded). `look` = {skin, hair, hairColor, outfit} (1-based)."""
    look = look or DEFAULT_LOOK
    a = ASSEMBLIES[job]
    face = face or face_for(look)
    hair = hair or hair_for(look)
    out = []
    for slot, val in a.items():
        if slot == "extras":
            for v in val:
                v = v.replace("%kingdom%", kingdom).replace("%accessory%", accessory_for(look) or "")
                if v:
                    out.append(v)
            continue
        if val is None:
            continue
        val = (val.replace("%face%", face).replace("%kingdom%", kingdom).replace("%hair%", hair)
               .replace("%torso%", torso_for(job, look) or ""))
        if slot == "boot" and job in BOOTS:
            val = boot_for(job, look)
        if slot in SIDED:
            out += [val + "_l", val + "_r"]
        else:
            out.append(val)
    return out


CLOTH = {job: v[0] for job, v in CLOTH_VARIANTS.items()}  # first variant per job (comparison scripts)
