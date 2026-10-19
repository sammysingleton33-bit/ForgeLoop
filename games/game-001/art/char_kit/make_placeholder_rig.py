#!/usr/bin/env python3
"""make_placeholder_rig — writes the PLACEHOLDER citizen kit (rig.json shape, schema_version 1) the Kit specs use.

FL-0135 (D-057), FORGE-02. Standard library only. Not art: boxes sized from today's part-built rig (Kit/Character.luau:
proportions, shoulder pivots, arm splay, tool grips) so every pose spec that holds for the primitive rig can be asked of a
mesh rig built from it. It exercises every feature of the data: %look.<axis>% variants, %kingdom% variants, mirror
pieces, an `empty` piece, weld_to by joint and by piece id, the hauler's TorsoTool joint, all five tints.

    python3 games/game-001/art/char_kit/make_placeholder_rig.py [--out PATH] [--check]

Default output games/game-001/tests/world/fixtures/char_kit_placeholder.rig.json (deterministic: same bytes every run).
--check exits 1 when the committed file differs. The real kit is games/game-001/art/char_kit/rig.json (Blender worker).
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
DEFAULT_OUT = ROOT / "games/game-001/tests/world/fixtures/char_kit_placeholder.rig.json"

# --- Kit/Character.luau proportions (feet at y = 0)
HIP_Y, TORSO_H, TORSO_D = 2.2, 1.7, 1.15
NECK_Y = HIP_Y + TORSO_H
SHOULDER_Y = NECK_Y - 0.4
SHOULDER_OUT = 0.41
ARM = (0.78, 1.7, 0.82)
SPLAY = math.radians(7)
HAND_UP = 0.2
HEAD_D, HEAD_Y = 1.6, NECK_Y + 0.8 - 0.06
LEG = (0.95, 2.2, 1.0)
WIDTH = 2.1  # one torso width for the whole fixture (the joint table is global)
GRIP_Z = -0.55
KINGDOMS = ("crimson", "azure", "emerald", "gold", "neutral")


def r(x: float) -> float:
    return round(x + 0.0, 4)


def v3(a, b, c) -> list:
    return [r(a), r(b), r(c)]


def arm_geometry(side: int):
    """Centre, size of the splayed arm's bounding box and its shoulder pivot for side -1 (left) / +1 (right)."""
    shoulder = (side * WIDTH / 2, SHOULDER_Y)
    arm_x = WIDTH / 2 + ARM[0] / 2 + 0.02
    drop_x, drop_y = arm_x - WIDTH / 2, -(ARM[1] / 2 - (NECK_Y - SHOULDER_Y))
    # Character.luau: the left arm turns -SPLAY about Z, the right +SPLAY
    ang = SPLAY if side > 0 else -SPLAY
    ox, oy = side * drop_x, drop_y
    cx = shoulder[0] + ox * math.cos(ang) - oy * math.sin(ang)
    cy = shoulder[1] + ox * math.sin(ang) + oy * math.cos(ang)
    hx = ARM[0] / 2 * math.cos(ang) + ARM[1] / 2 * abs(math.sin(ang))
    hy = ARM[0] / 2 * abs(math.sin(ang)) + ARM[1] / 2 * math.cos(ang)
    hand = (cx + (0 * math.cos(ang) - (-ARM[1] / 2 + HAND_UP) * math.sin(ang)),
            cy + (0 * math.sin(ang) + (-ARM[1] / 2 + HAND_UP) * math.cos(ang)))
    return (cx, cy), (2 * hx, 2 * hy, ARM[2]), (side * (WIDTH / 2 + SHOULDER_OUT), SHOULDER_Y), hand


def build() -> dict:
    pieces: dict = {}

    def piece(pid, joint, center, size, tris, tint, slot, weld_to=None, **extra):
        d = {"joint": joint, "weld_to": weld_to, "bbox_center": v3(*center), "size": v3(*size), "tris": tris,
             "tint": tint, "slot": slot, "tags": extra.pop("tags", [])}
        d.update(extra)
        pieces[pid] = d

    (lcx, lcy), arm_size, l_pivot, _ = arm_geometry(-1)
    (rcx, rcy), _, r_pivot, hand = arm_geometry(+1)
    hx, hy = hand

    joints = {
        "Torso": {"parent": "Root", "pos": v3(0, HIP_Y, 0)},
        "Head": {"parent": "Torso", "pos": v3(0, NECK_Y, 0)},
        "LeftArm": {"parent": "Torso", "pos": v3(*l_pivot, 0)},
        "RightArm": {"parent": "Torso", "pos": v3(*r_pivot, 0)},
        "LeftLeg": {"parent": "Torso", "pos": v3(-0.5, HIP_Y, 0)},
        "RightLeg": {"parent": "Torso", "pos": v3(0.5, HIP_Y, 0)},
        "Tool": {"parent": "RightArm", "pos": v3(hx, hy, 0)},
        "TorsoTool": {"parent": "Torso", "pos": v3(WIDTH / 2 + ARM[0] / 2 + 0.02 - 0.6, NECK_Y - 0.1, TORSO_D / 2)},
    }

    # heads (4 faces) and the soldier's helm
    for i, tris in enumerate((150, 140, 170, 160), 1):
        piece(f"head_{i:02d}", "Head", (0, HEAD_Y, 0), (HEAD_D,) * 3, tris, "skin", "head", tags=[f"face_{i}"])
    piece("head_helm", "Head", (0, NECK_Y + 0.8, 0), (1.45, 1.6, 1.45), 80, "fixed", "head", tags=["soldier"])

    # hair (8 styles; 05 is bald: no mesh), welded to whichever head the assembly has
    hair = [
        ("short", (0, HEAD_Y + 0.13, 0.13), (1.66, 1.66, 1.66), 90, "hair", "hair"),
        ("curls", (0, HEAD_Y + 0.22, 0.1), (2.05, 2.05, 2.05), 100, "hair", "hair"),
        ("long", (0, HEAD_Y - 0.05, 0.29), (1.87, 1.87, 1.87), 100, "hair", "hair"),
        ("beard", (0, HEAD_Y - 0.48, -0.5), (1.14, 0.76, 0.52), 40, "hair", "hair"),
        None,
        ("hood", (0, HEAD_Y + 0.08, 0.3), (1.83, 1.83, 1.83), 90, "kingdom", "hat"),
        ("bun", (0, HEAD_Y + 0.4, 0.3), (1.7, 1.9, 1.7), 100, "hair", "hair"),
        ("crop", (0, HEAD_Y + 0.1, 0.05), (1.62, 1.5, 1.62), 60, "hair", "hair"),
    ]
    for i, h in enumerate(hair, 1):
        if h is None:
            pieces[f"hair_{i:02d}"] = {"joint": "Head", "weld_to": "Head", "empty": True, "tris": 0,
                                        "tint": "hair", "slot": "hair", "tags": ["bald"]}
        else:
            name, c, s, tris, tint, slot = h
            piece(f"hair_{i:02d}", "Head", c, s, tris, tint, slot, weld_to="Head", tags=[name])

    # job headwear: fixed (baked) colours; a kingdom-coloured crown over the straw hat
    piece("hat_farmer", "Head", (0, HEAD_Y + 0.62, 0), (3.1, 0.42, 3.1), 50, "fixed", "hat", weld_to="Head")
    piece("hat_farmer_crown", "Head", (0, HEAD_Y + 1.1, 0), (1.5, 0.55, 1.5), 30, "kingdom", "hat", weld_to="hat_farmer")
    piece("hat_woodcutter", "Head", (0, HEAD_Y + 0.7, 0.05), (1.5, 1.5, 1.5), 60, "fixed", "hat", weld_to="Head")
    piece("hat_miner", "Head", (0, HEAD_Y + 0.79, 0), (1.9, 0.7, 1.9), 60, "fixed", "hat", weld_to="Head")
    piece("hat_miner_lamp", "Head", (0, HEAD_Y + 0.8, -1.05), (0.5, 0.4, 0.35), 12, "fixed", "hat", weld_to="hat_miner",
          tags=["detail"])
    piece("hat_builder", "Head", (0, HEAD_Y + 0.815, 0), (1.8, 0.75, 1.8), 60, "fixed", "hat", weld_to="Head")
    piece("hat_builder_visor", "Head", (0, HEAD_Y + 0.56, -1.2), (1.3, 0.16, 0.9), 12, "fixed", "hat", weld_to="hat_builder",
          tags=["detail"])

    # idle accessories (head and neck), one of them empty
    piece("acc_01", "Head", (0, HEAD_Y + 0.4, 0), (1.6, 0.22, 1.6), 24, "kingdom", "acc", weld_to="Head", tint_factor=0.72)
    piece("acc_02", "Head", (0, HEAD_Y - 0.64, 0), (1.5, 0.35, 1.5), 30, "cloth", "acc", weld_to="Head")
    pieces["acc_03"] = {"joint": "Head", "weld_to": "Head", "empty": True, "tris": 0, "tint": "fixed", "slot": "acc",
                        "tags": ["none"]}

    # torsos (outfit variants), soldier armour and governor robe in the kingdom colours
    torso_size = (WIDTH, TORSO_H, TORSO_D)
    torso_c = (0, HIP_Y + TORSO_H / 2, 0)
    piece("torso_01", "Torso", torso_c, torso_size, 130, "kingdom", "torso", tags=["tunic"])
    piece("torso_02", "Torso", torso_c, torso_size, 140, "cloth", "torso", tags=["apron"])
    piece("torso_03", "Torso", torso_c, torso_size, 120, "kingdom", "torso", tint_factor=0.9, tags=["vest"])
    for k in KINGDOMS:
        piece(f"armour_{k}", "Torso", torso_c, (WIDTH, TORSO_H, TORSO_D + 0.05), 220, "kingdom", "armour", tags=[k])
        piece(f"cape_{k}", "Torso", (0, NECK_Y - 1.65 + 0.2, TORSO_D / 2 + 0.2), (2.5, 3.3, 0.18), 12, "kingdom", "cape",
              weld_to="Torso", tags=[k])
    piece("torso_regal", "Torso", torso_c, torso_size, 200, "kingdom", "torso", tint_factor=1.0, tags=["governor"])

    # arms: explicit left/right (the splay is part of the geometry); sleeves welded to them
    piece("arm_l", "LeftArm", (lcx, lcy, 0), arm_size, 45, "skin", "arm")
    piece("arm_r", "RightArm", (rcx, rcy, 0), arm_size, 45, "skin", "arm")
    sleeve = (arm_size[0] + 0.04, arm_size[1] * 0.6, arm_size[2] + 0.04)
    piece("sleeve_l", "LeftArm", (lcx, lcy + arm_size[1] * 0.2, 0), sleeve, 25, "cloth", "sleeve", weld_to="LeftArm")
    piece("sleeve_r", "RightArm", (rcx, rcy + arm_size[1] * 0.2, 0), sleeve, 25, "cloth", "sleeve", weld_to="RightArm")
    piece("sleeve_kingdom_l", "LeftArm", (lcx, lcy + arm_size[1] * 0.2, 0), sleeve, 25, "kingdom", "sleeve",
          weld_to="LeftArm")
    piece("sleeve_kingdom_r", "RightArm", (rcx, rcy + arm_size[1] * 0.2, 0), sleeve, 25, "kingdom", "sleeve",
          weld_to="RightArm")

    # legs and boots: mirror pieces, the left one is the authored one
    piece("leg_trousers", "LeftLeg", (-0.5, LEG[1] / 2, 0), LEG, 55, "cloth", "leg", mirror=True)
    piece("leg_mail", "LeftLeg", (-0.5, LEG[1] / 2, 0), LEG, 60, "fixed", "leg", mirror=True)
    for i, tris in enumerate((35, 45), 1):
        piece(f"boot_{i:02d}", "LeftLeg", (-0.5, 0.3, -0.15), (1.0, 0.6, 1.3), tris, "fixed", "boot", weld_to="LeftLeg",
              mirror=True)

    # tools: boxes at the primitive tools' grips (upright, so the box is honest), heads welded by piece id
    gx = hx + 0.03
    piece("tool_hoe", "Tool", (gx, hy + 1.6, GRIP_Z), (0.38, 4.2, 0.38), 40, "fixed", "tool")
    piece("tool_hoe_blade", "Tool", (gx, hy + 3.5, GRIP_Z - 0.6), (1.1, 0.34, 1.3), 30, "fixed", "tool", weld_to="tool_hoe",
          tags=["detail"])
    piece("tool_axe", "Tool", (gx, hy + 0.9, GRIP_Z), (0.42, 3.9, 0.42), 40, "fixed", "tool")
    piece("tool_axe_head", "Tool", (gx, hy + 2.0, GRIP_Z - 0.8), (0.5, 1.7, 1.9), 50, "fixed", "tool", weld_to="tool_axe",
          tags=["detail"])
    piece("tool_pick", "Tool", (gx, hy + 1.225, GRIP_Z), (0.4, 4.55, 0.4), 40, "fixed", "tool")
    piece("tool_pick_head", "Tool", (gx, hy + 3.7, GRIP_Z), (0.9, 0.5, 1.6), 50, "fixed", "tool", weld_to="tool_pick",
          tags=["detail"])
    piece("tool_hammer", "Tool", (gx, hy + 0.5, GRIP_Z), (0.42, 3.0, 0.42), 40, "fixed", "tool")
    piece("tool_hammer_head", "Tool", (gx, hy + 2.0, GRIP_Z), (0.8, 1.15, 1.6), 40, "fixed", "tool", weld_to="tool_hammer",
          tags=["detail"])
    piece("tool_spear", "Tool", (gx, hy + 2.2, GRIP_Z), (0.4, 9.0, 0.4), 40, "fixed", "tool")
    piece("tool_spear_head", "Tool", (gx, hy + 7.6, GRIP_Z), (0.75, 1.9, 0.75), 24, "fixed", "tool", weld_to="tool_spear",
          tags=["detail"])
    piece("tool_spear_pennant", "Tool", (gx + 0.7, hy + 5.5, GRIP_Z), (1.2, 0.1, 0.8), 12, "kingdom", "tool",
          weld_to="tool_spear", tags=["detail"])
    piece("tool_bow", "Tool", (gx, hy + 1.0, GRIP_Z), (0.3, 3.4, 0.9), 60, "fixed", "tool")
    piece("tool_staff", "Tool", (gx, hy + 1.1, GRIP_Z), (0.5, 6.4, 0.5), 40, "fixed", "tool")
    piece("tool_staff_orb", "Tool", (gx, hy + 4.55, GRIP_Z), (0.9, 0.9, 0.9), 60, "fixed", "tool", weld_to="tool_staff",
          tags=["detail"])
    sj = joints["TorsoTool"]["pos"]
    piece("tool_sack", "TorsoTool", (sj[0] - 0.86, sj[1] - 1.0, sj[2] + 1.525), (2.7, 2.7, 2.7), 100, "fixed", "back")
    piece("tool_sack_strap", "TorsoTool", (sj[0] - 0.96, sj[1] - 0.72, TORSO_D / 2 + 0.2), (0.34, 2.7, 0.26), 12, "kingdom",
          "back", weld_to="tool_sack", tags=["detail"])

    # crowns and crests on the head
    piece("crown_gold", "Head", (0, HEAD_Y + 0.72, 0), (1.9, 0.6, 1.9), 100, "fixed", "hair", weld_to="Head")
    crest = {
        "crimson": ((0, NECK_Y + 0.8 + 0.8 + 0.8 - 0.05, 0), (1.41, 1.6, 1.41), 40),
        "azure": ((0, NECK_Y + 0.8 + 0.8 + 0.24 - 0.02, 0), (1.95, 0.48, 1.95), 24),
        "emerald": ((0, NECK_Y + 0.8 + 0.8 + 0.6, 0.7), (0.7, 1.6, 2.4), 60),
        "gold": ((0, NECK_Y + 0.8 + 0.8 + 0.4 - 0.25, 0), (1.3, 1.3, 1.3), 90),
        "neutral": ((0, NECK_Y + 0.8 + 0.8 + 0.1, 0), (0.6, 0.4, 0.6), 24),
    }
    for k, (c, s, tris) in crest.items():
        piece(f"crest_{k}", "Head", c, s, tris, "kingdom", "hair", weld_to="Head", tags=[k])

    def base(**slots):
        return dict(slots)

    citizen = {
        "torso": "torso_%look.outfit%",
        "head": "head_%look.face%",
        "arm_l": "arm_l", "arm_r": "arm_r",
        "sleeve_l": "sleeve_l", "sleeve_r": "sleeve_r",
        "leg": "leg_trousers", "boot": "boot_%look.boots%",
    }
    assemblies = {
        "idle": base(**citizen, hair="hair_%look.hair%", acc="acc_%look.acc%"),
        "hauler": base(**citizen, hair="hair_%look.hair%", tool="tool_sack", extras=["tool_sack_strap"]),
        "farmer": base(**citizen, hair="hat_farmer", extras=["hat_farmer_crown"], tool="tool_hoe",
                       tool_extra="tool_hoe_blade"),
        "woodcutter": base(**citizen, hair="hat_woodcutter", tool="tool_axe", tool_extra="tool_axe_head"),
        "miner": base(**citizen, hair="hat_miner", extras=["hat_miner_lamp"], tool="tool_pick",
                      tool_extra="tool_pick_head"),
        "builder": base(**citizen, hair="hat_builder", extras=["hat_builder_visor"], tool="tool_hammer",
                        tool_extra="tool_hammer_head"),
        "soldier": {
            "torso": "armour_%kingdom%", "head": "head_helm", "hair": "crest_%kingdom%",
            "arm_l": "arm_l", "arm_r": "arm_r", "sleeve_l": "sleeve_kingdom_l", "sleeve_r": "sleeve_kingdom_r",
            "leg": "leg_mail", "boot": "boot_01",
            "tool": "tool_spear", "extras": ["tool_spear_head", "tool_spear_pennant"],
        },
        "governor": {
            "torso": "torso_regal", "head": "head_%look.face%", "hair": "crown_gold", "cape": "cape_%kingdom%",
            "arm_l": "arm_l", "arm_r": "arm_r", "sleeve_l": "sleeve_kingdom_l", "sleeve_r": "sleeve_kingdom_r",
            "leg": "leg_trousers", "boot": "boot_02",
            "tool": "tool_staff", "extras": ["tool_staff_orb"],
        },
    }
    archer = dict(assemblies["soldier"])
    archer["tool"] = "tool_bow"
    del archer["extras"]
    assemblies["soldier_archer"] = archer
    return {
        "schema_version": 1,
        "unit": "stud",
        "root_height": 3.2,
        "joints": joints,
        "pieces": pieces,
        "assemblies": assemblies,
    }


def render() -> str:
    return json.dumps(build(), indent=1, sort_keys=True) + "\n"


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--check", action="store_true", help="exit 1 if the file on disk differs")
    args = ap.parse_args(argv)
    text = render()
    if args.check:
        if not args.out.exists() or args.out.read_text() != text:
            print(f"make_placeholder_rig: {args.out} is out of date", file=sys.stderr)
            return 1
        print(f"make_placeholder_rig: {args.out} is up to date")
        return 0
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(text)
    print(f"make_placeholder_rig: wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
