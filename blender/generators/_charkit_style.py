"""Character kit (FL-0135): style switch, palette and the piece registry shared by the _charkit_* modules.

Two stylised low-poly directions were built from the SAME piece definitions for the one-pass comparison
(games/game-001/art/reviews/char-mesh.md):
  A  smooth-shaded rounded low-poly (round lofts, soft shading, small readable face)
  B  faceted / flat-shaded chunky low-poly (fewer, squarer segments, flat normals, faceted colour variation)
Every builder asks the Style for segment counts / roundness, so one definition yields both looks.
"""

from lib.ckit import M, grey, merge, mix, rgb, loft  # noqa: F401

# ------------------------------------------------------------------ rig constants (Kit/Character.luau)
HIP_Y = 2.2
TORSO_H = 1.7
NECK_Y = HIP_Y + TORSO_H  # 3.9
SHOULDER_Y = NECK_Y - 0.4  # 3.5
HEAD_Y = NECK_Y + 0.8 - 0.06  # 4.64
HEAD_TOP = HEAD_Y + 0.8  # 5.44
ARM_X = 1.46  # arm joint |x|: reference torso width 2.1 / 2 + SHOULDER_OUT 0.41
SHOULDER_OUT = 0.41
ARM_SPLAY = 7.0  # degrees, the arms hang splayed outward at rest
LEG_X = 0.5
TORSO_D = 1.15
TRUNK_REF_W = 2.1


class Style:
    """name 'A' = smooth rounded, 'B' = faceted chunky."""

    def __init__(self, name):
        assert name in ("A", "B")
        self.name = name
        self.A = name == "A"

    def seg(self, a, b=None):
        """segment count: `a` for A, `b` (default: two thirds of a, even, at least 6) for B."""
        if self.A:
            return a
        if b is None:
            b = max(6, int(round(a * 0.66 / 2)) * 2)
        return b

    @property
    def n(self):
        """super-ellipse exponent of round rings (2 = ellipse, higher = squarer)."""
        return 2.0 if self.A else 2.7

    @property
    def smooth(self):
        return self.A

    @property
    def phase(self):
        """ring phase: B puts a flat facet (not a ridge) at the front."""
        return 0.0 if self.A else None  # None -> caller derives pi / seg

    @property
    def ao(self):
        return 0.22

    @property
    def facet(self):
        return 0.0 if self.A else 0.06

    def rings(self, a, b=None):
        return self.seg(a, b)


STYLE_A = Style("A")
STYLE_B = Style("B")


def ph(S, seg):
    """Ring phase for style S: ridge at the front for A, flat facet at the front for B."""
    import math

    return 0.0 if S.A else math.pi / seg


# ------------------------------------------------------------------ palette (sRGB, mirrors Kit/Character.luau)
STEEL = rgb(176, 182, 192)
STEEL_DARK = rgb(84, 90, 100)
BLADE = rgb(200, 206, 216)
BURLAP = rgb(146, 108, 70)
LINEN = rgb(226, 214, 186)
LEATHER = rgb(120, 78, 46)
LEATHER_DARK = rgb(72, 46, 30)
STRAW = rgb(214, 170, 76)
STRAW_DARK = rgb(176, 130, 52)
ASH = rgb(214, 190, 146)
WOOD = rgb(139, 90, 51)
WOOD_LIGHT = rgb(176, 123, 74)
WOOD_DARK = rgb(92, 59, 34)
WOOD_PALE = rgb(198, 152, 104)
GOLD = rgb(229, 181, 58)
GOLD_DARK = rgb(176, 128, 30)
ERMINE = rgb(242, 238, 228)
ERMINE_SPOT = rgb(34, 30, 34)
CANVAS = rgb(242, 234, 212)
IRON = rgb(63, 68, 75)
INK = rgb(34, 24, 22)  # eyes, brows
MOUTH = rgb(120, 54, 48)
BLUSH = rgb(238, 150, 140)
LAMP = rgb(255, 226, 140)
TINT = grey(1.0)  # "tinted" pieces are baked white (the shading term keeps them in 0.78-1.0)


class Piece:
    __slots__ = ("name", "m", "joint", "slot", "tint", "weld", "tags", "info")

    def __init__(self, name, m, joint, slot, tint, weld=None, tags=(), info=None):
        self.name, self.m, self.joint, self.slot, self.tint = name, m, joint, slot, tint
        self.weld, self.tags, self.info = weld, list(tags), dict(info or {})


class Registry:
    """Ordered piece collection. Sided pieces are defined once (the character's right, +x) and mirrored."""

    def __init__(self, style):
        self.S = style
        self.pieces = {}

    def add(self, name, m, joint, slot, tint, weld=None, tags=(), info=None):
        assert name not in self.pieces, f"duplicate piece {name}"
        self.pieces[name] = Piece(name, m, joint, slot, tint, weld, tags, info)
        return self.pieces[name]

    def add_sided(self, base, m_right, slot, tint, weld, tags=(), info=None):
        """Registers base_r (joint RightX, as modelled) and base_l (mirror, joint LeftX)."""
        kind = {"arm": "Arm", "sleeve": "Arm", "shield": "Arm", "glove": "Arm", "leg": "Leg", "boot": "Leg"}[slot]
        self.add(base + "_r", m_right, "Right" + kind, slot, tint, weld, tags, info)
        self.add(base + "_l", m_right.copy().mirror_x(), "Left" + kind, slot, tint, weld, tags, info)
