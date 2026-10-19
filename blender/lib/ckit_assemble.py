"""Blender-side assembly of kit rigs (FL-0135): builds a citizen from piece meshes + an assembly + look + kingdom colour.

The tint table mirrors Kit/Character.luau (SKIN, HAIR_COLORS, kingdom colours, Parts.shade) so renders here and the
Kit's MeshPart.Color agree. Colour model (assumption, unverified in Studio): rendered colour = baked vertex colour x
MeshPart.Color, multiplied per channel in sRGB.
"""

import math

from . import ckit, ckit_view

SKIN = [(242, 201, 160), (255, 222, 196), (210, 156, 112), (162, 108, 70), (110, 70, 44), (78, 50, 34)]
HAIR = [(92, 58, 32), (36, 28, 24), (150, 94, 48), (222, 178, 92), (178, 74, 34), (206, 204, 198), (62, 42, 30), (242, 224, 166)]
KINGDOM = {"crimson": (190, 40, 50), "azure": (40, 110, 210), "gold": (235, 185, 16), "emerald": (35, 128, 95)}
TINT_FACTOR = {"torso": 0.8, "sleeve": 0.78, "hat": 0.9, "hatband": 0.9, "crest": 1.0, "cape": 1.0, "extra": 0.85, "toolband": 0.9,
               "tool": 0.85, "leg": 0.5}


def c01(rgb255):
    return tuple(c / 255.0 for c in rgb255)


def shade(c, f):
    return tuple(min(1.0, max(0.0, v * f)) for v in c)


def tint_for(piece, ctx):
    """MeshPart.Color the Kit would set for `piece` (a Piece with .tint/.slot/.info) in this context."""
    t = piece.tint
    if t in (None, "fixed"):
        return (1.0, 1.0, 1.0)
    if t == "skin":
        return c01(SKIN[ctx.get("skin", 0)])
    if t == "hair":
        return c01(HAIR[ctx.get("hairColor", 0)])
    if t == "kingdom":
        base = piece.name[:-2] if piece.name.endswith(("_l", "_r")) else piece.name
        f = ctx.get("kit_tint", {}).get(base) or TINT_FACTOR.get(piece.slot, 0.85)
        return shade(c01(KINGDOM[ctx.get("kingdom", "crimson")]), f)
    if t == "cloth":
        palette = ctx.get("cloth", {})
        c = palette.get(piece.slot) or palette.get("default") or (200, 200, 200)
        return c01(c)
    return (1.0, 1.0, 1.0)


def build(pieces, names, ctx, collection=None, facet=0.0, location=(0.0, 0.0, 0.0), yaw=0.0, tag=""):
    """Create preview objects for the piece names `names` ({slot: piece name} flattened to a list by the caller).

    pieces: {name: Piece}. Returns the list of objects (each already tinted)."""
    objs = []
    for n in names:
        p = pieces[n]
        o = ckit_view.make(f"{tag}{n}", p.m, tint_for(p, ctx), facet=facet, seed=hash(n) & 0xFFFF, collection=collection)
        o.location.x += -location[0]
        o.location.y += location[2]
        o.location.z += location[1]
        if yaw:
            _yaw(o, yaw, location)
        objs.append(o)
    return objs


def _yaw(o, deg, pivot):
    """Rotate an object about the vertical axis through `pivot` (rig x, z); deg = turn of the character's facing."""
    a = math.radians(deg)
    px, pz = -pivot[0], pivot[2]  # preview-space pivot
    x, y = o.location.x - px, o.location.y - pz
    c, s = math.cos(a), math.sin(a)
    o.location.x = px + x * c - y * s
    o.location.y = pz + x * s + y * c
    o.rotation_euler.z += a
