"""Piece contact sheets of the character kit (FL-0135): every piece on a grid, tinted the way the Kit would tint it.

  ~/forge-bpy/bin/python blender/scripts/charkit_sheets.py --out DIR [--groups heads,hair,torso,limbs,hats,tools,extras] [--quick]
Reads the generator registry (same pieces as citizen_kit.fbx). --quick = Workbench (fast, no sun/shadows).
"""

import argparse
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(HERE))

import bpy  # noqa: E402,F401

from lib import ckit_assemble, ckit_view  # noqa: E402

GROUPS = {
    "heads": lambda p: p.slot == "head",
    "hair": lambda p: p.slot == "hair",
    "torso": lambda p: p.slot == "torso",
    "limbs": lambda p: p.slot in ("arm", "sleeve", "leg", "boot") and p.joint.startswith("Right"),
    "hats": lambda p: p.slot in ("hat", "hatband", "crest"),
    "tools": lambda p: p.slot in ("tool", "toolband"),
    "extras": lambda p: p.slot in ("extra", "cape", "shield"),
}
VIEW = {"heads": (3, 300, 22, 6), "hair": (5, 260, -30, 10), "torso": (5, 300, 20, 8), "limbs": (6, 250, 20, 8), "hats": (5, 260, 25, 14),
        "tools": (6, 260, 25, 10), "extras": (4, 330, 25, 10)}


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--groups", default=",".join(GROUPS))
    ap.add_argument("--quick", action="store_true")
    a = ap.parse_args(argv)
    from generators import char_kit

    R, rig, hand = char_kit.registry()
    ctx = {"skin": 0, "hairColor": 1, "kingdom": "crimson", "kit_tint": rig.KIT_TINT,
           "cloth": {"default": (190, 170, 130), "leg": (110, 90, 60)}}
    ckit_view.QUICK = a.quick
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    for g in a.groups.split(","):
        items, tints = [], {}
        for n, p in R.pieces.items():
            if GROUPS[g](p):
                items.append((n, p.m))
                tints[n] = ckit_assemble.tint_for(p, ctx)
        cols, cell, yaw, elev = VIEW[g]
        path = out / f"kit_{g}.png"
        ckit_view.piece_sheet(items, str(path), cols=cols, cell=cell, yaw=yaw, elev=elev, samples=12, facet=R.S.facet, tints=tints)
        print(f"[sheets] {g}: {len(items)} pieces -> {path}", flush=True)


if __name__ == "__main__":
    main(sys.argv[1:] if "--" not in sys.argv else sys.argv[sys.argv.index("--") + 1:])
