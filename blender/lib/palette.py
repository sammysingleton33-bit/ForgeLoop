"""FORGE palette v1: one shared 512 px texture for every asset in the kit.

Every mesh uses one material that samples this texture; a face's colour is chosen by
pointing its UVs at a swatch. Because all assets share the same image, Roblox only
needs one texture upload for the whole kit (see blender/README.md).

Each 32 px swatch is not flat: bottom-to-top it ramps from darker to lighter (cheap
painted shading), and left-to-right it shifts slightly cool-to-warm (per-part tint
variation without extra colours). Generators choose the position inside a swatch.

Indices are APPEND-ONLY: never reorder or delete an entry, or every exported asset's
UVs change. Bump PALETTE_VERSION when appending.

No bpy import here, so tests and tools can use it with plain Python.
"""

PALETTE_VERSION = 1  # values tuned 2026-10-12 (muted thatch and straw, saturated kingdom gold, jewel-green kingdom apart from foliage); indices unchanged
SIZE = 512
SWATCH = 32
GRID = SIZE // SWATCH  # 16 x 16 swatches
PAD = 3  # pixels kept away from swatch edges when mapping UVs (mip bleed margin)

# fmt: off
_ENTRIES = [
    # row 0: foliage and grass
    ("leaf_dark", "2E6B2F"), ("leaf_mid", "3F8A36"), ("leaf_light", "63A83C"), ("leaf_bright", "8CC43F"),
    ("leaf_yellow", "B7D24A"), ("grass_dark", "4A8A2E"), ("grass", "67A93A"), ("grass_light", "8FC24C"),
    ("pine_dark", "1F5236"), ("pine_mid", "2D6B43"), ("pine_light", "4A8A50"), ("moss", "6E8F3A"),
    ("autumn_orange", "D9822B"), ("autumn_red", "B9472E"), ("autumn_yellow", "E2B13C"), ("blossom_pink", "E89AB0"),
    # row 1: bark, wood, thatch
    ("bark_dark", "4A3222"), ("bark", "6B4A30"), ("bark_light", "8A6442"), ("birch_white", "E8E2D2"),
    ("birch_mark", "3B3530"), ("wood_dark", "5C3B22"), ("wood", "8B5A33"), ("wood_light", "B07B4A"),
    ("wood_pale", "CFA171"), ("timber", "4B3020"), ("thatch_dark", "9C8556"), ("thatch", "BFA36C"),
    ("thatch_light", "D6C08E"), ("straw", "E6D49A"), ("hay", "CDB373"), ("rope", "B89A6A"),
    # row 2: stone, plaster, slate
    ("stone_dark", "6F6A63"), ("stone", "8F8A82"), ("stone_light", "B3ADA3"), ("stone_pale", "CFC9BE"),
    ("sandstone_dark", "8A7558"), ("sandstone", "B39A74"), ("sandstone_light", "D6BE95"), ("stone_cool_dark", "5E6772"),
    ("stone_cool", "7F8A96"), ("stone_cool_light", "A7B1BB"), ("plaster", "EFE3C8"), ("plaster_white", "F8F1E2"),
    ("plaster_shadow", "D8C6A3"), ("cobble", "9C9183"), ("slate_dark", "3F4650"), ("slate", "56606B"),
    # row 3: earth, water, glass, iron
    ("dirt_dark", "7A5A3A"), ("dirt", "A27A4E"), ("dirt_light", "C49E6E"), ("path_sand", "D8BE8A"),
    ("mud", "6B5038"), ("water_deep", "2A6FA8"), ("water", "3B93C9"), ("water_light", "69BEE3"),
    ("foam", "E6F4F8"), ("window_dark", "2B3340"), ("window_glow", "F2C46B"), ("glass", "7FB6D4"),
    ("black", "22252A"), ("iron_dark", "3F444B"), ("iron", "5F666F"), ("steel", "A3ADB7"),
    # row 4: metals, skin, hair, plain cloth
    ("gold", "E5B53A"), ("gold_dark", "B58423"), ("bronze", "B07A3A"), ("copper_green", "5FA391"),
    ("skin_1", "F2C9A0"), ("skin_2", "D9A276"), ("skin_3", "B07A52"), ("skin_4", "7D5136"),
    ("hair_dark", "3A2A20"), ("hair_brown", "6B4428"), ("hair_blond", "D9B05A"), ("hair_red", "A8502A"),
    ("cloth_white", "ECE6D8"), ("cloth_brown", "8A6A4A"), ("cloth_grey", "7E7E7A"), ("leather", "7A4A2A"),
    # rows 5-8: kingdoms (same 16 roles per row, see KINGDOM_ROLES)
    ("red_roof_dark", "8C2E2B"), ("red_roof", "C14A3A"), ("red_roof_light", "DC6D52"), ("red_cloth_dark", "6E1C22"),
    ("red_cloth", "B32E32"), ("red_cloth_light", "D9574F"), ("red_trim", "E8B93E"), ("red_trim_dark", "A87A22"),
    ("red_shutter", "9C3B2E"), ("red_stone", "9A8B80"), ("red_stone_dark", "74675E"), ("red_stone_light", "BFB1A5"),
    ("red_accent", "F0D9A8"), ("red_wood", "7A4630"), ("red_emblem", "F4E4B8"), ("red_glow", "F28A3C"),

    ("blue_roof_dark", "2A4A7A"), ("blue_roof", "3B6DB0"), ("blue_roof_light", "5C8FCC"), ("blue_cloth_dark", "1D3462"),
    ("blue_cloth", "2E5BA8"), ("blue_cloth_light", "5A86C8"), ("blue_trim", "D9DEE6"), ("blue_trim_dark", "9AA5B3"),
    ("blue_shutter", "3A5F8F"), ("blue_stone", "8A929C"), ("blue_stone_dark", "636B75"), ("blue_stone_light", "B0B7BF"),
    ("blue_accent", "E3ECF5"), ("blue_wood", "5E4A3A"), ("blue_emblem", "F2F5FA"), ("blue_glow", "8FD3F2"),

    ("green_roof_dark", "175443"), ("green_roof", "23805F"), ("green_roof_light", "45A383"), ("green_cloth_dark", "16503F"),
    ("green_cloth", "1E7A58"), ("green_cloth_light", "48A684"), ("green_trim", "C9873A"), ("green_trim_dark", "8F5A24"),
    ("green_shutter", "2C6A52"), ("green_stone", "8C8E7C"), ("green_stone_dark", "66695A"), ("green_stone_light", "B2B39E"),
    ("green_accent", "E9DFAF"), ("green_wood", "6A4A2A"), ("green_emblem", "F0E2B0"), ("green_glow", "B8E06A"),

    ("yellow_roof_dark", "B08408"), ("yellow_roof", "EBB910"), ("yellow_roof_light", "F7D447"), ("yellow_cloth_dark", "A87A06"),
    ("yellow_cloth", "F0BE14"), ("yellow_cloth_light", "FADA5A"), ("yellow_trim", "6E3F92"), ("yellow_trim_dark", "4A2868"),
    ("yellow_shutter", "B8860B"), ("yellow_stone", "C4A47A"), ("yellow_stone_dark", "9A7D58"), ("yellow_stone_light", "DEC79F"),
    ("yellow_accent", "FFF2CF"), ("yellow_wood", "8A5A30"), ("yellow_emblem", "FFF6DD"), ("yellow_glow", "FFD86B"),
    # row 9: crops, flowers, canvas, fire
    ("wheat", "D9BC6A"), ("wheat_dark", "C49A3A"), ("crop_green", "7DB043"), ("crop_dark", "4F7F2C"),
    ("pumpkin", "E07B26"), ("cabbage", "9BC768"), ("apple_red", "C8322B"), ("flower_red", "D9343A"),
    ("flower_yellow", "F4D03F"), ("flower_white", "F5F3EA"), ("flower_purple", "8E5CC2"), ("flower_blue", "4F8FE0"),
    ("canvas", "E8DCC0"), ("canvas_dark", "C8B793"), ("fire", "F2742B"), ("ember", "FFC14A"),
    # row 10: extra foliage, rock and ore (v1 append)
    ("oak_dark", "356B2A"), ("oak_mid", "4F8F2F"), ("oak_light", "7AB33A"), ("oak_sun", "A6CF4A"),
    ("birch_leaf", "9CC94A"), ("birch_leaf_light", "C4DE6A"), ("pine_blue", "2A5C4E"), ("pine_tip", "5E9A5A"),
    ("granite_dark", "6E6A66"), ("granite", "8E8984"), ("granite_light", "B4AEA6"), ("rock_warm", "9A8670"),
    ("ore_iron", "A0563A"), ("ore_gold", "F2C230"), ("crystal", "6FD0E0"), ("coal", "2F2F33"),
    # row 11: cloth, armour, siege, misc (v1 append)
    ("tunic_brown", "8B5E3C"), ("tunic_green", "5E7F3A"), ("tunic_blue", "4F6E9A"), ("tunic_red", "9E4A3A"),
    ("tunic_cream", "D9CBA6"), ("apron", "BFAF8E"), ("armor", "8E99A4"), ("armor_dark", "5D6670"),
    ("armor_light", "C3CCD4"), ("chainmail", "7A828A"), ("siege_wood", "9A6A3E"), ("siege_wood_dark", "6A4528"),
    ("road", "B89A70"), ("road_dark", "927652"), ("hay_dark", "A98F4E"), ("clay", "C26E4A"),
]
# fmt: on

KINGDOMS = ("red", "blue", "green", "yellow")
KINGDOM_ROLES = (
    "roof_dark", "roof", "roof_light", "cloth_dark", "cloth", "cloth_light", "trim", "trim_dark",
    "shutter", "stone", "stone_dark", "stone_light", "accent", "wood", "emblem", "glow",
)

NAMES = [n for n, _ in _ENTRIES]
INDEX = {n: i for i, n in enumerate(NAMES)}
assert len(INDEX) == len(_ENTRIES), "duplicate palette names"
assert len(_ENTRIES) <= GRID * GRID


def hex_to_rgb(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


RGB = {n: hex_to_rgb(h) for n, h in _ENTRIES}


def kingdom_color(kingdom, role):
    """Palette name for a kingdom role, e.g. ('blue', 'roof') -> 'blue_roof'."""
    if kingdom not in KINGDOMS:
        raise ValueError(f"unknown kingdom {kingdom!r}; expected one of {KINGDOMS}")
    if role not in KINGDOM_ROLES:
        raise ValueError(f"unknown kingdom role {role!r}")
    return f"{kingdom}_{role}"


def swatch_uv(name, u01=0.5, v01=0.5):
    """UV for a position inside a swatch. u01: cool(0)..warm(1) tint; v01: dark(0)..light(1)."""
    i = INDEX[name]
    col, row = i % GRID, i // GRID
    inner = SWATCH - 2 * PAD
    u01 = min(1.0, max(0.0, u01))
    v01 = min(1.0, max(0.0, v01))
    x = col * SWATCH + PAD + u01 * inner
    y = row * SWATCH + PAD + v01 * inner
    return x / SIZE, y / SIZE


def swatch_at_uv(u, v):
    """Inverse lookup (validation): palette name under a UV, or None if outside any used swatch."""
    if not (0.0 <= u <= 1.0 and 0.0 <= v <= 1.0):
        return None
    col = min(GRID - 1, int(u * GRID))
    row = min(GRID - 1, int(v * GRID))
    i = row * GRID + col
    return NAMES[i] if i < len(NAMES) else None


def _shade(rgb, u01, v01):
    # vertical ramp: 0.80 at the bottom -> 1.10 at the top (value), slight warm/cool shift across
    k = 0.80 + 0.30 * v01
    t = (u01 - 0.5) * 2.0  # -1 cool .. +1 warm
    warm = (1.0 + 0.045 * t, 1.0 + 0.01 * t, 1.0 - 0.05 * t)
    return tuple(min(1.0, max(0.0, c * k * w)) for c, w in zip(rgb, warm))


def build_pixels():
    """Flat RGBA float list, bottom row first (Blender image order), sRGB-encoded values."""
    px = [0.0] * (SIZE * SIZE * 4)
    unused = (1.0, 0.0, 1.0)  # magenta: an unused swatch showing up in a render is a bug
    inner = SWATCH - 2 * PAD
    for i in range(GRID * GRID):
        col, row = i % GRID, i // GRID
        rgb = RGB[NAMES[i]] if i < len(NAMES) else None
        for yy in range(SWATCH):
            v01 = min(1.0, max(0.0, (yy - PAD) / inner))
            y = row * SWATCH + yy
            for xx in range(SWATCH):
                u01 = min(1.0, max(0.0, (xx - PAD) / inner))
                c = _shade(rgb, u01, v01) if rgb else unused
                o = (y * SIZE + col * SWATCH + xx) * 4
                px[o:o + 4] = (c[0], c[1], c[2], 1.0)
    return px
